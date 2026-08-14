# Mutant overlay (local — not in git)

After `build_mutant_slc.ps1`:

```
overlay/mutant/slc/
```

Gitignored until you build. This repo does not ship dumps, certs, or tickets.

| File | Change |
|------|--------|
| `cert.sys` | Retail + kiosk chains |
| `ticket/**/*.tik` | New kiosk tickets only |
| `title.list` | Combined IDs |
| `sys_prod.xml` | **WIS-001** / **FW** (region/serial stay retail) — do not Submit to WiiUIdent |
| `system.xml` | Home Menu coldboot + kiosk policy fields (built; **not** FTP'd unless you answer **Y**) |
| `system.xml.kioskboot` | Coldboot → native SCT (`swap_coldboot_ftp.ps1 -Mode sct`) |
| `system.xml.kioskmenu` | Coldboot → Kiosk Menu (`-Mode kioskmenu`; trap risk) |

**`apply_mutant_slc_ftp.ps1`** always uploads certs, title.list, sys_prod, and additive tickets. It then asks **Y/N** to upload `system.xml` (**default N** — could cause instability). Pass **`-ApplySystemXml`** to upload without the prompt. **`-FullKioskPolicy`** also uploads eco/prefs.

**Launch tickets:** additive apply skips paths already on live SLC. If SCT/Kiosk Menu say *Cannot launch this title*, see [README troubleshooting](../README.md#cannot-launch-this-title-sct-or-kiosk-menu). For other apps/demos see [Adding tickets](../README.md#adding-tickets-for-more-apps-demos-kiosk-titles).

Scripts check required files exist before any FTP write and ask **Y/N** for every live SLC change.

Next: follow [docs/REDNAND.md](../docs/REDNAND.md) or [docs/SYSNAND.md](../docs/SYSNAND.md).
