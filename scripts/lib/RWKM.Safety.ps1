# Logging, Y/N confirmations, and session exit handling.
#
# Policy: default answer is N. Every risky change should call Confirm-Rwkm
# (or Confirm-RwkmFileWrite / Confirm-RwkmPhysicalWrite / Confirm-RwkmWiiUFtpWrite)
# so beginners see what will change before anything is written.

$script:RwkmLogPath = $null
$script:RwkmSessionName = $null
$script:RwkmRepoRootCached = $null

function Get-RwkmRepoRoot {
    if ($script:RwkmRepoRootCached) { return $script:RwkmRepoRootCached }
    $lib = $PSScriptRoot
    $script:RwkmRepoRootCached = (Resolve-Path (Join-Path $lib '..\..')).Path
    return $script:RwkmRepoRootCached
}

function Confirm-RwkmFileWrite {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string]$Description = '',
        [ValidateSet('Normal', 'Warning', 'Critical')][string]$Level = 'Warning',
        [switch]$Force
    )

    $srcLine = if ($Source) { "  From: $Source" } else { '' }
    $desc = if ($Description) { "`n$Description" } else { '' }
    $msg = @"
About to write/copy files:

  To:   $Destination
$srcLine
$desc
"@
    if (-not (Confirm-Rwkm -Level $Level -Prompt $msg -Force:$Force)) {
        throw 'Cancelled: file write not confirmed.'
    }
}

function Start-RwkmSession {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$LogDir = ''
    )
    $script:RwkmSessionName = $Name
    if (-not $LogDir) {
        $LogDir = Join-Path (Get-RwkmRepoRoot) 'logs'
    }
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $script:RwkmLogPath = Join-Path $LogDir ("{0}_{1:yyyyMMdd_HHmmss}.log" -f $Name, (Get-Date))
    "START $(Get-Date -Format o) - $Name" | Out-File -LiteralPath $script:RwkmLogPath -Encoding utf8
    Write-RwkmLog "Log file: $script:RwkmLogPath"
    return $script:RwkmLogPath
}

function Write-RwkmLog {
    param([string]$Message)
    $line = "$(Get-Date -Format 'HH:mm:ss') $Message"
    Write-Host $line
    if ($script:RwkmLogPath) {
        Add-Content -LiteralPath $script:RwkmLogPath -Value $line -Encoding utf8
    }
}

function Confirm-Rwkm {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [ValidateSet('Normal', 'Warning', 'Critical')][string]$Level = 'Warning',
        [switch]$DefaultYes,
        [switch]$Force
    )

    if ($Force) {
        Write-RwkmLog "CONFIRM [$Level] (forced yes): $Prompt"
        return $true
    }

    Write-Host ''
    $color = switch ($Level) {
        'Critical' { 'Red' }
        'Warning'  { 'Yellow' }
        default    { 'Cyan' }
    }
    Write-Host "[$Level] $Prompt" -ForegroundColor $color
    $hint = if ($DefaultYes) { 'Y/n' } else { 'y/N' }
    $raw = Read-Host "Type Y to continue, N to cancel ($hint)"

    $yes = $false
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $yes = [bool]$DefaultYes
    } else {
        $yes = $raw.Trim().ToUpperInvariant() -eq 'Y'
    }

    Write-RwkmLog "CONFIRM [$Level]: $Prompt -> $(if ($yes) { 'YES' } else { 'NO' })"
    return $yes
}

function Stop-RwkmSession {
    param(
        [int]$ExitCode = 0,
        [switch]$PauseOnError,
        [switch]$AlwaysPause
    )

    if ($ExitCode -ne 0) {
        Write-RwkmLog "Finished with errors (exit $ExitCode)."
        if ($script:RwkmLogPath) {
            Write-Host ''
            Write-Host "Full log saved to:" -ForegroundColor Yellow
            Write-Host "  $script:RwkmLogPath" -ForegroundColor Yellow
        }
    } else {
        Write-RwkmLog 'Finished OK.'
        if ($script:RwkmLogPath) {
            Write-Host "Log: $script:RwkmLogPath"
        }
    }

    if ($AlwaysPause -or (($PauseOnError -or $ExitCode -ne 0) -and -not $env:RWKM_NO_PAUSE)) {
        Write-Host ''
        Read-Host 'Press Enter to close this window'
    }

    exit $ExitCode
}

# Expected sizes (Wii U redNAND)
$script:RwkmSizeRawSlc     = 553648128L
$script:RwkmSizeStripped   = 536870912L
$script:RwkmSectorsSlcPart = 1048576L

