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
3. Retail + kiosk dumps extracted on PC:
   - **SLC** with [NAND Extractor](https://github.com/koolkdev/wiiu-nandextract) + **otp.bin** → `dumps\retail\` and `dumps\kiosk\` (see the text file in each folder)
   - **Kiosk MLC** with [wfs-extract](https://github.com/koolkdev/wfs-tools): `wfs-extract --input mlc.bin --otp otp.bin --dump-path Extracted` inside `dumps\kiosk`, **or** set `KioskMlcSysTitleRoot` to your extract
4. `.\scripts\setup_config.ps1` — Region, **your** Wii U IP, **your** SD drive letter (from This PC — the volume with `\minute\`). Scripts resolve the disk number from that letter; they never guess `E:` or auto-pick a USB stick.
5. Set **`DeploymentMode`** in config:
   - **`Hybrid`** (default) — redSLC on SD + **sys** MLC (your games stay on console)
   - **`FullRedNand`** — SLC + MLC on SD (isolated kiosk world; retail sys MLC not copied in)

Windows shows a FAT drive (whatever letter Windows assigned, with `\minute\`) plus hidden ~512 MB partitions. Flash scripts need **Administrator** PowerShell and ask **Y/N** before writing.

Shared concepts (SCT, coldboot, demos): [README](../README.md). Problems / undo: [PROBLEMS.md](PROBLEMS.md).

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

When asked about Kiosk Menu as default boot → **N**. Once trapped, Home never loads → **FTP plugins never start**. Undo: [PROBLEMS.md](PROBLEMS.md#stuck-in-kiosk-menu-coldboot).

Quick check: `cert.sys` under `storage_slc/sys/rights/sys/` should be ~6656 bytes.

If SCT/Kiosk Menu say *Cannot launch this title* after apply, run `.\scripts\force_kiosk_launch_tickets_ftp.ps1` — [PROBLEMS.md](PROBLEMS.md#cannot-launch-this-title-sct-or-kiosk-menu).

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

In SCT: **Title Launcher** → **System NAND memory (mlc)** → **Kiosk Menu** → **A** → confirm **Title Type: Menu** before launch. If you have no retail SCT on Home, install `13374454` via WUP Installer GX or coldboot native SCT (`swap_coldboot_ftp.ps1 -Mode sct`). Details: [README — SCT](../README.md#system-config-tool).

More demos: [README — Adding demos](../README.md#adding-demos). Launch / grid issues: [PROBLEMS.md](PROBLEMS.md).

**After first Kiosk Menu use:** idle reboot on Home (~2 min) is common. In **Kiosk Settings**, set **No-Input Reset → Off**. If it still reboots when idle: `.\scripts\restore_im_cfg_ftp.ps1` — [PROBLEMS.md — Idle reboot](PROBLEMS.md#idle-reboot-after-kiosk-menu--demos).

---

## Idle reboots / recovery

Idle reboot, *Cannot launch*, demo grid, coldboot trap, full undo: **[PROBLEMS.md](PROBLEMS.md)**.
