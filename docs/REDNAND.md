# redNAND path

Licenses on the **SD** (redSLC). Kiosk Menu on **sys MLC** (Hybrid) or **red MLC** (Full). **Keep the SD in** while Kiosk Menu runs.

Note: You cannot fully use Kiosk Menu since it requires the user to remove the SD card to leave Kiosk Settings. Use SysNAND if you want full Kiosk Menu.

**SysNAND / removable SD?** → [SYSNAND.md](SYSNAND.md)

---

## Before you start

1. ISFShax + minute working; Aroma OK for FTP
2. **64 GB+** SD → minute **Format redNAND** (backs up the card first) (SD size depends on the MLC size)
3. Retail + kiosk dumps extracted on PC (nandextract / wfs-tools)
4. `.\scripts\setup_config.ps1` — Region, **your** Wii U IP, **your** SD drive letter (from This PC — the volume with `\minute\`), extract paths. Scripts resolve the disk number from that letter; they never guess `E:` or auto-pick a USB stick.
5. Set `DeploymentMode`:
   - **`Hybrid`** (default) — redSLC + **sys** MLC (your games stay on console)
   - **`FullRedNand`** — SLC+MLC on SD (isolated kiosk world; retail MLC not copied in)

Windows shows a FAT drive (whatever letter Windows assigned, with `\minute\`) plus hidden ~512 MB partitions. Flash scripts need **Administrator** PowerShell and ask **Y/N** before writing.

**Terms:** `SLC.RAW` = minute backup → strip to 512 MB → flash. Extract **folders** build the mutant; they are not copied to the SD as-is.

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

Boot once from SD to confirm the console still starts.

---

## 2. Build mutant on PC

```powershell
.\scripts\build_mutant_slc.ps1
```

Output: `overlay\mutant\slc\` — merged certs/tickets, Home Menu coldboot, software identity **WIS-001** / **FW** (region/serial stay retail).

---

## 3. Install rednand.ini + reboot

```powershell
.\scripts\install_rednand_ini.ps1
```

| Mode | Effect |
|------|--------|
| Hybrid | `rednand.hybrid.ini` — `mlc=false` |
| FullRedNand | `rednand.full.ini` — `mlc=true` |

Reboot with the redNAND SD inserted so FTP sees the intended mounts.

---

## 4. FTP → patch redSLC

Wii U on, Home Menu up, FTP plugin running, same Wi‑Fi as PC. Each script asks **Y/N** before touching `storage_slc`.

```powershell
.\scripts\backup_slc_ftp.ps1
.\scripts\plan_additive_tickets.ps1
.\scripts\apply_mutant_slc_ftp.ps1
```

When asked about Kiosk Menu as default boot → **N**. Once trapped, Home never loads → **FTP plugins never start**. Undo is **re-flash clean redSLC** on the SD (PC), not `make_home_menu_default.ps1`.

Quick check: `cert.sys` under `storage_slc/sys/rights/sys/` should be ~6656 bytes.

---

## 5. Add Kiosk Menu + SCT

Upload only titles that extracted **cleanly**.

```powershell
.\scripts\upload_sys_title_mlc.ps1
```

Default: Kiosk Menu (`1fa81000`) + native SCT (`1f700500`). No native SCT in extract → install retail SCT (`13374454`) with WUP Installer GX.

**Use:** Home → **SCT** → Kiosk Menu. Empty demo grid inside Kiosk Menu is normal without kiosk save/demo data. Your Home Menu library on sys MLC is unchanged (Hybrid) unless you delete titles.

---

## Recovery / mistakes

| Problem | Fix |
|---------|-----|
| Bad redSLC | Fresh SLC.RAW → strip → validate → flash → re-apply mutant |
| Stuck in Kiosk Menu | Re-flash clean redSLC on the SD — no Home Menu means no FTP plugins |
| Pull SD while kiosk runs | Crash — licenses are on redSLC |
| Undo kiosk | Clean retail redSLC flash; delete uploaded titles from MLC if you want |

Full script list and warnings: [README.md](../README.md).
