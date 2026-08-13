# Apply Mutant SLC overlay to live storage_slc via FTP.
#
# Process (why):
# 1) Trust local mutant built from YOUR extracts (build_mutant_slc.ps1).
# 2) Warn + Y/N for DeploymentMode and every live SLC write.
# 3) Upload config/prefs/certs + only additive tickets (never delete retail tickets).
# 4) Leave Home Menu as default boot unless the user explicitly opts into the trap.

param(
    [string]$ConfigPath = '',
    [string]$MutantSlc = '',
    [string]$TicketPlan = '',
    [string]$FtpHost = '',
    [int]$Port = 0,
    [switch]$Force,
    [switch]$SkipBootPrompt
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

    Assert-RwkmMutantReady -MutantSlc $mutant
    Test-RwkmRegionConsistency -Config $cfg -Force:$Force | Out-Null

    $mode = Confirm-RwkmDeploymentMode -Config $cfg -Action 'PATCH live storage_slc (mutant licenses/config)' -Force:$Force
    Write-RwkmLog "DeploymentMode=$mode"

    $ticketCount = 0
    if (Test-Path -LiteralPath $planPath) {
        $ticketCount = (@(Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json)).Count
    } else {
        $tikRoot = Join-Path $mutant 'sys\rights\ticket'
        if (Test-Path -LiteralPath $tikRoot) {
            $ticketCount = (Get-ChildItem $tikRoot -Recurse -Filter *.tik).Count
        }
    }

    $slcWhere = switch ($mode) {
        'SysNand' { 'sysNAND SLC (INTERNAL - real console)' }
        'FullRedNand' { 'redSLC on SD (full redNAND)' }
        default { 'redSLC on SD (hybrid)' }
    }

    Confirm-RwkmWiiUFtpWrite -Config $cfg -Mount slc -Force:$Force -Action 'Apply mutant SLC (certs, title.list, system.xml, prefs, additive tickets)' -Extra @"
  Mutant:   $mutant
  Region:   $($cfg.Region)
  Storage:  $slcWhere
  Tickets:  ~$ticketCount additive uploads
  Plan:     $(if (Test-Path -LiteralPath $planPath) { $planPath } else { '(none - will scan mutant tickets)' })

Have you run backup_slc_ftp.ps1 first?
$(if ($mode -eq 'SysNand') { 'Confirm you booted WITHOUT rednand.ini so this is NOT redSLC.' } else { 'Confirm the redNAND SD is inserted and rednand.ini matches this mode.' })
"@

    Assert-RwkmFtpReady -Config $cfg -Mount slc

    Write-RwkmLog '=== Mutant SLC FTP apply ==='
    Write-RwkmLog "Mutant: $mutant"
    Write-RwkmLog "Target: $base"

    Write-RwkmLog '[1/3] config + prefs + rights index...'
    Invoke-RwkmFtpPut "$mutant\sys\config\system.xml" "$base/sys/config/system.xml" $cred
    Invoke-RwkmFtpPutOptional "$mutant\sys\config\system.xml.kioskboot" "$base/sys/config/system.xml.kioskboot" $cred @(
        "$base/sys/config/kioskboot.xml"
    ) | Out-Null
    Invoke-RwkmFtpPutOptional "$mutant\sys\config\system.xml.kioskmenu" "$base/sys/config/system.xml.kioskmenu" $cred @(
        "$base/sys/config/kioskmenu.xml"
    ) | Out-Null
    Invoke-RwkmFtpPut "$mutant\sys\config\sys_prod.xml" "$base/sys/config/sys_prod.xml" $cred
    Invoke-RwkmFtpPut "$mutant\sys\config\eco.xml" "$base/sys/config/eco.xml" $cred
    Invoke-RwkmFtpPut "$mutant\sys\proc\prefs\im_cfg.xml" "$base/sys/proc/prefs/im_cfg.xml" $cred
    Invoke-RwkmFtpPut "$mutant\sys\proc\prefs\caffeine.xml" "$base/sys/proc/prefs/caffeine.xml" $cred
    Invoke-RwkmFtpPut "$mutant\sys\proc\prefs\nn.xml" "$base/sys/proc/prefs/nn.xml" $cred
    Invoke-RwkmFtpPut "$mutant\sys\rights\sys\cert.sys" "$base/sys/rights/sys/cert.sys" $cred
    Invoke-RwkmFtpPut "$mutant\sys\rights\sys\title.list" "$base/sys/rights/sys/title.list" $cred

    Write-RwkmLog '[2/3] additive kiosk tickets...'
    $live = Get-RwkmLiveTicketSet -FtpSlcBase $base -Credential $cred

    if (Test-Path -LiteralPath $planPath) {
        $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
        $uploaded = 0; $skipped = 0
        foreach ($t in $plan) {
            if ($live.Contains($t.Rel)) { $skipped++; continue }
            Invoke-RwkmFtpPut $t.Path "$base/sys/rights/ticket/$($t.Rel)" $cred
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
    Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', "$base/sys/config/system.xml", '--user', $cred) -FailContext 'FTP verify system.xml' |
        Select-String 'default_title_id|reset_on_crash'
    Write-RwkmLog '----'
    Invoke-RwkmCurlFtp -CurlArgs @('-s', '--ftp-pasv', "$base/sys/config/sys_prod.xml", '--user', $cred) -FailContext 'FTP verify sys_prod' |
        Select-String 'model_number|code_id'
    Write-RwkmLog 'NOTE: Do NOT use WiiUIdent Submit System Data while WIS-001/FW identity is active - it can ruin the public database.'

    if (-not $SkipBootPrompt -and -not $Force) {
        Write-RwkmLog ''
        Write-RwkmLog 'Patch applied. Default boot is still Home Menu (recommended).'
        if (Confirm-RwkmKioskMenuDefault) {
            Write-RwkmLog 'Setting Kiosk Menu as default boot...'
            # User already confirmed trap; still show host/path confirm inside helper unless Force
            Invoke-RwkmSwapColdbootFtp -Mode kioskmenu -Config $cfg -Force:$Force
        } else {
            Write-RwkmLog 'Skipped Kiosk Menu default boot (safe). Use Home -> SCT -> Kiosk Menu when ready.'
        }
    }

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
