# Pembantu konfigurasi pi.
#
# models.json dan settings.json adalah JSON milik dev. Fungsi di sini hanya
# menggabungkan kunci yang dikelola CooperAgent dan mempertahankan properti
# lain, provider lain, model tambahan, serta setting pribadi.

function Get-PiProperty([object]$Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    return $Object.PSObject.Properties[$Name]
}

function Get-PiPropertyValue([object]$Object, [string]$Name) {
    $p = Get-PiProperty $Object $Name
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Set-PiProperty([object]$Object, [string]$Name, [object]$Value) {
    $p = Get-PiProperty $Object $Name
    if ($null -eq $p) {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    } else {
        $p.Value = $Value
    }
}

function Assert-PiObject([object]$Value, [string]$Label) {
    if ($null -eq $Value -or $Value -is [System.Array] -or
        $Value -is [string] -or $Value -is [System.ValueType]) {
        throw "Struktur JSON pi tidak valid: $Label harus berupa objek"
    }
    return $Value
}

function Read-PiJson([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{} }
    $raw = [System.IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($raw)) { return [pscustomobject]@{} }
    try {
        $value = $raw | ConvertFrom-Json
    } catch {
        throw "JSON pi tidak valid: $Path"
    }
    return Assert-PiObject $value $Path
}

function Copy-PiProperties([object]$Target, [object]$Source) {
    foreach ($p in $Source.PSObject.Properties) {
        Set-PiProperty $Target $p.Name $p.Value
    }
}

function Merge-PiModels([string]$ExistingPath, [string]$TemplatePath) {
    $root = Read-PiJson $ExistingPath
    $tpl = Read-PiJson $TemplatePath
    $providers = Get-PiPropertyValue $root 'providers'
    if ($null -eq $providers) {
        $providers = [pscustomobject]@{}
        Set-PiProperty $root 'providers' $providers
    } else { Assert-PiObject $providers 'providers' | Out-Null }

    $tplProvider = Get-PiPropertyValue $tpl 'providers' | ForEach-Object {
        Get-PiPropertyValue $_ 'cooperagent'
    }
    if ($null -eq $tplProvider) { throw 'Template models pi tidak memuat providers.cooperagent' }
    Assert-PiObject $tplProvider 'providers.cooperagent template' | Out-Null

    $provider = Get-PiPropertyValue $providers 'cooperagent'
    if ($null -eq $provider) { $provider = [pscustomobject]@{} }
    else { Assert-PiObject $provider 'providers.cooperagent' | Out-Null }

    $desiredModels = Get-PiPropertyValue $tplProvider 'models'
    if ($null -eq $desiredModels -or $desiredModels -isnot [System.Array] -or
        @($desiredModels).Count -eq 0) {
        throw 'Template models pi tidak memuat model'
    }
    $desired = @($desiredModels)[0]
    Assert-PiObject $desired 'cooperagent model template' | Out-Null

    $oldModels = @()
    $oldModelsProperty = Get-PiProperty $provider 'models'
    if ($null -ne $oldModelsProperty) {
        if ($oldModelsProperty.Value -isnot [System.Array]) {
            throw 'Struktur JSON pi tidak valid: cooperagent.models harus berupa array'
        }
        $oldModels = @($oldModelsProperty.Value)
    }

    $oldManaged = $null
    foreach ($m in $oldModels) {
        if ($null -eq $m) { continue }
        Assert-PiObject $m 'cooperagent model' | Out-Null
        $sameId = ((Get-PiPropertyValue $m 'id') -eq (Get-PiPropertyValue $desired 'id'))
        $name = [string](Get-PiPropertyValue $m 'name')
        if ($sameId -or $name.StartsWith('CooperAgent')) {
            $oldManaged = $m
            break
        }
    }

    $mergedModel = if ($null -ne $oldManaged) { $oldManaged } else { [pscustomobject]@{} }
    Copy-PiProperties $mergedModel $desired
    $preserved = @($oldModels | Where-Object {
        $id = Get-PiPropertyValue $_ 'id'
        $name = [string](Get-PiPropertyValue $_ 'name')
        ($id -ne (Get-PiPropertyValue $desired 'id')) -and
            (-not $name.StartsWith('CooperAgent'))
    })

    # Provider template adalah daftar managed keys; property lain pada provider
    # lama tetap berada di object yang sama.
    Copy-PiProperties $provider $tplProvider
    Set-PiProperty $provider 'models' (@($mergedModel) + $preserved)
    Set-PiProperty $providers 'cooperagent' $provider
    Set-PiProperty $root 'providers' $providers
    return $root
}

function Merge-PiSettings([string]$ExistingPath, [string]$TemplatePath) {
    $root = Read-PiJson $ExistingPath
    $tpl = Read-PiJson $TemplatePath

    $tplProvider = [string](Get-PiPropertyValue $tpl 'defaultProvider')
    $tplModel = [string](Get-PiPropertyValue $tpl 'defaultModel')
    $p = Get-PiProperty $root 'defaultProvider'
    if ($null -eq $p -or [string]::IsNullOrWhiteSpace([string]$p.Value)) {
        Set-PiProperty $root 'defaultProvider' $tplProvider
    }
    $p = Get-PiProperty $root 'defaultModel'
    if ($null -eq $p -or [string]::IsNullOrWhiteSpace([string]$p.Value)) {
        Set-PiProperty $root 'defaultModel' $tplModel
    }
    if ([string](Get-PiPropertyValue $root 'defaultProvider') -eq 'cooperagent') {
        Set-PiProperty $root 'defaultModel' $tplModel
    }

    $compaction = Get-PiPropertyValue $root 'compaction'
    if ($null -eq $compaction) { $compaction = [pscustomobject]@{} }
    else { Assert-PiObject $compaction 'compaction' | Out-Null }
    $tplCompaction = Get-PiPropertyValue $tpl 'compaction'
    if ($null -eq $tplCompaction) { throw 'Template settings pi tidak memuat compaction' }
    Assert-PiObject $tplCompaction 'compaction template' | Out-Null
    Copy-PiProperties $compaction $tplCompaction
    Set-PiProperty $root 'compaction' $compaction

    $tplSkills = @()
    $tplSkillsProperty = Get-PiProperty $tpl 'skills'
    if ($null -ne $tplSkillsProperty) {
        if ($tplSkillsProperty.Value -isnot [System.Array]) {
            throw 'Template settings pi tidak valid: skills harus berupa array'
        }
        $tplSkills = @($tplSkillsProperty.Value)
    }
    $skills = @()
    $skillsProperty = Get-PiProperty $root 'skills'
    if ($null -ne $skillsProperty) {
        if ($skillsProperty.Value -is [string] -or
            $skillsProperty.Value -isnot [System.Collections.IEnumerable]) {
            throw 'Struktur JSON pi tidak valid: skills harus berupa array'
        }
        $skills = @($skillsProperty.Value)
    }
    $seen = @{}
    $mergedSkills = New-Object System.Collections.Generic.List[object]
    foreach ($skill in @($skills + $tplSkills)) {
        $key = [string]$skill
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [void]$mergedSkills.Add($skill)
        }
    }
    Set-PiProperty $root 'skills' @($mergedSkills.ToArray())
    return $root
}

