<#
.SYNOPSIS
    Pemasang template harness CooperAgent ke ~/.grok/ pada mesin developer Windows.

.DESCRIPTION
    Padanan PowerShell dari scripts/setup-dev.sh. Memasang:
      ~/.grok/AGENTS.md        aturan kerja agent (Grok, folder mana pun)
      ~/.omp/agent/AGENTS.md   aturan yang SAMA untuk Oh My Pi
      ~/.grok/config.toml auto-compact + cadangan jatah output + memory
      ~/.grok/skills/     skill CooperAgent, tersedia di luar repo ini

    config.toml di-MERGE, bukan ditimpa: hanya kunci yang dikelola template yang
    diubah. api_key dan pengaturan pribadi lain di mesin dev tetap utuh.

.PARAMETER DryRun
    Tampilkan perubahan tanpa menulis apa pun.

.EXAMPLE
    .\scripts\setup-dev.ps1 -DryRun
    .\scripts\setup-dev.ps1 -Token ca_...
    .\scripts\setup-dev.ps1
#>
[CmdletBinding()]
param([switch]$DryRun, [string]$Token = '')

# Bentuk token diperiksa di sini, bukan diserahkan ke gateway. Salah tempel
# adalah kesalahan paling umum saat onboarding, dan menemukannya sekarang jauh
# lebih murah daripada menemukannya lewat 401 di tengah kerja.
if ($Token) {
    if (-not $Token.StartsWith('ca_')) {
        Write-Error "Token harus diawali 'ca_'. Yang Anda tempel diawali '$($Token.Substring(0,[Math]::Min(3,$Token.Length)))'."
        exit 2
    }
    if ($Token.Length -ne 51) {
        Write-Error "Token harus 51 karakter (ca_ + 48 hex); yang ditempel $($Token.Length). Kemungkinan terpotong saat disalin."
        exit 2
    }
}

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$TplDir   = Join-Path $RepoRoot 'templates'
$GrokHome = if ($env:GROK_HOME) { $env:GROK_HOME } else { Join-Path $HOME '.grok' }
$Stamp    = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $TplDir)) { throw "Template tidak ditemukan: $TplDir" }

Write-Host "Template CooperAgent -> $GrokHome" -ForegroundColor White
if ($DryRun) { Write-Host 'Mode dry-run: tidak ada berkas yang ditulis.' -ForegroundColor Yellow }
Write-Host ''

New-Item -ItemType Directory -Force -Path (Join-Path $GrokHome 'skills') | Out-Null

# --- merge TOML -------------------------------------------------------------
# Implementasinya di pustaka bersama supaya setup.ps1 dan skrip ini tidak pernah
# menyimpang. Sebelumnya setup.ps1 justru MENIMPA config.toml, sehingga hasil
# kerja kedua skrip bertolak belakang.
. (Join-Path $RepoRoot 'scripts/lib/MergeToml.ps1')
. (Join-Path $RepoRoot 'scripts/lib/Contract.ps1')
. (Join-Path $RepoRoot 'scripts/lib/OmpModels.ps1')

# --- config.toml -------------------------------------------------------------
$Cfg = Join-Path $GrokHome 'config.toml'
$TplCfg = Join-Path $TplDir 'config.toml'

