---
name: tactics-ai
description: >-
  Use when changing how Beyond The Neon Void units think in battle: AIBehavior
  utility scoring, the Aggressive/Cautious/Support/Tactical presets, threat
  maps, positioning (cover, height, flanks, range), target choice, hit-and-run,
  enemy or auto-battle behaviour, teaching the AI to use map anchors
  (terminals, switches, medstations, traps), charged-cast dodging and timing,
  using both AP, team coordination, boss phases, AI difficulty, or measuring AI
  quality with seeded probes. Not for rules/formulas (tactics-combat-core) or
  ability data (job-ability-system).
---

# Tactics AI

BTNV's AI is a clean utility scorer (`src/combat/ai/ai_behavior.gd`). For every
reachable cell it scores the position and the best action from there, compares
"move→act" with "act→move", and presets only swap weights. It reads
`DamageCalculator.forecast()`, so the AI and the HUD can never disagree. What it
can't do yet is what makes FFT and Into the Breach enemies feel smart: use the
map, use the clock, use its whole turn, and play as a team. This skill makes the
AI deeper **without breaking determinism or the shared brain**.

Load as needed:
- `references/ai-architecture.md`: wiring, the `plan_turn` pipeline, exact scoring formulas, the weights table per preset, blind spots
- `references/anchor-use-plan.md`: three-layer plan for anchor use (sims see the world → anchors as actions → second action), based on Vault Breach
- `references/charged-casts-and-time.md`: dodging pending casts, timing your own, turn-order-aware threat, CT economy
- `references/team-and-boss.md`: team blackboard, roles, the proposed `boss_script` and `BossBehavior`, difficulty levers
- `references/probe-baseline.json`: `ai_probe` output on the snapshot (seeds 201–203, level 6), for diffs
- `scripts/gd/ai_probe.gd` (+ `ai_probe_body.gd`): seeded AI-vs-AI behaviour report, see below
- `scripts/probe_diff.py`: before/after comparison of two probe JSONs; `--strict` exits 1 on regressions
- `templates/behavior_preset.gd`: new preset (tested: instantiates on 4.7.2)
- `templates/boss_behavior.gd`: phase-swapping boss brain skeleton (tested: phase sort)
- `templates/test_ai.gd.txt`: unit test for a plan decision (tested: passes on the snapshot copy)

Related skills: `tactics-combat-core` (formulas, CT, statuses, determinism rules),
`mission-architect` (anchors and sequences the AI must understand),
`godot-verify` (the gate: replay determinism plus win-rate sims),
`job-ability-system` (ability fields the AI reads), and `game-feel-polish`
(telegraphing AI intent to the player).

## When to run
- Requests like: "enemies are dumb", "AI just stands there", "make the boss smarter", "AI should use the terminal/switches", "enemies walk into the firestorm", "add a sniper/zealot behaviour", "hard mode", "auto-battle is bad", "Vault Breach never finishes in sims".
- After any change to `ai_behavior.gd`, a preset, `DamageCalculator.forecast`, `TurnQueue`, `Interactions`, or `CombatManager._ai_turn`.
- When a mission design (from `mission-architect`) relies on enemies doing something specific.

