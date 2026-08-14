# Real hardware (sysNAND) path

Mutant licenses + Kiosk Menu on the **console’s own SLC and MLC**. After apply, the **SD is optional** for day-to-day kiosk use (but with the highest brick risk).

**Safer lab first?** Prove the mutant on [REDNAND.md](REDNAND.md) (Hybrid), then come here.

---

## Before you start

1. ISFShax + minute; **full minute SLC (+ SLCCMPT) backup** of sysNAND stored offline
2. Retail + kiosk dumps extracted; only **clean** MLC title folders ([wiiu-nandextract](https://github.com/koolkdev/wiiu-nandextract) / [wfs-tools](https://github.com/koolkdev/wfs-tools))
3. `.\scripts\setup_config.ps1` — Region, **your** Wii U IP, SD letter if you still use the card for minute/`rednand.ini`, extract paths
4. Set **`DeploymentMode = 'SysNand'`**
5. **Back up all user saves** (kiosk may create user **Sarah**)

FTP always writes to whatever is mounted as `storage_slc` / `storage_mlc`. For this path that must be **real** internal NAND — not redNAND.

---

## 1. Boot so FTP hits sysNAND

```powershell
.\scripts\install_rednand_ini.ps1
```

With **`DeploymentMode = SysNand`**, this **renames `rednand.ini` away** so minute does not redirect SLC/MLC to the SD card.

Then boot with minute: **Patch (slc)** → **boot IOS (slc)** — **not** redNAND. Wait until Home Menu is up and turn on FTP (FTPiiU or your plugin).

Confirm FTP mounts **internal** `storage_slc` / `storage_mlc` before continuing. Scripts use **Critical** Y/N confirms for sysNAND writes.

---

## 2. Build mutant on PC

Use this script to build the mutant SLC overlay on PC — retail base plus kiosk certs/tickets so the console can launch Kiosk Menu titles:

```powershell
.\scripts\build_mutant_slc.ps1
```

Retail base + kiosk certs/tickets, **WIS-001** / **FW** identity (serial/region kept retail). Build includes a merged `system.xml`; apply asks **Y/N** before uploading it (**default N**).

---

## 3. FTP → patch sys SLC

```powershell
.\scripts\backup_slc_ftp.ps1
.\scripts\plan_additive_tickets.ps1
.\scripts\apply_mutant_slc_ftp.ps1
```

By default apply uploads **cert.sys**, **title.list**, **sys_prod.xml**, and additive tickets. It then prompts to upload **system.xml** (kiosk crash/standby policy) — answer **N** (default). Kiosk Menu works without it via Home → SCT. **`-ApplySystemXml`** skips the prompt and uploads. **`-FullKioskPolicy`** also uploads eco/prefs.

Default boot prompt → **N**. If Kiosk Menu is the coldboot title on **sys** SLC, you never reach Home Menu, so **FTP plugins never start** — `make_home_menu_default.ps1` cannot help. Recovery is **minute restore / reflash** from your offline dump only.

A mistake here hits **internal** SLC. Same recovery: minute restore, not “re-flash the SD partition.”

### Known bug: additive tickets skip kiosk launch paths (real hardware)

**Symptom:** SLC apply looks successful (`cert.sys` ~6656 bytes, WIS-001 / FW, `title.list` updated), MLC upload completes, but **System Config Tool** or **Kiosk Menu** shows *Cannot launch this title*.

**Cause:** `plan_additive_tickets.ps1` only lists tickets **missing** on live SLC. On a retail sysNAND, many ticket **paths already exist** with **retail** `.tik` bytes. The scripts **skip** those paths — they do not compare file content. Kiosk needs **different** tickets at the same paths, so launch fails even though the mutant overlay is correct on PC.

**Confirmed on real sysNAND (PAL retail + Cat-I EUR kiosk):** these two paths were in `tickets_skipped.txt` and absent from `tickets_to_upload.json`:

| Live SLC path | Needed for |
|---------------|------------|
| `sys/rights/ticket/sys/0001/0000000b.tik` | Kiosk Menu (`1fa81000`) |
| `sys/rights/ticket/sys/0003/00000002.tik` | Native SCT (`1f700500`) |

**PAL vs USA:** the **paths are the same** — ticket folders are derived from the **title ID**, not the console region. Cat-I EUR and Cat-I USA both store Kiosk Menu at `sys/0001/0000000b.tik` and native SCT at `sys/0003/00000002.tik`. The **`.tik` bytes differ** by kiosk dump (EUR vs USA signing). Use tickets from **your** kiosk extract (e.g. Cat-I 2 EUR on a PAL retail Wii U), not the other region's dump.

**Fix (manual overwrite via FTP):** after `apply_mutant_slc_ftp.ps1`, force-upload both files from `overlay\mutant\slc\`:

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

Then **Home → SCT → Kiosk Menu**. A reflash is **not** required for this — it is a rights mismatch, not NAND corruption.

**Note:** First Kiosk Menu launch can also write live SLC (e.g. region fields in `sys_prod.xml` if you change PAL/USA/JPN in kiosk settings). Keep retail region unless you are deliberately testing cross-region demos.

---

## 4. Add Kiosk Menu + SCT on sys MLC

```powershell
.\scripts\upload_sys_title_mlc.ps1
```

**System Config Tool (required):** Kiosk Menu is opened from SCT. You need **one** on MLC:

- **Native SCT** `1f700500` — uploaded by the script above (default)
- **Retail / homebrew SCT** `13374454` — install with WUP Installer GX if native SCT is missing from your kiosk dump

**Launch:** Home → **SCT** → Kiosk Menu (unless you change coldboot — see [README — Default boot](../README.md#default-boot-optional)).

**Optional coldboot** (after the above works): `swap_coldboot_ftp.ps1 -Mode home` (recommended), `-Mode sct` (boot to SCT), or `-Mode kioskmenu` (Kiosk Menu trap — see README).

**Demo titles:** Do **not** launch **stub** / `non_playable_demo.rpx` titles from Home or SCT — black screen / softlock risk. Use **`playable`** demos; prefer Kiosk Menu when they appear there, otherwise **Home Menu** ([README — known limitation](../README.md#demos-launch-on-home-menu-but-not-from-kiosk-menu)).

Empty kiosk demo grid is common even with MLC folders installed — not the same as “tickets missing.”

If launch fails, see [Known bug: additive tickets](#known-bug-additive-tickets-skip-kiosk-launch-paths-real-hardware) (step 3 above).

More demos / apps: [README — Adding tickets](../README.md#adding-tickets-for-more-apps-demos-kiosk-titles) (SLC ticket + `title.list` + MLC content).

After a good apply, you can remove the SD for normal kiosk use (keep a card if you still want Aroma/homebrew).

---

## Idle reboots after Kiosk Menu / demos

**Symptom:** Console **reboots when left idle** on Home Menu or in retail games, but often **not** while Kiosk Menu is foreground. May start after the first kiosk demo idle test.

**Cause:** Kiosk software can set **`reset_enable=1`** in SLC **`sys/proc/prefs/im_cfg.xml`** (Idle Manager). With **`reset_secnds=120`**, the system reboots after ~2 minutes of inactivity. `system.xml` can stay retail Home Menu — this is separate from coldboot policy.

**Fix:**

```powershell
.\scripts\restore_im_cfg_ftp.ps1
```

Uses **`config\config.ps1`** (`FtpHost`, `DeploymentMode`). Prompts twice: deployment mode check, then Critical SLC write confirm (SysNand = real internal SLC — have minute backup).

- **Patch (default)** — download live `im_cfg.xml`, set `reset_enable=0`, upload.
- **RestoreRetail** — upload retail `im_cfg.xml` from `RetailSlcExtract` or `-LocalImCfg`.

Manual alternative: WinSCP → `storage_slc/sys/proc/prefs/im_cfg.xml`.

**Confirm:** `backup_slc_ftp.ps1` before/after demo tests — diff `prefs/im_cfg.xml`.

---

## Recovery / undo

| Problem | Fix |
|---------|-----|
| Soft-brick / bad sys SLC | minute restore from your offline dump |
| **Cannot launch SCT / Kiosk Menu** | [Launch-ticket skip bug](#known-bug-additive-tickets-skip-kiosk-launch-paths-real-hardware) (also [README](../README.md#cannot-launch-this-title-sct-or-kiosk-menu)) |
| **Demo works on Home, not Kiosk Menu** | [Known limitation](../README.md#demos-launch-on-home-menu-but-not-from-kiosk-menu) — use Home Menu |
| **Idle reboot outside Kiosk Menu** | [Idle reboots](#idle-reboots-after-kiosk-menu--demos) — `im_cfg.xml` `reset_enable` |
| Stuck in Kiosk Menu | **Reflash / minute restore** — no Home Menu means no FTP plugins, so PC scripts cannot undo coldboot. Playable demos may allow **Home** to exit in some setups |
| Leave kiosk features | Restore clean SLC from backup; remove uploaded titles from MLC if desired |
| WiiUIdent | Never **Submit System Data** while WIS-001/FW is active |

Full script list and shared warnings: [README.md](../README.md).
