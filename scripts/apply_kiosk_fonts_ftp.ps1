# Apply kiosk system fonts (0005001B-10042400) via FTP.
# Docs: docs\AI\EXPERIMENTAL.MD
#
# Safer than a full TMD swap:
#   1) Download live title from storage_mlc (backup)
#   2) Keep live code/* (TMD/FST/identity); take Cafe*.ttf from kiosk dump
#   3) Upload only content/*.ttf (overwrite)
#   4) Re-download and hash-check
#   5) Restart the Wii U
#
# Note: on a normal retail console the Cafe*.ttf files often already match the
# kiosk dump, so expect no visible change after apply.
#
# Example:
#   .\scripts\apply_kiosk_fonts_ftp.ps1 -Force

param(
    [string]$ConfigPath = '',
    [string]$KioskFontRoot = '',
    [string]$TitleId = '10042400',
    [string]$UpperId = '0005001b',
    [string]$WorkRoot = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Region.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Hbm.ps1')
Initialize-RwkmScript -Name 'apply_kiosk_fonts_ftp' -Force:$Force

function Resolve-RwkmFontTitleFolder {
    param(
        [string]$ExplicitRoot,
        [string]$SearchHint,
        [string]$UpperId,
        [string]$TitleId
    )
    if ($ExplicitRoot) {
        if (-not (Test-Path -LiteralPath $ExplicitRoot)) {
            throw "Kiosk font folder not found: $ExplicitRoot"
        }
        return (Resolve-Path -LiteralPath $ExplicitRoot).Path
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($SearchHint) {
        $hint = $SearchHint.TrimEnd('\', '/')
        [void]$candidates.Add((Join-Path $hint $TitleId))
        [void]$candidates.Add((Join-Path (Split-Path $hint -Parent) "$UpperId\$TitleId"))
        if ($hint -match '[\\/]00050010[\\/]?$') {
            [void]$candidates.Add((Join-Path (Split-Path $hint -Parent) "$UpperId\$TitleId"))
        }
        if ($hint -match '[\\/]title[\\/]?$') {
            [void]$candidates.Add((Join-Path $hint "$UpperId\$TitleId"))
        }
    }

    $repo = Get-RwkmRepoRoot
    [void]$candidates.Add((Join-Path $repo "dumps\kiosk\Extracted\sys\title\$UpperId\$TitleId"))

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            $std = Join-Path $c 'content\CafeStd.ttf'
            if (Test-Path -LiteralPath $std) {
                return (Resolve-Path -LiteralPath $c).Path
            }
        }
    }

    throw @"
Kiosk font title folder not found ($UpperId/$TitleId).

Pass -KioskFontRoot, or ensure dumps\kiosk\Extracted\sys\title\$UpperId\$TitleId exists with content\CafeStd.ttf.
"@
}

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $titleId = $TitleId.ToLowerInvariant()
    $upperId = $UpperId.ToLowerInvariant()

    $kioskRoot = Resolve-RwkmFontTitleFolder -ExplicitRoot $KioskFontRoot `
        -SearchHint $cfg.KioskMlcSysTitleRoot -UpperId $upperId -TitleId $titleId

    $requiredFonts = @('CafeStd.ttf', 'CafeCn.ttf', 'CafeKr.ttf', 'CafeTw.ttf')
    foreach ($fontName in $requiredFonts) {
        $p = Join-Path $kioskRoot "content\$fontName"
        if (-not (Test-Path -LiteralPath $p) -or ((Get-Item -LiteralPath $p).Length -le 0)) {
            throw "Kiosk font missing or empty: $p"
        }
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $workRoot = if ($WorkRoot) {
        $WorkRoot
    } else {
        Join-Path (Get-RwkmRepoRoot) "backup\fonts_ftp_$stamp"
    }
    $liveRoot = Join-Path $workRoot '01_live_mlc_download'
    $patchedRoot = Join-Path $workRoot '02_patched'
    $verifyRoot = Join-Path $workRoot '03_remote_verify'

    $cred = Get-RwkmFtpCredential -Config $cfg
    $mlcBase = Get-RwkmFtpBase -Config $cfg -Mount mlc
    $remoteTitle = "$mlcBase/sys/title/$upperId/$titleId"

    Write-RwkmLog '=== Apply Kiosk Fonts via FTP ==='
    Write-RwkmLog "Title:      $upperId-$titleId"
    Write-RwkmLog "FtpHost:    $($cfg.FtpHost)"
    Write-RwkmLog "Mode:       $(Get-RwkmDeploymentMode -Config $cfg)"
    Write-RwkmLog "Kiosk dump: $kioskRoot"
    Write-RwkmLog "Work dir:   $workRoot"
    Write-RwkmLog "Remote:     $remoteTitle"
    Write-RwkmLog ''

    Confirm-RwkmDeploymentMode -Config $cfg -Action 'REPLACE system fonts on storage_mlc' -Force:$Force | Out-Null
    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount mlc -Force:$Force -Level Critical -Action 'Replace system fonts (Cafe*.ttf)' -Extra @"
  Remote: $remoteTitle
  Backup: $liveRoot
  Patch:  $patchedRoot

Order:
  1) Download live font title (backup)
  2) Keep live code/* (TMD/FST/identity); swap content Cafe*.ttf from kiosk
  3) Upload the four TTFs only (overwrite)
  4) Re-download TTFs and hash-check
  5) You restart the Wii U

Shared system data - prefer redNAND. Backup under backup\fonts_ftp_*.
See docs\AI\EXPERIMENTAL.MD
"@

    Assert-RwkmFtpReady -Config $cfg -Mount mlc

    if (-not (Test-RwkmFtpRemoteDir -RemoteDirUrl $remoteTitle -Credential $cred)) {
        throw "Remote font title folder not found: $remoteTitle"
    }

    # --- 1) Download live ---
    Write-RwkmLog 'STEP 1/5: Download live fonts from MLC...'
    if (Test-Path -LiteralPath $liveRoot) { Remove-Item -LiteralPath $liveRoot -Recurse -Force }
    $got = Invoke-RwkmFtpDownloadTree -RemoteDirUrl $remoteTitle -LocalDir $liveRoot -Credential $cred
    Write-RwkmLog "Downloaded $got files -> $liveRoot"

    foreach ($fontName in $requiredFonts) {
        $liveFont = Join-Path $liveRoot "content\$fontName"
        if (-not (Test-Path -LiteralPath $liveFont)) {
            throw "Live MLC fonts missing $fontName. Backup at: $liveRoot"
        }
    }
    $liveTmd = Join-Path $liveRoot 'code\title.tmd'
    if (-not (Test-Path -LiteralPath $liveTmd)) {
        throw "Live MLC fonts missing code\title.tmd. Backup at: $liveRoot"
    }
    Write-RwkmLog 'LIVE: font title looks intact.'

    # --- 2) Patch (live identity + kiosk TTFs) ---
    Write-RwkmLog 'STEP 2/5: Build patched tree (live code + kiosk fonts)...'
    if (Test-Path -LiteralPath $patchedRoot) { Remove-Item -LiteralPath $patchedRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $patchedRoot | Out-Null
    # Path (not LiteralPath): need wildcard expansion to copy code/content/meta.
    Copy-Item -Path (Join-Path $liveRoot '*') -Destination $patchedRoot -Recurse -Force
    $patchedContent = Join-Path $patchedRoot 'content'
    if (-not (Test-Path -LiteralPath $patchedContent)) {
        throw "Patched tree missing content/ after copy from live. Live root: $liveRoot"
    }

    $changed = 0
    $unchanged = 0
    foreach ($fontName in $requiredFonts) {
        $src = Join-Path $kioskRoot "content\$fontName"
        $dst = Join-Path $patchedContent $fontName
        $liveFont = Join-Path $liveRoot "content\$fontName"
        $hSrc = Get-RwkmFileSha256 $src
        $hOld = Get-RwkmFileSha256 $dst
        Copy-Item -LiteralPath $src -Destination $dst -Force
        if ($hSrc -eq $hOld) {
            Write-RwkmLog "  $fontName already matches kiosk (no visual change expected)"
            $unchanged++
        } else {
            Write-RwkmLog ('  {0} REPLACE {1} -> {2} bytes' -f $fontName, (Get-Item -LiteralPath $liveFont).Length, (Get-Item -LiteralPath $src).Length)
            $changed++
        }
    }
    if ($changed -eq 0) {
        Write-RwkmLog 'NOTE: All four fonts already matched kiosk dump. Upload will still rewrite them for verify.'
    } else {
        Write-RwkmLog "Fonts to change: $changed (identical: $unchanged)"
    }

    # --- 3) Upload TTFs only ---
    Write-RwkmLog 'STEP 3/5: Upload kiosk Cafe*.ttf (overwrite)...'
    $i = 0
    foreach ($fontName in $requiredFonts) {
        $i++
        $local = Join-Path $patchedRoot "content\$fontName"
        $remote = "$remoteTitle/content/$fontName"
        $mb = [math]::Round((Get-Item -LiteralPath $local).Length / 1MB, 2)
        Write-RwkmLog "  PUT [$i/$($requiredFonts.Count)] content/$fontName ($mb MB)"
        Invoke-RwkmFtpPut -LocalPath $local -RemoteUrl $remote -Credential $cred
    }

    # --- 4) Verify ---
    Write-RwkmLog 'STEP 4/5: Re-download TTFs and hash-check...'
    if (Test-Path -LiteralPath $verifyRoot) { Remove-Item -LiteralPath $verifyRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Join-Path $verifyRoot 'content') | Out-Null
    foreach ($fontName in $requiredFonts) {
        $rel = "content/$fontName"
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

    # Spot-check that we did not touch TMD (still present remotely)
    if (-not (Test-RwkmFtpRemoteExists -RemoteUrl "$remoteTitle/code/title.tmd" -Credential $cred)) {
        throw 'Remote code/title.tmd missing after font upload (unexpected).'
    }

    Write-RwkmLog ''
    Write-RwkmLog '========================================'
    Write-RwkmLog 'SUCCESS: System fonts replaced on MLC.'
    Write-RwkmLog "Backup:  $liveRoot"
    Write-RwkmLog "Patched: $patchedRoot"
    Write-RwkmLog "Remote:  $remoteTitle"
    Write-RwkmLog '========================================'
    Write-RwkmLog ''
    Write-RwkmLog '>>> RESTART THE WII U NOW <<<'
    Write-RwkmLog 'Full power off, then power on. Fonts are loaded early.'
    Write-Host ''
    Write-Host 'RESTART THE WII U NOW.' -ForegroundColor Green
    Write-Host 'Power off fully, then power on.' -ForegroundColor Green
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Write-RwkmLog 'Wii U may still have old fonts if failure was before/during upload. Check log.'
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
