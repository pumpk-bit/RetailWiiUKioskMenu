# SD / physical disk helpers for redNAND partition writes.
#
# Policy: never guess which removable disk is the SD card.
# The user must set SdDriveLetter (e.g. F). We resolve PhysicalDriveN from that letter.

function Get-RwkmNormalizedDriveLetter {
    param([string]$Letter)
    if ([string]::IsNullOrWhiteSpace($Letter)) { return '' }
    return $Letter.Trim().TrimEnd(':').ToUpperInvariant()
}

function Get-RwkmSdDiskNumber {
    param([hashtable]$Config)

    $letter = Get-RwkmNormalizedDriveLetter $Config.SdDriveLetter
    if (-not $letter) {
        throw @"
SdDriveLetter is not set in config.ps1.

Open File Explorer, note the drive letter of the SD card that has a \minute\ folder
(example: F:), then either:
  - re-run:  .\scripts\setup_config.ps1
  - or edit config\config.ps1 and set:  SdDriveLetter = 'F'

We refuse to auto-pick a disk (wrong USB stick = wiped data).
"@
    }

    if (-not (Test-Path -LiteralPath "${letter}:\")) {
        throw @"
Drive ${letter}: is not available on this PC.

Insert the redNAND SD, wait for Windows to assign a letter, then set SdDriveLetter
in config.ps1 to that letter (This PC -> right-click SD -> properties shows the letter).
"@
    }

    $part = Get-Partition -DriveLetter $letter -ErrorAction SilentlyContinue
    if (-not $part) {
        throw @"
Could not map drive ${letter}: to a physical disk.

Fix:
  1) Run PowerShell as Administrator (Storage cmdlets need elevation for some cards).
  2) Confirm ${letter}: is the SD FAT partition (should contain \minute\).
  3) Or set SdDiskNumber explicitly AFTER checking Disk Management (diskmgmt.msc).
