# Real hardware (sysNAND) path

Mutant licenses + Kiosk Menu on the **console’s own SLC and MLC**. After apply, the **SD is optional** for day-to-day kiosk use (but with the highest brick risk).

**Safer lab first?** Prove the mutant on [REDNAND.md](REDNAND.md) (Hybrid), then come here. Problems / undo: [PROBLEMS.md](PROBLEMS.md).

---

## Before you start

1. ISFShax + minute; **full minute SLC (+ SLCCMPT) backup** of sysNAND stored offline

   Dump at least **SEEPROM & OTP**, **SLC.RAW**, and **SLCCMPT.RAW** before any mutant apply:

   ![What to dump before sysNAND work](PNG/Minute/WhatNeedsToBeDumpedOnYourConsole.png)

2. Retail + kiosk dumps extracted:
   - **SLC** with [NAND Extractor](https://github.com/koolkdev/wiiu-nandextract) + **otp.bin** → `dumps\retail\` and `dumps\kiosk\`
   - **Kiosk MLC** with [wfs-extract](https://github.com/koolkdev/wfs-tools) (`--dump-path Extracted`) into `dumps\kiosk\Extracted`, or set `KioskMlcSysTitleRoot`. Only **clean** title folders.
3. `.\scripts\setup_config.ps1` — Region, **your** Wii U IP, SD letter if you still use the card for minute/`rednand.ini`, extract paths
4. Set **`DeploymentMode = 'SysNand'`**
5. **Back up all user saves** (kiosk will create user **Sarah**):

FTP always writes to whatever is mounted as `storage_slc` / `storage_mlc`. For this path that must be **real** internal NAND — not redNAND.

---

## 1. Boot so FTP hits sysNAND

```powershell
.\scripts\install_rednand_ini.ps1
```

With **`DeploymentMode = SysNand`**, this **renames `rednand.ini` away** so minute does not redirect SLC/MLC to the SD card. If `SdDriveLetter` is empty or the SD is not in the PC, the script skips (nothing to disable) — still boot **Patch (slc) and boot IOS (slc)**.

Then boot with minute: **Patch (slc) and boot IOS (slc)** — **not** redNAND:

![Boot native sysNAND from minute](PNG/Minute/HowToBootNativeWiiU.png)

Wait until Home Menu is up and turn on FTP (FTPiiU or your plugin).

Confirm FTP mounts **internal** `storage_slc` / `storage_mlc` before continuing. Scripts use **Critical** Y/N confirms for sysNAND writes.

### If Patch (slc) and boot IOS (slc) fails

That usually means **minute / ISFShax plugins are not on SLC** (`hax` was never copied, or was wiped). Until `hax` is on SLC, you can still boot with **Patch (sd) and boot IOS (slc)** (plugins from the SD):

![Patch (sd) and boot IOS (slc) when hax is missing from SLC](PNG/Minute/IfMinuteIsntOnSLC.png)

Then copy `hax` to SLC with **haxcopy** ([ISFShax setup guide](https://gbatemp.net/threads/how-to-set-up-isfshax.642258/)):

1. If you downloaded from [isfsh.ax](https://isfsh.ax/) or used their download script, the files are already under a `hax` folder — you can skip steps 2–6 and go to **haxcopy**. That download uses **fastboot** minute (see the ISFShax thread).
2. Otherwise create a folder **`hax`** on the SD card (this is what gets copied to SLC).
3. Copy **`fw.img`** into `hax\`.
4. Create **`hax\ios_plugins\`**.
5. Copy **`00core.ipx`** and **`5isfshax.ipx`** into `hax\ios_plugins\`.
6. Optional: for coldboot Aroma/Tiramisu, also copy **`5payldr.ipx`**. Any other plugins (e.g. `wafel_unlimit.ipx`) go in the same folder with the names the guide expects.
7. Install the **haxcopy** app under `wiiu\apps\` like any other homebrew.
8. Put the SD in the Wii U, boot to Home, run **haxcopy** to copy the `hax` folder to SLC.
9. Reboot into minute and try **Patch (slc) and boot IOS (slc)** again.

Full detail and updates: [How to set up ISFShax](https://gbatemp.net/threads/how-to-set-up-isfshax.642258/).

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

Default boot prompt → **N**. Kiosk Menu coldboot on **sys** SLC traps you (no Home, no FTP). Recovery: [PROBLEMS.md](PROBLEMS.md#stuck-in-kiosk-menu-coldboot).

A mistake here hits **internal** SLC. Same recovery: minute restore, not “re-flash the SD partition.”

If SCT/Kiosk Menu say *Cannot launch this title*, run `.\scripts\force_kiosk_launch_tickets_ftp.ps1` — [PROBLEMS.md](PROBLEMS.md#cannot-launch-this-title-sct-or-kiosk-menu).

---

## 4. Add Kiosk Menu + SCT on sys MLC

```powershell
.\scripts\upload_sys_title_mlc.ps1
```

**System Config Tool (required):** Kiosk Menu is opened from SCT. You need **one** on MLC:

- **Native SCT** `1f700500` — uploaded by the script above (default)
- **Retail / homebrew SCT** `13374454` — install with WUP Installer GX if native SCT is missing from your kiosk dump

**Launch:** Home → **SCT** → Kiosk Menu (unless you change coldboot — [README](../README.md#default-boot-optional)).

In SCT: **Title Launcher** → **System NAND memory (mlc)** → **Kiosk Menu** → **A** → confirm **Title Type: Menu** before launch. No retail SCT on Home? Install `13374454` via WUP Installer GX, or coldboot native SCT (`swap_coldboot_ftp.ps1 -Mode sct`). See [README — SCT](../README.md#system-config-tool).

More demos: [README — Adding demos](../README.md#adding-demos). Launch / idle / undo: [PROBLEMS.md](PROBLEMS.md).

**After first Kiosk Menu use:** idle reboot on Home (~2 min) is common. In **Kiosk Settings**, set **No-Input Reset → Off**. If it still reboots when idle: `.\scripts\restore_im_cfg_ftp.ps1` — [PROBLEMS.md — Idle reboot](PROBLEMS.md#idle-reboot-after-kiosk-menu--demos).

After a good apply, you can remove the SD for normal kiosk use (keep a card if you still want Aroma/homebrew). Exit Kiosk Settings → **Remove the SD card** is fine here (unlike redNAND) — [PROBLEMS.md](PROBLEMS.md#exit-kiosk-settings-remove-the-sd-card-rednand).

Menu map: [HowKioskSettingsLookLike.MD](PNG/HowKioskSettingsLookLike.MD).

---

## You made it

If you reach **Kiosk Settings** after Home → SCT → Kiosk Menu, the mutant + MLC path worked:

![Kiosk Settings main screen](PNG/Kiosk/Settings/readme/KioskSettingsMain.jpg)
