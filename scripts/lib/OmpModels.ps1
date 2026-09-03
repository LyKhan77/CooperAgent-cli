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
# Provider dikenali dari NAMANYA (`cooperagent`, `cooperagent-localhost`,
# `cooperagent-s2` -- persis yang ditulis templates/omp-models.yml), bukan dari
# bentuk alamatnya. Menebak dari alamat akan salah menyebut Ollama milik dev
# (`http://localhost:11434`) sebagai provider kita, dan yang terbaca lalu
# dilaporkan sebagai "kredensial Anda" adalah kunci orang lain.
function Get-OmpStoredKey([string]$Path) {
    if (-not (Test-Path $Path)) { return '' }
    $mine = $false
    foreach ($l in (Get-Content $Path)) {
        if ($l -match '^  ([A-Za-z0-9_-]+):\s*$') { $mine = ($Matches[1] -like 'cooperagent*'); continue }
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
        if ($l -match '^  ([A-Za-z0-9_-]+):\s*$') { $mine = ($Matches[1] -like 'cooperagent*'); continue }
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
