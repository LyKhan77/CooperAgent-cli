# Uji runtime OmpModels.ps1 — dijalankan pada runner Windows.
#
# KENAPA ADA: cacat yang membuat uji ini ditulis lolos berbulan-bulan karena
# tidak ada satu pun yang MENJALANKAN sisi PowerShell omp. Job `ps-parse`
# membuktikan berkasnya sah secara sintaks; ia tidak membuktikan fungsinya
# mengenali provider apa pun.
#
# Yang terjadi: penyatuan profil 3.0.0 mengganti nama provider di
# templates/omp-models.yml dari `cooperagent` menjadi `cooper-agent`, sementara
# sisi Windows masih mencari nama lama di tiga tempat. Akibatnya SETIAP
# pemasangan omp Windows yang dibuat 3.0.0 ke atas tidak terlihat sebagai
# terpasang -- Set-CooperAllHarness melewatinya, dan baseUrl maupun apiKey-nya
# tidak pernah ikut pindah saat dev berganti LAN/VPN. Tidak ada galat sama
# sekali; omp hanya diam-diam menembak alamat lama.
#
# Sisi bash tidak pernah punya cacat ini: regexnya menerima kedua nama sejak
# awal. Itu justru yang membuatnya sulit terlihat -- dev Linux tidak pernah
# mengalaminya.
#
# Uji ini tidak menyentuh jaringan, tidak memasang apa pun, dan tidak menulis di
# luar direktori sementaranya.

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts\lib\OmpModels.ps1')

$script:pass = 0
$script:fail = 0
function ok([string]$m) { $script:pass++; Write-Host ("  ok    " + $m) }
function no([string]$m) { $script:fail++; Write-Host ("  GAGAL " + $m) }

function Write-Utf8([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("omp-uji-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    # --- pengenalan nama ------------------------------------------------------
    # Nama 3.0.0 yang ditulis templates/omp-models.yml hari ini.
    foreach ($n in @('cooper-agent', 'cooper-s1', 'cooper-s2', 'cooper-s3')) {
        if (Test-OmpNamaMilikKami $n) { ok ("nama 3.0.0 dikenali: " + $n) }
        else { no ("nama 3.0.0 TIDAK dikenali: " + $n + " -- omp akan dilewati di Windows") }
    }
    # Nama lama tetap dikenali: berkas dev yang belum pernah dimigrasi memakainya.
    foreach ($n in @('cooperagent', 'cooperagent-localhost', 'cooperagent-s2')) {
        if (Test-OmpNamaMilikKami $n) { ok ("nama lama tetap dikenali: " + $n) }
        else { no ("nama lama tidak dikenali lagi: " + $n) }
    }
    # Dan provider milik dev tidak boleh diakui sebagai milik kita: yang terbaca
    # lalu dilaporkan sebagai "kredensial Anda" akan menjadi kunci orang lain.
    foreach ($n in @('anthropic', 'ollama', 'cooper', 'cooper-lain', 'openai-cooper')) {
        if (Test-OmpNamaMilikKami $n) { no ("provider dev diakui milik kita: " + $n) }
        else { ok ("provider dev tidak diakui: " + $n) }
    }

    # --- pembacaan dari berkas bernama 3.0.0 ----------------------------------
    $yml = Join-Path $tmp 'models.yml'
    Write-Utf8 $yml @'
providers:
  cooper-agent:
    name: CooperAgent
    baseUrl: http://198.51.100.20:8987/v1
    apiKey: ca_kunci_uji
    models:
      - id: intercon-agent
        maxTokens: 12288

  cooper-s2:
    name: CooperAgent server 2
    baseUrl: http://198.51.100.20:8987/v1/upstream/s2
    apiKey: ca_kunci_uji
    models:
      - id: intercon-agent
        maxTokens: 12288

  anthropic-saya:
    name: Punya dev
    baseUrl: https://api.anthropic.com/v1
    apiKey: sk-ant-BERBAYAR
    models:
      - id: claude
        maxTokens: 8192
'@

    if ((Get-OmpStoredKey $yml) -eq 'ca_kunci_uji') { ok "apiKey terbaca dari provider bernama cooper-agent" }
    else { no ("apiKey tidak terbaca: '" + (Get-OmpStoredKey $yml) + "'") }

    if ((Get-OmpStoredGateway $yml) -eq 'http://198.51.100.20:8987') { ok "gateway terbaca, /v1 dipangkas" }
    else { no ("gateway tidak terbaca: '" + (Get-OmpStoredGateway $yml) + "'") }

    # --- perpindahan gateway --------------------------------------------------
    [void](Set-OmpBaseUrl $yml 'http://198.51.100.20:8987' 'http://10.8.0.2:8987')
    $isi = Get-Content $yml -Raw
    if ($isi -match 'baseUrl: http://10\.8\.0\.2:8987/v1\s' -and
        $isi -match 'baseUrl: http://10\.8\.0\.2:8987/v1/upstream/s2') {
        ok "kedua provider kami ikut pindah, jalur /upstream utuh"
    } else { no "provider kami tidak ikut pindah saat gateway diganti" }

    if ($isi -match 'https://api\.anthropic\.com/v1') { ok "endpoint dev tidak diseret ikut pindah" }
    else { no "endpoint dev ikut ditimpa" }

    # --- penulisan token ------------------------------------------------------
    [void](Set-OmpApiKey $yml 'ca_kunci_baru' 'http://10.8.0.2:8987')
    $isi = Get-Content $yml -Raw
    if ($isi -match 'apiKey: ca_kunci_baru') { ok "token baru ditulis ke provider kami" }
    else { no "token baru tidak ditulis" }

    if ($isi -match 'sk-ant-BERBAYAR') { ok "kunci berbayar dev selamat" }
    else { no "kunci berbayar dev HILANG" }

    # --- berkas peninggalan bernama lama --------------------------------------
    # Dev yang memasang sebelum 3.0.0 dan belum pernah menjalankan setup ulang.
    $lama = Join-Path $tmp 'models-lama.yml'
    Write-Utf8 $lama @'
providers:
  cooperagent:
    baseUrl: http://192.168.1.50:8987/v1
    apiKey: ca_kunci_lama
    models:
      - id: intercon-agent
        maxTokens: 12288
'@
    if ((Get-OmpStoredKey $lama) -eq 'ca_kunci_lama' -and
        (Get-OmpStoredGateway $lama) -eq 'http://192.168.1.50:8987') {
        ok "pemasangan peninggalan tetap terbaca"
    } else { no "pemasangan peninggalan tidak terbaca lagi" }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ("lulus " + $script:pass + ", gagal " + $script:fail)
if ($script:fail -gt 0) { exit 1 }