# Kontrak DULU, merge kemudian.
#
# Template memuat placeholder yang hanya gateway bisa isi. Alamatnya dibaca dari
# config yang sudah ada - skrip ini pembaru, bukan onboarding, jadi ia tidak
# menanyakan apa pun.
$gwBase = ''
if (Test-Path $Cfg) {
    $bl = Get-Content -LiteralPath $Cfg | Where-Object { $_ -match '^\s*base_url\s*=' } | Select-Object -First 1
    if ($bl -and $bl -match '["'']([^"'']*)["'']') { $gwBase = $Matches[1] }
}
$gwBase = $gwBase -replace '/api/v1$', '' -replace '/v1$', ''
# Jalur mundur untuk mesin yang belum punya config sama sekali.
if (-not $gwBase) { $gwBase = $env:COOPERAGENT_GATEWAY }
$gwBase = ($gwBase -replace '/$', '') -replace '/api/v1$', '' -replace '/v1$', ''
if (Get-CooperContract $gwBase) {
    Write-Host "  OK  kontrak dari gateway: context $(Format-CooperNumber $ContractContextWindow) / output $ContractMaxTokens / compact $ContractCompactPct% / model $ContractModelId" -ForegroundColor Green
    if ($ContractUpstreamSource -eq 'env-fallback') {
        Write-Host '  !   gateway memakai nilai env - tidak ada slot upstream sehat saat ditanya.' -ForegroundColor Yellow
    }
} else {
    $wh = if ($gwBase) { $gwBase } else { '(alamat tidak terbaca)' }
    Write-Host "  !   kontrak tidak terambil dari $wh - memakai nilai cadangan." -ForegroundColor Yellow
    Write-Host '      Nilai yang ditulis bisa tertinggal dari server. Jalankan ulang saat gateway terjangkau.' -ForegroundColor Yellow
}
Write-Host ''

# Yang di-merge SELALU hasil render, tidak pernah template mentah:
# `context_window = __CONTEXT_WINDOW__` di config dev adalah kerusakan yang baru
# terlihat jauh dari sini, saat harness-nya gagal start.
# `__GATEWAY__` diisi dari alamat yang SEDANG dipakai dev, bukan dari konstanta.
# Skrip ini pembaru, bukan onboarding: bila belum ada alamat, ia menolak
# menuliskan config yang pasti salah.
if (-not $gwBase) {
    Write-Host "XX  Tidak ada alamat gateway di $Cfg." -ForegroundColor Red
    Write-Host "    Jalankan onboarding dulu: .\setup.ps1 -Token ca_..." -ForegroundColor Yellow
    Write-Host "    Atau setel: `$env:COOPERAGENT_GATEWAY = 'http://<host>:8987'" -ForegroundColor Yellow
    exit 1
}
$tplText = (Expand-CooperTemplate (Get-Content -Raw -LiteralPath $TplCfg)).Replace('__GATEWAY__', $gwBase)
if (-not (Assert-CooperRendered $tplText 'templates/config.toml')) { exit 1 }
$TplRendered = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($TplRendered, $tplText, (New-Object System.Text.UTF8Encoding($false)))
$managed = Get-ManagedKeys $TplRendered

if (Test-Path $Cfg) {
    $existing = @(Get-Content -LiteralPath $Cfg)
    $merged = Merge-Toml $managed $existing
} else {
    Write-Host 'config.toml belum ada - dibuat dari template.' -ForegroundColor Yellow
    $existing = @()
    $merged = @(Get-Content -LiteralPath $TplRendered)
}
Remove-Item -LiteralPath $TplRendered -Force -ErrorAction SilentlyContinue

