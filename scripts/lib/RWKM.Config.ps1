# Shared config loader for RetailWiiUKioskMenu scripts.
#
# Never silently use config.example.ps1 for live work — that file has placeholders
# (YOUR_WIIU_IP, empty drive letter) meant for copying, not for FTP/disk writes.

if (-not (Get-Command Get-RwkmRepoRoot -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'RWKM.Safety.ps1')
}

function Get-RwkmConfigPath {
    param([string]$ConfigPath)
    if ($ConfigPath) {
        if (-not (Test-Path -LiteralPath $ConfigPath)) {
            throw "Config file not found: $ConfigPath"
        }
        return $ConfigPath
    }
    $default = Join-Path (Get-RwkmRepoRoot) 'config\config.ps1'
    if (Test-Path -LiteralPath $default) { return $default }

    throw @"
config\config.ps1 not found.

This repo does not use config.example.ps1 automatically (it contains placeholders
that could target the wrong PC drive or Wii U).

Fix:  .\scripts\setup_config.ps1
  or copy config\config.example.ps1 -> config\config.ps1 and edit FtpHost + SdDriveLetter.
"@
}

function Get-RwkmRelativeUnixPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$FullPath
    )
    # Resolve .\ segments so Substring length matches Get-ChildItem FullName
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $fileFull = [IO.Path]::GetFullPath($FullPath)
    if (-not $fileFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path not under root:`n  Root=$rootFull`n  File=$fileFull"
    }
    return $fileFull.Substring($rootFull.Length).TrimStart('\').Replace('\', '/')
}

function Import-RwkmConfig {
    param(
        [string]$ConfigPath,
        [switch]$AskRegion,
        [switch]$SkipRegionPrompt
    )

    $path = Get-RwkmConfigPath -ConfigPath $ConfigPath
    $cfg = . $path
    if ($cfg -isnot [hashtable]) { throw "Config must return a hashtable: $path" }

    $root = Get-RwkmRepoRoot
    function Resolve-CfgPath([string]$p) {
        if ([string]::IsNullOrWhiteSpace($p)) { return '' }
        if ([IO.Path]::IsPathRooted($p)) { return $p }
        return (Join-Path $root $p)
    }

    foreach ($key in @(
        'SlcRawPath','SlccmptRawPath','StrippedDir','RetailSlcExtract','KioskSlcExtract',
        'MutantSlc','LiveSlcBackup','KioskMlcSysTitleRoot'
    )) {
        if ($cfg.ContainsKey($key)) { $cfg[$key] = Resolve-CfgPath $cfg[$key] }
    }

    if ($cfg.StrippedDir) {
        New-Item -ItemType Directory -Force -Path $cfg.StrippedDir | Out-Null
    }

    $resolvedRoots = @()
    foreach ($r in @($cfg.SearchRoots)) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        if ($r -match '^[A-Za-z]:\\?$') {
            $resolvedRoots += $r.TrimEnd('\')
        } elseif ([IO.Path]::IsPathRooted($r)) {
            $resolvedRoots += $r
        } else {
            $resolvedRoots += (Join-Path $root $r)
        }
    }
    $cfg.SearchRoots = $resolvedRoots

    $regionOk = $cfg.Region -and $cfg.Region.ToString().ToUpperInvariant() -match '^(USA|PAL)$'
    if (-not $regionOk -and -not $SkipRegionPrompt) {
        if (-not (Get-Command Ask-RwkmRegion -ErrorAction SilentlyContinue)) {
            . (Join-Path $PSScriptRoot 'RWKM.Safety.ps1')
            . (Join-Path $PSScriptRoot 'RWKM.Region.ps1')
        }
        Write-Host ''
        Write-Host 'Region (USA or PAL) is not set in config.ps1.' -ForegroundColor Yellow
        $picked = Ask-RwkmRegion
        $cfg = Apply-RwkmRegionPreset -Config $cfg -Region $picked
        Write-Host "Using region: $picked (save it with scripts\setup_config.ps1)" -ForegroundColor Yellow
    } elseif ($regionOk) {
        if (Get-Command Apply-RwkmRegionPreset -ErrorAction SilentlyContinue) {
            $cfg = Apply-RwkmRegionPreset -Config $cfg -Region $cfg.Region.ToString().ToUpperInvariant()
        }
    }

    return $cfg
}

function Assert-RwkmMutantReady {
    param(
        [Parameter(Mandatory = $true)][string]$MutantSlc,
        [string[]]$RequiredRelPaths = @(
            'sys\config\system.xml',
            'sys\config\sys_prod.xml',
            'sys\rights\sys\cert.sys',
            'sys\rights\sys\title.list'
        )
    )

    if (-not (Test-Path -LiteralPath $MutantSlc)) {
        throw @"
Mutant SLC folder missing: $MutantSlc

Fix: run  .\scripts\build_mutant_slc.ps1
(after setting RetailSlcExtract / KioskSlcExtract in config.ps1).
"@
    }

    $missing = @()
    foreach ($rel in $RequiredRelPaths) {
        $p = Join-Path $MutantSlc $rel
        if (-not (Test-Path -LiteralPath $p)) { $missing += $rel }
    }
    if ($missing.Count -gt 0) {
        throw @"
Mutant overlay is incomplete under: $MutantSlc

Missing:
  $($missing -join "`n  ")

Fix: run  .\scripts\build_mutant_slc.ps1 -Rebuild
"@
    }
}

