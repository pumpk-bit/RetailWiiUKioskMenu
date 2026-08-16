# Mutant overlay (local — not in git)

After `build_mutant_slc.ps1`:

```
overlay/mutant/slc/
```

Gitignored until you build. This repo does not ship dumps, certs, or tickets.

| Path | Role |
|------|------|
| `overlay/mutant/slc/` | Mutant SLC rights (`build_mutant_slc.ps1`) |
| `overlay/mutant/mlc/sys/title/00050030/<id>/` | Retail-compatible kiosk HBM (`build_kiosk_hbm_mlc.ps1`) — **lab / redNAND only** |
| Live replace | `apply_kiosk_hbm_ftp.ps1` (FTP backup → patch → verify → upload → orphan delete → remote hash check) |

| File | Change |
|------|--------|
| `cert.sys` | Retail + kiosk chains |
| `ticket/**/*.tik` | Kiosk tickets (including overwrite of same-path retail files) |
| `title.list` | Combined IDs |
| `sys_prod.xml` | **WIS-001** / **FW** (region/serial stay retail) — do not Submit to WiiUIdent |
| `system.xml` | Home Menu coldboot + kiosk policy fields (built; **not** FTP'd unless you answer **Y**) |
| `system.xml.kioskboot` | Coldboot → native SCT (`swap_coldboot_ftp.ps1 -Mode sct`) — **synthesized** from merged `system.xml` |
| `system.xml.kioskmenu` | Coldboot → Kiosk Menu (`-Mode kioskmenu`; trap risk) — **synthesized** |

**`apply_mutant_slc_ftp.ps1`** always uploads certs, title.list, sys_prod, additive tickets, and **overwrites Kiosk Menu + native SCT `.tik`** (retail already has those paths). It then asks **Y/N** to upload `system.xml` (**default N** — could cause instability). Pass **`-ApplySystemXml`** to upload without the prompt. **`-FullKioskPolicy`** also uploads eco/prefs.

If SCT/Kiosk Menu still say *Cannot launch this title* after an older apply, run `.\scripts\force_kiosk_launch_tickets_ftp.ps1` — see [PROBLEMS.md](../docs/AI/PROBLEMS.md#cannot-launch-this-title-sct-or-kiosk-menu). Adding demos: [NEWDEMOS.MD](../docs/AI/NEWDEMOS.MD).

Scripts check required files exist before any FTP write and ask **Y/N** for every live SLC change.

Next: follow [docs/AI/SYSNAND.md](../docs/AI/SYSNAND.md).
