# Install or clear minute rednand.ini according to DeploymentMode.

param(
    [string]$ConfigPath = '',
    [string]$IniSource = '',
    [string]$DestIni = '',
    [ValidateSet('', 'Hybrid', 'FullRedNand', 'SysNand')]
    [string]$Mode = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Disk.ps1')
Initialize-RwkmScript -Name 'install_rednand_ini' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $repo = Get-RwkmRepoRoot
    $mode = if ($Mode) { $Mode } else { Get-RwkmDeploymentMode -Config $cfg }

    if ($mode -eq 'SysNand' -and -not $DestIni) {
        $letter = Get-RwkmNormalizedDriveLetter $cfg.SdDriveLetter
        if (-not $letter) {
            Write-RwkmLog 'SysNand: SdDriveLetter is not set — no SD rednand.ini to disable.'
            Write-RwkmLog 'Boot minute: Patch (slc) -> boot IOS (slc). Do not boot redNAND.'
            Stop-RwkmSession -ExitCode 0
        }
        $probeMinute = "${letter}:\minute"
        if (-not (Test-Path -LiteralPath $probeMinute)) {
            Write-RwkmLog "SysNand: $probeMinute not found (SD not inserted?). Nothing to disable."
            Write-RwkmLog 'Boot minute: Patch (slc) -> boot IOS (slc). Do not boot redNAND.'
            Stop-RwkmSession -ExitCode 0
        }
    }

    $dst = if ($DestIni) { $DestIni } else { Get-RwkmMinuteIniPath -Config $cfg }

    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstDir)) {
        throw @"
SD minute folder not found: $dstDir

Fix:
  1) Insert the redNAND SD.
  2) In This PC, find the drive that contains \minute\ (do not guess the letter).
  3) Set SdDriveLetter in config.ps1 to that letter, or re-run .\scripts\setup_config.ps1
"@
    }

    if ($mode -eq 'SysNand') {
        $disablePrompt = @(
            "DeploymentMode = SysNand"
            ''
            'This will DISABLE redNAND by renaming rednand.ini (if present) so the console uses sys SLC/MLC.'
            "Target: $dst"
            ''
            'After reboot (no redNAND), FTP storage_slc / storage_mlc are INTERNAL.'
            'Only then run apply_mutant_slc_ftp / upload_sys_title_mlc for real CAT-I on console.'
        ) -join "`n"
        if (-not (Confirm-Rwkm -Level Critical -Prompt $disablePrompt -Force:$Force)) {
            throw 'Cancelled: SysNand redNAND disable not confirmed.'
        }
        if (Test-Path -LiteralPath $dst) {
            $bak = "$dst.disabled_for_sysnand_$(Get-Date -Format yyyyMMdd_HHmmss)"
            Move-Item -LiteralPath $dst -Destination $bak -Force
            Write-RwkmLog "Renamed $dst -> $bak"
        } else {
            Write-RwkmLog "No rednand.ini at $dst (already using sysNAND layout)."
        }
        Write-RwkmLog 'Next: reboot without redNAND, confirm FTP paths, then apply mutant with DeploymentMode SysNand.'
        Stop-RwkmSession -ExitCode 0
    }

    $src = if ($IniSource) {
        $IniSource
    } else {
        Get-RwkmRednandIniForMode -Mode $mode -RepoRoot $repo
    }
    if (-not (Test-Path -LiteralPath $src)) { throw "Missing ini template: $src" }

    $diskNum = Get-RwkmSdDiskNumber -Config $cfg
    Test-RwkmRedNandLayout -DiskNum $diskNum -Config $cfg -Force:$Force | Out-Null

    $iniDesc = switch ($mode) {
        'Hybrid' {
            'Install Hybrid rednand.ini: redSLC on SD + sys MLC. Keep SD inserted while Kiosk Menu runs.'
        }
        'FullRedNand' {
            'Install Full redNAND ini: SLC+MLC on SD. Retail sys MLC games are separate unless copied.'
        }
        default { "Install rednand.ini for mode $mode" }
    }
    Confirm-RwkmFileWrite -Source $src -Destination $dst -Description $iniDesc -Level Critical -Force:$Force

    Copy-Item -Force -LiteralPath $src -Destination $dst
    Write-RwkmLog "Mode=$mode Installed: $dst (from $src)"
    Get-Content -LiteralPath $dst | ForEach-Object { Write-RwkmLog $_ }

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
