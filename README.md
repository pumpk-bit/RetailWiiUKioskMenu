# Retail Wii U Kiosk Menu

Tools to run **Kiosk Menu** on a retail Wii U. **No dumps or tickets** in this repo.

**Risk:** bad writes can soft-brick. Back up SD + NAND first. **PAL** tested; **USA** in scripts; **JPN** not supported yet.

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
3. **Wii U IP** — from FTPiiU on the console (required; no placeholder)
4. **SD drive letter** — look in **This PC** for the volume that has `\minute\` (example: `F`). Scripts resolve `PhysicalDriveN` from that letter. **Nothing guesses `E:` or auto-picks a USB disk.**

Or copy `config\config.example.ps1` → `config\config.ps1` and fill `FtpHost` + `SdDriveLetter` yourself. Scripts **refuse** to use the example file automatically.

| `DeploymentMode` | Use with |
|------------------|----------|
| `Hybrid` / `FullRedNand` | [REDNAND.md](docs/REDNAND.md) |
| `SysNand` | [SYSNAND.md](docs/SYSNAND.md) |

**Safety:** every write to the Wii U (and every SD partition flash) asks **Y/N** (default **N**), logs under `logs\`, and pauses on error. `-Force` skips confirms (automation only).

---

## Hard rules (both paths)

- **SCT required** — native `1f700500` (default upload) or retail `13374454` via WUP Installer GX
- Keep **Home Menu** as default boot. Kiosk Menu coldboot traps you: Home never loads, so **FTP plugins never start** — undo needs a **reflash** (SD on redNAND, minute restore on sysNAND)
- **Back up all saves** before first kiosk launch (auto-user **Sarah** can displace a profile)
- Mutant sets software identity **WIS-001** / **FW** — **do not** [WiiUIdent](https://github.com/GaryOderNichts/WiiUIdent) **Submit System Data** while that is active
- Upload only **clean** MLC extracts (no 0-byte / `dummy.txt` / failed wfs titles). Broken **sys** titles are worse than broken games
- In SCT, avoid **Boot title** (bricked redSLC in testing)

---

## Scripts

| Script | Role |
|--------|------|
| `setup_config.ps1` | Interactive config (IP + SD letter required) |
| `strip_from_config.ps1` / `validate_slc_dump.ps1` / `flash_stripped_partition.ps1` | redNAND SD prepare |
| `build_mutant_slc.ps1` | Merge retail + kiosk licenses on PC |
| `backup_slc_ftp.ps1` / `plan_additive_tickets.ps1` / `apply_mutant_slc_ftp.ps1` | Live SLC patch |
| `install_rednand_ini.ps1` | Install or remove `rednand.ini` from mode |
| `upload_sys_title_mlc.ps1` | Kiosk Menu + native SCT → MLC |
| `make_home_menu_default.ps1` / `make_kiosk_menu_default.ps1` | Coldboot swap **only while Home/FTP still works**; kiosk default trap needs reflash |
| `set_sys_prod_region_ftp.ps1` | Optional region spoof experiment |

Mutant output (local, gitignored): `overlay\mutant\slc\` — see [overlay/README.md](overlay/README.md).

---

## If something fails

- Read the red **ERROR:** line — most messages say what to fix (config, FTPiiU, drive letter, missing mutant).
- Open the log path printed at the end under `logs\`.
- FTP errors: Home Menu up, FTPiiU running, same IP as `FtpHost`, matching `DeploymentMode` boot layout.
- SD errors: confirm the letter in This PC has `\minute\`, then re-run setup or edit `SdDriveLetter`.

---

## Legal

Kiosk NAND/title data is copyrighted. You obtain dumps yourself.

## Links

- [ISFShax](https://isfsh.ax/) · [redNAND guide](https://gbatemp.net/threads/how-to-setup-rednand-to-fix-system-memory-error-160-0103-failing-emmc-without-soldering.642268/)
- [wiiu-nandextract](https://github.com/koolkdev/wiiu-nandextract) · [wfs-tools](https://github.com/koolkdev/wfs-tools)

Thanks: [koolkdev](https://github.com/koolkdev), ISFShax / minute community.

## AI usage

Thanks to Cursor AI for helping me with this project. (cursoragent@cursor.com / https://cursor.com/ )
