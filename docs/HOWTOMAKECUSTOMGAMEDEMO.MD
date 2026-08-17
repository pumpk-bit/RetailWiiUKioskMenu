# How to make a custom kiosk demo (playable game)

Use this when you want **Play Demo** in Kiosk Menu to launch **your homebrew game** instead of the original retail demo.

This tutorial **DOES NOT** generate a new title ID + tickets. We replace existing ones.

This works for demos that come as a **pair**:

| Folder | Role | What Kiosk Menu uses it for |
|--------|------|-----------------------------|
| **`…00`** (playable) | Real game / RPX + `content/` | **Play Demo** launches this title |
| **`…FF`** (stub) | `non_playable_demo.rpx` + `KioskMeta.xml` + trailer | Tile, box art, video, text |

Example pair: **NES Remix Pack** — playable `1017c100`, stub `1017c1ff`. The stub’s `KioskMeta.xml` points at the playable ID (`titleID` → `1017C100`, `demoFlg=1`).

You **do not** replace `non_playable_demo.rpx` on the stub for this trick. That file only powers the kiosk tile/trailer. Swap the **playable** title’s main RPX instead.

**Requirements:** Aroma (or similar), an SD card if your homebrew loads assets from SD, and a **playable + stub pair** you are okay overwriting. Keep the same **title ID + ticket** — do not invent a new demo ID without a signed ticket.

---

## Needed

* A **playable + stub pair** from your kiosk dump (e.g. NES Remix `1017c100` / `1017c1ff`).
* Your homebrew built as a **`.rpx`** (WUT / wut-style output).
* An **SD card** if the game reads files from `sd:/` (common for homebrew).
* FTP access to upload the modified playable folder (see [Adding demos](AI/NEWDEMOS.MD)).

---

## 1. Find the playable RPX name

Open the **playable** folder (`…00`), not the stub (`…FF`):

```
1017c100 - NES Remix Pack/
  code/
    cos.xml          ← lists which RPX the OS loads
    WUP-B-AFDE.rpx   ← example: NES Remix playable binary
  content/           ← original game data (can stay or go unused)
  meta/
```

In `code/cos.xml`, read **`argstr`**. That string is the exact filename your replacement must use.

Example (NES Remix):

```xml
<argstr type="string" length="4096">WUP-B-AFDE.rpx</argstr>
```

**Rule:** your homebrew file must be uploaded under **that same name**. The console does not care that the bytes inside changed — it only loads whatever `cos.xml` says.

---

## 2. Replace the playable RPX

1. Back up the original `code/*.rpx`.
2. Rename your homebrew RPX to match `argstr` (e.g. `WUP-B-AFDE.rpx`).
3. Copy it into the playable title’s `code/` folder, overwriting the old file.
4. Leave **`cos.xml`** alone at first. Leave **`app.xml`**, **`title.tmd`**, and the **ticket** unchanged.

**Do not edit the stub’s** `code/non_playable_demo.rpx` **for Play Demo** — Kiosk Menu still shows the stub tile, but **Play Demo** starts the playable title you just patched.

---

## 3. Put game data on the SD card

Many homebrew titles keep large assets on SD instead of MLC `content/`.

Typical layout:

```
sd:/wiiu/apps/YourGame/
  (whatever your homebrew expects)
```

Copy those files **before** testing. If everything is inside the RPX, you can skip this step.

**SD during kiosk use:** Kiosk Menu may ask you to **remove the SD card** when exiting Kiosk Settings. That prompt is only for leaving the menu. You can reinsert the SD after pressing A.

---

## 4. Install on the Wii U

Upload the **playable** MLC folder (and keep the **stub** sibling installed if you still want a kiosk tile):

| Piece | Path |
|-------|------|
| Playable files | `storage_mlc/usr/title/00050002/<playable-id>/` (e.g. `1017c100`) |
| Stub files (tile) | `storage_mlc/usr/title/00050002/<stub-id>/` (e.g. `1017c1ff`) |
| Ticket + `title.list` | unchanged if you reskin an existing demo |

Folder name on the console = **8-char ID only** (`1017c100`), not the long dump folder name.

Details: [NEWDEMOS - AI](AI/NEWDEMOS.MD) · [ADDINGGAMES - Human](HUMAN/ADDINGGAMES.MD)

---

## 5. Test in order

1. **Home Menu** — launch the `.rpx` file like any other homebrew game. If you didn't put the `.rpx` into the game folder, skip this.
2. **Home Menu** — launch the **playable** title ID (not the stub `…FF` / “Non Playable Demo”). Confirm the game runs.
3. **Kiosk Menu** — find the tile (from the stub), press **Play Demo**. That should launch your homebrew.

If Home works but Kiosk Menu does not, check ticket / `title.list` ([PROBLEMS - AI](AI/PROBLEMS.md) · [ISSUES - Human](Human/ISSUES.MD)).

---

## 6. Custom tile, trailer, and text (optional)

The kiosk carousel/title list still shows the **stub** branding/text (old name, trailer, box art) until you change the **`…FF`** folder:

* Video, `KioskMeta.xml`, box art → [HOWTOMAKECUSTOMDEMO.MD](HOWTOMAKECUSTOMDEMO.MD)

Leave `titleID` in that stub meta pointing at your **playable** ID unless you also change tickets and folders together.

Example:

![Custom demo layout on TV](PNG/Kiosk/menu/CustomTV.png)

Game made by [siahisaforker](https://github.com/PortPak/sonic3air-plus).

---

## Troubleshooting

### Black screen or instant exit

* RPX filename does not match `argstr`.
* Wrong title launched (stub `…FF` instead of playable `…00`).
* Make sure the SD card is inside the Wii U when launching from Kiosk menu.

### Tile still shows the old game

Expected. You need to reskin the **stub** (`…FF`) with [HOWTOMAKECUSTOMDEMO.MD](HOWTOMAKECUSTOMDEMO.MD). Play Demo and the tile are separate titles.

---

## AI usage

Cursor helped structure this guide and explain this out. AI did not invent new info and everything was tested by me.
