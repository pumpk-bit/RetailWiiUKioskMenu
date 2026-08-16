# Problems, bugs, and undo

Hub: [README.md](README.md) · Setup: [SYSNAND.md](SYSNAND.md) · Demos: [NEWDEMOS.MD](NEWDEMOS.MD)

Scripts log under `logs\`. Read the red **ERROR:** line first. FTP needs **Home Menu** up, FTPiiU running, same IP as `FtpHost`, and `DeploymentMode = SysNand` so mounts are internal `storage_slc` / `storage_mlc`.

---

## Index

| Problem | Jump |
|---------|------|
| Script / FTP / SD errors | [PC side](#pc-side) |
| **NAND Extractor** won't take my SLC dump | [NAND Extractor](#nand-extractor-doesnt-take-my-slc-dump) |
| **MLC upload** paths look like `ode/` / `ontent/` | [MLC path upload](#mlc-upload-shows-ode--ontent--eta) |
| *Cannot launch this title* (SCT or Kiosk Menu app) | [Launch tickets](#cannot-launch-this-title-sct-or-kiosk-menu) |
| **Title not appearing** in Kiosk Menu | [Title not appearing](#my-title-isnt-appearing) |
| **Demo does not launch** (black screen / crash / error) | [Demo does not launch](#my-kiosk-demo-doesnt-launch-when-loaded) |
| Demo works on Home, not Kiosk Menu | [`title.list`](#demos-launch-on-home-menu-but-not-from-kiosk-menu) |
| USA / PAL / other-region demos | [Region](#region-and-adding-demos-from-another-region) |
| Idle reboot after kiosk / demos | [Idle reboot](#idle-reboot-after-kiosk-menu--demos) |
| Title hard-crashes (Home and Kiosk) | [Hard crash](#title-hard-crashes-home-and-kiosk) |
| Stuck in Kiosk Menu (no Home / FTP) | [Coldboot trap](#stuck-in-kiosk-menu-coldboot) |
| **Remove the SD card** (Exit Kiosk Settings) | [SD remove](#exit-kiosk-settings-remove-the-sd-card) |
| Soft-brick / bad SLC | [Recovery](#recovery-reflash) |
| Undo kiosk / go back to retail | [Reverse](#how-to-reverse-this) |
| Aroma / Discovery plugins in Kiosk Menu | [Plugins](#aroma--discovery-plugins-in-kiosk-menu) |
| Screenshot index | [Screenshots](#screenshots) |

---

## PC side

- **FTP fails:** Home Menu loaded (plugins start from Home), FTPiiU IP matches `config\config.ps1`, same LAN, and you booted so FTP mounts **internal** NAND (`DeploymentMode = SysNand`).
- **SD letter errors:** the letter in This PC must have `\minute\`. Re-run `setup_config.ps1` or edit `SdDriveLetter`.
- **NAND Extractor won't open the dump:** [below](#nand-extractor-doesnt-take-my-slc-dump).
- **Plugins inside Kiosk Menu:** [below](#aroma--discovery-plugins-in-kiosk-menu).

---

## NAND Extractor doesn't take my SLC dump

[NAND Extractor](https://github.com/koolkdev/wiiu-nandextract) needs a matching key file next to the image.

1. Put **`otp.bin`** in the **same folder** as the SLC dump.
2. The dump must be named **`slc.bin`**, not `SLC.RAW` / `SLC.raw` — you can **safely rename** it.
3. **`otp.bin` and `slc.bin` must be from the same console.** Mixing OTP from one Wii U with an SLC from another will fail.

Minute dumps as `SLC.RAW`; renaming to `slc.bin` for the extractor is normal.

---

## MLC upload shows ode / ontent / eta

**Symptom:** [`upload_sys_title_mlc.ps1`](../../scripts/upload_sys_title_mlc.ps1) log lists remote paths like `ode/app.xml`, `ontent/...`, `eta/...` instead of `code/`, `content/`, `meta/`.

**Cause:** An older build computed relative paths with a raw `Substring` against a config root that contained `\.`. That ate the first character of every folder name and uploaded into the wrong MLC trees.

**Fix:** Use a current script (it resolves the source root and builds relative paths safely). Re-run:

```powershell
.\scripts\upload_sys_title_mlc.ps1
```

Confirm the new log shows `code/`, `content/`, `meta/`. Optional cleanup in WinSCP: delete orphan `ode` / `ontent` / `eta` folders under `storage_mlc/sys/title/00050010/1fa81000/` and `…/1f700500/`.

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

Paths are the same on PAL and USA kiosks. **File bytes** differ by donor dump — use **your** kiosk extract. Reboot, then open SCT and launch Kiosk Menu with **Title Type: Menu** ([README — SCT](README.md#system-config-tool)). This is a rights mismatch, not NAND corruption.

Same-path skip still applies to **game demo** tickets that already exist on retail. Use `patch_demo_rights_ftp.ps1 -Mode Add` (overwrites the matching `.tik`).

Also confirm MLC paths are under `code/` / `content/` / `meta/` — [MLC path upload](#mlc-upload-shows-ode--ontent--eta).

---

## My title isn't appearing

The demo never shows in the Kiosk Menu grid (or the count at the **top right** does not include it).

1. **Kiosk Menu → Region** (**North/Latin America**, **Japan**, **Europe/Australia/NZ** — labels may differ by kiosk version). The menu **filters** by that setting — it does **not** delete titles. America shows USA demos and hides PAL; Europe shows PAL and hides USA. Switch back to bring the other set back. In **Kiosk Settings** (before the title/video carousel), the top right shows **CAT-I Standalone** with **All titles / Featured / New Releases** counts — use that to confirm the filter. Changing Region can rewrite country in live `sys_prod.xml` (PAL → US or the reverse). Do **not** WiiUIdent **Submit System Data** after.
2. Folder on the console is `storage_mlc/usr/title/00050002/<8-char-id>/` — **kiosk demo** (`00050002`), not a retail eShop/disc title (`00050000`). Name must be the bare ID (`10117e00`), no ` - Mario 2D` suffix.
3. Content is a **clean extract** (real `.rpx`, no 0-byte / `Failed-*` as the whole title). Re-copy from the donor dump if unsure.
4. Title ID is in live `title.list` and a matching `.tik` is on SLC — `patch_demo_rights_ftp.ps1 -Mode Add`. See [title.list](#demos-launch-on-home-menu-but-not-from-kiosk-menu).
5. Stub-only tiles (`…ff`, `non_playable_demo.rpx`) may show as video tiles, not playable games. Pair them with the playable sibling, like `10159b00` (video) and `10159bff` (playable) — see [NEWDEMOS.MD — Stubs](NEWDEMOS.MD#stubs).

---

## My kiosk demo doesn't launch when loaded

The tile is there, but starting it fails (error, black screen, crash, or instant reboot).

1. **Power off / reboot the console and try once more.** Some titles have launched on a second try with no other change.
2. Confirm **playable** title ID (not the stub `…ff`), **ticket**, **`title.list`**, and MLC folder `storage_mlc/usr/title/00050002/<id>/`. Easiest check: `patch_demo_rights_ftp.ps1 -Mode Add` on the PC extract folder, then reboot.
3. **Not corrupted** — compare `code/*.rpx` size to your PC dump; re-upload if it was a failed FTP. Skip titles that extracted as `Failed-*` or 0-byte files.
4. **Region** matches the demo (North/Latin America for USA Cat-I). See [Region](#region-and-adding-demos-from-another-region).
5. If **Home Menu** plays it but Kiosk Menu does not → [title.list](#demos-launch-on-home-menu-but-not-from-kiosk-menu).
6. If it **hard-crashes from Home too** → [Hard crash](#title-hard-crashes-home-and-kiosk) (not a missing ticket).
7. Do **not** launch stubs from Home or SCT. On Home they often look like **DUMMY** / **Non Playable Demo**:

   ![Stub tiles on Home Menu](../PNG/Kiosk/KioskTitlesAndNonStubs.png)

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

Step-by-step: [NEWDEMOS.MD](NEWDEMOS.MD).

---

## Idle reboot after Kiosk Menu / demos

**Symptom:** Console reboots when left idle on Home Menu or in retail games (~2 minutes), often **not** while Kiosk Menu is open.

**Cause:** something in the kiosk path can set `reset_enable=1` in SLC `sys/proc/prefs/im_cfg.xml` (`reset_secnds` often 120). Separate from coldboot.

**Try first — Kiosk Settings → No-Input Reset → Off.** That preference is stored on **MLC** and survives reboots until you wipe MLC or delete the kiosk settings data. It often stops the idle reboot behavior. If idle reboot **still** happens after Off + a reboot, patch SLC from the PC:

```powershell
.\scripts\restore_im_cfg_ftp.ps1
```

Uses `config\config.ps1`. Default **Patch** only sets `reset_enable=0`. `-Mode RestoreRetail` uploads retail `im_cfg.xml` from your dump. Writes live SLC — have a minute backup. Confirm over FTP: `storage_slc/sys/proc/prefs/im_cfg.xml` → `reset_enable`.

---

## Title hard-crashes (Home and Kiosk)

If a demo **hard-crashes from Home Menu too**, tickets / `title.list` / Region are not the cause. **We do not know why** and have no fix — skip that title. Do not launch the **stub** (`…ff`) from Home or SCT.

---

## Stuck in Kiosk Menu coldboot

One way you can try to escape is with the internet browser. If you have a demo game installed, launch it and then press the "Home" button. You should be able to access the internet browser from there. Go to `wiiuexploit.xyz` , press the button and hold B. Then contine like usual. When you launch System Config Tool, change the defualt boot menu.


Kiosk Menu as default boot means **Home never loads**, so **FTP plugins never start**. PC scripts cannot undo that.

**Recovery:** **minute restore** from your offline SLC dump.

Keep **retail Home Menu** as default unless you accept that trap. See [README — Default boot](README.md#default-boot-optional).

---

## Exit Kiosk Settings: Remove the SD card

On **Exit Kiosk Settings**, if an SD card is inserted, Kiosk Menu shows **Remove the SD card** before the carousel / **Kiosk Show** path:

![Exit Kiosk Settings — Remove the SD card](../PNG/Kiosk/Settings/RemoveTheSDCard.png)

After a good apply, the SD is optional. Removing it at this prompt is normal if you want the stock Exit → Kiosk Show flow. Keep a card inserted if you still want Aroma/homebrew from that SD.

---

## Recovery (reflash)

| Problem | What to do |
|---------|------------|
| Bad / experimental SLC | **minute restore** from your offline dump |
| Broken sys title on MLC | Delete/replace the uploaded folder (and check [MLC paths](#mlc-upload-shows-ode--ontent--eta)) |
| In SCT, **Boot title** | Can brick sys SLC — minute restore as above |

**Erase MLC / Delete scfm.img** (minute Backup and Restore) wipes console storage — only when a MLC rebuild guide tells you to; this erases the real MLC:

![Erase MLC and Delete scfm.img in minute](../PNG/Minute/HowToDeleteMLCWiiU.png)

A guide on how to rebuild MLC:

[wafel_setup_mlc](https://github.com/StroopwafelCFW/wafel_setup_mlc)

---

## How to reverse this

You can stop using Kiosk Menu without undoing everything, or strip the mutant off SLC.
If weird bugs and crashes happen then you can reflash the SLC.

### Keep Home Menu, stop using kiosk (light)

1. Coldboot Home: `.\scripts\swap_coldboot_ftp.ps1 -Mode home`
2. Idle reboot: Kiosk Settings → **No-Input Reset → Off**; if it still reboots when idle, `.\scripts\restore_im_cfg_ftp.ps1`
3. Region filter: Kiosk Menu **Region** (North/Latin America / Europe/Australia/NZ / Japan) as you prefer — demos on MLC are not deleted. Optional: `.\scripts\set_sys_prod_region_ftp.ps1 -Mode Restore`
4. Optional: remove demos you added — `.\scripts\patch_demo_rights_ftp.ps1 -Mode Remove -DemoFolder '…'` then delete MLC folders `storage_mlc/usr/title/00050002/<id>/` in WinSCP. This does **not** restore retail `cert.sys` / identity.

Kiosk Menu / SCT can stay on MLC unused.

### Full undo (retail SLC again)

Need Home Menu + FTP (not trapped in Kiosk Menu coldboot).

1. **minute restore** of the **offline SLC backup** you took before the first mutant apply. Highest risk if that backup is missing. Remove uploaded MLC titles (`00050010` Kiosk Menu / SCT, `00050002` demos) if you want them gone.
2. Do **not** WiiUIdent **Submit System Data** while `model_number` is still **WIS-001** / `code_id` **FW**. After a clean retail SLC restore, identity should be retail again.

Saves / Miis: first Kiosk Menu use can create user **Sarah** and **replace the current Mii + name** on the active account. **Back up** before the first launch. A **new** Wii U account you create afterward is left alone. Game saves were not fully tested (MLC was wiped in the lab install).

![User Settings — Sarah set as default user](../PNG/Kiosk/DefaultUserBeingSarah.png)

---

## Aroma / Discovery plugins in Kiosk Menu

Some Aroma / Discovery plugins **may** work while **Kiosk Menu** is running. Lab shots in [README](README.md#kiosk-menu-not-kiosk-os) were taken that way.

That is **not** a guarantee. 

**Do not** rely on FTP or other plugins *inside* Kiosk Menu to fix a bad SLC write. Keep **Home Menu** coldboot for admin work; open FTPiiU from Home.

---

## Screenshots

| Topic | Image |
|-------|--------|
| Retail SCT on Home | [RetailSystemConfigTool.png](../PNG/RetailSystemConfigTool.png) |
| SCT menu map | [HowSystemConfigLooksLike.MD](../PNG/HowSystemConfigLooksLike.MD) |
| Kiosk Settings menu map | [HowKioskSettingsLookLike.MD](../PNG/HowKioskSettingsLookLike.MD) |
| Kiosk Settings main (success) | [KioskSettingsMain.png](../PNG/Kiosk/Settings/KioskSettingsMain.png) |
| Set Menu Options | [KioskSettingsMenu.png](../PNG/Kiosk/Settings/KioskSettingsMenu.png) |
| Exit → Remove the SD card | [RemoveTheSDCard.png](../PNG/Kiosk/Settings/RemoveTheSDCard.png) |
| Kiosk Menu categories (DRC) | [SelectionMenuInDRC.png](../PNG/Kiosk/Menu/SelectionMenuInDRC.png) |
| Kiosk Menu demo carousel (DRC) | [Mario3DWorldDemoDRC.png](../PNG/Kiosk/Menu/Mario3DWorldDemoDRC.png) · [MarioTennisDemoDRC.png](../PNG/Kiosk/Menu/MarioTennisDemoDRC.png) |
| Kiosk Menu title page / video (TV) | [Mario3DWorldDemoTV.png](../PNG/Kiosk/Menu/Mario3DWorldDemoTV.png) · [MarioTennisDemoTV.png](../PNG/Kiosk/Menu/MarioTennisDemoTV.png) |
| Wii U logo splash (TV) | [KiosWiiULogoTV.png](../PNG/Kiosk/Menu/KiosWiiULogoTV.png) |
| Sarah / default user | [DefaultUserBeingSarah.png](../PNG/Kiosk/DefaultUserBeingSarah.png) |
| Stub / Non Playable Demo tiles | [KioskTitlesAndNonStubs.png](../PNG/Kiosk/KioskTitlesAndNonStubs.png) |
| minute Main menu | [Minute.png](../PNG/Minute/Minute.png) |
| Boot sysNAND | [HowToBootNativeWiiU.png](../PNG/Minute/HowToBootNativeWiiU.png) |
| Dump OTP / SLC / SLCCMPT | [WhatNeedsToBeDumpedOnYourConsole.png](../PNG/Minute/WhatNeedsToBeDumpedOnYourConsole.png) |
| Backup and Restore | [DumpAndRestore.png](../PNG/Minute/DumpAndRestore.png) |
| Patch (sd) → boot IOS (slc) | [IfMinuteIsntOnSLC.png](../PNG/Minute/IfMinuteIsntOnSLC.png) |
| Erase MLC / Delete scfm.img | [HowToDeleteMLCWiiU.png](../PNG/Minute/HowToDeleteMLCWiiU.png) — **destructive**; only when a guide tells you to |
