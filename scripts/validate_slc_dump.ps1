#Requires -Version 5.1
# Validate a SLC dump (RAW or stripped) for redNAND use.
# Exits 0 only if ISFS can walk /sys/title/00050010/1000400a/code/fw.img
#
# Needs Python 3 (py -3, python, or python3 on PATH).

param(
    [Parameter(ParameterSetName = 'Explicit')][string]$InputPath,
    [string]$StrippedPath = '',
    [string]$ConfigPath = '',
    [Parameter(ParameterSetName = 'Config')][switch]$UseConfig,
    [ValidateSet('slc','slccmpt')][string]$Kind = 'slc',
    [switch]$SkipStrip
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')

$rawSize = 553648128L
$stripSize = 536870912L
$stripScript = Join-Path $scriptDir 'strip_nand_ecc.ps1'
$scanScript = Join-Path $scriptDir 'scan_isfs_all_supers.py'

if ($UseConfig) {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    if ($Kind -eq 'slc') {
        $InputPath = Find-RwkmRawDump -Kind slc -SearchRoots $cfg.SearchRoots -ExplicitPath $cfg.SlcRawPath
    } else {
        $InputPath = Find-RwkmRawDump -Kind slccmpt -SearchRoots $cfg.SearchRoots -ExplicitPath $cfg.SlccmptRawPath
    }
    if (-not $StrippedPath) {
        $StrippedPath = Get-RwkmStrippedPath -StrippedDir $cfg.StrippedDir -Kind $Kind -SourceRawPath $InputPath
    }
}

if (-not $InputPath) {
    throw 'Provide -InputPath or -UseConfig'
}

function Test-FwImgPath([string]$StrippedFile) {
    $py = Find-RwkmPython
    $argList = @($py.Args) + @($scanScript, $StrippedFile)
    $out = & $py.Exe @argList 2>&1 | Out-String
    Write-Host $out
    return ($out -match 'fw\.img YES size=')
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input not found: $InputPath"
}

$size = (Get-Item -LiteralPath $InputPath).Length
$toScan = $InputPath

if ($size -eq $stripSize) {
    Write-Host "Input is already stripped ($stripSize bytes)"
} elseif ($size -eq $rawSize) {
    if (-not $StrippedPath) {
        $StrippedPath = [IO.Path]::ChangeExtension($InputPath, '.stripped.bin')
    }
    if (-not $SkipStrip) {
        Write-Host "Stripping ECC (2112->2048) -> $StrippedPath"
        & $stripScript -InputPath $InputPath -OutputPath $StrippedPath
    }
    $toScan = $StrippedPath
} else {
    throw @"
Unexpected size $size for $InputPath

Expected:
  RAW (with ECC):     $rawSize bytes
  Stripped (for SD):  $stripSize bytes

Fix: use a minute SLC.RAW dump, or the .stripped.bin from strip_from_config.ps1.
"@
}

if (Test-FwImgPath $toScan) {
    Write-Host 'PASS: fw.img path is walkable in this SLC image.'
    exit 0
}

Write-Host 'FAIL: no ISFS superblock has a walkable path to fw.img.'
Write-Host 'Do NOT flash this image to redSLC; minute will fail with isfs_open error 5.'
Write-Host 'Fix: dump a clean SLC.RAW from minute on a working console, then strip + validate again.'
exit 1
