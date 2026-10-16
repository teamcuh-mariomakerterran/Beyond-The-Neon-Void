---
name: tactics-combat-core
description: >-
  Use when changing Beyond The Neon Void battle rules: the CT turn clock,
  CombatManager state machine, move/act commands, hit/crit/damage/heal
  formulas, facing and height and cover math, statuses, hazards, charged
  casts, Additions, passives/reactions, win/lose checks, battle rewards hooks,
  seeded RNG/determinism, battle logs or replays, enemy level scaling, or the
  rules/presentation split (Lying HUD InfoFilter). Not for ability content
  (job-ability-system) or AI decisions (tactics-ai).
---

# Tactics Combat Core

BTNV's battle backend is FFT-shaped: CT clock, charge-time casts, facing, height,
reactions. It adds XCOM-style directional cover, Additions, cards, chips and map
anchors. It already works headless and is tested: AI-vs-AI battles finish, and a
seeded run replays identically on the box. This skill keeps it **correct,
deterministic and decoupled** while it gets deeper.

Load as needed:
- `references/combat-loop.md`: state machine, turn flow, commands, resolution, end of battle, headless contract
- `references/formulas.md`: stats, hit, crit, damage, heal, cover, CT, Additions, hazards (from the code)
- `references/statuses.md`: all 33 statuses with data effect, code hook and **which ones do nothing yet**
- `references/fft-parity.md`: FFT features vs BTNV, with ASK-BRIAN items
- `references/rules-presentation-split.md`: coupling inventory, target shape, rules for new code, InfoFilter
- `scripts/gd/forecast_matrix.gd`: CSV balance sheet from the **real** `DamageCalculator.forecast` (class × enemy × ability)
- `scripts/rng_audit.py`: every RNG site, classified rules vs presentation; `--strict` for CI
- `templates/battle_log.gd`: proposed `BattleLog` (tested on Godot 4.7.2: 187 events for m01, seed 7)
- `templates/status_effect.template.jsonc`

Verification is `godot-verify` (the `replay` gate checks determinism). Cue and juice work belongs to `game-feel-polish` and the shared `design-juice`. Grid math belongs to `iso-tactics-grid`.

---

## When to run
- Any edit in `src/autoload/combat_manager.gd`, `src/combat/*.gd` (not `ai/`), `src/data/ability.gd` (resolve, targeting), `src/data/status_effect.gd`, `data/status_effects.json`, `data/passives.json` effects, or hazard handling.
- Requests like: "make side attacks matter", "add a status", "enemies should scale with level", "add a replay", "why did that miss", "balance damage", "Lying HUD", "seeded battles differ".

---

## Ground truth (box snapshot)
- **Loop:**
  - `start_battle` (seeded) → `_battle_loop` → `turn_queue.advance()` returns a cast or a unit → `_run_unit_turn` → `_check_battle_end`.
  - `MAX_TURNS = 600`; a battle that hits it is a loss.
  - CT: 100 / carry 60 / costs 100-80-60.
- **Formulas live in two files only:** `UnitStats.calculate` and `DamageCalculator`.
  - `forecast()` feeds both the HUD and the AI.
  - Damage is deterministic; only hit, crit and status rolls are random, all from `ctx.rng` = `CombatManager.rng`.
- **Determinism:** `replay_check` gives 0 mismatches. `rng_audit.py` lists 6 rules-path issues:
  - the Passives fallback
  - Interactions
  - CampaignManager loot
  - ExploreScene encounters
  - DispatchManager
  - `ClassLibrary.pick_random`
- **Known gaps** (`neon-void-architect/references/known-gaps.md`):
  - Enemy `level` only scales HP/MP.
  - Side hits give no damage bonus.
  - AoE footprint ignores height.
  - Statuses `focused`, `blinded`, `identity_loss`, `dualcast` do nothing. `hidden` doesn't affect hit chance. `asleep` doesn't wake on damage. `berserk` doesn't force attacks.
  - `steal_chip`/`steal_coins` pay mid-battle (even in sims).
  - `conclude_battle` gives XP to KO'd units.
  - `difficulty_modifier` is unused.
  - Two time-scale owners (`VFX.hit_stop` vs Cues).
- **Baseline balance:**
  - suite rosters: player 19/36
  - starting crew L6: m01 2/2, m02 1/2, Vault Breach 0/2 with a turn-cap stalemate (AI ignores anchors; see `tactics-ai`)

---

## Hard rules
1. **One formula home.** Hit, damage, crit and heal changes go in `DamageCalculator`; stat changes go in `UnitStats`. Never compute damage in an ability, the HUD or the AI. Call `forecast()`/`damage()`.
2. **Forecast = resolution.** After any formula change, the forecast for a deterministic case must equal the dealt damage. Add a test that checks `forecast().damage == take_damage` result when hit is forced.
3. **Rules randomness comes only from the battle RNG** (`ctx.rng` / `CombatManager.rng`). No `randf()`, `pick_random()`, `shuffle()` or fresh `RandomNumberGenerator.new()` in rules code. Run `rng_audit.py` and get no new issues. The `replay` gate must stay at 0 mismatches.
4. **New rules code doesn't touch presentation:**
   - no `await` on FX, timers or tweens
   - no `get_tree()` and no `Engine.time_scale`
   - emit EventBus signals or `Cues.fire` instead.

   Existing couplings are listed in `rules-presentation-split.md`; don't add more.
