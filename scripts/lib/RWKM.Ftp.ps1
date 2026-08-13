# FTP helpers (curl.exe - not PowerShell Invoke-WebRequest alias).
#
# Every STOR to the Wii U should go through Confirm-Rwkm + Assert-RwkmFtpReady
# so beginners see host/path and get actionable errors when FTPiiU is down.

function Get-RwkmFtpCredential {
    param([hashtable]$Config)
    $user = $Config.FtpUser
    $pass = $Config.FtpPass
    if ($null -eq $user) { $user = '' }
    if ($null -eq $pass) { $pass = '' }
    return "${user}:${pass}"
}

function Get-RwkmFtpBase {
    param([hashtable]$Config, [ValidateSet('slc','mlc')] [string]$Mount)
    $hostName = $Config.FtpHost
    $port = if ($Config.FtpPort) { $Config.FtpPort } else { 21 }
    return "ftp://${hostName}:${port}/storage_${Mount}"
}

function Test-RwkmCurlPresent {
    $cmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw @"
curl.exe was not found on PATH.

Windows 10/11 usually includes it. Fix:
  1) Open a new PowerShell window and run:  curl.exe --version
  2) If missing, install "Curl" or use Windows Update / optional features.
  3) Do NOT use the PowerShell 'curl' alias (that is Invoke-WebRequest).
"@
    }
}

function Assert-RwkmFtpHostConfigured {
    param([hashtable]$Config)
    $hostName = if ($Config.FtpHost) { $Config.FtpHost.ToString().Trim() } else { '' }
    if (-not $hostName -or $hostName -match 'YOUR_WIIU|CHANGE_ME|TODO|0\.0\.0\.0|127\.0\.0\.1') {
        throw @"
FtpHost is not set to your Wii U IP (got '$hostName').

Fix:
  1) On the Wii U, open FTPiiU Everywhere (or your FTP plugin) and note the IP.
  2) Run:  .\scripts\setup_config.ps1
     or edit config\config.ps1:  FtpHost = '192.168.x.x'
"@
    }
}

function Get-RwkmFtpHint {
    param([string]$RemoteUrl = '', [int]$ExitCode = -1)
    return @"
FTP failed$(if ($ExitCode -ge 0) { " (curl exit $ExitCode)" } else { '' }).
$(if ($RemoteUrl) { "URL: $RemoteUrl" } else { '' })

Check on YOUR side:
  1) Wii U is on, Home Menu loaded (FTP plugins start from Home).
  2) FTPiiU / FTP plugin is running and shows the same IP as FtpHost in config.ps1.
  3) PC and Wii U are on the same LAN; Windows Firewall allows curl.
  4) DeploymentMode matches how you booted (redNAND SD vs sysNAND).
  5) Paths are storage_slc / storage_mlc (ISFShax FTP), not a random PC folder.
"@
}

function Invoke-RwkmCurlFtp {
    param(
        [Parameter(Mandatory = $true)][string[]]$CurlArgs,
        [string]$FailContext = 'FTP'
    )
    Test-RwkmCurlPresent
    $errFile = [IO.Path]::GetTempFileName()
    try {
        $output = & curl.exe @CurlArgs 2>$errFile
        $code = $LASTEXITCODE
        $errText = ''
        if (Test-Path -LiteralPath $errFile) {
            $errText = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
            if ($errText) { $errText = $errText.Trim() }
        }
        if ($code -ne 0) {
            $hint = Get-RwkmFtpHint -ExitCode $code
            $detail = if ($errText) { "`ncurl stderr: $errText" } else { '' }
            throw "$FailContext failed.$detail`n$hint"
        }
        return $output
    } finally {
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
}

function Assert-RwkmFtpReady {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [ValidateSet('slc','mlc','either')][string]$Mount = 'either'
    )

    Assert-RwkmFtpHostConfigured -Config $Config
    Test-RwkmCurlPresent

    $cred = Get-RwkmFtpCredential -Config $Config
    $ports = if ($Config.FtpPort) { @([int]$Config.FtpPort) } else { @(21) }
    $mounts = switch ($Mount) {
        'slc' { @('slc') }
        'mlc' { @('mlc') }
        default { @('slc', 'mlc') }
    }

    $ok = $false
    $lastErr = ''
    foreach ($m in $mounts) {
        $url = "$(Get-RwkmFtpBase -Config $Config -Mount $m)/"
        try {
            $null = Invoke-RwkmCurlFtp -CurlArgs @(
                '-s', '--ftp-pasv', '--connect-timeout', '8', '--max-time', '20',
                $url, '--user', $cred
            ) -FailContext "FTP LIST $m"
            Write-RwkmLog "FTP OK: $url"
            $ok = $true
            break
        } catch {
            $lastErr = $_.Exception.Message
        }
    }

    if (-not $ok) {
        throw @"
Cannot reach the Wii U over FTP ($($Config.FtpHost)).

$lastErr
"@
    }
}

