"""Scan all non-ISFShax ISFS supers for fw.img path walk."""
from __future__ import annotations

import sys
from pathlib import Path

from scan_isfs_fwimg import (
    ISFSHAX_GEN,
    TARGET,
    find_path,
    parse_super,
    read_fst_entry,
)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: py -3 scan_isfs_all_supers.py <stripped_slc.bin> [...]", file=sys.stderr)
        sys.exit(2)

    for path_str in sys.argv[1:]:
        path = Path(path_str)
        if not path.exists():
            print(f"skip missing {path}")
            continue
        data = path.read_bytes()
        print(f"\n=== {path.name} ===")
        hits = 0
        best = None
        for i in range(64):
            s = parse_super(data, i)
            if not s or s["generation"] >= ISFSHAX_GEN:
                continue
            if best is None or s["generation"] > best["generation"]:
                best = s
            hit = find_path(data, s["fst_base"], TARGET)
            if hit:
                hits += 1
                print(
                    f"  super[{s['index']}] gen=0x{s['generation']:08X} "
                    f"fw.img YES size={hit['size']}"
                )
        if not hits:
            if not best:
                print("  no usable supers")
                continue
            print(
                f"  NO super has walkable path; minute picks gen=0x{best['generation']:08X} "
                f"(idx {best['index']})"
            )
            fb = best["fst_base"]
            orphans = []
            for idx in range(4096):
                e = read_fst_entry(data, fb, idx)
                if e["name"] == "fw.img" and e["size"] > 0:
                    orphans.append((idx, e["size"]))
            print(f"  orphan fw.img entries in active super: {orphans[:5]}")
        else:
            print(f"  {hits} supers have walkable fw.img path")


if __name__ == "__main__":
    main()
