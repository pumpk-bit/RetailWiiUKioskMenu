# System Config Tool — menu map

How **System Config Tool** (SCT) looks on-screen. Use this when launching **Kiosk Menu**, or when hunting a setting.

**Retail / homebrew SCT on Home Menu** (`13374454` — normal Home icon):

![System Config Tool tile on Wii U Home Menu](RetailSystemConfigTool.png)

Native kiosk SCT (`1f700500`) does **not** appear as a Home tile. Open it via coldboot SCT, or use retail SCT from Home. Launch steps: [README — System Config Tool](../../README.md#system-config-tool).

### Conventions

| Markup | Meaning |
|--------|---------|
| `<…>` | Value you can change (region, language, on/off, …) |
| `[…]` | On-screen button / action (e.g. `[Erase]`, `[Reset to default]`) |
| `>>` | Opens another screen — linked to that section |

Header line (example):

```text
System Config Tool ver.X.XX.X		Sys X.X.X : WUP : OS [NAND]
```

---

## Root of the main screen

| Field | Options |
|-------|---------|
| Calendar | `<The Time>` |
| Game Region | `<Region Code>` |
| Platform Region | `<Region Code>` |
| Language | `<Language>` |
| Country | `<Country>` |

---

## Main menu

### Everyday settings

- [Title Launcher >>](#title-launcher)
- [Data Manager >>](#data-manager)
- [Account Manager >>](#account-manager)
- [Display and Audio >>](#display-and-audio)
- [Wii U GamePad (DRC) Setting >>](#wii-u-gamepad-drc-setting)
- [Wii Remote and Sensor Bar >>](#wii-remote-and-sensor-bar)
- [Network Setting >>](#network-setting)
- [Parental Control Setting >>](#parental-control-setting)
- [Spot Pass Setting >>](#spot-pass-setting)
- [Eula >>](#eula)
- [Other Setting >>](#other-setting) 

### Diagnostics / info

- [Boot Configuration >>](#boot-configuration)
- [Test Setting >>](#test-setting) 
- [System Titles Viewer >>](#system-titles-viewer)
- [System Log Viewer >>](#system-log-viewer)
- [Crash Logs Viewer >>](#crash-log-viewer)
- [Console Event Viewer >>](#console-event-viewer)
- [System Hardware Information >>](#system-hardware-information)
- [Software Version Information >>](#software-version-information)

### System actions

- [Update System >>](#update-system)
- [Format System](#format-system)
- [Reboot System](#reboot-system)

---

## Title Launcher

**System NAND memory (mlc)** (also lists other apps and USB drives)

Example row (Kiosk Menu):

```text
<00050010_1fa81000> : Kiosk Menu [mlc1] [Menu]
```

1. Highlight the title → press **A** → [Title Information](#title-information).
2. Confirm fields → press **A** again to launch.

### Title Information

| Field | Example |
|-------|---------|
| Title Name | Kiosk Menu |
| Title Type | Menu |
| Title ID | `<00050010_1fa81000>` |
| … | … |

> **This project:** pick **Kiosk Menu**, confirm **Title Type: Menu**, then launch. See [README — System Config Tool](../../README.md#system-config-tool).

---

## Data Manager

- [Title Manager >>](#title-manager)
- [Save Data Manager >>](#save-data-manager)
- [File System Viewer >>](#file-system-viewer)
- [Format External Storage >>](#format-external-storage)

### Title Manager

| Entry | Notes |
|-------|--------|
| Install >> | Installs content from USB |
| Uninstall >> | Uninstalls content from the system |
| Copy >> | Copies content within the system |
| Move >> | Moves content within the system |
| Initialize Title Version Table >> | Initializes the title version table |

### Save Data Manager

| Entry | Notes |
|-------|--------|
| NAND >> | NAND save data |
| Import from SD card >> | Saves from SD card |
| Fill-up Tool >> | Fill-up tool |
| Move Save Data >> | |
| Copy Save Data >> | |

Also on this screen:

- Create Initial System Application Save Data
- Remove NFC Backup Save Data

### File System Viewer

| Entry | Notes |
|-------|--------|
| SD Card >> | View SD card contents |

### Format External Storage

Format the external storage device (USB drive) to be compatible with the system.

---

## Account Manager

Needs the Account Manager app on the system. SCT is essentially a launcher into that app.

---

## Display and Audio

### DRC

| Setting | Options |
|---------|---------|
| DRC Sound | `<SURROUND/MONO/STEREO>` |

### TV

| Setting | Options |
|---------|---------|
| NTSC/PAL | `<NTSC/PAL>` |
| Connection Mode | `<MANUAL/AUTO>` |
| Video Out | `<HDMI/COMPONENT/S-VIDEO/COMPOSITE/SCART/COMPOSITE>` |
| Resolution | `<480I/480p/576I/720p/1080p/1080I>` |
| Aspect Ratio | `<4:3/16:9>` |
| TV Under Scan | `<0-20>` |
| TV Sound | `<SURROUND/MONO/STEREO>` |
| Audio out | `<HDMI/HDMI + RCA/RCA>` |

---

## Wii U GamePad (DRC) Setting

| Setting | Options / action |
|---------|------------------|
| Firmware Version | `<DRC Firmware Version>` |
| Multi DRC | `<ENABLED/DISABLED>` |
| Pair DRC | Action |
| Restore default mic gain | Action |
| Restore default LCD settings | Action |
| DRC Wifi Diags >> | GamePad Wi‑Fi status |
| DRC Motor mode | `<ON/OFF>` |

---

## Wii Remote and Sensor Bar

| Setting | Options |
|---------|---------|
| Motor Mode | `<ON/OFF>` |
| Sensor Bar Position | `<Upper/Lower>` |
| Pointer Sensitivity | `<1-5>` |
| Speaker Volume | `<0-127>` |
| Clear Pairing Information | Action |

**Connected Controllers** (lists what is connected):

- Chan\[0]
- Chan\[1]
- Chan\[2]
- Chan\[3]

---

## Network Setting

| Entry | Notes |
|-------|--------|
| Select Default Profile | `<Profile 1–6>` |
| Edit Profile >> | Edit the selected network settings |

Profiles:

- Profile 1 >>
- Profile 2 >>
- Profile 3 >>
- Profile 4 >>
- Profile 5 >>
- Profile 6 >>

| Entry | Notes |
|-------|--------|
| Import Profile >> | Import a profile from SD card |
| Export Profile >> | Export a profile to SD card |

### Profile X

| Setting | Options |
|---------|---------|
| Status | `<Valid/Invalid>` |
| Edit Config >> | → [Edit Config](#edit-config) |
| Clear Config | Action |
| Connection Test | Result: `---` |

### Edit Config

| Setting | Options |
|---------|---------|
| Connection Mode | `<Wireless/Wired/Unestablished>` |
| Access Point (AP) Setting >> | → [Access Point (AP) Setting](#access-point-ap-setting) |
| IP Address Obtain Mode | `<DHCP/Sticky/Manual>` |
| IP Address Setting >> | IP / DNS |
| Proxy Setting >> | Use proxy? |
| MTU | `<Value>` |

### Access Point (AP) Setting

| Setting | Options / notes |
|---------|-----------------|
| Config Method | `<Manual/WPS>` |
| Scan >> | Scans for networks |
| Config >> | SSID, Privacy Mode (e.g. WPA), Privacy Key (password) |

---

## Parental Control Setting

| Setting | Options |
|---------|---------|
| Use Parental Control | `<No/Yes>` |
| Pin Code | `<code>` |
| E-Mail Address | `<email address>` |
| Security Question | `<question>` |
| User's Secret Question | `<question>` |
| Secret Answer | `<answer>` |
| Permit to Delete All Parental Settings | `<Allow/Not Allow>` |
| Rating Organization | `<Pegi General/Pegi Finland/…>` |

**For Accounts:**

- Account 1 >> → [Account X](#account-x)
- Account 2 >>
- Account 3 >>
- Account 4 >>
- Account 5 >>
- Account 6 >>
- Account 7 >>
- Account 8 >>
- Account 9 >>
- Account 10 >>
- Account 11 >>
- Account 12 >>

### Account X

| Setting | Options |
|---------|---------|
| Game Rating | `<0–18>` |
| Online Interaction in Games | `<Restricted/Unrestricted>` |
| Internet Browser | `<Restricted/Unrestricted>` |
| Wii U Shopping Services | `<Restricted/Unrestricted>` |
| Miiverse | `<Restricted/Unrestricted>` |
| Friend Registration | `<Restricted/Unrestricted>` |
| Entertainment Excluding Games | `<Restricted/Unrestricted>` |
| Data Management | `<Restricted/Unrestricted>` |
| Internet Settings | `<Restricted/Unrestricted>` |
| Account Modify | `<Restricted/Unrestricted>` |
| Change Country Settings | `<Restricted/Unrestricted>` |
| Nintendo TVii | `<Restricted/Unrestricted>` |
| System Initialization | `<Restricted/Unrestricted>` |

---

## Spot Pass Settings

(On-screen main-menu row may say **Spot Pass Setting**.)

| Setting | Options |
|---------|---------|
| Spot Pass | `<Enable/Disable>` |
| Auto DL application | `<Yes/No>` |

**Upload Console Info & Play History of Account:**

| Account | Options |
|---------|---------|
| Account 1 | `<Allow/Not Allow>` |
| Account 2 | `<Allow/Not Allow>` |
| Account 3 | `<Allow/Not Allow>` |
| Account 4 | `<Allow/Not Allow>` |
| Account 5 | `<Allow/Not Allow>` |
| Account 6 | `<Allow/Not Allow>` |
| Account 7 | `<Allow/Not Allow>` |
| Account 8 | `<Allow/Not Allow>` |
| Account 9 | `<Allow/Not Allow>` |
| Account 10 | `<Allow/Not Allow>` |
| Account 11 | `<Allow/Not Allow>` |
| Account 12 | `<Allow/Not Allow>` |

---

## EULA

EULA Version `XX.XX`

---

## Other Setting

| Setting | Options | Notes |
|---------|---------|--------|
| Spin on Crash | `<Disable/Enable>` | System stays active for COS shell commands |
| Copy Tmp on Crash | `<Disable/Enable>` | |
| Crash Dump Type | `<Full/Mini>` | |
| System Timestamps | `<System+User/System Only/User Only/Disable>` | |
| Detail Crash Log | `<Disable/Enable>` | |
| Crash Recovery | `<Disable/Enable>` | |
| USB Keep-Alive | `<Disable/Enable>` | |
| Debug Flags Setting >> | | → [Debug Flags Setting](#debug-flags-setting) |

**Behavior at the time of no input**

| Setting | Options |
|---------|---------|
| Auto Dimming (after 5min) | `<Use/Not Use>` |
| Auto Power Down | `<Use/Not Use>` |
| Time before powering down | `<1 hour>` |

**Standby Function Settings (Eco mode)**

| Setting | Options |
|---------|---------|
| Enable StandBy Function | `<Enable/Disable>` |
| Standby time (min) | `<Value>` |
| \[Reset to default] | Button |

**For System Config Tool**

| Setting | Options |
|---------|---------|
| Keyboard Type | `<Auto/Keyboard type>` |

### Debug Flags Setting

| Setting | Options |
|---------|---------|
| Synchronous Printing | `<Enable/Disable>` |
| Override Debug Print level | `<LV X>` |
| Process Debug Setting >> | → [Process Debug Setting](#process-debug-setting) |
| Module Debug Setting >> | → [Module Debug Setting](#module-debug-setting) |

### Process Debug Setting

| Setting | Options |
|---------|---------|
| Game Process Debug | `<Enable/Disable>` |
| Cafe Menu Process Debug | `<Enable/Disable>` |
| System Application Debug | `<Enable/Disable>` |
| Overlay Application Debug | `<Enable/Disable>` |

### Module Debug Setting

| Setting | Options |
|---------|---------|
| OS Debug | `<Enable/Disable>` |
| Loader Debug | `<Enable/Disable>` |
| Graphics Debug | `<Enable/Disable>` |
| Sound Debug | `<Enable/Disable>` |
| Filesystem Debug | `<Enable/Disable>` |
| Pads Debug | `<Enable/Disable>` |
| Network Debug | `<Enable/Disable>` |
| USB Debug | `<Enable/Disable>` |
| Video Debug | `<Enable/Disable>` |
| Background Daemon Debug | `<Enable/Disable>` |
| Other Debug | `<Enable/Disable>` |

---

## Boot Configuration

| Setting | Options / notes |
|---------|-----------------|
| System Mode | `<Production Mode/Development Mode>` |
| Memory Size for Application | `<1GB (Production)>` |
| Launch State | `<After Initial Account Setting (Stage 2)>` (boot state) |
| Disc Auto Launch | `<Enable/Disable>` |
| Default Title >> | → [Set Default Title](#set-default-title) |
| Run Application on PC | `<Enable/Disable>` |
| PCFS Port | `<Value>` |

**For CAT-DEV**

| Entry | Notes |
|-------|--------|
| CAT-DEV Disc Auto-Re-Insert | `<Enable/Disable>` |
| Change HostBridge HDD Bank | Action |
| Delete HostBridge HDD Bank | Action |

### Set Default Title

Sets the main menu title for the Wii U.

| Title ID | Name |
|----------|------|
| `<00050010_1fa82100>` | Kiosk Menu |
| `<00050010_1f700500>` | System Config Tool |
| `<00050010_10040200>` | Wii U Menu |

> Do **not** change default boot to Kiosk Menu from SCT **Boot title** unless you accept losing Home/FTP. Prefer `swap_coldboot_ftp.ps1` only after Home → SCT → Kiosk Menu already works. See [PROBLEMS — coldboot trap](../PROBLEMS.md#stuck-in-kiosk-menu-coldboot).

---

## Test Setting

| Setting | Options |
|---------|---------|
| Background Stress Mode | `<Enable/Mode 1 (1GB download)/Mode 2 (Repeat 2.5MB file download)/Mode 3 (1GB file to USB)/Mode 4 (2.5MB file to USB)>` |
| Status | `----` |
| Background Daemon | `<Enable/Disable>` (run in background?) |
| Find USB | `<True/False>` |
| Advance System Time (hour) | `<Value>` |
| Network Update Check | `<Enable/Disable>` |

---

## System Titles Viewer

Browse titles on **MLC**, **USB**, and **SLC**.

---

## System Log Viewer

- Current System Log >>
- Previous System Log >>

---

## Crash Log Viewer

(On-screen main-menu row may say **Crash Logs Viewer**.)

- Crash Log #X >> (open that log)

---

## Console Event Viewer

- System Event >>
- Error Event >>
- \[Delete All Event Log]

---

## System Hardware Information

| Field | |
|-------|--|
| Code ID | |
| Serial ID | |
| Model ID | |
| Hardware Version | |
| WiFi MAC | |
| LAN MAC | |

---

## Software Version Information

**System Config Tool**

- System Config Tool Build SDK Version:
- System Config Tool Ver:

**OS**

- Cafe OS SDK Version:
- OS Version:
- OS Minor Version:

**Boot1**

- Boot1 Version:

**Wii U GamePad**

- Firmware Version:

---

## Update System

Needs an update image.

---

## Format System

Formats the system (as the name says). Destructive — use only if you mean it.

---

## Reboot System

Reboots the console.
