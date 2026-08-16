# Apply Kiosk Home Button Menu (00050030/10010x0a) via FTP.
# Docs: docs\AI\EXPERIMENTAL.MD
#
# 1) Download live HOME from storage_mlc (backup)
# 2) Build patched tree (kiosk payload + live retail identity + reference TMD/FST)
# 3) Compare to known-good reference (abort if critical mismatch)
# 4) Upload patched files (overwrite), then delete remote orphans (e.g. hbm.rpx)
# 5) Re-download critical remotes and hash-check
# 6) Restart the Wii U
#
# Safer than delete-first: HOME is never left empty mid-flight.
#
# Example (PAL):
#   .\scripts\apply_kiosk_hbm_ftp.ps1 -ReferenceHomeRoot 'D:\path\to\known-good\1001020a' -Force
#
# -ReferenceHomeRoot must be a working HBM extract with resigned title.tmd / title.fst
# (raw kiosk TMD alone usually fails on modern retail OS).

param(
    [string]$ConfigPath = '',
    [string]$KioskHomeRoot = '',
    [string]$ReferenceHomeRoot = '',
    [string]$TitleId = '',
    [string]$WorkRoot = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Region.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Hbm.ps1')
Initialize-RwkmScript -Name 'apply_kiosk_hbm_ftp' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $titleId = if ($TitleId) { $TitleId.ToLowerInvariant() } else { Get-RwkmHbmTitleIdForRegion -Region $cfg.Region }

    if (-not $ReferenceHomeRoot) {
        throw @"
-ReferenceHomeRoot is required (known-good working HBM extract with resigned title.tmd/title.fst).

Example:
  .\scripts\apply_kiosk_hbm_ftp.ps1 -ReferenceHomeRoot 'D:\path\to\known-good\1001020a' -Force

See docs\AI\EXPERIMENTAL.MD
"@
    }

    $kioskRoot = Resolve-RwkmHbmTitleFolder -ExplicitRoot $KioskHomeRoot `
        -SearchHint $cfg.KioskMlcSysTitleRoot -TitleId $titleId -Label 'Kiosk'
    $referenceRoot = Resolve-RwkmHbmTitleFolder -ExplicitRoot $ReferenceHomeRoot `
        -SearchHint '' -TitleId $titleId -Label 'Reference'

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $workRoot = if ($WorkRoot) {
        $WorkRoot
    } else {
        Join-Path (Get-RwkmRepoRoot) "backup\hbm_ftp_$stamp"
    }
    $liveRoot = Join-Path $workRoot '01_live_mlc_download'
    $patchedRoot = Join-Path $workRoot '02_patched'
    $verifyRoot = Join-Path $workRoot '03_remote_verify'

    $cred = Get-RwkmFtpCredential -Config $cfg
    $mlcBase = Get-RwkmFtpBase -Config $cfg -Mount mlc
    $remoteTitle = "$mlcBase/sys/title/00050030/$titleId"

    Write-RwkmLog '=== Apply Kiosk HBM via FTP ==='
    Write-RwkmLog "Region:     $($cfg.Region)"
    Write-RwkmLog "Title:      00050030-$titleId"
    Write-RwkmLog "FtpHost:    $($cfg.FtpHost)"
    Write-RwkmLog "Mode:       $(Get-RwkmDeploymentMode -Config $cfg)"
    Write-RwkmLog "Kiosk dump: $kioskRoot"
    Write-RwkmLog "Reference:  $referenceRoot"
    Write-RwkmLog "Work dir:   $workRoot"
    Write-RwkmLog "Remote:     $remoteTitle"
    Write-RwkmLog ''

    Confirm-RwkmDeploymentMode -Config $cfg -Action 'REPLACE Home Button Menu on storage_mlc' -Force:$Force | Out-Null
    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount mlc -Force:$Force -Level Critical -Action 'Replace HOME overlay (kiosk HBM)' -Extra @"
  Remote: $remoteTitle
  Backup: $liveRoot
  Patch:  $patchedRoot

Order used by this script (safe):
  1) Download live HOME (backup)
  2) Build + compare to reference (abort if mismatch)
  3) Upload patched files (overwrite)
  4) Delete remote orphans (e.g. hbm.rpx)
  5) Re-download critical files and hash-check
  6) You restart the Wii U

