# Map kiosk demo folders (MLC usr/title/00050002) to matching SLC ticket paths.
# Read-only on PC — scans your kiosk extract and writes a text report.

param(
    [string]$ConfigPath = '',
    [string]$KioskSlcExtract = '',
    [string]$DemoMlcRoot = '',
    [string]$OutputPath = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Tickets.ps1')
Initialize-RwkmScript -Name 'map_kiosk_demo_tickets' -Force:$Force

function Get-RwkmDemoMlcDefault {
    param([string]$KioskSlc)
    $roots = @($KioskSlc)
    $parent = Split-Path -Parent $KioskSlc
    if ($parent) { $roots += $parent }
    foreach ($root in $roots) {
        if (-not $root) { continue }
        foreach ($extracted in @('Extracted', 'extracted')) {
            $candidate = Join-Path $root "$extracted\usr\title\00050002"
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return (Join-Path $KioskSlc 'Extracted\usr\title\00050002')
}

function Get-RwkmTitleIdFromFolder {
    param([string]$FolderPath)
    $name = Split-Path -Leaf $FolderPath
    # Prefer full 16-char title ID if present (e.g. 0005000210117e00).
    if ($name -match '^([0-9A-Fa-f]{16})') {
        return $Matches[1].ToUpperInvariant()
    }
    if ($name -match '^([0-9A-Fa-f]{8})') {
        return ('00050002' + $Matches[1]).ToUpperInvariant()
    }

    foreach ($rel in @('code\app.xml', 'meta\meta.xml')) {
        $xmlPath = Join-Path $FolderPath $rel
        if (-not (Test-Path -LiteralPath $xmlPath)) { continue }
        $text = [IO.File]::ReadAllText($xmlPath)
        if ($text -match '(?s)<title_id[^>]*>\s*([0-9A-Fa-f]{16})\s*</title_id>') {
            return $Matches[1].ToUpperInvariant()
        }
    }
    return $null
}

function Get-RwkmStubHint {
    param(
        [string]$FolderPath,
        [string]$TitleId = ''
    )
    $cos = Join-Path $FolderPath 'code\cos.xml'
    if ($TitleId -and $TitleId.EndsWith('FF', [StringComparison]::OrdinalIgnoreCase)) { return 'stub' }
    if (-not (Test-Path -LiteralPath $cos)) { return 'unknown' }
    $text = [IO.File]::ReadAllText($cos)
    if ($text -match 'non_playable_demo\.rpx') { return 'stub' }
    if (Test-Path -LiteralPath (Join-Path $FolderPath 'content\dummy.txt')) { return 'stub' }

    # Carousel stub tiles ship KioskMeta for a sibling playable title (e.g. 1017bdff -> 1017bd00).
    # Playable demos can also have KioskMeta when titleID matches this folder's title.
    $kioskMeta = Join-Path $FolderPath 'meta\KioskMeta.xml'
    if ((Test-Path -LiteralPath $kioskMeta) -and $TitleId) {
        $metaText = [IO.File]::ReadAllText($kioskMeta)
        if ($metaText -match '(?s)<titleID>\s*0x([0-9A-Fa-f]{16})\s*</titleID>') {
            $metaTid = $Matches[1].ToUpperInvariant()
            if ($metaTid -ne $TitleId.ToUpperInvariant()) {
                return 'stub'
            }
        }
    }

    return 'playable'
}

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath -SkipRegionPrompt
    $kioskSlc = if ($KioskSlcExtract) { $KioskSlcExtract } else { $cfg.KioskSlcExtract }
    $ticketRoot = Join-Path $kioskSlc 'sys\rights\ticket'
    $mlcRoot = if ($DemoMlcRoot) { $DemoMlcRoot } else { Get-RwkmDemoMlcDefault $kioskSlc }
    $out = if ($OutputPath) {
        $OutputPath
    } else {
        Join-Path $cfg.LiveSlcBackup 'kiosk_demo_ticket_map.txt'
    }

    if (-not (Test-RwkmSlcExtractTree $kioskSlc)) {
        throw @"
Kiosk SLC extract missing (need sys\rights\sys\cert.sys): $kioskSlc

Put NAND Extractor output in dumps\kiosk (see dumps\kiosk\IN_HERE_PUT_THE_FILES_THAT_ARE_NEEDED.txt)
or pass -KioskSlcExtract / set KioskSlcExtract in config.ps1.
"@
    }
    if (-not (Test-Path -LiteralPath $mlcRoot)) {
        throw @"
Kiosk demo MLC folder missing: $mlcRoot

Set -DemoMlcRoot to your extracted usr/title/00050002 folder, or extract kiosk MLC with:

  wfs-extract --input mlc.bin --otp otp.bin --dump-path Extracted

into dumps\kiosk so this exists:
  dumps\kiosk\Extracted\usr\title\00050002
"@
    }

    Write-RwkmLog '=== Kiosk demo -> SLC ticket map ==='
    Write-RwkmLog "SLC tickets: $ticketRoot"
    Write-RwkmLog "MLC demos:   $mlcRoot"
    Write-RwkmLog "Output:      $out"

    Write-RwkmLog 'Indexing SLC tickets...'
    $ticketIndex = Build-RwkmTicketIndex -TicketRoot $ticketRoot
    Write-RwkmLog "  indexed $($ticketIndex.Count) unique 00050002 title IDs in tickets"

    $rows = New-Object System.Collections.Generic.List[string]
    [void]$rows.Add('# Kiosk demo title ID -> SLC ticket path')
    [void]$rows.Add("# Generated: $(Get-Date -Format o)")
    [void]$rows.Add("# SLC tickets: $ticketRoot")
    [void]$rows.Add("# MLC demos:   $mlcRoot")
    [void]$rows.Add('#')
    [void]$rows.Add('# Columns: folder | full_title_id | kind | ticket_rel | product_code')
    [void]$rows.Add('# ticket_rel is relative to sys/rights/ticket/ on SLC')
    [void]$rows.Add('')

    $mapped = 0
    $missing = 0
    $folders = Get-ChildItem -LiteralPath $mlcRoot -Directory | Sort-Object Name

    foreach ($dir in $folders) {
        $tid = Get-RwkmTitleIdFromFolder -FolderPath $dir.FullName
        $kind = Get-RwkmStubHint -FolderPath $dir.FullName -TitleId $tid
        $product = ''
        $meta = Join-Path $dir.FullName 'meta\meta.xml'
        if (Test-Path -LiteralPath $meta) {
            $metaText = [IO.File]::ReadAllText($meta)
            if ($metaText -match '(?s)<product_code[^>]*>\s*([^<]*?)\s*</product_code>') {
                $product = $Matches[1].Trim()
            }
        }

        if (-not $tid) {
            [void]$rows.Add(("{0}`t{1}`t{2}`t{3}`t{4}" -f $dir.Name, '?', $kind, 'NO_TITLE_ID', $product))
            $missing++
            continue
        }

        if ($ticketIndex.ContainsKey($tid)) {
            [void]$rows.Add(("{0}`t{1}`t{2}`t{3}`t{4}" -f $dir.Name, $tid, $kind, $ticketIndex[$tid].TicketRel, $product))
            $mapped++
        } else {
            [void]$rows.Add(("{0}`t{1}`t{2}`t{3}`t{4}" -f $dir.Name, $tid, $kind, 'NOT_IN_SLC', $product))
            $missing++
        }
    }

    [void]$rows.Add('')
    [void]$rows.Add("# Summary: folders=$($folders.Count) mapped=$mapped missing_or_unknown=$missing")

    $outDir = Split-Path -Parent $out
    if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

    if (Test-Path -LiteralPath $out) {
        Confirm-RwkmFileWrite -Source '(generated map)' -Destination $out `
            -Description 'Overwrite previous kiosk_demo_ticket_map.txt' -Level Normal -Force:$Force
    }

    $rows | Set-Content -LiteralPath $out -Encoding UTF8
    Write-RwkmLog "Wrote: $out"
    Write-RwkmLog "Mapped: $mapped / $($folders.Count) demo folders"

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
