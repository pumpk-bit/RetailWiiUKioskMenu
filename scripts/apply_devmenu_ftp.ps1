# Experimental: upload DevMenu (00050010-1f7001ff) via the same MLC uploader as Kiosk Menu.
# Docs: docs\AI\EXPERIMENTAL.MD
#
# Reuses upload_sys_title_mlc.ps1 (TitleIds / SourceRoot only). Then, if needed:
#   - append the packed DevMenu ticket inside sys/0000/00000009.tik (does not replace the file)
#   - add 000500101F7001FF to title.list
#
# Example:
#   .\scripts\apply_devmenu_ftp.ps1 -Force
#   .\scripts\apply_devmenu_ftp.ps1 -SourceRoot 'D:\Cat-I USA\Extracted\sys\title\00050010' -Force

param(
    [string]$ConfigPath = '',
    [string]$SourceRoot = '',
    [string]$TitleId = '1f7001ff',
    [string]$KioskSlcExtract = '',
    [switch]$SkipTicket,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'apply_devmenu_ftp' -Force:$Force

function Get-RwkmPackedTicketSlice {
    param([string]$TikPath, [string]$WantTid)
    $want = $WantTid.ToUpperInvariant()
    $b = [IO.File]::ReadAllBytes($TikPath)
    for ($off = 0; $off + 848 -le $b.Length; $off += 848) {
        $tid = [BitConverter]::ToString($b, $off + 0x1DC, 8).Replace('-', '')
        if ($tid -eq $want) {
            $slice = New-Object byte[] 848
            [Array]::Copy($b, $off, $slice, 0, 848)
            return $slice
        }
    }
    throw "No $want ticket inside $TikPath"
}

function Test-RwkmPackedTicketHasTitle {
    param([byte[]]$Bytes, [string]$WantTid)
    $want = $WantTid.ToUpperInvariant()
    for ($off = 0; $off + 848 -le $Bytes.Length; $off += 848) {
        $tid = [BitConverter]::ToString($Bytes, $off + 0x1DC, 8).Replace('-', '')
        if ($tid -eq $want) { return $true }
    }
    return $false
}

function Read-RwkmTitleListSet([byte[]]$Bytes) {
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($i = 0; $i + 8 -le $Bytes.Length; $i += 8) {
        [void]$set.Add([BitConverter]::ToString($Bytes, $i, 8).Replace('-', '').ToUpperInvariant())
    }
    return , $set
}

function Write-RwkmTitleListBytes([System.Collections.Generic.HashSet[string]]$Set) {
    $sorted = @($Set) | Sort-Object
    $out = New-Object byte[] ($sorted.Count * 8)
    $idx = 0
    foreach ($hex in $sorted) {
        for ($j = 0; $j -lt 8; $j++) {
            $out[$idx + $j] = [Convert]::ToByte($hex.Substring($j * 2, 2), 16)
        }
        $idx += 8
    }
    return $out
}

function Resolve-RwkmDevMenuSourceRoot {
    param([hashtable]$Config, [string]$Explicit, [string]$TitleId)
    $tid = $TitleId.ToLowerInvariant()
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($Explicit) { [void]$candidates.Add($Explicit) }
    if ($Config.KioskMlcSysTitleRoot) { [void]$candidates.Add($Config.KioskMlcSysTitleRoot) }
    $docsFolder = [Environment]::GetFolderPath('MyDocuments')
    foreach ($dump in @('Cat-I USA', 'Cat-I 3 USA')) {
        [void]$candidates.Add((Join-Path $docsFolder "WiiUKioskVsRetail\WiiUDumps\$dump\Extracted\sys\title\00050010"))
    }

    foreach ($c in $candidates) {
        if (-not $c) { continue }
        $folder = if (Test-Path -LiteralPath (Join-Path $c $tid)) { $c } else { $c }
        $probe = Join-Path $folder $tid
        if (Test-Path -LiteralPath (Join-Path $probe 'code\devmenu.rpx')) {
            return (Resolve-Path -LiteralPath $folder).Path
        }
    }
    throw @"
DevMenu folder not found ($tid\code\devmenu.rpx).

Pass -SourceRoot to the extracted kiosk MLC sys title dir, e.g.:
  ...\Extracted\sys\title\00050010
"@
}

function Resolve-RwkmDevMenuPackedTik {
    param([hashtable]$Config, [string]$SourceRoot, [string]$OverrideSlc)
    $paths = New-Object System.Collections.Generic.List[string]
    if ($OverrideSlc) {
        [void]$paths.Add((Join-Path $OverrideSlc 'sys\rights\ticket\sys\0000\00000009.tik'))
    }
    if ($Config.KioskSlcExtract) {
        $slc = Resolve-RwkmSlcExtractTree $Config.KioskSlcExtract
        [void]$paths.Add((Join-Path $slc 'sys\rights\ticket\sys\0000\00000009.tik'))
    }
    $p = $SourceRoot
    for ($i = 0; $i -lt 6; $i++) {
        foreach ($name in @('slc', 'SLC')) {
            [void]$paths.Add((Join-Path $p "$name\sys\rights\ticket\sys\0000\00000009.tik"))
        }
        $parent = Split-Path $p -Parent
        if (-not $parent -or $parent -eq $p) { break }
        $p = $parent
    }
    foreach ($tik in $paths) {
        if ($tik -and (Test-Path -LiteralPath $tik)) { return (Resolve-Path -LiteralPath $tik).Path }
    }
    throw 'Packed DevMenu ticket not found (sys\rights\ticket\sys\0000\00000009.tik). Pass -KioskSlcExtract.'
}

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $tid = $TitleId.ToLowerInvariant()
    $fullTid = ('00050010{0}' -f $tid).ToUpperInvariant()
    $source = Resolve-RwkmDevMenuSourceRoot -Config $cfg -Explicit $SourceRoot -TitleId $tid

    Confirm-RwkmDeploymentMode -Config $cfg -Action 'EXPERIMENTAL upload DevMenu to storage_mlc (+ optional ticket)' -Force:$Force | Out-Null

    Write-RwkmLog '=== Experimental DevMenu (reuses upload_sys_title_mlc.ps1) ==='
    Write-RwkmLog "Title:  $tid"
    Write-RwkmLog "Source: $source"

    $upload = Join-Path $scriptDir 'upload_sys_title_mlc.ps1'
    $psArgs = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', $upload
        '-TitleIds', $tid
        '-SourceRoot', $source
    )
    if ($ConfigPath) { $psArgs += @('-ConfigPath', $ConfigPath) }
    if ($Force) { $psArgs += '-Force' }

    $prevPause = $env:RWKM_NO_PAUSE
    $env:RWKM_NO_PAUSE = '1'
    try {
        & powershell.exe @psArgs
        if ($LASTEXITCODE -ne 0) {
            throw "upload_sys_title_mlc.ps1 failed (exit $LASTEXITCODE)"
        }
    } finally {
        if ($null -eq $prevPause) { Remove-Item Env:RWKM_NO_PAUSE -ErrorAction SilentlyContinue }
        else { $env:RWKM_NO_PAUSE = $prevPause }
    }

    if ($SkipTicket) {
        Write-RwkmLog 'SkipTicket: MLC only. Launch from SCT may still say Cannot launch.'
        Write-RwkmLog 'SCT Title Launcher -> mlc -> 00050010_1f7001ff -> Title Type: Menu'
        Stop-RwkmSession -ExitCode 0
    }

    $donorTik = Resolve-RwkmDevMenuPackedTik -Config $cfg -SourceRoot $source -OverrideSlc $KioskSlcExtract
    $slice = Get-RwkmPackedTicketSlice -TikPath $donorTik -WantTid $fullTid
    Write-RwkmLog "Donor packed ticket: $donorTik"

    $cred = Get-RwkmFtpCredential -Config $cfg
    $slcBase = Get-RwkmFtpBase -Config $cfg -Mount slc
    $remoteTik = "$slcBase/sys/rights/ticket/sys/0000/00000009.tik"
    $remoteList = "$slcBase/sys/rights/sys/title.list"

    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Force:$Force -Action 'Append DevMenu ticket + title.list id' -Extra @"
  Ticket: append $fullTid inside sys/0000/00000009.tik (keep existing bytes)
  title.list: add $fullTid if missing
  Donor: $donorTik
