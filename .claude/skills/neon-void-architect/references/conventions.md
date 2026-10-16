# Conventions already followed in this repo (copy them)

## GDScript
- **Static typing everywhere:** `var grid := IsometricGrid.new()`, `var units: Array[Node] = []`, `for c: Dictionary in list:`, `func f(a: int) -> void:`. Typed lambdas: `func(r: Dictionary) -> bool: return …`.
- **Tabs** for indentation. `snake_case` for files, funcs and vars; `PascalCase` for `class_name` and inner classes; `UPPER_SNAKE` for consts.
- **File header:** `class_name X` (never on autoloads), `extends Y`, then a `##` block explaining purpose, schema and usage. `src/world/interactions.gd` and `src/world/world_map.gd` are the gold standard; they document the full dict schema in the header.
- **`##` doc comments** on vars and funcs that aren't obvious. Plain `#` for inline notes.
- **Inner classes** for small render helpers (`WorldRenderer.StripView`, `Signage.Board`, `ExploreScene.AvatarMarker`).
- **Pure logic is RefCounted/static:** `IsometricGrid`, `WorldMap`, `Interactions`, `NpcStages`, `MapValidator`, `ProgressionSystem`, `DamageCalculator`, `VFX`. Nodes are used only for drawing or time.
- **Host protocol instead of hard references:** `Interactions` asks its host with `has_method` (`ix_toast`, `ix_units`, `ix_group_changed`, `ix_spawn`, `ix_npc`, `ix_anchor_changed`, `run_trigger`). Use this duck-typed host pattern for systems shared by the battle and explore scenes.
- **Awaitable flows:** `await player.finished`, `await NpcStages.run(npc, self)`. Async presentation is awaited by the scene, never by pure rules (see the known gap about CombatManager).
- **Errors:** `push_error` for programmer errors (unknown mission id), `push_warning` for content problems, and `EventBus.log_message` for player-facing text.
- **`FileAccess.store_*` returns bool** in 4.7; check it. Save atomically (write tmp, then rename), as SaveManager does.

## Data
- **Ids are snake_case slugs, prefixed by type:** `wpn_`, `arm_`, `acc_`, `con_`, `mat_`, `chip_`, `dsk_`, `key_` (items); `m01_`, `demo_` (missions); `q_` (quests); `dsp_` (dispatch); `r_` (rumours); `loot_`; `anc_<map>_<n>` and `rgn` (anchors and regions); `bl_` (blue-learnable enemy abilities); `add_` (Additions); `call_` (Daemon Caller summons).
- **Presentation JSON documents itself** with a `_note`/`_readme` key: `cues.json`, `vfx.json`, `status_looks.json`, `signage.json`.
- **HDR colours as strings:** `"#ff2e88*1.6"` (multiplier over 1 means glow), `$palette*k` inside vfx.
- **Story flags are namespaced:**
  - `npc:<id>:met|gift|fetch|fetched|repeat`
  - `found_<trigger_id>`
  - `trig:<map>:<region_id>:<i>`
  - `ixstate:<map_id>`
  - visited flags via `ExploreScene.visited_flag(map_id, obj_id)`
  - `<mission_id>_done` / `m01_done`
- **Text placeholders:** cues use `{name} {title} {amount} {status}`; signage uses `{soul_coins} {leader} {party_size} {time}`; cutscenes use `{PLACE} {MISSION} {ATTACKER} {TARGET} {ABILITY} {DAMAGE}`.

## Tests
- `tests/run_tests.gd` runs `tests/test_suite.gd` then `tests/test_world.gd`. Each file has `func check(cond: bool, msg: String)` and `test_<feature>()` funcs, called from `run()`.
- Battles are tested headless: `CombatManager.animate = false; CombatManager.autobattle = true; CombatManager.start_battle(g, units, mission, null, seed)`. `test_battles` runs 2 missions × 6 rosters × 3 seeds (36 battles) and prints the player win count.
- Screenshot harnesses (`tests/*_shot*.gd`, `vfx_showcase.gd`, `world_shots.gd`, `cutscene_frames.gd`) need a display: `xvfb-run godot --rendering-method gl_compatibility -s …`.
- Demo content is generated: `tools/demo/make_tactics_demo.py`, `make_block_demo.py`, `make_demo_worlds.py`. Change the generator, not the JSON.

## Docs
- Design docs are in `docs/design/`, research in `docs/research/`, lore in `docs/lore/LORE_DIGEST.md`.
- `ROADMAP.md` logs **Brian's calls** with dates and "Built <date>" lists. `BIG_IDEAS.md` tags each idea BUILT / HOOKED / NEW / seed. Proposed names are marked "awaiting approval".
- Lore statements carry source tags: FWB, NOX, COMP, README, `[BNV PROPOSAL]`.
- **Voice:** short plain sentences, dry humour in flavour text, British spellings in player-facing text ("rumour", "authorisation", "colour").
- README keeps "Tests" counts and feature lists current.

## Tooling
- Windows-first: `.bat` + `.ps1` pairs in `tools/` (`sync_assets`, `compile_pixelmatrix`, `convert_music`, `intake_dump`).
- Python 3 for generators and cutscene authoring (`tools/cutscene_builder/author.py`, `generate_all.py`).
- Asset intake: drop files into the Forge and the intake wizard copies them (never moves), slugs them and indexes them into `data/asset_index.json`. `assets/incoming/` is the raw dump area (ROADMAP: "Claude sorts, renames and indexes it").
