# USA / PAL region presets and consistency checks.

function Get-RwkmRegionPresets {
    return @{
        USA = @{
            Label                   = 'USA (NTSC)'
            RetailSystemMenuTitleId = '10040100'
            RetailSlcExtract        = '.\dumps\usa\retail\slc'
            KioskSlcExtract         = '.\dumps\usa\kiosk\slc'
            KioskMlcSysTitleRoot    = '.\dumps\usa\kiosk\extracted\sys\title\00050010'
            CountryHints            = @('US', 'USA', 'CA', 'MX')
            ProductAreas            = @(1, 2)
        }
        PAL = @{
            Label                   = 'PAL (EUR)'
            RetailSystemMenuTitleId = '10040200'
            RetailSlcExtract        = '.\dumps\pal\retail\slc'
            KioskSlcExtract         = '.\dumps\pal\kiosk\slc'
            KioskMlcSysTitleRoot    = '.\dumps\pal\kiosk\extracted\sys\title\00050010'
            CountryHints            = @('EU', 'DE', 'FR', 'GB', 'UK', 'ES', 'IT', 'NL', 'AU', 'NZ')
            ProductAreas            = @(3, 4)
        }
    }
}

function Ask-RwkmRegion {
    param([string]$Current = '')

    if ($Current -match '^(USA|PAL)$') {
        $reuse = Confirm-Rwkm -Level Normal -Prompt "Config region is $Current. Keep this region?" -DefaultYes
        if ($reuse) { return $Current.ToUpperInvariant() }
    }

    Write-Host ''
    Write-Host 'Which region is YOUR RETAIL Wii U?' -ForegroundColor Cyan
    Write-Host '  1) USA (NTSC - Americas)'
    Write-Host '  2) PAL  (EUR/AU - Europe, Australia, etc.)'
    Write-Host ''

    while ($true) {
        $pick = Read-Host 'Enter 1 or 2'
        switch ($pick.Trim()) {
            '1' { return 'USA' }
            '2' { return 'PAL' }
            default { Write-Host 'Please type 1 or 2.' -ForegroundColor Yellow }
        }
    }
}

function Apply-RwkmRegionPreset {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [Parameter(Mandatory = $true)][ValidateSet('USA', 'PAL')][string]$Region
    )

    $presets = Get-RwkmRegionPresets
    $p = $presets[$Region]
    $Config.Region = $Region
    $Config.RetailSystemMenuTitleId = $p.RetailSystemMenuTitleId

    foreach ($key in @('RetailSlcExtract', 'KioskSlcExtract', 'KioskMlcSysTitleRoot')) {
        if (-not $Config.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($Config[$key])) {
            $Config[$key] = $p[$key]
        }
    }

    return $Config
}

