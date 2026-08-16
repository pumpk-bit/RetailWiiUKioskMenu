# Build a retail-compatible Kiosk Home Button Menu overlay on the PC (no FTP).
# Docs: docs\AI\EXPERIMENTAL.MD
#
# Prefer the live applicator for day-to-day use:
#   .\scripts\apply_kiosk_hbm_ftp.ps1 -ReferenceHomeRoot 'D:\path\to\known-good\1001020a' -Force
#
# Examples:
#   .\scripts\build_kiosk_hbm_mlc.ps1 -RetailHomeRoot 'D:\retail\1001020a' -ReferenceHomeRoot 'D:\known-good\1001020a' -Force
#   .\scripts\build_kiosk_hbm_mlc.ps1 -VerifyOnly -KioskHomeRoot '...' -RetailHomeRoot '...' -ReferenceHomeRoot '...'

param(
    [string]$ConfigPath = '',
    [string]$KioskHomeRoot = '',
    [string]$RetailHomeRoot = '',
    [string]$ReferenceHomeRoot = '',
    [string]$OutputRoot = '',
    [string]$TitleId = '',
    [switch]$VerifyOnly,
    [switch]$SkipReferenceTmd,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Region.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Hbm.ps1')
Initialize-RwkmScript -Name 'build_kiosk_hbm_mlc' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $titleId = if ($TitleId) {
        $TitleId.ToLowerInvariant()
    } else {
        Get-RwkmHbmTitleIdForRegion -Region $cfg.Region
    }

    if (-not $RetailHomeRoot) {
        throw @"
Retail HOME folder is required (not shipped in this repo).

Example (EUR):
  .\scripts\build_kiosk_hbm_mlc.ps1 -RetailHomeRoot 'C:\path\to\00050030\1001020a'

Or use the FTP applicator (downloads live HOME for you):
  .\scripts\apply_kiosk_hbm_ftp.ps1 -ReferenceHomeRoot 'C:\path\to\known-good\1001020a' -Force
"@
    }

    $kioskRoot = Resolve-RwkmHbmTitleFolder -ExplicitRoot $KioskHomeRoot `
        -SearchHint $cfg.KioskMlcSysTitleRoot -TitleId $titleId -Label 'Kiosk'
    $retailRoot = Resolve-RwkmHbmTitleFolder -ExplicitRoot $RetailHomeRoot `
        -SearchHint '' -TitleId $titleId -Label 'Retail'

    $referenceRoot = $null
    if ($ReferenceHomeRoot) {
        $referenceRoot = Resolve-RwkmHbmTitleFolder -ExplicitRoot $ReferenceHomeRoot -SearchHint '' -TitleId $titleId -Label 'Reference'
    }

    $outRoot = if ($OutputRoot) {
        $OutputRoot
    } else {
        Join-Path (Get-RwkmRepoRoot) "overlay\mutant\mlc\sys\title\00050030\$titleId"
    }

    Write-RwkmLog '=== Kiosk HBM compat build ==='
    Write-RwkmLog "Region:    $($cfg.Region)"
    Write-RwkmLog "Title ID:  00050030-$titleId"
    Write-RwkmLog "Kiosk:     $kioskRoot"
    Write-RwkmLog "Retail:    $retailRoot"
    if ($referenceRoot) { Write-RwkmLog "Reference: $referenceRoot" }
    Write-RwkmLog "Output:    $outRoot"

    $kioskIssues = Test-RwkmKioskHbmSource -Root $kioskRoot
    $retailIssues = Test-RwkmRetailHomeSource -Root $retailRoot
    foreach ($i in $kioskIssues) { Write-RwkmLog "VERIFY kiosk: $i" }
    foreach ($i in $retailIssues) { Write-RwkmLog "VERIFY retail: $i" }
    if ($kioskIssues.Count -gt 0 -or $retailIssues.Count -gt 0) {
        throw 'Verification failed. Fix the source folders and re-run.'
    }
    Write-RwkmLog 'VERIFY: kiosk + retail sources look usable.'

    if ($referenceRoot) {
        $refRpx = Join-Path $referenceRoot 'code\kiosk_hbm.rpx'
        if (Test-Path -LiteralPath $refRpx) {
            $dumpHash = Get-RwkmFileSha256 (Join-Path $kioskRoot 'code\kiosk_hbm.rpx')
            $refHash = Get-RwkmFileSha256 $refRpx
            if ($dumpHash -eq $refHash) {
                Write-RwkmLog 'VERIFY: reference RPX matches kiosk dump.'
            } else {
                Write-RwkmLog "WARN: reference RPX hash differs from dump.`n  dump=$dumpHash`n  ref =$refHash"
            }
        }
    }

    if ($VerifyOnly) {
        Write-RwkmLog 'VerifyOnly: no output written.'
        Stop-RwkmSession -ExitCode 0
        return
    }

    Confirm-RwkmFileWrite -Source $kioskRoot -Destination $outRoot -Level Critical -Force:$Force -Description @"
Build retail-compatible Kiosk Home Button Menu overlay (PC only).

Does NOT FTP. For automatic live replace use:
  .\scripts\apply_kiosk_hbm_ftp.ps1 -ReferenceHomeRoot '...' -Force
"@

    $refArg = if ($referenceRoot) { $referenceRoot } else { '' }
    $build = Build-RwkmCompatHbmTree -KioskRoot $kioskRoot -RetailRoot $retailRoot `
        -OutputRoot $outRoot -ReferenceRoot $refArg -RequireReferenceTmd:$false
    Write-RwkmLog "Output meta product_code=$($build.ProductCode) title_version=$($build.TitleVersion)"

    if ($referenceRoot) {
        $null = Compare-RwkmHbmToReference -BuiltRoot $outRoot -ReferenceRoot $referenceRoot
    }

    Write-RwkmLog ''
    Write-RwkmLog 'Done.'
    Write-RwkmLog "Overlay ready at: $outRoot"
    if (-not $build.UsedReferenceTmd) {
        Write-RwkmLog 'NOTE: Without reference TMD/FST this may fail on retail OS. Prefer apply_kiosk_hbm_ftp.ps1 with -ReferenceHomeRoot.'
    }
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