function Get-PiStoredKey([string]$Path) {
    try {
        $root = Read-PiJson $Path
        $provider = Get-PiPropertyValue (Get-PiPropertyValue $root 'providers') 'cooperagent'
        $value = [string](Get-PiPropertyValue $provider 'apiKey')
        if ($value -like 'ca_*') { return $value }
    } catch { }
    return ''
}

function Get-PiStoredGateway([string]$Path) {
    try {
        $root = Read-PiJson $Path
        $provider = Get-PiPropertyValue (Get-PiPropertyValue $root 'providers') 'cooperagent'
        $value = ([string](Get-PiPropertyValue $provider 'baseUrl')).TrimEnd('/')
        $value = $value -replace '/api/v1$', '' -replace '/v1$', '' -replace '/api$', ''
        return $value.TrimEnd('/')
    } catch { return '' }
}

function Test-PiProvider([string]$Path) {
    try {
        $root = Read-PiJson $Path
        $providers = Get-PiPropertyValue $root 'providers'
        return ($null -ne (Get-PiProperty $providers 'cooperagent'))
    } catch { return $false }
}

function Get-PiCompactionReserve {
    $reserve = [int64]$script:ContractContextWindow - [int64]$script:ContractCompactTokens
    if ($reserve -le 0) { throw 'Kontrak compaction tidak valid: threshold_tokens >= context_window' }
    return $reserve
}

