<#{
.SYNOPSIS
    Pemasang pi sebagai harness tambahan CooperAgent.

.DESCRIPTION
    Jalur ini hanya menulis ~/.pi/agent dan sumber skill bersama
    ~/.cooper/skills. Ia tidak memanggil setup Grok atau Oh My Pi.
    models.json dan settings.json di-merge sehingga provider, model, key, dan
    setting milik dev di luar CooperAgent tetap utuh.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$Token = '',
    [string]$Endpoint = '',
    [switch]$Rules,
    [switch]$NoRules,
    [switch]$RemoveRules
)
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$TplDir = Join-Path $RepoRoot 'templates'
$PiAgentDir = if ($env:PI_AGENT_DIR) { $env:PI_AGENT_DIR } else { Join-Path $HOME '.pi\agent' }
$ModelsPath = Join-Path $PiAgentDir 'models.json'
$SettingsPath = Join-Path $PiAgentDir 'settings.json'
$RulesPath = Join-Path $PiAgentDir 'AGENTS.md'
$CooperSkills = Join-Path $HOME '.cooper\skills'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

. (Join-Path $RepoRoot 'scripts\lib\Contract.ps1')
. (Join-Path $RepoRoot 'scripts\lib\Credential.ps1')
. (Join-Path $RepoRoot 'scripts\lib\PiModels.ps1')

function ConvertTo-PiCanonicalEndpoint([string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $u = $Url.Trim().TrimEnd('/')
    foreach ($suffix in @('/api/v1', '/v1', '/api')) {
        if ($u.EndsWith($suffix)) {
            $u = $u.Substring(0, $u.Length - $suffix.Length)
            break
        }
    }
    return "$u/api/v1"
}

function Get-PiCachedEndpoint([string]$Id) {
    $cache = Join-Path (Join-Path $HOME '.cooper') 'gateway-endpoints'
    if (-not (Test-Path -LiteralPath $cache)) { return '' }
    foreach ($line in (Get-Content -LiteralPath $cache)) {
        $parts = $line -split "`t", 3
        if ($parts.Count -eq 3 -and $parts[0] -eq $Id) { return $parts[2] }
    }
    return ''
}

function Write-PiJsonAtomic([object]$Value, [string]$Path) {
    $json = $Value | ConvertTo-Json -Depth 50
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.bak.$Stamp"
        Copy-Item -LiteralPath $Path -Destination $backup
        if (-not (Test-Path -LiteralPath $backup) -or (Get-Item -LiteralPath $backup).Length -le 0) {
            throw "Cadangan $Path gagal diverifikasi; berkas tidak ditimpa."
        }
        Write-Host "  cadangan: $backup"
    }
    $tmp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.File]::WriteAllText($tmp, $json + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false)))
        if ((Get-Item -LiteralPath $tmp).Length -le 0) { throw "Hasil sementara kosong: $Path" }
        Move-Item -LiteralPath $tmp -Destination $Path -Force
        if (-not (Test-Path -LiteralPath $Path) -or (Get-Item -LiteralPath $Path).Length -le 0) {
            throw "Hasil $Path tidak dapat diverifikasi setelah ditulis."
        }
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    }
}

function Install-PiRules {
    # Kepemilikan diperiksa LEBIH DULU, sebelum apa pun diklaim -- lihat
    # catatan sepadan di scripts/setup-pi.sh.
    $tplRules = Join-Path $TplDir 'agent-rules.md'
    if ((Test-Path -LiteralPath $RulesPath) -and (Test-Path -LiteralPath $tplRules)) {
        $a = [System.IO.File]::ReadAllBytes($tplRules)
        $b = [System.IO.File]::ReadAllBytes($RulesPath)
        if ($a.Length -eq $b.Length -and
            [System.Convert]::ToBase64String($a) -eq [System.Convert]::ToBase64String($b)) {
            Write-Host '  [v] aturan agent pi sudah mutakhir.'
            return
        }
    }
    if ((Test-Path -LiteralPath $RulesPath) -and -not $Rules) {
        Write-Host "  [!] aturan pi BERBEDA dari template CooperAgent - dipertahankan: $RulesPath" -ForegroundColor Yellow
        Write-Host '     Jalankan dengan -Rules bila memang ingin menggantinya.' -ForegroundColor Yellow
        return
    }
    if ($DryRun) {
        Write-Host "  [v] aturan penuh akan dipasang ke $RulesPath"
        return
    }
    $src = Join-Path $TplDir 'agent-rules.md'
    New-Item -ItemType Directory -Force -Path $PiAgentDir | Out-Null
    if (Test-Path -LiteralPath $RulesPath) {
        $backup = "$RulesPath.bak.$Stamp"
        Copy-Item -LiteralPath $RulesPath -Destination $backup
        if (-not (Test-Path -LiteralPath $backup) -or (Get-Item -LiteralPath $backup).Length -le 0) {
            throw 'Cadangan AGENTS.md pi kosong; tidak menimpa aturan dev.'
        }
    }
    Copy-Item -LiteralPath $src -Destination $RulesPath -Force
    if (-not ((Get-Content -Raw -LiteralPath $src) -ceq (Get-Content -Raw -LiteralPath $RulesPath))) {
        throw 'AGENTS.md pi tidak sama dengan template setelah ditulis.'
    }
    Write-Host "  [v] aturan penuh dipasang ke $RulesPath ($((Get-Item $RulesPath).Length) byte)."
}

