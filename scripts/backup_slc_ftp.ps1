# Backup live storage_slc files via FTP before applying mutant overlay.
# Read-only on the Wii U, but overwrites the local backup folder — confirm that too.

param(
    [string]$ConfigPath = '',
    [string]$BackupDir = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'backup_slc_ftp' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $bak = if ($BackupDir) { $BackupDir } else { $cfg.LiveSlcBackup }
    $cred = Get-RwkmFtpCredential -Config $cfg
    $base = Get-RwkmFtpBase -Config $cfg -Mount slc

    $mode = Confirm-RwkmDeploymentMode -Config $cfg -Action 'DOWNLOAD (backup) live storage_slc to PC' -Force:$Force

    $backupPrompt = @(
        'Download key SLC files from the Wii U to this PC folder:'
        ''
        "  Folder:  $bak"
        "  Wii U:   $($cfg.FtpHost)"
        "  Mode:    $mode"
        ''
        'This overwrites any previous files in that backup folder.'
        'Wrong DeploymentMode = you may back up redSLC when you meant sysNAND (or vice versa).'
        ''
        'Continue?'
    ) -join "`n"
    if (-not (Confirm-Rwkm -Level Warning -Prompt $backupPrompt -Force:$Force)) {
        throw 'Cancelled: SLC backup not confirmed.'
    }

    Assert-RwkmFtpReady -Config $cfg -Mount slc

    New-Item -ItemType Directory -Force -Path $bak | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $bak 'rights\sys') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $bak 'config') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $bak 'prefs') | Out-Null

    Write-RwkmLog "Backing up storage_slc from $($cfg.FtpHost) -> $bak"

    $files = @(
        @{ Remote = 'sys/rights/sys/cert.sys'; Local = 'rights\sys\cert.sys' },
        @{ Remote = 'sys/rights/sys/title.list'; Local = 'rights\sys\title.list' },
        @{ Remote = 'sys/config/system.xml'; Local = 'config\system.xml' },
        @{ Remote = 'sys/config/sys_prod.xml'; Local = 'config\sys_prod.xml' },
        @{ Remote = 'sys/config/eco.xml'; Local = 'config\eco.xml' },
        @{ Remote = 'sys/proc/prefs/im_cfg.xml'; Local = 'prefs\im_cfg.xml' },
        @{ Remote = 'sys/proc/prefs/caffeine.xml'; Local = 'prefs\caffeine.xml' },
        @{ Remote = 'sys/proc/prefs/nn.xml'; Local = 'prefs\nn.xml' }
    )

    foreach ($f in $files) {
        $local = Join-Path $bak $f.Local
        Invoke-RwkmFtpGet -RemoteUrl "$base/$($f.Remote)" -LocalPath $local -Credential $cred
        Write-RwkmLog "  ok $($f.Local)"
    }

    Write-RwkmLog "Backup complete: $bak"
    Write-RwkmLog 'Next: plan_additive_tickets.ps1 then apply_mutant_slc_ftp.ps1'
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
