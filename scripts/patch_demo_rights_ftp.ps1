# Add or remove kiosk demo rights on live SLC from PC MLC extract folder(s).
#
# Resolves title ID(s) from folder name (10117e00) or meta/meta.xml, pairs stub/playable
# siblings when present, patches title.list, and uploads/deletes matching .tik files.
#
# Usage:
#   .\scripts\patch_demo_rights_ftp.ps1 -Mode Add -DemoFolder '...\10117e00 - new mario u'
#   .\scripts\patch_demo_rights_ftp.ps1 -Mode Remove -DemoFolder '...\Crashes\1017bd00 - kart'
#   .\scripts\patch_demo_rights_ftp.ps1 -Mode Add -DemoFolder @('...\101e2b00','...\101e2bff') -SkipStubPair
#
# Ticket source: -KioskSlcExtract, else config KioskSlcExtract, else nearest parent slc\
# that covers the demo title IDs, else overlay\mutant\slc.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Add', 'Remove')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string[]]$DemoFolder,

    [string]$ConfigPath = '',
    [string]$KioskSlcExtract = '',
    [switch]$SkipStubPair,
    [switch]$SkipTickets,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Tickets.ps1')
Initialize-RwkmScript -Name 'patch_demo_rights' -Force:$Force

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

function Get-RwkmTitleIdFromDemoFolder {
    param([string]$FolderPath)
    if (-not (Test-Path -LiteralPath $FolderPath)) {
        throw "Demo folder not found: $FolderPath"
    }
    $name = Split-Path -Leaf $FolderPath
    # Prefer full 16-char title ID if present (e.g. 0005000210117e00).
    # An 8-char-only match would wrongly turn that into 0005000200050002.
    if ($name -match '^([0-9A-Fa-f]{16})') {
        $tid = $Matches[1].ToUpperInvariant()
        if (-not $tid.StartsWith('00050002')) {
            throw "Folder title ID must be a kiosk demo (00050002…), got $tid from: $FolderPath"
        }
        return $tid
    }
    if ($name -match '^([0-9A-Fa-f]{8})') {
        return ('00050002' + $Matches[1]).ToUpperInvariant()
    }
    foreach ($rel in @('code\app.xml', 'meta\meta.xml')) {
        $xmlPath = Join-Path $FolderPath $rel
        if (-not (Test-Path -LiteralPath $xmlPath)) { continue }
        $text = [IO.File]::ReadAllText($xmlPath)
        if ($text -match '(?s)<title_id[^>]*>\s*([0-9A-Fa-f]{16})\s*</title_id>') {
            $tid = $Matches[1].ToUpperInvariant()
            if (-not $tid.StartsWith('00050002')) {
                throw "meta title_id must be a kiosk demo (00050002…), got $tid from: $xmlPath"
            }
            return $tid
        }
    }
    throw "Could not resolve title ID from folder name or meta.xml: $FolderPath"
}

function Test-RwkmLooksLikeDemoFolderName {
    param([string]$Name)
    # 8-char ID (optionally followed by separator + label) or full 16-char title ID.
    return [bool]($Name -match '^[0-9A-Fa-f]{16}(\b|[^0-9A-Fa-f]|$)' -or
        $Name -match '^[0-9A-Fa-f]{8}(\b|[^0-9A-Fa-f]|$)')
}

function Get-RwkmKioskMetaTitleId {
    param([string]$FolderPath)
    $kioskMeta = Join-Path $FolderPath 'meta\KioskMeta.xml'
    if (-not (Test-Path -LiteralPath $kioskMeta)) { return $null }
    $text = [IO.File]::ReadAllText($kioskMeta)
    if ($text -match '(?s)<titleID>\s*0x([0-9A-Fa-f]{16})\s*</titleID>') {
        $tid = $Matches[1].ToUpperInvariant()
        if ($tid.StartsWith('00050002')) { return $tid }
    }
    return $null
}

