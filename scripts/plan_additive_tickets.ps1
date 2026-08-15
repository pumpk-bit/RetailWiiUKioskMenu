# Compare mutant tickets vs live storage_slc; write tickets_to_upload.json (additive only).
# Does not write to the Wii U — only lists remote tickets and writes a plan on the PC.

param(
    [string]$ConfigPath = '',
    [string]$MutantSlc = '',
    [string]$OutputJson = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'plan_additive_tickets' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $mutant = if ($MutantSlc) { $MutantSlc } else { $cfg.MutantSlc }
    $tikRoot = Join-Path $mutant 'sys\rights\ticket'
    $out = if ($OutputJson) { $OutputJson } else { Join-Path $cfg.LiveSlcBackup 'tickets_to_upload.json' }

    Assert-RwkmMutantReady -MutantSlc $mutant -RequiredRelPaths @('sys\rights\ticket')
    if (-not (Test-Path -LiteralPath $tikRoot)) {
        throw "Missing mutant tickets: $tikRoot - run build_mutant_slc.ps1 first"
    }

    Confirm-RwkmDeploymentMode -Config $cfg -Action 'LIST live tickets via FTP (read-only) and write a local upload plan' -Force:$Force | Out-Null

    $listPrompt = @(
        'Connect to the Wii U and list tickets under storage_slc (read-only).'
        ''
        "  Wii U:   $($cfg.FtpHost)"
        "  Mutant:  $mutant"
        "  Plan ->  $out"
        ''
        'No files are written to the console in this step. Continue?'
    ) -join "`n"
    if (-not (Confirm-Rwkm -Level Normal -Prompt $listPrompt -Force:$Force)) {
        throw 'Cancelled: ticket plan not confirmed.'
    }

    Assert-RwkmFtpReady -Config $cfg -Mount slc

    $cred = Get-RwkmFtpCredential -Config $cfg
    $base = Get-RwkmFtpBase -Config $cfg -Mount slc
    $live = Get-RwkmLiveTicketSet -FtpSlcBase $base -Credential $cred

    $plan = @()
    $skipped = @()
    foreach ($f in (Get-ChildItem $tikRoot -Recurse -Filter *.tik)) {
        $rel = Get-RwkmRelativeUnixPath -Root $tikRoot -FullPath $f.FullName
        if ($live.Contains($rel)) {
            $skipped += $rel
            continue
        }
        $plan += [ordered]@{
            Rel  = $rel
            Path = $f.FullName
            Len  = $f.Length
        }
    }

    $outDir = Split-Path -Parent $out
    if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

    if (Test-Path -LiteralPath $out) {
        Confirm-RwkmFileWrite -Source '(generated plan)' -Destination $out `
            -Description 'Overwrite previous tickets_to_upload.json' -Level Normal -Force:$Force
    }

    Write-RwkmJsonArrayFile -Path $out -Items $plan
    $skipped | Set-Content -LiteralPath (Join-Path $outDir 'tickets_skipped.txt') -Encoding UTF8

    Write-RwkmLog "New tickets to upload: $($plan.Count)"
    Write-RwkmLog "Skipped (already on live): $($skipped.Count)"
    Write-RwkmLog "Plan: $out"
    Write-RwkmLog 'Next: .\scripts\apply_mutant_slc_ftp.ps1'

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
