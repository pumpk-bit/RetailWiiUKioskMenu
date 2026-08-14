# Shared kiosk demo ticket helpers (title ID from .tik, ticket path index).

function Get-RwkmTitleIdFromTicketBytes {
    param([byte[]]$Bytes)

    # Standard Wii U ticket: big-endian title_id at offset 0x1DC.
    if ($Bytes.Length -ge 0x1E4) {
        $atOffset = ([BitConverter]::ToString($Bytes, 0x1DC, 8)).Replace('-', '').ToUpperInvariant()
        if ($atOffset -match '^00050002[0-9A-F]{8}$') {
            return $atOffset
        }
    }

    # Fallback: scan a small window around 0x1DC only (not the whole file — cert blobs
    # can contain a stray 00050002XXXXXXXX that is not this ticket's title).
    $windowOff = [Math]::Max(0, 0x1DC - 32)
    $windowLen = [Math]::Min(80, $Bytes.Length - $windowOff)
    if ($windowLen -ge 8) {
        $hex = ([BitConverter]::ToString($Bytes, $windowOff, $windowLen)).Replace('-', '').ToUpperInvariant()
        $unique = @(
            [regex]::Matches($hex, '00050002[0-9A-F]{8}') |
                ForEach-Object { $_.Value } |
                Select-Object -Unique
        )
        if ($unique.Count -eq 1) {
            return $unique[0]
        }
    }
    return $null
}

function Build-RwkmTicketIndex {
    param([string]$TicketRoot)

    $index = @{}
    if (-not (Test-Path -LiteralPath $TicketRoot)) {
        throw "SLC ticket folder missing: $TicketRoot"
    }

    Get-ChildItem -LiteralPath $TicketRoot -Recurse -Filter *.tik | ForEach-Object {
        $bytes = [IO.File]::ReadAllBytes($_.FullName)
        $tid = Get-RwkmTitleIdFromTicketBytes -Bytes $bytes
        if (-not $tid) { return }

        if (-not $index.ContainsKey($tid)) {
            $rel = Get-RwkmRelativeUnixPath -Root $TicketRoot -FullPath $_.FullName
            $index[$tid] = @{
                LocalPath = $_.FullName
                TicketRel = $rel
            }
        }
    }
    return $index
}

function Get-RwkmTicketRelOwnerMap {
    param([hashtable]$TicketIndex)

    $owners = @{}
    foreach ($tid in $TicketIndex.Keys) {
        $rel = $TicketIndex[$tid].TicketRel
        if (-not $owners.ContainsKey($rel)) {
            $owners[$rel] = New-Object 'System.Collections.Generic.List[string]'
        }
        [void]$owners[$rel].Add($tid)
    }
    return $owners
}
