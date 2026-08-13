# Set Kiosk Menu as the default boot title (via FTP) while Home Menu still works.
# WARNING: once coldboot is Kiosk Menu, Home never loads -> FTP plugins never start.
# Recovery is a reflash (redNAND SD partition or SysNand minute restore), not make_home_menu_default.ps1.

param(
    [string]$ConfigPath = '',
    [string]$MutantConfigDir = '',
    [string]$FtpHost = '',
    [int]$Port = 0,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'make_kiosk_menu_default' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    if ($FtpHost) { $cfg.FtpHost = $FtpHost }
    if ($Port) { $cfg.FtpPort = $Port }

    Confirm-RwkmDeploymentMode -Config $cfg -Action 'Set Kiosk Menu as DEFAULT BOOT (storage_slc system.xml)' -Force:$Force | Out-Null

    # Single Critical confirm inside Invoke-RwkmSwapColdbootFtp includes trap text + FtpHost.
    Invoke-RwkmSwapColdbootFtp -Mode kioskmenu -Config $cfg -MutantConfigDir $MutantConfigDir -Force:$Force

    Write-RwkmLog 'Done. Reboot the Wii U to test.'
    Write-RwkmLog 'If trapped: reflash SLC (FTP undo will not work - no Home Menu / no plugins).'

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
