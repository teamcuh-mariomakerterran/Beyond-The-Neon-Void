"""Builds the two demo maps for the World Painter (format 2).

neon_expanse      world map: coast, grassland, forest, mountains with fog on
                  the peaks, a storm front, a city and a point of interest.
neo_kowloon_hub   the city's inner hub, entered from the world map.

Uses flat colour terrain tiles ("terrain:<id>") until real tile art lands; open
them in Neon Forge ▸ WORLD PAINTER and repaint with god_tiles.
"""
import json, math, random

random.seed(7)


def noise(x, y, s):
    return (math.sin(x * 0.37 + s) + math.sin(y * 0.29 + s * 1.7) + math.sin((x + y) * 0.21 + s * 0.3)) / 3.0


def world():
    W = D = 28
    tiles, particles, objects = {}, {}, []
    for x in range(W):
        for y in range(D):
            n = noise(x, y, 1.3)
            coast = x + y * 0.35
            if coast < 6 + noise(x, y, 4) * 2:
                stack = [[0, "terrain:water"]]
            elif coast < 8:
                stack = [[0, "terrain:sand"]]
            else:
                mountain = max(0.0, (x - 17) * 0.55 + (6 - abs(y - 9)) * 0.45 + n * 2)
                h = int(mountain)
                if h >= 2:
                    stack = [[z, "terrain:rock"] for z in range(h)] + [[h, "terrain:snow" if h >= 6 else "terrain:rock"]]
                    if h >= 4:
                        particles[f"{x},{y}"] = [[h + 1, "fog"]]
                elif n > 0.25:
                    stack = [[0, "terrain:forest"]]
                elif n < -0.45:
                    stack = [[0, "terrain:swamp"]]
                else:
                    stack = [[0, "terrain:grass"]]
                if 20 <= y <= 24 and 12 <= x <= 16:
                    stack = [[-1, "terrain:rock"], [0, "terrain:toxic"]]
            tiles[f"{x},{y}"] = stack
            if 20 <= x <= 27 and 0 <= y <= 5:
                particles.setdefault(f"{x},{y}", []).append([14, "storm_clouds"])
                particles[f"{x},{y}"].append([10, "rain"])
    # Road from the coast to the city.
    for i in range(9, 15):
        tiles[f"{i},14"] = [[0, "terrain:concrete"]]
    objects.append({"id": "obj_neon_expanse_city", "asset": "res://assets/structures/04_casino_facade.png",
                    "cell": [15, 14], "z": 0, "offset": [0, 0], "scale": 0.24, "flip": False, "layer": 0,
                    "kind": "location", "anim": None, "loot_item_id": "", "found_text": "", "empty_text": "",
                    "dialog_npc": "",
                    "location": {"type": "city", "name": "Neo Kowloon Sprawl", "target_map": "neo_kowloon_hub",
                                 "target_spawn": 0, "intro_cutscene": "res://data/cutscenes/demo_supply_works.parallax.json",
                                 "discovered": False, "radius": 1.5}})
    objects.append({"id": "obj_neon_expanse_poi", "asset": "res://assets/structures/13_data_center.png",
                    "cell": [10, 22], "z": 0, "offset": [0, 0], "scale": 0.22, "flip": False, "layer": 0,
                    "kind": "location", "anim": None, "loot_item_id": "", "found_text": "", "empty_text": "",
                    "dialog_npc": "",
                    "location": {"type": "poi", "name": "Dead Server Farm", "target_map": "", "target_spawn": 0,
                                 "intro_cutscene": "", "discovered": False, "radius": 1.5}})
    objects.append({"id": "obj_neon_expanse_cache", "asset": "res://assets/structures/07_fuel_depot.png",
                    "cell": [11, 12], "z": 0, "offset": [0, 0], "scale": 0.12, "flip": False, "layer": 0,
                    "kind": "loot", "anim": None, "loot_item_id": "con_neon_gin",
                    "found_text": "Behind the pumps: a bottle of Neon Gin. Someone's retirement plan.",
                    "empty_text": "Just fumes and regret.", "dialog_npc": "", "location": None})
    # Stardust: no art, no marker, no hint. Unlocks the Sync Blade (LoD homage).
    # Move it to the ~25% point of the real campaign once that map exists.
    objects.append({"id": "obj_neon_expanse_stardust", "asset": "", "cell": [5, 19], "z": 0, "offset": [0, 0],
                    "scale": 1.0, "flip": False, "layer": 0, "kind": "loot", "anim": None,
                    "loot_item_id": "key_stardust",
                    "found_text": "Something glitters between the roots. It hums in time with your pulse. STARDUST.",
                    "empty_text": "Just roots. They hum a little, if you're imagining things.", "dialog_npc": "",
                    "location": None})
    return {"format": 2, "id": "neon_expanse", "name": "The Neon Expanse", "kind": "world", "width": W, "depth": D,
            "tile_width": 128, "tile_height": 64, "height_step": 32, "tiles": tiles, "details": [],
            "particles": particles, "objects": objects, "spawns": {"player": [[9, 13]], "enemy": []}, "gameplay": {}}


