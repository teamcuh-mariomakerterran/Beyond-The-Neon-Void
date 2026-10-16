# Time-aware AI: charged casts, turn order, CT

FFT-style depth comes from the clock. Today the AI plays as if every turn is the last. Everything it needs is already exposed.

## What the engine exposes
- `CombatManager.turn_queue.pending_casts: Array[Dictionary]`, each `{caster, ability, cell, ticks_left}`. Casts target a **cell**, so a unit that walks off it dodges. Casts resolve before units on the same tick (`advance()` checks casts first).
- `CombatManager.turn_forecast()` → `turn_queue.forecast(count, active, moved, acted)` returns `[{unit}|{cast}]` in order. It simulates CT gain (`speed` per tick, `CT_READY` 100, carry cap 60) without mutating state. **Pass the hypothetical `moved/acted`** for the acting unit, because CT cost is 100/80/60 (`TurnQueue.ct_cost`).
- `EventBus.ability_charging(unit, ability, cell, ticks)` fires when a charge starts, and `charging` is applied as a status.
- `TurnQueue.cancel_casts_for(unit)` exists but **nothing calls it** (only `remove_unit` clears a dead caster's casts). Stuns, KO-less hits and `stop` don't interrupt a charge. Interrupts are a `tactics-combat-core` decision (ASK BRIAN) before the AI can value "hit the caster".

## Rules to implement (in order of value)
1. **Dodge incoming casts.** In `score_position`, subtract the forecast damage of every pending *hostile* cast whose `get_affected_cells(grid, caster.cell, cast.cell)` contains `c` and which resolves before this unit's next turn. Use `DamageCalculator.forecast(caster, unit_at_c, ability, grid)` with the unit virtually at `c`; never a hand estimate.
2. **Don't stand in a friendly cast.** The same check, for allied casts that affect allies. Friendly fire uses the existing ×1.5 weighting.
3. **Time your own charged casts.** For an ability with `charge_ticks > 0`, use the forecast to find whether the target acts before the cast lands. If it does, expected value ×P(still there). Start with P = 0.35 if the target can move, and 1.0 if it has `stop` (the only movement-denying status id in `status_effects.json`) or `move` is 0. Prefer cells where several foes cluster *and* none act before resolution.
4. **Prefer ending in a spot you won't be hit in before your next turn.** Weight the threat map per foe by whether that foe acts before this unit's next turn (forecast order) instead of summing all foes.
5. **CT economy.** A unit with nothing useful to do should `wait` (no move, no act = CT cost 60) rather than shuffle (80). Today the AI often moves for tiny position gains, so compare `pos_gain` with the value of 20 CT, i.e. acting sooner. Start the threshold at `0.2 * mean action score` and tune.

## Pitfalls
- Never mutate `turn_queue` while planning. Use `forecast()`.
- Forecasts read `attacker.cell`. Set and restore it as `_best_action_from` does, and restore it in every branch, including early returns.
- Keep it deterministic. No randomness in planning; ties go to iteration order (cells come from `reachable_cells`, which is deterministic).
- Performance: the probe shows 11–29 ms average and 110 ms max per AI turn on the box (animate off). Keep max under 150 ms on Brian's PC. Cache affected cells per pending cast per plan.

## Tests
- A unit standing in a pending Firestorm cell with 2 ticks left moves off it.
- An AI with a 4-tick cast on a fast target picks a slower or stopped target when the values are close.
- Replay gate: 0 mismatches.