function Get-RwkmRegionFromSysProd {
    param([string]$SysProdPath)

    if (-not (Test-Path -LiteralPath $SysProdPath)) {
        return @{ Region = 'Unknown'; Detail = 'sys_prod.xml not found' }
    }

    try {
        # Avoid [xml]: tag 5ghz_country_code is illegal in System.Xml (leading digit).
        $text = [IO.File]::ReadAllText($SysProdPath)
        $country = $null
        $area = $null
        $codeId = $null
        if ($text -match '(?s)<5ghz_country_code[^>]*>\s*([^<]*?)\s*</5ghz_country_code>') {
            $country = $Matches[1].Trim()
        }
        if ($text -match '(?s)<product_area[^>]*>\s*([^<]*?)\s*</product_area>') {
            $area = [int]$Matches[1].Trim()
        }
        if ($text -match '(?s)<code_id[^>]*>\s*([^<]*?)\s*</code_id>') {
            $codeId = $Matches[1].Trim()
        }

        $presets = Get-RwkmRegionPresets
        # Prefer product_area / ntsc_pal over 5ghz country (some EUR kiosks store US wifi country).
        foreach ($name in @('USA', 'PAL')) {
            $p = $presets[$name]
            if ($null -ne $area -and ($p.ProductAreas -contains $area)) {
                return @{ Region = $name; Detail = "product_area=$area"; ProductArea = $area; CodeId = $codeId }
            }
        }
        if ($text -match '(?s)<ntsc_pal[^>]*>\s*PAL\s*</ntsc_pal>') {
            return @{ Region = 'PAL'; Detail = 'ntsc_pal=PAL'; ProductArea = $area; CodeId = $codeId }
        }
        if ($text -match '(?s)<ntsc_pal[^>]*>\s*NTSC\s*</ntsc_pal>') {
            # Retail EUR dumps sometimes still say NTSC with product_area=4 / EU wifi
            if ($null -ne $area -and $area -ge 3) {
                return @{ Region = 'PAL'; Detail = "ntsc_pal=NTSC but product_area=$area"; ProductArea = $area; CodeId = $codeId }
            }
        }
        foreach ($name in @('USA', 'PAL')) {
            $p = $presets[$name]
            if ($country -and ($p.CountryHints -contains $country)) {
                return @{ Region = $name; Detail = "country=$country"; ProductArea = $area; CodeId = $codeId }
            }
        }

        if ($codeId -eq 'FJM') {
            return @{ Region = 'PAL'; Detail = 'code_id=FJM (retail EUR)'; ProductArea = $area; CodeId = $codeId }
        }

        return @{ Region = 'Unknown'; Detail = "country=$country area=$area code=$codeId"; ProductArea = $area; CodeId = $codeId }
    } catch {
        return @{ Region = 'Unknown'; Detail = $_.Exception.Message }
    }
}

function Test-RwkmRegionConsistency {
    param(
        [hashtable]$Config,
        [string]$RetailExtract = '',
        [string]$KioskExtract = '',
        [switch]$Force
    )

    $cfgRegion = if ($Config.Region) { $Config.Region.ToString().ToUpperInvariant() } else { '' }
    if (-not $cfgRegion) {
        throw 'Config Region is not set. Run scripts\setup_config.ps1 first.'
    }

    $retailPath = if ($RetailExtract) { $RetailExtract } else { $Config.RetailSlcExtract }
    $kioskPath  = if ($KioskExtract) { $KioskExtract } else { $Config.KioskSlcExtract }

    $retailInfo = Get-RwkmRegionFromSysProd (Join-Path $retailPath 'sys\config\sys_prod.xml')
    $kioskInfo  = Get-RwkmRegionFromSysProd (Join-Path $kioskPath 'sys\config\sys_prod.xml')

    Write-RwkmLog "Region config: $cfgRegion"
    Write-RwkmLog "Retail dump: $($retailInfo.Region) ($($retailInfo.Detail))"
    Write-RwkmLog "Kiosk dump:  $($kioskInfo.Region) ($($kioskInfo.Detail))"

    $issues = @()

    if ($retailInfo.Region -ne 'Unknown' -and $retailInfo.Region -ne $cfgRegion) {
        $issues += "Retail extract looks like $($retailInfo.Region) but config says $cfgRegion."
    }
    if ($kioskInfo.Region -ne 'Unknown' -and $kioskInfo.Region -ne $cfgRegion) {
        $issues += "Kiosk extract looks like $($kioskInfo.Region) but config says $cfgRegion."
    }
    if ($retailInfo.Region -ne 'Unknown' -and $kioskInfo.Region -ne 'Unknown' -and $retailInfo.Region -ne $kioskInfo.Region) {
        $issues += "Retail ($($retailInfo.Region)) and kiosk ($($kioskInfo.Region)) dumps are different regions."
    }

    foreach ($issue in $issues) {
        $ok = Confirm-Rwkm -Level Critical -Prompt "$issue`nContinue anyway?" -Force:$Force
        if (-not $ok) { throw 'Cancelled: region mismatch.' }
    }

    return @{
        ConfigRegion = $cfgRegion
        Retail       = $retailInfo
        Kiosk        = $kioskInfo
        Issues       = $issues
    }
}
