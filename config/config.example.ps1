# Copy this file to config.ps1 and edit for your setup.
# Or run: .\scripts\setup_config.ps1
# All scripts accept -ConfigPath to point at a different file.
#
# Do NOT leave placeholders if you will run FTP/disk scripts:
#   FtpHost must be your Wii U LAN IP
#   SdDriveLetter must be the letter of YOUR SD (This PC) — never assume E:

@{
    # --- Region (required) ---
    # USA = Americas (NTSC)   PAL = Europe / Australia (EUR)
    # JPN is not supported by these scripts yet.
    Region = 'PAL'   # or 'USA'

    # --- Deployment mode ---
    # Hybrid      = redSLC on SD + sys MLC (lab default; keep SD in while Kiosk Menu runs)
    # FullRedNand = SLC+MLC on SD (isolated kiosk SD; retail games not included)
    # SysNand     = real console SLC+MLC (CAT-I on hardware; highest risk; SD removable after)
    # Guides: docs/REDNAND.md (Hybrid/FullRedNand) or docs/SYSNAND.md (SysNand)
    DeploymentMode = 'Hybrid'

    # --- FTP (file transfer to Wii U) ---
    # Required for any script that talks to the console. Example: '192.168.1.50'
    FtpHost     = ''
    FtpPort     = 21
    FtpUser     = ''
    FtpPass     = ''

    # --- SD card ---
    # Letter only (no colon). Look in This PC for the volume that contains \minute\.
    # Scripts resolve PhysicalDriveN from this letter. Leave SdDiskNumber as $null.
    SdDriveLetter = ''
    SdDiskNumber  = $null

    # --- minute RAW dumps ---
    SlcRawPath       = ''
    SlccmptRawPath   = ''

    # SearchRoots: after setup, include your SD letter (e.g. 'F:\') plus local folders.
    SearchRoots = @(
        '.\dumps'
        '.\stripped'
    )

    StrippedDir = '.\stripped'

    # --- Extracted dumps (see dumps\retail\ and dumps\kiosk\ instruction text files) ---
    # SLC: NAND Extractor + otp.bin into dumps\retail and dumps\kiosk (sys\ at top, or nested slc\).
    # MLC: optional — wfs-extract --input mlc.bin --otp otp.bin --dump-path Extracted
    #      inside dumps\kiosk, OR set KioskMlcSysTitleRoot to your extract's sys\title\00050010.
    RetailSlcExtract = '.\dumps\retail'
    KioskSlcExtract  = '.\dumps\kiosk'

    MutantSlc = '.\overlay\mutant\slc'
    LiveSlcBackup = '.\backup\live_slc_pre_mutant'

    KioskMlcSysTitleRoot = '.\dumps\kiosk\Extracted\sys\title\00050010'

    KioskMenuTitleId = '1fa81000'
    NativeSctTitleId = '1f700500'   # Required — launch Kiosk Menu from SCT
    # RetailSctTitleId = '13374454' # Retail/homebrew SCT — WUP Installer GX if native 1f700500 missing
    SugarBootTitleId = '1fa83200'

    RetailSystemMenuTitleId = '10040200'   # PAL Home Menu; USA: 10040100
}
