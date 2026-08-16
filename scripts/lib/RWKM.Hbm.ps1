# Shared helpers for retail-compatible Kiosk Home Button Menu (00050030/10010x0a).
# Used by build_kiosk_hbm_mlc.ps1 and apply_kiosk_hbm_ftp.ps1. See docs\AI\EXPERIMENTAL.MD.

function Get-RwkmHbmTitleIdForRegion {
    param([string]$Region)
    switch ($Region.ToUpperInvariant()) {
        'USA' { return '1001010a' }
        'PAL' { return '1001020a' }
        default { throw "Unsupported region '$Region' (use USA or PAL)." }
    }
}

function Resolve-RwkmHbmTitleFolder {
    param(
        [string]$ExplicitRoot,
        [string]$SearchHint,
        [string]$TitleId,
        [string]$Label
    )
    if ($ExplicitRoot) {
        if (-not (Test-Path -LiteralPath $ExplicitRoot)) {
            throw "$Label folder not found: $ExplicitRoot"
        }
        return (Resolve-Path -LiteralPath $ExplicitRoot).Path
    }
    if (-not $SearchHint) {
        throw "$Label path not set. Pass an explicit folder for $Label."
    }
    $candidates = @(
        (Join-Path $SearchHint $TitleId),
        (Join-Path $SearchHint ($TitleId.ToUpperInvariant())),
        (Join-Path (Split-Path $SearchHint -Parent) "00050030\$TitleId"),
        (Join-Path (Split-Path $SearchHint -Parent) ("00050030\" + $TitleId.ToUpperInvariant()))
    )
    if ($SearchHint -match '[\\/]00050010[\\/]?$') {
        $sib = Join-Path (Split-Path $SearchHint -Parent) "00050030\$TitleId"
        $candidates = @($sib) + $candidates
    }
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }
    throw @"
$Label Home Button Menu folder not found for title $TitleId.

Tried:
  $($candidates -join "`n  ")
"@
}

function Get-RwkmFileSha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Set-RwkmXmlTagValue {
    param(
        [Parameter(Mandatory = $true)][string]$Xml,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
    )
    $escaped = [regex]::Escape($Tag)
    $pattern = '(<' + $escaped + '\b[^>]*>)([^<]*)(</' + $escaped + '>)'
    if ($Xml -notmatch $pattern) {
        return $Xml
    }
    return [regex]::Replace($Xml, $pattern, { param($m) $m.Groups[1].Value + $Value + $m.Groups[3].Value }, 1)
}

function Get-RwkmXmlTagValue {
    param([string]$Xml, [string]$Tag)
    $escaped = [regex]::Escape($Tag)
    $pattern = '<' + $escaped + '\b[^>]*>([^<]*)</' + $escaped + '>'
    if ($Xml -match $pattern) {
        return $Matches[1]
    }
    return ''
}

function New-RwkmCompatHbmMetaXml {
    param(
        [Parameter(Mandatory = $true)][string]$RetailMetaXml,
        [Parameter(Mandatory = $true)][string]$KioskMetaXml
    )

    $out = $RetailMetaXml
    $fallbackLong = Get-RwkmXmlTagValue -Xml $KioskMetaXml -Tag 'longname_en'
    if ([string]::IsNullOrWhiteSpace($fallbackLong)) {
        $fallbackLong = 'Wii U Kiosk Home Button Menu'
    }
    $fallbackShort = Get-RwkmXmlTagValue -Xml $KioskMetaXml -Tag 'shortname_en'
    if ([string]::IsNullOrWhiteSpace($fallbackShort)) {
        $fallbackShort = $fallbackLong
    }

    $nameTags = @(
        'longname_ja', 'longname_en', 'longname_fr', 'longname_de', 'longname_it', 'longname_es',
        'longname_zhs', 'longname_ko', 'longname_nl', 'longname_pt', 'longname_ru', 'longname_zht',
        'shortname_ja', 'shortname_en', 'shortname_fr', 'shortname_de', 'shortname_it', 'shortname_es',
        'shortname_zhs', 'shortname_ko', 'shortname_nl', 'shortname_pt', 'shortname_ru', 'shortname_zht'
    )
    foreach ($tag in $nameTags) {
        $kVal = Get-RwkmXmlTagValue -Xml $KioskMetaXml -Tag $tag
        if (-not [string]::IsNullOrWhiteSpace($kVal)) {
            $use = $kVal
        } else {
            $use = if ($tag -like 'shortname_*') { $fallbackShort } else { $fallbackLong }
        }
        $out = Set-RwkmXmlTagValue -Xml $out -Tag $tag -Value $use
    }
    return $out
}

function Test-RwkmKioskHbmSource {
    param([string]$Root)

    $issues = New-Object System.Collections.Generic.List[string]
    $rpx = Join-Path $Root 'code\kiosk_hbm.rpx'
    $hbm = Join-Path $Root 'code\hbm.rpx'
    if (-not (Test-Path -LiteralPath $rpx)) {
        if (Test-Path -LiteralPath $hbm) {
            [void]$issues.Add('Found hbm.rpx (retail HOME), not kiosk_hbm.rpx - this is not a kiosk HBM dump.')
        } else {
            [void]$issues.Add('Missing code\kiosk_hbm.rpx')
        }
    } else {
        $len = (Get-Item -LiteralPath $rpx).Length
        if ($len -lt 50000) {
            [void]$issues.Add("kiosk_hbm.rpx looks too small ($len bytes)")
        }
    }

    $boot = Join-Path $Root 'content\assets\sounds\bootSound.btsnd'
    if (-not (Test-Path -LiteralPath $boot)) {
        [void]$issues.Add('Missing content\assets\sounds\bootSound.btsnd (kiosk jingle)')
    } elseif ((Get-Item -LiteralPath $boot).Length -lt 1000) {
        [void]$issues.Add('bootSound.btsnd is suspiciously small')
    }

    foreach ($rel in @('code\app.xml', 'code\cos.xml', 'meta\meta.xml', 'content')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $rel))) {
            [void]$issues.Add("Missing $rel")
        }
    }

    if (Test-Path -LiteralPath (Join-Path $Root 'code\cos.xml')) {
        $cos = Get-Content -LiteralPath (Join-Path $Root 'code\cos.xml') -Raw
        if ($cos -notmatch 'kiosk_hbm\.rpx') {
            [void]$issues.Add('cos.xml argstr does not reference kiosk_hbm.rpx')
        }
    }

    $empty = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 })
    if ($empty.Count -gt 0) {
        [void]$issues.Add("Source has $($empty.Count) zero-byte file(s) - possible failed extract")
    }

    return $issues
}