def hub():
    W = D = 18
    tiles, objects = {}, []
    for x in range(W):
        for y in range(D):
            street = x in (8, 9) or y in (8, 9)
            if street:
                tiles[f"{x},{y}"] = [[0, "terrain:concrete"]]
            elif (x + y) % 7 == 0:
                tiles[f"{x},{y}"] = [[0, "terrain:metal_grate"]]
            else:
                tiles[f"{x},{y}"] = [[0, "terrain:catwalk"], [1, "terrain:catwalk"]] if (x < 3 and y < 3) else [[0, "terrain:metal_grate" if (x * y) % 5 == 0 else "terrain:concrete"]]
    for i, (asset, cell, name) in enumerate([
        ("27_neon_bar.png", [5, 5], "The Neon Void (bar)"),
        ("09_cyber_bar_transparent.png", [12, 5], "Byte & Barrel"),
        ("26_black_market_stall.png", [5, 12], "Black Market"),
    ]):
        objects.append({"id": f"obj_neo_kowloon_hub_{i}", "asset": "res://assets/structures/" + asset, "cell": cell,
                        "z": 0, "offset": [0, 0], "scale": 0.3, "flip": False, "layer": 0, "kind": "location",
                        "anim": None, "loot_item_id": "", "found_text": "", "empty_text": "", "dialog_npc": "",
                        "location": {"type": "building", "name": name, "target_map": "", "target_spawn": 0,
                                     "intro_cutscene": "", "discovered": True, "radius": 1.5}})
    lights = [([5, 7], "neon_pink"), ([12, 7], "neon_cyan"), ([7, 12], "toxic_glow"), ([9, 9], "sodium_lamp"),
              ([14, 14], "broken_tube"), ([3, 15], "fire")]
    presets = {"neon_pink": ("#ff3fb4", 1.4, 3.0, 0.1), "neon_cyan": ("#3ff6ff", 1.3, 3.0, 0.05),
               "toxic_glow": ("#8dff3f", 1.2, 2.5, 0.15), "sodium_lamp": ("#ffb347", 1.1, 4.0, 0.0),
               "broken_tube": ("#d9e8ff", 1.0, 2.0, 0.9), "fire": ("#ff7a2f", 1.6, 2.5, 0.45)}
    for i, (cell, preset) in enumerate(lights):
        col, en, rad, fl = presets[preset]
        objects.append({"id": f"obj_neo_kowloon_hub_light_{i}", "asset": "", "cell": cell, "z": 0, "offset": [0, 0],
                        "scale": 1.0, "flip": False, "layer": 0, "kind": "light", "anim": None, "loot_item_id": "",
                        "found_text": "", "empty_text": "", "dialog_npc": "", "location": None,
                        "light": {"preset": preset, "color": col, "energy": en, "radius": rad, "flicker": fl, "height": 1.0}})
    particles = {f"{x},{y}": [[6, "neon_rain"]] for x in range(W) for y in range(D) if (x + y) % 2 == 0}
    return {"format": 2, "id": "neo_kowloon_hub", "name": "Neo Kowloon — Street Level", "kind": "hub", "width": W,
            "depth": D, "tile_width": 128, "tile_height": 64, "height_step": 32, "ambient": "#5a5294", "tiles": tiles,
            "details": [], "particles": particles, "objects": objects, "spawns": {"player": [[9, 16]], "enemy": []},
            "gameplay": {}}


for m in (world(), hub()):
    with open(f"data/maps/{m['id']}.json", "w") as f:
        json.dump(m, f, indent="\t")
        f.write("\n")
    print("wrote", m["id"], len(m["tiles"]), "columns")