## Ground truth (box snapshot)
- **Files:** `ai_behavior.gd` (base, 265 lines), plus `aggressive_` (Brute), `cautious_` (Sniper: ideal 4, min 2), `support_` (Medic) and `tactical_behavior.gd` (Operative, the default).
- **Factory and fallbacks:** `AIBehavior.create(kind)`; unknown strings silently become Tactical. `CombatManager._ai_turn` falls back to Tactical if `unit.behavior` is null.
- **Assignment:** `Unit.setup` reads `CharacterData.ai_behavior` (class default `"aggressive"`). `characters.json` has 9 tactical, 4 cautious, 3 aggressive and 3 support.
- **AI control:** player units run AI when `data.ai_controlled`, for mission `guests`, or when `CombatManager.autobattle`.
- **Ignored inputs:** the mission `enemies[].ai` override (known-gaps #24) and `difficulty_modifier` (#25).
- **Plan shape:** `{move_to, ability, target_cell, act_first, face, score}`.
  - At most 80 candidate cells, nearest to foes first.
  - Abilities with `charge_ticks > 12` are skipped. None exist today (27 charged abilities, max 5 ticks).
  - Facing ends toward the nearest foe.
- **One action per turn.** Every class has `max_ap` 2, and 176/195 abilities cost 1 AP, so the AI leaves about 1 AP on the table each turn (#31).
- **The world layer is invisible to AI and sims:**
  - `Interactions` exists only inside `BattleMap` (`map_node.ix`), so AI never uses anchors.
  - Traps spring only in `BattleMap.on_unit_path`.
  - `tests/test_suite.gd:_run_battle` loads format-2 maps flat (#30).
- **`ai_probe` baseline** (real grids; 3 seeds each; starting crew L6; animate off):

  | mission | player wins | stalemates | AP unused/turn (P/E) | idle % (P/E) | ms/turn (max) |
  |---|---|---|---|---|---|
  | m01_the_brew_plan | 3/3 | 0 | 0.95 / 1.21 | 13 / 21 | 16–22 (56) |
  | m02_shift_change | 3/3 | 0 | 0.71 / 1.15 | 4 / 16 | 11–15 (42) |
  | demo_vault_breach | **0/3** | **2** | 1.51 / 1.64 | 56 / 64 | 11 (50) |

  In Vault Breach the crew's moves/turn drops to 0.14: they sit behind the shut `vault_door` casting `rally_cry` (196×) because nobody hacks terminal `anc_vault_breach_demo_1` or presses the `core` 1→2→3 switches that unshield `foreman_grisk`.
- **Other facts:**
  - The `godot-verify` replay gate shows 0 mismatches. AI planning has no RNG.
  - No character has `is_boss: true` (#33).
  - `TurnQueue.cancel_casts_for` is never called, so nothing interrupts a charge.

## Hard rules
1. **One brain.** All decision logic lives in `AIBehavior`. Presets set weights in `_init()` and only override `score_position`/`score_action` (always via `super`) when no weight can express the idea. Never fork `plan_turn` into a preset.
2. **`DamageCalculator.forecast()` is the only damage/hit estimate.** Never hand-roll damage, hit or kill math in AI code. If the AI needs a number forecast lacks, add it to forecast (`tactics-combat-core`) so the HUD gets it too.
3. **Plan without side effects.** Never mutate `grid`, `turn_queue`, `ix.progress`, statuses or HP while scoring. The one existing trick, setting `unit.cell` temporarily in `_best_action_from`, must be restored on every path. Use `turn_queue.forecast()`, not `advance()`.
4. **Deterministic.** No `randf`/`randi`/`pick_random`/`shuffle` in AI. If you want variety (easy mode, personality), roll `CombatManager.rng` exactly once per decision, in a fixed order. The `replay` gate must stay at 0 mismatches.
5. **Measure before and after.** Run `ai_probe` on the same seeds before your change and after it, and paste the `probe_diff.py` output into the PR or message. "Feels smarter" is not evidence.
6. **Budget:** keep average planning ≤ 30 ms and max ≤ 150 ms per AI turn on the box probe (animate off). Cache per plan (threat map, affected cells, anchor lists); never per cell × ability × target.
7. **Fail soft.** Unknown preset → Tactical. Missing `ix` → no anchor actions. Missing data → skip the action. Never crash or stall a battle. A stall is worse than a dumb move, and the 600-turn cap counts as a loss.
8. **Headless parity.** Anything the AI uses must also exist in headless sims: anchors via an `Interactions` with `host=null`, traps via `CombatManager`, and grids built through `WorldMap.to_grid()` for format ≥ 2 (`anchor-use-plan.md`, Layer 0). If sims can't see it, balance numbers are lies.
9. **Data-driven knobs.** New behaviour switches go in data (`CharacterData.ai_behavior`, the honoured mission `ai` override, a proposed `boss_script`), and Forge's enums (`src/tools/forge_form.gd` `ai`/`ai_behavior`) get updated in the same change. Remember that `GameResource.apply_dict` **silently drops unknown keys**, so add the `@export` first.
10. **Telegraph what the AI knows.** If the AI starts exploiting a hidden rule (e.g. reading charged casts), the player must be able to see it too (turn strip, cast markers). Coordinate with `game-feel-polish`.

## Workflow: tune or add a preset
1. Run the baseline: `& $env:GODOT --headless --path . -s "$PWD/.claude/skills/tactics-ai/scripts/gd/ai_probe.gd" -- --seeds=5 --json=$env:TEMP\ai_before.json`.
2. Copy `templates/behavior_preset.gd` to `src/combat/ai/<name>_behavior.gd`, set the weights (see the table in `ai-architecture.md`), and add it to `AIBehavior.create` and the Forge enums.
3. Run `--import` once (new `class_name`), then `godot-verify -Quick`.
4. Assign it in `characters.json` (`ai_behavior`), run the probe again, then `python .claude/skills/tactics-ai/scripts/probe_diff.py before.json after.json`.
5. Add a decision test (`templates/test_ai.gd.txt`) that pins the preset's signature behaviour (e.g. the Sniper never ends adjacent when it can avoid it).

## Workflow: AI uses anchors (the big one)
Follow `references/anchor-use-plan.md` in order. Each layer ships separately, gated on `replay` 0 mismatches:
1. **Layer 0:** `CombatManager.ix`, headless `Interactions`, traps fired from `request_move`, and sims build grids via `to_grid()`. m01/m02 numbers must not move.
2. **Layer 1:** anchors become candidate actions (`usable_from` per candidate cell, `score_anchor` per action verb, sequences only at `progress[seq]`, a multi-turn goal toward the best unreachable anchor). Target: Vault Breach 0 stalemates over 10 seeds.
3. **Layer 2:** second action with the leftover AP. Target: AP unused/turn < 0.5.
- **ASK BRIAN** before enabling it for enemies, and on whether anchor use counts as an action for CT (#32).

## Workflow: time-aware AI
See `references/charged-casts-and-time.md`. In order:
1. Dodge pending hostile casts.
2. Avoid friendly casts.
3. Discount your own charged casts by whether the target acts first.
4. Weight threat by turn order.
5. Wait (60 CT) instead of shuffling.

Each step gets a unit test plus a probe diff.

## Workflow: bosses and difficulty
See `references/team-and-boss.md`. Prerequisites:
1. Brian confirms which units are bosses (set `is_boss`, which also lights up the `boss.intro`/`kill.boss` cues).
2. Add the `CharacterData.boss_script` export.
3. Wire `BossBehavior` in `Unit.setup` when `boss_script` is non-empty.

Difficulty uses AI levers only (blackboard, anchors, dodging, second action, seeded second-best picks) until Brian decides on stat scaling.

## Workflow: "AI did something dumb" bug
1. Get the mission and seed (`ai_probe --missions=<id> --seeds=N` or the replay check), and reproduce it deterministically.
2. Write a decision test that sets up the board and asserts on `plan_turn` (template). It should fail first.
3. Find the term that dominated. Temporarily print `pos_scores` and the act score for the top 5 cells, and remove the prints before finishing.
4. Fix it with a weight or a scoring term, never a special case keyed on a unit or mission id.
5. Run the probe diff and `godot-verify`.

## Probe usage
```powershell
# all missions, 3 seeds, starting crew at level 6
& $env:GODOT --headless --path . -s "$PWD/.claude/skills/tactics-ai/scripts/gd/ai_probe.gd" -- --seeds=3
# one mission, JSON for diffing
& $env:GODOT --headless --path . -s "$PWD/.claude/skills/tactics-ai/scripts/gd/ai_probe.gd" -- --missions=demo_vault_breach --seeds=10 --json="$env:TEMP/ai.json"
python .claude/skills/tactics-ai/scripts/probe_diff.py .claude/skills/tactics-ai/references/probe-baseline.json "$env:TEMP/ai.json"
```
How to read the report:
- **actions/turn** counts ability uses plus charge starts during the unit's own turn.
- **AP unused** is the remaining `current_ap` of living, non-disabled units at turn end.
- **idle** is the share of turns with no action.
- **ms/turn** covers planning plus resolution with animation off.
- **stalemate** means the battle hit `MAX_TURNS`.

The probe changes no game code. It uses the same spawn logic as the `godot-verify` replay body.

## Anti-patterns
- `if unit.data.id == "foreman_grisk": ...` in AI. Use data (`boss_script`, `is_boss`) and weights.
- A second damage estimate ("roughly attack minus defence") inside AI code.
- Random tie-breaks with `randi()`. Ties resolve by deterministic iteration order, or by `CombatManager.rng` if you must.
- Re-planning by calling `request_move` speculatively. Commands are real and emit EventBus signals.
- Teaching the AI something in `BattleMap` (the presentation layer). It must live in `AIBehavior`/`CombatManager` so headless sims get it.
- Scoring a sequence switch out of order (it resets `progress` and fires `fail_actions`).
- Treating Vault Breach 0/3 as an AI-only failure: sims also lack `Interactions` (fix Layer 0 first).
- Raw `IsometricGrid.load_dict(map)` for a format-2 map in a sim (flat grid; 36 walkability differences on `vault_breach_demo`).
- Tuning weights by vibe without a probe diff, or tuning on one seed.
- Letting planning cost grow per target × cell × ability without caching. Watch `max_ms`.

## Done checklist
- [ ] Before/after `ai_probe` on the same seeds, with the `probe_diff.py` output in the message (no new stalemates; ms within budget)
- [ ] `godot-verify` full gate: data/compile/tests PASS, `replay` 0 mismatches
- [ ] A decision test added for the new behaviour, written to fail first
- [ ] No RNG in AI except a single documented `CombatManager.rng` roll per decision
- [ ] All scoring goes through `DamageCalculator.forecast` (grep your diff for `attack -`/`defense` math)
- [ ] Planning restores `unit.cell` and mutates nothing (tests run twice in a row give the same plan)
- [ ] Anything new the AI sees also exists headless (Interactions, traps, `to_grid()`)
- [ ] New presets are registered in `AIBehavior.create` and the Forge enums; `--import` run after a new `class_name`
- [ ] Data keys have matching `@export` fields (else `apply_dict` drops them)
- [ ] `neon-void-architect/references/known-gaps.md` updated (close #24/#30/#31 etc. when fixed)
- [ ] ASK-BRIAN items listed in the final message, not decided silently
