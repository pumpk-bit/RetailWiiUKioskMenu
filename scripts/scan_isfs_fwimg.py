"""Scan stripped Wii U SLC for ISFS superblocks and fw.img FST entries."""
from __future__ import annotations

import struct
import sys
from pathlib import Path

CLUSTER_SIZE = 0x4000
CLUSTER_COUNT = 0x8000
SUPER_CLUSTERS = 0x10
SUPER_COUNT = 64
FST_ENTRY_SIZE = 0x20
ISFSHAX_GEN = 0xFFFF7FFF
TARGET = "/sys/title/00050010/1000400a/code/fw.img"


def super_cluster(index: int) -> int:
    return CLUSTER_COUNT - (SUPER_COUNT - index) * SUPER_CLUSTERS


def parse_super(data: bytes, index: int) -> dict | None:
    cluster = super_cluster(index)
    off = cluster * CLUSTER_SIZE
    if off + CLUSTER_SIZE > len(data):
        return None
    hdr = data[off : off + 12]
    magic = hdr[:4]
    if magic not in (b"SFFS", b"SFS!"):
        return None
    generation = struct.unpack(">I", hdr[4:8])[0]
    version = 0 if magic == b"SFFS" else 1
    fst_base = off + 0x10000 + 0x0C
    return {
        "index": index,
        "cluster": cluster,
        "offset": off,
        "magic": magic.decode(),
        "generation": generation,
        "version": version,
        "fst_base": fst_base,
    }


def read_fst_entry(data: bytes, fst_base: int, idx: int) -> dict:
    off = fst_base + idx * FST_ENTRY_SIZE
    raw = data[off : off + FST_ENTRY_SIZE]
    name = raw[:12].split(b"\x00", 1)[0].decode("ascii", "ignore")
    mode = raw[12]
    sub, sib = struct.unpack(">HH", raw[14:18])
    size = struct.unpack(">I", raw[18:22])[0]
    return {"idx": idx, "name": name, "mode": mode, "sub": sub, "sib": sib, "size": size}


def find_path(data: bytes, fst_base: int, path: str) -> dict | None:
    parts = [p for p in path.strip("/").split("/") if p]
    root = read_fst_entry(data, fst_base, 0)
    next_idx = root["sub"]
    for part in parts:
        if next_idx == 0xFFFF:
            return None
        found = None
        while next_idx != 0xFFFF:
            ent = read_fst_entry(data, fst_base, next_idx)
            if ent["name"] == part:
                found = ent
                break
            next_idx = ent["sib"]
        if not found:
            return None
        next_idx = found["sub"]
    return found


def scan(path: Path) -> None:
    data = path.read_bytes()
    print(f"\n=== {path.name} ({len(data)} bytes) ===")
    supers = []
    for i in range(SUPER_COUNT):
        s = parse_super(data, i)
        if s:
            supers.append(s)
    if not supers:
        print("No superblocks found")
        return
    usable = [s for s in supers if s["generation"] < ISFSHAX_GEN]
    usable.sort(key=lambda s: s["generation"], reverse=True)
    print(f"Found {len(supers)} super slots; newest usable gen=0x{usable[0]['generation']:08X} idx={usable[0]['index']}")
    for s in usable[:5]:
        hit = find_path(data, s["fst_base"], TARGET)
        code_dir = find_path(data, s["fst_base"], "/sys/title/00050010/1000400a/code")
        title_dir = find_path(data, s["fst_base"], "/sys/title/00050010/1000400a")
        print(
            f"  super[{s['index']}] gen=0x{s['generation']:08X} magic={s['magic']} "
            f"fw.img={'YES size='+str(hit['size']) if hit else 'NO'} "
            f"code_dir={'YES' if code_dir else 'NO'} "
            f"title={'YES' if title_dir else 'NO'}"
        )


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: py -3 scan_isfs_fwimg.py <stripped_slc.bin> [...]", file=sys.stderr)
        sys.exit(2)
    for arg in sys.argv[1:]:
        scan(Path(arg))
