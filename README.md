# Retail Wii U Kiosk Menu

Tools to run **Kiosk Menu** on a retail Wii U. **No dumps or tickets** in this repo.

**Risk:** bad writes can soft-brick. Back up SD + NAND first. **PAL** tested; **USA** in scripts; **JPN** not supported yet. We cannot guarantee the console will be 100% stable. Crashed/reboots *may* happen more often.

Pick **one** guide:

| Path | Guide | Flow |
|------|--------|------|
| **redNAND** (SD lab) | **[docs/REDNAND.md](docs/REDNAND.md)** | Format SD → flash partitions → FTP → patch SLC → add Kiosk Menu / SCT |
| **Real hardware** (sysNAND) | **[docs/SYSNAND.md](docs/SYSNAND.md)** | FTP → patch SLC → add Kiosk Menu / SCT on **console** storage |

Same mutant scripts either way. See **[System Config Tool](#system-config-tool)** and **[Default boot](#default-boot-optional)** below.

---

## Kiosk Menu, not "kiosk OS"

Store kiosks ran the **retail Wii U system** — not a separate operating system. **Kiosk Menu** is an app (title `1fa81000`) opened from **System Config Tool**, plus extra SLC tickets and demo titles on MLC. This project adds that app and licensing to a retail console; it does **not** replace the whole OS with kiosk firmware.

**Home** on the GamePad still opens the **normal retail Home Menu** when retail Home is the default boot title. That is why FTP via Home works, and why we keep **retail Home Menu** as the recommended default unless you explicitly choose another coldboot (see [Default boot](#default-boot-optional)).

---

## System Config Tool

**Kiosk Menu** is opened from **System Config Tool (SCT)** — unless you set coldboot to Kiosk Menu directly ([option 3](#default-boot-optional)).

You need **one** SCT on MLC before Kiosk Menu is reachable from Home:

| SCT | Title ID | How to get it |
|-----|----------|---------------|
| **Native (kiosk)** | `1f700500` | Default — `upload_sys_title_mlc.ps1` from your kiosk MLC extract |
| **Retail / homebrew** | `13374454` | Fallback — install with **WUP Installer GX** if native SCT is missing from your dump |

Native and retail SCT both work for **Home → SCT → Kiosk Menu**. The mutant upload script pulls native SCT automatically; use retail only when your kiosk dump has no usable `1f700500` folder.

**Normal launch path:** power on → **Home Menu** → **System Config Tool** → **Kiosk Menu**.

---

## Default boot (optional)

After **Kiosk Menu + SCT launch successfully from Home**, you may change what the console boots into on power-on. All options edit live `storage_slc/sys/config/system.xml` via FTP (uses `config\config.ps1` for Wii U IP). Run `build_mutant_slc.ps1` first — variants live under `overlay\mutant\slc\sys\config\`.

| # | Boots into | Command | When to use |
|---|------------|---------|-------------|
| **1** | **Retail Home Menu** | `.\scripts\swap_coldboot_ftp.ps1 -Mode home` | **Recommended** — Home, FTP, and undo scripts still work |
| **2** | **Native System Config Tool** | `.\scripts\swap_coldboot_ftp.ps1 -Mode sct` | Skip Home; land in SCT every boot (then open Kiosk Menu from there) |
| **3** | **Kiosk Menu** | `.\scripts\swap_coldboot_ftp.ps1 -Mode kioskmenu` | Store-kiosk style; **trap risk** — see below |

Shorthand wrappers: `make_home_menu_default.ps1` (= `-Mode home`), `make_kiosk_menu_default.ps1` (= `-Mode kioskmenu`).

**Option 3 warning:** Kiosk Menu coldboot means **Home Menu never loads**, so **FTP plugins never start**. PC undo (`make_home_menu_default.ps1`, `swap_coldboot_ftp.ps1`) **will not work** once trapped. Recovery = reflash SLC (redNAND SD partition or sysNAND minute restore). Only choose option 3 if you accept that.

**Option 2 note:** You still need SCT on MLC (`1f700500` or retail `13374454`). Boot goes straight to SCT, not Kiosk Menu — open Kiosk Menu from inside SCT as usual.

Do **not** change coldboot until **Home → SCT → Kiosk Menu** works at least once on option 1.

---

## Do not launch stub / video demo titles from Home or SCT

Kiosk demo folders marked **`stub`** in `map_kiosk_demo_tickets.ps1` are **not playable games**. They use **`non_playable_demo.rpx`**, `content/dummy.txt`, `…FF` title IDs, or `KioskMeta.xml` pointing at a sibling title — they exist for **video tiles inside Kiosk Menu**.

| Launch from | Stub / video title | Playable demo |
|-------------|-------------------|-----------------|
| **Home Menu** | **Do not** — black screen / softlock risk | OK — **use this if Kiosk Menu won't launch the demo** |
| **System Config Tool** | **Do not** — black screen / softlock risk | Avoid — use Home Menu instead |
| **Kiosk Menu** | OK (intended kiosk UI) | Intended path — see [known limitation](#demos-launch-on-home-menu-but-not-from-kiosk-menu) |

Only install and open **`playable`** rows from the ticket map for actual game demos. If you copied stub MLC folders for pairing, that is fine — just do not launch those title IDs manually from Home or SCT.

---

## You need

- **ISFShax + minute** ([setup](https://gbatemp.net/threads/how-to-set-up-isfshax.642258/)) — Aroma alone is not enough (FTP apps still fine)
- **Windows 10/11 PC** + PowerShell 5.1+ (Administrator for SD flash)
- **curl.exe** on PATH (built into modern Windows — scripts call `curl.exe`, not the `curl` alias)
- **Python 3** on PATH (`py`, `python`, or `python3`) — only for `validate_slc_dump.ps1` before flashing
- Retail **and** kiosk dumps, extracted yourself ([nandextract](https://github.com/koolkdev/wiiu-nandextract) / [wfs-tools](https://github.com/koolkdev/wfs-tools))
- FTP to the Wii U (e.g. FTPiiU) while **Home Menu** is up
- **redNAND path:** **32 GB+** SD (Hybrid) or **64 GB+** (FullRedNand) — see [REDNAND.md](docs/REDNAND.md)
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

- **SCT on MLC** — native `1f700500` (upload script) **or** retail/homebrew `13374454` (WUP Installer GX); required to reach Kiosk Menu from Home unless coldboot is Kiosk Menu
- **Recommended coldboot** — retail Home Menu ([default boot option 1](#default-boot-optional)). Kiosk Menu coldboot traps you — no Home, no FTP
- **No stub launches from Home/SCT** — see [Do not launch stub titles](#do-not-launch-stub--video-demo-titles-from-home-or-sct)
- **Back up all saves** before first kiosk launch (auto-user **Sarah** can displace a profile)
- Mutant sets software identity **WIS-001** / **FW** — **do not** [WiiUIdent](https://github.com/GaryOderNichts/WiiUIdent) **Submit System Data** while that is active
- Upload only **clean** MLC extracts (no 0-byte / failed wfs titles). Broken **sys** titles are worse than broken games
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

Stubs (`…FF` IDs, `non_playable_demo.rpx`, `content/dummy.txt`, or `KioskMeta.xml` pointing at a sibling title) are **video tiles for Kiosk Menu**, not games you launch from Home or SCT — doing so can **black-screen or softlock** the console. Use **`playable`** rows when installing demos; prefer **Kiosk Menu** when it works, otherwise **Home Menu** ([known limitation](#demos-launch-on-home-menu-but-not-from-kiosk-menu)).

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

After SLC + MLC are in place, reboot or return to Home. Launch **playable** demos from **Kiosk Menu** when they appear; if not, use **Home Menu** ([known limitation](#demos-launch-on-home-menu-but-not-from-kiosk-menu)).

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

## Idle reboot after Kiosk Menu / demos

Kiosk Menu and demos can enable **idle reboot** (`im_cfg.xml` → `reset_enable=1`, often ~120s). After kiosk use, Home Menu and retail games may reboot when left idle.

**Fix on PC** (uses `config\config.ps1` for Wii U IP and deployment mode):

```powershell
.\scripts\restore_im_cfg_ftp.ps1
```

Upload retail dump instead: `.\scripts\restore_im_cfg_ftp.ps1 -Mode RestoreRetail`

See [SYSNAND — Idle reboots](docs/SYSNAND.md#idle-reboots-after-kiosk-menu--demos). Writes live SLC — script prompts with brick-risk warnings.

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
| `upload_sys_title_mlc.ps1` | Kiosk Menu + native SCT → MLC (or retail SCT via WUP Installer GX) |
| `swap_coldboot_ftp.ps1` | Default boot: `-Mode home` / `sct` / `kioskmenu` |
| `make_home_menu_default.ps1` / `make_kiosk_menu_default.ps1` | Shorthand for `-Mode home` / `kioskmenu` |
| `set_sys_prod_region_ftp.ps1` | Optional region spoof experiment |
| `restore_im_cfg_ftp.ps1` | Patch `im_cfg.xml` `reset_enable=0` on live SLC (idle reboot fix) |

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

### Demos launch on Home Menu but not from Kiosk Menu

**Symptom:** You followed [Adding tickets](#adding-tickets-for-more-apps-demos-kiosk-titles) — SLC ticket, `title.list`, and MLC folder are in place. The demo is marked **`playable`** in `map_kiosk_demo_tickets.ps1`. **Retail Home Menu** opens and runs the demo fine. **Kiosk Menu** shows an empty grid, a dead tile, or fails to start the same title.

**Likely cause (not fully understood):** Kiosk Menu is more than “ticket + files on MLC.” Real demo stations also rely on kiosk-side catalog data — stub/playable pairs, `KioskMeta.xml`, save data, region/layout the menu expects — that a **retail + mutant** setup may not reproduce. Home Menu uses the normal retail launch path and only needs valid rights + content.

**Status:** Known limitation on retail hardware with this project. **We do not have a reliable fix** today; treat Kiosk Menu demo grid as best-effort.

**Workaround:** Launch **`playable`** demos from **retail Home Menu** (or test from SCT title list if you accept the softlock risk on stubs). Kiosk Menu is still useful for the kiosk shell, SCT path, and idle-behavior testing.

**Still worth doing:** Install tickets + MLC (and stub folders when the map lists pairs) — some titles may work in Kiosk Menu later, and Home Menu needs them anyway.

---

## Legal

Kiosk NAND/title data is copyrighted. You obtain dumps yourself.

## Links

- [ISFShax](https://isfsh.ax/) · [redNAND guide](https://gbatemp.net/threads/how-to-setup-rednand-to-fix-system-memory-error-160-0103-failing-emmc-without-soldering.642268/)
- [wiiu-nandextract](https://github.com/koolkdev/wiiu-nandextract) · [wfs-tools](https://github.com/koolkdev/wfs-tools)

Thanks: [koolkdev](https://github.com/koolkdev), ISFShax / minute community.

## AI usage

Thanks to Cursor AI for helping with code and documentation ([cursor.com](https://cursor.com/), cursoragent@cursor.com).
