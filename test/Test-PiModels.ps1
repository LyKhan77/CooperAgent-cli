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
# Get-Content dipaksa UTF-8 -- lihat catatan panjang di setup.ps1. Tanpa ini,
# 5.1 membaca ANSI, dan siklus baca-tulis menggandakan setiap karakter non-ASCII.
$PSDefaultParameterValues['Get-Content:Encoding'] = 'UTF8'

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
    Write-Utf8 $existingSettings @'
{
  "theme": "dracula",
  "skills": ["~/skill-dev"],
  "mcpServers": { "punya-dev": { "command": "npx", "args": ["-y", "server-dev"] } },
  "extensions": ["~/.pi/agent/extensions/milik-dev.ts"],
  "keybindings": { "submit": "ctrl+enter" }
}
'@

    # --- models -----------------------------------------------------------
    $merged = Merge-PiModels $existingModels $modelsTplPath
    $prov = $merged.providers.'cooper-agent'
    if ($null -ne $prov) { ok "provider cooper-agent ditulis" } else { no "provider cooper-agent tidak ada" }

    # KEEMPAT profil harus masuk, bukan hanya satu.
    #
    # Sampai 12 September 2026 Merge-PiModels mengeraskan satu nama provider,
    # jadi pi hanya pernah mendapat sepertiga dari yang dimiliki Grok dan omp.
    # Uji ini yang menahannya kembali ke sana.
    $wajib = @('cooper-agent', 'cooper-s1', 'cooper-s2', 'cooper-s3')
    $hilang = @($wajib | Where-Object { $null -eq $merged.providers.PSObject.Properties[$_] })
    if ($hilang.Count -eq 0) { ok "keempat profil model masuk" }
    else { no ("profil hilang: " + ($hilang -join ', ')) }

    # Profil langsung menembus routing; kalau baseUrl-nya sama dengan yang
    # auto-routing, ia tidak menembus apa pun dan uji banding jadi bohong.
    $s1 = $merged.providers.'cooper-s1'
    if ($null -ne $s1 -and $s1.baseUrl -like '*/upstream/s1') { ok "cooper-s1 menunjuk /upstream/s1" }
    else { no ("cooper-s1 baseUrl salah: " + $s1.baseUrl) }

    # Regresi: nilai array yang di-`return` dari fungsi ikut terbongkar
    # pipeline, sehingga template satu model dikira kosong.
    $modelsProp = $prov.PSObject.Properties['models']
    if ($null -ne $modelsProp -and $modelsProp.Value -is [System.Array] -and
        @($modelsProp.Value).Count -ge 1) {
        ok "models tetap array meski hanya satu model"
    } else {
        no "models bukan array - array satu elemen terbongkar pipeline"
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

    if ((@($ms.skills) -contains '~/skill-dev') -and (@($ms.skills) -contains '~/.cooper/skills')) {
        ok "skill dev DAN skill CooperAgent hidup berdampingan"
    } else { no "skill dev tergusur oleh skill CooperAgent" }

    # Yang tidak dikelola CooperAgent tidak boleh tersentuh sama sekali.
    if ($ms.mcpServers.'punya-dev'.command -eq 'npx' -and
        (@($ms.mcpServers.'punya-dev'.args) -contains 'server-dev') -and
        (@($ms.extensions) -contains '~/.pi/agent/extensions/milik-dev.ts') -and
        $ms.keybindings.submit -eq 'ctrl+enter') {
        ok "server MCP, extension, dan keybinding milik dev utuh"
    } else { no "config dev di luar kelolaan CooperAgent hilang" }

    # Regresi: instalasi lama dengan defaultProvider "cooperagent" (tanpa
    # strip, kunci yatim yang tidak lagi disentuh Merge-PiModels) harus
    # dipindah ke "cooper-agent" -- kalau tidak, baseUrl-nya beku dan pi
    # timeout diam-diam setiap kali gateway pindah LAN/VPN.
    $legacySettings = Join-Path $tmp 'settings.legacy.json'
    Write-Utf8 $legacySettings '{ "defaultProvider": "cooperagent" }'
    $msLegacy = Merge-PiSettings $legacySettings $settingsTplPath
    if ($msLegacy.defaultProvider -eq 'cooper-agent') { ok "defaultProvider cooperagent dipindah ke cooper-agent" }
    else { no ("defaultProvider tidak dipindah: " + $msLegacy.defaultProvider) }

}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ("lulus " + $script:pass + ", gagal " + $script:fail)
if ($script:fail -gt 0) { exit 1 }
