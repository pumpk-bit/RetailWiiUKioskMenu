param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

# Wii U SLC/SLCCMPT RAW from minute: 2048-byte pages + 64-byte spare = 2112
# Output for redNAND SD partition: 2048-byte pages only (512 MiB)

$ErrorActionPreference = 'Stop'
$rawSize = 553648128L
$outSize = 536870912L
$pageIn = 2112
$pageOut = 2048

$inLen = (Get-Item -LiteralPath $InputPath).Length
if ($inLen -ne $rawSize) {
    throw "Expected ECC dump size $rawSize bytes, got $inLen ($InputPath)"
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$src = [IO.File]::OpenRead($InputPath)
try {
    $dst = [IO.File]::Create($OutputPath)
    try {
        $inBuf = New-Object byte[] $pageIn
        $outBuf = New-Object byte[] $pageOut
        $written = 0L
        while ($written -lt $outSize) {
            $n = $src.Read($inBuf, 0, $pageIn)
            if ($n -lt $pageOut) { throw "Unexpected EOF at output offset $written" }
            [Array]::Copy($inBuf, 0, $outBuf, 0, $pageOut)
            $dst.Write($outBuf, 0, $pageOut)
            $written += $pageOut
        }
        if ($src.Read($inBuf, 0, 1) -gt 0) {
            throw "Input has trailing data after $rawSize ECC bytes"
        }
    } finally { $dst.Dispose() }
} finally { $src.Dispose() }

if ((Get-Item -LiteralPath $OutputPath).Length -ne $outSize) {
    throw 'Strip output size mismatch'
}

Write-Host "Stripped $InputPath -> $OutputPath ($outSize bytes) [2112->2048]"
