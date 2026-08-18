# Kiosk helper titles

These are the extra **system titles** (`00050000`) that Kiosk Menu uses alongside demo tiles (`00050002`). Your console may be missing some of them. Most are optional — you can copy missing titles from another kiosk install.

For Kiosk Menu itself (`1fa81000`), see [JPNKIOSKMENU.MD](AI/JPNKIOSKMENU.MD) (Japan/NCL profile) or the main setup guides.

**On this page**

- [Title overview](#title-overview)
- [Video helpers (About Wii U, Attract, Amiibo)](#video-helpers-about-wii-u-attract-amiibo)
- [Featured list](#featured-list-1fa82200)
- [New releases list](#new-releases-list-1fa82300)
- [Broken or missing files](#broken-or-missing-files)
- [How to encode video](#how-to-encode-video)
- [How to recreate XML](#how-to-recreate-xml)
- [AI usage](#ai-usage)

---

## Title overview

Full title IDs start with **`00050000`**, then the 8-character folder name (example: `1fa82200` → `000500001fa82200`).

On the Wii U, these titles live under:

`mlc/usr/title/00050000/<8-char-id>/`

| ID | Name | What it does |
|----|------|--------------|
| `1fa82000` | About Wii U | Top-right bubble with Wii U explainer videos (e.g. “What is the GamePad?”). |
| `1fa82100` | Attract Mode | Idle/attract videos when Kiosk Menu is not in use. |
| `1fa82200` | Featured | Controls which demos show under **Featured** (bottom left). |
| `1fa82300` | New releases | Controls which demos show under **New** (bottom left). |
| `1fa83300` | About Amiibo | Top-left bubble with Amiibo explainer videos. |
| `1fa80000` | KioskMenuSetterDev | Switches the main boot title of the Wii U. |

---

## Video helpers (About Wii U, Attract, Amiibo)

Titles `1fa82000`, `1fa82100`, and `1fa83300` play MP4 files from their `meta/` folder.

| Title | Video file pattern |
|-------|-------------------|
| About Wii U | `AboutWiiU00.mp4` … `AboutWiiU05.mp4` |
| Attract Mode | `AttractMode00.mp4` … `AttractMode11.mp4` |
| About Amiibo | `AboutAmiibo00.mp4` |

You can replace broken videos — see [Broken or missing files](#broken-or-missing-files) and [How to encode video](#how-to-encode-video).

---

## Featured list (`1fa82200`)

Kiosk Menu reads **`meta/Featured.xml`** from this title.

Example file:

```xml
<?xml version="1.0" encoding="utf-8"?>
<title_list type="featured">
	<title order="1" start_date="2012-01-01 00:00:00" end_date="2035-01-01 23:59:59">00050002101DB4FF</title>
	<title order="2" start_date="2012-01-01 00:00:00" end_date="2035-01-01 23:59:59">00050002101CE4FF</title>
	...
</title_list>
```

Each entry is a **full 16-hex demo title ID** (`00050002` + 8-char folder ID). Use the **stub** ID (`…FF`) when that is the tile Kiosk Menu shows.

### Add a demo to Featured

1. Pick the demo you want listed.
2. Build the full ID: `00050002` + folder name.  
   Example: New Super Mario Bros. U folder `10117e00` → `0005000210117e00` (or `…10117eff` if your tile is the stub).
3. Add a line to `Featured.xml`:

```xml
<title order="3" start_date="2012-01-01 00:00:00" end_date="2035-01-01 23:59:59">0005000210117e00</title>
```

| Attribute | Meaning |
|-----------|---------|
| `order` | Sort position (lower numbers first). |
| `start_date` | When the entry becomes active (date + time). |
| `end_date` | When it stops showing (date + time). |

4. Upload the changed file, reboot or re-open Kiosk Menu, and check **Featured**.

---

## New releases list (`1fa82300`)

Same idea as Featured, but Kiosk Menu reads **`meta/NewReleases.xml`**.

Example file:

```xml
<?xml version="1.0" encoding="utf-8"?>
<title_list type="new release">
	<title order="1" start_date="2012-01-01 00:00:00" end_date="2035-01-01 23:59:59">00050002101DB4FF</title>
	<title order="2" start_date="2012-01-01 00:00:00" end_date="2035-01-01 23:59:59">00050002101CE4FF</title>
	...
</title_list>
```

### Add a demo to New

1. Build the full demo ID the same way as Featured.
2. Add a line to `NewReleases.xml`:

```xml
<title order="3" start_date="2012-01-01 00:00:00" end_date="2035-01-01 23:59:59">0005000210117e00</title>
```

3. Upload, reboot or re-open Kiosk Menu, and check **New**.

`start_date` / `end_date` work the same as on Featured.

---

## Broken or missing files

**Video files** — replacements can be found online. Re-encode if the Wii U rejects them ([How to encode video](#how-to-encode-video)).

**Boot art / manual** (`bootDrcTex.tga`, `bootLogotex.tga`, `bootTvTex.tga`, `iconTex.tga`, `bootMovie.h264`, `Manual.bfma`) — copy from another kiosk helper title if missing. Not every title needs every asset.

**`.rpx` / `title.fst` / `title.tmd`** — no recovery guide here.

**`.xml`** — you can try to recreate them ([How to recreate XML](#how-to-recreate-xml)).

---

## How to encode video

Use [ffmpeg](https://ffmpeg.org/download.html).

Same recipe as demo trailers in [HOWTOMAKECUSTOMDEMO.MD](HOWTOMAKECUSTOMDEMO.MD): **1080p H.264 High@L4.0 + AAC stereo 48 kHz** (not Opus).

```powershell
ffmpeg -y -i "YourSource.mp4" `
  -map 0:v:0 -map 0:a:0? `
  -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p `
  -x264-params "cabac=1:ref=4:deblock=1:0:0:me=hex:subme=7" `
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" `
  -r 30 `
  -c:a aac -b:a 192k -ac 2 -ar 48000 `
  -movflags +faststart `
  -brand mp42 `
  "Output.mp4"
```

Replace the output filename with the MP4 your title expects (e.g. `AboutWiiU00.mp4`). Keep a backup of the old file unless it is empty (0 bytes).

---

## How to recreate XML

Use this when `app.xml`, `cos.xml`, or `meta.xml` under a kiosk **`00050000`** title is missing or corrupted.

This does **not** cover demo stub text — that is `KioskMeta.xml` on **`00050002`** titles ([HOWTOMAKECUSTOMDEMO.MD](HOWTOMAKECUSTOMDEMO.MD)).

The templates below are **fictional examples**. They use the same element names as real Cafe title XML, but values are placeholders. If you have a working copy of the same title, prefer that over guessing.

### Folder layout

```text
<8-char-id>/
  code/
    app.xml
    cos.xml
    example_app.rpx    ← filename must match cos.xml argstr
    title.tmd          ← not recreatable here
    title.fst          ← not recreatable here
  meta/
    meta.xml
    Featured.xml       ← Featured title only
    NewReleases.xml    ← New releases title only
  content/
```

| File | Role |
|------|------|
| `code/app.xml` | Title identity: `title_id`, OS/SDK version |
| `code/cos.xml` | Launch config: `argstr` = RPX filename; FS permissions |
| `meta/meta.xml` | Display names, product code, publisher |
| `meta/Featured.xml` | Featured demo list (plain XML) |
| `meta/NewReleases.xml` | New-release demo list (plain XML) |

### `title_id` format

16 hex characters, no `0x` prefix: **`00050000`** + your **8-character folder ID**.

| Folder (example) | Value in `app.xml` / `meta.xml` |
|------------------|----------------------------------|
| `12345678` | `0005000012345678` |
| `87654321` | `0005000087654321` |

The same **`title_id`** must appear in **`app.xml`** and **`meta.xml`**. A mismatch usually prevents launch.

### RPX name (`cos.xml` → `argstr`)

**`argstr`** must match the exact `.rpx` filename in `code/` (case-sensitive), e.g. `example_app.rpx`.

If `cos.xml` is fixed but the matching `.rpx`, `title.tmd`, or `title.fst` is still broken, XML alone is not enough.

### After editing

1. Upload changed files into the title folder on MLC (8-char folder name only).
2. Reboot the console.
3. Re-open Kiosk Menu and verify the affected feature.

---

### `app.xml` template (example)

Replace placeholders with values from your title. **`group_id`**, **`sdk_version`**, and **`os_version`** should match a working install of the same title when possible.

```xml
<!--
  Fictional Wii U app.xml example.
  Not an original platform vendor file.
  Values are illustrative placeholders.
-->
<?xml version="1.0" encoding="utf-8"?>
<app type="complex" access="777">
  <version type="unsignedInt" length="4">1</version>
  <os_version type="hexBinary" length="8">0005000000000000</os_version>
  <title_id type="hexBinary" length="8">0005000012345678</title_id>
  <title_version type="hexBinary" length="2">0000</title_version>
  <sdk_version type="unsignedInt" length="4">12345</sdk_version>
  <app_type type="hexBinary" length="4">80000000</app_type>
  <group_id type="hexBinary" length="4">00001234</group_id>
</app>
```

| Field | Purpose |
|-------|---------|
| `title_id` | Full 16-hex system title ID |
| `title_version` | 4-hex title version |
| `sdk_version` | SDK build number from a working copy |
| `group_id` | Title group — copy from a working file when unsure |
| `os_version` | Minimum OS version the title expects |

---

### `cos.xml` template (example)

Set **`argstr`** to your RPX filename. The **permissions** block defines FS/USB/account access. The masks below are a generic starting layout — prefer a working `cos.xml` from the same title type if launch fails.

```xml
<!--
  Fictional Wii U cos.xml example.
  Not an original platform vendor file.
  Values are illustrative placeholders.
-->
<?xml version="1.0" encoding="utf-8"?>
<app type="complex" access="777">
  <version type="unsignedInt" length="4">1</version>
  <cmdFlags type="unsignedInt" length="4">0</cmdFlags>
  <argstr type="string" length="4096">example_app.rpx</argstr>
  <avail_size type="hexBinary" length="4">00000000</avail_size>
  <codegen_size type="hexBinary" length="4">00000000</codegen_size>
  <codegen_core type="hexBinary" length="4">00000001</codegen_core>
  <max_size type="hexBinary" length="4">80000000</max_size>
  <max_codesize type="hexBinary" length="4">0e000000</max_codesize>
  <permissions type="complex">
    <p0 type="complex">
      <group type="unsignedInt" length="4"> 1</group>
      <mask type="hexBinary" length="8">000000000000FF00</mask>
    </p0>
    <!--BSP-->
    <p1 type="complex">
      <group type="unsignedInt" length="4"> 3</group>
      <mask type="hexBinary" length="8">0000000000000007</mask>
    </p1>
    <!--DK -->
    <p2 type="complex">
      <group type="unsignedInt" length="4"> 9</group>
      <mask type="hexBinary" length="8">FFFFFFFFFFFFFFFF</mask>
    </p2>
    <!--USB CLS DRV-->
    <p3 type="complex">
      <group type="unsignedInt" length="4">12</group>
      <mask type="hexBinary" length="8">0000000000000001</mask>
    </p3>
    <!--UHS-->
    <p4 type="complex">
      <group type="unsignedInt" length="4">11</group>
      <mask type="hexBinary" length="8">FFFFFFFFFFFFFFFF</mask>
    </p4>
    <!--FS -->
    <p5 type="complex">
      <group type="unsignedInt" length="4">13</group>
      <mask type="hexBinary" length="8">00000000000000FF</mask>
    </p5>
    <!--MCP-->
    <p6 type="complex">
      <group type="unsignedInt" length="4">14</group>
      <mask type="hexBinary" length="8">0000000000000000</mask>
    </p6>
    <!--NIM-->
    <p7 type="complex">
      <group type="unsignedInt" length="4">15</group>
      <mask type="hexBinary" length="8">0000000000000003</mask>
    </p7>
    <!--ACT (account)-->
    <p8 type="complex">
      <group type="unsignedInt" length="4">16</group>
      <mask type="hexBinary" length="8">0000000000000003</mask>
    </p8>
    <!--FPD-->
    <p9 type="complex">
      <group type="unsignedInt" length="4">17</group>
      <mask type="hexBinary" length="8">0000000000000001</mask>
    </p9>
    <!--BOSS-->
    <p10 type="complex">
      <group type="unsignedInt" length="4">18</group>
      <mask type="hexBinary" length="8">0000000000000001</mask>
    </p10>
    <!--ACP-->
    <p11 type="complex">
      <group type="unsignedInt" length="4">19</group>
      <mask type="hexBinary" length="8">0000000000000001</mask>
    </p11>
    <!--PDM-->
    <p12 type="complex">
      <group type="unsignedInt" length="4">20</group>
      <mask type="hexBinary" length="8">0000000000000003</mask>
    </p12>
    <!--AC-->
    <p13 type="complex">
      <group type="unsignedInt" length="4">21</group>
      <mask type="hexBinary" length="8">0000000000000001</mask>
    </p13>
    <!--NDM-->
    <p14 type="complex">
      <group type="unsignedInt" length="4">22</group>
      <mask type="hexBinary" length="8">0000000000000001</mask>
    </p14>
    <!--NSEC-->
  </permissions>
  <default_stack0_size type="hexBinary" length="4">00000000</default_stack0_size>
  <default_stack1_size type="hexBinary" length="4">00000000</default_stack1_size>
  <default_stack2_size type="hexBinary" length="4">00000000</default_stack2_size>
  <default_redzone0_size type="hexBinary" length="4">00000000</default_redzone0_size>
  <default_redzone1_size type="hexBinary" length="4">00000000</default_redzone1_size>
  <default_redzone2_size type="hexBinary" length="4">00000000</default_redzone2_size>
  <exception_stack0_size type="hexBinary" length="4">00001000</exception_stack0_size>
  <exception_stack1_size type="hexBinary" length="4">00001000</exception_stack1_size>
  <exception_stack2_size type="hexBinary" length="4">00001000</exception_stack2_size>
</app>
```

---

### `meta.xml` template (example)

**`longname_*`**, **`shortname_*`**, and **`publisher_*`** control how the title reads on Home. Kiosk helper titles are often invisible there, but keep them consistent. **`product_code`** and **`company_code`** are metadata strings — copy from a working install when recreating a real title.

```xml
<!--
  Fictional Wii U meta.xml example.
  Not an original Nintendo file.
  Values are illustrative placeholders.
-->
<?xml version="1.0" encoding="utf-8"?>
<menu type="complex" access="777">
  <version type="unsignedInt" length="4">1</version>
  <product_code type="string" length="32">WUP-P-EX00</product_code>
  <content_platform type="string" length="32">WUP</content_platform>
  <company_code type="string" length="8">EXMP</company_code>
  <mastering_date type="string" length="32">2000-01-01 00.00.00</mastering_date>
  <logo_type type="unsignedInt" length="4">0</logo_type>
  <app_launch_type type="hexBinary" length="4">00000000</app_launch_type>
  <invisible_flag type="hexBinary" length="4">00000000</invisible_flag>
  <no_managed_flag type="hexBinary" length="4">00000000</no_managed_flag>
  <no_event_log type="hexBinary" length="4">00000000</no_event_log>
  <no_icon_database type="hexBinary" length="4">00000000</no_icon_database>
  <launching_flag type="hexBinary" length="4">00000000</launching_flag>
  <install_flag type="hexBinary" length="4">00000000</install_flag>
  <closing_msg type="unsignedInt" length="4">0</closing_msg>
  <title_version type="unsignedInt" length="4">0</title_version>
  <title_id type="hexBinary" length="8">0005000012345678</title_id>
  <group_id type="hexBinary" length="4">00001234</group_id>
  <boss_id type="hexBinary" length="8">0000000000000000</boss_id>
  <os_version type="hexBinary" length="8">0005000000000000</os_version>
  <app_size type="hexBinary" length="8">0000000000000000</app_size>
  <common_save_size type="hexBinary" length="8">0000000000400000</common_save_size>
  <account_save_size type="hexBinary" length="8">0000000000200000</account_save_size>
  <common_boss_size type="hexBinary" length="8">0000000000400000</common_boss_size>
  <account_boss_size type="hexBinary" length="8">0000000000100000</account_boss_size>
  <save_no_rollback type="unsignedInt" length="4">0</save_no_rollback>
  <join_game_id type="hexBinary" length="4">00000000</join_game_id>
  <join_game_mode_mask type="hexBinary" length="8">0000000000000000</join_game_mode_mask>
  <bg_daemon_enable type="unsignedInt" length="4">1</bg_daemon_enable>
  <olv_accesskey type="unsignedInt" length="4">0</olv_accesskey>
  <wood_tin type="unsignedInt" length="4">0</wood_tin>
  <e_manual type="unsignedInt" length="4">1</e_manual>
  <e_manual_version type="unsignedInt" length="4">0</e_manual_version>
  <region type="hexBinary" length="4">00000002</region>
  <pc_cero type="unsignedInt" length="4">0</pc_cero>
  <pc_esrb type="unsignedInt" length="4">0</pc_esrb>
  <pc_bbfc type="unsignedInt" length="4">0</pc_bbfc>
  <pc_usk type="unsignedInt" length="4">0</pc_usk>
  <pc_pegi_gen type="unsignedInt" length="4">0</pc_pegi_gen>
  <pc_pegi_fin type="unsignedInt" length="4">0</pc_pegi_fin>
  <pc_pegi_prt type="unsignedInt" length="4">0</pc_pegi_prt>
  <pc_pegi_bbfc type="unsignedInt" length="4">0</pc_pegi_bbfc>
  <pc_cob type="unsignedInt" length="4">0</pc_cob>
  <pc_grb type="unsignedInt" length="4">0</pc_grb>
  <pc_cgsrr type="unsignedInt" length="4">0</pc_cgsrr>
  <pc_oflc type="unsignedInt" length="4">0</pc_oflc>
  <pc_reserved0 type="unsignedInt" length="4">0</pc_reserved0>
  <pc_reserved1 type="unsignedInt" length="4">0</pc_reserved1>
  <pc_reserved2 type="unsignedInt" length="4">0</pc_reserved2>
  <pc_reserved3 type="unsignedInt" length="4">0</pc_reserved3>
  <ext_dev_nunchaku type="unsignedInt" length="4">0</ext_dev_nunchaku>
  <ext_dev_classic type="unsignedInt" length="4">0</ext_dev_classic>
  <ext_dev_urcc type="unsignedInt" length="4">0</ext_dev_urcc>
  <ext_dev_board type="unsignedInt" length="4">0</ext_dev_board>
  <ext_dev_usb_keyboard type="unsignedInt" length="4">0</ext_dev_usb_keyboard>
  <ext_dev_etc type="unsignedInt" length="4">0</ext_dev_etc>
  <ext_dev_etc_name type="string" length="512">ExampleDevice</ext_dev_etc_name>
  <eula_version type="unsignedInt" length="4">0</eula_version>
  <drc_use type="unsignedInt" length="4">1</drc_use>
  <network_use type="unsignedInt" length="4">0</network_use>
  <online_account_use type="unsignedInt" length="4">0</online_account_use>
  <direct_boot type="unsignedInt" length="4">0</direct_boot>
  <reserved_flag0 type="hexBinary" length="4">00000000</reserved_flag0>
  <reserved_flag1 type="hexBinary" length="4">00000000</reserved_flag1>
  <reserved_flag2 type="hexBinary" length="4">00000000</reserved_flag2>
  <reserved_flag3 type="hexBinary" length="4">00000000</reserved_flag3>
  <reserved_flag4 type="hexBinary" length="4">00000000</reserved_flag4>
  <reserved_flag5 type="hexBinary" length="4">00000000</reserved_flag5>
  <reserved_flag6 type="hexBinary" length="4">00000000</reserved_flag6>
  <reserved_flag7 type="hexBinary" length="4">00000000</reserved_flag7>
  <longname_ja type="string" length="512">Example Application (JA)</longname_ja>
  <longname_en type="string" length="512">Example Wii U Application</longname_en>
  <longname_fr type="string" length="512">Example Application (FR)</longname_fr>
  <longname_de type="string" length="512">Example Application (DE)</longname_de>
  <longname_it type="string" length="512">Example Application (IT)</longname_it>
  <longname_es type="string" length="512">Example Application (ES)</longname_es>
  <longname_zhs type="string" length="512">Example Application (ZHS)</longname_zhs>
  <longname_ko type="string" length="512">Example Application (KO)</longname_ko>
  <longname_nl type="string" length="512">Example Application (NL)</longname_nl>
  <longname_pt type="string" length="512">Example Application (PT)</longname_pt>
  <longname_ru type="string" length="512">Example Application (RU)</longname_ru>
  <longname_zht type="string" length="512">Example Application (ZHT)</longname_zht>
  <shortname_ja type="string" length="256">Example App (JA)</shortname_ja>
  <shortname_en type="string" length="256">Example App</shortname_en>
  <shortname_fr type="string" length="256">Example App (FR)</shortname_fr>
  <shortname_de type="string" length="256">Example App (DE)</shortname_de>
  <shortname_it type="string" length="256">Example App (IT)</shortname_it>
  <shortname_es type="string" length="256">Example App (ES)</shortname_es>
  <shortname_zhs type="string" length="256">Example App (ZHS)</shortname_zhs>
  <shortname_ko type="string" length="256">Example App (KO)</shortname_ko>
  <shortname_nl type="string" length="256">Example App (NL)</shortname_nl>
  <shortname_pt type="string" length="256">Example App (PT)</shortname_pt>
  <shortname_ru type="string" length="256">Example App (RU)</shortname_ru>
  <shortname_zht type="string" length="256">Example App (ZHT)</shortname_zht>
  <publisher_ja type="string" length="256">Example Publisher (JA)</publisher_ja>
  <publisher_en type="string" length="256">Example Publisher</publisher_en>
  <publisher_fr type="string" length="256">Example Publisher (FR)</publisher_fr>
  <publisher_de type="string" length="256">Example Publisher (DE)</publisher_de>
  <publisher_it type="string" length="256">Example Publisher (IT)</publisher_it>
  <publisher_es type="string" length="256">Example Publisher (ES)</publisher_es>
  <publisher_zhs type="string" length="256">Example Publisher (ZHS)</publisher_zhs>
  <publisher_ko type="string" length="256">Example Publisher (KO)</publisher_ko>
  <publisher_nl type="string" length="256">Example Publisher (NL)</publisher_nl>
  <publisher_pt type="string" length="256">Example Publisher (PT)</publisher_pt>
  <publisher_ru type="string" length="256">Example Publisher (RU)</publisher_ru>
  <publisher_zht type="string" length="256">Example Publisher (ZHT)</publisher_zht>
  <add_on_unique_id0 type="hexBinary" length="4">00000000</add_on_unique_id0>
  <add_on_unique_id1 type="hexBinary" length="4">00000000</add_on_unique_id1>
  <add_on_unique_id2 type="hexBinary" length="4">00000000</add_on_unique_id2>
  <add_on_unique_id3 type="hexBinary" length="4">00000000</add_on_unique_id3>
  <add_on_unique_id4 type="hexBinary" length="4">00000000</add_on_unique_id4>
  <add_on_unique_id5 type="hexBinary" length="4">00000000</add_on_unique_id5>
  <add_on_unique_id6 type="hexBinary" length="4">00000000</add_on_unique_id6>
  <add_on_unique_id7 type="hexBinary" length="4">00000000</add_on_unique_id7>
  <add_on_unique_id8 type="hexBinary" length="4">00000000</add_on_unique_id8>
  <add_on_unique_id9 type="hexBinary" length="4">00000000</add_on_unique_id9>
  <add_on_unique_id10 type="hexBinary" length="4">00000000</add_on_unique_id10>
  <add_on_unique_id11 type="hexBinary" length="4">00000000</add_on_unique_id11>
  <add_on_unique_id12 type="hexBinary" length="4">00000000</add_on_unique_id12>
  <add_on_unique_id13 type="hexBinary" length="4">00000000</add_on_unique_id13>
  <add_on_unique_id14 type="hexBinary" length="4">00000000</add_on_unique_id14>
  <add_on_unique_id15 type="hexBinary" length="4">00000000</add_on_unique_id15>
  <add_on_unique_id16 type="hexBinary" length="4">00000000</add_on_unique_id16>
  <add_on_unique_id17 type="hexBinary" length="4">00000000</add_on_unique_id17>
  <add_on_unique_id18 type="hexBinary" length="4">00000000</add_on_unique_id18>
  <add_on_unique_id19 type="hexBinary" length="4">00000000</add_on_unique_id19>
  <add_on_unique_id20 type="hexBinary" length="4">00000000</add_on_unique_id20>
  <add_on_unique_id21 type="hexBinary" length="4">00000000</add_on_unique_id21>
  <add_on_unique_id22 type="hexBinary" length="4">00000000</add_on_unique_id22>
  <add_on_unique_id23 type="hexBinary" length="4">00000000</add_on_unique_id23>
  <add_on_unique_id24 type="hexBinary" length="4">00000000</add_on_unique_id24>
  <add_on_unique_id25 type="hexBinary" length="4">00000000</add_on_unique_id25>
  <add_on_unique_id26 type="hexBinary" length="4">00000000</add_on_unique_id26>
  <add_on_unique_id27 type="hexBinary" length="4">00000000</add_on_unique_id27>
  <add_on_unique_id28 type="hexBinary" length="4">00000000</add_on_unique_id28>
  <add_on_unique_id29 type="hexBinary" length="4">00000000</add_on_unique_id29>
  <add_on_unique_id30 type="hexBinary" length="4">00000000</add_on_unique_id30>
  <add_on_unique_id31 type="hexBinary" length="4">00000000</add_on_unique_id31>
</menu>
```

| Field group | Purpose |
|-------------|---------|
| `longname_*` / `shortname_*` | Display name per language |
| `publisher_*` | Publisher line per language |
| `product_code` / `company_code` | Product metadata strings |
| `title_id` / `group_id` | Must match `app.xml` |
| `pc_*` | Rating-board flags (technical; `0` = unset in this example) |
| `add_on_unique_id*` | DLC slot IDs (usually all zero) |

### `Featured.xml` / `NewReleases.xml`

Plain list files in `meta/` — not Cafe `app.xml` / `meta.xml`. See [Featured list](#featured-list-1fa82200) and [New releases list](#new-releases-list-1fa82300). Each entry uses a full **`00050002`** demo ID from your install.

---

## AI usage

Cursor was used for spelling fixes and to clarify a few awkward sentences. It also helped document the ffmpeg settings the Wii U accepts for kiosk MP4s, and the XML templates above for readers new to Cafe title files.
