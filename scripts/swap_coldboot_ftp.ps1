# Swap coldboot by overwriting system.xml via FTP.
# Shows Critical Y/N with Wii U IP + local file before any upload.

param(
    [ValidateSet('home', 'sct', 'kioskmenu')]
    [string]$Mode = 'home',
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
Initialize-RwkmScript -Name 'swap_coldboot_ftp' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    if ($FtpHost) { $cfg.FtpHost = $FtpHost }
    if ($Port) { $cfg.FtpPort = $Port }

    Confirm-RwkmDeploymentMode -Config $cfg -Action "Coldboot swap to '$Mode' on storage_slc" -Force:$Force | Out-Null
    Invoke-RwkmSwapColdbootFtp -Mode $Mode -Config $cfg -MutantConfigDir $MutantConfigDir -Force:$Force

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
