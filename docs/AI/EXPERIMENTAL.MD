# Experimental options

Work-in-progress extras beyond the main Kiosk Title.

# WARNING:

**Risk:** these touch system MLC titles. A bad write can soft-brick until you restore from backup / reflash. You are on your own for data loss.

If anything goes wrong your system won't boot into the OS anymore. You'll need to do a full Minute restore.

Do this only after the normal mutant + Kiosk Menu path already works.

----

## Region support

| Region | Support |
|--------|---------|
| PAL | Yes (lab-tested) |
| USA | Scripts accept USA title IDs; not lab-verified here |
| JPN | No |

## What’s here

| Feature | Title | Script(s) | Status |
|---------|-------|-----------|--------|
| **Kiosk Home Button Menu** | `00050030-1001020A` (PAL) / `1001010A` (USA) | [`apply_kiosk_hbm_ftp.ps1`](../../scripts/apply_kiosk_hbm_ftp.ps1), [`build_kiosk_hbm_mlc.ps1`](../../scripts/build_kiosk_hbm_mlc.ps1) | Works: kiosk jingle + kiosk HOME UI |
| **System fonts** | `0005001B-10042400` | [`apply_kiosk_fonts_ftp.ps1`](../../scripts/apply_kiosk_fonts_ftp.ps1) | Apply works; **usually no visible change** (retail TTFs already match kiosk) |
| **DevMenu** | `00050010-1F7001FF` | [`apply_devmenu_ftp.ps1`](../../scripts/apply_devmenu_ftp.ps1) | Works and launches. Useless since you cannot navigate it. |

Helpers: [`RWKM.Hbm.ps1`](../../scripts/lib/RWKM.Hbm.ps1), FTP tree helpers in [`RWKM.Ftp.ps1`](../../scripts/lib/RWKM.Ftp.ps1).

---

## Kiosk Home Button Menu

Replaces the retail HOME overlay with a **frankenstein** build:

- **Payload** from your CAT-I dump (`kiosk_hbm.rpx` + kiosk `content/`)
- **Identity** from live retail HOME (`app.xml` / `cos.xml` / `meta.xml`, with `hbm.rpx` → `kiosk_hbm.rpx`)
- **TMD/FST** from a **known-good resigned** reference extract (raw kiosk TMD usually fails on modern retail OS)

### Apply (recommended)

FTPiiU running. Config set (`FtpHost`, `Region`, `DeploymentMode`).

```powershell
.\scripts\apply_kiosk_hbm_ftp.ps1 -ReferenceHomeRoot 'D:\path\to\known-good\1001020a' -Force
```

Flow: download live HOME → patch → compare to reference → overwrite upload → delete orphans → hash verify → **restart the Wii U**.

Backups land under `backup\hbm_ftp_<stamp>\` (includes `01_live_mlc_download` for restore).

### PC-only build (optional)

```powershell
.\scripts\build_kiosk_hbm_mlc.ps1 `
  -RetailHomeRoot 'D:\path\to\retail\1001020a' `
  -ReferenceHomeRoot 'D:\path\to\known-good\1001020a' `
  -Force
```

Output: `overlay\mutant\mlc\sys\title\00050030\<titleId>\`. Prefer the FTP script for live consoles.

### Known limits and bugs

| Issue | Notes |
|-------|--------|
| **Quit Game → Main boot** | Quit returns to whatever main boot menu is. Does not return to return Kiosk Demo shower |
| **System apps softlock** | Opening some retail applets (e.g. **Notifications**) from kiosk HOME can softlock. Kiosk HBM is not a drop-in for full retail applet handoff; retail `Inf2.pack` / `Hbm*.pack` are removed by the apply. |
| **Brick risk** | Same title ID as retail HOME. Prefer redNAND; keep the FTP backup folder. If anything goes wrong your system won't boot into the OS anymore. Full Minute restore. |

Restore retail HOME: re-upload from `backup\hbm_ftp_*\01_live_mlc_download` over FTP (or your own retail extract), then reboot.

---

## System fonts (`10042400`)

Swaps `CafeStd.ttf` / `CafeCn.ttf` / `CafeKr.ttf` / `CafeTw.ttf` under `sys/title/0005001b/10042400/content/`. Keeps live `code/` (TMD/FST).

```powershell
.\scripts\apply_kiosk_fonts_ftp.ps1 -Force
```

On a typical retail console these files **already match** the kiosk dump — apply still verifies, but UI text will look the same.

Kiosk **Show** UI mainly uses MenuApp’s own fonts under `content/menuapp/fonts/`, not system `CafeStd`.

Backup: `backup\fonts_ftp_<stamp>\`.

---

## DevMenu (`1f7001ff`)

Factory **DevMenu** (`devmenu.rpx` / `sysmenuD`). Same MLC uploader as Kiosk Menu (`upload_sys_title_mlc.ps1`); this wrapper only changes **TitleIds** to `1f7001ff`.

It will **not** appear on Home (`app_type` Menu). Ticket is packed inside kiosk `sys/rights/ticket/sys/0000/00000009.tik` (not its own file). The script **appends** that 848-byte ticket to the live file and adds the ID to `title.list` if missing. It does **not** overwrite `00000009.tik` wholesale (first ticket in that file is the USA version list).

```powershell
.\scripts\apply_devmenu_ftp.ps1 -Force
.\scripts\apply_devmenu_ftp.ps1 -SourceRoot 'D:\Cat-I USA\Extracted\sys\title\00050010' -Force
```

Launch: reboot → **SCT → Title Launcher → System NAND (mlc)** → `<00050010_1f7001ff>` → **Title Type: Menu**.

Do **not** coldboot this title (same FTP trap as Kiosk Menu). Backup: `backup\devmenu_ftp_<stamp>\`.

---

## Credits

Known-good HBM reference packs and related uploads:  
[https://archive.org/details/@this_is_where_my_old_video_goes/uploads](https://archive.org/details/@this_is_where_my_old_video_goes/uploads)
