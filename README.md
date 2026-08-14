# Retail Wii U Kiosk Menu

Tools to run **Kiosk Menu** on a retail Wii U. **No dumps or tickets** in this repo.

**Risk:** bad writes can soft-brick. Back up SD + NAND first. **PAL** tested; **USA** in scripts; **JPN** not supported yet. We cannot guarantee the console will be 100% stable. Crashed/reboots *may* happen more often.

Pick **one** guide:

| Path | Guide | Flow |
|------|--------|------|
| **redNAND** (SD lab) | **[docs/REDNAND.md](docs/REDNAND.md)** | Format SD → flash partitions → FTP → patch SLC → add Kiosk Menu / SCT |
| **Real hardware** (sysNAND) | **[docs/SYSNAND.md](docs/SYSNAND.md)** | FTP → patch SLC → add Kiosk Menu / SCT on **console** storage |

Same mutant scripts either way. Launch: **Home → System Config Tool (SCT) → Kiosk Menu**.

---

## You need

- **ISFShax + minute** ([setup](https://gbatemp.net/threads/how-to-set-up-isfshax.642258/)) — Aroma alone is not enough (FTP apps still fine)
- **Windows 10/11 PC** + PowerShell 5.1+ (Administrator for SD flash)
- **curl.exe** on PATH (built into modern Windows — scripts call `curl.exe`, not the `curl` alias)
- **Python 3** on PATH (`py`, `python`, or `python3`) — only for `validate_slc_dump.ps1` before flashing
- Retail **and** kiosk dumps, extracted yourself ([nandextract](https://github.com/koolkdev/wiiu-nandextract) / [wfs-tools](https://github.com/koolkdev/wfs-tools))
- FTP to the Wii U (e.g. FTPiiU) while **Home Menu** is up
- **redNAND path:** 64 GB+ SD, Format redNAND in minute
- **SysNAND path:** fresh minute SLC backup before you touch internal NAND (mlc if you want)

---

## Setup (every PC / every console)

```powershell
cd RetailWiiUKioskMenu
.\scripts\setup_config.ps1
```

The wizard asks for:

1. **Region** (USA or PAL)
2. **DeploymentMode** (Hybrid / FullRedNand / SysNand)
3. **Wii U IP** — from FTPiiU on the console (required)
4. **SD drive letter** — look in **This PC** for the volume that has `\minute\` (example: `F`).

Or copy `config\config.example.ps1` → `config\config.ps1` and fill `FtpHost` + `SdDriveLetter` yourself. Scripts **refuse** to use the example file automatically.

| `DeploymentMode` | Use with |
|------------------|----------|
| `Hybrid` / `FullRedNand` | [REDNAND.md](docs/REDNAND.md) |
| `SysNand` | [SYSNAND.md](docs/SYSNAND.md) |

**Safety:** every write to the Wii U (and every SD partition flash) asks **Y/N** (default **N**), logs under `logs\`, and pauses on error. `-Force` skips confirms (automation only).

---

## Hard rules (both paths)

- **SCT required** — native `1f700500` (default upload) or retail `13374454` via WUP Installer GX
- Keep **Home Menu** as default boot. Kiosk Menu coldboot traps you: Home never loads, so **FTP plugins never start** — undo needs a **reflash** (SD on redNAND, minute restore on sysNAND). If a playable demo is configured, **Home** on the GamePad may still exit Kiosk Menu in some setups.
- **Back up all saves** before first kiosk launch (auto-user **Sarah** can displace a profile)
- Mutant sets software identity **WIS-001** / **FW** — **do not** [WiiUIdent](https://github.com/GaryOderNichts/WiiUIdent) **Submit System Data** while that is active
- Upload only **clean** MLC extracts (no 0-byte / failed wfs titles). Broken **sys** titles are worse than broken games. Some apps do have a "dummy.txt" or similar file.
- In SCT, avoid **Boot title** (bricked redSLC in testing)

---

## Adding tickets for more apps (demos, kiosk titles)

Launching an extra title needs **three** things:

1. **Ticket** (`.tik`) on **SLC** under `sys/rights/ticket/…`
2. **Title ID** listed in **`title.list`** (merged at build time)
3. **Title files** on **MLC** (for games/demos) — separate from SLC patch

### Automatic (recommended)

If the ticket already exists in your **kiosk SLC extract**, a normal mutant build picks it up:

```powershell
.\scripts\build_mutant_slc.ps1 -Rebuild
.\scripts\plan_additive_tickets.ps1
.\scripts\apply_mutant_slc_ftp.ps1
```

`build_mutant_slc.ps1` copies **kiosk-only** ticket paths (skips paths retail already has) and **unions** `title.list`. Then upload the title content to MLC yourself (FTP, WUP Installer GX, etc.).

### Manual: one ticket from the kiosk dump

When a ticket is **missing from mutant** or was **skipped** on live (same path as retail — see [launch-ticket bug](#cannot-launch-this-title-sct-or-kiosk-menu)):

**1. Find the ticket file** in your kiosk extract — search for the title ID hex inside `.tik` files:

```powershell
$kioskTik = 'C:\path\to\kiosk\slc\sys\rights\ticket'
$tid = '000500021017BD00'   # example: Mario Kart 8 demo
Get-ChildItem $kioskTik -Recurse -Filter *.tik | ForEach-Object {
    $hex = ([BitConverter]::ToString([IO.File]::ReadAllBytes($_.FullName))).Replace('-','')
    if ($hex -match $tid) {
        $_.FullName.Substring($kioskTik.Length).TrimStart('\') -replace '\\','/'
    }
}
```

**2. Copy into mutant** (keep the same relative path):

```text
overlay\mutant\slc\sys\rights\ticket\<path from step 1>
```

**3. Ensure `title.list` includes the ID** — easiest: `.\scripts\build_mutant_slc.ps1 -Rebuild` (re-unions retail + kiosk lists). Or confirm the hex ID is already in the merged mutant `title.list`.

**4. Upload to console**

```powershell
# Re-plan and apply, OR force-upload one file:
. .\scripts\lib\RWKM.Config.ps1
. .\scripts\lib\RWKM.Ftp.ps1
$cfg = Import-RwkmConfig
$cred = Get-RwkmFtpCredential -Config $cfg
$base = Get-RwkmFtpBase -Config $cfg -Mount slc
Invoke-RwkmFtpPut 'overlay\mutant\slc\sys\rights\sys\title.list' "$base/sys/rights/sys/title.list" $cred
Invoke-RwkmFtpPut 'overlay\mutant\slc\sys\rights\ticket\apps\000b\0000001c.tik' "$base/sys/rights/ticket/apps/000b/0000001c.tik" $cred
```

Use your real path from step 1 instead of the example Kart path.

**5. Put the title on MLC** — demos live under `storage_mlc/usr/title/0005000x\<titleid>\` (not handled by `upload_sys_title_mlc.ps1`, which only uploads **sys** titles `00050010` Kiosk Menu / SCT).

### Same-path overwrite warning

If `plan_additive_tickets.ps1` lists a ticket under **skipped** (already on live), apply will **not** replace it. **Force-upload** the kiosk `.tik` from mutant (same as Kiosk Menu / SCT fix above).

### Region (PAL console, USA demo)

- **Sys titles** (`1fa81000`, `1f700500`): same title ID and ticket **path** on EUR/USA kiosks; use tickets from **your** kiosk donor.
- **Game demos** (e.g. USA `1017bd00`): often need the **USA** ticket from the USA kiosk dump **and** matching MLC content. PAL-only mutant builds may omit USA demo tickets — copy them manually from Cat-I USA. Cross-region may also need `set_sys_prod_region_ftp.ps1` (experimental; back up `sys_prod.xml` first).

---

## Scripts

| Script | Role |
|--------|------|
| `setup_config.ps1` | Interactive config (IP + SD letter required) |
| `strip_from_config.ps1` / `validate_slc_dump.ps1` / `flash_stripped_partition.ps1` | redNAND SD prepare |
| `build_mutant_slc.ps1` | Merge retail + kiosk licenses on PC (builds system.xml; `-FullKioskPolicy` for eco/prefs) |
| `backup_slc_ftp.ps1` / `plan_additive_tickets.ps1` / `apply_mutant_slc_ftp.ps1` | Live SLC patch (system.xml prompt default **N**; `-ApplySystemXml` to upload) |
| `install_rednand_ini.ps1` | Install or remove `rednand.ini` from mode |
| `upload_sys_title_mlc.ps1` | Kiosk Menu + native SCT → MLC |
| `make_home_menu_default.ps1` / `make_kiosk_menu_default.ps1` | Coldboot swap **only while Home/FTP still works**; kiosk default trap needs reflash |
| `set_sys_prod_region_ftp.ps1` | Optional region spoof experiment |

Mutant output (local, gitignored): `overlay\mutant\slc\` — see [overlay/README.md](overlay/README.md).

---

## If something fails (PC side)

- Read the red **ERROR:** line — most messages say what to fix (config, FTPiiU, drive letter, missing mutant).
- Open the log path printed at the end under `logs\`.
- FTP errors: Home Menu up, FTPiiU running, same IP as `FtpHost`, matching `DeploymentMode` boot layout.
- SD errors: confirm the letter in This PC has `\minute\`, then re-run setup or edit `SdDriveLetter`.

### "Cannot launch this title" (SCT or Kiosk Menu)

**sysNAND:** full write-up in [docs/SYSNAND.md — Known bug](docs/SYSNAND.md#known-bug-additive-tickets-skip-kiosk-launch-paths-real-hardware) (confirmed on real hardware). Same fix applies on redNAND.

MLC titles can be fine while launch still fails — **kiosk launch tickets** on SLC are often the cause.

`plan_additive_tickets.ps1` / `apply_mutant_slc_ftp.ps1` only upload tickets **missing** on live SLC. Retail already has `.tik` files at the same paths; those are **skipped** even when the bytes are wrong for kiosk titles. Check `backup\live_slc_pre_mutant\tickets_skipped.txt` for:

| Ticket on live SLC | Title |
|--------------------|--------|
| `sys/rights/ticket/sys/0001/0000000b.tik` | Kiosk Menu (`1fa81000`) |
| `sys/rights/ticket/sys/0003/00000002.tik` | Native SCT (`1f700500`) |

Paths are **identical on PAL and USA** kiosks (title-ID layout). Only the **ticket file bytes** differ by region — upload from **your** kiosk donor dump, not another region's.

If either path is in **skipped** (not in `tickets_to_upload.json`), force-upload from your mutant overlay (Home Menu up, FTP running):

```powershell
. .\scripts\lib\RWKM.Config.ps1
. .\scripts\lib\RWKM.Ftp.ps1
$cfg = Import-RwkmConfig
$cred = Get-RwkmFtpCredential -Config $cfg
$base = Get-RwkmFtpBase -Config $cfg -Mount slc
$m = $cfg.MutantSlc

Invoke-RwkmFtpPut "$m\sys\rights\ticket\sys\0001\0000000b.tik" "$base/sys/rights/ticket/sys/0001/0000000b.tik" $cred
Invoke-RwkmFtpPut "$m\sys\rights\ticket\sys\0003\00000002.tik" "$base/sys/rights/ticket/sys/0003/00000002.tik" $cred
```

Reboot or return to Home, then **Home → SCT → Kiosk Menu**. Also confirm live `cert.sys` is **~6656** bytes (retail + kiosk chains).

---

## Legal

Kiosk NAND/title data is copyrighted. You obtain dumps yourself.

## Links

- [ISFShax](https://isfsh.ax/) · [redNAND guide](https://gbatemp.net/threads/how-to-setup-rednand-to-fix-system-memory-error-160-0103-failing-emmc-without-soldering.642268/)
- [wiiu-nandextract](https://github.com/koolkdev/wiiu-nandextract) · [wfs-tools](https://github.com/koolkdev/wfs-tools)

Thanks: [koolkdev](https://github.com/koolkdev), ISFShax / minute community.

## AI usage

Thanks to Cursor AI for helping with code and documentation ([cursor.com](https://cursor.com/), cursoragent@cursor.com).
