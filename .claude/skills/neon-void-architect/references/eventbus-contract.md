# EventBus contract (`src/autoload/event_bus.gd`)

Generated from the 2026-10-07 snapshot with `scripts/eventbus_audit.py --json`. Re-run the script on the live repo before relying on this; the script is the source of truth.

Legend: **no listener** = emitted but nobody connects (open hook for new features: UI toasts, achievements, replay log). Emit/listen paths are relative to the repo root.

## Battle flow

| Signal | Emitted by | Listened by |
|---|---|---|
| `battle_started(battle_id: String)` | `src/autoload/combat_manager.gd` | `src/autoload/cues.gd` |
| `battle_ended(victory: bool, battle_id: String)` | `src/autoload/combat_manager.gd` | `src/autoload/cues.gd`<br>`src/autoload/quest_manager.gd` |
| `round_advanced(tick: int)` | `src/autoload/combat_manager.gd` | **no listener** |
| `turn_started(unit: Node)` | `src/autoload/combat_manager.gd` | `src/grid/battle_map.gd` |
| `turn_ended(unit: Node)` | `src/autoload/combat_manager.gd` | **no listener** |
| `turn_order_changed(forecast: Array)` | `src/autoload/combat_manager.gd`<br>`src/combat/abilities/time_ability.gd` | `src/grid/battle_map.gd` |

## Units

| Signal | Emitted by | Listened by |
|---|---|---|
| `unit_moved(unit: Node, from_cell: Vector2i, to_cell: Vector2i)` | `src/combat/unit.gd` | `src/grid/battle_map.gd` |
| `unit_damaged(unit: Node, amount: int, is_critical: bool)` | `src/combat/unit.gd` | `src/autoload/cues.gd`<br>`src/grid/battle_map.gd` |
| `unit_healed(unit: Node, amount: int)` | `src/combat/unit.gd` | `src/autoload/cues.gd`<br>`src/grid/battle_map.gd` |
| `unit_missed(unit: Node)` | `src/data/ability.gd` | `src/grid/battle_map.gd` |
| `unit_died(unit: Node)` | `src/combat/unit.gd` | `src/autoload/cues.gd`<br>`src/autoload/quest_manager.gd`<br>`src/grid/battle_map.gd` |
| `unit_status_applied(unit: Node, status_id: String)` | `src/combat/unit.gd` | `src/autoload/cues.gd`<br>`src/grid/battle_map.gd` |
| `unit_status_removed(unit: Node, status_id: String)` | `src/combat/unit.gd` | **no listener** |

## Abilities

| Signal | Emitted by | Listened by |
|---|---|---|
| `ability_used(caster: Node, ability: Resource, cell: Vector2i)` | `src/autoload/combat_manager.gd` | **no listener** |
| `ability_charging(caster: Node, ability: Resource, cell: Vector2i, ticks: int)` | `src/autoload/combat_manager.gd` | **no listener** |
| `card_spent(unit: Node, card: Resource)` | `src/combat/job_handler.gd` | **no listener** |

## Grid

| Signal | Emitted by | Listened by |
|---|---|---|
| `grid_changed(cells: Array)` | `src/autoload/combat_manager.gd`<br>`src/combat/abilities/terrain_ability.gd`<br>`src/grid/battle_map.gd` | `src/grid/battle_map.gd` |
| `cell_hovered(cell: Vector2i)` | `src/grid/battle_map.gd` | **no listener** |

## Economy & progression

| Signal | Emitted by | Listened by |
|---|---|---|
| `soul_coins_changed(total: int)` | `src/autoload/game_manager.gd` | `src/world/hub_menu.gd` |
| `inventory_changed()` | `src/autoload/forge_manager.gd`<br>`src/autoload/game_manager.gd`<br>`src/autoload/quest_manager.gd` | `src/autoload/quest_manager.gd` |
| `item_crafted(instance: Dictionary)` | `src/autoload/forge_manager.gd` | **no listener** |
| `ability_unlocked(character_id: String, ability_id: String)` | `src/autoload/combat_manager.gd`<br>`src/progression/progression_system.gd` | **no listener** |
| `class_unlocked(character_id: String, class_id: String)` | `src/progression/progression_system.gd` | **no listener** |
| `character_leveled(character_id: String, new_level: int)` | `src/progression/progression_system.gd` | **no listener** |

## World & narrative