function Invoke-RwkmFtpPut {
    param(
        [string]$LocalPath,
        [string]$RemoteUrl,
        [string]$Credential
    )
    if (-not (Test-Path -LiteralPath $LocalPath)) {
        throw "Local file missing for FTP upload: $LocalPath"
    }
    $null = Invoke-RwkmCurlFtp -CurlArgs @(
        '-s', '--ftp-pasv', '--ftp-create-dirs',
        '-T', $LocalPath, $RemoteUrl, '--user', $Credential
    ) -FailContext "FTP STOR $RemoteUrl"
}

function Invoke-RwkmFtpPutOptional {
    param(
        [string]$LocalPath,
        [string]$RemoteUrl,
        [string]$Credential,
        [string[]]$AltRemotes = @()
    )
    if (-not (Test-Path -LiteralPath $LocalPath)) {
        Write-Host "  skip missing: $LocalPath"
        return $false
    }
    foreach ($target in @($RemoteUrl) + $AltRemotes) {
        try {
            Invoke-RwkmFtpPut -LocalPath $LocalPath -RemoteUrl $target -Credential $Credential
            Write-Host "  ok: $target"
            return $true
        } catch {
            continue
        }
    }
    Write-Warning "optional upload failed: $LocalPath"
    return $false
}

function Get-RwkmFtpListLines {
    param([string]$Url, [string]$Credential)
    try {
        $raw = Invoke-RwkmCurlFtp -CurlArgs @(
            '-s', '--ftp-pasv', $Url, '--user', $Credential
        ) -FailContext "FTP LIST $Url"
    } catch {
        return @()
    }
    if (-not $raw) { return @() }
    $text = if ($raw -is [array]) { $raw -join "`n" } else { [string]$raw }
    return ($text -split "`r?`n" | Where-Object { $_ -ne '' })
}

function Invoke-RwkmFtpGet {
    param(
        [string]$RemoteUrl,
        [string]$LocalPath,
        [string]$Credential
    )
    $dir = Split-Path -Parent $LocalPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $null = Invoke-RwkmCurlFtp -CurlArgs @(
        '-s', '--ftp-pasv', $RemoteUrl, '--user', $Credential, '-o', $LocalPath
    ) -FailContext "FTP GET $RemoteUrl"
}

function Get-RwkmLiveTicketSet {
    param([string]$FtpSlcBase, [string]$Credential)
    $live = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($kind in @('apps','sys')) {
        $dirs = @()
        foreach ($line in (Get-RwkmFtpListLines "$FtpSlcBase/sys/rights/ticket/$kind/" $Credential)) {
            if ($line -match '([0-9a-f]{4})$') { $dirs += $Matches[1] }
        }
        foreach ($d in $dirs) {
            foreach ($line in (Get-RwkmFtpListLines "$FtpSlcBase/sys/rights/ticket/$kind/$d/" $Credential)) {
                if ($line -match '([0-9a-f]{8}\.tik)$') {
                    [void]$live.Add("$kind/$d/$($Matches[1])")
                }
            }
        }
    }
    return , $live
}

