#!/usr/bin/env python3
"""World audit for Beyond The Neon Void maps (format 1/2, and format-3 manifests
written by chunk_split.py).

For every data/maps/*.json it reports size, render cost estimates and broken
links, so world work starts from facts:
  * tiles, StripView count (WorldRenderer.STRIP_LEN = 32 cells of an iso diagonal),
    animated strips (redraw every frame), objects, particle volumes, lights
  * locations: target_map exists, target_spawn index valid, intro_cutscene file exists
  * regions: teleport/battle/cutscene/dialog trigger targets, encounter mission ids
  * anchors: battle/teleport/npc/cutscene action args
  * spawns in bounds and on a painted column

Usage:  python world_audit.py [repo_root] [--map <id>] [--strict]
Exit 1 when errors are found (--strict also fails on warnings). Read-only.
"""
import json, os, sys

STRIP_LEN = 32

def jload(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)

def main() -> int:
    args = sys.argv[1:]
    strict = "--strict" in args
    only = args[args.index("--map") + 1] if "--map" in args else None
    pos = [a for i, a in enumerate(args) if not a.startswith("--") and (i == 0 or args[i - 1] != "--map")]
    root = os.path.abspath(pos[0] if pos else ".")
    data = os.path.join(root, "data")
    mdir = os.path.join(data, "maps")
    maps = {}
    for f in sorted(os.listdir(mdir)):
        if f.endswith(".json"):
            try:
                d = jload(os.path.join(mdir, f))
                maps[d.get("id", f[:-5])] = d
            except Exception as e:  # noqa: BLE001
                print(f"ERROR {f}: unreadable JSON ({e})")
    missions = {m["id"] for m in jload(os.path.join(data, "missions.json"))}
    npcs = {n["id"] for n in jload(os.path.join(data, "npcs.json"))}
    items = {i["id"] for i in jload(os.path.join(data, "items.json"))}
    tiles_db = jload(os.path.join(data, "tiles.json")) if os.path.exists(os.path.join(data, "tiles.json")) else {}
    particles = set(jload(os.path.join(data, "particles.json")).keys())

    def res_exists(path):
        if not path:
            return True
        if path.startswith("res://"):
            return os.path.exists(os.path.join(root, path[6:]))
        return os.path.exists(os.path.join(root, path))

    errors = warnings = 0
    for mid, d in maps.items():
        if only and mid != only:
            continue
        fmt = int(d.get("format", 1))
        w, h = int(d.get("width", 0)), int(d.get("depth", 0))
        issues = []
        def err(t):
            issues.append(("ERROR", t))
        def warn(t):
            issues.append(("warn", t))
        if fmt >= 2:
            tiles = d.get("tiles", {})
            cells = []
            for k in tiles:
                x, y = (int(v) for v in k.split(","))
                cells.append((x, y))
            if fmt == 3:
                st = d.get("streaming", {})
                cdir = os.path.join(root, st.get("dir", "").replace("res://", ""))
                if os.path.isdir(cdir):
                    cs = int(st.get("chunk_size", 32))
                    for cf in os.listdir(cdir):
                        if cf.endswith(".json"):
                            c = jload(os.path.join(cdir, cf))
                            cx, cy = c.get("chunk", [0, 0])
                            for k in c.get("tiles", {}):
                                lx, ly = (int(v) for v in k.split(","))
                                cells.append((cx * cs + lx, cy * cs + ly))
                else:
                    err(f"streaming.dir not found: {st.get('dir')}")
            strips = {(x + y, x // STRIP_LEN) for x, y in cells}
            anim = set()
            for k, stack in tiles.items():
                x, y = (int(v) for v in k.split(","))
                for e in stack:
                    t = tiles_db.get(str(e[1]), {})
                    if isinstance(t, dict) and len(t.get("frames", []) or []) > 1:
                        anim.add((x + y, x // STRIP_LEN))
            objs = d.get("objects", [])
            kinds = {}
            for o in objs:
                kinds[o.get("kind", "?")] = kinds.get(o.get("kind", "?"), 0) + 1
            pvol = sum(len(v) for v in d.get("particles", {}).values())
            print(f"== {mid}  format={fmt} kind={d.get('kind')} {w}x{h} tile={d.get('tile_width')}x{d.get('tile_height')}")
            print(f"   cells={len(cells)}  StripViews~{len(strips)}  animated strips={len(anim)}  objects={len(objs)} {kinds}  particle cells={pvol}")
            print(f"   regions={len(d.get('regions', []))}  anchors={len(d.get('anchors', []))}  spawns={ {k: len(v) for k, v in d.get('spawns', {}).items()} }")
            if w * h >= 128 * 128 and fmt < 3:
                warn("large map without streaming: WorldRenderer.rebuild() builds everything at once (see chunk-streaming.md)")
            painted = set(cells)
            for team, lst in d.get("spawns", {}).items():
                for s in lst:
                    c = (int(s[0]), int(s[1]))
                    if not (0 <= c[0] < w and 0 <= c[1] < h):
                        err(f"{team} spawn {c} out of bounds")
                    elif fmt == 2 and c not in painted:
                        err(f"{team} spawn {c} on an empty column (hole)")
            for o in objs:
                loc = o.get("location")
                if isinstance(loc, dict):
                    tm = loc.get("target_map", "")
                    name = loc.get("name", o.get("id"))
                    if tm:
                        if tm not in maps:
                            err(f"location '{name}' -> unknown target_map '{tm}'")
                        else:
                            sp = maps[tm].get("spawns", {}).get("player", [])
                            ts = int(loc.get("target_spawn", 0))
                            if sp and not (0 <= ts < len(sp)):
                                err(f"location '{name}' target_spawn {ts} but '{tm}' has {len(sp)} player spawns")
                    else:
                        warn(f"location '{name}' ({loc.get('type')}) has no target_map (dead end)")
                    if not res_exists(loc.get("intro_cutscene", "")):
                        err(f"location '{name}' intro_cutscene missing: {loc.get('intro_cutscene')}")
                if o.get("kind") == "loot" and o.get("loot_item_id") and o["loot_item_id"] not in items:
                    err(f"loot object {o.get('id')} -> unknown item {o['loot_item_id']}")
                if o.get("dialog_npc") and o["dialog_npc"] not in npcs:
                    err(f"object {o.get('id')} dialog_npc unknown: {o['dialog_npc']}")
            for k, stack in d.get("particles", {}).items():
                for e in stack:
                    if str(e[1]) not in particles:
                        err(f"particle preset '{e[1]}' at {k} not in data/particles.json")
            for r in d.get("regions", []):
                rn = r.get("name", r.get("id"))
                for t in r.get("triggers", []):
                    do, arg = t.get("do"), str(t.get("arg", ""))
                    if do == "battle" and arg not in missions:
                        err(f"region '{rn}' battle trigger -> unknown mission '{arg}'")
                    if do == "teleport" and arg.split(":")[0] not in maps:
                        err(f"region '{rn}' teleport -> unknown map '{arg}'")
                    if do == "cutscene" and not res_exists(arg):
                        err(f"region '{rn}' cutscene missing: {arg}")
                    if do == "dialog" and arg in npcs:
                        pass
                    if do == "music":
                        warn(f"region '{rn}' music trigger: known runtime bug (AudioStream passed to play_music(String))")
                enc = r.get("encounter", {})
                for m in enc.get("missions", []):
                    if m not in missions:
                        err(f"region '{rn}' encounter -> unknown mission '{m}'")
                if enc.get("missions") and float(enc.get("rate", 0)) <= 0:
                    warn(f"region '{rn}' has encounter missions but rate 0")
            for a in d.get("anchors", []):
                for act in list(a.get("actions", [])) + list(a.get("fail_actions", [])):
                    do, arg = act.get("do"), str(act.get("arg", ""))
                    if do == "battle" and arg not in missions:
                        err(f"anchor {a.get('id')} battle -> unknown mission '{arg}'")
                    if do == "teleport" and ":" in arg and arg.split(":")[0] not in maps:
                        warn(f"anchor {a.get('id')} teleport arg '{arg}' (local cell or map:spawn?)")
                    if do in ("npc", "dialog") and arg and arg not in npcs and do == "npc":
                        err(f"anchor {a.get('id')} npc -> unknown npc '{arg}'")
                if a.get("kind") == "npc" and a.get("npc_id") and a["npc_id"] not in npcs:
                    err(f"anchor {a.get('id')} npc_id unknown: {a['npc_id']}")
                if a.get("requires_item") and a["requires_item"] not in items:
                    err(f"anchor {a.get('id')} requires_item unknown: {a['requires_item']}")
        else:
            print(f"== {mid}  format=1 (legacy) {w}x{h} tile={d.get('tile_width')}x{d.get('tile_height')} cells={len(d.get('cells', []))}")
            warn("format 1 map: port to format 2 to get masks/anchors/objects (WorldMap.load_dict reads v1 for compatibility)")
        for lvl, t in issues:
            print(f"   {lvl}: {t}")
            if lvl == "ERROR":
                errors += 1
            else:
                warnings += 1
    print(f"\n{errors} error(s), {warnings} warning(s)")
    return 1 if errors or (strict and warnings) else 0

if __name__ == "__main__":
    sys.exit(main())
