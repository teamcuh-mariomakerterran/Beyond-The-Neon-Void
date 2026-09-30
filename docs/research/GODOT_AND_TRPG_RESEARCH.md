# Godot 4.x Porting + Tactics RPG Design Research

_Compiled 2026-09-30 for Beyond The Neon Void (isometric, grid-based cyberpunk TRPG, FFT spiritual successor). The port is from Godot 4.2 GDScript to the latest stable 4.x._

---

## Part A: Godot facts

### A1. Latest stable release

| Item | Value |
|---|---|
| **Latest stable** | **Godot 4.7.2-stable**, released **2026-08-18**. It is the second maintenance release of 4.7 (4.7 released 2026-06-18, 4.7.1 on 2026-07-14). |
| Next branch | 4.8 is still in development (4.8-dev7 on 2026-09-29). It is not stable. |
| **Linux x86_64 editor zip** | `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` (verified: HTTP 200 on 2026-09-30) |
| Binary inside zip | `Godot_v4.7.2-stable_linux.x86_64` |
| Export templates | `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz` |

We checked the tags with `git ls-remote --tags https://github.com/godotengine/godot-builds`. The newest `*-stable` tag is `4.7.2-stable`, and the newest tag overall is `4.8-dev7`.

Release dates (from https://godotengine.org/download/archive/):
- 4.2: 2023-11-30
- 4.3: 2024-08-15
- 4.4: 2025-03-03
- 4.5: 2025-09-15
- 4.6: 2026-01-26
- 4.7: 2026-06-18
- 4.7.2: 2026-08-18

Sources:
- https://godotengine.org/article/maintenance-release-godot-4-7-2/
- https://godotengine.org/download/archive/4.7.2-stable/

The 4.7.2 blog post says it has "no known incompatibilities" with 4.7.x.

Headless CI usage:
```bash
curl -L -o godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip godot.zip && chmod +x Godot_v4.7.2-stable_linux.x86_64
./Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import          # builds .godot/ cache + generates .uid files
./Godot_v4.7.2-stable_linux.x86_64 --headless --path . --check-only --script res://path/to/file.gd   # parse check one script
./Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after 2     # boot the project once, surfaces autoload/parse errors
```
Run `--import` first. Class-name (`class_name`) resolution and UID lookup depend on the `.godot/` cache, so running `--check-only` on a fresh clone can report false "identifier not declared" errors.

### A2. Porting checklist from 4.2 to 4.7.2 (GDScript projects)

Official migration guides:
- https://docs.godotengine.org/en/4.3/tutorials/migrating/upgrading_to_godot_4.3.html
- https://docs.godotengine.org/en/4.4/tutorials/migrating/upgrading_to_godot_4.4.html
- https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html
- https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html
- https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html

#### Project-level items
- [ ] **`project.godot`**: set `config/features=PackedStringArray("4.7", "Forward Plus")`. Use `"GL Compatibility"` or `"Mobile"` instead of `"Forward Plus"` if you pick those renderers. For a 2D isometric game, Compatibility is a valid choice if you want web export or low-end hardware. `config_version=5` stays unchanged.
- [ ] **UID files (4.4)**: every script and shader now gets a sibling `*.gd.uid` / `*.gdshader.uid`. **Commit them to git.** Move files inside the editor, or move the `.uid` file along with the file. Opening the project once, or running `--import`, generates them.
- [ ] **Scene format (4.6)**: `.tscn` files no longer contain `load_steps`, and unique node IDs are saved. The editor rewrites files on save. Expect a big diff the first time you save.
- [ ] Scene and resource references prefer `uid://`. Hand-written `.tscn` or `.tres` files may use either `uid://` or `res://` paths.

#### TileMap and 2D (the biggest change for this game)
- [ ] **4.3: `TileMap` is deprecated in favor of `TileMapLayer`.** Each layer is now its own node. The API drops the `layer` argument: `set_cell(coords, source_id, atlas_coords, alt)`, `get_cell_source_id(coords)`, `get_used_cells()`, `local_to_map()`, `map_to_local()`. The editor has "Extract TileMap layers as individual TileMapLayer nodes" (select the TileMap, open the toolbar menu). New code must use `TileMapLayer`.
- [ ] **4.5: TileMapLayer physics chunking is on by default.** `get_coords_for_body_rid()` returns different values now. `collision_quadrant_size` / `physics_quadrant_size` controls chunking.
- [ ] 4.6: scene tiles can be rotated. 4.7 adds a 2D scene "paint mode" for scattering objects.

#### Core, Resources and files
- [ ] **4.4: every `FileAccess.store_*()` now returns `bool`.** This is compatible with GDScript. Check the return value in SaveManager to detect write failures.
- [ ] **4.5: `Resource.duplicate(true)` no longer deep-copies external (file-backed) sub-resources.** Use the new `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` when you need a true clone. This matters for ClassResource, UnitStats and weapon instances. If you duplicate a template to create a runtime copy, audit every call site.
- [ ] 4.4: `OS.read_string_from_stdin(buffer_size)` now requires its argument.
- [ ] 4.4: `Curve` enforces `min_value`/`max_value`. Stat or XP curves with values outside `[0,1]` need their range set.
- [ ] 4.5: `Node.get_rpc_config()` is renamed to `get_node_rpc_config()`. `JSONRPC.set_scope()` is replaced by `set_method()`.
- [ ] 4.7: `Object.is_class()` now takes a `StringName`. It still works from GDScript.

#### GDScript language (new features and stricter rules)
- [ ] **4.4: typed dictionaries** such as `var loot: Dictionary[StringName, ItemResource]`. Use them for registries like ClassLibrary and item databases, which gives safer data and better autocomplete. Typed dictionaries can also be exported.
- [ ] **4.4: `@export_tool_button("Label", "Icon") var btn = some_callable`** creates inspector buttons in `@tool` scripts. It is handy for "Rebuild grid" or "Validate class library" actions.
- [ ] **4.5: `@abstract` classes and methods.** Mark bases like `Ability`, `AIBehavior` and `JobHandler` strategies as abstract.
- [ ] **4.5: variadic functions** with `func log(msg, ...args)`, where the rest parameter is an `Array`.
- [ ] 4.5: script backtraces (`Engine.capture_script_backtraces()`) are available in release builds, which helps crash logging.
- [ ] **4.7: an overridden function with a typed return must have an explicit `return` on every path.** This used to be lenient. Fix any errors this flags.
- [ ] **4.7: assigning an element of a packed array (`obj.packed_prop[i] = x`) no longer calls the property setter.** If a setter emits `changed` or recomputes stats, reassign the whole array instead.
- [ ] 4.3 and later add stricter warnings, for example for unused or shadowed variables and confusable local declarations. Treat warnings as a to-do list, not as blockers.
- [ ] 4.2-era `Callable` / `signal.connect(func)` / `await` syntax is unchanged. No signal API break affects plain GDScript.

#### Navigation and pathfinding
- [ ] **4.6: `AStar2D/3D.get_point_path()` and `AStarGrid2D.get_id_path()`/`get_point_path()` return an EMPTY path when the start point is disabled or solid.** Units usually mark their own tile solid, so un-solid the start cell before querying or you will get no path. This is the most likely silent bug in the port.
- [ ] 4.5: NavigationServer2D is now a dedicated 2D server, and region updates are asynchronous. This only matters if you use NavigationRegion2D. It does not affect grid AStar.
- [ ] AStarGrid2D already had `CELL_SHAPE_ISOMETRIC_RIGHT/DOWN` and `DIAGONAL_MODE_*` in 4.2. 4.3 and later add `fill_solid_region`, `fill_weight_scale_region` and `get_point_data_in_region`, all of which the TRPG can use.

#### Animation, UI and rendering behavior
- [ ] 4.3: AnimationPlayer capture mode was reworked, and AnimationTree blending changed. Re-test transitions.
- [ ] 4.6: `AnimationPlayer.current_animation`, `assigned_animation` and `autoplay` are `StringName` now. This is fine in GDScript. 4.7: `AnimationNodeBlendSpace` uses a sync-mode enum instead of `sync: bool`.
- [ ] 4.3: `auto_translate` is deprecated in favor of `auto_translate_mode`. The default font outline color changed from white to black.
- [ ] **4.6: glow defaults to Screen blend and is applied before tonemapping, so it looks brighter.** Retune any neon WorldEnvironment glow. 4.7: `LinearToSRGB` no longer clamps. **4.7 also removes CanvasItem line antialiasing**, so `draw_line(..., antialiased=true)` produces thinner lines. Check grid overlays drawn with `_draw()`.
- [ ] 4.7: RichTextLabel `UPDATE_WIDTH_IN_PERCENT` is renamed to `UPDATE_WIDTH_UNIT`. Mouse and keyboard device IDs are named constants now, which matters if you compare `event.device == 0`.
- [ ] 4.7: `AudioStreamPlayer.area_mask` default changed from 1 to 0 (this only affects 3D area audio).

#### Physics and platform
- [ ] 4.4: Jolt is available built in. 4.6: Jolt is the default **3D** engine for new projects. This game is 2D (`CharacterBody2D`), so Godot Physics 2D is unaffected.
- [ ] 4.6: new Windows projects default to D3D12. The macOS minimum is 11 as of 4.7. Android no longer requests permissions automatically (4.3).

#### Recommended port procedure
1. Back up the project and delete `.godot/`.
2. Open the project in 4.7.2, or run `--headless --import`, and let it upgrade the project and generate `.uid` files.
3. Run Project > Tools > "Upgrade Project Files" so every resource is re-saved in the current format.
4. Convert TileMap to TileMapLayer nodes and update scripts to drop the layer argument.
5. Grep for `duplicate(true)`, `get_id_path`/`get_point_path`, `store_`, `get_rpc_config`, `antialiased`, `device ==` and `sync =`.
6. Fix every parser error, then work through the warnings.
7. Add typed dictionaries and `@abstract` to the core data layer.

### A3. Godot features for an isometric TRPG and editor tooling

**Isometric maps**
- Isometric `TileMapLayer`:
  - In the TileSet, set `tile_shape = TILE_SHAPE_ISOMETRIC`, `tile_layout = DIAMOND_DOWN` (or STACKED) and `tile_size` to something like `(64,32)`.
  - Use one TileMapLayer per logical layer (ground, cliffs, props, overlay).
  - Enable `y_sort_enabled` on each layer and on the parent Node2D. Units must be children of a y-sorted node that shares the same parent.
  - Use each tile's `texture_origin`/`y_sort_origin` so tall tiles sort correctly.
  - Use `z_index` for "height levels", and draw each elevation as its own TileMapLayer shifted by `-height_px * level`.
  - Docs: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html
- Store height as TileSet **custom data layers**, for example `height:int`, `terrain:StringName`, `blocks_los:bool` and `move_cost:float`. Read them with `get_cell_tile_data(coords).get_custom_data("height")`.
- **Pathfinding**: AStarGrid2D cannot express height differences between neighbors. Options:
  - (a) Use `AStar2D` with custom `_compute_cost` / `_estimate_cost` overrides (subclass `AStar2D`) and connect points only where `abs(h1 - h2) <= unit.jump`. This makes the graph per-unit, or you can rebuild the connections lazily.
  - (b) Use AStarGrid2D with `cell_shape = CELL_SHAPE_ISOMETRIC_DOWN`, `fill_weight_scale_region` for terrain costs, and a post-filter pass for jump limits.
  - For FFT-style move range, a Dijkstra/BFS flood fill in GDScript over under 1,000 cells is fast and simpler. Use AStar only for AI path queries.
- Picking in isometric: use `local_to_map(get_local_mouse_position())` on the topmost height layer first, then fall back to lower layers.

**Data**
- Custom `Resource` classes (`class_name ItemResource extends Resource` plus `@export`) are saved as `.tres`, which is diffable text. Keep `ResourceLoader.load(path, "", CACHE_MODE_REUSE)` for loading and `duplicate_deep()` for runtime instances (4.5+).
- Typed dictionaries (4.4) work well for registries.
- `ResourceSaver.save()` works at runtime, so an in-game editor can write `.tres` into `user://`. `res://` is read-only in exported builds.
- Export `Array[AbilityResource]` for typed inspector lists.

**Editor tooling**
- **EditorPlugin vs. an in-game runtime editor**:
  - An EditorPlugin (`addons/…/plugin.cfg`, `@tool`) lives in the Godot editor. It gets the Inspector, undo (`EditorUndoRedoManager`) and the FileSystem dock for free, but it is not shippable to players and is limited to the Godot UI.
  - A **runtime editor** is a normal scene with Controls. It can ship later as a modding or campaign tool, you control its look completely, and it runs in the 4.4+ embedded game window. You write your own undo with the `UndoRedo` class, which is available at runtime.
  - **Recommendation: build the campaign editor as a runtime scene** (`res://tools/editor/`) that reads and writes the same `.tres` Resources. Add a thin EditorPlugin later only for a button that launches it.
- Drag and drop inside the UI: override `_get_drag_data(at_pos)` (and call `set_drag_preview(ctrl)`), then `_can_drop_data(at_pos, data)` and `_drop_data(at_pos, data)` on the target Control. Docs: https://docs.godotengine.org/en/stable/classes/class_control.html
- **Dropping files from the OS**: `get_window().files_dropped.connect(func(paths: PackedStringArray): ...)`. Load images with `Image.load_from_file(path)` and `ImageTexture.create_from_image()`, and audio with `AudioStreamWAV.load_from_file()` / `AudioStreamOggVorbis.load_from_file()` / `AudioStreamMP3.load_from_file()` (the runtime loaders were added in 4.2 to 4.4). Copy the files into `user://` or into `res://` in editor or dev builds. Docs: https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-signal-files-dropped
- Sprite sheets: `AtlasTexture` and `SpriteFrames.add_frame()` can build animations at runtime from a dropped sheet if the user enters the columns, rows and fps.
- `@export_tool_button` (4.4) adds one-click actions to the Inspector. 4.5's `FoldableContainer` gives accordion panels for the editor UI. 4.6 adds `pivot_offset_ratio`. 4.7 adds Control offset transforms, which animate UI "juice" without breaking layout.
- `Tree`, `ItemList`, `GraphEdit` (dialog and quest graphs), `CodeEdit` (trigger scripts), `TabContainer` and `SplitContainer` cover the editor's layout needs. `GraphEdit` suits quest prerequisite chains and dialog trees.

**Look and feel**
- **Neon, CRT and glitch**:
  - Use `canvas_item` shaders on a full-screen `ColorRect` in a `CanvasLayer`, reading `hint_screen_texture`. Techniques: chromatic aberration, scanlines, barrel distortion, RGB split on a noise-driven glitch timer, pixel-sort bands, dithering.
  - 2D glow: turn on WorldEnvironment glow with `background_mode = Canvas` and push HDR 2D via `rendering/viewport/hdr_2d` (4.2+). Modulate values above 1.0 then bloom. Retune glow for 4.6's new Screen blend.
- **CompositorEffect** (4.3+, Forward+/Mobile) runs compute-shader post effects. It is mostly aimed at 3D. For 2D, prefer screen-texture shaders or a SubViewport pipeline.
- **SubViewport tricks**:
  - Render the battlefield at low resolution into a SubViewport, then upscale with a CRT shader.
  - Render unit portraits live.
  - Draw a minimap with a second camera.
  - Build a "digimancy vision" layer: render only a certain `visibility_layer` in a second SubViewport and composite it in with a glitch mask.
- 4.5 adds **stencil buffer** support in spatial shaders, which works for see-through-walls silhouettes if you go 2.5D. `CanvasGroup` gives unit outlines. `BackBufferCopy` supports hologram-style distortion. `GPUParticles2D` with trails handles data sparks, and `Line2D` handles attack beams.
- 4.7 adds HDR output and inline shader previews, which speed up shader iteration.

---

## Part B: Tactics RPG design survey

### B1. Standout mechanics by game

| Game | Standout mechanic(s) worth studying |
|---|---|
| **Final Fantasy Tactics** | Job tree with cross-class ability slots (Action, Reaction, Support, Movement). JP spillover to allies. Height and facing affect hit chance. Charge time (CT) with visible turn order. Zodiac compatibility. Recruiting and poaching. Brave and Faith as stats that change the story. |
| **FFT Advance / A2** | **Dispatch missions** (auto-resolved by stats and time). The Laws/Judge system (rule restrictions per battle). The Bazaar, which crafts from loot. Clan-wide skills. |
| **Tactics Ogre: Reborn** | CHARIOT (rewind up to 50 turns). WORLD (revisit story branches). Branching routes decided by moral choices. Class levels shared across the class. Tarot buff cards on the field. |
| **Triangle Strategy** | The **Scales of Conviction**: party members vote on big decisions, and the player can persuade voters with information gathered during exploration. Conviction stats (Utility, Morality, Liberty) are tracked invisibly. Elevation and follow-up attacks. Quietus. |
| **Disgaea** | Geo panels and geo symbols (terrain color rules as a puzzle layer). Throwing and stacking units. Item World (procedural dungeons inside an item to level it). Absurd numbers. A Dark Assembly that votes on legislation. |
| **Fire Emblem: Three Houses / Engage** | Support and bond conversations tied to combat buffs. Permadeath with Divine Pulse rewind. Battalions and gambits. Engage rings, which fuse with heroes of the past. The weapon triangle and break. |
| **XCOM 2** | Hit chances shown as percentages. Overwatch. Concealment ambush. Timer pressure. Soldier customization and bonds. Avenger base building. Chosen nemeses who learn. |
| **Into the Breach** | **Perfect information**: enemy intents shown a turn ahead. Pushes and knockback as the core verb. Tiny 8x8 boards. Time-travel pilots. |
| **Mario + Rabbids** | Team jumps and dash through enemies in the movement phase, with free movement inside a radius. Very low friction. |
| **The Banner Saga** | Strength doubles as HP (damage lowers your damage output). Alternating turns regardless of unit count. Caravan supplies and morale. Permanent story deaths. |
| **Slay the Spire / Wildfrost** | Deckbuilding with energy. Visible enemy intents. Relics that bend rules. Wildfrost's **counter timers** (units act when their counter reaches 0) and snow freeze on counters. |
| **Unicorn Overlord** | Squad programming with gambit-like conditional **tactics** (e.g. "if an ally is under 50% HP, heal"). Auto-battles resolve in a few seconds. Real-time overworld movement. |
| **Symphony of War** | Squads as units, with formation grids inside each squad. Morale. Many unit types. |
| **Jagged Alliance 3** | Mercenaries with personalities who dislike each other and quit. Real-time exploration switching to turn-based combat. Morale. Interrupts. Ballistic hit locations. |
| **Othercide** | HP is the action resource (heal only by sacrificing units). A timeline where you can **interrupt** and delay enemies. Grim memory-based permanent upgrades. |
| **Tactical Breach Wizards** | Free, unlimited undo within your turn. Defenestration and push combos. **Foresight** previews of results. Very funny writing that sits on top of the tactics. |
| **Fae Tactics** | Environmental elemental combos. Recruiting enemies you defeat. Lush pixel art. |
| **Also worth a look** | *Wargroove* (critical-hit conditions per unit). *Battle Brothers* (a brutal company-management loop). *Invisible, Inc.* (stealth tactics with an alarm timer). *Gears Tactics* (no grid, action economy). *Midnight Suns* (card-driven tactics). *Hard West 2* (the Bravado action refund). *Band of Crusaders*. *Mechabellum*. |

### B2. Gaps: what the genre rarely or never does
1. **Deceptive information as a mechanic.** The UI tells the truth in almost every TRPG. Hit % never lies, and intel is never wrong. Nobody makes the UI itself an in-fiction, possibly compromised source that the player learns to distrust.
2. **Two simultaneous truths.** Branching stories exist (Tactics Ogre, Triangle Strategy), but a single battle almost never exists as two overlapping states that the player resolves.
3. **Moral cost as a resource spent in combat.** Choices are usually story votes. They are seldom a currency you burn mid-battle, where power now costs humanity later.
4. **Persistent social bonds formed through downtime rituals** (a tavern, drinking) that change combat verbs. Fire Emblem has support bonus stats, not new combo actions.
5. **Consequence-rich dispatch.** Dispatch is almost always a timer plus a dice roll. It never creates new maps, rumors, rivals or injuries that feed back into the main story.
6. **Weapons with memory.** Weapon leveling exists (Disgaea's Item World, FE forging), but weapons don't remember what they killed, where, or who held them.
7. **Surveillance as a board state.** A stealth alarm meter exists (Invisible, Inc.), but a map-wide, state-owned "watcher" with its own turn and logic that rewrites the rules is rare.
8. **Asymmetric information between allies.** Each unit has perfect shared knowledge. There are no "only the hacker sees the trap" mechanics with a need to tell the others.
9. **Rewinding as diegetic tech with a cost.** CHARIOT and Divine Pulse exist but are free out-of-fiction tools.
10. **Card decks that interact with the grid.** Most card tactics games bolt a hand onto units. Very few let cards be physically placed as tiles, traps or terrain.
11. **Comedy as a mechanic.** Humor lives in dialog only. No TRPG rewards badly timed jokes, pratfalls or drunken stumbles in a systemic way.
12. **Enemies with an ideology you can shift mid-fight** (persuading conscripts to defect based on what they believe).

### B3. Fifteen implementable mechanic pitches for Beyond The Neon Void

Each pitch has a name, a rules sketch, and implementation notes for our Godot architecture.

1. **Doctrine Overlay (the lying UI).**
   - Rules: While a map's Doctrine Relay tower stands, the HUD's hit %, damage previews and enemy HP bars are fed by the state. They skew by up to ±25% in the state's favor, and some enemies appear as "civilians".
   - Countermeasures: a Digimancer can "jack" the relay (a 2-turn channel), or a unit with the `Clear Eyes` support skill sees true values for itself.
   - Implementation: add an `InfoFilter` service between CombatManager and the HUD. The HUD asks `InfoFilter.displayed_hit(unit, target)`, which returns `true_value` plus any distortion. This is cheap and very on-theme.

2. **Two Truths Battlefields (Schrödinger maps).**
   - Rules: Some maps load two TileMapLayer sets, "Official" and "Street". Tiles, cover and objectives differ. Each turn a truth token flips based on which faction controls the most **Narrative Nodes**.
   - Units standing on tiles that don't exist in the current truth fall to a lower height layer and take damage.
   - Implementation: add two TileMapLayer groups with `visible`/`collision_enabled` toggles, plus a shader dissolve between them.

3. **Essence Ledger (humanity as a combat currency).**
   - Rules: Every unit has `Essence` (0–100). Powerful abilities, especially digimancy, can be overcast by spending Essence for +50% effect.
   - Essence regenerates only through tavern downtime. At 0, the unit becomes **Hollowed**: AI-controlled next battle, with an unlockable redemption mission.
   - The villain's factory extracts essence, and the player can do a smaller version to themselves.
   - Implementation: an `essence` stat on UnitStats and an `overcast` flag on AbilityResource.

4. **Digimancy Code Tiles.**
   - Rules: Digimancers don't cast at units. They **rewrite tile properties**: flip a tile's height, make a tile "null" (impassable), fork a tile (a unit standing there acts twice at half power), or loop a tile (a unit that enters is teleported to a linked tile).
   - Changes last N turns and render with a glitch shader.
   - Implementation: tile custom data plus a `TileEffect` Resource stack per cell, and recompute AStar weights on change.

5. **Tarot of the Grid (card class that places cards on the board).**
   - Rules: The card class (a "Dealer") builds a 20-card deck, and each card is usable once per battle. Some cards are **played face-down onto tiles** as traps, blessings or bluffs, and enemies can't tell which.
   - Enemy AI weighs face-down cards with a risk score, and bluff cards exploit it.
   - Combos: playing a pair or straight in consecutive turns triggers bonus "hands".
   - Implementation: `DeckResource`, `CardResource` (`effect: Script`, `placement: HAND|TILE|UNIT`), and `CardManager` per unit.

6. **Last Call (Drunk Meter).**
   - Rules: Before a mission, the party drinks at the bar. Each unit picks a drink with its own buzz level. Buzz gives +Brave and crit, costs accuracy, and unlocks slapstick **Stumble** actions such as a random-direction shove that can knock enemies off ledges.
   - Some drunken **Duo Techs** only work when two bonded units are both buzzed.
   - The hangover is a debuff on the next dispatch.
   - Implementation: `buzz` stat, a StumbleAbility with a weighted RNG direction, and a BondMatrix check.

7. **Rumor Mill Dispatch.**
   - Rules: Dispatch missions (FFTA2-style timers plus a stat check) return loot **and rumors**.
   - Rumors are two-truth intel cards, such as "The convoy at Sector 9 has 3 guards" and "…or 9". A rumor becomes true or false when you deploy, weighted by the dispatched unit's `Perception` and by how drunk they were.
   - Failed dispatches can create **Wanted** units who get hunted in later maps, or captured units who become rescue maps.
   - Implementation: `DispatchResource` (duration, stat weights, loot table, rumor table) and a `RumorResource` with `true_chance`.

8. **Weapon Memory and Grudge.**
   - Rules: Weapons log their kills by enemy faction. At thresholds they gain an **Epithet** (for example "Doctrine-Breaker", +15% vs. Doctrine).
   - Weapons carry a hidden "Grudge" against whoever last disarmed or broke them.
   - Crafting timing matters: crafting at level 10 keeps 1 epithet slot, and waiting to level 20/30/50 keeps 2/3/4 slots (a hard-coded reward for patience, consistent with the design doc's max-stat rule). Memory transfers through crafting as a "ghost" line of text.
   - Implementation: `WeaponInstance` Resource with `kills: Dictionary[StringName, int]` (a typed dict from 4.4) and an `epithets: Array[EpithetResource]`.

9. **The Watcher (the surveillance turn).**
   - Rules: The state has its own slot in the turn order: a drone eye with a sweeping vision cone.
   - Units seen while committing crimes raise **Heat**. At Heat thresholds, the map's rules change: curfew (move −1), reinforcements, and a Judge unit that enforces "laws" (a nod to FFTA2's Laws). Players can break the law on purpose to trigger Heat when it helps them.
   - Implementation: a `WatcherActor` in CombatManager's CT queue, a vision cone via a raycast over the grid, and a `LawResource` list.

10. **Propaganda Duel (convert conscripts mid-battle).**
    - Rules: Doctrine grunts have `Belief` (0–100). Talk-type abilities, which use evidence gathered in the hub (in the spirit of Triangle Strategy's persuasion), lower Belief. At 0 they defect or flee.
    - Enemy officers raise Belief with broadcasts.
    - Killing converts, or sparing Doctrine officers, feeds the ending.
    - Implementation: a `belief` stat on enemies, `PersuadeAbility`, and `EvidenceResource` items.

11. **Two-Witness Replay (diegetic rewind with a cost).**
    - Rules: After a unit dies, you may "re-render" the last 3 turns from a different party member's memory. The rewind is real, but the replay uses **that unit's** version of events, so enemy positions shift slightly (unreliable memory).
    - Each use costs Essence from the rememberer.
    - Implementation: snapshot the battle state per turn (a `BattleSnapshot` Resource). On replay, restore it and apply a jitter to enemy positions within 1 tile.

12. **Asymmetric Sight Network.**
    - Rules: Only digimancers or hackers see "code layer" objects: traps, hidden loot and ghost enemies. They must spend an action to **Share** that knowledge, which tags the objects for allies until the end of the turn.
    - This creates information logistics instead of perfect knowledge.
    - Implementation: a per-faction and per-unit `known_entities` set, with a second SubViewport "code vision" rendered only for the active unit.

13. **Essence Extraction Stations (map objective and moral lever).**
    - Rules: Factory maps have extraction pods holding captives. Freeing a pod costs 2 turns and yields a potential recruit. **Draining** a pod instantly fully heals the party and grants power, at a huge Essence and Karma cost.
    - The villain's digimancer grows stronger for each pod left untouched when the timer ends.
    - This is a mid-battle three-way choice, not a dialog vote.
    - Implementation: an `Interactable` prop with a `choices: Array[ChoiceResource]` and a map-level `TimerCondition`.

14. **Hangover Morning (tavern downtime as a turn-based mini-game).**
    - Rules: Between chapters, the hub is a bar played as a tiny, turn-based **social** grid. Choosing seats sets bonds (units in adjacent seats gain Bond XP).
    - Bond thresholds unlock Duo Techs (combo attacks) and "Bar Stories", humorous vignettes that reveal which "truth" a character believes.
    - Implementation: reuse the same grid, turn and ability systems with social abilities (Toast, Roast, Tell a Lie, Buy a Round). It reuses code and is very on-brand ("Cheers meets cyberpunk").

15. **Microchip Grafting Board.**
    - Rules: Class abilities unlock at a terminal by slotting microchips (dropped by enemies) into a **circuit-board grid** (a polyomino puzzle, like Backpack Hero or Tetris-style inventories).
    - Chips adjacent along traces share modifiers. A chip from a boss carries that boss's quirk. Corrupted chips give strong abilities with a glitch side effect (random targeting 10% of the time).
    - Implementation: `ChipResource` (shape as `Array[Vector2i]`, `ability: AbilityResource`, `corruption: float`) and a `ChipBoard` Control with drag-and-drop (`_can_drop_data`/`_drop_data`).

**Bonus pitches**
- **Soul Coin Inflation**: the state devalues soul coins after each Heat spike, which pushes players to spend or convert to crafting mats.
- **Broadcast Interrupts**: the war news plays on in-map screens and can buff or debuff as it reports victories or losses. This carries the "overseas war" background into gameplay.
- **Perfect-Info Mode toggle**: an accessibility option that disables Doctrine Overlay distortions for players who dislike deception mechanics.

### B4. Design takeaways to adopt
- Keep FFT's CT turn order, height and facing, and a job tree with cross-class ability slots. Show the turn order visibly.
- Borrow from Into the Breach and Tactical Breach Wizards: telegraph enemy intents and allow free undo within the movement phase. **Truthful** telegraphs should be the default. The *lying* telegraph is only a map-state exception (the Doctrine Overlay), so the deception feels deliberate, not unfair.
- Borrow from FFTA2 and Unicorn Overlord: dispatch plus gambit-like AI for auto-resolved and dispatched fights. The same AIBehavior Resources can drive both.
- Borrow from Triangle Strategy: evidence-based persuasion, used for two-truths story votes among the drinking buddies.
