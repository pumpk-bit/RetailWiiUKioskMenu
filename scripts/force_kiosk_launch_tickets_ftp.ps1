# Force-upload Kiosk Menu + native SCT tickets that additive apply may skip.
#
# plan_additive_tickets.ps1 skips paths already on live SLC (retail bytes).
# Kiosk launch needs kiosk .tik bytes at the same paths. Uses config\config.ps1.
#
# Usage:
#   .\scripts\force_kiosk_launch_tickets_ftp.ps1

param(
    [string]$ConfigPath = '',
    [string]$MutantSlc = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'force_kiosk_launch_tickets' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $cred = Get-RwkmFtpCredential -Config $cfg
    $base = Get-RwkmFtpBase -Config $cfg -Mount slc
    $m = if ($MutantSlc) { $MutantSlc } else { $cfg.MutantSlc }
    Assert-RwkmMutantReady -MutantSlc $m -RequiredRelPaths @(
        'sys\rights\ticket\sys\0001\0000000b.tik'
        'sys\rights\ticket\sys\0003\00000002.tik'
    )

    $tickets = @(
        @{
            Rel   = 'sys/rights/ticket/sys/0001/0000000b.tik'
            Title = 'Kiosk Menu (1fa81000)'
        }
        @{
            Rel   = 'sys/rights/ticket/sys/0003/00000002.tik'
            Title = 'Native SCT (1f700500)'
        }
    )

    $list = ($tickets | ForEach-Object { "  $($_.Rel)  - $($_.Title)" }) -join "`n"
    $extra = @"
Overwrite live SLC tickets with kiosk bytes from mutant:

$list

Local mutant: $m
Remote base:  $base

WHY:
  Additive apply skips these paths when retail already has a .tik there.
  SCT / Kiosk Menu then show 'Cannot launch this title' even with MLC uploaded.

AFTER:
  Reboot, then Home -> SCT -> Kiosk Menu (Title Type: Menu).
  Confirm cert.sys is ~6656 bytes if launch still fails.
"@

    Confirm-RwkmDeploymentMode -Config $cfg -Action 'force-upload Kiosk Menu + native SCT tickets' -Force:$Force | Out-Null
    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Action 'Overwrite Kiosk Menu + native SCT .tik on live SLC' -Extra $extra -Force:$Force | Out-Null
    Assert-RwkmFtpReady -Config $cfg -Mount slc

    $bakRoot = Join-Path $cfg.LiveSlcBackup 'force_launch_tickets'
    New-Item -ItemType Directory -Force -Path $bakRoot | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

    foreach ($t in $tickets) {
        $remote = "$base/$($t.Rel)"
        $bak = Join-Path $bakRoot ("{0}_{1}" -f $stamp, ($t.Rel -replace '[/\\]', '_'))
        try {
            Invoke-RwkmFtpGet -RemoteUrl $remote -LocalPath $bak -Credential $cred
            Write-RwkmLog "Backed up live $($t.Rel) -> $bak"
        } catch {
            Write-RwkmLog "WARN: could not download live $($t.Rel) before overwrite - $($_.Exception.Message)"
        }
    }

    $null = Invoke-RwkmForceKioskLaunchTickets -MutantSlc $m -FtpSlcBase $base -Credential $cred

    Write-RwkmLog 'Reboot, then Home -> SCT -> Kiosk Menu (Title Type: Menu).'
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
