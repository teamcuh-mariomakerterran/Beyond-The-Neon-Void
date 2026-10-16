# World format cheat sheet (format 2 = live; format 3 = proposed)

Source of truth: `src/world/world_map.gd` (`load_dict`/`to_dict`) and `docs/design/WORLD_FORMAT.md`. When they disagree, the code wins. Then update the doc.

## Format 2 (`WorldMap`)
| Key | Type | Notes |
|---|---|---|
| `format` | 2 | v1 maps have no `format` (loaded via `cells`, `"terrain:<id>"` tile ids) |
| `id`, `name` | String | `id` = file name in `data/maps/` |
| `kind` | `world`, `city`, `hub`, `interior`, `encounter`, `event` | `WorldMap.KINDS`; drives World Painter tabs and LINKS graph columns |
| `width`, `depth` | int | grid size |
| `tile_width`, `tile_height`, `height_step` | float | v2 default 128 / 64 / 32 (v1 64 / 32 / 16). **ASK BRIAN** about unifying with BD 64×32 |
| `music`, `ambient` | String | ambient = hex or `WorldRenderer.AMBIENT_PRESETS` key (`day dusk neon_noir night toxic_haze blackout blood_moon`) |
| `post` | String or Dict | HD2DPost preset (`off hd2d_warm neon_noir toxic_haze dream cinematic`) or `{"preset":…, overrides}` |
| `tiles` | `{"x,y": [[z, tile_id, opts?], …]}` | sparse stacks, z from −16 to 48 (`MIN_Z`/`MAX_Z`); top of stack becomes battle height (clamped −16..32) |
| `details` | Array | free-placed decals (`add_detail(asset, pos, z)`) |
| `particles` | `{"x,y": [[z, preset]]}` | presets from `data/particles.json` |
| `objects` | Array of dicts | `id, asset, cell, z, offset, scale, flip, layer, kind (prop/structure/character/location/loot/trigger/light), anim, loot_item_id, found_text, empty_text, dialog_npc, character_id, team, location{}, screen{}, cables, mask_group` |
| `location` (on object) | Dict | `type, name, target_map, target_spawn, intro_cutscene, discovered, radius` |
| `spawns` | `{"player": [[x,y]…], "enemy": […]}` | |
| `gameplay` | `{"x,y": {walkable, cover (1 half / 2 full), blocks_los, cost, hazard, group}}` | painted tactical masks land here; `group` = door group opened/closed by anchor actions `open/close/toggle` |
| `regions` | Array | `{id, name, color, cells: ["x,y"…], triggers: [{on: enter/exit/interact, do: cutscene/dialog/battle/flag/music/toast/teleport, arg, once, requires_flag, blocks_flag}], encounter: {rate, missions: []}}` |
| `anchors` | Array | interaction anchors, schema in `src/world/interactions.gd` header (see mission-architect) |
| `cables` | Dict | `CableNet.settings_of`: `{enabled, live, extra, sway, color, debris}` |
| `props` | Array | legacy v1 hidden-loot props (round-tripped) |

`WorldMap.to_grid()`:
- Every column with no tiles becomes `walkable=false`, terrain `void`.
- Top tile's terrain comes from `data/tiles.json` → `terrain`, then `apply_terrain_defaults`, then the `gameplay` overrides.
- `structure`/`location` footprints become unwalkable, LoS blockers with full cover.
- `prop`/`loot` set `prop_id`.

**API you'll use:**
- `to_screen(cell, z)`, `from_screen`, `pick_top(p)`
- `stack_at`, `tile_at`, `top_z`, `top_tile`, `set_tile`, `remove_tile`
- `add_object`, `add_anchor`, `anchors_at`, `group_cells(group)`
- `regions_at(cell)`, `add_region`, `locations()`
- `footprint_cells(o)`, `key(cell)`, `parse_key(k)`

## Format 3 (PROPOSED in `docs/research/WORLD_MAP_FF8_FF9.md` §3; nothing in code reads it yet)
- **Manifest** `data/maps/<id>.json`: the format-2 header plus `objects`, `spawns`, `regions`, `anchors`, `gameplay`, and:
  - `"format": 3`, `"wrap": "none"|"x"|"xy"`
  - `"streaming": {chunk_size: 32, dir, default_tile, overview}`
  - `"chunks": {"cx,cy": {"variants": [{flag, file}]}}`
  - `"regions"` as a grid of bytes + `defs` (music, fog, tint_day, tint_night, weather). **Note:** the research doc's regions shape differs from format 2's `regions` array. **ASK BRIAN** whether to keep the v2 array (painted cell lists with triggers) and add a separate `atmosphere` layer, or migrate.
  - `"encounter_zones": {"x,y": zone_id}`, `"zone_defaults"`, `"curvature": {k, k_air, haze_start}`
- **Chunk** `data/maps/<id>/chunks/<cx>_<cy>.json` is `{"chunk": [cx, cy], "tiles": {local "x,y": stack}, "details": [], "particles": {}}`. A missing chunk means all `default_tile`.
- **New data files:** `data/vehicles.json` and `data/encounter_zones.json`. `terrain.json` gains `vehicle_tags` and `encounter_factor`.
- **New save data:** `world_reveal` (zlib + base64 bitset per map) and `vehicles` (`{id: {cell, facing}}`).

`scripts/chunk_split.py` writes and reads exactly this chunk layout (losslessly round-trip tested on `neon_expanse` and a synthetic 256² map). `templates/chunk_store.gd` loads it into a `WorldMap` (compile and behaviour tested on Godot 4.7.2).