function Confirm-RwkmWiiUFtpWrite {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [Parameter(Mandatory = $true)][string]$Action,
        [ValidateSet('slc','mlc')][string]$Mount = 'slc',
        [string]$Extra = '',
        [ValidateSet('Normal', 'Warning', 'Critical')][string]$Level = 'Critical',
        [switch]$Force
    )

    $mode = if (Get-Command Get-RwkmDeploymentMode -ErrorAction SilentlyContinue) {
        Get-RwkmDeploymentMode -Config $Config
    } else { '(unknown)' }

    $where = switch ($Mount) {
        'mlc' { 'storage_mlc (titles / system apps on MLC)' }
        default { 'storage_slc (tickets, certs, system.xml, sys_prod)' }
    }

    $msg = @(
        'WRITE TO THE WII U via FTP'
        ''
        "  Action:  $Action"
        "  Target:  $where"
        "  Wii U:   $($Config.FtpHost):$(if ($Config.FtpPort) { $Config.FtpPort } else { 21 })"
        "  Mode:    $mode"
        $(if ($Extra) { "`n$Extra" } else { '' })
        ''
        'Type Y only if the console is booted the way DeploymentMode expects'
        '(redNAND SD inserted vs sysNAND without rednand.ini).'
    ) -join "`n"

    if (-not (Confirm-Rwkm -Level $Level -Prompt $msg -Force:$Force)) {
        throw 'Cancelled: Wii U FTP write not confirmed.'
    }
}

function Invoke-RwkmSwapColdbootFtp {
    param(
        [ValidateSet('home', 'sct', 'kioskmenu')]
        [string]$Mode,
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [string]$MutantConfigDir = '',
        [switch]$Force,
        [switch]$SkipConfirm
    )

    if (-not (Get-Command Confirm-Rwkm -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'RWKM.Safety.ps1')
    }

    $configDir = if ($MutantConfigDir) { $MutantConfigDir } else { Join-Path $Config.MutantSlc 'sys\config' }
    $cred = Get-RwkmFtpCredential -Config $Config
    $base = Get-RwkmFtpBase -Config $Config -Mount slc

    $map = @{
        home      = 'system.xml'
        sct       = 'system.xml.kioskboot'
        kioskmenu = 'system.xml.kioskmenu'
    }

    $local = Join-Path $configDir $map[$Mode]
    if (-not (Test-Path -LiteralPath $local)) {
        throw @"
Missing coldboot file: $local

Fix: run .\scripts\build_mutant_slc.ps1 first, or copy the variant from your kiosk SLC extract into the mutant config folder.
"@
    }

    Assert-RwkmFtpReady -Config $Config -Mount slc

    if (-not $SkipConfirm) {
        $depMode = if (Get-Command Get-RwkmDeploymentMode -ErrorAction SilentlyContinue) {
            Get-RwkmDeploymentMode -Config $Config
        } else { '' }
        $slcLabel = if ($depMode -eq 'SysNand') { 'INTERNAL sysNAND SLC' } else { 'redSLC (SD) or mounted storage_slc' }

        $swapPrompt = @(
            'Change DEFAULT BOOT TITLE on live SLC via FTP.'
            ''
            "  Mode:     $Mode"
            "  File:     $local"
            "  Wii U:    $($Config.FtpHost)"
            "  Storage:  $slcLabel"
            '  Target:   storage_slc/sys/config/system.xml'
            ''
            'This overwrites the boot title. Wrong file = console may not reach Home Menu.'
        ) -join "`n"

        if ($Mode -eq 'kioskmenu') {
            $swapPrompt = $swapPrompt + "`n`n" + (Get-RwkmKioskMenuDefaultWarning)
        }

        if (-not (Confirm-Rwkm -Level Critical -Prompt $swapPrompt -Force:$Force)) {
            throw 'Cancelled: coldboot swap not confirmed.'
        }
    }

    $url = "$base/sys/config/system.xml"
    Write-RwkmLog "Uploading $Mode coldboot -> system.xml on $($Config.FtpHost)"
    Invoke-RwkmFtpPut -LocalPath $local -RemoteUrl $url -Credential $cred
    $verify = Invoke-RwkmCurlFtp -CurlArgs @(
        '-s', '--ftp-pasv', $url, '--user', $cred
    ) -FailContext 'FTP verify system.xml'
    $verify | Select-String 'default_title_id'
}
