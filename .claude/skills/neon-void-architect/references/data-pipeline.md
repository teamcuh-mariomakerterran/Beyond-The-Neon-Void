# Data pipeline: JSON → ContentDB → GameResource → Neon Forge

## How it works
1. **JSON** lives in `data/<bucket>.json`. Typed buckets are arrays of `{id, …}` records; plain buckets are dicts. Maps are one file per map in `data/maps/<id>.json`.
2. **ContentDB.reload()** reads `res://data` and then `user://content`. For each typed bucket (`CATALOG`) it instantiates the Resource script and calls `apply_dict(entry)`. Abilities with `"script": "kinetic"|"time"|"terrain"` use `ABILITY_SCRIPTS` subclasses.
3. **GameResource** (`src/data/game_resource.gd`, `@abstract`) reflects over `@export` properties (`PROPERTY_USAGE_SCRIPT_VARIABLE | STORAGE`):
   - Unknown JSON keys are ignored, so older files keep loading.
   - Enums are stored by **name** (`"kind": "ATTACK"`).
   - Base fields are `id`, `display_name` and `description`.
4. **ForgeForm** (`src/tools/forge_form.gd`) builds an editor form for any GameResource or Dictionary. It picks widgets by type **and field name**.
5. **ForgeStore** (`src/tools/forge_store.gd`) writes back to `res://data` (editor) or `user://content` (export).
6. **ContentDB.validate()** cross-checks references (classes, abilities, characters, missions, loot, dispatch, items, vendors, quests, NPC dialog graph). Known gap: `_map_prop_exists` only checks v1 `props`.

## ForgeForm name → picker (REFS, from `forge_form.gd`)

| Field name | Picks from |
|---|---|
| `class_id`, `secondary_class_id`, `unlock_requirements`, `class_affinity`, `class_levels` | classes |
| `innate_ability_ids`, `learnable_ability_ids`, `learned_ability_ids` | abilities |
| `status_ids`, `cure_status_ids` | status_effects |
| `loot_table_id` | loot_tables |
| `map_id` | maps |
| `music_id`, `sfx_id`, `vfx_id` | music / sfx / vfx |
| `item_id`, `result`, `loot_item_id`, `give_item_id`, `stock.id`, `reward_items`, `fetch_reward_items_*` | items_and_cards |
| `evolves_into`, `from`, `to`, `crafting_materials`, `materials`, `fetch_items` | items |
| `unlocks_mission_ids`, `fight_mission_id` | missions |
| `quest_ids`, `prerequisite_quest_ids`, `next_quest_id`, `offer_quest_id`, `chain_quest_id` | quests |
| `giver_npc_id` | npcs |
| `character_id` | characters |
| `vendor_id` | vendors |
| `rumor_ids` | rumors |
| `equip_type`, `weapon_types`, `specialty_weapon_types`, `weapon_specialties` | weapon_types |
| `terrain` | terrain |
| `intro_cutscene`, `outro_cutscene`, `cutscene`, `stage_cutscene` | cutscenes |
| `*_path`, `texture`, `asset` | file field with preview (accepts drops) |

**Record lists** (ForgeRecordList defaults):
- `enemies {character_id, cell, level, ai, statuses}`
- `guests`
- `entries {item_id, weight, min, max}`
- `objectives {type, target, count, text}`
- `dialog {id, text, speaker, voice_path, requires_flag, sets_flag, next, choices}`
- `choices`
- `eavesdrop_lines`
- `stock {id, price, required_flag}`
- `props`

**Enum dropdowns (CHOICES):**
- `after_talk`, objective `type`
- `ai`/`ai_behavior` (aggressive, cautious, tactical, support)
- `scaling_stat`, `damage_type` (physical, kinetic, plasma, cryo, electric, tech, void, essence)
- `win_condition` (defeat_all, defeat_target, survive, reach_cell), `lose_condition` (party_wiped, leader_down, protect, time_limit)
- `special`, `script`
- rumour `channel` (news, gossip, graffiti, radio)
- `location_id` (currently only `neon_gutter`)

**Help text:** `win_param` means "defeat_target: character id • survive: rounds • reach_cell: x,y".

**Rule:** name new fields to hit these patterns so the Forge gets a picker for free. If you need a new reference source, add it to `REFS` in `forge_form.gd` in the same change.

## Recipe: add a field to an existing content type
1. Add `@export var my_field: <Type> = <default>` to the Resource in `src/data/`, inside the right `@export_group`. Add a `##` doc line, and add a tooltip to `ForgeForm.HELP` (in `forge_form.gd`) if the field isn't obvious. Add `ForgeForm.CHOICES` if it's an enum-like string.
2. Give the default the old behaviour, so existing JSON is unchanged.
3. Use it in rules code.
4. Add it to the JSON entries that need non-default values. Never bulk-rewrite every entry just to add a default.
5. If it's a reference, extend `ContentDB.validate()` to check it.
6. Test: load → `to_dict()` round-trip, plus the behaviour.

## Recipe: add a new typed content bucket
1. Create `src/data/<thing>_resource.gd` with `class_name <Thing>Resource extends GameResource` and `@export` fields.
2. Add `"<bucket>": <Thing>Resource` to `ContentDB.CATALOG` and a typed getter `get_<thing>(id)`.
3. Create `data/<bucket>.json` (array of records with `id`).
4. Register it in `SECTIONS` in `src/tools/neon_forge.gd` as `["<bucket>", "LABEL", "bucket", "<bucket>"]` (plain dicts use `"dict"` plus a `DICT_TEMPLATES` entry). Note: `passives` is a ContentDB bucket but is **not** in `SECTIONS` today (gap).
5. Add validation to `ContentDB.validate()`.
6. Add tests: content loads, the editor produces a form (`test_suite.gd::test_editor` iterates content types), round-trip.

## Recipe: plain-dict data (no Resource yet)
Use this for presentation or lookup tables (cues, vfx, particles, status_looks, signage, terrain, tiles):
- Add a `var` on ContentDB plus a `merge(_read_dict(...))` line in `reload()`, **or** let the owning system read its own JSON (as `Cues` reads `res://data/cues.json` and `VFX` reads `data/vfx.json`).
- Start the file with a `"_note"` or `"_readme"` key that documents the schema. Every existing presentation JSON does this.

## Maps
`data/maps/<id>.json` holds format 1 (`cells`, legacy) or format 2 (see `open-world-tactics`). `ContentDB.get_map(id)` returns the raw Dictionary; `WorldMap.from_dict(d)` gives the typed map, and `WorldMap.to_grid()` gives the battle grid.