HOME is never left empty. Still: prefer redNAND. Have a restore path.
See docs\AI\EXPERIMENTAL.MD
"@

    Assert-RwkmFtpReady -Config $cfg -Mount mlc

    if (-not (Test-RwkmFtpRemoteDir -RemoteDirUrl $remoteTitle -Credential $cred)) {
        throw "Remote HOME title folder not found: $remoteTitle"
    }

    # --- 1) Download live ---
    Write-RwkmLog 'STEP 1/6: Download live HOME from MLC...'
    if (Test-Path -LiteralPath $liveRoot) { Remove-Item -LiteralPath $liveRoot -Recurse -Force }
    $got = Invoke-RwkmFtpDownloadTree -RemoteDirUrl $remoteTitle -LocalDir $liveRoot -Credential $cred
    Write-RwkmLog "Downloaded $got files -> $liveRoot"

    $liveIssues = Test-RwkmRetailHomeSource -Root $liveRoot
    foreach ($i in $liveIssues) { Write-RwkmLog "LIVE check: $i" }
    if ($liveIssues.Count -gt 0) {
        throw @"
Live MLC HOME does not look like retail HOME (need hbm.rpx + app/cos/meta).
Backup kept at: $liveRoot
Fix: restore retail 00050030/$titleId first, then re-run.
"@
    }
    Write-RwkmLog 'LIVE: retail HOME identity confirmed (hbm.rpx present).'

    # --- 2) Patch ---
    Write-RwkmLog 'STEP 2/6: Build patched tree...'
    $build = Build-RwkmCompatHbmTree -KioskRoot $kioskRoot -RetailRoot $liveRoot `
        -OutputRoot $patchedRoot -ReferenceRoot $referenceRoot -RequireReferenceTmd
    Write-RwkmLog "Patched meta product_code=$($build.ProductCode) title_version=$($build.TitleVersion)"

    # --- 3) Compare ---
    Write-RwkmLog 'STEP 3/6: Compare patched tree to reference (must match critical files)...'
    $null = Compare-RwkmHbmToReference -BuiltRoot $patchedRoot -ReferenceRoot $referenceRoot -RequireExactCritical
    Write-RwkmLog 'COMPARE: critical files MATCH reference.'

    # --- 4) Upload overwrite ---
    Write-RwkmLog 'STEP 4/6: Upload patched files (overwrite in place)...'
    $localFiles = Get-ChildItem -LiteralPath $patchedRoot -Recurse -File
    $i = 0
    foreach ($file in $localFiles) {
        $i++
        $rel = Get-RwkmRelativeUnixPath -Root $patchedRoot -FullPath $file.FullName
        $remote = "$remoteTitle/$rel"
        Write-RwkmLog "  PUT [$i/$($localFiles.Count)] $rel"
        Invoke-RwkmFtpPut -LocalPath $file.FullName -RemoteUrl $remote -Credential $cred
    }

    # --- 5) Delete orphans ---
    Write-RwkmLog 'STEP 5/6: Delete remote orphans not in patched tree...'
    $localRelSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $localFiles) {
        $rel = Get-RwkmRelativeUnixPath -Root $patchedRoot -FullPath $file.FullName
        [void]$localRelSet.Add($rel)
    }
    $remoteRels = Get-RwkmFtpRelativeFiles -RemoteDirUrl $remoteTitle -Credential $cred
    $deleted = 0
    foreach ($rel in $remoteRels) {
        if (-not $localRelSet.Contains($rel)) {
            Write-RwkmLog "  DELE orphan $rel"
            Invoke-RwkmFtpDelete -RemoteUrl "$remoteTitle/$rel" -Credential $cred
            $deleted++
        }
    }
    Write-RwkmLog "Deleted $deleted orphan remote file(s)."

    # Explicit guarantee: retail RPX must be gone
    if (Test-RwkmFtpRemoteExists -RemoteUrl "$remoteTitle/code/hbm.rpx" -Credential $cred) {
        Write-RwkmLog '  DELE leftover code/hbm.rpx'
        Invoke-RwkmFtpDelete -RemoteUrl "$remoteTitle/code/hbm.rpx" -Credential $cred
    }
    if (-not (Test-RwkmFtpRemoteExists -RemoteUrl "$remoteTitle/code/kiosk_hbm.rpx" -Credential $cred)) {
        throw 'After upload, remote code/kiosk_hbm.rpx is missing. Aborting before reboot advice.'
    }

    # --- 6) Remote verify ---
    Write-RwkmLog 'STEP 6/6: Re-download critical remotes and hash-check...'
    if (Test-Path -LiteralPath $verifyRoot) { Remove-Item -LiteralPath $verifyRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Join-Path $verifyRoot 'code') | Out-Null
    $spot = @(
        'code/app.xml',
        'code/cos.xml',
        'code/kiosk_hbm.rpx',
        'code/title.tmd',
        'code/title.fst'
    )
    foreach ($rel in $spot) {
        $localExpect = Join-Path $patchedRoot ($rel.Replace('/', '\'))
        $localGot = Join-Path $verifyRoot ($rel.Replace('/', '\'))
        Invoke-RwkmFtpGet -RemoteUrl "$remoteTitle/$rel" -LocalPath $localGot -Credential $cred
        $h1 = Get-RwkmFileSha256 $localExpect
        $h2 = Get-RwkmFileSha256 $localGot
        if ($h1 -ne $h2) {
            throw "Remote verify FAILED for $rel`n  patched=$h1`n  remote =$h2"
        }
        Write-RwkmLog "REMOTE MATCH $rel"
    }

    # cos must not mention hbm.rpx
    $remoteCos = Get-Content -LiteralPath (Join-Path $verifyRoot 'code\cos.xml') -Raw
    if ($remoteCos -notmatch 'kiosk_hbm\.rpx') { throw 'Remote cos.xml missing kiosk_hbm.rpx' }
    if ($remoteCos -match 'argstr[^>]*>hbm\.rpx<') { throw 'Remote cos.xml still has hbm.rpx' }

    Write-RwkmLog ''
    Write-RwkmLog '========================================'
    Write-RwkmLog 'SUCCESS: Home Button Menu replaced on MLC.'
    Write-RwkmLog "Backup:  $liveRoot"
    Write-RwkmLog "Patched: $patchedRoot"
    Write-RwkmLog "Remote:  $remoteTitle"
    Write-RwkmLog '========================================'
    Write-RwkmLog ''
    Write-RwkmLog '>>> RESTART THE WII U NOW <<<'
    Write-RwkmLog 'Full power off, then power on (redNAND SD still inserted if using redNAND).'
    Write-RwkmLog 'Do not pull the SD during boot.'
    Write-Host ''
    Write-Host 'RESTART THE WII U NOW.' -ForegroundColor Green
    Write-Host 'Power off fully, then power on.' -ForegroundColor Green
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Write-RwkmLog 'Wii U may still have old HOME if failure was before/during upload. Check log.'
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
