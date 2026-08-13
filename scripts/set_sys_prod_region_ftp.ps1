# Switch live sys_prod.xml region fields (experiment for cross-region demos).
# Example: PAL console + USA demos - set product_area / game_region / country to USA.
#
# Does NOT change plastic hardware. Serial stays yours. Keeps WIS-001 / FW if already set.
# WARNING: Do not Submit System Data with WiiUIdent while region is spoofed.
#
# Important: do NOT use [xml] / System.Xml — tag 5ghz_country_code is illegal there.
# We edit with the same regex approach as build_mutant_slc.ps1.

param(
    [ValidateSet('USA', 'PAL', 'Restore')]
    [string]$Mode = 'USA',
    [string]$ConfigPath = '',
    [string]$LocalSysProd = '',
    [string]$BackupDir = '',
    [string]$FtpHost = '',
    [int]$Port = 0,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'set_sys_prod_region_ftp' -Force:$Force

$presets = @{
    USA = @{
        Label                        = 'USA (for USA demos on a non-USA console)'
        product_area                 = '2'
        game_region                  = '2'
        '5ghz_country_code'          = 'US'
        '5ghz_country_code_revision' = '8'
    }
    PAL = @{
        Label                        = 'PAL / EUR'
        product_area                 = '4'
        game_region                  = '4'
        '5ghz_country_code'          = 'EU'
        '5ghz_country_code_revision' = '24'
    }
}

function Get-RwkmXmlTagText([string]$xml, [string]$tag) {
    if ($xml -match "(?s)<$tag[^>]*>\s*([^<]*?)\s*</$tag>") { return $Matches[1].Trim() }
    return $null
}

function Set-RwkmXmlTagText([string]$xml, [string]$tag, [string]$value) {
    if ($xml -notmatch "(?s)<$tag[^>]*>") {
        throw "Tag <$tag> not found in sys_prod.xml - is this a real Wii U dump?"
    }
    return [regex]::Replace($xml, "(?s)(<$tag[^>]*>\s*)[^<]*?(\s*</$tag>)", "`${1}$value`${2}", 1)
}

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    if ($FtpHost) { $cfg.FtpHost = $FtpHost }
    if ($Port) { $cfg.FtpPort = $Port }

    $cred = Get-RwkmFtpCredential -Config $cfg
    $base = Get-RwkmFtpBase -Config $cfg -Mount slc
    $remote = "$base/sys/config/sys_prod.xml"

    $bakRoot = if ($BackupDir) { $BackupDir } else { Join-Path $cfg.LiveSlcBackup 'sys_prod_region_experiments' }
    New-Item -ItemType Directory -Force -Path $bakRoot | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $liveLocal = Join-Path $bakRoot "live_before_${Mode}_$stamp.xml"
    $restorePath = Join-Path $bakRoot 'last_known_good_sys_prod.xml'

    Confirm-RwkmDeploymentMode -Config $cfg -Action "sys_prod.xml region experiment ($Mode)" -Force:$Force | Out-Null

    if ($Mode -eq 'Restore') {
        $src = if ($LocalSysProd) { $LocalSysProd } else { $restorePath }
        if (-not (Test-Path -LiteralPath $src)) {
            throw "No restore file at $src - set -LocalSysProd or run USA/PAL once so last_known_good is saved."
        }
        Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Force:$Force -Action 'Restore sys_prod.xml' -Extra "Local file:`n  $src"
        Assert-RwkmFtpReady -Config $cfg -Mount slc
        Invoke-RwkmFtpPut -LocalPath $src -RemoteUrl $remote -Credential $cred
        Write-RwkmLog "Restored sys_prod.xml from $src"
        Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', $remote, '--user', $cred) -FailContext 'FTP verify' |
            Select-String 'product_area|game_region|5ghz_country_code|code_id|model_number|serial_id'
        Stop-RwkmSession -ExitCode 0
    }

    $preset = $presets[$Mode]
    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Force:$Force -Level Critical -Action "EXPERIMENT: set software region to $($preset.Label)" -Extra @"
Edits live storage_slc sys_prod.xml:
  product_area               -> $($preset.product_area)
  game_region                -> $($preset.game_region)
  5ghz_country_code          -> $($preset.'5ghz_country_code')
  5ghz_country_code_revision -> $($preset.'5ghz_country_code_revision')

Kept: your serial_id, and current model_number / code_id (e.g. WIS-001 / FW).

Risks:
  - Some titles / network features may behave oddly until you Restore.
  - Do NOT use WiiUIdent Submit System Data with a spoofed region.
  - Back up saves first (kiosk user Sarah issue is separate).

PC copies will be saved under:
  $bakRoot
"@

    Assert-RwkmFtpReady -Config $cfg -Mount slc

    if ($LocalSysProd -and (Test-Path -LiteralPath $LocalSysProd)) {
        Copy-Item -LiteralPath $LocalSysProd -Destination $liveLocal -Force
        Write-RwkmLog "Using local base: $LocalSysProd"
    } else {
        Invoke-RwkmFtpGet -RemoteUrl $remote -LocalPath $liveLocal -Credential $cred
        Write-RwkmLog "Downloaded live sys_prod.xml -> $liveLocal"
    }

    if (-not (Test-Path -LiteralPath $restorePath)) {
        Copy-Item -LiteralPath $liveLocal -Destination $restorePath -Force
        Write-RwkmLog "Saved last_known_good: $restorePath"
    } else {
        Copy-Item -LiteralPath $liveLocal -Destination (Join-Path $bakRoot "snapshot_$stamp.xml") -Force
    }

    $text = [IO.File]::ReadAllText($liveLocal)
    $before = @(
        "product_area=$(Get-RwkmXmlTagText $text 'product_area')"
        "game_region=$(Get-RwkmXmlTagText $text 'game_region')"
        "country=$(Get-RwkmXmlTagText $text '5ghz_country_code')"
        "rev=$(Get-RwkmXmlTagText $text '5ghz_country_code_revision')"
        "model=$(Get-RwkmXmlTagText $text 'model_number')"
        "code=$(Get-RwkmXmlTagText $text 'code_id')"
        "serial=$(Get-RwkmXmlTagText $text 'serial_id')"
    ) -join ' '

    $text = Set-RwkmXmlTagText $text 'product_area' $preset.product_area
    $text = Set-RwkmXmlTagText $text 'game_region' $preset.game_region
    $text = Set-RwkmXmlTagText $text '5ghz_country_code' $preset.'5ghz_country_code'
    $text = Set-RwkmXmlTagText $text '5ghz_country_code_revision' $preset.'5ghz_country_code_revision'

    $outFile = Join-Path $bakRoot "sys_prod_${Mode}_$stamp.xml"
    [IO.File]::WriteAllText($outFile, $text)

    $after = @(
        "product_area=$(Get-RwkmXmlTagText $text 'product_area')"
        "game_region=$(Get-RwkmXmlTagText $text 'game_region')"
        "country=$(Get-RwkmXmlTagText $text '5ghz_country_code')"
        "rev=$(Get-RwkmXmlTagText $text '5ghz_country_code_revision')"
        "model=$(Get-RwkmXmlTagText $text 'model_number')"
        "code=$(Get-RwkmXmlTagText $text 'code_id')"
        "serial=$(Get-RwkmXmlTagText $text 'serial_id')"
    ) -join ' '

    Write-RwkmLog "Before: $before"
    Write-RwkmLog "After:  $after"

    Invoke-RwkmFtpPut -LocalPath $outFile -RemoteUrl $remote -Credential $cred
    Write-RwkmLog "Uploaded $outFile -> $remote"
    Write-RwkmLog 'Reboot the Wii U, then try launching a USA demo from SCT.'
    Write-RwkmLog 'Undo: .\scripts\set_sys_prod_region_ftp.ps1 -Mode Restore'
    Write-RwkmLog 'NOTE: Do NOT Submit System Data with WiiUIdent while region is spoofed.'

    Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', $remote, '--user', $cred) -FailContext 'FTP verify' |
        Select-String 'product_area|game_region|5ghz_country_code|code_id|model_number|serial_id'

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
