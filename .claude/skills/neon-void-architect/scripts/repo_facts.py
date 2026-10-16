#!/usr/bin/env python3
"""Print the live facts of a Beyond The Neon Void checkout so Claude works from
the repo, not from memory: Godot version, autoload order, ContentDB buckets,
data counts, maps (format/kind/size), missions graph, test entry points.

Usage:  python repo_facts.py [repo_root]        (Windows: py -3 repo_facts.py .)
Read-only.
"""
import json, os, re, sys

def load(p):
    try:
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:  # noqa: BLE001
        return {"_error": str(e)}

def count(v):
    if isinstance(v, list):
        return len(v)
    if isinstance(v, dict):
        return len([k for k in v if not k.startswith("_")])
    return "?"

def main() -> int:
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
    pg = os.path.join(root, "project.godot")
    if not os.path.isfile(pg):
        print(f"no project.godot in {root}", file=sys.stderr)
        return 2
    txt = open(pg, encoding="utf-8").read()
    feat = re.search(r'config/features=PackedStringArray\(([^)]*)\)', txt)
    print("== project.godot")
    print("  features:", feat.group(1) if feat else "?")
    for key in ("run/main_scene", "viewport/hdr_2d", "textures/canvas_textures/default_texture_filter",
                "window/size/viewport_width", "window/size/viewport_height", "window/stretch/mode"):
        m = re.search(re.escape(key) + r"=(.*)", txt)
        print(f"  {key} = {m.group(1) if m else '-'}")
    auto = re.search(r"\[autoload\](.*?)(\n\[|\Z)", txt, re.S)
    print("== autoloads (order matters)")
    if auto:
        for i, line in enumerate([l for l in auto.group(1).strip().splitlines() if "=" in l], 1):
            k, v = line.split("=", 1)
            print(f"  {i:2}. {k.strip():18} {v.strip().strip(chr(34)).lstrip('*')}")
    cdb = os.path.join(root, "src", "autoload", "content_db.gd")
    if os.path.isfile(cdb):
        c = open(cdb, encoding="utf-8").read()
        cat = re.search(r"var CATALOG := \{(.*?)\}", c, re.S)
        if cat:
            print("== ContentDB typed buckets:", ", ".join(re.findall(r'"(\w+)"', cat.group(1))))
    data = os.path.join(root, "data")
    print("== data/*.json entry counts")
    for f in sorted(os.listdir(data)):
        if f.endswith(".json"):
            d = load(os.path.join(data, f))
            extra = ""
            if f == "vfx.json" and isinstance(d, dict):
                extra = f"  (effects {count(d.get('effects', {}))})"
            print(f"  {f:24} {count(d)}{extra}")
    md = os.path.join(data, "maps")
    if os.path.isdir(md):
        print("== data/maps")
        for f in sorted(os.listdir(md)):
            if f.endswith(".json"):
                d = load(os.path.join(md, f))
                print(f"  {f:28} format={d.get('format', 1)} kind={d.get('kind', '-')} size={d.get('width')}x{d.get('depth')} "
                      f"tile={d.get('tile_width')}x{d.get('tile_height')} regions={len(d.get('regions', []))} anchors={len(d.get('anchors', []))}")
    ms = load(os.path.join(data, "missions.json"))
    if isinstance(ms, list):
        print("== missions (id -> map | win | unlocks)")
        for m in ms:
            print(f"  {m['id']:22} {m.get('map_id', ''):20} {m.get('win_condition', 'defeat_all'):14} -> {m.get('unlocks_mission_ids', [])}")
    print("== tests:", ", ".join(sorted(f for f in os.listdir(os.path.join(root, "tests")) if f.endswith(".gd"))))
    return 0

if __name__ == "__main__":
    sys.exit(main())
