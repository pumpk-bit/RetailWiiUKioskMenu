# Problems, bugs, and undo

Hub: [README.md](../README.md). Path guides: [REDNAND.md](REDNAND.md) · [SYSNAND.md](SYSNAND.md).

Scripts log under `logs\`. Read the red **ERROR:** line first. FTP needs **Home Menu** up, FTPiiU running, same IP as `FtpHost`, and `DeploymentMode` matching how you booted.

---

## Index

| Problem | Jump |
|---------|------|
| Script / FTP / SD errors | [PC side](#pc-side) |
| **Title not appearing** in Kiosk Menu | [Title not appearing](#my-title-isnt-appearing) |
| **Demo does not launch** (black screen / crash / error) | [Demo does not launch](#my-kiosk-demo-doesnt-launch-when-loaded) |
| *Cannot launch this title* (SCT or Kiosk Menu app) | [Launch tickets skipped](#cannot-launch-this-title-sct-or-kiosk-menu) |
| Demo works on Home, not Kiosk Menu | [`title.list` + Region](#demos-launch-on-home-menu-but-not-from-kiosk-menu) |
| USA / PAL / other-region demos | [Region](#region-and-adding-demos-from-another-region) |
| Idle reboot after kiosk / demos | [Idle reboot](#idle-reboot-after-kiosk-menu--demos) |
| Title hard-crashes (Home and Kiosk) | [Hard crash](#title-hard-crashes-home-and-kiosk) |
| Stuck in Kiosk Menu (no Home / FTP) | [Coldboot trap](#stuck-in-kiosk-menu-coldboot) |
| Soft-brick / bad SLC | [Recovery](#recovery-reflash) |
| Undo kiosk / go back to retail | [Reverse](#how-to-reverse-this) |

---

## PC side

- **FTP fails:** Home Menu loaded (plugins start from Home), FTPiiU IP matches `config\config.ps1`, same LAN, `DeploymentMode` matches boot (redNAND SD vs sysNAND without `rednand.ini`).
- **SD flash errors:** the letter in This PC must have `\minute\`. Re-run `setup_config.ps1` or edit `SdDriveLetter`.
- **redNAND will not boot:** [REDNAND.md](REDNAND.md#if-rednand-does-not-boot) — Hybrid vs FullRedNand checks.

---

## My title isn't appearing

The demo never shows in the Kiosk Menu grid (or the count at the **top right** does not include it).
1. **Kiosk Menu → Region** (**North/Latin America**, **Japan**, **Europe/Australia/NZ** — labels may differ by kiosk version). The menu **filters** by that setting — it does **not** delete titles. America shows USA demos and hides PAL; Europe shows PAL and hides USA. Switch back to bring the other set back. In **Kiosk Settings** (before the title/video carousel), the top right shows **CAT-I Standalone** with **All titles / Featured / New Releases** counts — use that to confirm the filter. Changing Region can rewrite country in live `sys_prod.xml` (PAL → US or the reverse). Do **not** WiiUIdent **Submit System Data** after.
2. Folder on the console is `storage_mlc/usr/title/00050002/<8-char-id>/` — **kiosk demo** (`00050002`), not a retail eShop/disc title (`00050000`). Name must be the bare ID (`10117e00`), no ` - Mario 2D` suffix.
3. Content is a **clean extract** (real `.rpx`, no 0-byte / `Failed-*` as the whole title). Re-copy from the donor dump if unsure.
4. Title ID is in live `title.list` and a matching `.tik` is on SLC — `patch_demo_rights_ftp.ps1 -Mode Add`. See [title.list](#demos-launch-on-home-menu-but-not-from-kiosk-menu).
5. Stub-only tiles (`…ff`, `non_playable_demo.rpx`) may show as video tiles, not playable games. Pair them with the playable sibling, like `10159b00` - contains video and `10159bff` - contains the playable version.

---

## My kiosk demo doesn't launch when loaded

The tile is there, but starting it fails (error, black screen, crash, or instant reboot).

1. **Power off / reboot the console and try once more.** Some titles have launched on a second try with no other change.
2. Confirm **playable** title ID (not the stub `…ff`), **ticket**, **`title.list`**, and MLC folder `storage_mlc/usr/title/00050002/<id>/`. Easiest check: `patch_demo_rights_ftp.ps1 -Mode Add` on the PC extract folder, then reboot.
3. **Not corrupted** — compare `code/*.rpx` size to your PC dump; re-upload if it was a failed FTP. Skip titles that extracted as `Failed-*` or 0-byte files.
4. **Region** matches the demo (North/Latin America for USA Cat-I). See [Region](#region-and-adding-demos-from-another-region).
5. If **Home Menu** plays it but Kiosk Menu does not → [title.list](#demos-launch-on-home-menu-but-not-from-kiosk-menu).
6. If it **hard-crashes from Home too** → [Hard crash](#title-hard-crashes-home-and-kiosk) (not a missing ticket).
7. Do **not** launch stubs from Home or SCT.

---

## Cannot launch this title (SCT or Kiosk Menu)

**Symptom:** Apply looks fine (`cert.sys` ~6656 bytes, WIS-001 / FW, MLC uploaded), but SCT or Kiosk Menu says *Cannot launch this title*.

**Cause:** Retail already has `.tik` files at the **same paths** as Kiosk Menu / native SCT, with **retail** bytes. Kiosk needs **kiosk** bytes. Confirmed on real PAL sysNAND.

`apply_mutant_slc_ftp.ps1` **always overwrites** these two tickets from `overlay\mutant\slc`. If you applied with an older script, or launch still fails:

```powershell
.\scripts\force_kiosk_launch_tickets_ftp.ps1
```

| Ticket on live SLC | Title |
|--------------------|--------|
| `sys/rights/ticket/sys/0001/0000000b.tik` | Kiosk Menu (`1fa81000`) |
| `sys/rights/ticket/sys/0003/00000002.tik` | Native SCT (`1f700500`) |

Paths are the same on PAL and USA kiosks. **File bytes** differ by donor dump — use **your** kiosk extract. Reboot, then open SCT and launch Kiosk Menu with **Title Type: Menu** ([README — SCT](../README.md#system-config-tool)). This is a rights mismatch, not NAND corruption.

Same-path skip still applies to **game demo** tickets that already exist on retail. Use `patch_demo_rights_ftp.ps1 -Mode Add` (overwrites the matching `.tik`).

---

## Demos launch on Home Menu but not from Kiosk Menu

**Symptom:** Ticket + MLC folder are on the console. **Home Menu** plays the demo. **Kiosk Menu** shows an empty/dead tile or fails to start it.

**Usual cause — `title.list`:** Home Menu can launch from ticket + content. Kiosk Menu also needs the title ID in `storage_slc/sys/rights/sys/title.list`. Mutant apply unions **retail + kiosk donor** only. USA demos copied later onto a PAL mutant often have files and tickets but **no list entry**.

```powershell
.\scripts\patch_demo_rights_ftp.ps1 -Mode Add -DemoFolder 'C:\path\to\101e2b00 - tennis'
```

Reboot. Stub/playable pairs: pass either folder — the script adds both IDs when `KioskMeta.xml` links them.

**Also check Kiosk Menu → Region.** See [Region](#region-and-adding-demos-from-another-region).

---

## Region and adding demos from another region

Kiosk Menu **Region** is a **catalog filter**. Typical labels (may differ by kiosk version):

| Setting | Grid shows | Hidden (still on MLC) |
|---------|------------|------------------------|
| **North/Latin America** | USA demos | PAL / other |
| **Europe/Australia/NZ** | PAL demos | USA / other |
| **Japan** | Japan demos | others |

Titles stay on MLC when you switch; they just stop showing until you switch back. In **Kiosk Settings** (before titles + videos), the top right shows **CAT-I Standalone — All titles / Featured / New Releases**. Those counts update with Region; they are not shown the same way on the main carousel.

Region can write live `sys_prod.xml` (country PAL → US or the reverse). Do **not** [WiiUIdent](https://github.com/GaryOderNichts/WiiUIdent) **Submit System Data** afterward.

Optional PC spoof of the same SLC fields: `.\scripts\set_sys_prod_region_ftp.ps1 -Mode USA` — back up first. Undo: `-Mode Restore`.

Sys titles (`1fa81000`, `1f700500`) use the same ticket **paths** on EUR/USA kiosks; use tickets from **your** kiosk donor to launch the menu itself.

### Add a demo from another region

1. Upload the kiosk demo folder to `storage_mlc/usr/title/00050002/<8-char-id>/` (bare ID, playable + stub pair if the map has one). Use the **same region dump** as the demo (Cat-I USA for USA titles).
2. Inject ticket + `title.list`:

   ```powershell
   .\scripts\patch_demo_rights_ftp.ps1 -Mode Add -DemoFolder 'C:\path\to\10117e00 - new mario u'
   ```

   Tickets are taken from the donor SLC (`dumps\kiosk` or `-KioskSlcExtract`).
3. In Kiosk Menu, set **Region** to match the demo (North/Latin America for USA, Europe/Australia/NZ for PAL). Reboot if the grid is stale.

Region alone does not install titles. Tickets + `title.list` + MLC without the matching Region setting = titles on disk but hidden in the menu.

---

## Idle reboot after Kiosk Menu / demos

**Symptom:** Console reboots when left idle on Home Menu or in retail games (~2 minutes), often **not** while Kiosk Menu is open.

**Cause:** something in the kiosk path can set `reset_enable=1` in SLC `sys/proc/prefs/im_cfg.xml` (`reset_secnds` often 120). Separate from coldboot.

**Try first — Kiosk Settings → No-Input Reset → Off.** That preference is stored on **MLC** and survives reboots until you wipe MLC or delete the kiosk settings data. It often stops the idle reboot behavior. If idle reboot **still** happens after Off + a reboot, patch SLC from the PC:

```powershell
.\scripts\restore_im_cfg_ftp.ps1
```

Uses `config\config.ps1`. Default **Patch** only sets `reset_enable=0`. `-Mode RestoreRetail` uploads retail `im_cfg.xml` from your dump. Writes live SLC — have a minute backup on sysNAND. Confirm over FTP: `storage_slc/sys/proc/prefs/im_cfg.xml` → `reset_enable`.

---

## Title hard-crashes (Home and Kiosk)

If a demo **hard-crashes from Home Menu too**, tickets / `title.list` / Region are not the cause. **We do not know why** and have no fix — skip that title. Do not launch the **stub** (`…ff`) from Home or SCT.

---

## Stuck in Kiosk Menu coldboot

Kiosk Menu as default boot means **Home never loads**, so **FTP plugins never start**. PC scripts cannot undo that.

| Path | Recovery |
|------|----------|
| **redNAND** | Re-flash a **clean retail** redSLC on the SD ([REDNAND.md](REDNAND.md#1-format-sd--flash-redslc)) |
| **sysNAND** | **minute restore** from your offline SLC dump |

Keep **retail Home Menu** as default unless you accept that trap. See [README — Default boot](../README.md#default-boot-optional).

---

## Recovery (reflash)

| Problem | redNAND | sysNAND |
|---------|---------|---------|
| Bad / experimental SLC | Fresh SLC.RAW → strip → validate → flash SD partition → re-apply mutant | minute restore from offline dump |
| Pull SD while kiosk runs | Crash — licenses live on redSLC; keep the card in | n/a |
| Broken sys title on MLC | Delete/replace the uploaded folder | Same |
| In SCT, **Boot title** | Can brick redSLC — restore as above | Same risk on sys SLC |

---

## How to reverse this

You can stop using Kiosk Menu without undoing everything, or strip the mutant off SLC.

### Keep Home Menu, stop using kiosk (light)

1. Coldboot Home: `.\scripts\swap_coldboot_ftp.ps1 -Mode home`
2. Idle reboot: Kiosk Settings → **No-Input Reset → Off**; if it still reboots when idle, `.\scripts\restore_im_cfg_ftp.ps1`
3. Region filter: Kiosk Menu **Region** (North/Latin America / Europe/Australia/NZ / Japan) as you prefer — demos on MLC are not deleted. Optional: `.\scripts\set_sys_prod_region_ftp.ps1 -Mode Restore`
4. Optional: remove demos you added — `.\scripts\patch_demo_rights_ftp.ps1 -Mode Remove -DemoFolder '…'` then delete MLC folders `storage_mlc/usr/title/00050002/<id>/` in WinSCP. This does **not** restore retail `cert.sys` / identity.

Kiosk Menu / SCT can stay on MLC unused.

### Full undo (retail SLC again)

Need Home Menu + FTP (not trapped in Kiosk Menu coldboot).

1. **redNAND:** flash a **clean retail** stripped SLC to the SD SLC partition (same as first flash, **without** re-applying mutant). Delete uploaded kiosk titles from MLC if you want.
2. **sysNAND:** **minute restore** of the **offline SLC backup** you took before the first mutant apply. Highest risk if that backup is missing. Remove uploaded MLC titles (`00050010` Kiosk Menu / SCT, `00050002` demos) if you want them gone.
3. Do **not** WiiUIdent **Submit System Data** while `model_number` is still **WIS-001** / `code_id` **FW**. After a clean retail SLC restore, identity should be retail again.

Saves / Miis: first Kiosk Menu use can create user **Sarah** and **replace the current Mii + name** on the active account. **Back up** before the first launch. A **new** Wii U account you create afterward is left alone. Game saves were not fully tested (MLC was wiped in the lab install).
