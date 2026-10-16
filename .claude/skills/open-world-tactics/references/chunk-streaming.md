# Chunk streaming plan (ROADMAP: "Must come first")

## Where the renderer is today (read `src/world/world_renderer.gd`)
- `WorldRenderer.rebuild()` frees everything, then for **every** cell in `world.tiles` calls `refresh_column(cell)`. It then rebuilds all details, objects, particle volumes and lights.
- **StripView:** one node per `(x+y, floor(x/32))`, i.e. 32 cells of one iso diagonal share a node (`STRIP_LEN = 32`, `strip_key()`). This already cut node count about 32×, so the research doc's "one ColumnView per cell" description is stale.
- An animated StripView (any tile with >1 frame in `data/tiles.json`) runs `_process` with `queue_redraw()` **every frame**. On a mostly-ocean 512² map with an animated ocean tile, that means about 1000 strips redrawing every frame. This is the real cost hotspot, and why the plan wants the ocean as a single shader quad and animated tiles via a `TIME` shader.
- `explore_scene.gd:45-47` adds a 60,000×60,000 `ColorRect` (`z_index -4096`) as backdrop. Replace it with a `CanvasLayer` background or `RenderingServer` clear colour (the project clear colour is already `(0.02,0.01,0.05)`).
- `WorldMap.to_grid()` builds the **whole** battle grid. For streamed exploration you need a grid that is chunk-aware or rebuilt per live area. Exploration uses `grid` for `can_step`, `walk_path` and interactions.

## Measured baseline (box, Godot 4.7.2 headless, 2026-10-07; relative numbers only)
Synthetic maps from `scripts/make_big_map.py` were run through the timing harness below on a copy of the repo:

| Map | `WorldMap.from_dict` | WorldRenderer build (+1 frame) | `to_grid()` | Nodes |
|---|---|---|---|---|
| 256² (65,536 cells) | 137 ms | 1,653 ms | 511 ms | 2,353 |
| 512² (262,144 cells) | 543 ms | **8,550 ms** | **2,070 ms** | 8,762 |

Building the whole map at once is a multi-second hitch at 512². `to_grid()` is also O(map) and must become per-live-area. Re-measure on Brian's PC with a real GPU before setting budgets.

## Budget targets (propose to Brian; measure first)
- **Exploration:** 60 fps at 1080p on Brian's PC with a 512² world. Live 3×3 chunks plus a 5×5 prefetch ring.
- **Rebuild:** ≤ 8 ms per chunk load on the main thread (parse on WorkerThreadPool).
- **Animated redraws:** ≤ 50 animated canvas items redrawing per frame.
- **Measure** with `scripts/make_big_map.py --size 512` and a timing harness (template below), before and after.

## Phases (from `docs/research/WORLD_MAP_FF8_FF9.md` §4; do them in order)
| # | Phase | Concrete tasks in this repo |
|---|---|---|
| 1 | ChunkView rendering | New inner class or file `ChunkView` (one CanvasItem per 32×32 chunk, draws columns in `x+y` order) **or** keep StripView but key strips by chunk so a chunk unload frees whole strips. Units and objects stay at `draw_order*2+1`; columns at `draw_order*2` (the battle convention in the header). Animated tiles move to a `canvas_item` shader using `TIME` so the chunk never redraws. |
| 2 | Manifest + chunk files + streaming ring | Add `src/world/chunk_store.gd` (start from `templates/chunk_store.gd`). Teach `ContentDB._load_maps` to keep format-3 manifests as-is (it already loads any `data/maps/*.json`; make sure the chunk subfolder isn't scanned as maps). ExploreScene: when `ChunkStore.is_streamed(d)`, call `cs.update(world, cell, 1, 3)` on each step, then `_renderer.refresh_columns(added + removed)`. Ocean `default_tile` becomes one repeating shader quad. Migration: `scripts/chunk_split.py split`. |
| 3 | Painter support | `forge_world_painter.gd` (138 KB, read its header first): dirty-chunk tracking, save only dirty chunks, bake `overview.png`, paint layers for encounter zones and atmosphere. |
| 4 | Wrapping | `posmod` in `can_step`, `walk_path`, `roll_encounter`, region lookup, ChunkStore `in_range`; draw chunk copies near the camera; floating origin. |
| 5–6 | Mini-map/full map, fog bitset, horizon roll-off shader, region fog/music, day/night | see `godot-frontier` (fog compute) and `godot-shader-forge` (roll-off). |
| 7–8 | Vehicles, submarine | `data/vehicles.json`, object kind `vehicle`, board/exit, `surface_y` waterline clip, dive. **Facings: ASK BRIAN** (grid steps render as diagonals; code is cardinal). |
| 9 | Encounter zones (visible threats default) | see `regions-encounters.md` |
| 10–12 | Landmarks, variants, fast travel, airship, land vehicle | later |

## Rules
- Chunks are the unit of rendering, loading **and** painting. Never build per-cell nodes.
- Parse chunk JSON off the main thread (`WorkerThreadPool.add_task`), mutate `WorldMap` and nodes on the main thread only.
- Keep format-2 maps working unchanged: streaming only applies when `format >= 3` and `streaming` exists.
- A missing chunk is ocean, not an error. Holes are unwalkable in `to_grid()`, which is what you want for deep water.
- Every phase ships a test in `tests/test_world.gd` (`templates/test_chunks.gd.txt` for phase 2) and a perf number in the PR notes.

## Timing harness (headless; numbers are relative because headless skips GPU)
```gdscript
# tests/perf_world_body.gd: loaded from a tiny SceneTree runner after `await process_frame`
# (autoload names can't be referenced at compile time in a -s script)
extends RefCounted
func run(tree: SceneTree, path: String) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var t0 := Time.get_ticks_usec()
	var w := WorldMap.from_dict(d)
	var t1 := Time.get_ticks_usec()
	var r := WorldRenderer.new()
	r.world = w
	tree.root.add_child(r)          # _ready builds roots, then rebuild()
	await tree.process_frame
	var t2 := Time.get_ticks_usec()
	var g := w.to_grid()
	var t3 := Time.get_ticks_usec()
	print("load %.1f ms  render build %.1f ms  to_grid %.1f ms  nodes %d" % [
		(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, tree.get_node_count()])
```
Run it with a map generated by `make_big_map.py` and copied to `user://` or an absolute path. Check the actual `WorldRenderer._ready` behaviour before trusting the "render build" number.