| Signal | Emitted by | Listened by |
|---|---|---|
| `story_flag_changed(flag: String, value: Variant)` | `src/autoload/game_manager.gd` | `src/autoload/quest_manager.gd` |
| `loot_discovered(source_id: String, item_id: String, message: String)` | `src/world/interaction_trigger.gd` | `src/autoload/quest_manager.gd` |
| `dialog_requested(speaker: String, text: String)` | `src/autoload/ui_manager.gd` | **no listener** |
| `broadcast_line(channel: String, text: String)` | `src/autoload/cues.gd`<br>`src/autoload/dev_console.gd`<br>`src/autoload/dispatch_manager.gd`<br>`src/world/interactions.gd` | `src/world/hub_menu.gd`<br>`src/world/signage.gd` |

## Quests & dispatch

| Signal | Emitted by | Listened by |
|---|---|---|
| `quest_state_changed(quest_id: String, state: String)` | `src/autoload/quest_manager.gd` | **no listener** |
| `quest_objective_progress(quest_id: String, index: int, count: int)` | `src/autoload/quest_manager.gd` | **no listener** |
| `dispatch_started(assignment: Dictionary)` | `src/autoload/dispatch_manager.gd` | **no listener** |
| `dispatch_resolved(assignment: Dictionary, success: bool, rewards: Dictionary)` | `src/autoload/dispatch_manager.gd` | **no listener** |

## Presentation & misc

| Signal | Emitted by | Listened by |
|---|---|---|
| `cutscene_event(event_name: String, data: Variant)` | `src/cutscene/cutscene_player.gd` | **no listener** |
| `play_sfx(sfx_id: String)` | `src/autoload/cues.gd`<br>`src/combat/abilities/kinetic_ability.gd`<br>`src/combat/abilities/terrain_ability.gd`<br>`src/world/interaction_trigger.gd` | `src/autoload/audio_manager.gd` |
| `camera_shake(intensity: float, duration: float)` | `src/autoload/cues.gd`<br>`src/combat/abilities/kinetic_ability.gd`<br>`src/combat/abilities/terrain_ability.gd` | `src/autoload/camera_manager.gd` |
| `log_message(text: String)` | `src/autoload/combat_manager.gd`<br>`src/autoload/cues.gd`<br>`src/autoload/game_manager.gd`<br>`src/autoload/quest_manager.gd`<br>`src/autoload/save_manager.gd`<br>`src/combat/passives.gd`<br>`src/combat/unit.gd`<br>`src/data/ability.gd`<br>`src/world/interactions.gd`<br>`src/world/npc_stages.gd` | `src/autoload/dev_console.gd`<br>`src/ui/battle_hud.gd` |

## Non-EventBus signals worth knowing
- `CombatManager.player_input_needed(unit)`, `CombatManager.battle_finished(victory)`: BattleMap listens and drives the HUD and the results screen.
- `ContentDB.content_reloaded`: fired after `ContentDB.reload()` (the Forge and DevConsole `reload` trigger it).
- `DispatchManager.assignment_started/assignment_resolved`: local to dispatch, mirrored onto EventBus as `dispatch_started/resolved`.
- `CutscenePlayer.finished(skipped)`, `CutscenePlayer.event_fired(event_name, data)`: `await player.finished` is the pattern (see `explore_scene.run_trigger`).

## Rules for changing the contract
1. Add a signal only when 2+ systems need it. Prefer an existing one: `log_message` for text, `broadcast_line(channel, text)` for news, rumour and graffiti channels (`news`, `gossip`, `graffiti`, `radio`, `rumor`), `story_flag_changed` for anything narrative.
2. Typed args. Pass ids (`String`) for content and `Node` for units. Never pass Resources you expect listeners to mutate.
3. Put it in the right comment group in `event_bus.gd`, with a `##` line saying who emits it and when.
4. Emit from the rules owner (the autoload or the RefCounted that changed state), never from UI.
5. Listeners must tolerate headless runs (no scene, `CombatManager.map_node == null`).
6. Run `scripts/eventbus_audit.py` and update this file.

## Hooks that are open today (emitted, no listener)
`round_advanced`, `turn_ended`, `unit_status_removed`, `ability_used`, `ability_charging`, `card_spent`, `cell_hovered`, `item_crafted`, `ability_unlocked`, `class_unlocked`, `character_leveled`, `dialog_requested`, `quest_state_changed`, `quest_objective_progress`, `dispatch_started`, `dispatch_resolved`, `cutscene_event`.

These are the natural attachment points for:
- a battle action log or replay (`ability_used`, `unit_moved`, `unit_damaged`…)
- quest toasts (`quest_state_changed`)
- News Reacts (`ability_unlocked`, `battle_ended`)
- cutscene-driven camera beats (`cutscene_event`).
