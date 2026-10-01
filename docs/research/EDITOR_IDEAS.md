# World Painter: ideas from other level editors

_Compiled 2026-10-01. Compares the World Painter (`src/tools/forge_world_painter.gd`, format in `docs/design/WORLD_FORMAT.md`) with LDtk, Tiled, Godot TileMapLayer terrains and plugins, Crocotile3D/Sprytile, FFT fan tools, Mario Maker, Townscaper and WFC._

## What the editor already has (baseline)

The editor has stacked sparse tiles per column (`tiles: "x,y" -> [[z, id]]`, z can be negative). Its tools are brush, rect, fill, eyedropper, select/move, pan and erase, plus brush size, a solid-column toggle and dim-above. Palette multi-select cycles tiles while you paint. It also has free-placed decals (`details`), painted particle cells (`particles`), objects with anim, kind, loot, dialog and `location` links, and a GAMEPLAY layer for spawns, enemies, walkable, cover and LOS overrides. Other features: whole-map snapshot undo (40 deep), Ctrl+S save, and F5 play-here (it saves first, then runs the encounter or explore scene).

Renderer facts that affect several ideas below:
- Columns sort by `z_index = (x+y)*2`. Objects and details sort by `order*2+1`, where `order` is the rounded `x+y` of their single anchor cell. Nothing records a multi-cell footprint.
- The ghost colour is HDR (`Color(0.25, 1.9, 0.75)`), so 2D HDR/glow is already in use.

Effort: **S** is about a day or less, **M** is a few days, **L** is a week or more.

---

## Top 8: do next

| # | Idea | Group | Effort |
|---|---|---|---|
| 1 | Autosave, crash recovery and a map validator | Robustness | S |
| 2 | Auto-dress rules (LDtk/Tiled-style rule layer for stacks) | Speed | M |
| 3 | Stamps / prefabs (save a selection, paste with rotate/flip) | Speed | M |
| 4 | Scatter brush (density, jitter, weighted sets) | Speed | S |
| 5 | Editor juice pack (pop-in tweens, puffs, sounds) | Juice | S |
| 6 | Tactical overlay (move range, LOS, height and cover heatmaps) | Gameplay | M |
| 7 | Painted lights and ambient (neon PointLight2D + CanvasModulate) | Expressiveness | M |
| 8 | Multi-cell object footprints and correct iso sorting | Expressiveness / Robustness | M |

---

## Speed: build faster

### 2. Auto-dress rules (DO NEXT)
- **What:** you paint "intent" and rules pick the actual tile. LDtk auto-layers match grid patterns (for example "wall here AND no wall above → paint wall-top"). Tiled Automapping applies rule maps "while drawing", and Tiled terrains/Wang sets choose transitions. Townscaper dresses a whole building from one click.
- **Why:** you hand-pick cliff faces, grass edges, wall caps and puddle variants today. On a 24×24 FFT-style map that is hundreds of clicks per map. Rules also make every map look consistent.
- **Sketch:**
  - Add `data/dress_rules.json`. Each rule is an ordered entry: `{when: {self: "terrain:grass", above: "empty", n: "terrain:water", ...}, then: {replace: "god_tiles/grass/grass_edge_n"} | {add_detail: [...], chance: 0.3} | {stack_top: "..."}}`.
  - Neighbours are N/E/S/W, plus `above` and `below` in the same column. Match on `terrain` or `group` from `data/tiles.json` rather than on raw ids.
  - Run it as a pass over dirty cells and their 8 neighbours after `_apply()`. Toggle it with a "Dress" checkbox, the equivalent of Tiled's "AutoMap while drawing".
  - Mark output tiles with a flag (stack entry `[z, id, {"auto": true}]`) so re-dressing replaces only auto tiles and never hand-placed ones.
  - Seed the randomness with a hash of the cell (`hash(Vector2i)`) so results are stable between runs.
  - Copy LDtk 1.2's "rules assistant": the user paints a 3×3 example and the editor generates the rule.
- **Sources:**
  - https://ldtk.io/docs/general/auto-layers/auto-layer-rules
  - https://docs.mapeditor.org/en/latest/manual/automapping/
  - https://docs.mapeditor.org/en/stable/manual/terrain/
  - https://github.com/Portponky/better-terrain
  - https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making

