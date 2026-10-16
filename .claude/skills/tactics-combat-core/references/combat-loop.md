# Combat loop (`src/autoload/combat_manager.gd`, `src/combat/turn_queue.gd`)

## State machine
`enum State { IDLE, ADVANCING, PLAYER_INPUT, EXECUTING, AI_TURN, ENDED }`, `MAX_TURNS = 600`.

```
start_battle(grid, units, mission, map_node=null, seed=-1)
  rng.seed = seed (or randomize)   ct = rng.randi_range(0,30) + speed   battle_started
  _battle_loop():
    while not ENDED and turn_number < MAX_TURNS:
      ev = turn_queue.advance()          # ticks the CT clock to the next event
        "cast" -> _resolve_charged_cast  # pending casts resolve BEFORE units ready on the same tick
        "unit" -> _run_unit_turn
      _check_battle_end()
      (animate) await process_frame
    not ENDED -> _finish(false)          # turn cap = loss
```

## A unit turn (`_run_unit_turn`)
1. `turn_number += 1`. If the unit is `stitched`, its linked ally gains `ct_gain` (default 50).
2. `unit.begin_turn()`:
   - resets `has_moved`/`has_acted`/`move_streak` and `overwatch_spent`
   - refills AP to `max_ap`
   - **DoT/HoT** from `damage_per_turn(+_pct × max_hp)`
   - ticks status durations
   - returns `skip` if disabled.
3. Emits `turn_started` and `turn_order_changed(turn_forecast())`.
4. `_tick_round_hazards_if_needed()`: a "round" is `tick_count / 10`. Grid hazards tick down and `round_advanced` is emitted.
5. Player (`not autobattle`): `_player_turn` waits for `end_active_turn(face)`. Otherwise `_ai_turn` → `behavior.plan_turn(unit, self)`, which is either move→act or act→move (`act_first`).
6. `turn_queue.end_turn(unit, moved, acted)` → `ct = min(ct - cost, 60)`. Costs: 100 (moved+acted), 80 (one), 60 (neither).
7. `_apply_hazard_on(unit)` at the end of the turn:
   - `neon_fire` 8% max HP
   - `static` → `slow`
   - `essence_leak` 5% HP and +5 MP
8. Emits `turn_ended`.

## Commands (shared by player UI and AI)
- **`request_move(unit, cell)`**:
  1. `grid.flood(cell, move, jump, team, Passives.phases(unit))`, then the path.
  2. `await unit.move_along(path, animate)`.
  3. `await map_node.on_unit_path(unit, path)` (traps/anchors, battle scene only).
  4. `await Passives.after_move` (overwatch).
- **`request_ability(unit, ability, cell, extra_cells)`**:
  1. `validate_ability`: `can_act`, `can_afford`, deck card still playable, `get_targetable_cells` contains the cell.
  2. `face_towards`, `spend_for`.
  3. If `charge_ticks > 0`: `turn_queue.queue_cast` + `charging` status + `ability_charging`. **The cast targets the CELL**: a target that moves away dodges, FFT-style.
  4. Otherwise `_execute`.
- **`_execute`**:
  1. Builds `Ability.Context {caster, target_cell, extra_cells, grid, battle, rng=CombatManager.rng}` and emits `ability_used`.
  2. Additions: `_run_addition` (widget or `auto_hits`) → `ctx.power_mult` and `force_hit`. Otherwise (animate) `await map_node.play_ability_fx`.
  3. `job_handler.execute_ability` → `ability.resolve(ctx)` returns results `[{unit, kind: damage|heal|miss|status:<id>|…, amount, crit}]`.
  4. `await Passives.after_action` (counter, nullify, patch, step_away, adrenaline).
  5. `_last_team_action` (for `echo`), `_try_blue_learn`, kill counts.

## Hit and damage resolution (`Ability._apply_to_unit`)
- **Heal:** `heal_amount`.
- **ATTACK/MAGIC:**
  1. `rng.randf() > hit_chance` → miss (`unit_missed`). `force_hit` skips this roll.
  2. `crit = rng.randf() < crit_chance`.
  3. `dmg = damage(..., crit) * ctx.power_mult` → `take_damage`.
- **Statuses:** each `status_ids` entry rolls `rng.randf() <= status_chance`, then `apply_status`, which Firewall may block. A miss returns early, so no status lands.
- **`_resolve_special`:**
  - `cleanse`, `restore_mp`, `blink`
  - `summon`/`summon_droid` (max_active)
  - `revive` (`hp_pct`), `reanimate` (echo with `fading`)
  - `echo` (re-resolves the team's last action)
  - `steal_chip` / `steal_coins`: **these pay GameManager immediately, even mid-battle and in headless sims**.
- Script subclasses (`script: kinetic|time|terrain` in `abilities.json`) override `resolve` (see job-ability-system).

## End of battle
- `_check_battle_end()`: lose conditions first (a simultaneous wipe = loss), then win conditions. See the table in `mission-architect/references/schemas.md`. Every win condition also triggers on enemy wipe.
- `_finish(victory)` → `EventBus.battle_ended(victory, mission_id)` + `battle_finished(victory)`.
- `conclude_battle()` is called by the results screen, **not automatically**:
  - 25 weapon XP per kill
  - `CampaignManager.process_mission_completion(victory, mission, survivors)`. `survivors` = every PLAYER unit still valid, **KO'd units included** (they get XP too).

## Headless contract
- `animate = false` skips every `await` on FX/timers, so the whole battle resolves synchronously inside `start_battle`.
- `autobattle = true` makes the AI drive the player side as well.
- Tests and sims must set both, pass a seed, free units and call `stop_battle()` (see godot-verify).
