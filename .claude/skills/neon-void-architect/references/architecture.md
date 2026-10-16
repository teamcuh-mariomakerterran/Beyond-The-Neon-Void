# Architecture reference

Snapshot 2026-10-07. Re-verify against the repo with `scripts/repo_facts.py`.

## Autoloads: what each one owns

| # | Autoload | File | Owns | Key API |
|---|---|---|---|---|
| 1 | EventBus | `src/autoload/event_bus.gd` | Global signals only (no state) | 36 signals, see `eventbus-contract.md` |
| 2 | ContentDB | `src/autoload/content_db.gd` | All content (typed buckets + plain dicts + maps) | `reload()`, `get_entry(bucket,id)`, `get_all`, `get_ids`, `get_class_res`, `get_ability`, `get_card`, `get_passive`, `get_status`, `get_item`, `get_character`, `get_mission`, `get_loot_table`, `get_dispatch_mission`, `get_quest`, `get_npc`, `get_map(id) -> Dictionary`, `inject(bucket, entry, persist)`, `validate() -> Array[String]`, signal `content_reloaded`; dict vars `terrain, vendors, rumors, recipes, maps, particles, tiles` |
| 3 | ClassLibrary | `src/autoload/class_library.gd` | CLASS_ORDER (37 playable ids incl. `sync_blade`), unlock checks | `is_unlocked_for(...)` |
| 4 | GameManager | `src/autoload/game_manager.gd` | Roster, party, coins, microchips, items, cards, story flags | `new_game()`, `get_character`, `get_party_members`, `set_active_party`, `add/spend_soul_coins`, `add_microchips`, `add/remove_stack_item`, `give_item`, `create_item_instance`, `set_story_flag(name, value=true)`, `check_story_flag`, `get_state_data`/`load_state_data`. Consts `MAX_PARTY_SIZE=5`, `STARTING_SOUL_COINS=500`, `STARTING_ROSTER=[rook,mags,dizzy,brannoc,patch]` |
| 5 | SaveManager | `src/autoload/save_manager.gd` | JSON save slots (atomic tmp→rename), F5/F9 | `save_game(slot)`, `load_game(slot)`, `read_slot`, `has_save_file`, `delete_slot`; payload `{version, saved_at, game, campaign, dispatch, quests, scene}` |
| 6 | CampaignManager | `src/autoload/campaign_manager.gd` | Unlocked/completed missions, world clock, current mission/explore | `start_mission(id)`, `explore(map_id, spawn, at, from_forge)`, `advance_clock(h)`, `process_mission_completion(victory, mission, survivors)`, `return_to_hub()`, `get/load_campaign_data` (saves `unlocked_missions, completed_missions, current_mission_id, world_clock`; **not** `current_explore`) |
| 7 | QuestManager | `src/autoload/quest_manager.gd` | Quest states derived from flags/events | listens `battle_ended`, `unit_died`, `story_flag_changed`, `loot_discovered`, `inventory_changed` |
| 8 | SceneManager | `src/autoload/scene_manager.gd` | Scene changes with transition | `change_scene(path, t)`, `warm_boot_scene`, `load_game_state`, `current_scene_path` |
| 9 | TransitionLayer | `src/autoload/transition_layer.gd` | Fade layer | |
| 10 | CameraManager | `src/autoload/camera_manager.gd` | Shake + zoom (respects `SettingsFlags.reduce_motion`) | listens `camera_shake` |
| 11 | Cues | `src/autoload/cues.gd` | Presentation moments from `data/cues.json`; time_scale/zoom override stack | `fire(cue_id, ctx={})`, `resolve(cue_id)`, `register(step, fn)`, `push(channel, value, dur, shape)` / `effective(channel, base)` (override stack), `reload()`, `history`; auto cues from EventBus |
| 12 | AudioManager | `src/autoload/audio_manager.gd` | 2-player music crossfade, 8 SFX players | `play_music(music_id: String, fade)`, `play_sfx(sfx_id: String)`; listens `play_sfx` |
| 13 | CombatManager | `src/autoload/combat_manager.gd` | The battle state machine | `State {IDLE, ADVANCING, PLAYER_INPUT, EXECUTING, AI_TURN, ENDED}`, `MAX_TURNS=600`, `rng`, `animate`, `autobattle`, `start_battle(grid, units, mission, map, seed)`, `request_move`, `request_ability`, `conclude_battle`, `stop_battle`; signals `player_input_needed(unit)`, `battle_finished(victory)` |
| 14 | DispatchManager | `src/autoload/dispatch_manager.gd` | Real-time errands | `success_chance`, `check_completed`, `debug_now` test hook |
| 15 | ForgeManager | `src/autoload/forge_manager.gd` | Weapon XP/level/evolve, simple crafting | `xp_to_next = 40+12L+L²`, `craft_simple` |
| 16 | VendorSystem | `src/autoload/vendor_system.gd` | Shops, `stock_left` (**not saved**) | `get_vendor`, `available_stock`, `buy_item`, `sell_stack` |
| 17 | UIManager | `src/autoload/ui_manager.gd` | HUD router, DialogueBox | `register_hud`, `show_notification`, `show_dialog`, `get_dialogue_box`, `play_npc_dialog`, `open_vendor_menu`, `set_turn_indicator` |
| 18 | DevConsole | `src/autoload/dev_console.gd` | Backtick console | `help clear give chips coins flag heal kill win lose status passive cue news time tp spawn set watch unwatch fps reload units` + GDScript expressions |

