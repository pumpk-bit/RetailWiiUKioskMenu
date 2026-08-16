# Real hardware

Here is the last warning to turn back.

We will touch the following on your Wii U:
* SLC
* MLC

If anything goes wrong then you have to reflash your SLC or erase your MLC.

Main user will turn into "Sarah". Back up all your saves and accounts.

<p>
  <img src="../PNG/Kiosk/DefaultUserBeingSarah.png" alt="Backing up" width="980" />
</p>

Take note: launching a Wii U kiosk game will turn on a setting that reboots the Wii U when idle for ~2 minutes. Even in the Home Menu. When you reach the end there is a guide on how to stop it.


Back up the following on your Wii U if you want to continue:

<p>
  <img src="../PNG/Minute/WhatNeedsToBeDumpedOnYourConsole.png" alt="Backing up" width="980" />
</p>

Optionally your MLC on Aroma.

**Don’t** use WiiUIdent Submit System Data while WIS-001/FW. This makes your Wii U think that it is a CAT-I.


## Getting started

First, make sure your Wii U dumps are safe. Make a copy and put them into the folder: `\dumps\retail`.

Grab your kiosk dumps and move them over to the kiosk folder: `\dumps\kiosk`.

Make sure you have both [wiiu-nandextract](https://github.com/koolkdev/wiiu-nandextract) and [wfs-tools](https://github.com/koolkdev/wfs-tools) ready.


## Kiosk SLC

Put [wiiu-nandextract](https://github.com/koolkdev/wiiu-nandextract) into the folder where the kiosk SLC and OTP are in. Run the program and extract the SLC.

If your kiosk SLC is "SLC.RAW" you can rename it to "slc.bin".

## Kiosk MLC

Make sure you have both MLC.bin and OTP.bin in your folder. 

Use [wfs-tools](https://github.com/koolkdev/wfs-tools) to extract it and make sure the main kiosk menu isn't corrupted. Some files may fail - do not use them since they can crash the system. 

Find the kiosk menu. Title ID is `1fa81000` and should be in `mlc/sys/title/00050010/`

Optional: Find the kiosk System Config Tool. It should be in `00050010/1f700500`

## Finding the tickets for Kiosk Menu and SCT

To find the kiosk menu tickets you'll need to open the extracted SLC.

Tickets are what allow the system to boot the titles.

`sys/rights/ticket/sys/0001/0000000b.tik` - This is for the kiosk menu.

`sys/rights/ticket/sys/0003/00000002.tik` - This is for the kiosk SCT.

## On the Wii U side

Launch the Wii U -> Patch (slc) and boot IOS (slc)

<p>
  <img src="../PNG/Minute/HowToBootNativeWiiU.png" alt="Boot up" width="980" />
</p>

### If you cannot launch 

Make sure that Minute is on the SLC.

Boot into the Wii U with SD:

<p>
  <img src="../PNG/Minute/IfMinuteIsntOnSLC.png" alt="Boot up" width="980" />
</p>

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

Full detail: [How to set up ISFShax](https://gbatemp.net/threads/how-to-set-up-isfshax.642258/).


## FTP

Make sure you have FTP ready and the `.tik` + kiosk menu ready.

### MLC

Open WinSCP or another FTP app. Go to `mlc/sys/title/00050010` on your Wii U and drag and drop the kiosk menu folder there. After it's done uploading, make sure `storage_mlc/sys/title/00050010/1fa81000/` exists.

### SLC tickets

Retail already probably has tickets at these paths but they are retail. You should overwrite them with tickets from your kiosk SLC:

| Ticket on live SLC | Title |
|--------------------|--------|
| `sys/rights/ticket/sys/0001/0000000b.tik` | Kiosk Menu (`1fa81000`) |
| `sys/rights/ticket/sys/0003/00000002.tik` | Native SCT (`1f700500`) (Optional if you use retail) |

If SCT says "Cannot launch this title", these two files are probably the cause. Replace them again from the kiosk dump.

### SLC cert.sys

Retail cannot launch kiosk titles with retail `cert.sys` alone. Merge retail + kiosk bytes. Use PowerShell:

```powershell
$r = [IO.File]::ReadAllBytes('dumps\retail\sys\rights\sys\cert.sys')
$k = [IO.File]::ReadAllBytes('dumps\kiosk\sys\rights\sys\cert.sys')
[IO.File]::WriteAllBytes('merged_cert.sys', ($r + $k))
```

If your extract has a nested `slc\` folder, use `dumps\retail\slc\sys\...` and `dumps\kiosk\slc\sys\...` instead.

Retail is usually 2560 bytes; kiosk is larger (~4096+). Merged size is roughly 6656 bytes. FTP to `storage_slc/sys/rights/sys/cert.sys` and replace the retail file.

### Title list

Go to `storage_slc/sys/rights/sys/title.list` and download it as a copy.

Open in a hex editor.

Kiosk menu: `000500101fa81000` hex: `00 05 00 10 1F A8 10 00`

Native SCT: `000500101f700500` hex: `00 05 00 10 1F 70 05 00` (Optional if you use retail)

Search for each 8-byte sequence — if the ones you need exist, you’re done for the list.

If missing, add those 8 bytes (no separator; file length grows by 8 per ID).

Upload back to the same path.

Or do it straight on the console if you wish.


(Demos need their own title IDs in this file later — see [ADDINGGAMES.MD](ADDINGGAMES.MD).)

### sys_prod.xml (kiosk identity)

Keep your retail serial and region, but change a few things in `sys_prod.xml`.

1. FTP-download `storage_slc/sys/config/sys_prod.xml` (or copy from your retail extract).
2. Set `<model_number>` to `WIS-001` and `<code_id>` to `FW` (values from the kiosk dump’s `sys_prod.xml` if different).
3. Leave `serial_id` / region country fields as your retail values.
4. Upload back to `storage_slc/sys/config/sys_prod.xml`.

Or do it straight on the console if you wish.

### Final options

Optional: Set native SCT as default boot: `storage_slc/sys/config/system.xml`, in it change `<default_title_id>`  to `000500101f700500`

**Do not** set the default boot title to the kiosk menu. You'll be stuck there (Home never loads → FTP never starts). Prefer Home Menu, or native SCT, over Kiosk Menu coldboot.

You do **not** need to upload kiosk `system.xml` crash/standby policy for Home → SCT → Kiosk Menu to work (AI apply defaults to skipping it too).

Now reboot your Wii U system.

## Launching the System Config Tool

Open System Config Tool and go to: `Title Launcher`

Scroll down until you see `Kiosk Menu`. Press A and make sure it's a `Type: Menu`.

Press A to launch it. Don't expect to have any working titles yet. You'll need to FTP them over. [How to add more demos](ADDINGGAMES.MD).

<p>
  <img src="../PNG/Kiosk/Settings/KioskSettingsMain.png" alt="Kiosk Settings" width="980" />
</p>


And you've officially reached the Kiosk Settings, good job!

If anything bad happened then check [here](ISSUES.MD)!

## Turning off No-Input Reset

After first Kiosk Menu / demo use, the console often reboots when idle, even on Home (~2 min).

Do this first in Kiosk Settings → set No-Input Reset → Off. That preference is on the MLC and usually stops the reboots.

<p>
  <img src="../PNG/Kiosk/Settings/KioskSettingsMenu.png" alt="Kiosk Menu Settings" width="980" />
</p>

If it still reboots when idle: FTP `storage_slc/sys/proc/prefs/im_cfg.xml` and set `<reset_enable>` to `0`. That SLC patch alone is temporary — launching a kiosk demo can set it back to `1`. Prefer No-Input Reset → Off in settings.