# Retail Wii U Kiosk Menu

This project is focused on runing the **CAT-I Kiosk Menu** on a retail Wii U. **Kiosk Menu**, not a full kiosk OS. 

You open the Kiosk Menu from **System Config Tool (SCT)** after merging kiosk licenses onto SLC and uploading the menu (and demos) to MLC

**No dumps or tickets** in this repo. You supply your own CAT-I extract.

<p>
  <img src="docs/PNG/Kiosk/Menu/Mario3DWorldDemoTV.png" alt="Kiosk Menu on TV 3D World" />
  <img src="docs/PNG/Kiosk/Menu/MarioTennisDemoTV.png" alt="Kiosk Menu on TV Tennis" />
</p>

## Warnings

- Bad SLC/MLC writes can soft-brick. Back up **OTP / SLC / SLCCMPT** (and saves) first.
- First Kiosk Menu use creates user **Sarah** over the main account.
- Keep **retail Home Menu** as default boot so FTP still works. Coldbooting Kiosk Menu traps you (no Home → no FTP).
- **Don’t** use WiiUIdent **Submit System Data** while identity is **WIS-001 / FW**.

## Guides

| Install | Notes |
|-------|----------------|
| **[Human tutorial](docs/HUMAN/README.MD)** | Step-by-step FTP / hex / PowerShell by hand. Made by me. |
| **[AI / scripts tutorial](docs/AI/README.md)** | PowerShell scripts (`build_mutant_slc`, FTP apply, demos). Made with the help of Cursor AI. |

Both main paths need: **Aroma**, **FTPiiU**, **ISFShax + minute**, a **CAT-I dump**, and **SCT**. More about it in the tutorials.

| New life into your kiosk | Notes |
|-------|----------------|
| **[Custom video demo](docs/HOWTOMAKECUSTOMDEMO.MD)** | Reskin a video stub (your MP4, `KioskMeta.xml` text, box art).|
| **[Custom playable demo](docs/HOWTOMAKECUSTOMGAMEDEMO.MD)** | Swap a playable demo’s RPX for homebrew (SD assets).|

| Documentation | Notes |
|-------|----------------|
| **[Kiosk system titles](docs/KIOSKTITLESDOC.MD)** |Files that came with your system/dump. Don't know what is what? |
| **[System Config Tool](docs/PNG/HowSystemConfigLooksLike.MD)** | Want to learn about System Config Tool?|
| **[Kiosk Settings Menu](docs/PNG/HowKioskSettingsLookLike.MD)** | Want to learn about Kiosk before modding?|


| Experimental options | Notes |
|-------|----------------|
| **[Experimental](docs/AI/EXPERIMENTAL.MD)** | Kiosk Home Button Menu / system fonts (high risk, incomplete). |

---

| Adding all kinds of demos | Notes |
|-------|----------------|
| **[Human tutorial](docs/HUMAN/ADDINGGAMES.MD)** | Step-by-step FTP / hex / PowerShell guide by hand. Made by me. |
| **[AI / scripts tutorial](docs/AI/NEWDEMOS.md)** | PowerShell scripts and easier. Made with the help of Cursor AI. |


| Any problems? | Notes |
|-------|----------------|
| **[Human debugging](docs/HUMAN/ISSUES.MD)** | Debug and find fix problems. Guide by me. |
| **[AI / scripts debugging](docs/AI/PROBLEMS.md)** | Find mistakes. Made with the help of Cursor AI. |


## Legal

Kiosk NAND/title/SCT data is copyrighted. Obtain dumps yourself.

Thanks: [koolkdev](https://github.com/koolkdev), ISFShax / minute community, and Cursor AI ([cursor.com](https://cursor.com/)).