function Get-RwkmKioskSlcForDemoFolder {
    param(
        [string]$FolderPath,
        [hashtable]$Config,
        [string]$Override,
        [string[]]$NeededTitleIds = @()
    )
    if ($Override) {
        $resolvedOverride = Resolve-RwkmSlcExtractTree $Override
        if (-not (Test-Path -LiteralPath (Join-Path $resolvedOverride 'sys\rights\ticket'))) {
            throw "KioskSlcExtract missing ticket tree: $Override"
        }
        return (Resolve-Path -LiteralPath $resolvedOverride).Path
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($slcPath in @(
            $(if ($Config.KioskSlcExtract) { $Config.KioskSlcExtract } else { $null })
        )) {
        if ($slcPath) { $slcPath = Resolve-RwkmSlcExtractTree $slcPath }
        if ($slcPath -and (Test-Path -LiteralPath (Join-Path $slcPath 'sys\rights\ticket'))) {
            $full = (Resolve-Path -LiteralPath $slcPath).Path
            if ($candidates -notcontains $full) { [void]$candidates.Add($full) }
        }
    }

    $dir = $FolderPath
    for ($i = 0; $i -lt 8; $i++) {
        $dir = Split-Path -Parent $dir
        if (-not $dir) { break }
        foreach ($tryRoot in @((Join-Path $dir 'slc'), $dir)) {
            if (Test-Path -LiteralPath (Join-Path $tryRoot 'sys\rights\ticket')) {
                $full = (Resolve-Path -LiteralPath $tryRoot).Path
                if ($candidates -notcontains $full) { [void]$candidates.Add($full) }
            }
        }
    }

    if ($candidates.Count -eq 0) {
        $mutant = Join-Path $Config.MutantSlc 'sys\rights\ticket'
        if (Test-Path -LiteralPath $mutant) {
            Write-RwkmLog 'WARN: using mutant overlay tickets (region may not match demo folder)'
            return (Resolve-Path -LiteralPath $Config.MutantSlc).Path
        }
        throw @"
Could not find kiosk SLC ticket tree.

Pass -KioskSlcExtract pointing at dumps\kiosk (NAND Extractor output),
set KioskSlcExtract in config\config.ps1, or run build_mutant_slc.ps1.
"@
    }

    if ($candidates.Count -eq 1 -or $NeededTitleIds.Count -eq 0) {
        return $candidates[0]
    }

    $best = $candidates[0]
    $bestScore = -1
    foreach ($c in $candidates) {
        try {
            $idx = Build-RwkmTicketIndex -TicketRoot (Join-Path $c 'sys\rights\ticket')
            $score = @($NeededTitleIds | Where-Object { $idx.ContainsKey($_) }).Count
        } catch {
            $score = 0
        }
        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $c
        }
    }

    if ($bestScore -le 0) {
        Write-RwkmLog "WARN: no candidate SLC had tickets for $($NeededTitleIds -join ', '); using $best"
    } elseif ($candidates.Count -gt 1) {
        Write-RwkmLog "Ticket donor: $best (matched $bestScore / $($NeededTitleIds.Count) title IDs)"
    }
    return $best
}

function Get-RwkmPairedTitleIds {
    param(
        [string]$FolderPath,
        [switch]$SkipStubPair
    )
    $primary = Get-RwkmTitleIdFromDemoFolder -FolderPath $FolderPath
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    [void]$set.Add($primary)

    if ($SkipStubPair) { return @($set) | Sort-Object }

    $metaTid = Get-RwkmKioskMetaTitleId -FolderPath $FolderPath
    if ($metaTid) { [void]$set.Add($metaTid) }

    $parent = Split-Path -Parent $FolderPath
    if ($parent -and (Test-Path -LiteralPath $parent)) {
        foreach ($dir in Get-ChildItem -LiteralPath $parent -Directory) {
            if ($dir.FullName -eq $FolderPath) { continue }
            if (-not (Test-RwkmLooksLikeDemoFolderName -Name $dir.Name)) { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $dir.FullName 'meta\KioskMeta.xml'))) { continue }
            try {
                $sibTid = Get-RwkmTitleIdFromDemoFolder -FolderPath $dir.FullName
            } catch {
                continue
            }
            $sibMeta = Get-RwkmKioskMetaTitleId -FolderPath $dir.FullName
            if (-not $sibMeta) { continue }
            # Pair only when this sibling points at us, or we point at it.
            if ($sibMeta -eq $primary -or $sibTid -eq $primary -or
                ($metaTid -and ($sibTid -eq $metaTid -or $sibMeta -eq $metaTid))) {
                [void]$set.Add($sibTid)
                [void]$set.Add($sibMeta)
            }
        }
    }

    return @($set) | Sort-Object -Unique
}

