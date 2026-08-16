# How to add games/demos to the kiosk menu

Here you'll learn how to add games to the kiosk menu, different region games also work.

## What you need

Every playable kiosk demo needs three pieces on the console:

| # | What | FTP path |
|---|------|----------|
| 1 | Ticket (`.tik`) | `storage_slc/sys/rights/ticket/…` |
| 2 | Title ID in **`title.list`** | `storage_slc/sys/rights/sys/title.list` |
| 3 | Title files | `storage_mlc/usr/title/00050002/<8-char-id>/` |

Also:
* A kiosk title that's already extracted
* FTP
* The SLC you got the game from (other dumps are fine for demos if you have that dump’s SLC tickets)

Folder name on the console must be **only** the 8-character ID (`10117e00`).

## FTP

Use FTP to transfer the game folder over to the Wii U: `storage_mlc/usr/title/00050002/<8-char-id>/`.

Make sure the demo contains all the files and none of the files are corrupted.

If you want a playable demo then make sure the `content` folder contains files and `code` doesn't contain `non_playable_demo.rpx`. These are stubs that only show a video. But if a game has a stub sibling then don't forget to FTP it over too.

Let's take Mario 3D World as an example:

`00050002 -> 10159b00` and `00050002 -> 10159bff`. Mario 3D World has a video and a game folder, both need tickets.

## How to find the tickets?

Easiest way is to use the AI script:

```
.\scripts\map_kiosk_demo_tickets.ps1
```
Open `backup\live_slc_pre_mutant\kiosk_demo_ticket_map.txt` and find the row for `10159b00` and there is the ticket. Same for `10159bff`. 

### By hand (no script)

Example: New Super Mario Bros. U `10117e00`.

Know the full title ID: 00050002 + 10117e00 -> 0005000210117e00.

Go to the kiosk SLC extract tickets folder `dumps\kiosk\…\sys\rights\ticket\`

Open .tik files in a hex editor (like HxD) and check offset 0x1DC (476 decimal).
The next 8 bytes are the title ID. You’re looking for:

`00 05 00 02 10 11 7E 00`
That’s `0005000210117e00`.

If you eventually find the right ticket then drag and drop the `.tik` into the same folder on the Wii U SLC: `storage_slc/sys/rights/ticket/` + the path you found.

You also need the ID in title.list and the MLC folder
`storage_mlc/usr/title/00050002/10117e00/`

Practical tip:
Don’t hunt randomly through hundreds of .tik files. Either run the script, or search the ticket tree with a hex/binary search for the bytes `00 05 00 02 10 11 7E 00` (or the ASCII hex string if your tool supports it). The first hit at 0x1DC is almost always the right ticket.

### How to add the title list

Example: New Super Mario Bros. U demo `0005000210117e00`: `00 05 00 02 10 11 7E 00`

With FTP download the Wii U SLC title.list `\sys\rights\sys\title.list` 

Open in a hex editor.
Search for those 8 bytes. If already present in the list then skip.

If it's missing then add the 8 bytes (order doesn’t matter for launch).
Upload back to the Wii U and then reboot.

Easier than hex, use the AI script if you want:
```
.\scripts\patch_demo_rights_ftp.ps1 -Mode Add -DemoFolder 'C:\path\to\10117e00'
```
That patches title.list and uploads the ticket. (You need SLC and MLC extracted)


## How to remove demos

Use FTP to delete the game folder. Tickets and title list can stay but it's recommended to remove them too.

Find the tickets you copied over to the Wii U SLC and remove them.

Edit out the title from `title.list`.

Or use AI script:

```
.\scripts\patch_demo_rights_ftp.ps1 -Mode Remove -DemoFolder 'C:\path\to\game'
```

(You need SLC and MLC extracted)


## Stubs/Video titles

Some games are stubs that show only videos. These folders end with `…ff` and contain `non_playable_demo.rpx`. These show only an mp4 video on the kiosk menu. Don't try to launch them from the retail Home Menu.