function Test-RwkmSlcImageSize {
    param(
        [string]$FilePath,
        [ValidateSet('raw', 'stripped', 'any')][string]$Expected = 'stripped',
        [switch]$Force
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "File not found: $FilePath"
    }

    $sz = (Get-Item -LiteralPath $FilePath).Length
    Write-RwkmLog "Size check: $FilePath = $sz bytes"

    if ($Expected -eq 'raw' -or $Expected -eq 'any') {
        if ($sz -eq $script:RwkmSizeRawSlc) { return @{ Ok = $true; Kind = 'raw'; Size = $sz } }
    }
    if ($Expected -eq 'stripped' -or $Expected -eq 'any') {
        if ($sz -eq $script:RwkmSizeStripped) { return @{ Ok = $true; Kind = 'stripped'; Size = $sz } }
    }

    if ($sz -gt $script:RwkmSizeStripped) {
        $mb = [math]::Round($sz / 1MB, 1)
        $sizePrompt = @(
            "File is $mb MB but an SLC/SLCCMPT partition is only 512 MB (536870912 bytes)."
            'Writing this file will overwrite the wrong amount of data and may corrupt your SD card.'
            "File: $FilePath"
        ) -join "`n"
        $ok = Confirm-Rwkm -Level Critical -Prompt $sizePrompt -Force:$Force
        if (-not $ok) { throw 'Cancelled: file too large for SLC partition.' }
        return @{ Ok = $false; Kind = 'oversize'; Size = $sz }
    }

    if ($sz -lt $script:RwkmSizeStripped -and $Expected -ne 'any') {
        $smallPrompt = "File is smaller than expected 512 MB stripped image ($sz bytes). Continue anyway?"
        $ok = Confirm-Rwkm -Level Warning -Prompt $smallPrompt -Force:$Force
        if (-not $ok) { throw 'Cancelled: unexpected file size.' }
    }

    return @{ Ok = $false; Kind = 'unexpected'; Size = $sz }
}

function Get-RwkmKioskMenuDefaultWarning {
    return @(
        'Make KIOSK MENU the default boot app on every startup?'
        ''
        'WARNING - YOU CAN GET TRAPPED:'
        '  - The Wii U boots straight into Kiosk Menu every time.'
        '  - Home Menu never loads, so FTP / Aroma plugins never start.'
        '  - make_home_menu_default.ps1 CANNOT undo this once you are stuck.'
        '  - Recovery: reflash SLC (redNAND: flash SD partition; SysNand: minute restore from offline dump).'
        ''
        'RECOMMENDED (safer):'
        '  - Keep Home Menu as the default boot title (what build_mutant_slc.ps1 does).'
        '  - Open System Config Tool from Home, then launch Kiosk Menu from SCT.'
        '  - Native SCT (1f700500) is uploaded with Kiosk Menu; or use retail SCT (13374454) via WUP Installer GX.'
    ) -join "`n"
}

function Confirm-RwkmKioskMenuDefault {
    param([switch]$Force)
    return Confirm-Rwkm -Level Critical -Prompt (Get-RwkmKioskMenuDefaultWarning) -Force:$Force
}

function Get-RwkmSystemXmlPolicyWarning {
    return @(
        'Upload mutant system.xml to live SLC?'
        ''
        'This merges kiosk policy into system.xml (standby, reset_on_crash, simulated_ppc_mem2_size).'
        'Kiosk Menu rights work WITHOUT this file if you keep retail system.xml.'
        ''
        'WARNING - COULD CAUSE INSTABILITY:'
        '  - reset_on_crash=1 reboots the console on crashes instead of showing an error.'
        '  - simulated_ppc_mem2_size=1 can affect memory behavior.'
        '  - Kiosk standby settings differ from retail.'
        '  - Retail hardware testing showed random reboots after full kiosk policy apply.'
        ''
        'RECOMMENDED: answer N (default). Launch Kiosk Menu from Home -> SCT instead.'
    ) -join "`n"
}

function Confirm-RwkmSystemXmlPolicy {
    param([switch]$Force)
    return Confirm-Rwkm -Level Warning -Prompt (Get-RwkmSystemXmlPolicyWarning) -Force:$Force
}

function Read-RwkmJsonArrayFile {
    # Return List[object] of JSON array elements.
    # Avoids PS 5.1 pitfalls: @(ConvertFrom-Json) wrapping, and single-element return unwrap.
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }
    $list = New-Object 'System.Collections.Generic.List[object]'
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $list
    }
    $parsed = ConvertFrom-Json -InputObject $raw
    if ($null -eq $parsed) {
        return $list
    }
    if ($parsed -is [System.Array]) {
        foreach ($item in $parsed) {
            [void]$list.Add($item)
        }
    } else {
        [void]$list.Add($parsed)
    }
    # Unary comma: keep List intact when Count -eq 1 (PS otherwise unwraps to the item).
    return , $list
}

function Write-RwkmJsonArrayFile {
    # Always write a JSON array (including [] and single-element [{...}]).
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][object]$Items
    )
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $payload = New-Object 'System.Collections.Generic.List[object]'
    if ($null -ne $Items) {
        foreach ($item in @($Items)) {
            # Guard against accidental nested array from @($object[])
            if ($item -is [System.Array] -and -not ($item -is [string])) {
                foreach ($inner in $item) { [void]$payload.Add($inner) }
            } else {
                [void]$payload.Add($item)
            }
        }
    }
    $json = ConvertTo-Json -InputObject @($payload.ToArray()) -Depth 6
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

