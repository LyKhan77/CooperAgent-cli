# ==============================================================================
# Setup Script: CooperAgent (CooperxHarness - Grok Build & Oh My Pi)
# Platform: Windows PowerShell Edition (Gateway port 8987, 131.072 token per slot)
# Repository: https://github.com/LyKhan77/CooperAgent-cli.git
# ==============================================================================

#Requires -Version 5.1
[CmdletBinding()]
param(
    # `setup.ps1 -Endpoint vpn` hanya memindahkan alamat gateway: identitas dev
    # dibaca ulang dari config yang ada, tidak ada prompt, tidak ada pemasangan.
    # Inilah jalur berpindah LAN <-> VPN, yang dulu menuntut setup penuh.
    [string]$Endpoint = "",

    # Cetak endpoint + api key untuk dipakai dari harness LAIN, lalu keluar.
    # Gateway ini endpoint OpenAI-compatible biasa; tidak ada alasan ia hanya
    # bisa dipakai dari harness kita sendiri.
    [switch]$Info,

    # Token kredensial. Sejak penegakan menyala (1 September 2026) gateway
    # MENOLAK identitas lama `dev-nama@device` dengan 401, jadi setup tanpa
    # token menghasilkan config yang tidak bisa dipakai sama sekali.
    [string]$Token = ""
)
$ErrorActionPreference = "Stop"

if ($Token) {
    if (-not $Token.StartsWith('ca_')) {
        Write-Error "Token harus diawali 'ca_'. Minta ke admin: cooper issue <nama> <device>"; exit 2
    }
    if ($Token.Length -ne 51) {
        Write-Error "Token harus 51 karakter (ca_ + 48 hex); yang ditempel $($Token.Length). Kemungkinan terpotong saat disalin."; exit 2
    }
}

# Alamat gateway TIDAK dipatok di sini.
#
# Sampai 2 September 2026 tiga baris di tempat ini memuat alamat LAN dan VPN
# kantor -- fakta tentang SERVER yang hidup di KLIEN, penyakit yang sama dengan
# context_window. Ia juga yang menghalangi skrip ini pindah ke repo pemasang
# yang publik: riwayat git tidak bisa dilupakan.
#
# Urutan: -Endpoint <url> > $env:COOPERAGENT_GATEWAY > config yang ada >
# ditanyakan. Alias lan/vpn/local diselesaikan lewat kontrak gateway.
$COOPERAGENT_GATEWAY = $env:COOPERAGENT_GATEWAY

# Daftar alamat dari kontrak terakhir yang berhasil, di mesin dev -- bukan di
# repo. Dipakai saat gateway tidak terjangkau.
$ENDPOINT_CACHE = Join-Path (Join-Path $env:USERPROFILE '.cooper') 'gateway-endpoints'

function ConvertTo-CanonicalEndpoint {
    # Menerima bentuk apa pun yang ditempel dev dan mengembalikan bentuk kanonik.
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $u = $Url.Trim().TrimEnd('/')
    foreach ($suffix in @('/api/v1', '/v1', '/api')) {
        if ($u.EndsWith($suffix)) { $u = $u.Substring(0, $u.Length - $suffix.Length); break }
    }
    return "$u/api/v1"
}

function Save-CooperEndpointCache {
    if ($script:ContractEndpoints.Count -eq 0) { return }
    try {
        $dir = Split-Path -Parent $ENDPOINT_CACHE
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        ($script:ContractEndpoints | ForEach-Object { "$($_.id)`t$($_.label)`t$($_.url)" }) |
            Set-Content -LiteralPath $ENDPOINT_CACHE -Encoding UTF8
    } catch { }
}

function Get-CooperEndpointCache {
    if (-not (Test-Path $ENDPOINT_CACHE)) { return @() }
    try {
        Get-Content -LiteralPath $ENDPOINT_CACHE | Where-Object { $_ -match "`t" } | ForEach-Object {
            $p = $_ -split "`t", 3
            [pscustomobject]@{ id = $p[0]; label = $p[1]; url = $p[2] }
        }
    } catch { @() }
}
# Nama model DITANYAKAN ke gateway, tidak dipatok di sini. Nilai ini hanya
# cadangan bila gateway tidak terjangkau saat setup berjalan.
$DEFAULT_MODEL_NAME = "intercon-agent"
$SCRIPT_DIR = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SCRIPT_DIR)) { $SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Merge, bukan tulis-ulang. `~/.grok/config.toml` bukan milik skrip ini sendiri:
# dev menaruh server MCP, preferensi [ui], model tambahan, dan [marketplace] di
# berkas yang sama. Sampai 2026-08-27 skrip ini MENIMPA berkas itu, sehingga
# setiap pergantian endpoint menghapus semuanya.
. (Join-Path $SCRIPT_DIR "scripts\lib\MergeToml.ps1")

# Nilai kontrak -- context_window, max_tokens, ambang compaction, nama model --
# DIAMBIL dari gateway, tidak dipatok di sini. Lihat berkasnya untuk alasannya;
# ringkasnya: yang dipatok klien tidak pernah tahu saat server berubah.
. (Join-Path $SCRIPT_DIR "scripts\lib\Contract.ps1")

# Kunci api pada models.yml omp -- satu implementasi, dipakai skrip ini DAN
# scripts/setup-dev.ps1. Sampai 3 September 2026 keduanya menyimpang, dan yang
# di sini menulis bentuk lama yang dijawab 401.
. (Join-Path $SCRIPT_DIR "scripts\lib\OmpModels.ps1")


# Helper pi hanya digunakan oleh pilihan pi atau provider pi yang sudah ada.
. (Join-Path $SCRIPT_DIR "scripts\lib\PiModels.ps1")

# Gerbang kredensial. Ia yang mengubah "setup selesai lalu 401 belakangan"
# menjadi "setup berhenti sekarang, dengan sebabnya".
. (Join-Path $SCRIPT_DIR "scripts\lib\Credential.ps1")
. (Join-Path $SCRIPT_DIR "scripts\lib\Backup.ps1")

# --- membaca kondisi yang sudah terpasang -------------------------------------
# Seksi yang DIKELOLA CooperAgent. Apa pun di luar daftar ini milik dev --
# server MCP, preferensi [ui], model tambahan -- dan dipakai untuk memberi tahu
# dengan jujur apa yang akan hilang bila ia memilih tulis-ulang penuh.
$MANAGED_SECTIONS = @('[cli]','[features]','[session]','[memory]','[models]',
                      '[model.internal-qwen]','[model.internal-qwen-s2]')

function Get-GrokConfigPath { Join-Path (Join-Path $env:USERPROFILE '.grok') 'config.toml' }

if ($Info) {
    $cfgPath = Get-GrokConfigPath
    $id = ""; $url = ""
    if (Test-Path $cfgPath) {
        $lines = Get-Content $cfgPath
        $mk = $lines | Where-Object { $_ -match '^\s*api_key\s*=' } | Select-Object -First 1
        if ($mk -and $mk -match '["''"]([^"''"]*)["''"]') { $id = $Matches[1] }
        $mu = $lines | Where-Object { $_ -match '^\s*base_url\s*=' } | Select-Object -First 1
        if ($mu -and $mu -match '["''"]([^"''"]*)["''"]') { $url = $Matches[1] }
    }
    if (-not $url) { $url = ConvertTo-CanonicalEndpoint $COOPERAGENT_GATEWAY }
    if (-not $url -or $url -eq '/api/v1') {
        Write-Host "Belum ada endpoint yang tercatat di ~\.grok\config.toml." -ForegroundColor Yellow
        Write-Host "Jalankan setup dulu, atau setel `$env:COOPERAGENT_GATEWAY" -ForegroundColor Yellow
        exit 1
    }
    if (-not $id)  { $id  = "dev-<nama>@<device>" }
    $base = $url -replace '/api/v1$', ''

    # -Info dulu TIDAK PERNAH menghubungi gateway: ia mencetak 131072 dan 80%
    # yang dipatok di skrip, lalu keluar. Justru inilah jalur yang paling butuh
    # angka benar -- ia dipakai dev yang membawa coding agent sendiri, yang
    # tidak punya skrip apa pun untuk mengoreksinya di kemudian hari.
    [void](Get-CooperContract $base)
    $DEFAULT_MODEL_NAME = $ContractModelId
    $ctxFmt  = Format-CooperNumber $ContractContextWindow
    $compFmt = Format-CooperNumber $ContractCompactTokens
    $note    = Get-CooperContractNote

    Write-Host @"
CooperAgent - endpoint untuk harness apa pun

  Base URL (OpenAI-compatible)   $base/v1
  API key                        $id
  Model                          $DEFAULT_MODEL_NAME
  Context window                 $ContractContextWindow      (prompt DAN jawaban, plafon keras)
  Max output                     $ContractMaxTokens
  Ambang compact yang disarankan $ContractCompactPct%         = $compFmt token
  Sumber angka di atas           $note

Variabel lingkungan gaya OpenAI SDK:

  `$env:OPENAI_BASE_URL = "$base/v1"
  `$env:OPENAI_API_KEY  = "$id"
  `$env:OPENAI_MODEL    = "$DEFAULT_MODEL_NAME"

Catatan yang perlu diketahui sebelum memakai alat lain:

  - api_key HARUS berupa token CooperAgent (ca_...). Sejak 1 September 2026
    gateway menolak identitas lama dev-<nama>@<device> dengan 401.
    Minta token ke admin: cooper issue <nama> <device>
  - Beri max_tokens minimal ~2000: model ini berpikir dulu, dan token yang
    habis untuk penalaran menghasilkan jawaban KOSONG.
  - Auto-compaction adalah fitur KLIEN. Alat yang tidak memilikinya akan tumbuh
    sampai menabrak $ctxFmt lalu terpotong. Setel ambangnya sendiri di $ContractCompactPct%.
  - Ringkasan/compaction dari alat lain TIDAK dikenali gateway, jadi ia berjalan
    dengan reasoning penuh. Kirim "reasoning_effort":"none" pada request
    ringkasan untuk mematikannya.
  - Header X-Upstream pada respons menyebut server mana yang menjawab.
"@
    exit 0
}

function Read-ExistingEndpoint {
    $cfg = Get-GrokConfigPath
    if (-not (Test-Path $cfg)) { return '' }
    $inSection = $false
    foreach ($line in (Get-Content -LiteralPath $cfg)) {
        if ($line -match '^\[model\.internal-qwen\]\s*$') { $inSection = $true; continue }
        if ($line -match '^\[') { $inSection = $false; continue }
        if ($inSection -and $line -match "^\s*base_url\s*=\s*['`"](.+)['`"]\s*$") { return $Matches[1] }
    }
    return ''
}

