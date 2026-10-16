#!/usr/bin/env python3
"""Split a format-2 map into the PROPOSED format-3 layout (manifest + chunk files)
from docs/research/WORLD_MAP_FF8_FF9.md §3, or merge it back (round-trip check).

Format 3 is not implemented in the game yet. This script exists so the
ChunkStore/ChunkView work (phases 1–2) has real data and a migration path.

split:  python chunk_split.py split <map.json> <out_dir> [--chunk 32] [--default-tile <tile_id>]
   writes <out_dir>/<id>.json (manifest, format 3) and <out_dir>/<id>/chunks/<cx>_<cy>.json
   Chunks made only of the default tile are omitted (ocean fallback).
   Tiles, details and particles move to chunks (local "x,y" keys); objects, spawns,
   regions, anchors, gameplay overrides, cables, post, ambient stay in the manifest.
merge:  python chunk_split.py merge <manifest.json> <chunks_root_dir> <out.json>
   rebuilds a format-2 map; diff it against the original to prove the split is lossless.

The manifest's streaming.dir is written as "data/maps/<id>/chunks" (repo-relative), so
copy <out_dir> contents into data/maps/ when you adopt it.
"""
import json, os, sys

def jload(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)

def split(src, out_dir, cs, default_tile):
    d = jload(src)
    if int(d.get("format", 1)) != 2:
        print("only format-2 maps can be split", file=sys.stderr)
        return 2
    mid = d["id"]
    chunks = {}
    for k, stack in d.get("tiles", {}).items():
        x, y = (int(v) for v in k.split(","))
        key = (x // cs, y // cs)
        chunks.setdefault(key, {"tiles": {}, "details": [], "particles": {}})["tiles"][f"{x % cs},{y % cs}"] = stack
    for k, stack in d.get("particles", {}).items():
        x, y = (int(v) for v in k.split(","))
        chunks.setdefault((x // cs, y // cs), {"tiles": {}, "details": [], "particles": {}})["particles"][f"{x % cs},{y % cs}"] = stack
    tw, th = float(d.get("tile_width", 128)), float(d.get("tile_height", 64))
    for det in d.get("details", []):
        # details are free-placed in screen space; we bucket by their cell if present, else (0,0)
        cell = det.get("cell") or [0, 0]
        chunks.setdefault((int(cell[0]) // cs, int(cell[1]) // cs), {"tiles": {}, "details": [], "particles": {}})["details"].append(det)
    cdir = os.path.join(out_dir, mid, "chunks")
    os.makedirs(cdir, exist_ok=True)
    written = skipped = 0
    for (cx, cy), c in sorted(chunks.items()):
        only_default = default_tile and not c["details"] and not c["particles"] and all(
            len(s) == 1 and str(s[0][1]) == default_tile and int(s[0][0]) == 0 for s in c["tiles"].values())
        if only_default and len(c["tiles"]) == cs * cs:
            skipped += 1
            continue
        with open(os.path.join(cdir, f"{cx}_{cy}.json"), "w", encoding="utf-8") as f:
            json.dump({"chunk": [cx, cy], **c}, f, separators=(",", ":"))
        written += 1
    man = {k: v for k, v in d.items() if k not in ("tiles", "particles", "details")}
    man["format"] = 3
    man["streaming"] = {"chunk_size": cs, "dir": f"data/maps/{mid}/chunks", "default_tile": default_tile or ""}
    with open(os.path.join(out_dir, f"{mid}.json"), "w", encoding="utf-8") as f:
        json.dump(man, f, indent="\t")
    print(f"{mid}: {written} chunk files, {skipped} default-only chunks omitted, manifest {out_dir}/{mid}.json")
    return 0

def merge(man_path, chunks_root, out):
    m = jload(man_path)
    st = m.get("streaming", {})
    cs = int(st.get("chunk_size", 32))
    cdir = os.path.join(chunks_root, m["id"], "chunks") if os.path.isdir(os.path.join(chunks_root, m["id"])) else chunks_root
    tiles, parts, dets = {}, {}, []
    present = set()
    for f in os.listdir(cdir):
        if not f.endswith(".json"):
            continue
        c = jload(os.path.join(cdir, f))
        cx, cy = c["chunk"]
        present.add((cx, cy))
        for k, s in c.get("tiles", {}).items():
            lx, ly = (int(v) for v in k.split(","))
            tiles[f"{cx * cs + lx},{cy * cs + ly}"] = s
        for k, s in c.get("particles", {}).items():
            lx, ly = (int(v) for v in k.split(","))
            parts[f"{cx * cs + lx},{cy * cs + ly}"] = s
        dets += c.get("details", [])
    dt = st.get("default_tile", "")
    if dt:
        for cy in range((int(m["depth"]) + cs - 1) // cs):
            for cx in range((int(m["width"]) + cs - 1) // cs):
                if (cx, cy) not in present:
                    for y in range(cy * cs, min((cy + 1) * cs, int(m["depth"]))):
                        for x in range(cx * cs, min((cx + 1) * cs, int(m["width"]))):
                            tiles[f"{x},{y}"] = [[0, dt]]
    out_d = {k: v for k, v in m.items() if k != "streaming"}
    out_d.update({"format": 2, "tiles": dict(sorted(tiles.items(), key=lambda kv: (int(kv[0].split(',')[1]), int(kv[0].split(',')[0])))),
                  "particles": parts, "details": dets})
    with open(out, "w", encoding="utf-8") as f:
        json.dump(out_d, f, indent="\t")
    print(f"merged {len(tiles)} cells -> {out}")
    return 0

if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) >= 3 and a[0] == "split":
        cs = int(a[a.index("--chunk") + 1]) if "--chunk" in a else 32
        dt = a[a.index("--default-tile") + 1] if "--default-tile" in a else ""
        sys.exit(split(a[1], a[2], cs, dt))
    if len(a) >= 4 and a[0] == "merge":
        sys.exit(merge(a[1], a[2], a[3]))
    print(__doc__)
    sys.exit(2)
