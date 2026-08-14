# Build mutant SLC overlay tree on PC (retail base + kiosk rights/config).
# Requires YOUR extracted SLC trees - not included in this repo.

param(
    [string]$ConfigPath = '',
    [string]$RetailExtract = '',
    [string]$KioskExtract = '',
    [string]$OutputMutant = '',
    [switch]$Rebuild,
    [switch]$Force,
    [switch]$FullKioskPolicy
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Region.ps1')
Initialize-RwkmScript -Name 'build_mutant_slc' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $retail = if ($RetailExtract) { $RetailExtract } else { $cfg.RetailSlcExtract }
    $kiosk = if ($KioskExtract) { $KioskExtract } else { $cfg.KioskSlcExtract }
    $mutant = if ($OutputMutant) { $OutputMutant } else { $cfg.MutantSlc }
    $outRoot = Split-Path -Parent $mutant

    Test-RwkmRegionConsistency -Config $cfg -RetailExtract $retail -KioskExtract $kiosk -Force:$Force | Out-Null

    foreach ($p in @($retail, $kiosk)) {
        if (-not (Test-RwkmSlcExtractTree $p)) {
            throw @"
Missing SLC extract tree: $p

Need sys\rights\sys\cert.sys (NAND Extractor output).

Fix:
  Retail -> dumps\retail   (see dumps\retail\IN_HERE_PUT_THE_FILES_THAT_ARE_NEEDED.txt)
  Kiosk  -> dumps\kiosk    (see dumps\kiosk\IN_HERE_PUT_THE_FILES_THAT_ARE_NEEDED.txt)
  or set RetailSlcExtract / KioskSlcExtract in config.ps1.
"@
        }
    }

    if ((Test-Path -LiteralPath $mutant) -and $Rebuild) {
        if (-not (Confirm-Rwkm -Level Warning -Prompt "Delete existing mutant folder and rebuild?`n$mutant" -Force:$Force)) {
            throw 'Cancelled: rebuild not confirmed.'
        }
        Remove-Item -LiteralPath $mutant -Recurse -Force
    }

    Confirm-RwkmFileWrite -Source $retail -Destination $mutant `
        -Description "Merge retail + kiosk SLC rights/config into mutant overlay (region: $($cfg.Region))." `
        -Level Warning -Force:$Force

    if (-not (Test-Path -LiteralPath $mutant)) {
        Write-RwkmLog "Copying retail base -> $mutant"
        & robocopy $retail $mutant /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }
    }

    $log = New-Object System.Collections.Generic.List[string]
    function Log([string]$s) { [void]$log.Add($s); Write-RwkmLog $s }

    Log '=== Mutant SLC build ==='
    Log "Region: $($cfg.Region)"
    Log "Retail: $retail"
    Log "Kiosk:  $kiosk"
    Log "Output: $mutant"
    Log ''

    $retailCert = Join-Path $retail 'sys\rights\sys\cert.sys'
    $kioskCert  = Join-Path $kiosk  'sys\rights\sys\cert.sys'
    $outCert    = Join-Path $mutant 'sys\rights\sys\cert.sys'
    Copy-Item -LiteralPath $outCert -Destination "$outCert.retail.bak" -Force -ErrorAction SilentlyContinue

    $rb = [IO.File]::ReadAllBytes($retailCert)
    $kb = [IO.File]::ReadAllBytes($kioskCert)
    if ($rb.Length -ne 2560) { Write-RwkmLog "WARN: unexpected retail cert.sys size: $($rb.Length)" }
    if ($kb.Length -lt 4096) { Write-RwkmLog "WARN: unexpected kiosk cert.sys size: $($kb.Length)" }
    $merged = $rb + $kb
    [IO.File]::WriteAllBytes($outCert, $merged)
    Log "cert.sys: $($rb.Length) + $($kb.Length) = $($merged.Length) bytes"

    $retailTik = Join-Path $retail 'sys\rights\ticket'
    $kioskTik  = Join-Path $kiosk  'sys\rights\ticket'
    $mutantTik = Join-Path $mutant 'sys\rights\ticket'

    function Get-TicketRelMap([string]$root) {
        $map = @{}
        if (-not (Test-Path -LiteralPath $root)) { return $map }
        Get-ChildItem $root -Recurse -Filter *.tik | ForEach-Object {
            $rel = Get-RwkmRelativeUnixPath -Root $root -FullPath $_.FullName
            $map[$rel] = $_.FullName
        }
        return $map
    }

    $retailMap = Get-TicketRelMap $retailTik
    $kioskMap  = Get-TicketRelMap $kioskTik
    $copied = 0; $overwritten = 0
    foreach ($rel in $kioskMap.Keys) {
        $dest = Join-Path $mutantTik ($rel -replace '/','\')
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        }
        Copy-Item -LiteralPath $kioskMap[$rel] -Destination $dest -Force
        if ($retailMap.ContainsKey($rel)) { $overwritten++ } else { $copied++ }
    }
    Log "tickets: copied $copied kiosk-only; overwritten $overwritten retail paths with kiosk bytes"

    function Read-TitleList([string]$path) {
        $b = [IO.File]::ReadAllBytes($path)
        $set = New-Object 'System.Collections.Generic.HashSet[string]'
        for ($i = 0; $i + 8 -le $b.Length; $i += 8) {
            [void]$set.Add([BitConverter]::ToString($b, $i, 8).Replace('-',''))
        }
        # Unary comma: stop PowerShell unwrapping the HashSet into Object[]
        return , $set
    }

    $retailList = Join-Path $retail 'sys\rights\sys\title.list'
    $kioskList  = Join-Path $kiosk  'sys\rights\sys\title.list'
    $outList    = Join-Path $mutant 'sys\rights\sys\title.list'
    Copy-Item -LiteralPath $outList -Destination "$outList.retail.bak" -Force -ErrorAction SilentlyContinue

    $union = Read-TitleList $retailList
    foreach ($id in (Read-TitleList $kioskList)) { [void]$union.Add($id) }
    $sorted = @($union) | Sort-Object
    $outBytes = New-Object byte[] ($sorted.Count * 8)
    $idx = 0
    foreach ($hex in $sorted) {
        $bytes = [byte[]]::new(8)
        for ($j = 0; $j -lt 8; $j++) {
            $bytes[$j] = [Convert]::ToByte($hex.Substring($j * 2, 2), 16)
        }
        [Array]::Copy($bytes, 0, $outBytes, $idx, 8)
        $idx += 8
    }
    [IO.File]::WriteAllBytes($outList, $outBytes)
    Log ('title.list: {0} unique entries ({1} bytes)' -f $union.Count, $outBytes.Length)

    # sys_prod.xml: keep retail region/serial; only adopt kiosk hardware identity fields.
    # Physical console stays a retail Wii U - software reports as kiosk (WIS-001 / FW).
    # Note: do NOT use [xml] here - element name 5ghz_country_code is illegal in System.Xml.
    $retailProd = Join-Path $retail 'sys\config\sys_prod.xml'
    $kioskProd  = Join-Path $kiosk  'sys\config\sys_prod.xml'
    $outProd    = Join-Path $mutant 'sys\config\sys_prod.xml'
    if ((Test-Path -LiteralPath $retailProd) -and (Test-Path -LiteralPath $kioskProd)) {
        Copy-Item -LiteralPath $outProd -Destination "$outProd.retail.bak" -Force -ErrorAction SilentlyContinue
        $rpText = [IO.File]::ReadAllText($retailProd)
        $kpText = [IO.File]::ReadAllText($kioskProd)
        function Get-RwkmXmlTagText([string]$xml, [string]$tag) {
            if ($xml -match "(?s)<$tag[^>]*>\s*([^<]*?)\s*</$tag>") { return $Matches[1].Trim() }
            return $null
        }
        $oldModel = Get-RwkmXmlTagText $rpText 'model_number'
        $oldCode  = Get-RwkmXmlTagText $rpText 'code_id'
        $newModel = Get-RwkmXmlTagText $kpText 'model_number'
        $newCode  = Get-RwkmXmlTagText $kpText 'code_id'
        if (-not $newModel) { $newModel = 'WIS-001' }
        if (-not $newCode)  { $newCode  = 'FW' }
        $outText = $rpText
        if ($oldModel) {
            $outText = [regex]::Replace($outText, "(?s)(<model_number[^>]*>\s*)[^<]*?(\s*</model_number>)", "`${1}$newModel`${2}", 1)
        }
        if ($oldCode) {
            $outText = [regex]::Replace($outText, "(?s)(<code_id[^>]*>\s*)[^<]*?(\s*</code_id>)", "`${1}$newCode`${2}", 1)
        }
        [IO.File]::WriteAllText($outProd, $outText)
        Log "sys_prod.xml: model $oldModel -> $newModel ; code_id $oldCode -> $newCode (region/serial kept retail)"
        Log 'NOTE: Do NOT Submit System Data with WiiUIdent while this identity is active - can ruin the public database.'
    } else {
        Log 'WARN: missing retail or kiosk sys_prod.xml - skipped identity patch'
    }

    $retailSys = Join-Path $retail 'sys\config\system.xml'
    $kioskSys  = Join-Path $kiosk  'sys\config\system.xml'
    $outSys    = Join-Path $mutant 'sys\config\system.xml'

    Copy-Item -LiteralPath $outSys -Destination "$outSys.retail.bak" -Force -ErrorAction SilentlyContinue

    $rxText = [IO.File]::ReadAllText($retailSys)
    $kxText = [IO.File]::ReadAllText($kioskSys)
    $homeTitle = $cfg.RetailSystemMenuTitleId
    if ($homeTitle -notmatch '^00050010') { $homeTitle = "00050010$homeTitle" }
    $homeTitle = $homeTitle.ToLowerInvariant()

    $outSysText = [regex]::Replace(
        $rxText,
        '(?s)(<default_title_id[^>]*>\s*)[0-9A-Fa-f]{16}(\s*</default_title_id>)',
        "`${1}$homeTitle`${2}",
        1
    )
    if ($kxText -match '(?s)(<standby[^>]*>.*?<enable[^>]*>\s*)([^<]*?)(\s*</enable>)') {
        $standbyVal = $Matches[2].Trim()
        $outSysText = [regex]::Replace(
            $outSysText,
            '(?s)(<standby[^>]*>.*?<enable[^>]*>\s*)([^<]*?)(\s*</enable>)',
            "`${1}$standbyVal`${3}",
            1
        )
    }
    if ($kxText -match '(?s)<reset_on_crash[^>]*>\s*([^<]*?)\s*</reset_on_crash>') {
        $roc = $Matches[1].Trim()
        if ($outSysText -match 'reset_on_crash') {
            $outSysText = [regex]::Replace(
                $outSysText,
                '(?s)(<reset_on_crash[^>]*>\s*)[^<]*?(\s*</reset_on_crash>)',
                "`${1}$roc`${2}",
                1
            )
        } else {
            $outSysText = $outSysText -replace '</system>', "  <reset_on_crash type=`"unsignedInt`" length=`"4`">$roc</reset_on_crash>`r`n</system>"
        }
    }
    if ($kxText -match '(?s)(<simulated_ppc_mem2_size[^>]*>\s*)([^<]*?)(\s*</simulated_ppc_mem2_size>)') {
        $ppc = $Matches[2].Trim()
        $outSysText = [regex]::Replace(
            $outSysText,
            '(?s)(<simulated_ppc_mem2_size[^>]*>\s*)([^<]*?)(\s*</simulated_ppc_mem2_size>)',
            "`${1}$ppc`${3}",
            1
        )
    }
    [IO.File]::WriteAllText($outSys, $outSysText)
    Log "system.xml: coldboot $homeTitle (retail menu), kiosk policy fields (apply script asks Y/N before FTP)"

    function Set-RwkmSystemXmlDefaultTitleId([string]$xml, [string]$titleId) {
        $tid = $titleId.ToString().Trim()
        if ($tid -notmatch '^00050010') { $tid = "00050010$tid" }
        $tid = $tid.ToLowerInvariant()
        $updated = [regex]::Replace(
            $xml,
            '(?s)(<default_title_id[^>]*>\s*)[0-9A-Fa-f]{16}(\s*</default_title_id>)',
            "`${1}$tid`${2}",
            1
        )
        if ($updated -eq $xml) {
            throw "Could not set default_title_id to $tid in system.xml (no matching tag)."
        }
        return $updated
    }

    $sctTitle = if ($cfg.NativeSctTitleId) { $cfg.NativeSctTitleId } else { '1f700500' }
    $menuTitle = if ($cfg.KioskMenuTitleId) { $cfg.KioskMenuTitleId } else { '1fa81000' }
    $coldbootVariants = @(
        @{ File = 'system.xml.kioskboot'; TitleId = $sctTitle; Label = 'native SCT' }
        @{ File = 'system.xml.kioskmenu'; TitleId = $menuTitle; Label = 'Kiosk Menu' }
    )
    foreach ($variant in $coldbootVariants) {
        $dest = Join-Path $mutant "sys\config\$($variant.File)"
        $fromDump = Join-Path $kiosk "sys\config\$($variant.File)"
        if (Test-Path -LiteralPath $fromDump) {
            Copy-Item -LiteralPath $fromDump -Destination $dest -Force
            Log "copied from kiosk dump: $($variant.File)"
        } else {
            $variantXml = Set-RwkmSystemXmlDefaultTitleId $outSysText $variant.TitleId
            [IO.File]::WriteAllText($dest, $variantXml)
            Log "synthesized $($variant.File) (coldboot $($variant.Label))"
        }
    }

    if ($FullKioskPolicy) {
        $patchFiles = @(
            'sys\config\eco.xml',
            'sys\proc\prefs\im_cfg.xml',
            'sys\proc\prefs\caffeine.xml',
            'sys\proc\prefs\nn.xml'
        )
        foreach ($rel in $patchFiles) {
            $src = Join-Path $kiosk $rel
            $dst = Join-Path $mutant $rel
            if (-not (Test-Path -LiteralPath $src)) { continue }
            if (Test-Path -LiteralPath $dst) { Copy-Item -LiteralPath $dst -Destination "$dst.retail.bak" -Force }
            Copy-Item -LiteralPath $src -Destination $dst -Force
            Log "patched: $rel"
        }
    } else {
        Log 'prefs skipped: eco.xml, caffeine.xml, im_cfg.xml, nn.xml (use -FullKioskPolicy for kiosk prefs)'
    }

    $logRoot = if ($outRoot) { $outRoot } else { $mutant }
    $logPath = Join-Path $logRoot 'BUILD_LOG.txt'
    $log | Set-Content -LiteralPath $logPath -Encoding UTF8
    Write-RwkmLog "Done. Mutant tree: $mutant"
    Write-RwkmLog "Build log: $logPath"
    Write-RwkmLog 'Next: plan_additive_tickets.ps1 then apply_mutant_slc_ftp.ps1'

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
