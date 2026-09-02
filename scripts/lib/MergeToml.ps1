# Merge TOML berbasis "kunci terkelola" — padanan PowerShell dari
# scripts/lib/merge_toml.sh. Dipakai bersama oleh setup.ps1 dan
# scripts/setup-dev.ps1.
#
# Yang ditimpa HANYA kunci yang muncul di template. Server MCP, seksi [ui],
# [marketplace], dan model tambahan milik dev dibiarkan utuh.
# --- parse kunci terkelola dari template ------------------------------------
function Get-ManagedKeys([string]$Path) {
    $managed = New-Object System.Collections.Generic.List[object]
    $cur = ''
    $keepNext = $false
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        if ($line -match '^\s*$') { continue }
        # Penanda @keep-existing: kunci berikutnya hanya ditulis bila BELUM ada
        # di mesin dev. Dipakai untuk nilai per-mesin seperti base_url.
        if ($line -match '^\s*#\s*@keep-existing') { $keepNext = $true; continue }
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\[.*\]\s*$') { $cur = $line.Trim(); $keepNext = $false; continue }
        if ($line -match '^\s*([A-Za-z0-9_.\-]+)\s*=') {
            $managed.Add([pscustomobject]@{ Section = $cur; Key = $Matches[1]; Line = $line; Done = $false; Keep = $keepNext })
            $keepNext = $false
        }
    }
    return $managed
}

# --- peta rentang baris tiap seksi ------------------------------------------
function Get-SectionMap([string[]]$Lines) {
    $map = [ordered]@{}
    $cur = ''; $start = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\[.*\]\s*$') {
            if ($cur -ne '') { $map[$cur] = @{ Start = $start; End = $i } }
            $cur = $Lines[$i].Trim(); $start = $i + 1
        }
    }
    if ($cur -ne '') { $map[$cur] = @{ Start = $start; End = $Lines.Count } }
    return $map
}

function Merge-Toml([object]$Managed, [string[]]$Lines) {
    $out = New-Object System.Collections.Generic.List[string]
    $out.AddRange([string[]]$Lines)

    # 1. ganti nilai kunci yang sudah ada
    $map = Get-SectionMap $out
    foreach ($m in $Managed) {
        if (-not $map.Contains($m.Section)) { continue }
        $r = $map[$m.Section]
        for ($i = $r.Start; $i -lt $r.End; $i++) {
            if ($out[$i] -match ('^\s*' + [regex]::Escape($m.Key) + '\s*=')) {
                if (-not $m.Keep) { $out[$i] = $m.Line }   # keep-existing: nilai dev dibiarkan
                $m.Done = $true; break
            }
        }
    }

    # 2. sisipkan kunci yang hilang ke seksi yang sudah ada.
    #    Dikerjakan dari seksi paling belakang supaya indeks tetap sahih.
    $map = Get-SectionMap $out
    $sections = @($map.Keys)
    [array]::Reverse($sections)
    foreach ($sec in $sections) {
        $missing = @($Managed | Where-Object { $_.Section -eq $sec -and -not $_.Done })
        if ($missing.Count -eq 0) { continue }
        $end = $map[$sec].End
        while ($end -gt $map[$sec].Start -and $out[$end - 1] -match '^\s*$') { $end-- }
        for ($j = $missing.Count - 1; $j -ge 0; $j--) {
            $out.Insert($end, $missing[$j].Line); $missing[$j].Done = $true
        }
    }

    # 3. tambahkan seksi yang sama sekali belum ada
    $map = Get-SectionMap $out
    foreach ($m in $Managed) {
        if ($m.Done) { continue }
        if (-not $map.Contains($m.Section)) {
            $out.Add(''); $out.Add($m.Section)
            $map[$m.Section] = @{ Start = $out.Count; End = $out.Count }
        }
        $out.Add($m.Line); $m.Done = $true
    }
    return $out.ToArray()
}
