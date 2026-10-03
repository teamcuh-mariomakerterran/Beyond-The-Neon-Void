"""Demo city block built from the animator's real Lattice building clips.

Writes data/maps/neon_block_demo.json: a rainy crossroads lined with animated
buildings (each copy desynced), neon lights at the corners, and the overhead
cable web strung automatically between the roofs.
Run from the repo root: python3 tools/demo/make_block_demo.py
"""
import glob
import json
import os
import random

BUILD_DIR = "assets/incoming/Beyond_TheNeonVoid/animated/buildings"
TW = 128
W = D = 14
random.seed(7)

clips = []
for f in sorted(glob.glob(os.path.join(BUILD_DIR, "*_clip.json"))):
    if "overlay" in f:
        continue
    d = json.load(open(f))
    foot = (d.get("sourceArt") or {}).get("footprint") or {"w": 1, "h": 1}
    if d.get("qaGrade") in ("A-", "A", "A+", "B+") and foot == {"w": 1, "h": 1}:
        bb = d["buildingBBox"]
        clips.append(("res://" + f, TW / max(bb[2] - bb[0], 1)))
pick = random.sample(clips, min(14, len(clips)))

tiles, objects = {}, []
road = lambda x, y: x in (6, 7) or y in (6, 7)
for x in range(W):
    for y in range(D):
        if road(x, y):
            tiles[f"{x},{y}"] = [[0, "terrain:concrete"]]
        else:
            tiles[f"{x},{y}"] = [[0, "terrain:metal_grate" if (x * 3 + y) % 4 == 0 else "terrain:concrete"]]

n = 0
for x in range(W):
    for y in range(D):
        if road(x, y):
            continue
        frontage = x in (5, 8) or y in (5, 8)
        back = (x in (1, 3, 10, 12) and y in (1, 3, 10, 12))
        if (frontage and random.random() < 0.8) or (back and random.random() < 0.7):
            asset, scale = random.choice(pick)
            objects.append({"id": f"obj_block_{n}", "asset": asset, "cell": [x, y], "z": 0, "offset": [0, 0],
                            "scale": round(scale, 4), "flip": random.random() < 0.3, "layer": 0, "kind": "structure",
                            "anim": None, "loot_item_id": "", "found_text": "", "empty_text": "", "dialog_npc": "",
                            "location": None})
            n += 1

presets = {"neon_pink": ("#ff3fb4", 1.4, 3.0, 0.1), "neon_cyan": ("#3ff6ff", 1.3, 3.0, 0.05),
           "sodium_lamp": ("#ffb347", 1.1, 4.0, 0.0), "broken_tube": ("#d9e8ff", 1.0, 2.0, 0.9)}
for i, (cell, preset) in enumerate([([6, 6], "sodium_lamp"), ([7, 2], "neon_pink"), ([2, 7], "neon_cyan"),
                                    ([7, 11], "neon_pink"), ([11, 6], "neon_cyan"), ([6, 13], "broken_tube")]):
    col, en, rad, fl = presets[preset]
    objects.append({"id": f"obj_block_light_{i}", "asset": "", "cell": cell, "z": 0, "offset": [0, 0], "scale": 1.0,
                    "flip": False, "layer": 0, "kind": "light", "anim": None, "loot_item_id": "", "found_text": "",
                    "empty_text": "", "dialog_npc": "", "location": None,
                    "light": {"preset": preset, "color": col, "energy": en, "radius": rad, "flicker": fl, "height": 1.0}})

particles = {f"{x},{y}": [[6, "neon_rain"]] for x in range(W) for y in range(D) if (x + y) % 2 == 0}
m = {"format": 2, "id": "neon_block_demo", "name": "Demo — Lattice Block", "kind": "city", "width": W, "depth": D,
     "tile_width": TW, "tile_height": TW // 2, "height_step": TW // 4, "ambient": "#7a72b8", "post": "neon_noir",
     "tiles": tiles, "details": [], "particles": particles, "objects": objects,
     "spawns": {"player": [[6, 13]], "enemy": []}, "gameplay": {}}
with open("data/maps/neon_block_demo.json", "w") as f:
    json.dump(m, f, indent="\t")
    f.write("\n")
print("wrote neon_block_demo:", n, "buildings from", len(pick), "clips")