5. **Use the commands.** Player UI, AI, anchors and tests act through `request_move`/`request_ability`/`end_active_turn`. Never mutate `cell`, `ct`, `current_hp` or statuses directly from outside rules code. `spawn_unit`/`readd_unit` exist for summons and revives.
6. **Statuses are data first.** Prefer `stat_multipliers`/`stat_flat`/DoT/`prevents_*`/tags. A code hook is one tag check in one place (rule 1). Every status needs a look and an icon.
7. **Respect the headless contract.** Everything must work with `animate=false, autobattle=true, map_node=null`. Guard `map_node` calls with `has_method`.
8. **Measure balance, don't eyeball it.**
   - Run `forecast_matrix.gd` before and after.
   - Run `verify.ps1 -Only replay -Seeds 5` (and `-Rosters suite`).
   - Report win rate and average turns.
   - Target bands are **ASK BRIAN**.
9. **Don't decide design alone.** These are **ASK BRIAN**:
   - side-hit damage
   - variance (none, intentionally)
   - diagonal facings
   - Brave/Faith
   - permadeath or crystals
   - KO'd units getting XP
   - the enemy growth formula
   - which statuses to keep vs cut
10. **Save safety.** Rules changes that alter `CharacterData`, `UnitStats` or item instances must keep `to_dict`/`from_dict` round-trips green (save tests in `test_suite.gd`).

---

## Workflow: change a formula
1. Read `references/formulas.md`, then the function in `damage_calculator.gd`/`unit_stats.gd`.
2. Baseline: `forecast_matrix.gd -- --out=C:/temp/before.csv`, plus `verify.ps1 -Only replay -Seeds 5`.
3. Change the constant or function. Keep the names (`BACK_HIT_BONUS`, `COVER_DMG_WEIGHT`, …), and add new constants next to them.
4. Add or adjust tests in `tests/test_suite.gd` (`test_stats` / a new `test_formula_<x>`), including forecast = resolution.
5. Run `forecast_matrix.gd -- --out=C:/temp/after.csv`, diff the CSVs, and summarise the deltas per class.
6. Run the full `verify` gate. Report the win rate and turn deltas.

## Workflow: enemy level scaling (known gap)
1. **ASK BRIAN** for the rule. The obvious option is to apply `level_up(cls)` growth for `level - template_level` levels in `Unit.setup` when `level_override > stats.level`.
2. Implement it in `Unit.setup` only. Template characters keep their authored stats at their own level.
3. Re-run the forecast matrix with enemies at L2/L5/L10, then the replay gate. Mission rewards may need retuning (mission-architect).

## Workflow: make a dead status real (e.g. `blinded`)
1. Decide the effect with Brian, e.g. blinded = accuracy ×0.5.
2. Prefer data: `"stat_multipliers": {"accuracy": 0.5}` in `status_effects.json` works today, since accuracy is a derived stat.
3. If it needs logic (asleep wakes on damage), add one hook (`Unit.take_damage` → `remove_status("asleep")`) and a test.
4. Update `references/statuses.md`, plus the look and icon.

## Workflow: battle log and replay
1. Copy `templates/battle_log.gd` to `src/combat/battle_log.gd`, then run `--import` (new `class_name`).
2. In `CombatManager.start_battle` after seeding, call `log.begin(...)`. In `_finish`, call `log.end(...)` and save to `user://logs/last_battle.json` in debug builds.
3. Add a dev-console `replay <path>` and a test: same seed → same `digest()`.
4. Share the schema with `engine-port-contracts` (battle-log v1).

## Workflow: Lying HUD InfoFilter
Follow `rules-presentation-split.md` §5. It's a pure function between `forecast()` and the HUD, active in **one warped zone only** (Brian's call). The AI and rules never see the filtered numbers. Test both sides.

---

## Anti-patterns
- Re-implementing damage in Python or in an ability "for speed". Use `forecast_matrix.gd`.
- `if unit.has_status("blinded"): chance *= 0.5` in the HUD only, so the forecast lies everywhere.
- A new `RandomNumberGenerator.new()` in `src/combat/` or `Interactions`.
- Awaiting a tween inside `request_ability`.
- Writing `unit.ct += 50` from an anchor action instead of a rules function.
- Balancing by raising enemy `level` (HP sponge, see the gap).
- Adding Brave/Faith or variance because "FFT has it".
- Changing `MAX_TURNS` to hide a stalemate. Fix the stalemate (tactics-ai, mission design).
- Making a status visual without a mechanical effect, or the reverse.

---

## Done checklist
- [ ] Formula or rule lives in `DamageCalculator`/`UnitStats`/`CombatManager`/`Unit` only; forecast = resolution test added
- [ ] `rng_audit.py`: no new rules-path issues; `verify` replay 0 mismatches
- [ ] No new rules → presentation coupling (no awaits, tweens or `time_scale` in rules code)
- [ ] Before/after `forecast_matrix` CSV diff summarised; win rate and average turns reported
- [ ] Statuses: data + look + icon + test; `references/statuses.md` updated
- [ ] Save round-trip tests green
- [ ] `godot-verify` full gate green
- [ ] ASK-BRIAN items listed in the PR or reply
