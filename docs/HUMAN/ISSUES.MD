# Bugs and problems

## My title isn't appearing in the Kiosk menu

The demo never shows in the Kiosk Menu (or the count at the top right does not include it).

1. Kiosk Menu - Change the region (North/Latin America, Japan, Europe/Australia/NZ). The menu filters by that setting — it does **not** delete titles, only hides them. If you change your region, that will change it in `sys_prod.xml`. Use SCT or the kiosk menu to set it back if you want.
2. Folder on the console is `storage_mlc/usr/title/00050002/<8-char-id>/` — **kiosk demo** (`00050002`), not a retail eShop/disc title (`00050000`). Name must be the ID (`10117e00`), no ` - Mario 2D` extra names.
3. Make sure the files exist. No zero-byte files.
4. Title ID is in live `title.list` and a matching `.tik` is on SLC. Add them there.

## My kiosk demo doesn't launch when loaded from Kiosk menu

The app/tile is there, but starting it fails (error, black screen, crash, or instant reboot).

1. Reboot the console and try again. Some titles have launched on a second try with no other change.
2. Not corrupted — compare `code/*.rpx` size to your PC dump. Re-upload if it was a failed FTP. Skip titles that extracted as `Failed-` or have 0-byte files.
3. Region matches the demo (North/Latin America for USA Cat-I). If you change your region, that will change it in `sys_prod.xml`. Use SCT or the kiosk menu to set it back if you want.
4. If Home Menu plays it but Kiosk Menu does not - add it to the `title.list`.
5. If it hard-crashes from Home too - I don't know. Try a different version/another dump.
6. Do **not** launch stubs from Home or SCT. On Home they often look like **DUMMY** and are called "Non Playable Demo".

## Cannot launch this title (SCT or Kiosk Menu)

Apply can look fine (`cert.sys` ~6656 bytes, WIS-001 / FW, MLC uploaded) but SCT or Kiosk Menu still says *Cannot launch this title*.

Probably: retail already had `.tik` files at the same paths, with retail bytes. Kiosk needs kiosk bytes from your dump. Or you forgot to overwrite them before. Overwrite the files:

| Ticket on live SLC | Title |
|--------------------|--------|
| `sys/rights/ticket/sys/0001/0000000b.tik` | Kiosk Menu (`1fa81000`) |
| `sys/rights/ticket/sys/0003/00000002.tik` | Native SCT (`1f700500`) |

Also confirm that both title IDs are in `storage_slc/sys/rights/sys/title.list`. Reboot, then try again.

## Demos launch on Home Menu but not from Kiosk Menu

Check: `title.list`.

Home Menu can launch from ticket + content. Kiosk Menu also needs the title ID in `storage_slc/sys/rights/sys/title.list`. 

Then reboot. 

## Title crashes (Home and Kiosk)

If a demo crashes from Home Menu too, tickets / `title.list` / region are not the cause. I don't know. Skip that game for now and try another dump.

## Stuck in Kiosk Menu (default boot)

Kiosk Menu as default boot means Home never loads, so FTP plugins may never start.

One way you can try to escape is with the internet browser. If you have a demo game installed, launch it and then press the "Home" button. You should be able to access the internet browser from there. Go to `wiiuexploit.xyz` , press the button and hold B. Then contine like usual. When you launch System Config Tool, change the defualt boot menu.

You can use Minute restore to reflash the SLC.

If you find a way out of the Kiosk Menu and into the Home Menu then go to System Config Tool and set the default boot or use FTP.  [HowSystemConfigLooksLike.MD](../PNG/HowSystemConfigLooksLike.MD)

Keep retail Home Menu as default unless you accept that trap. Or set it as System Config Tool.

## Turning off No-Input Reset

Is your Wii U rebooting every ~2 min on Home Menu or in retail games (often **not** while Kiosk Menu is open)?

**First:** Kiosk Settings → **No-Input Reset → Off** (stored on MLC; survives reboots).

<p>
  <img src="../PNG/Kiosk/Settings/KioskSettingsMenu.png" alt="Kiosk Menu Settings" width="980" />
</p>

If it still reboots: FTP `storage_slc/sys/proc/prefs/im_cfg.xml` and set `<reset_enable>` to `0`. That is temporary — a kiosk demo can set it back to `1`. Keep No-Input Reset → Off in kiosk settings.