function Read-ExistingIdentity {
    $cfg = Get-GrokConfigPath
    if (-not (Test-Path $cfg)) { return '' }
    foreach ($line in (Get-Content -LiteralPath $cfg)) {
        # Nilai di dalam kutip, apa pun bentuknya. Pola sebelumnya MENUNTUT
        # awalan `dev-`, jadi pada config bertoken ia tidak pernah cocok dan
        # identitas dianggap tidak ada -- `-Endpoint vpn` menolak bekerja untuk
        # justru semua dev yang sudah bermigrasi ke token.
        if ($line -match "^\s*api_key\s*=\s*['`"]([^'`"]+)['`"]\s*$") { return $Matches[1] }
    }
    return ''
}

function Get-UnmanagedSections {
    $cfg = Get-GrokConfigPath
    if (-not (Test-Path $cfg)) { return @() }
    $out = @()
    foreach ($line in (Get-Content -LiteralPath $cfg)) {
        $t = $line.Trim()
        if ($t -match '^\[.*\]$' -and $MANAGED_SECTIONS -notcontains $t) { $out += $t }
    }
    return $out
}

# Ringkasan kondisi + pilihan cara memperbarui. Sampai 2026-08-27 skrip ini
# langsung menanyakan semuanya lalu menimpa; dev yang hanya ingin memperbarui
# parameter kehilangan server MCP-nya tanpa pernah diberi tahu.
function Show-ConfigModePrompt {
    $script:CONFIG_MODE = 'fresh'
    if (-not (Test-Path (Get-GrokConfigPath))) { return }

    $curEp = Read-ExistingEndpoint
    $curId = Read-ExistingIdentity
    $unmanaged = Get-UnmanagedSections

    Write-Host ""
    Write-Host "--- Konfigurasi Grok yang sudah ada terdeteksi ---" -ForegroundColor Cyan
    Write-Host "  berkas    : $(Get-GrokConfigPath)"
    if ($curEp) { Write-Host "  endpoint  : $curEp" }
    if ($curId) { Write-Host "  identitas : $curId" }
    if ($unmanaged.Count -gt 0) {
        Write-Host "  milik Anda: $($unmanaged -join ' ')" -ForegroundColor Yellow
        Write-Host "              (di luar kelolaan CooperAgent - mis. server MCP, setelan UI)"
    }

    Write-Host ""
    Write-Host "Bagaimana Anda ingin memperbarui?" -ForegroundColor Yellow
    Write-Host "  1) Perbarui parameter CooperAgent saja [disarankan]" -ForegroundColor Green
    Write-Host "     Endpoint dan identitas dipertahankan. Milik Anda tidak disentuh."
    Write-Host "  2) Ganti endpoint saja, sisanya dipertahankan"
    Write-Host "  3) Tulis ulang penuh dari template" -ForegroundColor Red
    if ($unmanaged.Count -gt 0) {
        Write-Host "     Seksi di atas AKAN HILANG (cadangan tetap dibuat)." -ForegroundColor Red
    }
    $modeChoice = Read-Host "Pilihan [1/2/3, default: 1]"
    if ([string]::IsNullOrWhiteSpace($modeChoice)) { $modeChoice = "1" }

    switch ($modeChoice) {
        "2" { $script:CONFIG_MODE = 'merge'; $script:KEEP_IDENTITY = $curId }
        "3" { $script:CONFIG_MODE = 'overwrite' }
        default {
            $script:CONFIG_MODE  = 'merge'
            $script:KEEP_IDENTITY = $curId
            $script:KEEP_ENDPOINT = $curEp
        }
    }
}

# --- penulisan config.toml ----------------------------------------------------
# Kunci di bawah adalah yang DIKELOLA skrip ini. Kunci lain di mesin dev tidak
# disebut di sini dan karena itu tidak pernah tersentuh oleh merge.
function Write-GrokConfig([string]$ServerUrl, [string]$Identity, [string]$Mode = 'merge') {
    $gw = $ServerUrl -replace '/api/v1$', ''
    # Aturannya di scripts/lib/OmpModels.ps1 -- SATU tempat, karena models.yml
    # omp menuntut kunci yang sama persis dan salinan kedua yang menyimpang
    # adalah bug yang baru terlihat saat `omp` 401 sementara `grok` jalan.
    $apiKeyValue = Get-OmpApiKey $Identity $script:Token
    $grokDir = Join-Path $env:USERPROFILE ".grok"
    if (-not (Test-Path $grokDir)) { New-Item -ItemType Directory -Path $grokDir -Force | Out-Null }
    $cfg = Join-Path $grokDir "config.toml"

    $tplLines = @(
        "[cli]", "auto_update = false", "",
        "[features]", "telemetry = false", "",
        "[session]",
        "# Compaction dipicu di $ContractCompactPct% dari context_window = $(Format-CooperNumber $ContractCompactTokens) token.",
        "#   $(Format-CooperNumber $ContractCompactTokens) (picu) + $(Format-CooperNumber $ContractMaxTokens) (jawaban) = $(Format-CooperNumber ($ContractCompactTokens + $ContractMaxTokens)) puncak, sisa $(Format-CooperNumber ($ContractContextWindow - $ContractCompactTokens - $ContractMaxTokens)).",
        "# Angka di blok ini: $(Get-CooperContractNote).",
        "auto_compact_threshold_percent = $ContractCompactPct",
        "load_envrc = true", "",
        "[memory]", "enabled = true", "",
        "[models]",
        "default = `"internal-qwen`"",
        "stream_tool_calls = true",
        "temperature = 1.0", "top_p = 0.95", "min_p = 0.0", "repeat_penalty = 1.0",
        "max_completion_tokens = $ContractMaxTokens", "max_tokens = $ContractMaxTokens", "max_output_tokens = $ContractMaxTokens", "",
        "[model.internal-qwen]",
        "model = `"$DEFAULT_MODEL_NAME`"",
        "base_url = `"$ServerUrl`"",
        "name = `"CooperAgent Qwen3.8-27B (routing otomatis)`"",
        "description = `"Gateway memilih server; header X-Upstream menyebut mana yang menjawab`"",
        "api_backend = `"chat_completions`"",
        "# Plafon SATU slot llama-server, ditanyakan ke gateway saat setup;",
        "# bantalan diatur oleh ambang $ContractCompactPct%.",
        "context_window = $ContractContextWindow",
        "max_completion_tokens = $ContractMaxTokens", "max_tokens = $ContractMaxTokens", "max_output_tokens = $ContractMaxTokens",
        "temperature = 1.0", "top_p = 0.95", "min_p = 0.0",
        "repeat_penalty = 1.0", "presence_penalty = 0.0",
        "api_key = `"$apiKeyValue`"", "",
        "# Menembus routing, langsung ke server 2 (bobot UD-Q4_K_XL).",
        "# ALAT PEMBANDING, bukan cara kerja sehari-hari: sesi yang memakainya",
        "# kehilangan failover otomatis.",
        "[model.internal-qwen-s2]",
        "model = `"$DEFAULT_MODEL_NAME`"",
        "base_url = `"$gw/api/v1/upstream/s2`"",
        "name = `"CooperAgent Qwen3.8-27B @ server 2 (UD-Q4_K_XL)`"",
        "description = `"Langsung ke server 2, menembus routing gateway`"",
        "api_backend = `"chat_completions`"",
        "context_window = $ContractContextWindow",
        "max_completion_tokens = $ContractMaxTokens", "max_tokens = $ContractMaxTokens", "max_output_tokens = $ContractMaxTokens",
        "temperature = 1.0", "top_p = 0.95", "min_p = 0.0",
        "repeat_penalty = 1.0", "presence_penalty = 0.0",
        "api_key = `"$apiKeyValue`""
    )

    $tmpTpl = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllLines($tmpTpl, [string[]]$tplLines, (New-Object System.Text.UTF8Encoding($false)))
    $managed = Get-ManagedKeys $tmpTpl

    if ((Test-Path $cfg) -and $Mode -ne 'overwrite') {
        $existing = @(Get-Content -LiteralPath $cfg)
        $merged = Merge-Toml $managed $existing
        if ((($existing -join "`n")) -eq (($merged -join "`n"))) {
            Write-Host "[v] config.toml sudah sesuai - tidak ada perubahan." -ForegroundColor Green
        } else {
            $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
            Copy-Item $cfg "$cfg.bak.$stamp"
            Invoke-CooperBakPrune $cfg
            [System.IO.File]::WriteAllLines($cfg, [string[]]$merged, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "[v] config.toml diperbarui (cadangan: config.toml.bak.$stamp)." -ForegroundColor Green
            Write-Host "    Server MCP, [ui], dan model tambahan Anda dibiarkan utuh." -ForegroundColor Yellow
        }
    } elseif (Test-Path $cfg) {
        # Tulis ulang penuh - hanya bila dev memilihnya secara sadar.
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item $cfg "$cfg.bak.$stamp"
        Invoke-CooperBakPrune $cfg
        [System.IO.File]::WriteAllLines($cfg, [string[]]$tplLines, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "[v] config.toml ditulis ulang (cadangan: config.toml.bak.$stamp)." -ForegroundColor Green
        Write-Host "    Seksi di luar kelolaan CooperAgent tidak ikut dibawa - ada di cadangan." -ForegroundColor Yellow
    } else {
        [System.IO.File]::WriteAllLines($cfg, [string[]]$tplLines, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "[v] config.toml dibuat: $cfg" -ForegroundColor Green
    }
    Remove-Item $tmpTpl -ErrorAction SilentlyContinue
}


# --- mode "sudah terpasang" ---------------------------------------------------
#
# Skrip ini adalah SATU pintu masuk, dan yang dilihat dev berbeda menurut
# keadaan mesinnya: onboarding penuh hanya untuk yang belum terpasang. Yang
# sudah terpasang tidak butuh ditanya harness dan endpoint lagi -- ia butuh tahu
# keadaannya sekarang, dan mengubah satu hal.
#
# Kredensial diperiksa di SINI, setiap kali, bahkan ketika dev hanya ingin
# memperbarui parameter. Pencabutan terjadi di sisi server tanpa memberi tahu
# klien; kalau bukan kita yang bertanya, dev baru mengetahuinya lewat 401 di
# tengah kerja.
$GROK_CFG_PATH = Get-GrokConfigPath
$OMP_YML_PATH  = Join-Path (Join-Path (Join-Path $env:USERPROFILE '.omp') 'agent') 'models.yml'
$PI_MODELS_PATH = Join-Path (Join-Path (Join-Path $env:USERPROFILE '.pi') 'agent') 'models.json'

function Test-CooperPiInstalled {
    return (Test-PiProvider $PI_MODELS_PATH)
}


function Test-CooperGrokInstalled {
    return ((Test-Path $GROK_CFG_PATH) -and
            ((Get-Content $GROK_CFG_PATH) -match '^\[model\.internal-qwen'))
}
function Test-CooperOmpInstalled {
    return ((Test-Path $OMP_YML_PATH) -and
            ((Get-Content $OMP_YML_PATH) -match '^  cooperagent:'))
}

# Alamat dan token dibaca dari MANA PUN yang ada. Dev yang memilih omp saja
# tidak punya config.toml, dan sampai 3 September 2026 ia karena itu tidak
# pernah terlihat sebagai "sudah terpasang".
function Get-CooperStoredGateway {
    $v = ''
    if (Test-CooperGrokInstalled) { $v = Read-ExistingEndpoint }
    if (-not $v -and (Test-CooperOmpInstalled)) { $v = Get-OmpStoredGateway $OMP_YML_PATH }
    if (-not $v -and (Test-CooperPiInstalled)) { $v = Get-PiStoredGateway $PI_MODELS_PATH }
    return $v
}
function Get-CooperStoredToken {
    $v = ''
    if (Test-CooperGrokInstalled) { $v = Read-ExistingIdentity }
    if ($v -notlike 'ca_*') { $v = '' }
    if (-not $v -and (Test-CooperOmpInstalled)) {
        $v = Get-OmpStoredKey $OMP_YML_PATH
    if (-not $v -and (Test-CooperPiInstalled)) {
        $v = Get-PiStoredKey $PI_MODELS_PATH
    }
        if ($v -notlike 'ca_*') { $v = '' }
    }
    return $v
}

# Menulis kredensial dan alamat ke SEMUA harness yang terpasang.
#
# Satu tempat, karena inilah yang selalu terlewat: sampai 3 September 2026
# -Endpoint hanya menyentuh config Grok, sehingga dev yang memakai keduanya
# berpindah jaringan di Grok dan tetap menunjuk alamat lama di omp.
function Set-CooperAllHarness([string]$NewUrl, [string]$Tok, [string]$Ident) {
    # Yang BUKAN token tidak boleh menyamar sebagai token: config lama berisi
    # `dev-nama@device`, dan meneruskannya sebagai $Token akan menulis
    # `api_key = "dev-nama@device"` menjadi `nama@device` -- bentuk ketiga yang
    # tidak pernah benar di mana pun.
    if ($Tok -notlike 'ca_*') { $Tok = '' }
    $key = Get-OmpApiKey $Ident $Tok
    if (Test-CooperGrokInstalled) {
        $script:Token = $Tok
        Write-GrokConfig $NewUrl $Ident
    }
    if (Test-CooperOmpInstalled) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item $OMP_YML_PATH "$OMP_YML_PATH.bak.$stamp"
        Invoke-CooperBakPrune $OMP_YML_PATH
        $newBase = Get-CooperGatewayBase $NewUrl
        $oldBase = Get-OmpStoredGateway $OMP_YML_PATH
        if ($oldBase -and $oldBase -ne $newBase) {
            [void](Set-OmpBaseUrl $OMP_YML_PATH $oldBase $newBase)
        }
        [void](Set-OmpApiKey $OMP_YML_PATH $key $newBase)
        Write-Host "[v] models.yml omp diperbarui (cadangan: models.yml.bak.$stamp)" -ForegroundColor Green
    }
    if (Test-CooperPiInstalled) {
        $setupPi = Join-Path (Join-Path $SCRIPT_DIR 'scripts') 'setup-pi.ps1'
        if (-not (Test-Path $setupPi)) { throw 'scripts\setup-pi.ps1 tidak ditemukan.' }
        & $setupPi -Endpoint $NewUrl -Token $Tok
    }

}

# --- eksekusi mode ganti endpoint --------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($Endpoint)) {
    # Alias diselesaikan oleh GATEWAY, bukan oleh tabel di skrip ini.
    # Bila tidak terjangkau, dipakai daftar dari kontrak terakhir yang berhasil.
    # Keduanya gagal = katakan, jangan tebak.
    $alias = $Endpoint.ToLower()
    if ($Endpoint -match '^https?://') {
        $newUrl = ConvertTo-CanonicalEndpoint $Endpoint
    } else {
        $curUrl = Get-CooperStoredGateway
        $newUrl = ''
        if ($curUrl -and (Get-CooperContract ($curUrl -replace '/api/v1$', ''))) {
            $newUrl = Get-CooperEndpointUrl $alias
            Save-CooperEndpointCache
        }
        if (-not $newUrl) {
            $hit = Get-CooperEndpointCache | Where-Object { $_.id -eq $alias } | Select-Object -First 1
            if ($hit) {
                $newUrl = $hit.url
                Write-Host "[!] Gateway tidak terjangkau - memakai alamat tersimpan." -ForegroundColor Yellow
            }
        }
        if (-not $newUrl) {
            Write-Host "[x] Alias '$alias' tidak dikenal gateway." -ForegroundColor Red
            $known = @(Get-CooperEndpointCache)
            if ($known.Count -gt 0) {
                Write-Host "    Yang tersimpan di mesin ini:" -ForegroundColor Yellow
                foreach ($e in $known) { Write-Host "      $($e.id)  $($e.url)  ($($e.label))" -ForegroundColor Cyan }
            } else {
                Write-Host "    Pakai alamat lengkap: .\setup.ps1 -Endpoint http://<host>:8987/api/v1" -ForegroundColor Yellow
            }
            exit 1
        }
    }

    # Identitas dibaca ulang dari config, bukan ditanya lagi: mengganti jaringan
    # tidak mengubah siapa Anda, dan salah ketik akan memecah leaderboard.
    $cfgPath = Join-Path (Join-Path $env:USERPROFILE ".grok") "config.toml"
    $identity = ""
    if (Test-Path $cfgPath) {
        foreach ($line in (Get-Content -LiteralPath $cfgPath)) {
            # Sama seperti Read-ExistingIdentity: nilai di dalam kutip, apa pun
            # bentuknya. Menuntut awalan `dev-` membuat -Endpoint gagal diam-diam
            # untuk setiap dev yang sudah memakai token.
            if ($line -match '^\s*api_key\s*=\s*[''"]([^''"]+)[''"]\s*$') { $identity = $Matches[1]; break }
        }
    }
    if ([string]::IsNullOrWhiteSpace($identity) -and (Test-CooperPiInstalled)) { $identity = Get-PiStoredKey $PI_MODELS_PATH }
    if ([string]::IsNullOrWhiteSpace($identity)) {
        Write-Host "[!] Tidak menemukan api_key di $cfgPath." -ForegroundColor Red
        Write-Host "Jalankan setup penuh dulu: .\setup.ps1" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Memindahkan endpoint ke: $newUrl" -ForegroundColor Cyan

    # Diverifikasi SEBELUM ditulis. Berpindah ke alamat yang tidak menjawab
    # berarti dev kehilangan gateway yang tadinya bekerja, dan sampai
    # 3 September 2026 blok ini menulis dulu lalu memeriksa kesehatan sesudahnya
    # -- urutan yang membuat pemeriksaannya tidak bisa mencegah apa pun.
    $identSwitch = $identity
    if ($identity -like 'ca_*') {
        $chkSw = Test-CooperCredential $newUrl $identity
        if ($chkSw.State -eq 'ok') {
            Write-Host "[v] Kredensial sah di alamat baru - identitas: $($chkSw.Who)" -ForegroundColor Green
            $identSwitch = $chkSw.Who
        } else {
            Write-Host "[x] Alamat baru TIDAK dipakai - kredensial tidak lolos di sana." -ForegroundColor Red
            foreach ($l in (Get-CooperCredentialHelp $chkSw.State $newUrl)) { Write-Host "    $l" -ForegroundColor Yellow }
            Write-Host ""
            Write-Host "    Config lama dibiarkan utuh." -ForegroundColor Yellow
            exit 3
        }
    } else {
        # Config lama tanpa token: tidak ada yang bisa diverifikasi, dan itu
        # dikatakan, bukan didiamkan. Awalan `dev-` dilepas karena yang disimpan
        # Write-GrokConfig adalah IDENTITAS -- ia yang memasangnya kembali.
        Write-Host "[!] Config ini belum memakai token - perpindahan tidak dapat diverifikasi." -ForegroundColor Yellow
        Write-Host "    Gateway akan menjawab 401 sampai token dipasang: .\setup.ps1" -ForegroundColor Yellow
        $identSwitch = $identity -replace '^dev-', ''
    }

    [void](Get-CooperContract (Get-CooperGatewayBase $newUrl))
    # SEMUA harness, bukan hanya Grok. Sampai 3 September 2026 baris ini hanya
    # menulis config.toml, sehingga dev yang memakai keduanya berpindah jaringan
    # di Grok dan tetap menunjuk alamat lama di omp -- gagal hanya di satu alat,
    # yang paling sulit ditebak sebabnya.
    Set-CooperAllHarness $newUrl $identity $identSwitch
    Save-CooperEndpointCache
    exit 0
}

# Prepare ~/.local/bin
$LOCAL_BIN = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $LOCAL_BIN)) {
    New-Item -ItemType Directory -Path $LOCAL_BIN -Force | Out-Null
}

# Ensure LOCAL_BIN is in PATH for current session
if ($env:PATH -notmatch [regex]::Escape($LOCAL_BIN)) {
    $env:PATH = "$LOCAL_BIN;$env:PATH"
}

# Ensure LOCAL_BIN is in User Environment PATH permanently
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if ($userPath -notmatch [regex]::Escape($LOCAL_BIN)) {
        [Environment]::SetEnvironmentVariable("Path", "$LOCAL_BIN;$userPath", [EnvironmentVariableTarget]::User)
    }
} catch {}

if ((-not $Endpoint) -and ((Test-CooperGrokInstalled) -or (Test-CooperOmpInstalled) -or (Test-CooperPiInstalled))) {
    $CUR_GATEWAY = Get-CooperStoredGateway
    $CUR_TOKEN   = Get-CooperStoredToken
    if ($Token) { $CUR_TOKEN = $Token }

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "   CooperAgent - sudah terpasang di mesin ini                    " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    $gwShow = if ($CUR_GATEWAY) { $CUR_GATEWAY } else { '(tidak terbaca)' }
    Write-Host "  gateway   : $gwShow"
    $hl = @()
    if (Test-CooperGrokInstalled) { $hl += 'Grok Build' }
    if (Test-CooperOmpInstalled)  { $hl += 'Oh My Pi (omp)' }
    # pi ditambahkan SEBELUM barisnya dicetak. Sebelumnya ia disisipkan sesudah
    # Write-Host, sehingga header tidak pernah menyebut pi meski jelas terpasang.
    if (Test-CooperPiInstalled)   { $hl += 'Pi Agent (pi)' }
    Write-Host "  harness   : $($hl -join ', ')"

    # Aturan agent OPSIONAL sejak 3 September 2026, jadi keadaannya harus
    # terlihat: dev yang menolaknya perlu tahu ia memang belum terpasang, bukan
    # menduga pemasangannya gagal.
    $RULES_ON = $false
    foreach ($r in @((Join-Path $env:USERPROFILE '.grok\AGENTS.md'),
                     (Join-Path $env:USERPROFILE '.omp\agent\AGENTS.md'),
                     (Join-Path $env:USERPROFILE '.pi\agent\AGENTS.md'))) {
        if (Test-Path $r) { $RULES_ON = $true }
    }
    if ($RULES_ON) {
        Write-Host "  aturan    : terpasang (CooperxHarness AGENTS.md)"
    } else {
        Write-Host "  aturan    : tidak dipasang - Anda memakai aturan sendiri" -ForegroundColor Yellow
    }

    # Kredensial: SELALU ditanyakan ke gateway, tidak pernah disimpulkan dari
    # berkas. Berkas hanya tahu apa yang pernah benar.
    $CRED_OK = $false
    if (-not $CUR_TOKEN) {
        Write-Host "  kredensial: tidak ada token di config" -ForegroundColor Yellow
        Write-Host "              Permintaan ke gateway akan dijawab 401."
    } elseif (-not $CUR_GATEWAY) {
        Write-Host "  kredensial: tidak dapat diperiksa - alamat gateway tidak terbaca" -ForegroundColor Yellow
    } else {
        $chk = Test-CooperCredential $CUR_GATEWAY $CUR_TOKEN
        if ($chk.State -eq 'ok') {
            $CRED_OK = $true
            $peran = if ($chk.Role) { $chk.Role } else { 'dev' }
            Write-Host "  identitas : $($chk.Who) (peran: $peran)"
            Write-Host "  kredensial: sah - diverifikasi ke gateway barusan" -ForegroundColor Green
            $CUR_WHO = $chk.Who
        } else {
            Write-Host "  kredensial: DITOLAK ($($chk.State))" -ForegroundColor Red
            Write-Host ""
            foreach ($l in (Get-CooperCredentialHelp $chk.State $CUR_GATEWAY)) {
                Write-Host "    $l" -ForegroundColor Yellow
            }
        }
    }

    # Kontrak ditampilkan hanya bila benar-benar terambil: angka tebakan yang
    # tampil seperti angka pasti adalah cara repo ini pernah kehilangan waktu.
    if ($CUR_GATEWAY -and (Get-CooperContract (Get-CooperGatewayBase $CUR_GATEWAY))) {
        Write-Host "  kontrak   : context $(Format-CooperNumber $ContractContextWindow) / output $ContractMaxTokens / compact $ContractCompactPct% / model $ContractModelId"
        Save-CooperEndpointCache
    } else {
        Write-Host "  kontrak   : tidak terambil - nilai cadangan yang berlaku" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Apa yang ingin Anda lakukan?" -ForegroundColor Yellow
    # Rekomendasi mengikuti KEADAAN, bukan kebiasaan. Menyarankan "perbarui
    # parameter" kepada dev yang kredensialnya ditolak berarti menyarankan
    # satu-satunya pilihan yang tidak memperbaiki apa pun.
    if ($CRED_OK) {
        Write-Host "  1) Perbarui parameter dari kontrak gateway [disarankan]" -ForegroundColor Green
    } else {
        Write-Host "  1) Perbarui parameter dari kontrak gateway"
    }
    Write-Host "     aturan agent, skill, ambang compaction, context_window"
    Write-Host "  2) Ganti alamat gateway (pindah LAN <-> VPN)"
    if ($CRED_OK) {
        Write-Host "  3) Pasang / ganti token kredensial"
    } else {
        Write-Host "  3) Pasang / ganti token kredensial [disarankan - inilah yang memperbaiki 401]" -ForegroundColor Green
    }
    Write-Host "  4) Pasang harness tambahan (Grok / omp / pi yang belum ada)"
    if ($RULES_ON) {
        Write-Host "  5) Lepas aturan agent CooperxHarness (skill tetap terpasang)"
    } else {
        Write-Host "  5) Pasang aturan agent CooperxHarness"
    }
    Write-Host "  6) Keluar"
    $HOME_CHOICE = Read-Host "Pilihan [1/2/3/4/5/6, default: 1]"
    if ([string]::IsNullOrWhiteSpace($HOME_CHOICE)) { $HOME_CHOICE = '1' }

    switch ($HOME_CHOICE) {
        '2' {
            # Alamat baru diverifikasi SEBELUM ditulis: berpindah ke alamat yang
            # tidak menjawab berarti dev kehilangan gateway yang tadinya bekerja.
            Write-Host ""
            Write-Host "--- Alamat gateway baru ---" -ForegroundColor Cyan
            $known = @(Get-CooperEndpointCache)
            if ($known.Count -gt 0) {
                Write-Host "Yang pernah bekerja di mesin ini:" -ForegroundColor Yellow
                foreach ($e in $known) { Write-Host "    $($e.url)  ($($e.label))" -ForegroundColor Cyan }
            }
            $newEp = Read-Host "Alias (lan/vpn/local) atau alamat lengkap"
            if ([string]::IsNullOrWhiteSpace($newEp)) { Write-Host "Dibatalkan." -ForegroundColor Yellow; exit 0 }
            if ($newEp -match '^https?://') { $newUrl = ConvertTo-CanonicalEndpoint $newEp }
            else {
                $newUrl = Get-CooperEndpointUrl $newEp
                if (-not $newUrl) {
                    $hit = @(Get-CooperEndpointCache) | Where-Object { $_.id -eq $newEp } | Select-Object -First 1
                    if ($hit) { $newUrl = $hit.url }
                }
            }
            if (-not $newUrl) {
                Write-Host "[x] Alias '$newEp' tidak dikenal gateway dan tidak ada di daftar tersimpan." -ForegroundColor Red
                exit 1
            }
            if (-not $CUR_TOKEN) {
                Write-Host "[x] Tidak ada token untuk diverifikasi di alamat baru." -ForegroundColor Red
                Write-Host "    Jalankan pilihan 3 lebih dulu." -ForegroundColor Yellow
                exit 3
            }
            Write-Host "Memverifikasi kredensial di alamat baru..." -ForegroundColor Yellow
            $chk2 = Test-CooperCredential $newUrl $CUR_TOKEN
            if ($chk2.State -ne 'ok') {
                Write-Host "[x] Alamat baru tidak dipakai - kredensial tidak lolos di sana." -ForegroundColor Red
                foreach ($l in (Get-CooperCredentialHelp $chk2.State $newUrl)) { Write-Host "    $l" -ForegroundColor Yellow }
                Write-Host ""
                Write-Host "    Config lama dibiarkan utuh." -ForegroundColor Yellow
                exit 3
            }
            [void](Get-CooperContract (Get-CooperGatewayBase $newUrl))
            Set-CooperAllHarness $newUrl $CUR_TOKEN $chk2.Who
            Save-CooperEndpointCache
            Write-Host ""
            Write-Host "[v] Gateway dipindahkan ke: $newUrl" -ForegroundColor Green
            Write-Host "[v] Identitas: $($chk2.Who)" -ForegroundColor Green
            exit 0
        }
        '3' {
            Write-Host ""
            Write-Host "--- Token CooperAgent ---" -ForegroundColor Cyan
            Write-Host "Minta ke admin bila belum punya: cooper issue <nama> <device>" -ForegroundColor Cyan
            $newTok = (Read-Host "Tempel token baru (ca_...)").Trim()
            if ([string]::IsNullOrWhiteSpace($newTok)) { Write-Host "Dibatalkan." -ForegroundColor Yellow; exit 0 }
            $gwForTok = $CUR_GATEWAY
            if (-not $gwForTok) {
                $gwForTok = (Read-Host "Alamat gateway").Trim()
                if (-not $gwForTok) { Write-Host "[x] Alamat wajib diisi." -ForegroundColor Red; exit 1 }
            }
            $chk3 = Test-CooperCredential $gwForTok $newTok
            if ($chk3.State -ne 'ok') {
                Write-Host "[x] Token tidak lolos pemeriksaan - tidak ada yang ditulis." -ForegroundColor Red
                foreach ($l in (Get-CooperCredentialHelp $chk3.State $gwForTok)) { Write-Host "    $l" -ForegroundColor Yellow }
                exit 3
            }
            [void](Get-CooperContract (Get-CooperGatewayBase $gwForTok))
            Set-CooperAllHarness $gwForTok $newTok $chk3.Who
            Write-Host ""
            Write-Host "[v] Token dipasang ke semua harness." -ForegroundColor Green
            Write-Host "[v] Identitas: $($chk3.Who)" -ForegroundColor Green
            exit 0
        }
        '4' {
            # Jatuh ke onboarding di bawah. Token dan alamat yang sudah ada
            # dibawa serta, jadi dev tidak ditanya ulang.
            Write-Host ""
            Write-Host "Melanjutkan ke pemasangan harness tambahan." -ForegroundColor Cyan
            if (-not $Token) { $Token = $CUR_TOKEN }
            if ($CUR_GATEWAY -and -not $COOPERAGENT_GATEWAY) { $COOPERAGENT_GATEWAY = $CUR_GATEWAY }
        }
        '5' {
            # Aturan agent adalah PENDAPAT tentang cara bekerja; skill adalah
            # perkakas. Melepas yang pertama tidak boleh ikut membawa yang
            # kedua -- dev yang menolak aturan kami tetap berhak atas
            # /cooper-handoff dan /cooper-structure.
            # pi diperlakukan seperti harness lain: aturannya diatur BILA pi
            # terpasang, bukan hanya bila pi satu-satunya. Syarat lama menuntut
            # Grok/omp TIDAK ada, sehingga dev dengan ketiganya tidak punya
            # jalan sama sekali untuk memasang atau melepas aturan pi.
            #
            # Yang dilepas hanya AGENTS.md yang byte-identik dengan template
            # kami; aturan yang sudah disunting dev dibiarkan. models.json,
            # settings.json, server MCP, extension, dan skill milik dev tidak
            # disentuh jalur ini sama sekali.
            $piRulesRc = 0
            if (Test-CooperPiInstalled) {
                $piSetup = Join-Path (Join-Path $SCRIPT_DIR 'scripts') 'setup-pi.ps1'
                if (-not (Test-Path $piSetup)) { throw 'scripts\setup-pi.ps1 tidak ditemukan.' }
                Write-Host ''
                if ($RULES_ON) {
                    & $piSetup -RemoveRules
                } elseif ($CUR_TOKEN) {
                    & $piSetup -Rules -Token $CUR_TOKEN
                } else {
                    & $piSetup -Rules
                }
                $piRulesRc = $LASTEXITCODE
                if ($null -eq $piRulesRc) { $piRulesRc = 0 }
            }
            if (-not (Test-CooperGrokInstalled) -and -not (Test-CooperOmpInstalled)) {
                exit $piRulesRc
            }
            $sd5 = Join-Path (Join-Path $SCRIPT_DIR 'scripts') 'setup-dev.ps1'
            if (-not (Test-Path $sd5)) {
                Write-Host "[x] scripts\setup-dev.ps1 tidak ditemukan." -ForegroundColor Red
                exit 1
            }
            Write-Host ""
            if ($RULES_ON) {
                & $sd5 -RemoveRules
            } else {
                if ($CUR_GATEWAY -and -not $env:COOPERAGENT_GATEWAY) {
                    $env:COOPERAGENT_GATEWAY = $CUR_GATEWAY
                }
                if ($CUR_TOKEN) { & $sd5 -Rules -Token $CUR_TOKEN } else { & $sd5 -Rules }
            }
            exit $piRulesRc
        }
        '6' {
            Write-Host "Tidak ada yang diubah." -ForegroundColor Green
            exit 0
        }
        default {
            # Pilihan 1 dan apa pun yang tidak dikenal: jalur paling aman, yang
            # hanya memperbarui parameter dan tidak menyentuh kredensial.
            if (-not $CRED_OK) {
                Write-Host ""
                Write-Host "[!] Parameter tetap diperbarui, tapi kredensial di atas belum sah -" -ForegroundColor Yellow
                Write-Host "    permintaan ke gateway akan tetap dijawab 401 sampai pilihan 3 dijalankan." -ForegroundColor Yellow
            }
            Write-Host ""
            # pi disegarkan BILA TERPASANG, apa pun harness lain yang ada.
            #
            # Syaratnya dulu menuntut pi terpasang DAN Grok/omp tidak ada,
            # sehingga hanya dev yang memakai pi saja yang terlayani. Dev dengan
            # ketiganya -- keadaan yang paling lazim -- menjalankan "Perbarui
            # parameter" dan pi-nya tidak pernah tersentuh.
            #
            # pi TIDAK dipasang di sini; pilihan ini menyegarkan, bukan menambah.
            $piRefreshRc = 0
            if (Test-CooperPiInstalled) {
                $piSetup = Join-Path (Join-Path $SCRIPT_DIR 'scripts') 'setup-pi.ps1'
                if (-not (Test-Path $piSetup)) { throw 'scripts\setup-pi.ps1 tidak ditemukan.' }
                if ($CUR_TOKEN) { & $piSetup -Token $CUR_TOKEN } else { & $piSetup }
                $piRefreshRc = $LASTEXITCODE
                if ($null -eq $piRefreshRc) { $piRefreshRc = 0 }
            }
            if (-not (Test-CooperGrokInstalled) -and -not (Test-CooperOmpInstalled)) {
                exit $piRefreshRc
            }
            $sd = Join-Path (Join-Path $SCRIPT_DIR 'scripts') 'setup-dev.ps1'
            if (Test-Path $sd) {
                # Alamat DITERUSKAN lewat env. setup-dev membacanya dari config
                # Grok, dan dev yang memilih omp saja tidak punya berkas itu --
                # tanpa ini ia berhenti dengan "tidak ada alamat gateway" pada
                # pilihan yang justru default.
                if ($CUR_GATEWAY -and -not $env:COOPERAGENT_GATEWAY) {
                    $env:COOPERAGENT_GATEWAY = $CUR_GATEWAY
                }
                if ($CUR_TOKEN) { & $sd -Token $CUR_TOKEN } else { & $sd }
            } else {
                Write-Host "[x] scripts\setup-dev.ps1 tidak ditemukan." -ForegroundColor Red
                exit 1
            }
            exit $piRefreshRc
        }
    }
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   [+] CooperAgent Multi-Harness Setup (Windows PowerShell)      " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Pilihan Coding Agent Harness
Write-Host "Pilih Coding Agent yang ingin dipasang/dikonfigurasi:" -ForegroundColor Yellow
Write-Host "  1) Grok Build (Fullscreen Rust TUI, Visual Diff Viewer) [Rekomendasi]"
Write-Host "  2) Oh My Pi / omp (coding agent CLI: 31 tool, LSP, session resume)"
Write-Host "  3) Pi Agent / pi (coding agent CLI ringan: 4 tool inti, hemat token, sesi bercabang)"
Write-Host "  4) Manual - endpoint gateway saja (pakai coding agent Anda sendiri)"
$AGENT_CHOICE = Read-Host "Pilihan [1/2/3/4, default: 1]"
if ([string]::IsNullOrWhiteSpace($AGENT_CHOICE)) { $AGENT_CHOICE = "1" }

# Apa yang sudah terpasang di mesin ini? Ditanyakan SEBELUM prompt lain, karena
# jawabannya menentukan pertanyaan mana yang tidak perlu diajukan sama sekali.
$CONFIG_MODE = "fresh"
$KEEP_IDENTITY = ""
$KEEP_ENDPOINT = ""
if ($AGENT_CHOICE -eq "1") {
    if (Get-Command "grok" -ErrorAction SilentlyContinue) {
        Write-Host "[v] Grok CLI sudah terpasang di sistem." -ForegroundColor Green
    } else {
        Write-Host "Grok CLI belum terpasang - akan diunduh pada langkah pemasangan." -ForegroundColor Yellow
    }
    Show-ConfigModePrompt
}

# 2. Token kredensial (identitas berasal dari sini)
#
# DITANYAKAN bila tidak diberikan lewat -Token. Sampai 1 September 2026 skrip
# ini diam saja dan menulis `dev-<nama>@<device>` -- config yang PASTI dijawab
# 401, dan dev baru mengetahuinya saat mencoba bekerja. Prompt yang bertanya
# lebih baik daripada berkas yang berbohong.
if (-not $Token) {
    # Token yang sudah ada dipertahankan tanpa bertanya: menjalankan ulang
    # setup untuk memperbarui parameter tidak boleh menuntut token ditempel
    # ulang.
    $cfgTok = Get-GrokConfigPath
    $existingTok = ""
    if (Test-Path $cfgTok) {
        $mk = Get-Content $cfgTok | Where-Object { $_ -match "^\s*api_key\s*=\s*['`"](ca_[a-f0-9]+)['`"]" } | Select-Object -First 1
        if ($mk -match "(ca_[a-f0-9]+)") { $existingTok = $Matches[1] }
    }
    if ($AGENT_CHOICE -eq '3' -and -not $existingTok) {
        $existingTok = Get-PiStoredKey $PI_MODELS_PATH
    }
    if ($existingTok) {
        $Token = $existingTok
        Write-Host ""
        Write-Host "[v] Token dipertahankan dari config: ...$($Token.Substring($Token.Length-4))" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "--- Token CooperAgent ---" -ForegroundColor Cyan
        Write-Host "Gateway menuntut token, dan identitas Anda berasal dari sana -"
        Write-Host "nama serta perangkat tidak perlu diketik bila token diberikan."
        Write-Host "Minta ke admin bila belum punya:"
        Write-Host "  cooper issue <nama-anda> <nama-perangkat>" -ForegroundColor Cyan
        $Token = (Read-Host "Tempel token (ca_...), atau Enter untuk melewati").Trim()
    }
}

if ($Token) {
    if (-not $Token.StartsWith('ca_')) {
        Write-Host "[x] Token harus diawali 'ca_'." -ForegroundColor Red; exit 2
    }
    if ($Token.Length -ne 51) {
        Write-Host "[x] Token harus 51 karakter (ca_ + 48 hex); yang ditempel $($Token.Length)." -ForegroundColor Red
        Write-Host "    Kemungkinan terpotong saat disalin - minta ulang ke admin." -ForegroundColor Yellow
        exit 2
    }
} else {
    # Dilewati dengan sadar. Pemasangan agent tetap berguna; yang tidak akan
    # bekerja adalah permintaan ke gateway, dan itu dikatakan sekarang.
    Write-Host "[!] Tanpa token, config yang ditulis AKAN DITOLAK gateway (401)." -ForegroundColor Yellow
    Write-Host "    Agent tetap dipasang. Tambahkan tokennya nanti dengan:"
    Write-Host "      .\scripts\setup-dev.ps1 -Token ca_..." -ForegroundColor Cyan
}


if ($AGENT_CHOICE -eq '3' -and -not $Token) {
    Write-Host '[x] Pilihan pi membutuhkan token ca_... yang dapat diverifikasi.' -ForegroundColor Red
    exit 3
}
# 3. Alamat gateway — DITENTUKAN SEBELUM identitas
#
# Urutannya penting. Probe /api/auth/whoami di bawah membutuhkan alamat, dan
# sampai 2 September 2026 ia diam-diam bersandar pada alamat LAN yang dipatok.
# Begitu patokan itu dilepas, probe pada pemasangan BARU tidak punya apa pun
# untuk ditanya, dan dev kembali diminta mengetik nama serta perangkat.

if (-not [string]::IsNullOrWhiteSpace($KEEP_ENDPOINT)) {
    $SERVER_URL = $KEEP_ENDPOINT
    Write-Host ""
    Write-Host "[v] Endpoint dipertahankan: $SERVER_URL" -ForegroundColor Green
    Write-Host "    Untuk memindahkannya nanti: .\setup.ps1 -Endpoint vpn|lan|local" -ForegroundColor Yellow
} elseif (-not [string]::IsNullOrWhiteSpace($COOPERAGENT_GATEWAY)) {
    $SERVER_URL = ConvertTo-CanonicalEndpoint $COOPERAGENT_GATEWAY
    Write-Host ""
    Write-Host "[v] Endpoint dari `$env:COOPERAGENT_GATEWAY: $SERVER_URL" -ForegroundColor Green
} else {
    # DITANYAKAN, bukan ditawarkan dari daftar. Menu lama memuat alamat internal,
    # dan itu yang menghalangi skrip ini pindah ke repo pemasang yang publik.
    # Alamatnya sudah ada di tangan dev: `cooper issue` mencetaknya bersama token.
    Write-Host ""
    Write-Host "--- Alamat CooperAgent Gateway ---" -ForegroundColor Cyan
    Write-Host "Ada di blok serah-terima yang Anda terima bersama token."
    Write-Host "Bentuknya: http://<host>:8987/api/v1" -ForegroundColor Yellow
    $known = @(Get-CooperEndpointCache)
    if ($known.Count -gt 0) {
        Write-Host ""
        Write-Host "Yang pernah bekerja di mesin ini:" -ForegroundColor Yellow
        foreach ($e in $known) { Write-Host "  $($e.url)  ($($e.label))" -ForegroundColor Cyan }
        Write-Host ""
    }
    $custom = Read-Host "Tempel alamat gateway"
    if ([string]::IsNullOrWhiteSpace($custom)) {
        Write-Host "[x] Alamat gateway wajib diisi." -ForegroundColor Red
        Write-Host "    Minta ke admin bila tidak menemukannya: cooper issue <nama> <device>" -ForegroundColor Yellow
        exit 1
    }
    $SERVER_URL = ConvertTo-CanonicalEndpoint $custom
}

# 2b. GERBANG KREDENSIAL — diperiksa SEBELUM satu berkas pun ditulis
#
# Gateway mencatat identitas dari TOKEN (`cred.devName`, `cred.device`), bukan
# dari config klien, jadi pemeriksaan ini sekaligus menjawab "siapa Anda".
#
# Sampai 3 September 2026 kegagalan di sini ditelan `catch {}` KOSONG: gateway
# tak terjangkau, token tidak dikenal, dan kredensial dicabut sama-sama jatuh
# diam-diam ke prompt nama manual di bawah, lalu setup berjalan sampai akhir dan
# menulis config yang pasti dijawab 401. Sekarang ia berhenti, dengan sebabnya.
$DEV_IDENTITY = ""
if ($Token) {
    Write-Host ""
    Write-Host "--- Verifikasi kredensial ---" -ForegroundColor Cyan
    Write-Host "  gateway : $(Get-CooperGatewayBase $SERVER_URL)"
    Write-Host "  token   : ...$($Token.Substring($Token.Length-4))"
    $chk = Test-CooperCredential $SERVER_URL $Token
    if ($chk.State -eq 'ok') {
        $DEV_IDENTITY = $chk.Who
        $peran = if ($chk.Role) { $chk.Role } else { 'dev' }
        Write-Host "[v] Kredensial sah - identitas: $DEV_IDENTITY (peran: $peran)" -ForegroundColor Green
        Write-Host "    Inilah yang tercatat di dashboard - tidak perlu diketik." -ForegroundColor Yellow
    } else {
        Write-Host "[x] Kredensial tidak lolos pemeriksaan." -ForegroundColor Red
        foreach ($l in (Get-CooperCredentialHelp $chk.State $SERVER_URL)) {
            Write-Host "    $l" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "    Tidak ada satu berkas pun yang ditulis." -ForegroundColor Yellow
        exit 3
    }
}


# 2c. Identitas manual — hanya bila token tidak ada atau gateway tak terjangkau
if (-not $DEV_IDENTITY) {
    if (-not [string]::IsNullOrWhiteSpace($KEEP_IDENTITY)) {
        $DEV_IDENTITY = $KEEP_IDENTITY
        Write-Host ""
        Write-Host "[v] Identitas dipertahankan: $DEV_IDENTITY" -ForegroundColor Green
    } else {
    Write-Host ""
    Write-Host "--- Identitas Developer (CooperxTelemetry) ---" -ForegroundColor Cyan
    $DEV_NAME = Read-Host "Masukkan nama/nickname Anda (contoh: lee, alex, budi, vincent) [default: dev-user]"
    if ([string]::IsNullOrWhiteSpace($DEV_NAME)) {
        $DEV_NAME = "dev-user"
    }
    $DEV_NAME = $DEV_NAME.Trim().ToLower() -replace "[^a-zA-Z0-9_-]", ""
    if ([string]::IsNullOrWhiteSpace($DEV_NAME)) { $DEV_NAME = "dev-user" }

    # Device dipakai sebagai kunci pengelompokan di leaderboard. Tanpa ini identitas
    # hanya bersandar pada IP -- dan IP DHCP yang berubah memecah satu orang menjadi
    # beberapa baris terpisah di dashboard.
    $DEFAULT_DEVICE = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($DEFAULT_DEVICE)) { $DEFAULT_DEVICE = "device" }
    $DEFAULT_DEVICE = $DEFAULT_DEVICE.Trim().ToLower() -replace "[^a-zA-Z0-9_-]", ""
    if ([string]::IsNullOrWhiteSpace($DEFAULT_DEVICE)) { $DEFAULT_DEVICE = "device" }

    Write-Host "Nama device memisahkan pemakaian antar perangkat Anda (laptop vs PC)." -ForegroundColor Yellow
    $DEV_DEVICE = Read-Host "Masukkan nama device (contoh: laptop-tuf, pc-kantor) [default: $DEFAULT_DEVICE]"
    if ([string]::IsNullOrWhiteSpace($DEV_DEVICE)) { $DEV_DEVICE = $DEFAULT_DEVICE }
    $DEV_DEVICE = $DEV_DEVICE.Trim().ToLower() -replace "[^a-zA-Z0-9_-]", ""
    if ([string]::IsNullOrWhiteSpace($DEV_DEVICE)) { $DEV_DEVICE = $DEFAULT_DEVICE }

    # Format `nama@device` inilah yang dibaca gateway sebagai identitas.
    $DEV_IDENTITY = "$DEV_NAME@$DEV_DEVICE"
    Write-Host "[v] Identitas tersimpan: $DEV_IDENTITY" -ForegroundColor Green
    }

}

# 4. Test Koneksi ke Server (Health Check)
$BASE_HOST = $SERVER_URL -replace "/api/v1.*$", "" -replace "/v1.*$", ""
$HEALTH_URL = "$BASE_HOST/api/health"
Write-Host ""
Write-Host "Menguji koneksi ke CooperAgent Gateway: $HEALTH_URL..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri $HEALTH_URL -TimeoutSec 5 -ErrorAction Stop
    if ($response.status -eq "ok" -or "$response" -match "ok") {
        Write-Host "[v] Koneksi Berhasil! CooperAgent Gateway & GPU Backend aktif & sehat." -ForegroundColor Green
    } else {
        Write-Host "[v] Terhubung ke Gateway." -ForegroundColor Green
    }

    # SELURUH kontrak ditanyakan, bukan ditebak: nama model, context_window,
    # max_tokens, dan ambang compaction sekaligus. Sampai 1 September 2026
    # ketiganya yang terakhir dipatok di skrip ini, jadi ketika --ctx-size
    # server berubah tidak ada satu pun config dev yang tahu.
    if (Get-CooperContract $BASE_HOST) {
        if ($ContractModelId -ne $DEFAULT_MODEL_NAME) {
            Write-Host "    Model yang disajikan gateway: $ContractModelId (bukan $DEFAULT_MODEL_NAME)" -ForegroundColor Yellow
        }
        $DEFAULT_MODEL_NAME = $ContractModelId
        Write-Host "[v] Kontrak diambil: context $(Format-CooperNumber $ContractContextWindow) / output $ContractMaxTokens / compact $ContractCompactPct%" -ForegroundColor Green
        # Disimpan di mesin dev supaya -Endpoint vpn tetap bisa dijawab nanti
        # ketika gateway justru sedang TIDAK terjangkau.
        Save-CooperEndpointCache
        if ($ContractEndpoints.Count -gt 0) {
            Write-Host "    Alamat lain yang diumumkan gateway:" -ForegroundColor Yellow
            foreach ($e in $ContractEndpoints) {
                Write-Host "      .\setup.ps1 -Endpoint $($e.id)  ->  $($e.url)  ($($e.label))" -ForegroundColor Cyan
            }
        }
        if ($ContractUpstreamSource -eq 'env-fallback') {
            Write-Host "    Catatan: gateway memakai nilai env - tidak ada slot upstream sehat saat ditanya." -ForegroundColor Yellow
        }
    } else {
        # Gateway sehat tapi kontraknya tidak terurai berarti bentuk /v1/models
        # berubah. Itu harus TERLIHAT. Jatuh diam-diam ke angka cadangan adalah
        # cara sebuah config menjadi salah tanpa seorang pun tahu kapan.
        Write-Host "[!] Kontrak tidak terbaca dari $BASE_HOST/v1/models - memakai nilai cadangan." -ForegroundColor Yellow
    }
} catch {
    Write-Host "[!] Peringatan: Tidak dapat terhubung ke $HEALTH_URL." -ForegroundColor Red
    # Alamat alternatif datang dari kontrak yang PERNAH berhasil di mesin ini,
    # bukan dari tabel di skrip.
    $known = @(Get-CooperEndpointCache)
    if ($known.Count -gt 0) {
        Write-Host "Bila Anda sedang di jaringan lain, coba yang pernah bekerja di mesin ini:" -ForegroundColor Yellow
        foreach ($e in $known) { Write-Host "  .\setup.ps1 -Endpoint $($e.id)  ->  $($e.url)  ($($e.label))" -ForegroundColor Cyan }
    } else {
        Write-Host "Alamat lain ada di blok serah-terima bersama token Anda." -ForegroundColor Yellow
    }
    Write-Host "Pastikan Anda terhubung ke Wi-Fi kantor / VPN dan server AI sedang aktif." -ForegroundColor Yellow
}

# 4b. Mode manual: endpoint saja, tidak memasang agent apa pun
#
# Gateway ini endpoint OpenAI-compatible biasa. Dev yang sudah punya coding
# agent pilihannya tidak perlu dipaksa memakai punya kita.
if ($AGENT_CHOICE -eq "4") {
    $gw = $SERVER_URL -replace '/api/v1$', ''
    # Yang dicetak harus yang BENAR-BENAR dipakai; identitas lama ditolak 401.
    $showKey = if ($Token) { $Token } else { "<minta token ke admin: cooper issue $DEV_IDENTITY>" }
    Write-Host ""
    Write-Host "--- Endpoint CooperAgent untuk coding agent Anda ---" -ForegroundColor Cyan
    $ctxFmt  = Format-CooperNumber $ContractContextWindow
    $compFmt = Format-CooperNumber $ContractCompactTokens
    $note    = Get-CooperContractNote
    Write-Host @"

  Base URL (OpenAI-compatible)   $gw/v1
  API key                        $showKey
  Model                          $DEFAULT_MODEL_NAME
  Context window                 $ContractContextWindow      (prompt DAN jawaban, plafon keras)
  Max output                     $ContractMaxTokens
  Ambang compact yang disarankan $ContractCompactPct%         = $compFmt token
  Sumber angka di atas           $note

  `$env:OPENAI_BASE_URL = "$gw/v1"
  `$env:OPENAI_API_KEY  = "$showKey"
  `$env:OPENAI_MODEL    = "$DEFAULT_MODEL_NAME"

Yang perlu diketahui:
  - api_key HARUS token CooperAgent (ca_...); identitas lama ditolak 401.
  - Auto-compaction adalah fitur KLIEN. Alat tanpa itu akan tumbuh sampai
    menabrak $ctxFmt lalu terpotong. Setel ambangnya sendiri di $ContractCompactPct%.
  - Ringkasan/compaction dari alat lain berjalan dengan reasoning penuh.
    Kirim "reasoning_effort":"none" pada request ringkasan.
  - Header X-Upstream pada respons menyebut server mana yang menjawab.

  Cetak ulang kapan saja: .\setup.ps1 -Info
"@

    # Opsional: dev mungkin sudah punya aturannya sendiri, dan menimpanya tanpa
    # bertanya adalah kesalahan.
    Write-Host ""
    $copyRules = Read-Host "Salin aturan kerja CooperAgent ke sebuah proyek? [y/N]"
    if ($copyRules -match '^[Yy]') {
        $rulesDir = Read-Host "Path proyek [default: direktori saat ini]"
        if ([string]::IsNullOrWhiteSpace($rulesDir)) { $rulesDir = (Get-Location).Path }
        if (-not (Test-Path $rulesDir)) {
            Write-Host "[x] Direktori tidak ada: $rulesDir" -ForegroundColor Red
        } else {
            $src  = Join-Path $SCRIPT_DIR "templates\agent-rules.md"
            $dest = Join-Path $rulesDir "AGENTS.md"
            if (Test-Path $dest) {
                Copy-Item $dest "$dest.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Invoke-CooperBakPrune $dest
                Write-Host "AGENTS.md sudah ada - dicadangkan." -ForegroundColor Yellow
            }
            # Hanya bagian sesudah penanda INTI: header template menjelaskan cara
            # memasangnya, dan itu tidak berguna di dalam proyek dev.
            Copy-Item $src $dest -Force
            Write-Host "[v] Aturan tersalin: $dest" -ForegroundColor Green
            Write-Host "    Dibaca otomatis oleh Oh My Pi, Grok, Cursor, Claude Code, dan Cline." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "Selesai. Tidak ada agent yang dipasang - sesuai pilihan Anda." -ForegroundColor Green
    exit 0
}

# 5. Instalasi & Konfigurasi Grok Build (jika opsi 1 atau 3)
if ($AGENT_CHOICE -eq "1") {
    Write-Host ""
    Write-Host "--- Mengonfigurasi Grok Build (Rust TUI) ---" -ForegroundColor Cyan
    if (Get-Command "grok" -ErrorAction SilentlyContinue) {
        Write-Host "[v] Grok CLI terdeteksi di sistem." -ForegroundColor Green
    } else {
        Write-Host "Mengunduh installer resmi xAI Grok untuk Windows..." -ForegroundColor Yellow
        try {
            Invoke-Expression (Invoke-RestMethod "https://x.ai/cli/install.ps1")
            $env:PATH += ";$($env:USERPROFILE)\.grok\bin;$($env:LOCALAPPDATA)\Programs\grok\bin"
        } catch {
            Write-Host "[!] Gagal mengunduh installer otomatis. Silakan pasang Grok CLI manual jika diperlukan." -ForegroundColor Red
        }
    }

    Write-GrokConfig $SERVER_URL $DEV_IDENTITY $CONFIG_MODE
}

# 6. Konfigurasi Oh My Pi (omp) (jika opsi 2 atau 3)
#
# Menggantikan Pi Agent (2026-08-29). Yang lama adalah klien chat ~120 baris
# buatan sendiri tanpa tool, tanpa edit berkas, tanpa memory. omp adalah coding
# agent sungguhan, dan ia menemukan AGENTS.md sendiri sehingga aturan kerja kita
# sampai tanpa mekanisme tambahan.
if ($AGENT_CHOICE -eq "2") {
    Write-Host ""
    Write-Host "--- Mengonfigurasi Oh My Pi (omp) ---" -ForegroundColor Cyan

    if (Get-Command "omp" -ErrorAction SilentlyContinue) {
        Write-Host "[v] omp sudah terpasang." -ForegroundColor Green
    } else {
        Write-Host "Memasang omp (biner siap pakai, tidak butuh Bun)..." -ForegroundColor Yellow
        # `-Binary` memakai biner siap pakai dan MELEWATI Bun sepenuhnya.
        #
        # Bentuk `irm | iex` yang polos memilih jalur source bila Bun terpasang,
        # lalu MENOLAK bila versinya di bawah 1.3.14 -- terjadi 29 Agustus 2026
        # pada Bun 1.3.13, beda satu patch. Pemasangan tidak boleh gagal karena
        # runtime yang bahkan tidak kita butuhkan.
        try {
            & ([scriptblock]::Create((Invoke-RestMethod https://omp.sh/install.ps1))) -Binary
        } catch {
            # Pesan aslinya DITAMPILKAN, tidak ditelan. Versi pertama skrip ini
            # hanya berkata "gagal" tanpa sebab, sehingga dev tidak tahu apakah
            # masalahnya jaringan, proxy, atau ExecutionPolicy.
            Write-Host "[x] Pemasangan omp gagal: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    Coba salah satu:" -ForegroundColor Yellow
            Write-Host "      & ([scriptblock]::Create((irm https://omp.sh/install.ps1))) -Binary"
            Write-Host "      bun install -g @oh-my-pi/pi-coding-agent    (bila Bun sudah ada)"
            Write-Host "      https://github.com/can1357/oh-my-pi         (unduh rilis)"
        }
    }

    # Installer menambahkan PATH ke registry, bukan ke sesi yang sedang jalan --
    # ia sendiri berkata "Restart your terminal". Tanpa baris ini, sisa skrip di
    # bawah tidak menemukan `omp` dan diam-diam MELEWATI penyetelan ambang
    # compaction. Terjadi 29 Agustus 2026: dev memasang omp dengan sukses tetapi
    # ambang 80% tidak pernah tersetel, dan tidak ada pesan apa pun.
    $ompDir = if ($env:PI_INSTALL_DIR) { $env:PI_INSTALL_DIR } else { "$env:LOCALAPPDATA\omp" }
    if ((Test-Path $ompDir) -and ($env:Path -notlike "*$ompDir*")) {
        $env:Path = "$ompDir;$env:Path"
    }

    $OMP_AGENT_DIR = Join-Path (Join-Path $env:USERPROFILE ".omp") "agent"
    if (-not (Test-Path $OMP_AGENT_DIR)) {
        New-Item -ItemType Directory -Path $OMP_AGENT_DIR -Force | Out-Null
    }

    # Dirender dari templates/omp-models.yml -- satu sumber, sama seperti
    # config.toml milik Grok.
    #
    # Bila berkasnya SUDAH ADA, dev ditanya lebih dulu -- sejajar dengan
    # perlakuan config.toml pada opsi 1. Sampai 30 Agustus 2026 blok ini
    # menimpanya diam-diam, padahal omp mendukung 60+ provider dan dev bisa
    # menambahkan miliknya sendiri di sana.
    #
    # Join-Path bertingkat, bukan tiga argumen: bentuk tiga argumen baru ada di
    # PowerShell 6, sedangkan skrip ini menyatakan #Requires -Version 5.1.
    $MODELS_YML = Join-Path $OMP_AGENT_DIR "models.yml"
    $ompTpl = Join-Path (Join-Path $SCRIPT_DIR 'templates') 'omp-models.yml'
    $ompGw  = $SERVER_URL -replace '/api/v1$', ''
    $utf8NoBomOmp = New-Object System.Text.UTF8Encoding($false)

    # Kunci dari TOKEN, bukan dari "dev-$DEV_IDENTITY".
    #
    # Sampai 3 September 2026 kedua baris render di bawah menulis
    # `dev-nama@device` tanpa syarat -- bentuk yang gateway jawab 401 sejak
    # 1 September. Jalur Grok (Write-GrokConfig) sudah benar sejak awal, jadi
    # gejalanya khas: `grok` jalan, `omp` 401, dan token yang sama berhasil
    # login di dashboard.
    $ompApiKey = Get-OmpApiKey $DEV_IDENTITY $Token

    if (-not (Test-Path $ompTpl)) {
        Write-Host "[x] Template tidak ditemukan: $ompTpl" -ForegroundColor Red
    } elseif (-not (Test-Path $MODELS_YML)) {
        $yml = (Expand-CooperTemplate (Get-Content -Raw $ompTpl)).Replace('__GATEWAY__', $ompGw).Replace('__API_KEY__', $ompApiKey)
        if (-not (Assert-CooperRendered $yml 'models.yml')) { exit 1 }
        [System.IO.File]::WriteAllText($MODELS_YML, $yml, $utf8NoBomOmp)
        Write-Host "[v] models.yml dibuat (3 provider: otomatis, localhost, server 2)" -ForegroundColor Green
    } else {
        $lines = Get-Content $MODELS_YML
        $first = $lines | Where-Object { $_ -match '^\s+baseUrl:' } | Select-Object -First 1
        $curGw = if ($first -match 'baseUrl:\s*(https?://[^/]*)') { $Matches[1] } else { '' }
        $nProv = @($lines | Where-Object { $_ -match '^  [a-z0-9-]+:' }).Count

        Write-Host ""
        Write-Host "--- models.yml omp sudah ada ---" -ForegroundColor Cyan
        Write-Host "  berkas   : $MODELS_YML"
        Write-Host "  endpoint : $(if ($curGw) { $curGw } else { '(tidak terbaca)' })"
        Write-Host "  provider : $nProv terdaftar"
        Write-Host "Bagaimana Anda ingin memperbarui?" -ForegroundColor Yellow
        Write-Host "  1) Pertahankan apa adanya [disarankan]" -ForegroundColor Green
        Write-Host "  2) Ganti alamat gateway saja, provider Anda dipertahankan"
        Write-Host "  3) Tulis ulang penuh dari template (provider tambahan Anda AKAN HILANG)" -ForegroundColor Red
        $ompMode = Read-Host "Pilihan [1/2/3, default: 1]"
        if ([string]::IsNullOrWhiteSpace($ompMode)) { $ompMode = "1" }
        $stampOmp = Get-Date -Format 'yyyyMMdd-HHmmss'

        switch ($ompMode) {
            "2" {
                if ($curGw) {
                    Copy-Item $MODELS_YML "$MODELS_YML.bak.$stampOmp"
                    Invoke-CooperBakPrune $MODELS_YML
                    # HANYA baris yang menunjuk gateway LAMA. Mengganti setiap
                    # baseUrl akan menyeret provider pihak ketiga milik dev
                    # (Anthropic, Ollama) ke gateway kita.
                    $esc = [regex]::Escape($curGw)
                    $out = $lines | ForEach-Object {
                        if ($_ -match '127\.0\.0\.1') { $_ }
                        else { $_ -replace "baseUrl:\s*$esc", "baseUrl: $ompGw" }
                    }
                    [System.IO.File]::WriteAllText($MODELS_YML, ($out -join "`r`n") + "`r`n", $utf8NoBomOmp)
                    Write-Host "[v] Alamat gateway diganti $curGw -> $ompGw (cadangan dibuat)" -ForegroundColor Green
                } else {
                    Write-Host "[!] Alamat lama tidak terbaca - tidak ada yang diubah." -ForegroundColor Yellow
                }
            }
            "3" {
                Copy-Item $MODELS_YML "$MODELS_YML.bak.$stampOmp"
                Invoke-CooperBakPrune $MODELS_YML
                $yml = (Expand-CooperTemplate (Get-Content -Raw $ompTpl)).Replace('__GATEWAY__', $ompGw).Replace('__API_KEY__', $ompApiKey)
                if (-not (Assert-CooperRendered $yml 'models.yml')) { exit 1 }
                [System.IO.File]::WriteAllText($MODELS_YML, $yml, $utf8NoBomOmp)
                Write-Host "[v] models.yml ditulis ulang dari template (cadangan dibuat)" -ForegroundColor Green
            }
            default { Write-Host "[v] models.yml dipertahankan - tidak ada yang disentuh." -ForegroundColor Green }
        }

        # apiKey DIPERBARUI apa pun pilihan di atas. Pilihan 1-3 mengatur
        # provider dan alamat -- itu memang milik dev. apiKey bukan: ia
        # kredensial terbitan admin, dan models.yml yang tertinggal berarti
        # `omp` 401 sementara `grok` jalan normal. Yang disentuh hanya provider
        # yang menunjuk gateway kita; kunci berbayar dev tidak ikut.
        if ($Token -and -not ((Get-Content $MODELS_YML) -match "apiKey:\s*$([regex]::Escape($ompApiKey))")) {
            # Cadangan hanya bila pilihan 2/3 belum membuatnya: menyalin lagi
            # dengan stempel yang sama akan MENIMPA cadangan asli dengan berkas
            # yang sudah diubah -- cadangan yang tidak mencadangkan apa pun.
            if (-not (Test-Path "$MODELS_YML.bak.$stampOmp")) {
                Copy-Item $MODELS_YML "$MODELS_YML.bak.$stampOmp"
            }
            $done = Set-OmpApiKey $MODELS_YML $ompApiKey $ompGw
            if ($done -and ((Get-Content $MODELS_YML) -match "apiKey:\s*$([regex]::Escape($ompApiKey))")) {
                Write-Host "[v] apiKey diperbarui ke token (cadangan dibuat)" -ForegroundColor Green
            } else {
                Write-Host "[!] Gagal memperbarui apiKey di $MODELS_YML - sunting manual." -ForegroundColor Yellow
            }
        }
    }

    Write-Host "    Pilih modelnya saat pertama menjalankan 'omp', atau set di ~/.omp/agent/config.yml" -ForegroundColor Yellow
}

# 6a. Konfigurasi pi (jalur tambahan, tidak memanggil Grok/omp)
if ($AGENT_CHOICE -eq '3') {
    Write-Host ''
    Write-Host '--- Memasang dan mengonfigurasi Pi Agent ---' -ForegroundColor Cyan
    $piCommand = Get-Command pi -ErrorAction SilentlyContinue
    if ($null -eq $piCommand) {
        $npmCommand = Get-Command npm -ErrorAction SilentlyContinue
        if ($null -eq $npmCommand) {
            Write-Host '[x] npm tidak ditemukan - pi tidak dipasang.' -ForegroundColor Red
            exit 1
        }
        Write-Host 'Memasang pi dari npm (@earendil-works/pi-coding-agent)...' -ForegroundColor Yellow
        & $npmCommand.Source install -g '@earendil-works/pi-coding-agent'
        if ($LASTEXITCODE -ne 0) { Write-Host '[x] Pemasangan pi gagal.' -ForegroundColor Red; exit 1 }
        $piCommand = Get-Command pi -ErrorAction SilentlyContinue
    }
    if ($null -eq $piCommand) { Write-Host '[x] Biner pi tidak ditemukan setelah pemasangan.' -ForegroundColor Red; exit 1 }
    $setupPi = Join-Path (Join-Path $SCRIPT_DIR 'scripts') 'setup-pi.ps1'
    if (-not (Test-Path $setupPi)) { Write-Host '[x] scripts\setup-pi.ps1 tidak ditemukan.' -ForegroundColor Red; exit 1 }
    & $setupPi -Endpoint $SERVER_URL -Token $Token -Rules
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# 6b. Aturan agent, skill, dan penyetelan omp
#
# DIDELEGASIKAN ke scripts/setup-dev.ps1, tidak disalin. Skrip itu sudah
# memasang AGENTS.md untuk Grok dan omp, menyalin skill, menyetel
# skills.customDirectories dan ambang compaction, lalu memverifikasi hasilnya.
# Dua salinan yang harus dijaga sinkron dengan tangan adalah kelas kegagalan
# yang sudah berkali-kali menggigit repo ini.
$setupDev = Join-Path (Join-Path $SCRIPT_DIR 'scripts') 'setup-dev.ps1'
if (($AGENT_CHOICE -ne '3') -and (Test-Path $setupDev)) {
    Write-Host ""
    Write-Host "--- Aturan agent, skill, dan penyetelan omp ---" -ForegroundColor Cyan
    try {
        if ($Token) { & $setupDev -Token $Token } else { & $setupDev }
    } catch {
        Write-Host "[!] setup-dev gagal: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 7. Pasang Git Hooks Otomatis (jika git diinisialisasi)
if (Test-Path (Join-Path $SCRIPT_DIR ".git")) {
    $hooksPath = (Join-Path $SCRIPT_DIR "scripts/hooks").Replace("\", "/")
    git config core.hooksPath "$hooksPath" 2>$null
    Write-Host "[v] Git pre-commit secret protection hooks diaktifkan." -ForegroundColor Green
}

# 8. Direktori bin pengguna


Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "[+] Setup Selesai! Selamat datang di CooperAgent (Windows)!" -ForegroundColor Green
Write-Host "  - Menjalankan Grok:      Ketik 'grok' di PowerShell folder project Anda."
Write-Host "  - Menjalankan Oh My Pi:  Ketik 'omp' -- BUKA TERMINAL BARU dulu bila baru dipasang."
if ($AGENT_CHOICE -eq '3') {
    Write-Host "  - Menjalankan Pi Agent:  Ketik 'pi' di PowerShell folder project Anda."
}
Write-Host "  - Checkpoint sesi:       .cooper/context/ di proyek Anda; /cooper-handoff saat context penuh."
Write-Host "  - Pantau Dashboard:      Buka $($SERVER_URL -replace '/api/v1$','')/"
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
