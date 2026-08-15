# Apply Mutant SLC overlay to live storage_slc via FTP.
#
# Process (why):
# 1) Trust local mutant built from YOUR extracts (build_mutant_slc.ps1).
# 2) Warn + Y/N for DeploymentMode and every live SLC write.
# 3) Upload certs/title.list/identity + additive tickets (never delete retail tickets).
#    Always overwrite Kiosk Menu + native SCT tickets (same path as retail, kiosk bytes).
#    system.xml is built but only uploaded if you answer Y (default N - could cause instability).
#    eco/prefs need -FullKioskPolicy. Leave Home Menu as default boot unless user opts into trap.

param(
    [string]$ConfigPath = '',
    [string]$MutantSlc = '',
    [string]$TicketPlan = '',
    [string]$FtpHost = '',
    [int]$Port = 0,
    [switch]$Force,
    [switch]$SkipBootPrompt,
    [switch]$ApplySystemXml,
    [switch]$FullKioskPolicy
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Region.ps1')
. (Join-Path $scriptDir 'lib\RWKM.Ftp.ps1')
Initialize-RwkmScript -Name 'apply_mutant_slc_ftp' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    if ($FtpHost) { $cfg.FtpHost = $FtpHost }
    if ($Port) { $cfg.FtpPort = $Port }

    $mutant = if ($MutantSlc) { $MutantSlc } else { $cfg.MutantSlc }
    $planPath = if ($TicketPlan) { $TicketPlan } else { Join-Path $cfg.LiveSlcBackup 'tickets_to_upload.json' }
    $cred = Get-RwkmFtpCredential -Config $cfg
    $base = Get-RwkmFtpBase -Config $cfg -Mount slc

    Assert-RwkmMutantReady -MutantSlc $mutant -RequiredRelPaths @(
        'sys\config\system.xml'
        'sys\config\sys_prod.xml'
        'sys\rights\sys\cert.sys'
        'sys\rights\sys\title.list'
        'sys\rights\ticket\sys\0001\0000000b.tik'
        'sys\rights\ticket\sys\0003\00000002.tik'
    )
    Test-RwkmRegionConsistency -Config $cfg -Force:$Force | Out-Null

    # Load + validate ticket plan BEFORE any live writes (avoids half-applied mutant).
    $plan = $null
    $usePlan = Test-Path -LiteralPath $planPath
    if ($usePlan) {
        $plan = Read-RwkmJsonArrayFile -Path $planPath
        $missing = New-Object 'System.Collections.Generic.List[string]'
        foreach ($t in $plan) {
            $rel = [string]$t.Rel
            $local = [string]$t.Path
            if (-not $rel -or -not $local) {
                throw "Bad ticket plan entry in $planPath (missing Rel/Path)."
            }
            if (-not (Test-Path -LiteralPath $local)) {
                [void]$missing.Add($local)
            }
        }
        if ($missing.Count -gt 0) {
            throw @"
Ticket plan references missing local files ($($missing.Count)). Re-run:
  .\scripts\build_mutant_slc.ps1
  .\scripts\plan_additive_tickets.ps1

First missing:
  $($missing[0])
"@
        }
    }

    $mode = Confirm-RwkmDeploymentMode -Config $cfg -Action 'PATCH live storage_slc (mutant licenses/config)' -Force:$Force
    Write-RwkmLog "DeploymentMode=$mode"

    $ticketCount = if ($usePlan) {
        $plan.Count
    } else {
        $tikRoot = Join-Path $mutant 'sys\rights\ticket'
        if (Test-Path -LiteralPath $tikRoot) {
            @(Get-ChildItem $tikRoot -Recurse -Filter *.tik).Count
        } else { 0 }
    }

    $slcWhere = switch ($mode) {
        'SysNand' { 'sysNAND SLC (INTERNAL - real console)' }
        'FullRedNand' { 'redSLC on SD (full redNAND)' }
        default { 'redSLC on SD (hybrid)' }
    }

    $applyScope = if ($FullKioskPolicy) {
        'certs, title.list, sys_prod, additive tickets + optional system.xml prompt + kiosk prefs'
    } else {
        'certs, title.list, sys_prod, additive tickets (+ optional system.xml prompt; default skip)'
    }

    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Force:$Force -Action "Apply mutant SLC ($applyScope)" -Extra @"
  Mutant:   $mutant
  Region:   $($cfg.Region)
  Storage:  $slcWhere
  Scope:    $applyScope
  Tickets:  ~$ticketCount additive uploads + force Kiosk Menu / native SCT .tik
  Plan:     $(if ($usePlan) { $planPath } else { '(none - will scan mutant tickets)' })

Have you run backup_slc_ftp.ps1 first?
$(if ($mode -eq 'SysNand') { 'Confirm you booted WITHOUT rednand.ini so this is NOT redSLC.' } else { 'Confirm the redNAND SD is inserted and rednand.ini matches this mode.' })
"@

    Assert-RwkmFtpReady -Config $cfg -Mount slc

    Write-RwkmLog '=== Mutant SLC FTP apply ==='
    Write-RwkmLog "Mutant: $mutant"
    Write-RwkmLog "Target: $base"

    $identityUploaded = $false
    $forceTicketsDone = $false
    try {
        Write-RwkmLog '[1/3] rights + identity...'

        $uploadSystemXml = $false
        if ($ApplySystemXml) {
            $uploadSystemXml = $true
            Write-RwkmLog '  -ApplySystemXml: uploading system.xml without prompt'
        } elseif (-not $Force) {
            $uploadSystemXml = Confirm-RwkmSystemXmlPolicy
        } else {
            Write-RwkmLog '  Skipping system.xml (default N; use -ApplySystemXml to upload with -Force)'
        }

        if ($uploadSystemXml) {
            Invoke-RwkmFtpPut "$mutant\sys\config\system.xml" "$base/sys/config/system.xml" $cred
        } else {
            Write-RwkmLog '  Skipped system.xml (retail crash/standby policy preserved)'
        }

        if ($FullKioskPolicy) {
            Write-RwkmLog '  -FullKioskPolicy: uploading eco.xml and kiosk prefs'
            Invoke-RwkmFtpPut "$mutant\sys\config\eco.xml" "$base/sys/config/eco.xml" $cred
            Invoke-RwkmFtpPut "$mutant\sys\proc\prefs\im_cfg.xml" "$base/sys/proc/prefs/im_cfg.xml" $cred
            Invoke-RwkmFtpPut "$mutant\sys\proc\prefs\caffeine.xml" "$base/sys/proc/prefs/caffeine.xml" $cred
            Invoke-RwkmFtpPut "$mutant\sys\proc\prefs\nn.xml" "$base/sys/proc/prefs/nn.xml" $cred
        } else {
            Write-RwkmLog '  Skipping eco.xml, caffeine/im_cfg/nn (use -FullKioskPolicy for kiosk prefs)'
        }
        Invoke-RwkmFtpPutOptional "$mutant\sys\config\system.xml.kioskboot" "$base/sys/config/system.xml.kioskboot" $cred @(
            "$base/sys/config/kioskboot.xml"
        ) | Out-Null
        Invoke-RwkmFtpPutOptional "$mutant\sys\config\system.xml.kioskmenu" "$base/sys/config/system.xml.kioskmenu" $cred @(
            "$base/sys/config/kioskmenu.xml"
        ) | Out-Null
        Invoke-RwkmFtpPut "$mutant\sys\config\sys_prod.xml" "$base/sys/config/sys_prod.xml" $cred
        Invoke-RwkmFtpPut "$mutant\sys\rights\sys\cert.sys" "$base/sys/rights/sys/cert.sys" $cred
        Invoke-RwkmFtpPut "$mutant\sys\rights\sys\title.list" "$base/sys/rights/sys/title.list" $cred
        $identityUploaded = $true

        # Launch tickets next (before additive). If additive fails later, Menu/SCT still get kiosk bytes.
        Write-RwkmLog '  Overwriting Kiosk Menu + native SCT tickets (retail already has these paths)...'
        $null = Invoke-RwkmForceKioskLaunchTickets -MutantSlc $mutant -FtpSlcBase $base -Credential $cred
        $forceTicketsDone = $true

        Write-RwkmLog '[2/3] additive kiosk tickets...'
        $live = Get-RwkmLiveTicketSet -FtpSlcBase $base -Credential $cred

        if ($usePlan) {
            $uploaded = 0; $skipped = 0
            foreach ($t in $plan) {
                $rel = [string]$t.Rel
                $local = [string]$t.Path
                if ($live.Contains($rel)) { $skipped++; continue }
                Invoke-RwkmFtpPut $local "$base/sys/rights/ticket/$rel" $cred
                $uploaded++
            }
            Write-RwkmLog "  uploaded=$uploaded skipped=$skipped"
        } else {
            Write-RwkmLog "  No ticket plan at $planPath - uploading all mutant tickets not on live..."
            $tikRoot = Join-Path $mutant 'sys\rights\ticket'
            foreach ($f in (Get-ChildItem $tikRoot -Recurse -Filter *.tik)) {
                $rel = Get-RwkmRelativeUnixPath -Root $tikRoot -FullPath $f.FullName
                if ($live.Contains($rel)) { continue }
                Invoke-RwkmFtpPut $f.FullName "$base/sys/rights/ticket/$rel" $cred
            }
        }

        Write-RwkmLog '[3/3] verify...'
        Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', "$base/sys/rights/sys/", '--user', $cred) -FailContext 'FTP verify rights' | Out-Host
        Write-RwkmLog '----'
        if ($uploadSystemXml) {
            Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', "$base/sys/config/system.xml", '--user', $cred) -FailContext 'FTP verify system.xml' |
                Select-String 'default_title_id|reset_on_crash'
        } else {
            Write-RwkmLog '  system.xml not uploaded (retail policy on live SLC)'
        }
        Write-RwkmLog '----'
        Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', "$base/sys/config/sys_prod.xml", '--user', $cred) -FailContext 'FTP verify sys_prod' |
            Select-String 'model_number|code_id'
        Write-RwkmLog 'NOTE: Do NOT use WiiUIdent Submit System Data while WIS-001/FW identity is active - it can ruin the public database.'

        if (-not $SkipBootPrompt -and -not $Force) {
            Write-RwkmLog ''
            Write-RwkmLog 'Patch applied. Default boot is still Home Menu (recommended).'
            if (Confirm-RwkmKioskMenuDefault) {
                Write-RwkmLog 'Setting Kiosk Menu as default boot...'
                Invoke-RwkmSwapColdbootFtp -Mode kioskmenu -Config $cfg -Force:$Force
            } else {
                Write-RwkmLog 'Skipped Kiosk Menu default boot (safe). Use Home -> SCT -> Kiosk Menu when ready.'
            }
        }

        Stop-RwkmSession -ExitCode 0
    } finally {
        # If identity landed but force tickets did not (crash mid-step), try once more.
        if ($identityUploaded -and -not $forceTicketsDone) {
            try {
                Write-RwkmLog 'FINALLY: forcing Kiosk Menu + native SCT tickets after partial apply...'
                $null = Invoke-RwkmForceKioskLaunchTickets -MutantSlc $mutant -FtpSlcBase $base -Credential $cred
            } catch {
                Write-RwkmLog "FINALLY WARN: force launch tickets failed - $($_.Exception.Message)"
                Write-RwkmLog 'Run: .\scripts\force_kiosk_launch_tickets_ftp.ps1'
            }
        }
    }
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
