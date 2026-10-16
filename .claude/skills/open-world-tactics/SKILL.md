---
name: open-world-tactics
description: >-
  Use when building or changing Beyond The Neon Void's world: format-2/3 maps,
  the huge FF8/FF9-style overworld, chunk streaming (ROADMAP "must come first"),
  WorldRenderer performance, exploration (ExploreScene), locations and links,
  regions/triggers, random or visible encounters, returning to the same map and
  cell after a battle, world save state, vehicles, fog of war or fast travel.
  Load neon-void-architect first; pair with iso-tactics-grid for grid math.
---

# Open-World Tactics

Brian is starting world work now. The ROADMAP says: **"Must come first: chunked
renderer + chunk streaming."** This skill gets the world from 28×28 demo maps
to a streaming FF8/FF9-feel overworld without breaking the tactics layer that
already works.

Load as needed:
- `references/world-format.md`: format 2 fields (live), format 3 (proposed), `WorldMap` API, `to_grid()` rules
- `references/chunk-streaming.md`: renderer state today, **measured baseline**, phased plan, budgets, timing harness
- `references/explore-battle-loop.md`: return-to-position after battles, world save checklist
- `references/regions-encounters.md`: triggers table, visible vs random encounters, mission hand-off
- `templates/chunk_store.gd`: format-3 chunk loader into `WorldMap` (compiles and passes on Godot 4.7.2)
- `templates/test_chunks.gd.txt`: the matching `test_chunk_store()` for `tests/test_world.gd`
- `scripts/world_audit.py`: per-map size, render-cost estimate, broken links, trigger and anchor targets
- `scripts/make_big_map.py`: synthetic 256²/512² format-2 world for perf tests (needs no art)
- `scripts/chunk_split.py`: format 2 → format 3 manifest + chunks, and merge back (lossless round-trip)

---

## When to run

- Any change in `src/world/` (world_map, world_renderer, explore_scene, interactions, cable_net, signage, map_validator) or in `data/maps/`.
- Planning or painting the overworld, cities, hubs, interiors, encounter maps.
- Anything about locations, travel, regions, encounters, vehicles, fog, fast travel, day/night.
- Battles started from the world, and what happens after them.

Not for: tactical rules inside a battle (`tactics-combat-core`), mission content (`mission-architect`), shaders (`godot-shader-forge`).

---

## Ground truth (verify with `scripts/world_audit.py <repo>`)

- **Maps today:** `neon_expanse` (world 28×28), `neo_kowloon_hub` (hub 18×18), `neon_block_demo` (city 14×14), `vault_breach_demo` (encounter 16×14) at 128×64 tiles. Two legacy v1 battle maps, `supply_works_dock` and `gutter_alley`, at 64×32.
- **Dead ends:** the 3 hub buildings have empty `target_map`; "Dead Server Farm" on `neon_expanse` has none either. No map uses `regions` yet.
- **Renderer:** `WorldRenderer` has one `StripView` per 32 cells of an iso diagonal (`STRIP_LEN`, `strip_key()`). `rebuild()` builds the **whole** map. Animated strips `queue_redraw()` every frame.
- **Measured (box, headless):** a 512² map takes about **8.5 s** to build in the renderer and **2.1 s** in `to_grid()`. See `chunk-streaming.md`.
- **Exploration:** `ExploreScene` (step/click, `walk_path`, `can_step`, labels, `_enter` locations, `_update_regions`, `roll_encounter`, anchors through `Interactions`, NPCs through `NpcStages`).
- **No in-game entry to exploration:** only the Forge "Play here", the dev console `tp` and `explore_scene.gd` call `CampaignManager.explore`. Wiring a hub or title entry to the overworld (e.g. a hub tab or button that calls `CampaignManager.explore("neon_expanse")`) is step zero of world work. **ASK BRIAN** where the entry goes.
- **Battles always return to the hub** (`BattleMap._on_continue` → `CampaignManager.return_to_hub()`). `CampaignManager.current_explore` is not saved.
- **Bugs to fix when nearby:** the region `music` trigger type error, and the 60k px `ColorRect` backdrop in `explore_scene.gd`.

---

## Hard rules