function Find-RwkmPython {
    foreach ($name in @('py', 'python', 'python3')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        if ($name -eq 'py') {
            return @{ Exe = $cmd.Source; Args = @('-3') }
        }
        # Avoid the Windows Store stub that opens the Store when Python is missing
        try {
            $ver = & $cmd.Source --version 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0 -and $ver -notmatch 'Python') { continue }
            if ($ver -match 'Python') {
                return @{ Exe = $cmd.Source; Args = @() }
            }
        } catch { continue }
    }
    throw @"
Python 3 was not found (tried: py -3, python, python3).

Needed for: validate_slc_dump.ps1 (ISFS fw.img walk before flashing).

Fix: install Python 3 from https://www.python.org/downloads/
  and tick "Add python.exe to PATH", then open a new PowerShell window.
"@
}

function Find-RwkmRawDump {
    param(
        [ValidateSet('slc','slccmpt')]
        [string]$Kind,
        [string[]]$SearchRoots,
        [string]$ExplicitPath = ''
    )

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) {
            throw "Explicit ${Kind} RAW path not found: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $patterns = if ($Kind -eq 'slc') {
        @('SLC.RAW','slc.raw','SLC.raw','slc.bin','SLC.bin','slc.RAW')
    } else {
        @('SLCCMPT.RAW','slccmpt.raw','SLCCMPT.raw','slccmpt.bin','SLCCMPT.bin','slccmpt.RAW')
    }

    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($name in $patterns) {
            $candidate = Join-Path $root $name
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
    }

    throw @"
Could not find ${Kind} RAW dump.

Fix:
  - Place SLC.RAW / SLCCMPT.RAW on the SD FAT partition, and set SdDriveLetter so SearchRoots includes that drive
  - or set SlcRawPath / SlccmptRawPath in config.ps1 to the full file path
"@
}

function Get-RwkmStrippedPath {
    param(
        [string]$StrippedDir,
        [ValidateSet('slc','slccmpt')]
        [string]$Kind,
        [string]$SourceRawPath = ''
    )
    $base = if ($SourceRawPath) {
        [IO.Path]::GetFileNameWithoutExtension($SourceRawPath)
    } else { $Kind }
    $safe = ($base -replace '[^\w\-]', '_')
    return Join-Path $StrippedDir "${safe}.stripped.bin"
}

function Initialize-RwkmScript {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$Force
    )

    $lib = $PSScriptRoot
    if ($lib -match '\\lib$') {
        $lib = Split-Path $lib -Parent
    }
    . (Join-Path $lib 'lib\RWKM.Safety.ps1')
    . (Join-Path $lib 'lib\RWKM.Region.ps1')
    . (Join-Path $lib 'lib\RWKM.Config.ps1')

    $script:RwkmForce = [bool]$Force
    Start-RwkmSession -Name $Name | Out-Null
}

function Get-RwkmDeploymentMode {
    param([hashtable]$Config)
    $raw = if ($Config.ContainsKey('DeploymentMode') -and $Config.DeploymentMode) {
        $Config.DeploymentMode.ToString()
    } else {
        'Hybrid'
    }
    switch -Regex ($raw.Trim()) {
        '^(Hybrid|Path1|1)$' { return 'Hybrid' }
        '^(FullRedNand|Full|2)$' { return 'FullRedNand' }
        '^(SysNand|Sys|CAT-?I|3)$' { return 'SysNand' }
        default {
            throw "Unknown DeploymentMode '$raw'. Use Hybrid, FullRedNand, or SysNand. See docs\REDNAND.md or docs\SYSNAND.md"
        }
    }
}

function Get-RwkmRednandIniForMode {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Hybrid', 'FullRedNand', 'SysNand')][string]$Mode,
        [string]$RepoRoot = ''
    )
    if (-not $RepoRoot) { $RepoRoot = Get-RwkmRepoRoot }
    switch ($Mode) {
        'Hybrid' { return Join-Path $RepoRoot 'config\rednand.hybrid.ini' }
        'FullRedNand' { return Join-Path $RepoRoot 'config\rednand.full.ini' }
        'SysNand' { return $null }  # remove / disable rednand.ini
    }
}

function Confirm-RwkmDeploymentMode {
    param(
        [hashtable]$Config,
        [string]$Action,
        [switch]$Force
    )
    $mode = Get-RwkmDeploymentMode -Config $Config
    $blurb = switch ($mode) {
        'Hybrid' {
            'Mode Hybrid: redSLC on SD + sys MLC. Keep SD inserted while Kiosk Menu runs.'
        }
        'FullRedNand' {
            'Mode FullRedNand: SLC+MLC on SD. Retail internal games are NOT on red MLC unless you copied them. Keep SD inserted.'
        }
        'SysNand' {
            'Mode SysNand: FTP targets REAL internal SLC/MLC. Boot WITHOUT rednand.ini (or without redNAND SD). Highest brick risk - have minute backups.'
        }
    }
    $prompt = @(
        $blurb
        ''
        "About to: $Action"
        "DeploymentMode = $mode"
        ''
        'Wrong mode + wrong boot layout = patching the wrong storage. Continue?'
    ) -join "`n"
    $level = if ($mode -eq 'SysNand') { 'Critical' } else { 'Warning' }
    if (-not (Confirm-Rwkm -Level $level -Prompt $prompt -Force:$Force)) {
        throw "Cancelled: DeploymentMode $mode not confirmed."
    }
    return $mode
}
