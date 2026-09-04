# Uji runtime PiModels.ps1 — dijalankan pada runner Windows.
#
# KENAPA ADA: dua cacat khusus Windows lolos ke main karena tidak ada satu pun
# yang MENJALANKAN PowerShell. Job `ps-parse` membuktikan berkasnya sah secara
# sintaks; ia tidak membuktikan fungsinya bekerja. Yang kedua lolos justru
# karena PowerShell membongkar array satu elemen saat sebuah fungsi
# me-`return`-kannya — perilaku yang tidak punya padanan di bash, sehingga tidak
# ada uji Linux yang bisa menangkapnya.
#
# Uji ini tidak menyentuh jaringan, tidak memasang apa pun, dan tidak menulis di
# luar direktori sementaranya.

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts\lib\PiModels.ps1')

$script:pass = 0
$script:fail = 0
function ok([string]$m) { $script:pass++; Write-Host ("  ok    " + $m) }
function no([string]$m) { $script:fail++; Write-Host ("  GAGAL " + $m) }

function Write-Utf8([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pi-uji-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $modelsTplPath = Join-Path $tmp 'models.tpl.json'
    $settingsTplPath = Join-Path $tmp 'settings.tpl.json'

    $modelsTpl = (Get-Content -Raw -LiteralPath (Join-Path $repo 'templates\pi-models.json')).
        Replace('__GATEWAY__', 'http://198.51.100.20:8987/api').
        Replace('__API_KEY__', 'ca_uji').
        Replace('__MODEL_ID__', 'intercon-agent').
        Replace('__CONTEXT_WINDOW__', '131072').
        Replace('__MAX_TOKENS__', '12288')
    Write-Utf8 $modelsTplPath $modelsTpl

    $settingsTpl = (Get-Content -Raw -LiteralPath (Join-Path $repo 'templates\pi-settings.json')).
        Replace('__MODEL_ID__', 'intercon-agent').
        Replace('__PI_COMPACTION_RESERVE__', '26215')
    Write-Utf8 $settingsTplPath $settingsTpl

    # Config milik dev yang TIDAK boleh hilang.
    $existingModels = Join-Path $tmp 'models.json'
    Write-Utf8 $existingModels @'
{
  "providers": {
    "anthropic": {
      "name": "Anthropic",
      "baseUrl": "https://api.anthropic.com/v1",
      "apiKey": "sk-milik-dev",
      "models": [ { "id": "punya-dev", "name": "Punya Dev" } ]
    }
  }
}
'@
    $existingSettings = Join-Path $tmp 'settings.json'
    Write-Utf8 $existingSettings '{ "theme": "dracula", "skills": ["~/skill-dev"] }'

    # --- models -----------------------------------------------------------
    $merged = Merge-PiModels $existingModels $modelsTplPath
    $prov = $merged.providers.cooperagent
    if ($null -ne $prov) { ok "provider cooperagent ditulis" } else { no "provider cooperagent tidak ada" }

    # Regresi: nilai array yang di-`return` dari fungsi ikut terbongkar
    # pipeline, sehingga template satu model dikira kosong.
    $modelsProp = $prov.PSObject.Properties['models']
    if ($null -ne $modelsProp -and $modelsProp.Value -is [System.Array] -and
        @($modelsProp.Value).Count -ge 1) {
        ok "models tetap array meski hanya satu model"
    } else {
        no "models bukan array — array satu elemen terbongkar pipeline"
    }

    if ((@($modelsProp.Value)[0].contextWindow) -eq 131072 -and
        (@($modelsProp.Value)[0].maxTokens) -eq 12288) {
        ok "angka kontrak masuk ke model"
    } else { no "contextWindow/maxTokens tidak terisi dari kontrak" }

    if ($merged.providers.anthropic -and
        $merged.providers.anthropic.apiKey -eq 'sk-milik-dev') {
        ok "provider dan kunci milik dev utuh"
    } else { no "config dev hilang saat merge" }

    if ($prov.baseUrl -like '*://*/v1') { ok "baseUrl berakhir /v1" }
    else { no ("baseUrl tidak sesuai: " + $prov.baseUrl) }

    # --- settings ---------------------------------------------------------
    $ms = Merge-PiSettings $existingSettings $settingsTplPath
    $skillsProp = $ms.PSObject.Properties['skills']
    if ($null -ne $skillsProp -and $skillsProp.Value -is [System.Array]) {
        ok "skills tetap array"
    } else { no "skills bukan array lagi" }

    if ($ms.theme -eq 'dracula') { ok "setelan lain milik dev utuh" }
    else { no "setelan dev hilang" }

    if ($ms.compaction.enabled -eq $true -and $ms.compaction.reserveTokens -eq 26215) {
        ok "compaction turunan kontrak terpasang"
    } else { no "compaction tidak terisi" }

    # --- lint jalur -------------------------------------------------------
    # Bukan bukti, tapi menangkap bentuk typo yang sudah pernah terjadi:
    # `Join-Path $tmp 'agentmodels.json'` -- nama direktori disambung ke nama
    # berkas TANPA pemisah, sisa terjemahan harfiah dari "$tmp/agent/models.json"
    # versi bash. Berkasnya mendarat di tempat yang salah, direktori yang
    # ditunjuk PI_CODING_AGENT_DIR kosong, dan pi menjawab
    # `Unknown provider "cooperagent"` atas config yang sudah benar.
    # Baris komentar dibuang lebih dulu: penjelasan cacat ini di PiModels.ps1
    # memuat contoh yang persis dicari lint, dan lint yang menyala pada
    # dokumentasinya sendiri akan segera dimatikan orang.
    $srcLines = [System.IO.File]::ReadAllLines((Join-Path $repo 'scripts\lib\PiModels.ps1'))
    $src = ($srcLines | Where-Object { $_.TrimStart() -notlike '#*' }) -join "`n"
    if ($src -match "Join-Path\s+\`$\w+\s+'agent[A-Za-z]") {
        no "ada Join-Path yang menyambung 'agent' ke nama berkas tanpa pemisah"
    } else {
        ok "tidak ada segmen jalur yang tersambung tanpa pemisah"
    }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ("lulus " + $script:pass + ", gagal " + $script:fail)
if ($script:fail -gt 0) { exit 1 }
