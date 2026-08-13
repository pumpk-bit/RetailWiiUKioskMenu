# Interactive setup - region (USA/PAL), paths, FTP, SD drive letter.
# Never invent a drive letter (no default E:). User must type the letter from This PC.

param(
    [string]$OutPath = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Safety.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Region.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Disk.ps1')

Start-RwkmSession -Name 'setup_config' | Out-Null

try {
    $repo = Get-RwkmRepoRoot
    $out = if ($OutPath) { $OutPath } else { Join-Path $repo 'config\config.ps1' }

    Write-Host ''
    Write-Host '=== Retail Wii U Kiosk Menu - config setup ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'This writes config\config.ps1 for YOUR PC and YOUR Wii U.' -ForegroundColor Yellow
    Write-Host 'Scripts will refuse to run until FtpHost and SdDriveLetter are real values.'
    Write-Host ''

    $region = Ask-RwkmRegion
    $presets = Get-RwkmRegionPresets
    $p = $presets[$region]

    Write-Host ''
    Write-Host 'Deployment mode (where SLC/MLC live):' -ForegroundColor Cyan
    Write-Host '  1) Hybrid      - redSLC on SD + sys MLC (lab default; keep SD in while Kiosk Menu runs)'
    Write-Host '  2) FullRedNand - SLC+MLC on SD (isolated kiosk SD; retail games not included)'
    Write-Host '  3) SysNand     - real console SLC+MLC (CAT-I on hardware; highest risk; SD removable after)'
    Write-Host '  See docs\REDNAND.md (1-2) or docs\SYSNAND.md (3)'
    Write-Host ''
    $mode = 'Hybrid'
    while ($true) {
        $pick = Read-Host 'Enter 1, 2, or 3 [1]'
        if ([string]::IsNullOrWhiteSpace($pick) -or $pick -eq '1') { $mode = 'Hybrid'; break }
        if ($pick -eq '2') { $mode = 'FullRedNand'; break }
        if ($pick -eq '3') { $mode = 'SysNand'; break }
        Write-Host 'Please type 1, 2, or 3.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host "Selected: $($p.Label) / DeploymentMode=$mode" -ForegroundColor Green
    Write-Host ''

    $ftpHost = ''
    while ([string]::IsNullOrWhiteSpace($ftpHost) -or $ftpHost -match 'YOUR_WIIU|CHANGE_ME') {
        $ftpHost = Read-Host 'Wii U IP address (FtpHost) - shown by FTPiiU on the console'
        if ([string]::IsNullOrWhiteSpace($ftpHost) -or $ftpHost -match 'YOUR_WIIU|CHANGE_ME') {
            Write-Host 'Enter a real LAN IP like 192.168.1.50 (not a placeholder).' -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host 'SD card: open This PC and find the drive that has a \minute\ folder.' -ForegroundColor Cyan
    Write-Host 'Type ONLY the letter (example: F). We look up the disk number from that letter.'
    Write-Host 'We will NOT guess E: or auto-pick a USB stick.'
    Write-Host ''

    $sdLetter = ''
    $diskNum = $null
    while (-not $sdLetter) {
        $raw = Read-Host 'SD drive letter with \minute\ (required)'
        $sdLetter = Get-RwkmNormalizedDriveLetter $raw
        if (-not $sdLetter) {
            Write-Host 'Drive letter is required.' -ForegroundColor Yellow
            continue
        }
        if ($sdLetter -notmatch '^[A-Z]$') {
            Write-Host 'Type a single letter A-Z.' -ForegroundColor Yellow
            $sdLetter = ''
            continue
        }
        if (-not (Test-Path -LiteralPath "${sdLetter}:\")) {
            Write-Host "Drive ${sdLetter}: is not available. Insert the SD and try again." -ForegroundColor Yellow
            $sdLetter = ''
            continue
        }
        $minutePath = "${sdLetter}:\minute"
        if (-not (Test-Path -LiteralPath $minutePath)) {
            Write-Host "No \minute\ folder on ${sdLetter}: - wrong letter? Continue anyway only if you are sure." -ForegroundColor Yellow
            if (-not (Confirm-Rwkm -Level Warning -Prompt "Use ${sdLetter}: even without \minute\?")) {
                $sdLetter = ''
                continue
            }
        }
        try {
            $tmpCfg = @{ SdDriveLetter = $sdLetter; SdDiskNumber = $null }
            $diskNum = Get-RwkmSdDiskNumber -Config $tmpCfg
            Write-Host "Resolved: drive ${sdLetter}: -> PhysicalDrive$diskNum" -ForegroundColor Green
        } catch {
            Write-Host $_.Exception.Message -ForegroundColor Yellow
            Write-Host 'You can still save the letter; flash scripts need Admin to resolve the disk.' -ForegroundColor Yellow
            if (-not (Confirm-Rwkm -Level Warning -Prompt "Save SdDriveLetter=${sdLetter} anyway?")) {
                $sdLetter = ''
            }
        }
    }

    Write-Host ''
    Write-Host 'Dump folder paths (press Enter for defaults for your region):' -ForegroundColor Cyan
    $retailSlc = Read-Host "Retail SLC extract [$($p.RetailSlcExtract)]"
    if ([string]::IsNullOrWhiteSpace($retailSlc)) { $retailSlc = $p.RetailSlcExtract }

    $kioskSlc = Read-Host "Kiosk SLC extract [$($p.KioskSlcExtract)]"
    if ([string]::IsNullOrWhiteSpace($kioskSlc)) { $kioskSlc = $p.KioskSlcExtract }

    $kioskMlc = Read-Host "Kiosk MLC titles [$($p.KioskMlcSysTitleRoot)]"
    if ([string]::IsNullOrWhiteSpace($kioskMlc)) { $kioskMlc = $p.KioskMlcSysTitleRoot }

    $diskLine = if ($null -ne $diskNum) { "PhysicalDrive$diskNum (from ${sdLetter}:)" } else { '(resolved later from drive letter)' }
    $summary = @"
Region:              $region ($($p.Label))
DeploymentMode:      $mode
Home Menu title ID:  $($p.RetailSystemMenuTitleId)
FtpHost:             $ftpHost
SdDriveLetter:       $sdLetter
Sd disk:             $diskLine
RetailSlcExtract:    $retailSlc
KioskSlcExtract:     $kioskSlc
KioskMlcSysTitleRoot: $kioskMlc
"@

    Write-Host ''
    Write-Host $summary
    Write-Host ''

    if (-not (Confirm-Rwkm -Level Warning -Prompt 'Write this to config\config.ps1?' -Force:$Force)) {
        throw 'Cancelled: config not saved.'
    }

    $content = @"
# Generated by setup_config.ps1 on $(Get-Date -Format o)
# Region: $region ($($p.Label))
# Mode: $mode - see docs/REDNAND.md or docs/SYSNAND.md
# SD: drive ${sdLetter}: -> disk resolved at runtime from this letter (SdDiskNumber left null)

@{
    Region = '$region'
    DeploymentMode = '$mode'

    FtpHost     = '$ftpHost'
    FtpPort     = 21
    FtpUser     = ''
    FtpPass     = ''

    # Letter of the SD FAT partition (This PC). Disk number is looked up from this letter.
    SdDriveLetter = '$sdLetter'
    SdDiskNumber  = `$null

    SlcRawPath       = ''
    SlccmptRawPath   = ''

    SearchRoots = @(
        '${sdLetter}:\'
        '.\dumps'
        '.\stripped'
    )

    StrippedDir = '.\stripped'

    RetailSlcExtract = '$retailSlc'
    KioskSlcExtract  = '$kioskSlc'

    MutantSlc = '.\overlay\mutant\slc'
    LiveSlcBackup = '.\backup\live_slc_pre_mutant'

    KioskMlcSysTitleRoot = '$kioskMlc'

    KioskMenuTitleId = '1fa81000'
    NativeSctTitleId = '1f700500'
    SugarBootTitleId = '1fa83200'

    RetailSystemMenuTitleId = '$($p.RetailSystemMenuTitleId)'
}
"@

    $outDir = Split-Path -Parent $out
    if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
    Set-Content -LiteralPath $out -Value $content -Encoding UTF8

    Write-RwkmLog "Wrote $out"
    Write-Host ''
    Write-Host "Saved: $out" -ForegroundColor Green
    Write-Host 'Next: follow docs\REDNAND.md or docs\SYSNAND.md. Scripts ask Y/N before every Wii U write.'

    Stop-RwkmSession -ExitCode 0 -AlwaysPause
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