function Install-PiSkills {
    $srcRoot = Join-Path $TplDir 'skills'
    if (-not (Test-Path -LiteralPath $srcRoot)) { return }
    foreach ($src in (Get-ChildItem -LiteralPath $srcRoot -Directory)) {
        $dst = Join-Path $CooperSkills $src.Name
        if ($DryRun) { continue }
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item -Path (Join-Path $src.FullName '*') -Destination $dst -Recurse -Force
        foreach ($managed in (Get-ChildItem -LiteralPath $src.FullName -Force)) {
            if (-not (Test-Path -LiteralPath (Join-Path $dst $managed.Name))) {
                throw "Skill pi tidak lengkap setelah ditulis: $($src.Name)"
            }
        }
    }
    Write-Host "  [v] skill CooperAgent tersedia melalui $CooperSkills."
}

if ($RemoveRules) {
    if (Test-Path -LiteralPath $RulesPath) {
        $src = Join-Path $TplDir 'agent-rules.md'
        if ((Get-Content -Raw -LiteralPath $RulesPath) -ceq (Get-Content -Raw -LiteralPath $src)) {
            if (-not $DryRun) {
                $backup = "$RulesPath.bak.$Stamp"
                Copy-Item -LiteralPath $RulesPath -Destination $backup
                if ((Get-Item -LiteralPath $backup).Length -le 0) { throw 'Cadangan aturan pi kosong.' }
                Remove-Item -LiteralPath $RulesPath -Force
            }
            Write-Host '  [v] aturan agent pi dilepas (cadangan dibuat).' -ForegroundColor Green
        } else {
            Write-Host '  [!] aturan pi milik dev atau tidak dikenali - tidak disentuh.' -ForegroundColor Yellow
        }
    } else { Write-Host '  [!] aturan pi belum ada - tidak ada yang dilepas.' -ForegroundColor Yellow }
    exit 0
}

if ($NoRules -and -not (Test-Path -LiteralPath $RulesPath)) {
    Write-Error 'Pemasangan pi dibatalkan: verify() mensyaratkan ~/.pi/agent/AGENTS.md. Pakai -Rules.'
    exit 4
}

$storedGateway = Get-PiStoredGateway $ModelsPath
$rawBase = if ($Endpoint) { $Endpoint } elseif ($env:COOPERAGENT_GATEWAY) { $env:COOPERAGENT_GATEWAY } else { $storedGateway }
if ([string]::IsNullOrWhiteSpace($rawBase)) {
    Write-Error 'Tidak ada alamat gateway pi. Pakai -Endpoint, COOPERAGENT_GATEWAY, atau config pi yang sudah ada.'
    exit 1
}

if ($rawBase -notmatch '^https?://') {
    $probeBase = if ($env:COOPERAGENT_GATEWAY) { $env:COOPERAGENT_GATEWAY } else { $storedGateway }
    if ([string]::IsNullOrWhiteSpace($probeBase)) {
        Write-Error "Alias endpoint '$rawBase' tidak dapat diselesaikan tanpa gateway yang sedang terpasang."
        exit 1
    }
    if (-not (Get-CooperContract (Get-CooperGatewayBase $probeBase))) {
        $resolved = Get-PiCachedEndpoint $rawBase
    } else { $resolved = Get-CooperEndpointUrl $rawBase }
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        Write-Error "Alias endpoint '$rawBase' tidak diumumkan gateway dan tidak ada di cache."
        exit 1
    }
    $rawBase = $resolved
}
$ServerUrl = ConvertTo-PiCanonicalEndpoint $rawBase

