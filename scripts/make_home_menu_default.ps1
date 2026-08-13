# Restore Home Menu as the default boot title via FTP.
# Only works while Home Menu still boots (FTP plugins load from Home).
# If already stuck in Kiosk Menu coldboot: reflash SLC instead.

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
Initialize-RwkmScript -Name 'make_home_menu_default' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    if ($FtpHost) { $cfg.FtpHost = $FtpHost }
    if ($Port) { $cfg.FtpPort = $Port }

    Confirm-RwkmDeploymentMode -Config $cfg -Action 'Restore HOME MENU as default boot (storage_slc system.xml)' -Force:$Force | Out-Null

    Invoke-RwkmSwapColdbootFtp -Mode home -Config $cfg -MutantConfigDir $MutantConfigDir -Force:$Force

    Write-RwkmLog 'Done. Reboot the Wii U - you should land on Home Menu.'

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