### 3. Stamps / prefabs (DO NEXT)
- **What:** select a box of columns (tiles, details, particles, objects and gameplay together) and save it as a named stamp. Paste it with R to rotate 90° and F to flip. Tiled Object Templates and Crocotile's select-and-copy are the models.
- **Why:** neon bar fronts, stair runs, catwalk segments and ruined cars repeat across hubs. Stamps also give new maps a shared visual language for free.
- **Sketch:**
  - Store stamps in `data/stamps/<id>.json`, using the map format cropped to the selection. Cells are relative, and `z` is relative to the anchor's top.
  - Add a SELECT-mode marquee for tiles, then "Save stamp" in the inspector.
  - The palette gets a STAMPS tab. The ghost draws the stamp with `WorldRenderer.draw_tile` at alpha 0.55, just as the current tile ghost does.
  - Rotating in iso means swapping (x,y) → (y,-x), and swapping directional tile variants through an optional `rot_variants` map in `tiles.json`.
  - Templates: an object can carry `"template": "stamp_id"` so editing the stamp updates its instances. That is optional for v2.
- **Sources:**
  - https://docs.mapeditor.org/en/latest/manual/using-templates/
  - https://digitalproduction.com/2024/12/02/crocotile-3d-2-4-5-tile-based-3d-modeling-tool-gets-new-features/

### 4. Scatter brush (DO NEXT)
- **What:** a brush that sprinkles details or props with set density, random scale, rotation, flip and tint jitter, picking from a weighted set. This is the 2D take on ProtonScatter and Terrain3D foliage painting.
- **Why:** debris, cables, trash, neon puddles and graffiti decals are what make cyberpunk read as lived-in. Placing them one by one is slow and looks too regular.
- **Sketch:**
  - In DETAILS/OBJECTS mode, add a "Scatter" toggle with density, min spacing (Poisson-disc), scale range and tint range sliders.
  - Use the palette multi-select (already in `sel_tiles`-style for tiles) as the weighted set.
  - Generate `details` entries with free `pos` floats inside the brush footprint, and only on cells whose top tile's `terrain` is in an allow-list.
  - Group one stroke under `"scatter_group": id` so "re-roll group" and "delete group" work.
  - ERASE + Scatter thins out a group by percentage.
- **Sources:**
  - https://github.com/HungryProton/scatter
  - https://github.com/TokisanGames/Terrain3D

