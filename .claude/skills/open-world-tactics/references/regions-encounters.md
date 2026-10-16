# Regions, triggers and encounters

## Regions today (format 2, `WorldMap.regions`)
`{id, name, color, cells: ["x,y"…], triggers: [...], encounter: {rate, missions: []}}`. Paint them in the World Painter **REGIONS** tab. No shipped map uses regions yet; they're covered by `test_world.gd::test_regions_and_links`.

**Triggers** (`ExploreScene.fire_triggers(region, on)` → `run_trigger(do, arg)`):

| `do` | `arg` | Effect |
|---|---|---|
| `toast` | text | cyan toast |
| `flag` | flag name | `GameManager.set_story_flag(arg)` |
| `dialog` | npc id **or** raw text | DialogueBox `play_npc` / `say` |
| `cutscene` | `res://…parallax.json` | `CutscenePlayer.play(root, arg, {"PLACE": world.name})`, awaited |
| `battle` | mission id | `CampaignManager.start_mission(arg)` (see explore-battle-loop.md) |
| `music` | path | **BROKEN:** passes an AudioStream to `play_music(String)`. Fix: add `AudioManager.play_stream(stream, fade)` or pass the id. |
| `teleport` | `map_id[:spawn]` | `CampaignManager.explore(map, spawn)` |

Gating per trigger: `on` (`enter`/`exit`/`interact`), `once` (flag `trig:<map>:<region>:<i>`), `requires_flag`, `blocks_flag`.

**Encounters:** `roll_encounter()` runs on every step inside a region. If `rng.randf() < rate`, it picks a random mission from `missions`. This is classic invisible random battles.

## Design direction (research doc §2.5, ROADMAP)
Tactics battles are long, so the recommended default is **visible roaming threats**. Classic random (FF8 danger counter) stays as an option. **ASK BRIAN** to confirm the default before building.

**Visible threats (proposed):**
- Each live chunk spawns 0–N threat sprites from its zone table. They wander inside the zone.
- Touching a threat calls `start_mission_from_explore(mission, map, cell)`.
- After a victory, the threat is removed and remembered via a flag `threat:<map>:<zone>:<n>` or a respawn timer on `world_clock`.
- Zone data: `data/encounter_zones.json` (`danger, mode, max_threats, rate, grace_steps, common/medium/rare, battle_maps, night{}`).

**Danger counter (option B):**
- Each step adds `rate × terrain.encounter_factor × vehicle.encounter_mult`. Roads add 0.
- `grace_steps` apply after leaving a vehicle.
- Formation tables are weighted common/medium/rare = 4/2/2.

**Mission hand-off:** a zone encounter needs a mission. Either author one mission per formation (simple and works today), or add a **generated encounter mission** path: the zone picks `battle_maps` plus an enemy formation and builds a `MissionResource` at runtime via `ContentDB.inject("missions", entry, false)`, with `persist=false` so nothing is written. Coordinate with `mission-architect` (validator) and `tactics-ai`.

## Rules
- Region triggers are content. Validate them with `scripts/world_audit.py` (unknown missions, maps, cutscenes) every time.
- One-shot story beats use `once: true`. Never re-implement "has this fired" with a new variable.
- Encounter RNG: exploration uses its own `_rng`. If you add replay or determinism tests for exploration, seed it from the save.
- Never call `start_mission` from exploration without recording the return point.