function Test-RwkmRetailHomeSource {
    param([string]$Root)

    $issues = New-Object System.Collections.Generic.List[string]
    $rpx = Join-Path $Root 'code\hbm.rpx'
    if (-not (Test-Path -LiteralPath $rpx)) {
        [void]$issues.Add('Missing code\hbm.rpx (expected retail HOME)')
    }
    foreach ($rel in @('code\app.xml', 'code\cos.xml', 'meta\meta.xml')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $rel))) {
            [void]$issues.Add("Missing $rel")
        }
    }
    if (Test-Path -LiteralPath (Join-Path $Root 'code\app.xml')) {
        $app = Get-Content -LiteralPath (Join-Path $Root 'code\app.xml') -Raw
        if ($app -notmatch 'os_mask[^>]*>.*0600') {
            Write-RwkmLog 'WARN: retail app.xml os_mask does not look like modern OSv10 (...0600). Still proceeding.'
        }
    }
    return $issues
}

function Build-RwkmCompatHbmTree {
    param(
        [Parameter(Mandatory = $true)][string]$KioskRoot,
        [Parameter(Mandatory = $true)][string]$RetailRoot,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [string]$ReferenceRoot = '',
        [switch]$RequireReferenceTmd
    )

    $kioskIssues = Test-RwkmKioskHbmSource -Root $KioskRoot
    $retailIssues = Test-RwkmRetailHomeSource -Root $RetailRoot
    foreach ($i in $kioskIssues) { Write-RwkmLog "VERIFY kiosk: $i" }
    foreach ($i in $retailIssues) { Write-RwkmLog "VERIFY retail: $i" }
    if ($kioskIssues.Count -gt 0 -or $retailIssues.Count -gt 0) {
        throw 'HBM source verification failed.'
    }

    if (Test-Path -LiteralPath $OutputRoot) {
        Remove-Item -LiteralPath $OutputRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

    Write-RwkmLog "Copying kiosk payload -> $OutputRoot"
    & robocopy $KioskRoot $OutputRoot /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }

    $outApp = Join-Path $OutputRoot 'code\app.xml'
    $outCos = Join-Path $OutputRoot 'code\cos.xml'
    $outMeta = Join-Path $OutputRoot 'meta\meta.xml'
    Copy-Item -LiteralPath (Join-Path $RetailRoot 'code\app.xml') -Destination $outApp -Force

    $cos = Get-Content -LiteralPath (Join-Path $RetailRoot 'code\cos.xml') -Raw
    if ($cos -notmatch 'hbm\.rpx') {
        throw 'Retail cos.xml does not contain hbm.rpx argstr.'
    }
    $cos = $cos -replace 'hbm\.rpx', 'kiosk_hbm.rpx'
    [IO.File]::WriteAllText($outCos, $cos)

    $retailMeta = Get-Content -LiteralPath (Join-Path $RetailRoot 'meta\meta.xml') -Raw
    $kioskMeta = Get-Content -LiteralPath (Join-Path $KioskRoot 'meta\meta.xml') -Raw
    $mergedMeta = New-RwkmCompatHbmMetaXml -RetailMetaXml $retailMeta -KioskMetaXml $kioskMeta
    [IO.File]::WriteAllText($outMeta, $mergedMeta)

    $tmdSrc = Join-Path $KioskRoot 'code\title.tmd'
    $fstSrc = Join-Path $KioskRoot 'code\title.fst'
    $usedReferenceTmd = $false
    if ($ReferenceRoot) {
        $refTmd = Join-Path $ReferenceRoot 'code\title.tmd'
        $refFst = Join-Path $ReferenceRoot 'code\title.fst'
        if ((Test-Path -LiteralPath $refTmd) -and (Test-Path -LiteralPath $refFst)) {
            $tmdSrc = $refTmd
            $fstSrc = $refFst
            $usedReferenceTmd = $true
            Write-RwkmLog 'Using reference title.tmd + title.fst'
        } elseif ($RequireReferenceTmd) {
            throw "ReferenceHome missing title.tmd/title.fst under $ReferenceRoot"
        } else {
            Write-RwkmLog 'WARN: reference TMD/FST missing - keeping kiosk TMD/FST'
        }
    } elseif ($RequireReferenceTmd) {
        throw 'ReferenceHomeRoot is required for this operation.'
    } else {
        Write-RwkmLog 'Keeping kiosk title.tmd + title.fst (no reference provided)'
    }
    Copy-Item -LiteralPath $tmdSrc -Destination (Join-Path $OutputRoot 'code\title.tmd') -Force
    Copy-Item -LiteralPath $fstSrc -Destination (Join-Path $OutputRoot 'code\title.fst') -Force

    # Remove retail-only leftovers if robocopy somehow left them (should not from kiosk base)
    $retailOnly = Join-Path $OutputRoot 'code\hbm.rpx'
    if (Test-Path -LiteralPath $retailOnly) {
        Remove-Item -LiteralPath $retailOnly -Force
    }
    $preload = Join-Path $OutputRoot 'code\preload.txt'
    if (Test-Path -LiteralPath $preload) {
        Remove-Item -LiteralPath $preload -Force
    }

    $outAppText = Get-Content -LiteralPath $outApp -Raw
    $outCosText = Get-Content -LiteralPath $outCos -Raw
    if ($outAppText -notmatch 'os_mask') { throw 'Output app.xml missing os_mask' }
    if ($outCosText -notmatch 'kiosk_hbm\.rpx') { throw 'Output cos.xml missing kiosk_hbm.rpx' }
    if ($outCosText -match 'argstr[^>]*>hbm\.rpx<') { throw 'Output cos.xml still references hbm.rpx' }
    if ((Get-RwkmFileSha256 $outApp) -ne (Get-RwkmFileSha256 (Join-Path $RetailRoot 'code\app.xml'))) {
        throw 'Output app.xml does not match retail donor.'
    }
    if ((Get-RwkmFileSha256 (Join-Path $OutputRoot 'code\kiosk_hbm.rpx')) -ne (Get-RwkmFileSha256 (Join-Path $KioskRoot 'code\kiosk_hbm.rpx'))) {
        throw 'Output RPX hash drifted from kiosk source.'
    }

    return @{
        OutputRoot         = $OutputRoot
        UsedReferenceTmd   = $usedReferenceTmd
        ProductCode        = (Get-RwkmXmlTagValue -Xml (Get-Content -LiteralPath $outMeta -Raw) -Tag 'product_code')
        TitleVersion       = (Get-RwkmXmlTagValue -Xml (Get-Content -LiteralPath $outMeta -Raw) -Tag 'title_version')
    }
}

