# Restore retail idle behavior: set reset_enable=0 in live storage_slc im_cfg.xml.
#
# Kiosk Menu / demos can set reset_enable=1 (~120s idle reboot). This script patches
# the on-disk Idle Manager prefs via FTP (uses config\config.ps1 for FtpHost / mode).
#
# Usage:
#   .\scripts\restore_im_cfg_ftp.ps1                  # patch live file in place
#   .\scripts\restore_im_cfg_ftp.ps1 -Mode RestoreRetail   # upload retail dump copy

param(
    [ValidateSet('Patch', 'RestoreRetail')]
    [string]$Mode = 'Patch',
    [string]$ConfigPath = '',
    [string]$LocalImCfg = '',
    [string]$BackupDir = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'restore_im_cfg_ftp' -Force:$Force

function Get-RwkmXmlTagText([string]$xml, [string]$tag) {
    if ($xml -match "(?s)<$tag[^>]*>\s*([^<]*?)\s*</$tag>") { return $Matches[1].Trim() }
    return $null
}

function Set-RwkmXmlTagText([string]$xml, [string]$tag, [string]$value) {
    if ($xml -notmatch "(?s)<$tag[^>]*>") {
        throw "Tag <$tag> not found in im_cfg.xml"
    }
    return [regex]::Replace($xml, "(?s)(<$tag[^>]*>\s*)[^<]*?(\s*</$tag>)", "`${1}$value`${2}", 1)
}

function Get-RwkmImCfgRestoreWarning {
    param([string]$Mode, [string]$Remote, [string]$HostName, [string]$DeployMode)
    $action = if ($Mode -eq 'RestoreRetail') {
        'Replace live im_cfg.xml with your retail SLC extract copy.'
    } else {
        'Download live im_cfg.xml, set <reset_enable>0</reset_enable>, upload back.'
    }
    return @(
        $action
        ''
        'WHAT THIS FIXES:'
        '  Kiosk software can set reset_enable=1 (idle reboot ~120s outside Kiosk Menu).'
        '  Retail keeps reset_enable=0.'
        ''
        'SLC WRITE WARNING:'
        '  Target file: storage_slc/sys/proc/prefs/im_cfg.xml'
        "  Wii U IP:    $HostName (from config\config.ps1)"
        "  Remote URL:  $Remote"
        "  Mode:        $DeployMode"
        ''
        '  SysNand mode writes REAL internal SLC - wrong boot layout or bad file = brick risk.'
        '  Have an offline minute SLC backup before any live SLC edit.'
        '  Hybrid / FullRedNand: confirm FTP hits the SLC you intend (SD vs internal).'
        ''
        'RestoreRetail overwrites the whole file - other im_cfg fields come from your PC dump.'
        'Patch mode only changes reset_enable and keeps the rest of the live file.'
    ) -join "`n"
}

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $cred = Get-RwkmFtpCredential -Config $cfg
    $base = Get-RwkmFtpBase -Config $cfg -Mount slc
    $remote = "$base/sys/proc/prefs/im_cfg.xml"

    $bakRoot = if ($BackupDir) { $BackupDir } else { Join-Path $cfg.LiveSlcBackup 'im_cfg_restore' }
    New-Item -ItemType Directory -Force -Path $bakRoot | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $liveLocal = Join-Path $bakRoot "live_before_$stamp.xml"
    $restorePath = Join-Path $bakRoot 'last_known_good_im_cfg.xml'

    $deployMode = Confirm-RwkmDeploymentMode -Config $cfg -Action "restore im_cfg.xml (idle reboot fix, $Mode)" -Force:$Force

    $warnExtra = Get-RwkmImCfgRestoreWarning -Mode $Mode -Remote $remote -HostName $cfg.FtpHost -DeployMode $deployMode

    if ($Mode -eq 'RestoreRetail') {
        $src = if ($LocalImCfg) {
            $LocalImCfg
        } elseif ($cfg.RetailSlcExtract) {
            Join-Path $cfg.RetailSlcExtract 'sys\proc\prefs\im_cfg.xml'
        } else {
            ''
        }
        if (-not $src -or -not (Test-Path -LiteralPath $src)) {
            throw @"
No retail im_cfg.xml source. Use -LocalImCfg or set RetailSlcExtract in config.ps1.
Example: RetailSlcExtract = '..\WiiUDumps\WiiU Retail EUR\slc'
"@
        }
        Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Force:$Force -Level Critical `
            -Action 'Upload retail im_cfg.xml (full file replace)' -Extra @"
$warnExtra

Local source:
  $src
"@
        Assert-RwkmFtpReady -Config $cfg -Mount slc
        Invoke-RwkmFtpGet -RemoteUrl $remote -LocalPath $liveLocal -Credential $cred
        Copy-Item -LiteralPath $liveLocal -Destination (Join-Path $bakRoot "backup_before_retail_$stamp.xml") -Force
        $backupRetailPath = Join-Path $bakRoot "backup_before_retail_$stamp.xml"
        Write-RwkmLog "Backed up live im_cfg -> $backupRetailPath"
        Invoke-RwkmFtpPut -LocalPath $src -RemoteUrl $remote -Credential $cred
        Write-RwkmLog "Uploaded retail im_cfg.xml from $src"
        Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', $remote, '--user', $cred) -FailContext 'FTP verify' |
            Select-String 'reset_enable|reset_secnds|apd_enable'
        Write-RwkmLog 'Done. Idle reboot should stay off after reboot.'
        Stop-RwkmSession -ExitCode 0
    }

    Assert-RwkmFtpReady -Config $cfg -Mount slc

    Invoke-RwkmFtpGet -RemoteUrl $remote -LocalPath $liveLocal -Credential $cred
    Write-RwkmLog "Downloaded live im_cfg.xml -> $liveLocal"

    if (-not (Test-Path -LiteralPath $restorePath)) {
        Copy-Item -LiteralPath $liveLocal -Destination $restorePath -Force
        Write-RwkmLog "Saved last_known_good: $restorePath"
    } else {
        Copy-Item -LiteralPath $liveLocal -Destination (Join-Path $bakRoot "snapshot_$stamp.xml") -Force
    }

    $text = [IO.File]::ReadAllText($liveLocal)
    $beforeEnable = Get-RwkmXmlTagText $text 'reset_enable'
    $before = @(
        "reset_enable=$beforeEnable"
        "reset_secnds=$(Get-RwkmXmlTagText $text 'reset_secnds')"
        "apd_enable=$(Get-RwkmXmlTagText $text 'apd_enable')"
    ) -join ' '

    if ($beforeEnable -eq '0') {
        Write-RwkmLog 'reset_enable already 0 on live SLC - nothing to upload.'
        Write-RwkmLog "Before: $before"
        Stop-RwkmSession -ExitCode 0
    }

    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Force:$Force -Level Critical `
        -Action 'Patch im_cfg.xml reset_enable=0' -Extra @"
$warnExtra

PC backup folder:
  $bakRoot

Live before patch: $before
"@

    $text = Set-RwkmXmlTagText $text 'reset_enable' '0'

    $outFile = Join-Path $bakRoot "im_cfg_patched_$stamp.xml"
    [IO.File]::WriteAllText($outFile, $text)

    $after = @(
        "reset_enable=$(Get-RwkmXmlTagText $text 'reset_enable')"
        "reset_secnds=$(Get-RwkmXmlTagText $text 'reset_secnds')"
        "apd_enable=$(Get-RwkmXmlTagText $text 'apd_enable')"
    ) -join ' '

    Write-RwkmLog "Before: $before"
    Write-RwkmLog "After:  $after"

    Invoke-RwkmFtpPut -LocalPath $outFile -RemoteUrl $remote -Credential $cred
    Write-RwkmLog "Uploaded $outFile -> $remote"
    Write-RwkmLog 'Done. Idle reboot should stay off after reboot.'

    Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', $remote, '--user', $cred) -FailContext 'FTP verify' |
        Select-String 'reset_enable|reset_secnds|apd_enable'

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