function Invoke-PiPrint([string]$PiPath, [string]$AgentDir, [string]$ProjectDir,
                        [string]$Model, [string]$Prompt) {
    $oldAgent = $env:PI_CODING_AGENT_DIR
    $oldTelemetry = $env:PI_TELEMETRY
    try {
        $env:PI_CODING_AGENT_DIR = $AgentDir
        $env:PI_TELEMETRY = '0'
        Push-Location $ProjectDir
        # Argumen dikumpulkan ke ARRAY, lalu di-splat.
        #
        # PowerShell TIDAK melanjutkan pemanggilan perintah ke baris berikutnya
        # tanpa backtick: `--no-session` di awal baris dibaca sebagai operator,
        # dan seluruh berkas gagal di-parse -- bukan hanya fungsi ini. Terjadi
        # 4 September 2026 dan membuat setup.ps1 mati untuk SETIAP dev Windows,
        # apa pun harness yang dipilihnya.
        #
        # Backtick di akhir baris memperbaiki gejalanya tetapi rapuh sendiri:
        # satu spasi di belakangnya sudah cukup untuk mematahkannya lagi, dan
        # spasi itu tidak terlihat di review. Array tidak punya mode gagal itu.
        $piArgs = @(
            '--provider', 'cooperagent',
            '--model', $Model,
            '--mode', 'json',
            '--no-session', '--print',
            '--no-extensions', '--no-prompt-templates', '--no-themes',
            $Prompt
        )
        $out = (& $PiPath @piArgs 2>&1 | Out-String)
        $rc = $LASTEXITCODE
        return [pscustomobject]@{ Output = $out; ExitCode = $rc }
    } finally {
        Pop-Location
        if ($null -eq $oldAgent) { Remove-Item Env:PI_CODING_AGENT_DIR -ErrorAction SilentlyContinue }
        else { $env:PI_CODING_AGENT_DIR = $oldAgent }
        if ($null -eq $oldTelemetry) { Remove-Item Env:PI_TELEMETRY -ErrorAction SilentlyContinue }
        else { $env:PI_TELEMETRY = $oldTelemetry }
    }
}

function Invoke-PiVerify([string]$AgentDir, [string]$ModelsPath, [string]$SettingsPath,
                         [string]$Model, [string]$Who, [string]$PiPath) {
    if (-not (Test-Path -LiteralPath $PiPath)) { throw 'Biner pi tidak ditemukan; verify() tidak dijalankan.' }
    if ($Who -notmatch '@' -or $Who -like 'dev-*') { throw "Identitas gateway tidak sah untuk pi: $Who" }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('cooperagent-pi-verify-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'agent'), (Join-Path $tmp 'project') | Out-Null
        Copy-Item $ModelsPath (Join-Path $tmp 'agentmodels.json')
        Copy-Item $SettingsPath (Join-Path $tmp 'agentsettings.json')
        Copy-Item (Join-Path $AgentDir 'AGENTS.md') (Join-Path $tmp 'agentAGENTS.md')
        $marker = 'COOPER_PI_RULES_GATE_' + (Get-Random)
        $checkpointMarker = 'COOPER_PI_CHECKPOINT_GATE_' + (Get-Random)
        $rulesPath = Join-Path $tmp 'agentAGENTS.md'
        [System.IO.File]::AppendAllText($rulesPath, [Environment]::NewLine + $marker + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false)))
        $first = Invoke-PiPrint $PiPath (Join-Path $tmp 'agent') (Join-Path $tmp 'project') $Model `
            'Read the global work rules. Return only the exact verification sentence appended to that global AGENTS.md.'
        if ($first.ExitCode -ne 0 -or $first.Output -notmatch '"type"\s*:\s*"message_end"' -or
            $first.Output -notmatch '"stopReason"\s*:\s*"stop"' -or $first.Output -notmatch [regex]::Escape($marker)) {
            throw 'POST /v1/chat/completions lewat pi tidak terverifikasi 200 atau marker AGENTS.md tidak muncul.'
        }
        Write-Host "  [v] POST /v1/chat/completions lewat pi selesai (message_end/stop; HTTP 200)."
        Write-Host "  [v] identitas gateway untuk leaderboard: $Who"
        Write-Host "  [v] pi membaca AGENTS.md global (marker sementara cocok: $marker)."

        $slug = 'pi-verify-' + (Get-Random)
        $checkpoint = Join-Path $tmp ("project\.cooper\context\$slug.md")
        $prompt = "Read the global work rules. This is a disposable project task boundary. Create .cooper/context/$slug.md using a temporary file and mv. Include the exact line $checkpointMarker and do not write elsewhere. Reply checkpoint-written."
        $second = Invoke-PiPrint $PiPath (Join-Path $tmp 'agent') (Join-Path $tmp 'project') $Model $prompt
        if ($second.ExitCode -ne 0 -or $second.Output -notmatch '"type"\s*:\s*"message_end"' -or
            $second.Output -notmatch '"stopReason"\s*:\s*"stop"' -or
            -not (Test-Path -LiteralPath $checkpoint) -or
            -not ([System.IO.File]::ReadAllText($checkpoint).Contains($checkpointMarker))) {
            throw 'task-boundary tidak menghasilkan .cooper/context checkpoint.'
        }
        Write-Host "  [v] task-boundary menghasilkan .cooper/context/$slug.md (marker cocok: $checkpointMarker)."
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}
