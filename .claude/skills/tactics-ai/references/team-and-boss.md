# Team coordination, boss scripts, difficulty

## Team coordination (cheap first)
Today each unit plans alone. Add a per-battle, per-team blackboard owned by `CombatManager` (e.g. `ai_blackboard[team]`, reset in `start_battle`):
- **Claimed kills:** after a unit's plan expects a kill (`forecast.kill` and hit ≥ 0.75), record `target -> expected_damage`. Later planners subtract expected damage already claimed this round before scoring the kill bonus. That prevents overkill pile-ons.
- **Focus target:** the team picks a focus at round start (`lowest effective HP / threat` or healer-first). `focus_fire` gets a bonus multiplier for that target.
- **Roles:** derive from preset (Brute = front, Sniper = back, Medic = support, Operative = flex). Use roles for formation cohesion: Medic stays within 3 of the Brute, etc. `ally_cohesion` already exists. Make it role-aware instead of a mean distance.
- **Body-blocking and zone control:** score cells that cut the shortest path from a foe to an ally healer (needs `grid.find_path` to be cheap; profile first).
- **Anchor claims:** one unit per anchor goal (see `anchor-use-plan.md`).

Never use globals for the blackboard. Keep it on `CombatManager` so `stop_battle()` clears it and headless sims stay isolated.

## Boss scripts
There is no boss logic, and no character has `is_boss: true` (known-gaps #33). Setting it already fires the `boss.intro` cue on spawn and `kill.boss` on death (`cues.gd:131-142`). That's free juice, so do it for Grisk once Brian confirms he's a boss. Proposed hook, data-first so missions can author it (`mission-architect`):

```jsonc
// CharacterData (characters.json) – new optional block, applied by GameResource.apply_dict
"boss_script": {
  "phases": [
    {"at_hp_pct": 100, "behavior": "cautious", "prefer": ["rail_shot"]},
    {"at_hp_pct": 50, "behavior": "aggressive", "on_enter": [{"do": "status", "arg": "berserk@self"}, {"do": "cue", "arg": "boss.phase"}]},
    {"at_hp_pct": 25, "behavior": "aggressive", "summon": "doctrine_warden@near", "once": true}
  ],
  "never_target": [], "always_open_with": "shift_whistle"
}
```
- Implement it as an `AIBehavior` subclass (`BossBehavior`) that wraps a preset and swaps weights per phase. `on_enter` reuses `Interactions.run_action` verbs where possible, so there's one action vocabulary. If the unit has no `Interactions`, call the equivalent code paths.
- `GameResource.apply_dict` **silently drops unknown keys**. Add `@export var boss_script: Dictionary` to `CharacterData` first, or the JSON block vanishes.
- Phases must be deterministic (HP thresholds only, or `CombatManager.rng` rolls).
- Fire a cue on each phase change (`Cues.fire("boss.phase", ...)`; register it in `data/cues.json`) for the juice layer (`game-feel-polish`).
- ASK BRIAN: phase vocabulary, whether bosses get extra AP or turns (FFT bosses often do), and whether `is_boss` should also give status immunities.

## Difficulty
`MissionResource.difficulty_modifier` exists but is unused (known-gaps #25). Clean levers, all in the AI layer (no stat cheats):
- Easy: lower `focus_fire`/`kill_bonus`, `hit_and_run=false`, no anchor use, 15% chance (seeded, `CombatManager.rng`) to pick the second-best plan.
- Hard: blackboard on, anchor use on, cast dodging on, second action on.
ASK BRIAN whether difficulty should scale enemy stats/levels too (that's `tactics-combat-core`'s enemy growth question).
