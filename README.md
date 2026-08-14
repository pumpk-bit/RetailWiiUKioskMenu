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

Launching an extra title needs **three** things on the console:

| # | What | Where on console (FTP) |
|---|------|-------------------------|
| 1 | **Ticket** (`.tik`) | `storage_slc/sys/rights/ticket/…` |
| 2 | **Title ID** in **`title.list`** | `storage_slc/sys/rights/sys/title.list` |
| 3 | **Title files** (games/demos) | `storage_mlc/usr/title/0005000x/<titleid>/` |

Scripts can upload SLC pieces for you; **MLC demo folders are always your job** (script or FTP). Any FTP client works — **WinSCP**, FileZilla, etc. Connect to the IP from `config.ps1` while **Home Menu** is up and FTPiiU is running. Paths are **`storage_slc`** and **`storage_mlc`** at the FTP root.

### 1. Map demo folders → SLC ticket paths (PC)

Before copying anything, generate a lookup table from your kiosk dump:

```powershell
.\scripts\map_kiosk_demo_tickets.ps1
```

Defaults: kiosk SLC from `KioskSlcExtract` in config, MLC demos at `<kiosk-dump-root>\Extracted\usr\title\00050002`, output `backup\live_slc_pre_mutant\kiosk_demo_ticket_map.txt`. Override with `-KioskSlcExtract`, `-DemoMlcRoot`, `-OutputPath`.

The report is tab-separated:

| Column | Meaning |
|--------|---------|
| folder | MLC folder name (starts with 8-char title ID) |
| full_title_id | e.g. `000500021017BD00` |
| kind | **`playable`** — launch this one · **`stub`** — show/video tile only (points at another title or shows a demo video instead of a game) |
| ticket_rel | Path under `sys/rights/ticket/` on SLC |
| product_code | From `meta/meta.xml` |

Stubs (`…FF` IDs, `non_playable_demo.rpx`, `content/dummy.txt`, or `KioskMeta.xml` pointing at a sibling title) are for the kiosk video titles, not for playing games. Launch from Kiosk Menu or SCT using the **`playable`** title ID.

If you're copying a **`playable`** demo that has a matching **stub** row in the map, copy **both** MLC folders and ensure **both** `.tik` files are on SLC (mutant bulk apply usually includes both). Kiosk Menu may misbehave if the stub is missing, even when the playable demo is present.

Some titles are **playable-only** (no separate stub folder) — one MLC install with game data and kiosk video content (e.g. New Super Mario Bros. U).

### 2. Tickets + `title.list` on SLC

**Most demos already in your kiosk extract** — let the mutant build pick them up:

```powershell
.\scripts\build_mutant_slc.ps1 -Rebuild
.\scripts\plan_additive_tickets.ps1
.\scripts\apply_mutant_slc_ftp.ps1
```

`build_mutant_slc.ps1` copies kiosk-only ticket paths (skips paths retail already has) and **unions** `title.list`.

**One ticket missing from mutant, or skipped on live** (same path as retail — see [launch-ticket bug](#cannot-launch-this-title-sct-or-kiosk-menu)):

1. From the map (or a hex search in your kiosk `.tik` files), note `ticket_rel` for each row you need — playable, and stub too when the map lists a pair (e.g. `1017bd00` + `1017bdff` → two tickets).
2. Copy that file from your kiosk SLC extract into mutant, **keeping the same path**:

   ```text
   overlay\mutant\slc\sys\rights\ticket\<ticket_rel>
   ```

3. Re-merge lists: `.\scripts\build_mutant_slc.ps1 -Rebuild` (or confirm the title ID hex is already in mutant `title.list`).
4. Upload — scripts **or manual FTP**:

   ```powershell
   .\scripts\plan_additive_tickets.ps1
   .\scripts\apply_mutant_slc_ftp.ps1
   ```

   **WinSCP / FTP manually:** upload the `.tik` to `storage_slc/sys/rights/ticket/<ticket_rel>`. If you changed `title.list`, upload `overlay\mutant\slc\sys\rights\sys\title.list` → `storage_slc/sys/rights/sys/title.list`. Keep binary mode; preserve the nested folder layout under `ticket/`.

### 3. Demo content on MLC

On the **console**, demos live under **`storage_mlc/usr/title/00050002/<8-char-id>/`** — the folder name must be **only** the 8-character title ID hex (e.g. `1017bd00`), matching what the system expects. Extra text in the folder name can prevent the title from loading.

On your **PC**, you can rename extract folders for your own notes (e.g. `1017bd00 - kart`). **Strip that suffix before FTP** — upload/rename to just `1017bd00` (and `1017bdff` for the stub when present). Source tree example:

```text
Extracted\usr\title\00050002\1017bd00 - kart\     ← OK on PC
storage_mlc/usr/title/00050002/1017bd00/          ← required on Wii U
```

- **WinSCP / FTP:** upload the **playable** folder (renamed to the bare ID). If the map has a matching **stub** row, upload that folder too (e.g. `1017bdff`). Skip stub-only tiles you are not pairing with a playable demo.
- **`upload_sys_title_mlc.ps1`** only uploads **sys** titles (`00050010` — Kiosk Menu / SCT). It does **not** install game demos.

After SLC + MLC are in place, reboot or return to Home, then launch from Kiosk Menu or SCT.

### Same-path overwrite warning

If `plan_additive_tickets.ps1` lists a ticket under **skipped** (already on live), apply will **not** replace it. **Force-upload** the kiosk `.tik` from mutant — via WinSCP or:

```powershell
. .\scripts\lib\RWKM.Config.ps1
. .\scripts\lib\RWKM.Ftp.ps1
$cfg = Import-RwkmConfig
$cred = Get-RwkmFtpCredential -Config $cfg
$base = Get-RwkmFtpBase -Config $cfg -Mount slc
Invoke-RwkmFtpPut 'overlay\mutant\slc\sys\rights\ticket\apps\000b\0000001c.tik' "$base/sys/rights/ticket/apps/000b/0000001c.tik" $cred
```

Use your real `ticket_rel` from the map instead of the Kart example.

### Region (PAL console, USA demo)

- **Sys titles** (`1fa81000`, `1f700500`): same title ID and ticket **path** on EUR/USA kiosks; use tickets from **your** kiosk donor.
- **Game demos** (e.g. USA `1017bd00`): often need the **USA** ticket from the USA kiosk dump **and** matching MLC content. PAL-only mutant builds may omit USA demo tickets — copy them manually from Cat-I USA (map script + WinSCP). Cross-region may also need `set_sys_prod_region_ftp.ps1` (experimental; back up `sys_prod.xml` first).

---

## Scripts

| Script | Role |
|--------|------|
| `setup_config.ps1` | Interactive config (IP + SD letter required) |
| `strip_from_config.ps1` / `validate_slc_dump.ps1` / `flash_stripped_partition.ps1` | redNAND SD prepare |
| `build_mutant_slc.ps1` | Merge retail + kiosk licenses on PC (builds system.xml; `-FullKioskPolicy` for eco/prefs) |
| `backup_slc_ftp.ps1` / `plan_additive_tickets.ps1` / `apply_mutant_slc_ftp.ps1` | Live SLC patch (system.xml prompt default **N**; `-ApplySystemXml` to upload) |
| `map_kiosk_demo_tickets.ps1` | Map MLC `00050002` demo folders → SLC `.tik` paths (PC only) |
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
