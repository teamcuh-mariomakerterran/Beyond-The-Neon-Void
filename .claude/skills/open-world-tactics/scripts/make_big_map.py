#!/usr/bin/env python3
"""Generate a synthetic format-2 world map for streaming / perf tests.

Writes ONE json file (default: ./perf_world_<size>.json). It never touches data/
unless you pass an --out path inside it on purpose. Use it to measure
WorldRenderer.rebuild() today and the ChunkView/streaming work later.

Terrain is drawn with "terrain:<id>" tile ids (the renderer draws those as
colour blocks from data/terrain.json, so no art is needed):
  ocean ring = terrain:water (unwalkable deep water, if present in terrain.json),
  land = terrain:concrete / terrain:rubble / terrain:metal_grate with noise hills,
  a road cross, sparse locations every ~64 cells (kind "location", no target).

Usage:
  python make_big_map.py --size 512 --out perf_world_512.json [--id perf_world_512] [--seed 7] [--land 0.6]
"""
import argparse, json, math, random

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--out", default=None)
    ap.add_argument("--id", default=None)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--land", type=float, default=0.6, help="fraction of the map radius that is land")
    ap.add_argument("--tile-width", type=int, default=128)
    a = ap.parse_args()
    n = a.size
    mid = a.id or f"perf_world_{n}"
    out = a.out or f"{mid}.json"
    rng = random.Random(a.seed)
    # cheap value noise
    g = 16
    grid = [[rng.random() for _ in range(n // g + 2)] for _ in range(n // g + 2)]
    def noise(x, y):
        gx, gy = x / g, y / g
        x0, y0 = int(gx), int(gy)
        fx, fy = gx - x0, gy - y0
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a0 = grid[y0][x0] * (1 - sx) + grid[y0][x0 + 1] * sx
        b0 = grid[y0 + 1][x0] * (1 - sx) + grid[y0 + 1][x0 + 1] * sx
        return a0 * (1 - sy) + b0 * sy
    tiles = {}
    c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            r = math.hypot(x - c, y - c) / c
            v = noise(x, y)
            if r > a.land + (v - 0.5) * 0.25:
                tiles[f"{x},{y}"] = [[0, "terrain:water"]]
                continue
            road = abs(x - n // 2) <= 1 or abs(y - n // 2) <= 1
            h = 0 if road else int(max(0, (v - 0.55) * 10))
            t = "terrain:metal_grate" if road else ("terrain:rubble" if v > 0.7 else "terrain:concrete")
            tiles[f"{x},{y}"] = [[h, t]]
    objects = []
    k = 0
    for y in range(32, n, 64):
        for x in range(32, n, 64):
            if tiles.get(f"{x},{y}", [[0, "terrain:water"]])[0][1] != "terrain:water":
                k += 1
                objects.append({"id": f"obj_{k}", "asset": "", "cell": [x, y], "z": tiles[f"{x},{y}"][0][0],
                                "kind": "location", "location": {"type": "poi", "name": f"POI {k}", "target_map": "",
                                "target_spawn": 0, "intro_cutscene": "", "discovered": False, "radius": 1.5}})
    w = a.tile_width
    d = {"format": 2, "id": mid, "name": f"Perf World {n}", "kind": "world", "width": n, "depth": n,
         "tile_width": w, "tile_height": w // 2, "height_step": w // 4, "tiles": tiles, "details": [],
         "particles": {}, "objects": objects, "spawns": {"player": [[n // 2, n // 2]], "enemy": []}, "gameplay": {}}
    with open(out, "w", encoding="utf-8") as f:
        json.dump(d, f, separators=(",", ":"))
    print(f"wrote {out}: {n}x{n}, {len(tiles)} cells, {len(objects)} locations")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