### 9. Height sculpt brushes
- **What:** raise, lower, flatten-to-height, smooth and "terrace" brushes that work on whole columns. These are Terrain3D sculpt tools on a voxel stack.
- **Why:** FFT and Triangle Strategy maps are about elevation. Shaping a hill one layer at a time with PgUp/PgDn is slow.
- **Sketch:**
  - Raise duplicates the top tile id one layer up, or a "fill" id from the column (as solid-column does). Lower pops the top.
  - Smooth moves each column toward its neighbour average, clamped to ±1 per stroke tick.
  - Combine with auto-dress (#2) so cliff faces re-skin automatically.
- **Effort:** S.
- **Source:** https://github.com/TokisanGames/Terrain3D

### 10. Line / stairs / ramp tool
- **What:** drag from A to B to lay a path, wall line or stair run. Height rises by one layer every N cells.
- **Why:** stairs and catwalks connect elevation tiers. Right now each step is a manual click.
- **Sketch:** Bresenham on the iso grid. The tool is `Tool.LINE` (key L), with ghost prisms showing each step's z.
- **Effort:** S.

### 11. Mirror / symmetry painting
- **What:** an X, Y or diagonal mirror axis, as in many pixel editors and Townscaper-style toys.
- **Why:** PvP-fair arenas and symmetric plazas are built in half the time.
- **Sketch:** `target_cells()` also returns the mirrored cells, and objects with `flip` get mirrored too.
- **Effort:** S.

### 12. Procedural fill: noise heightmap and WFC region fill
- **What:** "Generate" a selected rect.
  - **Noise mode:** FastNoiseLite gives height plus a terrain bands table.
  - **WFC mode:** learns adjacency from an example map region (mxgmn's overlapping model) and fills the rect.
- **Why:** it gives rough ground or ruins quickly, and you then hand-edit. That is the Townscaper "you author, it fills in" feel.
- **Sketch:**
  - Noise is S, using built-in `FastNoiseLite`.
  - WFC is L. Port the simple tiled model in GDScript, with adjacency over (tile id, Δz) pairs, or adapt godot-constraint-solving's 2D solver, which "infers rules from an example map" and backtracks.
  - Always produce output as one undo step.
- **Sources:**
  - https://github.com/mxgmn/WaveFunctionCollapse
  - https://github.com/AlexeyBond/godot-constraint-solving

### 13. Quick palette: search, favourites, recents
- **What:** a fuzzy search box over `tiles.json`, `asset_index.json` and stamps, plus a pinned "favourites" row and the last 12 used items.
- **Why:** the asset library grows with every intake-bot run, and scrolling through groups gets slow.
- **Sketch:** a `LineEdit` above `_palette`, filtering by id and group. Store recents and favourites in `user://forge_prefs.cfg` (ConfigFile).
- **Effort:** S.

---

## Juice: feel

### 5. Editor juice pack (DO NEXT)
- **What:** Mario Maker gives every placement a tiny animation and a sound, which makes building feel like play. "Juice it or lose it" gets the most out of small inputs.
- **Why:** the creator spends hundreds of hours in this tool. Feedback also confirms where something landed in a dense iso stack.
- **Sketch:**
  - **Pop-in tween:** in `WorldRenderer.refresh_column`, give new tiles a scale tween (0.7→1.08→1.0) and a 4px drop on their column node. `create_tween().set_trans(Tween.TRANS_BACK)`.
  - **Dust/spark puff:** spawn a one-shot `CPUParticles2D` at `to_screen(cell, z)`, colour-matched to the terrain's `side` colour from `data/terrain.json`.
  - **Sounds:** a per-terrain click (metal clank, concrete thud, water bloop) from `assets/sfx/forge/`, with pitch rising slightly over consecutive brush stamps (a pitch ladder). Erase plays a reverse whoosh, and fill plays a rising sweep.
  - **Camera nudge:** a 2–3px shake on fill or stamp only.
  - **Hover:** the ghost prism "breathes" (alpha sine). Selected objects show a pulsing outline shader.
  - Add an "Editor FX" toggle so it can be switched off.
- **Sources:**
  - https://www.youtube.com/watch?v=Fy0aCDmgnxg (Juice it or lose it)
  - https://popmatters.com/delightful-design-in-super-mario-maker-2495458717.html

### 14. Instant playtest round-trip
- **What:** Mario Maker switches between build and play with one button and drops you back exactly where you were.
- **Why:** F5 currently saves to disk and leaves the editor. A fast loop gets more iterations per hour.
- **Sketch:**
  - Play from the in-memory `world.to_dict()` without writing the file. Use `CampaignManager.explore` with a dict override, or a temp id `__playtest`.
  - Return with Esc to the Forge, restoring the camera, mode, tool and selection.
  - Spawn at the hover cell as a chosen unit.
  - Optionally record the walk path and show it as a fading trail in the editor afterward. This is Mario Maker's "ghost" path.
- **Effort:** M.

### 15. Sculpt-time preview of animated tiles, particles and lights at game speed
- **What:** a "Live" toggle that runs all anim and particles in the editor viewport, versus "Still" for precise placement.
- **Why:** it shows the real mood of a scene while building, with no playtest needed.
- **Effort:** S. Mostly `set_process` gating in the renderer.

---

## Expressiveness: new looks

### 7. Painted lights and ambient (DO NEXT)
- **What:** a LIGHTS mode. Click to place a `PointLight2D` (colour, energy, radius, flicker/pulse/neon-buzz preset). Each map gets an `ambient` colour driving `CanvasModulate`, plus optional `WorldEnvironment` glow. Objects can carry an `emit` block (a neon sign lights its surroundings).
- **Why:** a cyberpunk game lives on neon pools of light in dark streets. Today the mood comes only from tile art.
- **Sketch:**
  - Format: top-level `"lights": [{"id","pos":[x,y],"z","color","energy","radius","anim":"steady|flicker|pulse|buzz"}]` and `"ambient": "#1a1030"`.
  - The renderer adds a `CanvasModulate` and one PointLight2D per entry. It uses a radial gradient texture (`GradientTexture2D` fill radial), with `blend_mode = ADD`.
  - Occlusion is optional. Use height-aware LightOccluder2D only for objects with `blocks_los`.
  - Turn on 2D HDR (`rendering/viewport/hdr_2d`) for bloom on neon, since the ghost colour is already HDR.
  - Add a time-of-day slider in the topbar to preview ambient presets.
- **Sources:**
  - https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html
  - https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html#canvasmodulate

### 8. Multi-cell object footprints and correct iso sorting (DO NEXT)
- **What:** structures declare a footprint (`"size": [w, d, h]` in cells and layers). Sorting uses that footprint instead of a single anchor cell.
- **Why:** the renderer sorts objects at `order*2+1` from one cell. A 3×2 neon bar sorts wrongly against units walking past its east side. This is the classic multi-tile iso bug in Godot forums and Tiled discourse. The footprint also gives automatic walkable/LOS blocking.
- **Sketch:**
  - Add `"size"` to objects, defaulting to `[1,1,1]`. `asset_index.json` can store a per-asset default.
  - **Sort key:** use the footprint's front-most cell (max x+y). For units adjacent to large objects, fall back to a pairwise box test with topological ordering for overlapping screen rects. Only a few dozen dynamic sprites need this per frame.
  - **Editor:** draw the footprint prisms in the ghost, give the inspector W/D/H spinners, and tick "auto-block" to write `gameplay` overrides for covered cells.
- **Sources:**
  - https://forum.godotengine.org/t/godot-4-tilemap-sorting-larger-objects/3915
  - https://discourse.mapeditor.org/t/multi-tile-objects/4524
  - https://www.texturemind.com/post2354/

### 16. Per-tile variation: tint, flip and hue jitter
- **What:** optional per-stack-entry `{"tint","flip"}`, plus a "variation" brush that randomizes them within a range.
- **Why:** tile repetition is the number one tell of tile maps. Cheap colour noise breaks it up without new art.
- **Sketch:** a third element in the stack entry (as in #2). `draw_tile` already takes alpha, so add a modulate parameter.
- **Effort:** S.

### 17. Corner-based (dual-grid) terrain blending for ground
- **What:** dual-grid tilesets get full transitions from 5–6 tiles instead of 16–47, because corners are evaluated on an offset grid.
- **Why:** it cuts the art cost for each new ground type (toxic sludge, neon grass), and pairs well with auto-dress.
- **Sketch:** a "blend" tile kind whose four corner terrains come from neighbouring columns at the same z. It is drawn as four quarter-diamonds. This is L if done generally; M for flat ground only.
- **Sources:**
  - https://github.com/pablogila/TileMapDual
  - https://github.com/jess-hammer/dual-grid-tilemap-system-godot

### 18. View rotation (4 x 90°) in editor and game
- **What:** FFT and Triangle Strategy let you rotate the map. Triangle Strategy's developers note that maps must "look good from all angles".
- **Why:** it reveals hidden tiles and cover behind tall columns, and authors find occlusion problems early.
- **Sketch:**
  - `WorldMap.to_screen` takes a rotation and remaps (x,y) before projection. The sort key changes to match.
  - Tiles need rotated art or symmetric art. Show a warning badge on assets with no rotated variants.
- **Effort:** L.
- **Source:** https://nintendoeverything.com/triangle-strategy-devs-on-the-name-plot-multi-tiered-maps-and-more/

### 19. Cutaway / X-ray slice
- **What:** a slider "show layers ≤ N", with everything above drawn at 15% or hidden. This extends the existing `dim_above`. Crocotile and Sprytile depend on a layer focus like this.
- **Why:** you cannot paint interiors and under-bridge spaces without it.
- **Effort:** S.
- **Source:** https://github.com/BrahRah/ReSprytile

---

## Gameplay authoring: encounters and scripting

### 6. Tactical overlay (DO NEXT)
- **What:** toggles that show what the battle system will compute:
  - move range from a chosen spawn for a chosen unit (jump/move stats)
  - LOS fan from a cell
  - height-delta map (climbable vs. cliff)
  - cover heat
  - unreachable-cell warnings
- **Why:** Into the Breach's GDC postmortem stresses board readability. FFT fan editors (GaneshaDx) expose per-tile height, slope and depth because those values decide combat. Today you only see glyph markers.
- **Sketch:**
  - Reuse the grid/pathfinding code in `src/grid/` and `src/combat/`, fed with `world` plus `gameplay` overrides.
  - Draw in `GhostLayer._draw_gameplay`: tinted diamonds (cyan = reachable, amber = cover, red = blocked), and LOS rays as lines.
  - Clicking a cell with the overlay on sets the "origin".
- **Sources:**
  - https://gdcvault.com/play/1025772/-Into-the-Breach-Design
  - https://github.com/Garmichael/GaneshaDx

### 20. Typed entity fields and references (LDtk-style)
- **What:** objects get schema-driven fields: enum (`team`, `loot_item_id` from ContentDB), entity refs (a switch → door), arrays and colours. The inspector validates them.
- **Why:** `dialog_npc`, `loot_item_id` and `character_id` are free strings today, so typos only show in play.
- **Sketch:**
  - `data/object_kinds.json`: `kind -> [{name, type: "enum:items" | "ref:object" | "int" | "color" | "cell", default}]`.
  - The inspector builds `OptionButton`s from ContentDB buckets. A `ref:object` field picks by clicking in the viewport, and draws an arrow from source to target in the ghost layer.
- **Effort:** M.
- **Sources:**
  - https://ldtk.io/docs/general/editor-components/entities/
  - https://ldtk.io/docs/general/editor-components/enumerations-enums/

### 21. Regions and triggers
- **What:** paint named regions (cell sets): escape zone, capture point, reinforcement entry, hazard (fire/electrified water), dialog trigger. Attach simple conditions and actions: `on_enter`, `turn >= N`, `unit_dead(id)` → `spawn wave`, `play cutscene`, `set flag`.
- **Why:** FFT and Triangle Strategy battles turn on mid-fight events. This is a Dialogic-adjacent level of authoring without leaving the map.
- **Sketch:**
  - Format: `"regions": {"escape_a": {"cells": [[x,y],...], "color": "#..", "events": [{"when": "...", "do": [...]}]}}`.
  - Painted with the existing brush/rect in a new GAMEPLAY sub-tool. Reinforcement waves reference the mission's `enemies` with `"wave": n`.
- **Effort:** M–L.
- **Source:** https://github.com/dialogic-godot/dialogic

### 22. Location graph view
- **What:** a node-graph popup of every map and its `location` links (world → hub → interior), with broken links in red. Double-click opens that map.
- **Why:** the world, city, hub and interior chain grows fast. Dangling `target_map` or `target_spawn` values break travel.
- **Sketch:** a `GraphEdit` built from `ContentDB.maps`. Edges come from objects whose `kind == "location"`.
- **Effort:** S–M.

---

## Robustness

### 1. Autosave, crash recovery and a map validator (DO NEXT)
- **What:**
  - Autosave every N seconds and on F5 to `user://forge_autosave/<id>.json`, with a ring of 5.
  - On load, offer "Recover newer autosave?"
  - A Validate panel lists problems and clicking one jumps to the cell.
- **Why:** this is a hand-built content pipeline with a 40-step in-memory undo. One crash can lose an hour of map work. The validator catches broken content before playtesting.
- **Sketch:**
  - A `Timer` in `_ready` calls `if dirty: _autosave()`.
  - **Validator checks:**
    - no player spawns on an encounter map
    - spawn or enemy on a non-walkable or empty cell
    - location with an empty or missing `target_map`, or a `target_spawn` past the end of the target's spawns
    - unknown tile, detail or asset ids (asset missing on disk)
    - enemies unreachable from any spawn (reuse #6 pathing)
    - objects out of bounds
  - Run on save. Block nothing, but show a red count badge on the Save button.
- **Effort:** S.
- **Source:** this is our own design and is not taken from another editor's feature.

### 23. Command-based undo with a history list
- **What:** record diffs (changed columns and objects) instead of full `to_dict()` snapshots. Add a history panel ("Brush ×34 grass", "Stamp bar_front").
- **Why:** snapshotting the whole map on every stroke gets slow on 160×160 maps and caps undo at 40. A named history makes undo feel safe enough to experiment.
- **Sketch:** `_push_undo(cells, objects)` stores before/after for only the touched keys, and `_restore` applies the partial diff. The renderer already has `refresh_columns(cells)`.
- **Effort:** M.

### 24. Map thumbnails and a diff-friendly save
- **What:** on save, render a 256px thumbnail (`SubViewport.get_texture().get_image()`) to `data/maps/thumbs/<id>.png` for the map picker. Write JSON with sorted keys and one column per line.
- **Why:** you can find maps visually, and git diffs and merges stay readable (the asset bot already pulls and merges).
- **Effort:** S.

### 25. Asset-reference repair
- **What:** when an asset path moves (intake-bot reorganisations), show "missing asset" placeholders in magenta and offer a bulk find-replace of ids across all maps.
- **Why:** it stops silent blank tiles after asset folder shuffles.
- **Effort:** S.

---

## Suggested order
#1 → #5 → #4 → #2 → #3 → #6 → #8 → #7

1. #1 makes everything after it safe.
2. #5 and #4 are quick wins.
3. #2 and #3 are the biggest speed multipliers.
4. #6, #8 and #7 make the maps play and look like a neon tactics game.