# Token dipasang SESUDAH merge, supaya template tetap bebas rahasia. Setiap
# blok [model.*] mendapat api_key yang sama: ketiganya menunjuk gateway yang
# sama, dan membiarkan salah satunya tertinggal berarti dev terputus begitu ia
# berpindah antara endpoint LAN, localhost, dan s2.
if ($Token) {
    $out = New-Object System.Collections.Generic.List[string]
    $buf = New-Object System.Collections.Generic.List[string]
    $isModel = $false; $has = $false
    function Flush-Block {
        if ($buf.Count -eq 0) { return }
        $out.Add($buf[0])
        if ($isModel -and -not $has) { $out.Add("api_key = `"$Token`"") }
        for ($i = 1; $i -lt $buf.Count; $i++) { $out.Add($buf[$i]) }
        $buf.Clear(); $script:has = $false
    }
    foreach ($line in $merged) {
        if ($line -match '^\[') {
            Flush-Block
            # HANYA blok yang DIKELOLA CooperAgent. `^\[model\.` cocok dengan
            # SETIAP blok model, termasuk [model.claude-saya] milik dev -- dan
            # menimpa api_key di sana menghapus kunci BERBAYAR miliknya dengan
            # token kita. Ditemukan lewat pengujian 1 September 2026.
            $isModel = ($line -match '^\[model\.internal-qwen')
            $buf.Add($line)
            continue
        }
        if ($buf.Count -eq 0) { $out.Add($line); continue }
        if ($isModel -and $line -match '^\s*api_key\s*=') {
            $buf.Add("api_key = `"$Token`""); $has = $true; continue
        }
        $buf.Add($line)
    }
    Flush-Block
    $merged = $out.ToArray()
    $n = ($merged | Where-Object { $_ -eq "api_key = `"$Token`"" }).Count
    Write-Host "OK  token dipasang ke $n blok [model.*] (...$($Token.Substring($Token.Length-4)))" -ForegroundColor Green
}

if ((($existing -join "`n")) -eq (($merged -join "`n"))) {
    Write-Host 'OK  config.toml sudah sesuai template - tidak ada perubahan.' -ForegroundColor Green
} else {
    Write-Host 'config.toml - perubahan:' -ForegroundColor White
    (Compare-Object $existing $merged) | ForEach-Object {
        $sign = if ($_.SideIndicator -eq '=>') { '  +' } else { '  -' }
        Write-Host "$sign $($_.InputObject)"
    }
    if (-not $DryRun) {
        if (Test-Path $Cfg) {
            Copy-Item $Cfg "$Cfg.bak.$Stamp"
            Write-Host "  cadangan: config.toml.bak.$Stamp"
        }
        $tmp = [System.IO.Path]::GetTempFileName()
        Set-Content -LiteralPath $tmp -Value $merged -Encoding UTF8
        Move-Item -Force $tmp $Cfg
        Write-Host 'OK  config.toml diperbarui.' -ForegroundColor Green
    }
}
Write-Host ''

# --- Aturan agent: satu sumber, dua tujuan ------------------------------------
#
# Grok membaca ~/.grok/AGENTS.md; Oh My Pi membaca ~/.omp/agent/AGENTS.md.
# Keduanya global -- terverifikasi 2026-08-29 dengan kata sandi unik: omp
# menemukannya di ~/.omp/agent/ dan TIDAK di ~/.omp/.
$TplAgt = Join-Path $TplDir 'agent-rules.md'
$tplText = Get-Content -LiteralPath $TplAgt -Raw

function Install-Rules([string]$Dst, [string]$Label) {
    $dir = Split-Path -Parent $Dst
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if ((Test-Path $Dst) -and ((Get-Content -LiteralPath $Dst -Raw) -eq $script:tplText)) {
        Write-Host "OK  $Label sudah mutakhir." -ForegroundColor Green
    } else {
        if (-not $script:DryRun) {
            if (Test-Path $Dst) {
                Copy-Item $Dst "$Dst.bak.$script:Stamp"
                Write-Host "  cadangan: $(Split-Path -Leaf $Dst).bak.$script:Stamp"
            }
            Copy-Item -Force $script:TplAgt $Dst
        }
        Write-Host "OK  $Label dipasang ($($script:tplText.Length) karakter, batas 10.000)." -ForegroundColor Green
    }
}

Install-Rules (Join-Path $GrokHome 'AGENTS.md') 'Aturan agent (Grok)'
# Dipasang tanpa syarat: dev bisa memasang omp kapan saja setelah ini.
Install-Rules (Join-Path $env:USERPROFILE '.omp\agent\AGENTS.md') 'Aturan agent (Oh My Pi)'
Write-Host ''

# --- skills ------------------------------------------------------------------
function Get-DirSignature([string]$Path) {
    if (-not (Test-Path $Path)) { return '' }
    $full = (Resolve-Path $Path).Path
    return ((Get-ChildItem -Recurse -File $full | Sort-Object FullName | ForEach-Object {
        $rel = $_.FullName.Substring($full.Length)
        "$rel|$((Get-FileHash $_.FullName -Algorithm SHA256).Hash)"
    }) -join "`n")
}

Write-Host 'Skills:' -ForegroundColor White
$tplSkills = Get-ChildItem -Directory (Join-Path $TplDir 'skills')
foreach ($src in $tplSkills) {
    $dst = Join-Path $GrokHome "skills/$($src.Name)"
    $same = (Get-DirSignature $src.FullName) -eq (Get-DirSignature $dst)
    if ($same) {
        Write-Host "  OK  $($src.Name) (mutakhir)" -ForegroundColor Green
    } else {
        if (-not $DryRun) {
            if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
            Copy-Item -Recurse $src.FullName $dst
        }
        Write-Host "  OK  $($src.Name) dipasang" -ForegroundColor Green
    }
}
# Skill juga dipasang untuk Oh My Pi ke direktori TERPISAH.
#
# omp tidak membaca ~/.grok/skills -- terverifikasi 30 Agustus 2026: bawaan
# skills.customDirectories kosong. Direktori terpisah dipakai agar skill pihak
# ketiga milik dev di ~/.grok/skills tidak ikut terseret ke omp.
$CooperSkills = Join-Path (Join-Path $env:USERPROFILE '.cooper') 'skills'
foreach ($src in $tplSkills) {
    $dst = Join-Path $CooperSkills $src.Name
    if ((Get-DirSignature $src.FullName) -ne (Get-DirSignature $dst)) {
        if (-not $DryRun) {
            if (-not (Test-Path $CooperSkills)) { New-Item -ItemType Directory -Force -Path $CooperSkills | Out-Null }
            if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
            Copy-Item -Recurse $src.FullName $dst
        }
    }
}
Write-Host '  OK  skill juga dipasang untuk omp di ~/.cooper/skills' -ForegroundColor Green

# Skill yang PERNAH kami kirim lalu dipensiunkan. Tanpa ini, dev yang pernah
# menjalankan setup lama tetap melihat /standardization sesudah memperbarui, dan
# wizard itu menulis aturan ke proyek -- bertentangan dengan aturan global yang
# baru dipasang. Hanya nama di bawah yang dihapus; skill lain tidak disentuh.
foreach ($retired in @('standardization','init-changelog','checkpoint')) {
    $old = Join-Path $GrokHome "skills/$retired"
    if (Test-Path $old) {
        if (-not $DryRun) { Remove-Item -Recurse -Force $old }
        Write-Host "  --  $retired dihapus (dipensiunkan 2026-08-29)" -ForegroundColor Yellow
    }
}

$names = $tplSkills | ForEach-Object { $_.Name }
$other = @(Get-ChildItem -Directory (Join-Path $GrokHome 'skills') |
           Where-Object { $names -notcontains $_.Name })
if ($other.Count -gt 0) {
    Write-Host "  ($($other.Count) skill lain di ~/.grok/skills/ dibiarkan apa adanya)"
}
Write-Host ''

# --- Oh My Pi: ambang compaction + pemeriksaan endpoint -----------------------
#
# Aturan agent sudah dipasang di atas. Yang belum: models.yml dan ambang
# compaction, yang sampai sekarang hanya disentuh setup.ps1 yang interaktif.
# Akibatnya terlihat 29 Agustus 2026 -- models.yml seorang dev menunjuk VPN
# sementara ia di kantor, dan tidak ada perintah yang memberi tahu.
$OmpDir = Join-Path (Join-Path $env:USERPROFILE '.omp') 'agent'
$OmpBin = (Get-Command omp -ErrorAction SilentlyContinue).Source
if (-not $OmpBin) {
    $cand = Join-Path $env:LOCALAPPDATA 'omp\omp.exe'
    if (Test-Path $cand) { $OmpBin = $cand }
}

if ($OmpBin -or (Test-Path $OmpDir)) {
    Write-Host 'Oh My Pi:' -ForegroundColor White

    if ($OmpBin) {
        if (-not $DryRun) {
            # Tanpa ini omp tidak menemukan /handoff sama sekali.
            #
            # JSON WAJIB: `omp config set skills.customDirectories <path>` polos
            # ditolak diam-diam (nilai lama bertahan, exit 1). Jadi tanda kutip
            # ganda di dalam argumen harus benar-benar sampai ke omp.
            #
            # Di situlah PowerShell menggigit. Windows PowerShell 5.1 MEMBUANG
            # tanda kutip ganda saat melewatkan argumen ke program native,
            # sehingga omp menerima `[~/.cooper/skills]` dan menolaknya dengan
            # "Invalid array JSON" -- terlihat nyata di mesin dev 1 September
            # 2026. PowerShell 7.3+ dengan $PSNativeCommandArgumentPassing
            # 'Standard' justru meneruskan `\"` apa adanya, jadi bentuk yang
            # benar untuk 5.1 salah untuk 7 dan sebaliknya.
            #
            # Daripada menebak versi, kedua bentuk dicoba dan HASILNYA dibaca
            # kembali. Yang menentukan keberhasilan adalah nilai di config, bukan
            # tebakan tentang shell mana yang sedang berjalan.
            # Menekan stderr program native di PowerShell TIDAK cukup dengan
            # `2>$null`: PowerShell tetap membungkusnya sebagai NativeCommandError
            # dan mencetaknya. Itu sebabnya percobaan pertama yang memang
            # diharapkan gagal tetap membanjiri layar dev pada 1 September 2026,
            # menutupi baris hasil yang sebenarnya.
            $prevEA = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'

            # Urutan dicoba dari yang PALING MUNGKIN benar untuk shell ini,
            # supaya jalur normal tidak menghasilkan galat sama sekali.
            #
            # Windows PowerShell 5.1 -- dan PowerShell 7 dengan
            # $PSNativeCommandArgumentPassing 'Legacy', default di Windows --
            # MEMBUANG tanda kutip ganda saat melewatkan argumen ke program
            # native, jadi JSON harus di-escape backslash. PS 7 'Standard'
            # meneruskan apa adanya, dan di sana backslash justru ikut terkirim.
            # Bentuk yang benar untuk satu shell salah untuk yang lain.
            $standardPassing = $false
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $mode = Get-Variable -Name PSNativeCommandArgumentPassing -ValueOnly -ErrorAction SilentlyContinue
                if ($mode -eq 'Standard') { $standardPassing = $true }
            }
            $plain   = '["~/.cooper/skills"]'
            $escaped = '[\"~/.cooper/skills\"]'
            $forms = if ($standardPassing) { @($plain, $escaped) } else { @($escaped, $plain) }

            $skillsOk = $false
            foreach ($form in $forms) {
                & $OmpBin config set skills.customDirectories $form *>&1 | Out-Null
                $got = (& $OmpBin config get skills.customDirectories *>&1) -join ''
                if ($got -match 'cooper') { $skillsOk = $true; break }
            }

            & $OmpBin config set compaction.thresholdPercent $ContractCompactPct *>&1 | Out-Null
            $thr = (& $OmpBin config get compaction.thresholdPercent *>&1) -join ''
            $ErrorActionPreference = $prevEA

            if ($skillsOk) {
                Write-Host '  OK  direktori skill terdaftar (~/.cooper/skills)' -ForegroundColor Green
            } else {
                # Versi sebelumnya mencetak OK tanpa memeriksa apa pun, sehingga
                # kegagalan terlaporkan sebagai berhasil. Laporan palsu lebih
                # buruk daripada kegagalan yang terlihat.
                Write-Host '  !   gagal mendaftarkan direktori skill omp' -ForegroundColor Yellow
                Write-Host '      /handoff tidak tersedia di omp. Jalankan manual:'
                Write-Host "        omp config set skills.customDirectories '[\`"~/.cooper/skills\`"]'"
                Write-Host '      periksa: omp config get skills.customDirectories'
            }

            if ($thr -match '80') {
                Write-Host '  OK  ambang compaction 80%' -ForegroundColor Green
            } else {
                Write-Host '  !   gagal menyetel ambang compaction' -ForegroundColor Yellow
                Write-Host "      jalankan: omp config set compaction.thresholdPercent $ContractCompactPct"
            }
        } else {
            Write-Host '  OK  direktori skill + ambang compaction (dry-run)' -ForegroundColor Green
        }
    } else {
        Write-Host '  !   biner omp tidak ditemukan - ambang compaction tidak dapat disetel.' -ForegroundColor Yellow
        Write-Host "      Buka terminal baru lalu: omp config set compaction.thresholdPercent $ContractCompactPct"
    }

    # models.yml TIDAK ditimpa bila sudah ada -- dev bisa menambahkan provider
    # sendiri di sana. Yang dilakukan hanya membandingkan dengan config Grok.
    $gcfg = Join-Path $GrokHome 'config.toml'
    $id = ''; $url = ''
    if (Test-Path $gcfg) {
        $lines = Get-Content $gcfg
        $mk = $lines | Where-Object { $_ -match '^\s*api_key\s*=' } | Select-Object -First 1
        if ($mk -and $mk -match '["''"]([^"''"]*)["''"]') { $id = $Matches[1] }
        $mu = $lines | Where-Object { $_ -match '^\s*base_url\s*=' } | Select-Object -First 1
        if ($mu -and $mu -match '["''"]([^"''"]*)["''"]') { $url = $Matches[1] }
    }
    # -Token MENANG atas apa pun yang masih tertulis di config Grok. Tanpa ini,
    # memutar token lewat -Token memperbarui config.toml tapi meninggalkan
    # models.yml pada kunci lama -- `grok` jalan, `omp` 401.
    if ($Token) { $id = $Token }
    $wantUrl = ($url -replace '/api/v1$', '') + '/v1'
    $my = Join-Path $OmpDir 'models.yml'

    if (-not $id -or -not $url) {
        Write-Host "  !   identitas/endpoint tidak terbaca dari $gcfg - models.yml dilewati." -ForegroundColor Yellow
    } elseif (-not (Test-Path $my)) {
        if (-not $DryRun) {
            if (-not (Test-Path $OmpDir)) { New-Item -ItemType Directory -Force -Path $OmpDir | Out-Null }
            $gw = $url -replace '/api/v1$', ''
            $ompTpl = Join-Path $TplDir 'omp-models.yml'
            if (Test-Path $ompTpl) {
                $yml = (Expand-CooperTemplate (Get-Content -Raw $ompTpl)).Replace('__GATEWAY__', $gw).Replace('__API_KEY__', $id)
                if (-not (Assert-CooperRendered $yml 'models.yml')) { exit 1 }
                [System.IO.File]::WriteAllText($my, $yml, (New-Object System.Text.UTF8Encoding($false)))
            } else {
                Write-Host "  !   Template tidak ditemukan: $ompTpl" -ForegroundColor Red
            }
        }
        Write-Host "  OK  models.yml dibuat -> $wantUrl" -ForegroundColor Green
    } else {
        $cur = (Get-Content $my | Where-Object { $_ -match 'baseUrl:' } | Select-Object -First 1) -replace '.*baseUrl:\s*', ''
        if ($cur -eq $wantUrl) {
            Write-Host "  OK  models.yml endpoint sesuai ($wantUrl)" -ForegroundColor Green
        } else {
            Write-Host "  !   models.yml menunjuk $cur, config Grok menunjuk $wantUrl" -ForegroundColor Yellow
            Write-Host "      Tidak ditimpa. Sunting baris baseUrl di $my bila perlu."
        }
        # apiKey DIPERBARUI, tidak sekadar diperingatkan.
        #
        # Baris baseUrl memang milik dev -- ia boleh menunjuk endpoint lain, dan
        # menimpanya menghapus pekerjaannya. Tapi apiKey bukan pilihan dev: ia
        # kredensial yang diterbitkan admin, dan setiap kali token diputar,
        # models.yml yang tertinggal berarti omp berhenti bekerja sementara Grok
        # jalan normal. Peringatan saja membuat dev menyunting YAML dengan tangan
        # -- persis yang seharusnya dihapus oleh -Token.
        if ((Get-Content $my) -match "apiKey:\s*$([regex]::Escape($id))") {
            Write-Host '  OK  models.yml identitas sesuai' -ForegroundColor Green
        } elseif (-not $DryRun) {
            Copy-Item $my "$my.bak.$Stamp"
            # Implementasinya di scripts/lib/OmpModels.ps1 -- dipakai juga oleh
            # setup.ps1. Dua salinan yang harus dijaga sinkron dengan tangan
            # adalah kelas kegagalan yang sudah berkali-kali menggigit repo ini.
            [void](Set-OmpApiKey $my $id ($url -replace '/api/v1$', ''))
            if ((Get-Content $my) -match "apiKey:\s*$([regex]::Escape($id))") {
                Write-Host "  OK  models.yml identitas diperbarui (cadangan: models.yml.bak.$Stamp)" -ForegroundColor Green
            } else {
                Write-Host "  !   gagal memperbarui apiKey di $my - sunting manual" -ForegroundColor Yellow
            }
        } else {
            Write-Host '  OK  models.yml identitas akan diperbarui (dry-run)' -ForegroundColor Green
        }
    }
    Write-Host ''
}

# --- verifikasi --------------------------------------------------------------
Write-Host 'Verifikasi:' -ForegroundColor White
$check = $merged
# Diperiksa terhadap KONTRAK, bukan terhadap angka yang dipatok di skrip ini.
#
# Sampai 1 September 2026 baris ini berbunyi '131072'. Artinya begitu --ctx-size
# server berubah, skrip ini akan mencetak "OK context_window = 131072" dengan
# yakin justru pada saat nilainya sudah salah - memverifikasi config terhadap
# keyakinannya sendiri, bukan terhadap servernya.
foreach ($pair in @(@('auto_compact_threshold_percent', [string]$ContractCompactPct),
                    @('context_window', [string]$ContractContextWindow),
                    @('enabled', 'true'))) {
    $key = $pair[0]; $want = $pair[1]
    $line = $check | Where-Object { $_ -match ('^\s*' + [regex]::Escape($key) + '\s*=') } | Select-Object -First 1
    $got = if ($line) { ($line -split '=', 2)[1].Trim() } else { '(tidak ada)' }
    if ($got -eq $want) { Write-Host "  OK  $key = $got" -ForegroundColor Green }
    else { Write-Host "  XX  $key = $got, seharusnya $want" -ForegroundColor Red }
}

$curLine = $check | Where-Object { $_ -match '^\s*api_key\s*=' } | Select-Object -First 1
$curKey  = if ($curLine -match '["''"]([^"''"]*)["''"]') { $Matches[1] } else { '' }
if (-not $curKey) {
    Write-Host ''
    Write-Host 'PERINGATAN: tidak ada api_key di config.toml.' -ForegroundColor Yellow
    Write-Host '  Mintalah token kepada pemilik gateway, lalu jalankan:'
    Write-Host '    .\scripts\setup-dev.ps1 -Token ca_...'
} elseif (-not $curKey.StartsWith('ca_')) {
    Write-Host ''
    Write-Host "PERINGATAN: api_key masih berupa nama (`"$curKey`"), bukan token." -ForegroundColor Yellow
    Write-Host '  Nama bisa diketik siapa saja, jadi ia bukan autentikasi. Gateway'
    Write-Host '  akan menolaknya begitu penegakan dinyalakan.'
    Write-Host '    .\scripts\setup-dev.ps1 -Token ca_...'
} else {
    Write-Host "  OK  api_key berupa token (...$($curKey.Substring($curKey.Length-4)))" -ForegroundColor Green
}

Write-Host ''
if ($DryRun) {
    Write-Host 'Dry-run selesai - tidak ada yang ditulis.' -ForegroundColor Yellow
} else {
    Write-Host 'Selesai. Berlaku pada sesi grok berikutnya (sesi yang sedang jalan tidak terpengaruh).' -ForegroundColor Green
}
