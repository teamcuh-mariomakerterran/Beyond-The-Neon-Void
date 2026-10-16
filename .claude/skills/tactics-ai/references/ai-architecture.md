# AI architecture: how the current brain works

Source: `src/combat/ai/ai_behavior.gd` (265 lines, `class_name AIBehavior extends Resource`) plus four presets in the same folder. Everything below was read from the snapshot. Line numbers are approximate.

## Wiring (who gets which brain)

| Step | Where | Fact |
|---|---|---|
| Data | `CharacterData.ai_behavior` (`src/data/character_data.gd:42`) | String. **The default in the class is `"aggressive"`.** In `characters.json`: 9 tactical, 4 cautious, 3 aggressive, 3 support. |
| Build | `Unit.setup()` (`unit.gd:105`) | `behavior = AIBehavior.create(p_data.ai_behavior)` |
| Factory | `AIBehavior.create(kind)` | `aggressive`, `cautious`, `tactical` and `support`. **Anything else silently becomes Tactical**, so a typo never errors. |
| Fallback | `CombatManager._ai_turn` | If `unit.behavior == null` it uses `create("tactical")`. |
| Who is AI | `Unit.setup` | `is_player_controlled = team == PLAYER and not data.ai_controlled`. Guests (`BattleMap` mission `guests`) are forced to `is_player_controlled = false`. With `CombatManager.autobattle = true` the player team runs AI too. |
| Per-mission override | `mission.enemies[].ai` | **Ignored.** Documented in `mission_resource.gd:14` and offered by Forge (`forge_form.gd:57`), but `BattleMap._spawn_units` never reads it (known-gaps #24). |
| Forge intake | `forge_intake.gd:415,481` | Enemies get `aggressive`, others get `tactical`, and droids/guests get `ai_controlled=true` with `aggressive`. |

## Turn pipeline (`CombatManager._ai_turn`)

```
plan = unit.behavior.plan_turn(unit, CombatManager)
  -> {move_to, ability|null, target_cell, act_first, face, score}
(animate) wait 0.3 s
if act_first and ability: request_ability, then request_move   # plan B
else: request_move, then validate_ability again, then request_ability   # plan A
unit.facing = plan.face
```
- **One ability per turn.** All 49 classes have `max_ap` 2. 176 of 195 abilities cost 1 AP (the default) and 19 cost 2, so a human can usually act twice, but the AI never plans a second action (known-gaps #31). The probe measures about 1 AP unused per AI turn.
- The plan is computed once. If the move ends short, plan A checks the ability again and quietly drops it if it's no longer valid. There is no re-plan.
- Reactions, counters and traps fire inside `request_move`/`request_ability` like they do for the player. AI planning doesn't predict them.

## `plan_turn` step by step

1. `threat = build_threat_map(grid, foes)`
2. Candidate cells: `grid.reachable_cells(origin, move, jump, team, Passives.phases(unit))`. If there are more than `MAX_CANDIDATE_CELLS` (80), sort by distance to the nearest foe and keep the closest 80, plus the origin.
3. Abilities: `unit.get_abilities()` filtered by `can_afford` and `charge_ticks <= 12`. Today no ability in `abilities.json` exceeds 12 (27 charged, max 5), so this filter does nothing yet.
4. `pos_scores[c] = score_position(...)` for every candidate.
5. **Plan A:** for each cell, `_best_action_from(cell)`. If *no* cell offers an offensive action scoring above 1.0, apply the approach penalty: `pos -= approach_weight * nearest_foe_dist`. Pick the best `pos + act`.
6. **Plan B** (`hit_and_run` and can move and has abilities): best action from the origin plus the best-scoring position anywhere. It must beat plan A by 0.01.
7. Facing: `IsometricGrid.cardinal_direction(move_to, nearest_foe.cell)`.

`_best_action_from` temporarily sets `unit.cell = from_cell` so that `DamageCalculator.forecast` reads the hypothetical position. **Occupancy is not moved**: `grid.get_occupant(origin)` still returns the unit. An AoE that covers the old cell scores the unit as a friendly hit (×−1.5) even though it would have left, and line of sight from the new cell may be judged with the unit still blocking its old cell. This is suspected, not reproduced, so check it with a probe before relying on it.

## `score_action(unit, ability, from, target, grid)`

For each affected cell's living occupant:
- **Healing ability:** for allies, `min(DamageCalculator.heal_amount, missing_hp) * heal_weight`. Foes are skipped (healing undead or foes is never punished or used).
- **`affects_unit` false:** skip.
- **Non-damaging (buff/debuff/special):** `sv = status_value * status_chance * max(n_status_ids, 1)`, plus `status_value` if `special != ""`. It's 0 if an ally already has every status. Positive when helpful (an ally buff or a foe debuff), otherwise negative. **Target resistances and immunities are ignored**, and every special is valued the same.
- **Damaging (ATTACK/MAGIC):** `f = DamageCalculator.forecast(unit, u, ability, grid)`, then
  `value = hit*damage*aggression + (kill ? kill_bonus*hit : 0) + missing_pct*100*focus_fire*hit + status_value*status_chance*hit*n_status`. Friendly fire counts ×−1.5.
- Specials `summon`, `summon_droid`, `reanimate` and `revive` get `+ status_value * 2.5` (flat, once).
- Tie-breaker: `- mp_cost*0.05 - charge_ticks*0.3`.

Because `forecast()` is the single source of truth (see `tactics-combat-core`), any rules change to hit or damage automatically reaches the AI. Never add a second damage estimate in AI code.

## `score_position(unit, c, ...)`

```
- self_preservation * threat[c] / current_hp * 10
+ cover_weight * mean(cover_against(c, foe)) * 0.5
- flank_weight * aggression * (foes that have full cover against c) / n_foes   # "walled": no shot
+ height_weight * clamp(mean(height(c) - height(foe)), -3, 3)
- distance_weight * |nearest_foe_dist - preferred_distance|
- ally_cohesion * mean(distance to other allies)                  # if ally_cohesion > 0
- hazard_penalty if grid.get_hazard(c) != ""
```
Cautious overrides `score_position`: −20 if nearest foe < `min_distance` (2).

## `build_threat_map(grid, foes)`

For each foe: reach = `reachable_cells(move, jump, team)` (ignores `Passives.phases`), range = max(weapon range, best ATTACK/MAGIC `effective_range_max`), power = `max(attack, magic)`. Every cell within range of any reach cell gets `+power`. Approximations:
- Raw stats, not `forecast()`, so cover, height, facing and defence are ignored.
- Range only, so line of sight, min range and AoE are ignored.
- Ignores `pending_casts` (a charged Firestorm landing on the cell next tick counts as 0 threat).
- Ignores turn order: a foe who acts after this unit's *next* turn still counts.

## Weights table

| Weight | Base | Aggressive (Brute) | Cautious (Sniper) | Support (Medic) | Tactical (Operative) |
|---|---|---|---|---|---|
| aggression | 1.0 | **1.4** | 1.0 | **0.6** | 1.1 |
| kill_bonus | 40 | **60** | 40 | 40 | 50 |
| heal_weight | 1.2 | 1.2 | 1.2 | **2.5** | 1.2 |
| status_value | 8 | 8 | 8 | 10 | 8 |
| self_preservation | 0.5 | **0.1** | **1.2** | 1.0 | 0.6 |
| cover_weight | 6 | 2 | **10** | 6 | 7 |
| height_weight | 2 | 1 | 3 | 2 | 2.5 |
| preferred_distance | 1 | 1 | **4** (`ideal_distance`), min 2 (−20) | 3 | 2 |
| distance_weight | 1.0 | 1.5 | 2.0 | 1.0 | 0.8 |
| ally_cohesion | 0 | 0 | 0 | **1.2** | 0.3 |
| hazard_penalty | 15 | 15 | 15 | 15 | 15 |
| flank_weight | 4 | 4 | 4 | 4 | 4 |
| focus_fire | 0.15 | 0.15 | 0.15 | 0.15 | **0.3** |
| approach_weight | 3 | 3 | 1.5 | 3 | 3 |
| hit_and_run | true | **false** | true | true | true |

## Blind spots (prioritised; each one is a work item)

1. **Anchors.** No AI uses terminals, switches, medstations or devices, and traps are only avoided by accident. Headless sims don't even create `Interactions` (known-gaps #30). This is why Vault Breach stalls. See `anchor-use-plan.md`.
2. **Second action.** About 1 AP is wasted per AI turn (#31).
3. **Time.** It doesn't dodge pending charged casts aimed at its cell, doesn't time its own charged casts against the target's next turn, and doesn't read `turn_queue.forecast`. See `charged-casts-and-time.md`.
4. **Facing.** The end facing points at the nearest foe, not away from the most dangerous back attack. The threat map ignores facing, though the rules give back +0.20 hit and ×1.15 damage.
5. **Statuses.** Resistances, immunity, duration and existing statuses on foes are all ignored (a debuff gets re-applied).
6. **Team.** No coordination: two units can both "kill" the same 10-HP target, and there are no roles or formations. See `team-and-boss.md`.
7. **Bosses.** No phases or scripted moves. `CharacterData.is_boss` isn't consulted, and **no character in `characters.json` sets `is_boss: true`**, not even `foreman_grisk`, so the anchor action `status …@boss` hits nobody today. See `team-and-boss.md`.
8. **Data override.** The `mission.enemies[].ai` override is ignored (#24), and `difficulty_modifier` is unused (#25).