1. **Chunks are the unit** of rendering, loading and painting. Never add per-cell nodes. Never build a whole big map in one frame.
2. **Format 2 keeps working.** Streaming switches on only when `format >= 3` and `streaming` exists (`ChunkStore.is_streamed(d)`). Existing maps, the painter and battles must not change behaviour.
3. **One renderer.** The World Painter, exploration and battles all use `WorldRenderer`, and "what you paint is exactly what plays". Extend it (or add `ChunkView` beside StripView). Never fork a game-only renderer.
4. **Respect draw order:** column = `draw_order*2`, anything standing on it (details, objects, units, avatar) = `draw_order*2+1`, `draw_order = x+y`.
5. **Threading:** parse chunk JSON on `WorkerThreadPool`; mutate `WorldMap` and nodes only on the main thread. `ChunkStore.read_chunk` is thread-safe; `load_into` isn't.
6. **Every battle launched from the world records where to come back to** (`explore-battle-loop.md`). Never call `CampaignManager.start_mission` from exploration bare.
7. **World state has a home.** Before adding state, find its row in the world-save checklist. Flags for narrative, SaveManager blocks for structural state. Add a round-trip test.
8. **Content links are validated:** run `scripts/world_audit.py` after editing maps. Zero errors before you say done.
9. **Measure.** Any renderer or streaming change reports before/after numbers from the timing harness on a `make_big_map.py` map.
10. **Don't decide canon or feel alone.** Facings, tile scale, encounter default (visible vs random), defeat-from-world behaviour, region data shape for format 3: write `ASK BRIAN` and stop that branch.

---

## Workflow: chunk streaming (phases 1–2)

1. Baseline:
   - `python scripts/make_big_map.py --size 512 --out %TEMP%\perf512.json`
   - Run the harness from `chunk-streaming.md` and record the numbers.
2. **Phase 1 (render):** make strips chunk-aligned or add `ChunkView` (one CanvasItem per 32×32 chunk). Move animated tiles to a `TIME` shader so chunks don't redraw. Replace the 60k backdrop.
3. **Phase 2 (data and streaming):**
   - Copy `templates/chunk_store.gd` to `src/world/chunk_store.gd`.
   - Make sure `ContentDB._load_maps` ignores chunk subfolders.
   - In `ExploreScene`: if streamed, `cs.update(world, cell, 1, 3)` per step, then `_renderer.refresh_columns(added + removed)`.
   - Ocean `default_tile` becomes one shader quad.
   - `grid` becomes per live area (or rebuild `to_grid()` for the live window only).
4. Migrate a map with `scripts/chunk_split.py split data/maps/neon_expanse.json <out>`, then `merge` and diff to prove it's lossless.
5. Tests: paste `templates/test_chunks.gd.txt` into `tests/test_world.gd`, plus a streaming step test. Run the `godot-verify` gate.
6. Update `docs/design/WORLD_FORMAT.md` (format 3 section) and add `ROADMAP.md` "Built <date>".

## Workflow: return-to-position after battles
Follow `references/explore-battle-loop.md`:
- add `CampaignManager.return_to` and `start_mission_from_explore`
- add `finish_battle_navigation()` and call it from `BattleMap._on_continue`
- save `current_explore` and `return_to`
- test the round-trip
- **ASK BRIAN** about defeat behaviour.

## Workflow: a new location or region
1. Paint in the World Painter (Forge → WORLD PAINTER). Double-click an object to make it a location. Use the REGIONS tab for triggers.
2. Every location gets a `target_map` + `target_spawn` (or is deliberately a POI with a dialog/toast trigger) and an `intro_cutscene` only if it's a first-visit moment.
3. Check the LINKS graph (`src/tools/location_graph.gd`); broken links show as red ghost nodes.
4. Run `scripts/world_audit.py --map <id>`.

---

## Anti-patterns

- A second map format or renderer "just for the overworld".
- Loading all chunks at start "for now".
- `to_grid()` on a 512² map every step.
- Hardcoding encounter tables in GDScript instead of `data/encounter_zones.json`.
- Storing the player position only in a node (lost on scene change and save).
- Teleport triggers without a valid `map:spawn`.
- Locations with no `target_map` and no trigger (silent dead ends).
- Using a cardinal-facing sprite set for grid movement without Brian's facing decision.
- Animated tiles that each `queue_redraw()` per frame on huge maps.
- Writing perf test maps into `data/maps/` (use `%TEMP%` or `user://`).

---

## Done checklist

- [ ] `world_audit.py` shows 0 errors (warnings explained)
- [ ] Format-2 maps still load, paint and play (painter test + explore test green)
- [ ] Streaming: no per-cell nodes; JSON parsed off the main thread; chunk unload frees nodes
- [ ] Before/after perf numbers recorded from the harness
- [ ] Battles from the world return to the same map/cell; save/load keeps position
- [ ] New world state listed in the save checklist with a round-trip test
- [ ] `godot-verify` gate green
- [ ] `WORLD_FORMAT.md` / ROADMAP updated; ASK BRIAN items listed in the PR notes