"@
    Assert-RwkmFtpReady -Config $cfg -Mount slc

    $bakRoot = Join-Path $cfg.LiveSlcBackup ('devmenu_ftp_{0}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Force -Path $bakRoot | Out-Null

    $liveTik = Join-Path $bakRoot '00000009.tik'
    if (Test-RwkmFtpRemoteExists -RemoteUrl $remoteTik -Credential $cred) {
        Invoke-RwkmFtpGet -RemoteUrl $remoteTik -LocalPath $liveTik -Credential $cred
        Write-RwkmLog "Backed up live 00000009.tik -> $liveTik"
        $liveBytes = [IO.File]::ReadAllBytes($liveTik)
        if (Test-RwkmPackedTicketHasTitle -Bytes $liveBytes -WantTid $fullTid) {
            Write-RwkmLog 'Live 00000009.tik already has DevMenu ticket - leave it.'
        } else {
            $merged = New-Object byte[] ($liveBytes.Length + $slice.Length)
            [Array]::Copy($liveBytes, 0, $merged, 0, $liveBytes.Length)
            [Array]::Copy($slice, 0, $merged, $liveBytes.Length, $slice.Length)
            $mergedPath = Join-Path $bakRoot '00000009.tik.appended'
            [IO.File]::WriteAllBytes($mergedPath, $merged)
            Invoke-RwkmFtpPut -LocalPath $mergedPath -RemoteUrl $remoteTik -Credential $cred
            Write-RwkmLog ("Appended DevMenu ticket ({0} -> {1} bytes)" -f $liveBytes.Length, $merged.Length)
        }
    } else {
        Write-RwkmLog 'WARN: live 00000009.tik missing - not creating that path (would steal a sys ticket slot).'
        Write-RwkmLog 'MLC is uploaded; launch may still fail without a ticket.'
    }

    $liveList = Join-Path $bakRoot 'title.list'
    Invoke-RwkmFtpGet -RemoteUrl $remoteList -LocalPath $liveList -Credential $cred
    $set = Read-RwkmTitleListSet ([IO.File]::ReadAllBytes($liveList))
    if ($set.Contains($fullTid)) {
        Write-RwkmLog "title.list already has $fullTid"
    } else {
        [void]$set.Add($fullTid)
        $patched = Join-Path $bakRoot 'title.list.patched'
        [IO.File]::WriteAllBytes($patched, (Write-RwkmTitleListBytes $set))
        Invoke-RwkmFtpPut -LocalPath $patched -RemoteUrl $remoteList -Credential $cred
        Write-RwkmLog "title.list: added $fullTid"
    }

    Write-RwkmLog 'Reboot, then SCT Title Launcher -> System NAND (mlc) -> 00050010_1f7001ff -> Title Type: Menu.'
    Write-RwkmLog "Backup: $bakRoot"
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
