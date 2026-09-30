# Migration: original prototype → Godot 4.7

The originals are archived untouched in `legacy/original_gd/`. A `.gdignore` there keeps Godot from parsing them.

## Why this was a rebuild, not a straight port

Porting 4.2 → 4.7 itself was minor. The originals had problems no version bump would fix:

- **Pasted AI-chat text in the code.** `CombatManager.gd` contained `>>>`, `<<<END>>>`, "Wait, I noticed…" and `PS-END`.
- **Files that were only notes.** `Ability.gd` and `ClassResource.gd` contained no code at all.
- **Broken syntax.** Stray `)` lines, mis-indented lines, and duplicated functions (`resolve_attack` ×2, `_ready` ×2, `get_defense_power` ×2).
- **Truncated files.** `DispatchManager.gd` and `ForgeManager.gd` stopped mid-function.
- **Three incompatible grid classes** that disagreed on the isometric projection.
- **Missing classes and autoloads** that code referenced: `TurnManager`, `UnitManager`, `Visuals`, `PlayerStats`, `VendorItemRow`, `IsometricGrid.singleton`.
- **Three currencies:** credits, gold and soul coins.
- **A "19 classes" claim** against a 45-entry list with duplicates.

The rebuild keeps the **architecture from the README**: singleton orchestration, the ClassResource → ClassLibrary → UnitStats → Unit bridge, JobHandler-driven ability resources, and the Kinetic/Time/Terrain split. It also keeps the names, numbers and flavour, and makes all of it run.

## File map

| Original | Now | Notes |
|---|---|---|
| AIBehavior.gd | `src/combat/ai/ai_behavior.gd` | Utility AI with tactical positioning: threat map, cover, height, preferred range, hit-and-run. Satisfies the README directive. |
| AggressiveBehavior.gd | `src/combat/ai/aggressive_behavior.gd` | Weights preset. |
| CautiousBehavior.gd | `src/combat/ai/cautious_behavior.gd` | Keeps `preferred/min_distance` (as `ideal_distance`/`min_distance`). |
| — | `tactical_behavior.gd`, `support_behavior.gd` | New archetypes. |
| Ability.gd (notes only) | `src/data/ability.gd` | Data-driven: range, AoE shapes, charge time, statuses, specials. |
| KineticAbilities.gd | `src/combat/abilities/kinetic_ability.gd` | Kinetic Charge's `1.5^tiles` overflowed, so it's now linear and capped at x2. Pull, repulse, and slam damage doubled by Unstable. |
| TimeAbilities.gd | `src/combat/abilities/time_ability.gd` | Delay Thread, Stitch Turn, Rewind (now also a cheat-death save point), CT shift. |
| TerrainAbilities.gd | `src/combat/abilities/terrain_ability.gd` | Fault Line, Isolate Elevation, Warp Coordinates, hazards, plus geomancy. |
| ClassResource.gd (notes only) | `src/data/class_resource.gd` | Multiplicative stat scaling, growth, weapons, FFT unlock requirements. |
| ClassLibrary.gd | `src/autoload/class_library.gd` + `data/classes.json` | 35 playable classes. See `docs/design/CLASSES.md`. |
| JobData.gd | merged into ClassResource | Duplicate concept. |
| JobHandler.gd | `src/combat/job_handler.gd` | Builds the command list (innate + learned + secondary job + cards). |
| UnitStats.gd | `src/combat/unit_stats.gd` | Single-pass float math, rounded once and clamped. The overflow/rounding directive is covered by tests. |
| Unit.gd | `src/combat/unit.gd` | A Node2D now (grid tweening needs no physics). Statuses, facing, CT, summons, revive. |
| CombatManager.gd | `src/autoload/combat_manager.gd` + `src/combat/turn_queue.gd` + `damage_calculator.gd` | FFT CT clock, charged casts, win/lose conditions. Runs headless for tests. |
| IsometricGrid.gd, BattleMap.gd, BattleMap_New.gd | `src/grid/isometric_grid.gd` (data) + `src/grid/battle_map.gd` (scene) + `tile_view.gd` | One projection, height-aware picking, Dijkstra movement with a jump rule, LOS, directional cover. |
| BattleSpawnSystem.gd | inside `battle_map.gd` (`_spawn_units`) and `CombatManager.spawn_unit` | |
| HighlightManager.gd | `src/grid/highlight_manager.gd` | Layered highlights drawn on tiles (correct occlusion). |
| InputBridge.gd, InputManager.gd | inside `battle_map.gd` + `src/core/input_actions.gd` | Merged. Input actions are registered in code. |
| CameraController.gd | `src/world/camera_controller.gd` | Pan, drag, zoom, follow, bounds. |
| CameraManager.gd | `src/autoload/camera_manager.gd` | Shake via `EventBus.camera_shake`. |
| DamageText.gd | `src/ui/damage_text.gd` | |
| UnitHUD.gd | `src/ui/unit_hud.gd` (overhead) + `src/ui/battle_hud.gd` (panel) | Split into small overhead bars and a full panel. |
| UIManager.gd | `src/autoload/ui_manager.gd` | Now a router to the active HUD. |
| GameManager.gd | `src/autoload/game_manager.gd` | Roster, inventory (stacks + gear instances), soul coins, microchips, flags, Drunken Oracle unlock. |
| CampaignManager.gd | `src/autoload/campaign_manager.gd` | Missions, rewards, world clock. |
| ProgressionSystem.gd | `src/progression/progression_system.gd` | Polynomial XP curve (1.5^level overflowed), class levels, terminal learning. |
| SaveGame.gd, SaveManager.gd | `src/autoload/save_manager.gd` | JSON slots, written atomically. No `.tres` from user://, because those can run scripts. |
| SceneManager.gd, TransitionLayer.gd | `src/autoload/scene_manager.gd`, `transition_layer.gd` | |
| DispatchManager.gd (truncated) | `src/autoload/dispatch_manager.gd` | Real-time timers, stat-weighted success, loot + rumours. |
| ForgeManager.gd (truncated) | `src/autoload/forge_manager.gd` | Levels 1–50, evolve at 10+, potential rewards patience. |
| VendorSystem.gd | `src/autoload/vendor_system.gd` + `data/vendors.json` | |
| EquipmentManager.gd | `src/combat/equipment_manager.gd` | Specialty weapons: +15% stats, +25% class XP. |
| ItemResource.gd, CardResource.gd, DeckResource.gd, MissionResource.gd, StatusEffect.gd, GameData.gd | `src/data/*` | CardResource now *is* an Ability. |
| HubWorld.gd | `src/world/hub_menu.gd` (menu hub for now) | A walkable hub can replace it later. |
| InteractionTrigger.gd | `src/world/interaction_trigger.gd` | Hidden loot with found/empty text, one-shot per save. |
| MapEditor.gd, AssetInjectionEditor.gd | `src/tools/*` = **Neon Forge** | The full editor. |

## Godot 4.2 → 4.7 specifics applied
- `config/features` set to `4.7` with Forward+ and `hdr_2d` (neon glow).
- `FileAccess.store_*` return values are checked (they return `bool` since 4.4).
- The `@abstract` base class is used (4.5).
- `.uid` files are committed next to scripts (4.4+).
- No TileMap (deprecated in 4.3). Tiles are drawn per-cell with texture support; TileMapLayer can be adopted later if we want the TileSet editor.
- Autoload scripts carry no `class_name`, which avoids name clashes.
- `get_tree().scene_changed` is used for transitions.
