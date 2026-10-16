# Explore ↔ battle loop and world save

## Today (verified in code)
- `CampaignManager.explore(map_id, spawn=-1, at=(-1,-1), from_forge=false)` sets `current_explore = {map_id, spawn, at, from_forge}` and changes to `scenes/world/explore.tscn`.
- `ExploreScene._ready()` reads `CampaignManager.current_explore`. `_start_cell(info)` uses `at` if it's walkable, else `spawns.player[spawn]`, else the walkable cell nearest the middle.
- Encounters: `_update_regions()` → `roll_encounter()` → toast "AMBUSH!" → `CampaignManager.start_mission(m)`. Region `battle` triggers and anchor `battle` actions also call `start_mission`.
- Battle end: `BattleMap._on_battle_finished` → `CombatManager.conclude_battle()` → outro → `hud.show_results`. Then `_on_continue()` → `CombatManager.stop_battle(); CampaignManager.return_to_hub()`. **You always land in the hub.**
- `ExploreScene._leave()` (Esc) goes back to the Forge when `from_forge`, else to the hub.
- Saved: `CampaignManager.get_campaign_data()` = `{unlocked_missions, completed_missions, current_mission_id, world_clock}`. **Not saved:** `current_explore`. Interaction state **is** saved through `GameManager.story_flags["ixstate:<map_id>"]` (`ExploreScene._save_ix`), visited locations through `visited_flag(map_id, obj_id)`, and once-triggers through `trig:<map>:<region>:<i>`.

## Target behaviour
1. A battle started from exploration returns the party to the **same map and cell** (and facing, once facings are decided). Victory, defeat and retreat outcomes are all explicit.
2. Loading a save made while exploring puts you back on that map and cell.
3. Hub missions still return to the hub.

## Implementation sketch (proposed; adapt to the real code when you open it)
```gdscript
# campaign_manager.gd
## Where to go after the current battle: {} = hub, or {map_id, at: [x, y]}.
var return_to: Dictionary = {}

func start_mission_from_explore(mission_id: String, map_id: String, at: Vector2i) -> void:
	return_to = {"map_id": map_id, "at": [at.x, at.y]}
	start_mission(mission_id)

func finish_battle_navigation() -> void:   # called by BattleMap._on_continue
	if return_to.is_empty():
		return_to_hub()
		return
	var r := return_to
	return_to = {}
	explore(str(r["map_id"]), -1, Vector2i(int(r["at"][0]), int(r["at"][1])))

# get_campaign_data(): add
#	"current_explore": _explore_to_json(current_explore), "return_to": return_to
# load_campaign_data(): restore both (Vector2i ↔ [x, y]; JSON has no Vector2i)
```
- **ExploreScene:** replace `CampaignManager.start_mission(m)` in `_update_regions` and `run_trigger("battle")` with `start_mission_from_explore(m, world.id, cell)`. Keep `current_explore.at` updated on each `_step` so saves are exact.
- **BattleMap:** `_on_continue()` calls `CampaignManager.finish_battle_navigation()` instead of `return_to_hub()`.
- **Defeat from an exploration battle:** **ASK BRIAN.** Options: (a) return to the map at the last safe cell with party at 1 HP, (b) game over and load, (c) return to the hub (today's behaviour).
- **SaveManager** stores `"scene": SceneManager.current_scene_path`. Make sure loading into `explore.tscn` restores `current_explore` *before* the scene's `_ready` runs. Check `SceneManager.load_game_state()` order.
- **Tests (`test_world.gd`):**
  - `start_mission_from_explore` → simulate battle end → `current_explore.at` equals the original cell.
  - Campaign data round-trip keeps `current_explore` and `return_to`.

## World state checklist (anything new must answer "where is it saved?")
| State | Lives in | Saved? |
|---|---|---|
| Interaction anchors (used, sequences, doors, traps) | `story_flags["ixstate:<map>"]` | yes (flags) |
| Visited locations | flag via `ExploreScene.visited_flag` | yes |
| Once-triggers | `trig:<map>:<region_id>:<i>` | yes |
| Hidden loot found | `found_<trigger_id>` | yes |
| NPC stage progress | `npc:<id>:*` | yes |
| Current map/cell | `CampaignManager.current_explore` | **no, add it** |
| Post-battle return | `CampaignManager.return_to` (new) | add |
| Fog of war (future) | `world_reveal` bitset per map | add with phase 5 |
| Parked vehicles (future) | `vehicles` | add with phase 7 |
| World clock | `CampaignManager.world_clock` (+6 per mission) | yes; day/night can derive from it |
| Vendor stock | `VendorSystem.stock_left` | **no** (known gap) |
