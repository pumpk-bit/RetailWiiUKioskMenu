# redNAND path

Licenses on the **SD** (redSLC). Kiosk Menu on **sys MLC** (Hybrid) or **red MLC** (Full). **Keep the SD inserted** while Kiosk Menu runs — pulling the card crashes or drops the mutant licenses on redSLC.

**Hybrid note:** redSLC lives on the SD; your retail games stay on **internal sys MLC**. Some kiosk settings flows assume a full kiosk NAND layout — if you need Kiosk Menu without the SD-in/out quirks of redNAND, prove the mutant here first, then move to [SYSNAND.md](SYSNAND.md).

**SysNAND / no SD lab?** → [SYSNAND.md](SYSNAND.md)

---

## Before you start

1. ISFShax + minute working; Aroma OK for FTP
2. SD card — minute **Format redNAND** (backs up the card first):
   - **Hybrid:** **32 GB+** is usually enough (redSLC + minute FAT; sys MLC stays on console)
   - **FullRedNand:** **64 GB+** recommended (red SLC **and** red MLC on SD — size depends on your MLC dump)
3. Retail + kiosk dumps extracted on PC ([wiiu-nandextract](https://github.com/koolkdev/wiiu-nandextract) / [wfs-tools](https://github.com/koolkdev/wfs-tools))
4. `.\scripts\setup_config.ps1` — Region, **your** Wii U IP, **your** SD drive letter (from This PC — the volume with `\minute\`). Scripts resolve the disk number from that letter; they never guess `E:` or auto-pick a USB stick.
5. Set **`DeploymentMode`** in config:
   - **`Hybrid`** (default) — redSLC on SD + **sys** MLC (your games stay on console)
   - **`FullRedNand`** — SLC + MLC on SD (isolated kiosk world; retail sys MLC not copied in)

Windows shows a FAT drive (whatever letter Windows assigned, with `\minute\`) plus hidden ~512 MB partitions. Flash scripts need **Administrator** PowerShell and ask **Y/N** before writing.

Shared concepts (SCT, coldboot, stub demos): [README](../README.md#system-config-tool).

---

## 1. Format SD → flash redSLC

### Dump

minute → backup → **SLC.RAW** on the FAT partition.

### Strip + validate (PC)

```powershell
.\scripts\strip_from_config.ps1 -Kind slc
.\scripts\validate_slc_dump.ps1 -UseConfig
```

Do **not** flash if validation fails.

### Flash (Admin PowerShell, SD in PC)

```powershell
.\scripts\flash_stripped_partition.ps1 -UseConfig -Partition slc
```

This writes the stripped image to the **SD SLC partition** only — internal sys SLC is untouched on Hybrid.

**FullRedNand:** you also need a red MLC partition flashed from your dump (minute Format redNAND creates it). See the [redNAND guide](https://gbatemp.net/threads/how-to-setup-rednand-to-fix-system-memory-error-160-0103-failing-emmc-without-soldering.642268/) if MLC setup is not done yet.

Boot once with the SD inserted to confirm the console still starts.

---

## 2. Build mutant on PC

```powershell
.\scripts\build_mutant_slc.ps1
```

Output: `overlay\mutant\slc\` — merged certs/tickets, **WIS-001** / **FW** identity (region/serial stay retail). Build includes merged `system.xml`; apply asks **Y/N** before uploading it (**default N**).

---

## 3. Install rednand.ini + reboot

```powershell
.\scripts\install_rednand_ini.ps1
```

| Mode | `rednand.ini` effect |
|------|----------------------|
| Hybrid | `rednand.hybrid.ini` — `mlc=false` (sys MLC) |
| FullRedNand | `rednand.full.ini` — `mlc=true` (red MLC on SD) |

Boot with minute: **Patch (SD)** → **boot IOS (redNAND)**. Wait for Home Menu, then enable FTP if needed.

Reboot with the redNAND SD **inserted** so FTP `storage_slc` / `storage_mlc` match your `DeploymentMode`.

### If redNAND does not boot

**Hybrid**

- SD **inserted** and SLC partition **flashed** (step 1)
- `rednand.ini` present under `\minute\` on the FAT volume
- Re-flash redSLC from a fresh SLC.RAW → strip → validate if the partition is corrupt
- Boot minute: **Patch (SD)** → **boot IOS (redNAND)**

**FullRedNand**

- SD **inserted**; **both** SLC and MLC partitions flashed
- Re-flash redSLC and/or red MLC from offline dumps if either partition is bad
- You need a bootable Wii U OS on red MLC — if MLC is empty or corrupt, create/flash red MLC per the [redNAND guide](https://gbatemp.net/threads/how-to-setup-rednand-to-fix-system-memory-error-160-0103-failing-emmc-without-soldering.642268/)
- Boot minute: **Patch (SD)** → **boot IOS (redNAND)**

---

## 4. FTP → patch redSLC

Wii U on, Home Menu up, FTP plugin running, same Wi‑Fi as PC. Each script asks **Y/N** before touching `storage_slc` (uses **`config\config.ps1`** for Wii U IP).

```powershell
.\scripts\backup_slc_ftp.ps1
.\scripts\plan_additive_tickets.ps1
.\scripts\apply_mutant_slc_ftp.ps1
```

Default apply uploads **rights + identity** (cert, title.list, sys_prod, tickets). You are then asked **Y/N** to upload **system.xml** — **default N** (could cause instability; Kiosk Menu works without it). **`-ApplySystemXml`** uploads without asking. **`-FullKioskPolicy`** also uploads eco/prefs.

When asked about Kiosk Menu as default boot → **N**. Once trapped, Home never loads → **FTP plugins never start**. Undo is **re-flash clean redSLC** on the SD (PC), not `make_home_menu_default.ps1`.

Quick check: `cert.sys` under `storage_slc/sys/rights/sys/` should be ~6656 bytes.

If SCT/Kiosk Menu say *Cannot launch this title* after apply, see [README — launch tickets](../README.md#cannot-launch-this-title-sct-or-kiosk-menu) (additive apply may skip kiosk tickets at retail paths).

---

## 5. Add Kiosk Menu + SCT

Upload only titles that extracted **cleanly**.

```powershell
.\scripts\upload_sys_title_mlc.ps1
```

**System Config Tool (required):** Kiosk Menu is opened from SCT unless coldboot is Kiosk Menu ([README — Default boot](../README.md#default-boot-optional)). You need **one** SCT on MLC:

| SCT | Title ID | Install |
|-----|----------|---------|
| **Native (kiosk)** | `1f700500` | Default — uploaded by script above |
| **Retail / homebrew** | `13374454` | WUP Installer GX if native SCT is missing from your dump |

If you use coldboot **option 2** (`swap_coldboot_ftp.ps1 -Mode sct`), native SCT (`1f700500`) must be on MLC — retail SCT is for the Home → SCT → Kiosk Menu path, not the kiosk `system.xml.kioskboot` coldboot target.

**Launch:** Home → **SCT** → Kiosk Menu.

**Demo titles:** Do **not** launch stub / `non_playable_demo.rpx` titles from Home or SCT — use **`playable`** rows from the ticket map. Prefer Kiosk Menu when demos show up there; if not, **Home Menu** often works ([README — known limitation](../README.md#demos-launch-on-home-menu-but-not-from-kiosk-menu)).

Empty demo grid inside Kiosk Menu is common on retail + mutant setups even when MLC folders exist. On **Hybrid**, your retail Home Menu library on **sys MLC** is unchanged unless you delete titles — use it to play demos Kiosk Menu refuses.

Launch failures: [README — Cannot launch](../README.md#cannot-launch-this-title-sct-or-kiosk-menu). Adding more demos: [Adding tickets](../README.md#adding-tickets-for-more-apps-demos-kiosk-titles).

---

## Idle reboots (after kiosk / demo use)

Kiosk software can turn on ~2 minute idle reboot (`im_cfg.xml` → `reset_enable=1`). Fix on PC (writes live **redSLC** on Hybrid, or sys SLC on SysNand):

```powershell
.\scripts\restore_im_cfg_ftp.ps1
```

Details: [SYSNAND — Idle reboots](SYSNAND.md#idle-reboots-after-kiosk-menu--demos) (same file path on `storage_slc`).

---

## Recovery / mistakes

| Problem | Fix |
|---------|-----|
| Bad redSLC | Fresh SLC.RAW → strip → validate → flash → re-apply mutant |
| **Cannot launch SCT / Kiosk Menu** | [Launch-ticket skip bug](../README.md#cannot-launch-this-title-sct-or-kiosk-menu) — force-upload two tickets |
| **Demo works on Home, not Kiosk Menu** | [Known limitation](../README.md#demos-launch-on-home-menu-but-not-from-kiosk-menu) — use Home Menu |
| Stuck in Kiosk Menu coldboot | Re-flash clean redSLC on SD — no Home Menu means no FTP plugins |
| Pull SD while kiosk runs | Crash — licenses are on redSLC |
| Idle reboot outside Kiosk Menu | `restore_im_cfg_ftp.ps1` |
| Undo kiosk entirely | Clean retail redSLC flash; delete uploaded titles from MLC if you want |

Full script list and warnings: [README.md](../README.md).
