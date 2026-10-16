# Determinism and seeded replay

## Why
FFT-style tactics need reproducible battles for balance sims, bug repro ("seed 104 on m02 hangs"), replays and future netcode/engine port parity (`engine-port-contracts`). `CombatManager.start_battle(grid, units, mission, map, seed_value)` seeds `CombatManager.rng`, and every rules roll must come from it.

## RNG inventory (snapshot, `src/`; `tools/` excluded)
| Where | RNG | In the rules path? | Status |
|---|---|---|---|
| `combat_manager.gd:23` | `rng` seeded by `start_battle` | yes | OK |
| `passives.gd:90` | `battle.rng`, falls back to `RandomNumberGenerator.new()` (unseeded) when no battle | yes | fallback must not happen in battle |
| `campaign_manager.gd:63` | new RNG + `randomize()` for mission loot | rewards | **leak**: seed from mission id + save seed |
| `interactions.gd:66,129` | own `rng.randomize()` (trap disarm etc.) | yes, in battle | **leak**: use `CombatManager.rng` in battle |
| `explore_scene.gd:31,90` | `_rng.randomize()` (encounters) | world | decide: seeded per save? (**ASK BRIAN**) |
| `dispatch_manager.gd:103` | randomize when no rng passed | dispatch | acceptable (offline errands) |
| `class_library.gd:60` | `pick_random()` | content gen | check callers |
| `damage_text`, `unit_hud`, `camera_manager`, `audio_manager`, `vfx_*`, `particle_factory`, `sheet_sprite`, `hub_menu` ticker | global `randf` / own RNGs | presentation only | OK. **Never** let presentation randomness feed back into rules |

Rule: **rules code takes an RNG parameter or uses `CombatManager.rng`. Presentation code may use anything.**

## The replay check (`scripts/gd/replay_check.gd`)
- For each mission × roster × seed it runs the battle twice and hashes an event trace. The trace contains turn starts, moves, damage, heals, misses, deaths, statuses and abilities, each keyed by character id, team and cell.
- It mirrors `BattleMap._spawn_units`: enemy `statuses` are applied and guests are spawned. The repo's `test_battles` harness skips both.
- `REPLAY MISMATCH … first diff at event N`: open both traces (add `--json`) and find the first diverging event. The roll just before it comes from an unseeded RNG.
- `HIT TURN CAP`: stalemate. Usually a shielded or unreachable target that only an anchor can unlock (the AI ignores anchors), or a pathing hole.
- Baseline (box, starting crew, level 6, seeds 101–102): m01 won 2/2; m02 won 1/2; **demo_vault_breach won 0/2, and seed 102 hits the turn cap**. The vault door (`vault_door` group, opened by terminal `anc_vault_breach_demo_1`) stays shut and Grisk stays `shielded` (the `core` sequence switches 1→2→3 unshield him). Headless sims create no `Interactions` and no AI uses anchors, so this is expected until `tactics-ai` lands anchor use. It is not a determinism bug.
- The sim builds format-2 maps the way `BattleMap._build_grid` does (`WorldMap.from_dict(map).to_grid()`). Raw `IsometricGrid.load_dict(map)` on a format-2 map gives a flat, all-walkable grid: on `vault_breach_demo` 36 cells differ in walkability and 34 in height. `tests/test_suite.gd:_run_battle` still uses the raw call. That is harmless today (m01 and m02 use format-1 maps) but wrong for any future World Painter mission. See known-gaps #30.
- Balance use: `--rosters=suite --seeds=3` reproduces the repo's 6 rosters. Report the win rate and average turns per mission in PRs that touch combat numbers.

## Making a fix deterministic (checklist)
1. Find the roll (`first diff` event, then grep `randf|randi|RandomNumberGenerator.new|randomize|shuffle|pick_random` in the files that event touches).
2. Thread `CombatManager.rng` (in battle) or a seeded RNG derived from a stable key (`hash(mission_id + str(save_seed))`) into it.
3. Keep the Dictionary/Array iteration order stable. JSON order is stable; avoid iterating `units` after `erase` + re-add.
4. Re-run `verify -Only replay` and get 0 mismatches.