function Compare-RwkmHbmToReference {
    param(
        [Parameter(Mandatory = $true)][string]$BuiltRoot,
        [Parameter(Mandatory = $true)][string]$ReferenceRoot,
        [switch]$RequireExactCritical
    )

    $critical = @(
        'code\app.xml',
        'code\cos.xml',
        'code\kiosk_hbm.rpx',
        'code\title.tmd',
        'code\title.fst'
    )
    $failed = New-Object System.Collections.Generic.List[string]
    foreach ($rel in $critical) {
        $a = Join-Path $BuiltRoot $rel
        $b = Join-Path $ReferenceRoot $rel
        if (-not (Test-Path -LiteralPath $a)) {
            [void]$failed.Add("MISSING built: $rel")
            continue
        }
        if (-not (Test-Path -LiteralPath $b)) {
            Write-RwkmLog "SKIP compare (no reference file): $rel"
            continue
        }
        $same = (Get-RwkmFileSha256 $a) -eq (Get-RwkmFileSha256 $b)
        if ($same) {
            Write-RwkmLog "MATCH $rel"
        } else {
            Write-RwkmLog "DIFF  $rel"
            [void]$failed.Add($rel)
        }
    }

    $builtMeta = Get-Content -LiteralPath (Join-Path $BuiltRoot 'meta\meta.xml') -Raw
    $refMeta = Get-Content -LiteralPath (Join-Path $ReferenceRoot 'meta\meta.xml') -Raw
    foreach ($tag in @('product_code', 'title_version', 'longname_en', 'shortname_en')) {
        $ov = Get-RwkmXmlTagValue -Xml $builtMeta -Tag $tag
        $rv = Get-RwkmXmlTagValue -Xml $refMeta -Tag $tag
        if ($ov -eq $rv) {
            Write-RwkmLog "MATCH meta <$tag>"
        } else {
            Write-RwkmLog "DIFF  meta <$tag>: built='$ov' ref='$rv'"
            [void]$failed.Add("meta:$tag")
        }
    }

    if ($RequireExactCritical -and $failed.Count -gt 0) {
        throw @"
Patched HBM does not match reference on critical files:
  $($failed -join "`n  ")

Aborting before any Wii U write.
"@
    }
    return ,@($failed)
}
