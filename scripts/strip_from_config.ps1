# Strip SLC/SLCCMPT RAW dumps using paths from config.ps1.

param(
    [ValidateSet('slc','slccmpt','both')]
    [string]$Kind = 'both',
    [string]$ConfigPath = '',
    [string]$InputPath = '',
    [string]$OutputPath = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'lib\RWKM.Config.ps1')
Initialize-RwkmScript -Name 'strip_from_config' -Force:$Force

try {
    $cfg = Import-RwkmConfig -ConfigPath $ConfigPath
    $strip = Join-Path $scriptDir 'strip_nand_ecc.ps1'

    function Strip-One([string]$partKind) {
        if ($InputPath -and $OutputPath -and $Kind -ne 'both') {
            Test-RwkmSlcImageSize -FilePath $InputPath -Expected raw -Force:$Force | Out-Null
            Confirm-RwkmFileWrite -Source $InputPath -Destination $OutputPath `
                -Description "Strip ECC from $partKind RAW dump (2112 -> 512 byte sectors)." `
                -Level Normal -Force:$Force
            & $strip -InputPath $InputPath -OutputPath $OutputPath
            return
        }

        $explicit = if ($partKind -eq 'slc') { $cfg.SlcRawPath } else { $cfg.SlccmptRawPath }
        $raw = Find-RwkmRawDump -Kind $partKind -SearchRoots $cfg.SearchRoots -ExplicitPath $explicit
        $out = Get-RwkmStrippedPath -StrippedDir $cfg.StrippedDir -Kind $partKind -SourceRawPath $raw

        Test-RwkmSlcImageSize -FilePath $raw -Expected raw -Force:$Force | Out-Null
        Confirm-RwkmFileWrite -Source $raw -Destination $out `
            -Description "Strip ECC from $partKind RAW and write stripped 512 MiB image." `
            -Level Normal -Force:$Force

        Write-RwkmLog "=== $partKind : $raw -> $out ==="
        & $strip -InputPath $raw -OutputPath $out
    }

    if ($Kind -eq 'both') {
        Strip-One slc
        Strip-One slccmpt
    } else {
        Strip-One $Kind
    }

    Stop-RwkmSession -ExitCode 0
} catch {
    Write-RwkmLog "ERROR: $($_.Exception.Message)"
    Stop-RwkmSession -ExitCode 1 -PauseOnError
}
