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
| `system.xml` | Home Menu default + kiosk policy |

`apply_mutant_slc_ftp.ps1` checks these files exist before any FTP write and asks **Y/N** for every live SLC change.

Next: follow [docs/REDNAND.md](../docs/REDNAND.md) or [docs/SYSNAND.md](../docs/SYSNAND.md).