"@
    }

    $fromLetter = [int]$part.DiskNumber
    Write-RwkmLog "SD drive ${letter}: -> PhysicalDrive$fromLetter"

    if ($null -ne $Config.SdDiskNumber -and "$($Config.SdDiskNumber)" -ne '') {
        $configured = [int]$Config.SdDiskNumber
        if ($configured -ne $fromLetter) {
            throw @"
Config mismatch: SdDriveLetter ${letter}: is PhysicalDrive$fromLetter, but SdDiskNumber=$configured.

Fix: clear SdDiskNumber (set to `$null) and trust the drive letter, or correct the number in Disk Management.
"@
        }
    }

    return $fromLetter
}

function Get-RwkmMbrPartition {
    param([byte[]]$Mbr, [byte]$TypeId)
    for ($i = 0; $i -lt 4; $i++) {
        $off = 446 + $i * 16
        if ($Mbr[$off + 4] -eq $TypeId) {
            return @{
                Index  = $i
                Type   = $TypeId
                Start  = [BitConverter]::ToUInt32($Mbr, $off + 8)
                Length = [BitConverter]::ToUInt32($Mbr, $off + 12)
            }
        }
    }
    return $null
}

function Read-RwkmMbr {
    param([int]$DiskNum)
    $diskPath = "\\.\PhysicalDrive$DiskNum"
    $fs = [IO.File]::Open($diskPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $mbr = New-Object byte[] 512
        [void]$fs.Read($mbr, 0, 512)
        return $mbr
    } finally {
        $fs.Dispose()
    }
}

function Get-RwkmMbrPartitionReport {
    param([byte[]]$Mbr)
    $rows = @()
    for ($i = 0; $i -lt 4; $i++) {
        $off = 446 + $i * 16
        $type = $Mbr[$off + 4]
        if ($type -eq 0) { continue }
        $start = [BitConverter]::ToUInt32($Mbr, $off + 8)
        $len = [BitConverter]::ToUInt32($Mbr, $off + 12)
        $rows += [PSCustomObject]@{
            Partition = "P$($i + 1)"
            TypeHex   = ('0x{0:X2}' -f $type)
            StartLba  = $start
            Sectors   = $len
            SizeMiB   = [math]::Round($len * 512 / 1MB, 1)
        }
    }
    return $rows
}

function Test-RwkmRedNandLayout {
    param(
        [int]$DiskNum,
        [hashtable]$Config,
        [switch]$Force
    )

    $mbr = Read-RwkmMbr -DiskNum $DiskNum
    $report = Get-RwkmMbrPartitionReport -Mbr $mbr

    foreach ($row in $report) {
        Write-RwkmLog ("  {0} type={1} start={2} len={3} ({4} MiB)" -f $row.Partition, $row.TypeHex, $row.StartLba, $row.Sectors, $row.SizeMiB)
    }

    $fat = $report | Where-Object { $_.TypeHex -eq '0x0C' } | Select-Object -First 1
    $slc = $report | Where-Object { $_.TypeHex -eq '0x0E' } | Select-Object -First 1
    $slccmpt = $report | Where-Object { $_.TypeHex -eq '0x0D' } | Select-Object -First 1

    $errors = @()
    if (-not $fat) { $errors += 'Missing FAT32 partition (type 0x0C) for minute - is this the redNAND SD?' }
    if (-not $slc) { $errors += 'Missing redSLC partition (type 0x0E, 512 MiB).' }
    if ($slc -and $slc.Sectors -ne 1048576) {
        $errors += "redSLC partition is $($slc.SizeMiB) MiB but should be exactly 512 MiB (1048576 sectors)."
    }
    if ($slccmpt -and $slccmpt.Sectors -ne 1048576) {
        $errors += "redSLCCMPT partition is $($slccmpt.SizeMiB) MiB but should be 512 MiB."
    }

    $letter = Get-RwkmNormalizedDriveLetter $Config.SdDriveLetter
    if ($letter) {
        $minutePath = "${letter}:\minute"
        if (-not (Test-Path -LiteralPath $minutePath)) {
            $errors += "Drive ${letter}: exists but no \minute\ folder - wrong drive letter or SD not set up?"
        }
    }

    if ($errors.Count -gt 0) {
        $msg = @(
            'SD partition layout does not look like a minute redNAND card:'
            ''
            ($errors -join "`n")
            ''
            'Fix: boot Wii U -> minute -> Backup and Restore -> Format redNAND'
            'Then re-insert SD in PC and try again.'
            ''
            'Continue anyway? (usually N)'
        ) -join "`n"
        if (-not (Confirm-Rwkm -Level Critical -Prompt $msg -Force:$Force)) {
            throw 'Cancelled: SD layout check failed.'
        }
    }

    return @{
        Report  = $report
        SlcPart = $slc
        Errors  = $errors
    }
}

function Get-RwkmMinuteIniPath {
    param([hashtable]$Config)
    $letter = Get-RwkmNormalizedDriveLetter $Config.SdDriveLetter
    if (-not $letter) {
        throw 'Set SdDriveLetter in config.ps1 (the letter of the SD with \minute\). Do not guess - check This PC.'
    }
    return "${letter}:\minute\rednand.ini"
}

function Confirm-RwkmPhysicalWrite {
    param(
        [string]$SourceFile,
        [int]$DiskNum,
        [string]$PartitionLabel,
        [int]$PartitionIndex,
        [long]$ByteOffset,
        [long]$ByteCount,
        [string]$DriveLetter = '',
        [switch]$Force
    )

    $disk = Get-Disk -Number $DiskNum -ErrorAction Stop
    $srcMb = [math]::Round((Get-Item -LiteralPath $SourceFile).Length / 1MB, 1)
    $letterLine = if ($DriveLetter) { "  Drive letter: ${DriveLetter}:" } else { '' }

    $msg = @(
        'You are about to WRITE to a physical disk:'
        ''
        "  Source file:  $SourceFile (${srcMb} MB)"
        "  Target disk:  PhysicalDrive$DiskNum - $($disk.FriendlyName)"
        $letterLine
        "  Partition:    P$($PartitionIndex + 1) ($PartitionLabel)"
        "  Byte offset:  $ByteOffset"
        "  Bytes:        $ByteCount"
        ''
        'This can DESTROY data on that partition. The wrong disk = bricked SD or lost files.'
    ) -join "`n"

    if (-not (Confirm-Rwkm -Level Critical -Prompt $msg -Force:$Force)) {
        throw 'Cancelled: physical write not confirmed.'
    }
}
