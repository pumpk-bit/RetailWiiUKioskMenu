#Requires -RunAsAdministrator
# Flash a validated stripped 512 MiB image to redNAND SLC (0x0E) or SLCCMPT (0x0D).
#
# Always resolves the disk from SdDriveLetter (never guesses E: or the first USB disk).
# Always runs redNAND layout checks before writing.

param(
    [Parameter(ParameterSetName = 'Explicit')]
    [string]$StrippedPath,
    [Parameter(ParameterSetName = 'Explicit')]
    [ValidateSet('slc','slccmpt')]
    [string]$Partition = 'slc',
    [int]$DiskNum = 0,
    [string]$ConfigPath = '',
    [Parameter(ParameterSetName = 'Config')]
    [switch]$UseConfig,
    [switch]$SkipValidate,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Region.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Disk.ps1')
Initialize-RwkmScript -Name "flash_$Partition" -Force:$Force

$partBytes = 536870912L
$typeMap = @{ slc = 0x0E; slccmpt = 0x0D }
$validateScript = Join-Path $scriptDir 'validate_slc_dump.ps1'

try {
    $cfg = $null
    if ($UseConfig -or -not $StrippedPath -or -not $DiskNum) {
        $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    }

    if ($UseConfig -or (-not $StrippedPath)) {
        if (-not $cfg) { $cfg = Import-RwkmConfig -ConfigPath $ConfigPath }
        if (-not $DiskNum) { $DiskNum = Get-RwkmSdDiskNumber -Config $cfg }
        if (-not $StrippedPath) {
            $raw = Find-RwkmRawDump -Kind $Partition -SearchRoots $cfg.SearchRoots `
                -ExplicitPath $(if ($Partition -eq 'slc') { $cfg.SlcRawPath } else { $cfg.SlccmptRawPath })
            $StrippedPath = Get-RwkmStrippedPath -StrippedDir $cfg.StrippedDir -Kind $Partition -SourceRawPath $raw
            if (-not (Test-Path -LiteralPath $StrippedPath)) {
                $strip = Join-Path $scriptDir 'strip_nand_ecc.ps1'
                & $strip -InputPath $raw -OutputPath $StrippedPath
            }
        }
    }

    if (-not $StrippedPath) { throw 'Provide -StrippedPath or -UseConfig' }

    # Prefer drive letter -> disk number from config whenever available
    if (-not $DiskNum) {
        if (-not $cfg) { $cfg = Import-RwkmConfig -ConfigPath $ConfigPath }
        $DiskNum = Get-RwkmSdDiskNumber -Config $cfg
    }

    if (-not $cfg) {
        # Explicit flash still needs a letter for layout/minute checks when possible
        try { $cfg = Import-RwkmConfig -ConfigPath $ConfigPath } catch { $cfg = @{ SdDriveLetter = '' } }
    }

    Test-RwkmRedNandLayout -DiskNum $DiskNum -Config $cfg -Force:$Force | Out-Null
    Test-RwkmSlcImageSize -FilePath $StrippedPath -Expected stripped -Force:$Force | Out-Null

    if ($Partition -eq 'slc' -and -not $SkipValidate) {
        Write-RwkmLog 'Validating fw.img path...'
        & $validateScript -InputPath $StrippedPath
        if ($LASTEXITCODE -ne 0) { throw 'Validation failed - refusing to flash broken SLC image.' }
    }

    $typeId = $typeMap[$Partition]
    $disk = Get-Disk -Number $DiskNum -ErrorAction Stop
    Write-RwkmLog "Disk $DiskNum sectors=$([int64]($disk.Size/512)) model=$($disk.FriendlyName)"

    $diskPath = "\\.\PhysicalDrive$DiskNum"
    $diskStream = [IO.File]::Open($diskPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $mbr = New-Object byte[] 512
        [void]$diskStream.Seek(0, [IO.SeekOrigin]::Begin)
        [void]$diskStream.Read($mbr, 0, 512)

        for ($i = 0; $i -lt 4; $i++) {
            $off = 446 + $i * 16
            $t = $mbr[$off + 4]
            $st = [BitConverter]::ToUInt32($mbr, $off + 8)
            $ln = [BitConverter]::ToUInt32($mbr, $off + 12)
            Write-RwkmLog ("P{0}: type=0x{1:X2} start={2} len={3}" -f ($i + 1), $t, $st, $ln)
        }

        $part = Get-RwkmMbrPartition -Mbr $mbr -TypeId $typeId
        if (-not $part) {
            throw @"
No partition type 0x$($typeId.ToString('X2')) ($Partition) in MBR of PhysicalDrive$DiskNum.

Is this the redNAND SD? Format redNAND in minute first. Confirm SdDriveLetter in config.ps1.
"@
        }

        $byteOff = [int64]$part.Start * 512L
        $letter = if ($cfg.SdDriveLetter) { ($cfg.SdDriveLetter.ToString().TrimEnd(':')) } else { '' }
        Confirm-RwkmPhysicalWrite -SourceFile $StrippedPath -DiskNum $DiskNum `
            -PartitionLabel $Partition -PartitionIndex $part.Index `
            -ByteOffset $byteOff -ByteCount $partBytes -DriveLetter $letter -Force:$Force

        Write-RwkmLog "Writing $Partition to P$($part.Index + 1) at LBA $($part.Start)..."

        $src = [IO.File]::OpenRead($StrippedPath)
        try {
            $bufSize = 4MB
            $buf = New-Object byte[] $bufSize
            $written = 0L
            $lastPct = -1
            [void]$diskStream.Seek($byteOff, [IO.SeekOrigin]::Begin)
            while ($written -lt $partBytes) {
                $remaining = $partBytes - $written
                $toRead = if ($remaining -gt $bufSize) { $bufSize } else { [int]$remaining }
                $n = $src.Read($buf, 0, $toRead)
                if ($n -le 0) { throw "Unexpected EOF at $written" }
                $diskStream.Write($buf, 0, $n)
                $written += $n
                $pct = [int]($written * 100 / $partBytes)
                if ($pct -ge $lastPct + 10) {
                    Write-RwkmLog ("  {0}% ({1:F2} GiB)" -f $pct, ($written / 1GB))
                    $lastPct = $pct
                }
            }
            $diskStream.Flush()
            Write-RwkmLog "Wrote $written bytes"
        } finally { $src.Dispose() }

        $verBuf = New-Object byte[] 512
        $srcBuf = New-Object byte[] 512
        [void]$diskStream.Seek($byteOff, [IO.SeekOrigin]::Begin)
        [void]$diskStream.Read($verBuf, 0, 512)
        $src2 = [IO.File]::OpenRead($StrippedPath)
        try { [void]$src2.Read($srcBuf, 0, 512) } finally { $src2.Dispose() }
        if (-not [System.Linq.Enumerable]::SequenceEqual($verBuf, $srcBuf)) {
            throw 'Verify failed (first sector mismatch) - SD may be bad or write blocked.'
        }
        Write-RwkmLog 'Verify OK'
    } finally { $diskStream.Dispose() }

    Write-RwkmLog "ALL DONE - $Partition flashed on disk $DiskNum"
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
