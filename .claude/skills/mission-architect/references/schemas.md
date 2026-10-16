# Data schemas for campaign content (from `src/data/*.gd` @export vars; JSON keys == var names)

`GameResource.apply_dict` copies only keys that match `@export` vars, so **unknown keys are silently dropped** (a typo = a missing feature, no error). Run `scripts/validate_campaign.py`, and `godot-verify` for `ContentDB.validate()`.

## data/missions.json → `MissionResource` (`src/data/mission_resource.gd`)
| key | type | default | notes |
|---|---|---|---|
| id, display_name, description | String | | id: `m<NN>_<slug>` for story, `demo_*` for demos, `side_*` (proposed) for side battles |
| map_id | String | | must exist in `data/maps/<id>.json` |
| chapter | int | 1 | metadata only. **Nothing advances `GameManager.story_chapter`** (stays 1), so quests with `min_chapter > 1` are locked forever (gap 26) |
| music_id | String | "" | file `res://assets/music/<id>.ogg` (3 of 3 missing in snapshot) |
| briefing | String | "" | in-voice, should teach the mission's mechanic |
| intro_cutscene / outro_cutscene | String | "" | `res://data/cutscenes/*.parallax.json` |
| enemies | Array[Dict] | | `{character_id, cell:[x,y], level, statuses:[], ai}`. **`ai` is ignored today** (gap 24). `level` adds HP/MP only (no growth). Enemies spawn facing (-1,0) |
| guests | Array[Dict] | | AI-controlled allies `{character_id, cell, level}` (statuses ignored) |
| max_party_size | int | 5 | party slice; also capped by `spawns.player` length |
| difficulty_modifier | float | 1.0 | **unused** (gap 25) |
| win_condition | String | defeat_all | defeat_all / defeat_target (param = char id) / survive (param = rounds) / reach_cell (param = "x,y", any PLAYER-team unit incl. guests). Every win also triggers on enemy wipe |
| win_param | String | | |
| lose_condition | String | party_wiped | party_wiped / leader_down / protect (param = char id, must be on field) / time_limit (param = rounds, loses when round > N) |
| lose_param | String | | |
| soul_coin_reward, xp_reward, microchip_reward | int | 200/120/1 | xp to every survivor, class XP ×0.8 |
| loot_table_id | String | "" | `data/loot_tables.json` |
| story_flags_on_win | Array[String] | | set on victory |
| unlocks_mission_ids | Array[String] | | `CampaignManager.unlock_mission` |

Battle end lives in `CombatManager._check_battle_end`. Rewards and flags live in `CampaignManager.process_mission_completion` (loot roll uses an **unseeded** RNG; clock +6 h; emits `CampaignManager.mission_completed`). `EventBus.battle_ended(victory, battle_id)` bumps quest `complete_mission`.

## data/quests.json → `QuestResource` (QuestManager states: locked/available/active/complete)
| key | notes |
|---|---|
| id `q_<giver>_<slug>`, display_name, description | |
| giver_npc_id | an `npcs.json` id |
| chain_id | groups chains (`sly_card_chain`) |
| prerequisite_quest_ids / prerequisite_flags / min_chapter | gating |
| objectives[] | `{type, target, count, text}`. Types: `complete_mission` (mission id), `collect_item` (item id, consumed on turn-in), `talk_to` (NPC id via `QuestManager.notify_talk`), `find_loot` (**battle-map prop id with loot_item_id only**), `flag` (story flag), `defeat_character` (character id, any death via `unit_died`) |
| reward_soul_coins / reward_xp (whole party) / reward_microchips / reward_items{id: qty} / reward_flags[] | |
| unlocks_mission_ids[] / next_quest_id | |
| accept_text / progress_text / complete_text | |
| repeatable | bool |

Accepting a quest credits objectives that are already true (mission done, flag set, `found_<prop>` flag).

## data/dispatch_missions.json → `DispatchMission` (`src/data/dispatch_mission.gd`)
`duration_minutes` (real minutes), `difficulty`, `stat_weights{stat: w}`, `class_affinity{class_id: bonus}`, `min_level`, `loot_table_id`, `soul_coin_reward`, `xp_reward`, `success_text`, `failure_text`, `rumor_ids[]`, `required_flag`.
Success chance: `clamp(0.5 + (score - difficulty)/100, 0.1, 0.95)` (`dispatch_manager.gd:47`). On resolve, a random rumour goes out through `EventBus.broadcast_line("rumor", text)`.

## data/rumors.json (dict, not array)
`{"r_<slug>": {"channel": "news"|"rumor"|…, "text": "…"}}`. No `required_flag` yet (gap 20), so rumours can't react to story state. Proposal: add `required_flag` and filter in DispatchManager and the ticker. **ASK BRIAN** before adding.

## data/npcs.json → `NPCResource`
Core: `id, display_name, description, portrait_path, sprite_path, location_id (hub or map id), is_vendor, vendor_id, quest_ids[], required_flag, fight_mission_id`.
Talk: `dialog[]` graph, `eavesdrop_lines[]`, plus stages (see `anchors-and-actions.md`).

## Maps (battle side)
`spawns.player: [[x,y]…]` (count caps the party), `anchors[]`, `gameplay{"x,y": {walkable, cover, blocks_los, group, cost, hazard}}`, `props[]` (`{id, cell, asset, loot_item_id, found_text, empty_text}`, i.e. find_loot targets). Full world format: `open-world-tactics/references/world-format.md`.

## Flags (naming conventions seen in code and data)
| pattern | set by |
|---|---|
| `m01_done`, `<mission>_done` | mission `story_flags_on_win` |
| `<npc>_<fact>` e.g. `otto_tab_cleared`, `benno_trusts_crew` | quest `reward_flags` |
| `found_<prop_id>` | InteractionTrigger loot |
| `looted:<map>:<object_id>` | explore object loot |
| `visited:<map>:<object>` (see `explore_scene.visited_flag`) | entering a location |
| `npc:<id>:met/gift/fetch/fetched/repeat` | NpcStages |
| `anchor:<map>:<anchor_id>` | `once` anchors used in explore (battle-side `once` and sequence progress are in-memory per battle) |
| free-form via anchor `flag` action, e.g. `vault_cache_taken` | anchors |

Rule: **every flag that is read must be set somewhere**. The validator reports flags that are read but never set, and excludes the dynamic prefixes.