function Resolve-RwkmDemoTitlePlan {
    param(
        [string[]]$Folders,
        [hashtable]$Config,
        [string]$KioskSlcExtract,
        [switch]$SkipStubPair
    )
    $allTids = New-Object 'System.Collections.Generic.HashSet[string]'
    $folderNotes = New-Object System.Collections.Generic.List[string]

    foreach ($folder in $Folders) {
        $resolved = (Resolve-Path -LiteralPath $folder).Path
        $tids = Get-RwkmPairedTitleIds -FolderPath $resolved -SkipStubPair:$SkipStubPair
        foreach ($tid in $tids) { [void]$allTids.Add($tid) }
        $leaf = Split-Path -Leaf $resolved
        [void]$folderNotes.Add("$leaf -> $($tids -join ', ')")
    }

    $needed = @($allTids | Sort-Object)
    $kioskSlc = Get-RwkmKioskSlcForDemoFolder -FolderPath (Resolve-Path -LiteralPath $Folders[0]).Path `
        -Config $Config -Override $KioskSlcExtract -NeededTitleIds $needed
    $ticketRoot = Join-Path $kioskSlc 'sys\rights\ticket'
    $index = Build-RwkmTicketIndex -TicketRoot $ticketRoot
    $owners = Get-RwkmTicketRelOwnerMap -TicketIndex $index

    $ticketPlan = New-Object System.Collections.Generic.List[hashtable]
    $missingTickets = New-Object System.Collections.Generic.List[string]
    foreach ($tid in $needed) {
        if ($index.ContainsKey($tid)) {
            [void]$ticketPlan.Add(@{
                TitleId   = $tid
                TicketRel = $index[$tid].TicketRel
                LocalPath = $index[$tid].LocalPath
            })
        } else {
            [void]$missingTickets.Add($tid)
            Write-RwkmLog "WARN: no .tik in $ticketRoot for $tid"
        }
    }

    return @{
        TitleIds          = $needed
        TicketPlan        = $ticketPlan
        MissingTickets    = @($missingTickets)
        TicketRelOwners   = $owners
        KioskSlc          = $kioskSlc
        FolderNotes       = $folderNotes
    }
}

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $cred = Get-RwkmFtpCredential -Config $cfg
    $base = Get-RwkmFtpBase -Config $cfg -Mount slc
    $remoteList = "$base/sys/rights/sys/title.list"

    $plan = Resolve-RwkmDemoTitlePlan -Folders $DemoFolder -Config $cfg `
        -KioskSlcExtract $KioskSlcExtract -SkipStubPair:$SkipStubPair

    Write-RwkmLog '=== Demo rights plan ==='
    Write-RwkmLog "Mode:       $Mode"
    Write-RwkmLog "Ticket src: $($plan.KioskSlc)"
    foreach ($note in $plan.FolderNotes) { Write-RwkmLog "  $note" }
    Write-RwkmLog "Title IDs:  $($plan.TitleIds -join ', ')"
    foreach ($t in $plan.TicketPlan) {
        Write-RwkmLog "  ticket $($t.TitleId) -> $($t.TicketRel)"
    }

    $bakRoot = Join-Path $cfg.LiveSlcBackup 'title_list_patches'
    New-Item -ItemType Directory -Force -Path $bakRoot | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $liveLocal = Join-Path $bakRoot "title.list.live.$stamp"
    $patchedLocal = Join-Path $bakRoot "title.list.patched.$stamp"

    $action = if ($Mode -eq 'Add') { 'ADD demo title IDs (+ tickets)' } else { 'REMOVE demo title IDs (+ tickets)' }
    $extra = @(
        "Title IDs: $($plan.TitleIds -join ', ')"
        $(if (-not $SkipTickets -and $plan.TicketPlan.Count -gt 0) {
            "Tickets:`n$(($plan.TicketPlan | ForEach-Object { "  $($_.TicketRel) ($($_.TitleId))" }) -join "`n")"
        } else { 'Tickets: (skipped)' })
        ''
        'MLC demo folders are NOT uploaded/deleted by this script - only SLC title.list and .tik files.'
    ) -join "`n"

    if (-not $SkipTickets -and $Mode -eq 'Add' -and @($plan.MissingTickets).Count -gt 0) {
        throw @"
Refusing Add: no .tik in the donor SLC for:
  $($plan.MissingTickets -join "`n  ")

Donor used: $($plan.KioskSlc)

Fix:
  - Pass -KioskSlcExtract to dumps\kiosk (or the kiosk dump that contains this demo)
  - or use -SkipStubPair if a video-tile sibling was pulled in and you only want the playable title
  - or -SkipTickets if you really want title.list only (tile may not launch)
"@
    }

    if ($plan.TitleIds.Count -gt 1 -and -not $SkipStubPair) {
        $pairPrompt = @(
            'This folder is paired with a stub/playable sibling. All of these title IDs will be changed:'
            ''
            "  $($plan.TitleIds -join "`n  ")"
            ''
            'Use -SkipStubPair to change only the folder you passed. Continue with the pair?'
        ) -join "`n"
        if (-not (Confirm-Rwkm -Level Warning -Prompt $pairPrompt -Force:$Force)) {
            throw 'Cancelled: stub/playable pair not confirmed. Re-run with -SkipStubPair for one title only.'
        }
    }

    if (-not $SkipTickets -and $Mode -eq 'Remove') {
        $sysish = @($plan.TicketPlan | Where-Object {
            $_.TicketRel -match '^(sys/|sys\\)' -or $_.TicketRel -notmatch '^(apps/|apps\\)'
        })
        if ($sysish.Count -gt 0) {
            throw @"
Refusing to delete non-apps ticket path(s) via demo Remove:
  $(($sysish | ForEach-Object { $_.TicketRel }) -join "`n  ")

Demo tickets live under apps/. Re-check -DemoFolder / ticket map.
"@
        }
    }

    Confirm-RwkmDeploymentMode -Config $cfg -Action "$action via patch_demo_rights_ftp.ps1" -Force:$Force | Out-Null
    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Action $action -Extra $extra -Force:$Force | Out-Null
    Assert-RwkmFtpReady -Config $cfg -Mount slc

    Invoke-RwkmFtpGet -RemoteUrl $remoteList -LocalPath $liveLocal -Credential $cred
    Write-RwkmLog "Backed up live title.list -> $liveLocal"

    $bytes = [IO.File]::ReadAllBytes($liveLocal)
    $set = Read-RwkmTitleListSet $bytes
    $before = $set.Count

    foreach ($tid in $plan.TitleIds) {
        if ($Mode -eq 'Add') {
            [void]$set.Add($tid.ToUpperInvariant())
        } else {
            [void]$set.Remove($tid.ToUpperInvariant())
        }
    }

    if ($set.Count -eq 0) {
        throw @"
Refusing to upload an empty title.list (would wipe the kiosk catalog).

Live backup kept at:
  $liveLocal

Re-check -Mode Remove / -DemoFolder, or restore title.list from that backup.
"@
    }

    $patchedBytes = Write-RwkmTitleListBytes $set
    [IO.File]::WriteAllBytes($patchedLocal, $patchedBytes)

    if (-not $SkipTickets) {
        foreach ($t in $plan.TicketPlan) {
            $remoteTik = "$base/sys/rights/ticket/$($t.TicketRel)"
            if ($Mode -eq 'Add') {
                Invoke-RwkmFtpPut -LocalPath $t.LocalPath -RemoteUrl $remoteTik -Credential $cred
                Write-RwkmLog "  uploaded ticket $($t.TicketRel)"
            } else {
                $owners = @()
                if ($plan.TicketRelOwners -and $plan.TicketRelOwners.ContainsKey($t.TicketRel)) {
                    $owners = @($plan.TicketRelOwners[$t.TicketRel])
                }
                $stillNeeded = @($owners | Where-Object { $set.Contains($_.ToUpperInvariant()) })
                if ($stillNeeded.Count -gt 0) {
                    Write-RwkmLog "  skip delete $($t.TicketRel) - still needed by $($stillNeeded -join ', ')"
                    continue
                }
                Invoke-RwkmFtpDelete -RemoteUrl $remoteTik -Credential $cred
                Write-RwkmLog "  deleted ticket $($t.TicketRel)"
            }
        }
    }

    Invoke-RwkmFtpPut -LocalPath $patchedLocal -RemoteUrl $remoteList -Credential $cred
    Write-RwkmLog "title.list: $before -> $($set.Count) entries ($Mode)"

    Write-RwkmLog 'Reboot the console before testing launches.'
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
