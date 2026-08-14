# Retail Wii U Kiosk Menu

Tools to run **Kiosk Menu** on a retail Wii U. **No dumps or tickets** in this repo.

**Risk:** bad writes can soft-brick. Back up SD + NAND first. **PAL** tested; **USA** in scripts; **JPN** not supported yet. We cannot guarantee 100% stability.

| Path | Guide |
|------|--------|
| **redNAND** (SD lab) | **[docs/REDNAND.md](docs/REDNAND.md)** |
| **Real hardware** (sysNAND) | **[docs/SYSNAND.md](docs/SYSNAND.md)** |
| **Problems, bugs, undo** | **[docs/PROBLEMS.md](docs/PROBLEMS.md)** |

Same mutant scripts on both paths. Launch: **Home → System Config Tool (SCT) → Kiosk Menu**.

---

## Kiosk Menu, not "kiosk OS"

Store kiosks ran the **retail Wii U system**. **Kiosk Menu** is an app (`1fa81000`) opened from **SCT**, plus extra SLC tickets and demo titles on MLC. This project does **not** replace the OS with kiosk firmware.

Keep **retail Home Menu** as default boot so FTP still works. See [Default boot](#default-boot-optional).

---

## You need

- **ISFShax + minute** ([setup](https://gbatemp.net/threads/how-to-set-up-isfshax.642258/)) — Aroma alone is not enough (FTP apps still fine)
- **Windows 10/11** + PowerShell 5.1+ (Administrator for SD flash)
- **curl.exe** on PATH (scripts call `curl.exe`, not the PowerShell alias)
- **Python 3** — only for `validate_slc_dump.ps1` before flashing
- Retail **and** kiosk dumps, extracted yourself:
  - **SLC:** [NAND Extractor](https://github.com/koolkdev/wiiu-nandextract) — needs **otp.bin** from that NAND. Put the trees in `dumps\retail\` and `dumps\kiosk\` (read the text file in each folder).
  - **Kiosk MLC** (Kiosk Menu / SCT / demos): [wfs-extract](https://github.com/koolkdev/wfs-tools). Default: `dumps\kiosk\Extracted\`. Or set `KioskMlcSysTitleRoot` to wherever you extracted.
- FTP to the Wii U while **Home Menu** is up
- **redNAND:** 32 GB+ SD (Hybrid) or 64 GB+ (FullRedNand)
- **sysNAND:** fresh minute SLC backup before touching internal NAND

```powershell
cd RetailWiiUKioskMenu
.\scripts\setup_config.ps1
```

Wizard: region, `DeploymentMode`, Wii U IP, SD letter (volume with `\minute\`). Dump paths default to `dumps\retail` and `dumps\kiosk`. Or copy `config\config.example.ps1` → `config\config.ps1`. Scripts **refuse** the example file automatically.

Writes to the Wii U / SD ask **Y/N** (default **N**), log under `logs\`, pause on error. `-Force` skips confirms.

---

## System Config Tool

You need **one** SCT on MLC to open Kiosk Menu (unless coldboot is Kiosk Menu):

| SCT | Title ID | How |
|-----|----------|-----|
| **Native (kiosk)** | `1f700500` | Default — `upload_sys_title_mlc.ps1` |
| **Retail / homebrew** | `13374454` | WUP Installer GX |

**If retail SCT is not on Home Menu:** either install **retail/homebrew** `13374454` with WUP Installer GX, **or** set coldboot to **native SCT** (`.\scripts\swap_coldboot_ftp.ps1 -Mode sct`) so you land in `1f700500` every boot. Native SCT is for the Title Launcher path below; it does not appear as a normal Home icon like retail SCT.

**Launch Kiosk Menu from SCT:**

1. Open System Config Tool  
2. **Title Launcher** → **System NAND memory (mlc)**  
3. Find **Kiosk Menu** → press **A**  
4. Confirm **Title Type: Menu** before launching  

Do **not** use SCT **Boot title** to make Kiosk Menu the default (brick risk). Use `swap_coldboot_ftp.ps1` only after Home → SCT → Kiosk Menu works.

---

## Default boot (optional)

After **Home → SCT → Kiosk Menu** works, you may change power-on boot (`storage_slc/sys/config/system.xml`). Run `build_mutant_slc.ps1` first.

| # | Boots into | Command |
|---|------------|---------|
| **1** | **Retail Home Menu** (recommended) | `.\scripts\swap_coldboot_ftp.ps1 -Mode home` |
| **2** | Native SCT | `.\scripts\swap_coldboot_ftp.ps1 -Mode sct` |
| **3** | Kiosk Menu | `.\scripts\swap_coldboot_ftp.ps1 -Mode kioskmenu` |

Option 3: Home never loads → **FTP never starts** → PC undo will not work. Recovery = reflash SLC. Details: [PROBLEMS.md — coldboot trap](docs/PROBLEMS.md#stuck-in-kiosk-menu-coldboot).

---

## Hard rules

- **SCT on MLC** before launching Kiosk Menu from Home
- **Home Menu** coldboot unless you accept the Kiosk Menu trap
- **Do not** launch stub / `…ff` / `non_playable_demo.rpx` titles from Home or SCT ([stubs](#stubs))
- Back up **saves and Miis** before first kiosk launch — Kiosk Menu can create user **Sarah** and replace the current Mii + name. A new account you add later is left alone. Details: [PROBLEMS.md](docs/PROBLEMS.md#how-to-reverse-this)
- Mutant identity **WIS-001** / **FW** — do **not** [WiiUIdent](https://github.com/GaryOderNichts/WiiUIdent) **Submit System Data**
- Upload only **clean** MLC extracts. In SCT, avoid **Boot title**

---

## Adding demos (same MLC)

Three pieces on the console:

| # | What | FTP path |
|---|------|----------|
| 1 | Ticket (`.tik`) | `storage_slc/sys/rights/ticket/…` |
| 2 | Title ID in **`title.list`** | `storage_slc/sys/rights/sys/title.list` |
| 3 | Title files | `storage_mlc/usr/title/00050002/<8-char-id>/` |

**MLC folders are always your job** (WinSCP / FTP). Folder name on the console must be **only** the 8-character ID (`10117e00`), not `10117e00 - Super Mario U` or `0005000210117e00`. (Using New Super Mario Bros.U as an example only)

1. Map dump folders → ticket paths (PC): `.\scripts\map_kiosk_demo_tickets.ps1`  
   Looks in `dumps\kiosk\Extracted\usr\title\00050002` by default.  
   Output: `backup\live_slc_pre_mutant\kiosk_demo_ticket_map.txt` (`playable` vs `stub`).
2. Upload playable MLC folder (and stub sibling if the map has one).
3. Patch SLC rights from the PC extract folder (suffix in the name is fine):

```powershell
.\scripts\patch_demo_rights_ftp.ps1 -Mode Add -DemoFolder 'C:\path\to\10117e00 - Super Mario U'
```

Bulk path: `build_mutant_slc.ps1 -Rebuild` then `plan_additive_tickets.ps1` / `apply_mutant_slc_ftp.ps1`.

If Home plays a demo but Kiosk Menu does not: [PROBLEMS.md — title.list](docs/PROBLEMS.md#demos-launch-on-home-menu-but-not-from-kiosk-menu).

## Removing demos

Use FTP to delete the MLC folder, then remove the ticket and title.list entry from SLC:

```powershell
.\scripts\patch_demo_rights_ftp.ps1 -Mode Remove -DemoFolder 'C:\path\to\10117e00 - Super Mario U'
```

Reboot after removing demos files. 

Note: You can remove the files manually (WinSCP / FTP) — the script only removes tickets and title.list entries.

| # | What | FTP path |
|---|------|----------|
| 1 | Ticket (`.tik`) | `storage_slc/sys/rights/ticket/…` |
| 2 | Title ID in **`title.list`** | `storage_slc/sys/rights/sys/title.list` |
| 3 | Title files | `storage_mlc/usr/title/00050002/<8-char-id>/` |

## Adding different region demos

**Another region (e.g. USA demos on a PAL console):** FTP the demo onto MLC as above, run `patch_demo_rights_ftp.ps1 -Mode Add` with your extract folder, then in Kiosk Menu set **Region** to match. Labels are typically **North/Latin America**, **Japan**, **Europe/Australia/NZ** (wording can differ by kiosk version). Switching Region **hides** the other set; it does **not** delete them. Full write-up: [PROBLEMS.md — Region](docs/PROBLEMS.md#region-and-adding-demos-from-another-region).

If Home plays a demo but Kiosk Menu does not: [PROBLEMS.md — title.list](docs/PROBLEMS.md#demos-launch-on-home-menu-but-not-from-kiosk-menu).

### Stubs

`stub` rows (`…FF`, `non_playable_demo.rpx`, or `KioskMeta.xml` pointing at another title) are **video tiles for Kiosk Menu**. Do **not** open them from Home or SCT. Copy stub MLC + ticket when pairing with a playable demo. Some titles are playable-only (e.g. New Super Mario Bros. U).

---

## Scripts

| Script | Role |
|--------|------|
| `setup_config.ps1` | IP + SD letter + region |
| `strip_from_config.ps1` / `validate_slc_dump.ps1` / `flash_stripped_partition.ps1` | redNAND SD |
| `build_mutant_slc.ps1` | Merge retail + kiosk licenses on PC |
| `backup_slc_ftp.ps1` / `plan_additive_tickets.ps1` / `apply_mutant_slc_ftp.ps1` | Live SLC patch (`system.xml` default **N**; always overwrites Kiosk Menu / SCT tickets) |
| `map_kiosk_demo_tickets.ps1` | Demo folder → `.tik` map (PC) |
| `patch_demo_rights_ftp.ps1` | Add/remove demo `title.list` + `.tik` |
| `upload_sys_title_mlc.ps1` | Kiosk Menu + native SCT → MLC |
| `force_kiosk_launch_tickets_ftp.ps1` | Retry Kiosk Menu + native SCT tickets (if *Cannot launch* after an older apply) |
| `swap_coldboot_ftp.ps1` | `-Mode home` / `sct` / `kioskmenu` |
| `restore_im_cfg_ftp.ps1` | Idle reboot fix |
| `set_sys_prod_region_ftp.ps1` | Optional region spoof |

Mutant output: `overlay\mutant\slc\` ([overlay/README.md](overlay/README.md)).

Something broken? **[docs/PROBLEMS.md](docs/PROBLEMS.md)** — launch tickets, idle reboot, reverse/undo.

---

## Legal

Kiosk NAND/title data is copyrighted. You obtain dumps yourself.

- [ISFShax](https://isfsh.ax/) · [redNAND guide](https://gbatemp.net/threads/how-to-setup-rednand-to-fix-system-memory-error-160-0103-failing-emmc-without-soldering.642268/)
- [wiiu-nandextract](https://github.com/koolkdev/wiiu-nandextract) · [wfs-tools](https://github.com/koolkdev/wfs-tools)

Thanks: [koolkdev](https://github.com/koolkdev), ISFShax / minute community, and Cursor AI ([cursor.com](https://cursor.com/)).
