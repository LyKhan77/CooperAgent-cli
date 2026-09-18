# Kunci API pada `~\.omp\agent\models.yml` — sumber tunggal.
#
# KENAPA PUSTAKA, BUKAN DISALIN. Sampai 3 September 2026 logika ini hidup HANYA
# di `scripts/setup-dev.ps1`, sementara `setup.ps1` merender models.yml dengan
# `dev-$DEV_IDENTITY` tanpa syarat — bentuk lama yang dijawab 401 oleh gateway
# sejak penegakan menyala 1 September 2026. Dev yang memilih "omp saja" tidak
# pernah punya `~\.grok\config.toml`, sehingga setup-dev berhenti lebih awal dan
# tidak ada satu pun jalur yang membetulkannya: `omp` 401 sementara token yang
# sama berhasil login di dashboard.

# Kunci yang HARUS masuk ke models.yml. Token menang; identitas `nama@device`
# hanya jalur mundur untuk gateway yang belum menegakkan kredensial.
#
# Cabang `ca_*` ada karena `-Endpoint vpn` meneruskan api_key lama sebagai
# identitas: tanpa itu hasilnya `dev-ca_...`, token yang tidak pernah cocok.
function Get-OmpApiKey([string]$Identity, [string]$Token) {
    if ($Token) { return $Token }
    if ($Identity -like 'ca_*') { return $Identity }
    return "dev-$Identity"
}