## Non-autoload systems (static / RefCounted / Node)

- **Combat:** `src/combat/` holds `unit.gd` (Node2D), `unit_stats.gd`, `turn_queue.gd`, `damage_calculator.gd`, `job_handler.gd`, `equipment_manager.gd`, `passives.gd`, `additions.gd`, `abilities/{kinetic,time,terrain}_ability.gd`, and `ai/ai_behavior.gd`.
- **Grid:** `src/grid/isometric_grid.gd` (RefCounted data) and `battle_map.gd` (the battle scene root, about 820 lines).
- **World:** `src/world/` holds `world_map.gd` (format v2 data), `world_renderer.gd` (StripView/WorldSprite/NeonLight/FxLayer), `explore_scene.gd`, `hub_menu.gd`, `interactions.gd`, `anchor_marks.gd`, `npc_stages.gd`, `interaction_trigger.gd`, `signage.gd`, `cable_net.gd`, `map_validator.gd`, `camera_controller.gd`.
- **Data:** `src/data/` holds `GameResource` (`@abstract`) and its subclasses `Ability`, `ClassResource`, `CharacterData`, `ItemResource`, `StatusEffect`, `PassiveResource`, `MissionResource`, `QuestResource`, `NPCResource`, `DispatchMission`, `LootTable`, `CardResource` (extends Ability) and `DeckResource`. `GameData` is unused.
- **VFX:** `src/vfx/` holds `vfx.gd` (static library) and its parts, `particle_factory.gd`, `status_look.gd(.gdshader)`, `hd2d_post.gd`, `lattice_clip.gd`, `pixel_matrix.gd`, `sheet_sprite.gd`, `heartbeat.gdshader` and `screen.gdshader`.
- **Cutscene:** `src/cutscene/` holds the PARALLAX player (`CutscenePlayer.play(parent, path, vars, slots)` with `await .finished`).
- **Tools:** `src/tools/` holds the Neon Forge (`neon_forge.gd`, `forge_world_painter.gd`, `forge_form.gd`, `forge_intake.gd`, `forge_store.gd`, `location_graph.gd`, `asset_refs.gd`, …).
- **UI:** `src/ui/` holds `battle_hud.gd`, `unit_hud.gd`, `damage_text.gd`, `dialogue_box.gd`, `dialog_graph.gd`, `addition_widget.gd`, `shop_popup.gd`, `main_menu.gd`, `neon_theme.gd` and `ui_icons.gd`.
- **Core:** `src/core/input_actions.gd`, `settings_flags.gd` (`reduce_motion`, auto additions, `icon_style`), and `src/progression/progression_system.gd`.

## Scene flow

```
scenes/main.tscn (main_menu.gd)
 ├─ New Shift ─▶ scenes/hub/hub.tscn (hub_menu.gd: Missions | Regulars | Crew | Bar & Shops | Dispatch | Forge | Save)
 │                └─ CampaignManager.start_mission(id) ─▶ scenes/battle/battle.tscn (battle_map.gd)
 │                     intro_cutscene → CombatManager.start_battle → … → conclude_battle
 │                     → CampaignManager.process_mission_completion → outro_cutscene → results
 │                     → Continue → CampaignManager.return_to_hub()   ← ALWAYS the hub
 ├─ Quick Battle ─▶ m01_the_brew_plan
 └─ Neon Forge (F1) ─▶ scenes/editor/neon_forge.tscn ── "Play here" F5 ─▶ explore / battle
CampaignManager.explore(map_id, spawn, at) ─▶ scenes/world/explore.tscn (explore_scene.gd)
   locations (world → city/hub → interior/event), regions (enter/exit/interact triggers),
   random encounters → start_mission (→ hub afterwards: known gap)
```

## Content load order

`res://data/*.json` loads first, then `user://content/*.json`; later entries override by id. `ForgeStore` writes to `res://data` when run from the editor (git diff) and to `user://content` in exported builds.
