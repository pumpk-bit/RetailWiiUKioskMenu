# Upload sys title folder(s) from extracted kiosk MLC to live storage_mlc via FTP.
#
# Why: Kiosk Menu + native SCT must exist on MLC for Home -> SCT -> Kiosk Menu.
# We refuse obvious failed wfs extracts (0-byte / dummy.txt) unless you override.

param(
    [string]$ConfigPath = '',
    [string]$SourceRoot = '',
    [string[]]$TitleIds = @(),
    [string]$FtpHost = '',
    [int]$Port = 0,
    [switch]$IncludeSugarBoot,
    [switch]$WhatIf,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Region.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'upload_sys_title_mlc' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    if ($FtpHost) { $cfg.FtpHost = $FtpHost }
    if ($Port) { $cfg.FtpPort = $Port }

    $source = if ($SourceRoot) { $SourceRoot } else { $cfg.KioskMlcSysTitleRoot }
    $cred = Get-RwkmFtpCredential -Config $cfg
    $baseUrl = "$(Get-RwkmFtpBase -Config $cfg -Mount mlc)/sys/title/00050010"

    # Defaults match config.example.ps1 / setup_config.ps1 (avoid null.ToLowerInvariant crashes).
    $kioskMenuId = if ($cfg.ContainsKey('KioskMenuTitleId') -and $cfg.KioskMenuTitleId) {
        $cfg.KioskMenuTitleId.ToString().ToLowerInvariant()
    } else { '1fa81000' }
    $nativeSctId = if ($cfg.ContainsKey('NativeSctTitleId') -and $cfg.NativeSctTitleId) {
        $cfg.NativeSctTitleId.ToString().ToLowerInvariant()
    } else { '1f700500' }
    $sugarBootId = if ($cfg.ContainsKey('SugarBootTitleId') -and $cfg.SugarBootTitleId) {
        $cfg.SugarBootTitleId.ToString().ToLowerInvariant()
    } else { '1fa83200' }

    if (-not $TitleIds -or $TitleIds.Count -eq 0) {
        # Native SCT is required to launch Kiosk Menu from Home on retail hybrid setups.
        $TitleIds = @($kioskMenuId, $nativeSctId)
        if ($IncludeSugarBoot) { $TitleIds += $sugarBootId }
    }

    $totalFiles = 0
    $totalBytes = 0L
    foreach ($tid in $TitleIds) {
        if ([string]::IsNullOrWhiteSpace($tid)) {
            throw 'TitleIds contains an empty entry. Pass real 8-char IDs or set KioskMenuTitleId / NativeSctTitleId in config.ps1.'
        }
        $tidNorm = $tid.ToString().ToLowerInvariant()
        $localRoot = Join-Path $source $tidNorm
        if (-not (Test-Path -LiteralPath $localRoot)) {
            if ($tidNorm -eq $nativeSctId) {
                throw @"
Missing native SCT folder: $localRoot

Native SCT (1f700500) is required to launch Kiosk Menu from Home unless retail/homebrew SCT (13374454) is already installed via WUP Installer GX.

Fix: re-extract native SCT from kiosk MLC, or install retail SCT on the console, or upload Kiosk Menu only:
  .\scripts\upload_sys_title_mlc.ps1 -TitleIds @('$kioskMenuId')
"@
            }
            throw "Missing source folder: $localRoot - set KioskMlcSysTitleRoot in config.ps1"
        }
        $files = Get-ChildItem $localRoot -Recurse -File
        $totalFiles += $files.Count
        $totalBytes += ($files | Measure-Object Length -Sum).Sum

        $empty = @($files | Where-Object { $_.Length -eq 0 })
        $stubs = @($files | Where-Object { $_.Name -ieq 'dummy.txt' })
        if ($empty.Count -gt 0 -or $stubs.Count -gt 0) {
            $badPrompt = @(
                "Title $tid has signs of a FAILED wfs-tools extract:"
                "  0-byte files: $($empty.Count)"
                "  dummy.txt stubs: $($stubs.Count)"
                ''
                'Broken sys titles can crash the system (worse than bad games).'
                'Fix the extract or remove this title before uploading.'
                ''
                'Continue uploading this title anyway?'
            ) -join "`n"
            if (-not (Confirm-Rwkm -Level Critical -Prompt $badPrompt -Force:$Force)) {
                throw "Cancelled: title $tid looks like a failed extract."
            }
        }
    }

    $totalMb = [math]::Round($totalBytes / 1MB, 1)
    if (-not $WhatIf) {
        $mode = Confirm-RwkmDeploymentMode -Config $cfg -Action 'UPLOAD titles to storage_mlc' -Force:$Force
        $mlcWhere = switch ($mode) {
            'FullRedNand' { 'red MLC on SD (not your retail game library unless copied)' }
            'SysNand' { 'sys MLC (INTERNAL)' }
            default { 'sys MLC (INTERNAL) - hybrid' }
        }
        Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount mlc -Force:$Force -Action 'Upload kiosk sys titles' -Extra @"
  Region:  $($cfg.Region)
  Storage: $mlcWhere
  Titles:  $($TitleIds -join ', ')
  Files:   $totalFiles (~$totalMb MB)
  Source:  $source
"@
        Assert-RwkmFtpReady -Config $cfg -Mount mlc
    }

    function Upload-TitleTree {
        param([string]$TitleId)
        $localRoot = Join-Path $source $TitleId
        if (-not (Test-Path -LiteralPath $localRoot)) {
            throw "Missing source folder: $localRoot"
        }
        # Resolve .\ in config paths — raw Substring on an unresolved root eats the first path char
        # (code->ode, content->ontent, meta->eta) and uploads to the wrong MLC folders.
        $localRoot = (Resolve-Path -LiteralPath $localRoot).Path
        $files = Get-ChildItem $localRoot -Recurse -File
        $fileMb = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2)
        Write-RwkmLog ('Uploading {0} ({1} files, {2} MB)...' -f $TitleId, $files.Count, $fileMb)
        $i = 0
        foreach ($file in $files) {
            $i++
            $rel = Get-RwkmRelativeUnixPath -Root $localRoot -FullPath $file.FullName
            $remote = "$baseUrl/$TitleId/$rel"
            Write-RwkmLog "  [$i/$($files.Count)] $rel"
            if ($WhatIf) {
                Write-RwkmLog "    [whatif] -> $remote"
                continue
            }
            Invoke-RwkmFtpPut -LocalPath $file.FullName -RemoteUrl $remote -Credential $cred
        }
        Write-RwkmLog "Done: $TitleId"
    }

    Write-RwkmLog '=== Upload sys titles to storage_mlc ==='
    Write-RwkmLog "Source: $source"
    Write-RwkmLog "Target: $baseUrl"

    foreach ($tid in $TitleIds) {
        Upload-TitleTree -TitleId $tid.ToLowerInvariant()
    }

    Write-RwkmLog 'Next: Home Menu -> System Config Tool -> Kiosk Menu.'
    Write-RwkmLog 'SCT: native 1f700500 (this upload) OR retail/homebrew 13374454 (WUP Installer GX).'
    Write-RwkmLog 'Do not change coldboot until that works. See README: Default boot, stub titles.'
    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