# Menulis ulang `apiKey:` HANYA pada provider yang menunjuk gateway kita.
#
# -replace polos mengganti SETIAP apiKey — termasuk milik Anthropic, OpenAI,
# atau Ollama yang ditambahkan dev sendiri. omp mendukung 60+ provider, dan
# menimpa kunci berbayar mereka jauh lebih mahal daripada masalah yang sedang
# diperbaiki. Blok dibuffer, dan apiKey hanya diganti bila blok itu memuat
# baseUrl yang menunjuk gateway.
function Set-OmpApiKey([string]$Path, [string]$Key, [string]$Gateway) {
    if (-not (Test-Path $Path)) { return $false }
    $out = New-Object System.Collections.Generic.List[string]
    $buf = New-Object System.Collections.Generic.List[string]
    $mine = $false
    foreach ($l in (Get-Content $Path)) {
        if ($l -match '^  [A-Za-z0-9_-]+:\s*$') {
            foreach ($b in $buf) {
                if ($mine -and $b -match '^(\s*)apiKey:') { $out.Add("$($Matches[1])apiKey: $Key") }
                else { $out.Add($b) }
            }
            $buf.Clear(); $mine = $false
            $buf.Add($l); continue
        }
        if ($buf.Count -eq 0) { $out.Add($l); continue }
        if ($l -match 'baseUrl:' -and ($l -like "*$Gateway*" -or $l -like '*127.0.0.1*')) { $mine = $true }
        $buf.Add($l)
    }
    foreach ($b in $buf) {
        if ($mine -and $b -match '^(\s*)apiKey:') { $out.Add("$($Matches[1])apiKey: $Key") }
        else { $out.Add($b) }
    }
    [System.IO.File]::WriteAllText($Path, ($out -join "`r`n") + "`r`n",
        (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

# ── pembacaan ────────────────────────────────────────────────────────────────
# Dipakai mode "sudah terpasang": dev yang memilih omp saja tidak punya
# `~\.grok\config.toml`, jadi satu-satunya tempat alamat dan kredensialnya
# tercatat adalah berkas ini.
#
# Provider dikenali dari NAMANYA, bukan dari bentuk alamatnya. Menebak dari
# alamat akan salah menyebut Ollama milik dev (`http://localhost:11434`) sebagai
# provider kita, dan yang terbaca lalu dilaporkan sebagai "kredensial Anda"
# adalah kunci orang lain.
#
# Nama yang dikenali ada di SATU tempat, dan itu penting: sampai 17 September
# 2026 polanya ditulis tiga kali dengan dua ejaan berbeda -- dua kali di sini
# sebagai `-like 'cooperagent*'`, sekali lagi di setup.ps1 sebagai
# `'^  cooperagent:'`. Ketiganya berhenti cocok saat penyatuan profil 3.0.0
# mengganti nama provider menjadi `cooper-agent`, dan tidak ada yang memberi
# tahu: omp menjadi TIDAK TERLIHAT di Windows, sehingga Set-CooperAllHarness
# melewatinya -- baseUrl dan apiKey-nya tidak pernah ikut pindah saat dev
# berganti LAN/VPN, tanpa satu pun galat.
#
# Cermin dari regex yang sama di scripts/lib/omp_models.sh. Nama lama tetap
# dikenali: berkas dev yang belum pernah dimigrasi masih memakainya.
function Test-OmpNamaMilikKami([string]$Name) {
    return ($Name -match '^cooper-(agent|s[0-9]+)$' -or $Name -match '^cooperagent')
}
function Get-OmpStoredKey([string]$Path) {
    if (-not (Test-Path $Path)) { return '' }
    $mine = $false
    foreach ($l in (Get-Content $Path)) {
        if ($l -match '^  ([A-Za-z0-9_-]+):\s*$') { $mine = (Test-OmpNamaMilikKami $Matches[1]); continue }
        if ($mine -and $l -match '^\s*apiKey:\s*(\S+)\s*$') { return $Matches[1] }
    }
    return ''
}

# Yang BUKAN localhost didahulukan: itulah alamat yang berpindah saat dev
# berganti LAN <-> VPN. Tapi localhost dipakai bila ia satu-satunya -- dev yang
# bekerja langsung di host GPU memang hanya punya itu, dan mengembalikan kosong
# di sana berarti pemasangannya tidak terlihat sama sekali.
function Get-OmpStoredGateway([string]$Path) {
    if (-not (Test-Path $Path)) { return '' }
    $mine = $false; $local = ''
    foreach ($l in (Get-Content $Path)) {
        if ($l -match '^  ([A-Za-z0-9_-]+):\s*$') { $mine = (Test-OmpNamaMilikKami $Matches[1]); continue }
        if ($mine -and $l -match '^\s*baseUrl:\s*(\S+)\s*$') {
            $u = $Matches[1] -replace '/(api/)?v1.*$', ''
            if ($u -notmatch '127\.0\.0\.1') { return $u }
            if (-not $local) { $local = $u }
        }
    }
    return $local
}

# Memindahkan HANYA provider yang menunjuk gateway lama.
#
# Mengganti setiap baseUrl akan menyeret provider pihak ketiga milik dev
# (Anthropic, Ollama) ke gateway kita; localhost sengaja dilewati karena ia sama
# di mesin mana pun dan bukan bagian dari perpindahan LAN <-> VPN.
function Set-OmpBaseUrl([string]$Path, [string]$OldGateway, [string]$NewGateway) {
    if (-not (Test-Path $Path)) { return $false }
    if (-not $OldGateway) { return $false }
    $esc = [regex]::Escape($OldGateway)
    $out = foreach ($l in (Get-Content $Path)) {
        if ($l -match '127\.0\.0\.1') { $l }
        else { $l -replace "baseUrl:\s*$esc", "baseUrl: $NewGateway" }
    }
    [System.IO.File]::WriteAllText($Path, ($out -join "`r`n") + "`r`n",
        (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

# ── merge provider omp ───────────────────────────────────────────────────────
#
# Cermin dari scripts/lib/merge_providers.sh. Sampai 18 September 2026 sisi
# PowerShell tidak punya padanannya SAMA SEKALI: omp hanya di-sed di tempat,
# sehingga profil baru tidak pernah sampai ke pemasangan yang ada.
#
# Doktrinnya sama dengan MergeToml.ps1: yang ditimpa hanya kunci yang muncul di
# template, dan kunci bertanda `# @keep-existing` hanya ditulis bila dev belum
# punya. Provider di luar template tidak disentuh.
function Get-OmpManagedKeys([string[]]$TplLines) {
    $out = [ordered]@{}
    $prov = ''; $lvl = 'p'; $keep = $false
    foreach ($b in $TplLines) {
        if ($b -match '^\s*#\s*@keep-existing\s*$') { $keep = $true; continue }
        if ($b -match '^\s*#' -or $b -match '^\s*$') { continue }
        if ($b -match '^  ([A-Za-z0-9_-]+):\s*$') {
            $prov = $Matches[1]
            if (-not $out.Contains($prov)) { $out[$prov] = [ordered]@{ p = [ordered]@{}; m = [ordered]@{} } }
            $lvl = 'p'; $keep = $false; continue
        }
        if ($prov -eq '') { $keep = $false; continue }
        if ($b -match '^    models:\s*$') { $lvl = 'm'; $keep = $false; continue }
        $k = $null
        if ($b -match '^      - ([A-Za-z0-9_]+):')      { $k = $Matches[1]; $lvl = 'm' }
        elseif ($b -match '^        ([A-Za-z0-9_]+):')  { $k = $Matches[1]; $lvl = 'm' }
        elseif ($b -match '^    ([A-Za-z0-9_]+):')      { $k = $Matches[1]; $lvl = 'p' }
        if ($k) { $out[$prov][$lvl][$k] = @{ Line = $b; Keep = $keep } }
        $keep = $false
    }
    return $out
}

# Satu blok provider dari template, komentar pembukanya ikut. Penanda
# @keep-existing dibuang -- ia instruksi merge, bukan keterangan untuk pembaca.
function Get-OmpProviderBlock([string[]]$TplLines, [string]$Want) {
    $out = New-Object System.Collections.Generic.List[string]
    $hold = New-Object System.Collections.Generic.List[string]
    $collecting = $false
    foreach ($b in $TplLines) {
        if ($b -match '^\s*#\s*@keep-existing\s*$') { continue }
        if ($b -match '^\s*#' -or $b -match '^\s*$') { [void]$hold.Add($b); continue }
        if ($b -match '^  ([A-Za-z0-9_-]+):\s*$') {
            if ($Matches[1] -eq $Want) {
                foreach ($h in $hold) { [void]$out.Add($h) }
                $hold.Clear(); $collecting = $true; [void]$out.Add($b); continue
            }
            if ($collecting) { break }
            $hold.Clear(); continue
        }
        if (-not $collecting) { $hold.Clear(); continue }
        foreach ($h in $hold) { [void]$out.Add($h) }
        $hold.Clear(); [void]$out.Add($b)
    }
    return $out.ToArray()
}

function Merge-OmpProviders([string[]]$TplLines, [string[]]$CurLines, [bool]$KeepDevEndpoint = $false) {
    $managed = Get-OmpManagedKeys $TplLines
    if ($KeepDevEndpoint) {
        foreach ($p in @($managed.Keys)) {
            if ($managed[$p]['p'].Contains('baseUrl')) { $managed[$p]['p']['baseUrl'].Keep = $true }
        }
    }
    # Berkas yang tidak memuat `providers:` tidak kita kenali bentuknya.
    if (-not (@($CurLines | Where-Object { $_ -match '^providers:\s*$' }).Count -gt 0)) { return $CurLines }

    $out = New-Object System.Collections.Generic.List[string]
    $adaDiDev = @{}
    $prov = ''; $kelola = $false; $lvl = 'p'; $modelKe = 0
    $seen = @{}

    function SisipkanHilang($out, $managed, $prov, $lvl, $seen) {
        foreach ($k in $managed[$prov][$lvl].Keys) {
            if ($seen.ContainsKey("$prov|$lvl|$k")) { continue }
            $line = $managed[$prov][$lvl][$k].Line
            if ($lvl -eq 'm' -and $line -match '^      - ' -and $k -ne 'id') {
                $line = $line -replace '^      - ', '        '
            }
            [void]$out.Add($line)
        }
    }

    foreach ($b in $CurLines) {
        if ($b -match '^  ([A-Za-z0-9_-]+):\s*$' -and $prov -ne '' -and $kelola) {
            if ($lvl -eq 'm' -and $modelKe -ge 1) { SisipkanHilang $out $managed $prov 'm' $seen }
            elseif ($lvl -eq 'p') { SisipkanHilang $out $managed $prov 'p' $seen }
        }
        if ($b -match '^  ([A-Za-z0-9_-]+):\s*$') {
            $prov = $Matches[1]; $adaDiDev[$prov] = $true
            $kelola = $managed.Contains($prov); $lvl = 'p'; $modelKe = 0
            [void]$out.Add($b); continue
        }
        if (-not $kelola) { [void]$out.Add($b); continue }
        if ($b -match '^    models:\s*$') {
            SisipkanHilang $out $managed $prov 'p' $seen
            $lvl = 'm'; [void]$out.Add($b); continue
        }
        if ($b -match '^      - ([A-Za-z0-9_]+):') {
            $modelKe++
            if ($modelKe -eq 2) { SisipkanHilang $out $managed $prov 'm' $seen }
            if ($modelKe -eq 1) {
                $k = $Matches[1]
                if ($managed[$prov]['m'].Contains($k)) {
                    $seen["$prov|m|$k"] = $true
                    if (-not $managed[$prov]['m'][$k].Keep) { [void]$out.Add($managed[$prov]['m'][$k].Line); continue }
                }
            }
            [void]$out.Add($b); continue
        }
        if ($modelKe -eq 1 -and $b -match '^        ([A-Za-z0-9_]+):') {
            $k = $Matches[1]
            if ($managed[$prov]['m'].Contains($k)) {
                $seen["$prov|m|$k"] = $true
                if (-not $managed[$prov]['m'][$k].Keep) {
                    [void]$out.Add(($managed[$prov]['m'][$k].Line -replace '^      - ', '        ')); continue
                }
            }
            [void]$out.Add($b); continue
        }
        if ($lvl -eq 'p' -and $b -match '^    ([A-Za-z0-9_]+):') {
            $k = $Matches[1]
            if ($managed[$prov]['p'].Contains($k)) {
                $seen["$prov|p|$k"] = $true
                if (-not $managed[$prov]['p'][$k].Keep) { [void]$out.Add($managed[$prov]['p'][$k].Line); continue }
            }
            [void]$out.Add($b); continue
        }
        [void]$out.Add($b)
    }
    if ($prov -ne '' -and $kelola) {
        if ($lvl -eq 'm' -and $modelKe -ge 1) { SisipkanHilang $out $managed $prov 'm' $seen }
        elseif ($lvl -eq 'p') { SisipkanHilang $out $managed $prov 'p' $seen }
    }
    foreach ($p in $managed.Keys) {
        if ($adaDiDev.ContainsKey($p)) { continue }
        [void]$out.Add('')
        foreach ($l in (Get-OmpProviderBlock $TplLines $p)) { [void]$out.Add($l) }
    }
    return $out.ToArray()
}
