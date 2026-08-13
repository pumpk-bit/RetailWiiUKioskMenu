# Real hardware (sysNAND) path

Mutant licenses + Kiosk Menu on the **console’s own SLC and MLC**. After apply, the **SD is optional** for day-to-day kiosk use (highest brick risk).

**Safer lab first?** Prove the mutant on [REDNAND.md](REDNAND.md) (Hybrid), then come here.

---

## Before you start

1. ISFShax + minute; **full minute SLC (+ SLCCMPT) backup** of sysNAND stored offline
2. Retail + kiosk dumps extracted; only **clean** MLC title folders
3. `.\scripts\setup_config.ps1` — Region, **your** Wii U IP, SD letter if you still use the card for minute/`rednand.ini`, extract paths
4. Set **`DeploymentMode = 'SysNand'`**
5. **Back up all user saves** (kiosk may create user **Sarah**)

FTP always writes to whatever is mounted as `storage_slc` / `storage_mlc`. For this path that must be **real** NAND/SLC — not redNAND. Scripts use **Critical** Y/N confirms and refuse placeholder `FtpHost` values.

---

## 1. Boot so FTP hits sysNAND

```powershell
.\scripts\install_rednand_ini.ps1
```

With `SysNand`, this **renames `rednand.ini` away**. Reboot (or boot without the redNAND SD) so minute does **not** redirect SLC/MLC to the card.

Confirm on the console that you are on sysNAND before continuing. Scripts will demand extra **Critical** Y/N confirms.

---

## 2. Build mutant on PC

```powershell
.\scripts\build_mutant_slc.ps1
```

Same as redNAND: `overlay\mutant\slc\` — retail base + kiosk add-ons, Home Menu default boot, **WIS-001** / **FW** identity (serial/region kept retail).

---

## 3. FTP → patch sys SLC

```powershell
.\scripts\backup_slc_ftp.ps1
.\scripts\plan_additive_tickets.ps1
.\scripts\apply_mutant_slc_ftp.ps1
```

Default boot prompt → **N**. If Kiosk Menu is the coldboot title on **sys** SLC, you never reach Home Menu, so **FTP plugins never start** — `make_home_menu_default.ps1` cannot help. Recovery is **minute restore / reflash** from your offline dump only.

A mistake here hits **internal** SLC. Same recovery: minute restore, not “re-flash the SD partition.”

---

## 4. Add Kiosk Menu + SCT on sys MLC

```powershell
.\scripts\upload_sys_title_mlc.ps1
```

Default: Kiosk Menu + native SCT. Fallback: retail SCT via WUP Installer GX.

**Use:** Home → **SCT** → Kiosk Menu. Empty kiosk demo grid is normal without demo titles. Your existing MLC library stays unless you delete it.

After a good apply, you can remove the SD for normal kiosk use (keep a card if you still want Aroma/homebrew).

---

## Recovery / undo

| Problem | Fix |
|---------|-----|
| Soft-brick / bad sys SLC | minute restore from your offline dump |
| Stuck in Kiosk Menu | **Reflash / minute restore** — no Home Menu means no FTP plugins, so PC scripts cannot undo coldboot |
| Leave kiosk features | Restore clean SLC from backup; remove uploaded titles from MLC if desired |
| WiiUIdent | Never **Submit System Data** while WIS-001/FW is active |

Full script list and shared warnings: [README.md](../README.md).
