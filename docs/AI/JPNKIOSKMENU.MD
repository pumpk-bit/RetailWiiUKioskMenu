# Japan / NCL Kiosk Menu

Notes from a USA CAT-I MLC extract. **Not** a supported setup path for Japanese retail consoles.

Hub: [README.md](README.md) · [PROBLEMS.md](PROBLEMS.md#region-and-adding-demos-from-another-region) · [EXPERIMENTAL.MD](EXPERIMENTAL.MD) · [KIOSKTITLESDOC.MD](../KIOSKTITLESDOC.MD)

---

## There is no separate JPN Kiosk Menu title

Kiosk Menu is **one** system title worldwide:

| | |
|--|--|
| Title ID | `00050010-1fa81000` |
| MLC path | `storage_mlc/sys/title/00050010/1fa81000/` |
| Binary | `MenuApp.rpx` |
| `meta.xml` names | **Kiosk Menu** / **試遊台メニュー** |
| Region mask | `00000007` (JPN + USA + EUR) |

**Japan** is **Kiosk Settings → Set Region → Japan**. That loads the **NCL** profile (Japanese UI + CERO + Japan demo filter). Same app as North/Latin America (`NOA`) and Europe/Australia/NZ (`NOE`).

Scripts in this repo still only set up **USA** and **PAL** retail consoles.

---

## Region profiles inside `1fa81000`

Under `content/menuapp/MenuConfiguration/`:

| File | Kiosk region | Primary language | Rating board |
|------|----------------|------------------|--------------|
| `DefaultMenuConfigurationnoa.xml` | NOA | `US_English` | ESRB |
| `DefaultMenuConfigurationnoe.xml` | NOE | `EU_English` | PEGI_EU |
| `DefaultMenuConfigurationncl.xml` | NCL | `JP_Japanese` | CERO |

Also present on the USA CAT-I extract:

- `MessageStudio.xml` — completed **`JP_Japanese`** UI strings (not empty placeholders), e.g. タッチするとはじまります。
- Fonts `normal.fnt` / `bold.fnt` include Japanese glyphs; `normal_no_jp*` / `bold_no_jp*` are the smaller Western set
- Log-export keys for all three: `NOA` / `NOE` / `NCL`
- Japan-only copy notes in `MessageStudio.xml` (amiibo wording without the logo, CERO confirm, Featured button)

Kiosk Settings language/rating lists in screenshots are the **NOA** set (English / Spanish / French / Portuguese, ESRB/DJCTQ). **Japan** uses Japanese + **CERO** (see also **CERO Rating Confirmation** under Menu Options).

Region is a **catalog filter**. Switching to Japan hides USA/PAL demos still on MLC; it does not install a second menu. [PROBLEMS.md — Region](PROBLEMS.md#region-and-adding-demos-from-another-region).

---

## JPN kiosk HOME (not the menu)

Experimental HOME overlay is a different title. On the same CAT-I dump:

| Region | Title | On this dump |
|--------|--------|----------------|
| USA | `00050030-1001010A` | Newest (`kiosk_hbm.rpx` v`0051`, SDK 2.12.03) |
| PAL | `00050030-1001020A` | Older (SDK 2.07.03) |
| JPN | `00050030-1001000A` | Present, older (SDK 2.07.03) |

Apply scripts only wire **USA** / **PAL**. JPN HOME is not a drop-in. [EXPERIMENTAL.MD](EXPERIMENTAL.MD).

---

## What this is not

- Not a second MenuApp to upload
- Not “JPN console support” — no `sys_prod` / ticket / script path for a Japanese retail Wii U yet
- Japan demos still need MLC folders + tickets + `title.list`, then **Region = Japan**