if (-not $Token) { $Token = Get-PiStoredKey $ModelsPath }
if (-not (Test-CooperTokenForm $Token)) {
    Write-Error 'Pi membutuhkan token ca_...; identitas dev-... tidak digunakan.'
    exit 3
}

Write-Host '--- Gerbang kredensial pi ---' -ForegroundColor Cyan
$credential = Test-CooperCredential $ServerUrl $Token
if ($credential.State -ne 'ok') {
    Write-Host '[x] Kredensial pi tidak lolos pemeriksaan.' -ForegroundColor Red
    foreach ($line in (Get-CooperCredentialHelp $credential.State $ServerUrl)) { Write-Host "    $line" -ForegroundColor Yellow }
    Write-Host '    Tidak ada berkas pi yang ditulis.' -ForegroundColor Yellow
    exit 3
}
$Who = $credential.Who
Write-Host "[v] token sah - identitas: $Who" -ForegroundColor Green

$base = Get-CooperGatewayBase $ServerUrl
if (Get-CooperContract $base) {
    Write-Host "[v] kontrak dari gateway: context $(Format-CooperNumber $ContractContextWindow) / output $ContractMaxTokens / compact $ContractCompactPct%" -ForegroundColor Green
} else {
    Write-Host '[!] kontrak tidak terambil - memakai nilai cadangan; periksa ulang setelah tersambung.' -ForegroundColor Yellow
}
Write-Host "  sumber angka pi: $(Get-CooperContractNote)"

$piCommand = Get-Command pi -ErrorAction SilentlyContinue
if ($null -eq $piCommand) {
    Write-Error 'Biner pi tidak ditemukan; pasang pi atau siapkan PATH sebelum menulis config.'
    exit 1
}
$PiPath = $piCommand.Source

$modelsText = (Expand-CooperTemplate (Get-Content -Raw -LiteralPath (Join-Path $TplDir 'pi-models.json'))).Replace('__GATEWAY__', $base).Replace('__API_KEY__', $Token)
$settingsText = (Expand-CooperTemplate (Get-Content -Raw -LiteralPath (Join-Path $TplDir 'pi-settings.json'))).Replace('__GATEWAY__', $base).Replace('__API_KEY__', $Token)
if (-not (Assert-CooperRendered $modelsText 'templates/pi-models.json') -or
    -not (Assert-CooperRendered $settingsText 'templates/pi-settings.json')) { exit 1 }
$modelTemplate = [System.IO.Path]::GetTempFileName()
$settingsTemplate = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($modelTemplate, $modelsText, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($settingsTemplate, $settingsText, (New-Object System.Text.UTF8Encoding($false)))
    $modelsMerged = Merge-PiModels $ModelsPath $modelTemplate
    $settingsMerged = Merge-PiSettings $SettingsPath $settingsTemplate
} finally {
    Remove-Item -LiteralPath $modelTemplate,$settingsTemplate -Force -ErrorAction SilentlyContinue
}

$compaction = Get-PiPropertyValue $settingsMerged 'compaction'
if ((Get-PiPropertyValue $compaction 'enabled') -ne $true -or
    [int64](Get-PiPropertyValue $compaction 'reserveTokens') -le 0) {
    throw 'settings.json pi tidak memuat compaction kontrak yang sah.'
}

if ($DryRun) {
    Write-Host '[!] Dry-run selesai - verify() tidak dijalankan karena tidak ada config yang dipasang.' -ForegroundColor Yellow
    exit 0
}

Install-PiRules
Install-PiSkills
Write-PiJsonAtomic $modelsMerged $ModelsPath
Write-PiJsonAtomic $settingsMerged $SettingsPath

Write-Host '--- Verify pi ---' -ForegroundColor Cyan
Invoke-PiVerify $PiAgentDir $ModelsPath $SettingsPath $ContractModelId $Who $PiPath $Token (Join-Path $TplDir 'agent-rules.md')
Write-Host '[v] pi terpasang dan seluruh verify() lulus.' -ForegroundColor Green
