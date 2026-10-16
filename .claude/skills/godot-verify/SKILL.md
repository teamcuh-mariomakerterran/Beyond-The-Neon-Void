---
name: godot-verify
description: >-
  Use before saying any Beyond The Neon Void change is done, and whenever asked
  to test, verify, check for script errors, validate JSON/data, reproduce a
  battle by seed, check determinism, or measure balance (AI-vs-AI win rates).
  Runs headless Godot 4.7: import, compile_all, run_tests, data schema
  validation, campaign cross-refs, and a seeded double-run replay check, via
  verify.ps1 (Windows) or verify.sh. Also use when writing new tests or headless
  -s scripts (the autoload compile trap).
---

# Godot Verify

This is the gate every other BTNV skill ends on. One command; it writes nothing
into the repo.

```powershell
# Windows (repo root; Brian's machine)
powershell -ExecutionPolicy Bypass -File .claude\skills\godot-verify\scripts\verify.ps1
#   -Quick                  data + compile only (seconds)
#   -Only replay -Missions m02_shift_change -Seeds 5
#   -Godot C:\path\Godot_v4.7.2-stable_win64_console.exe   (or set $env:GODOT once)
```
```bash
bash .claude/skills/godot-verify/scripts/verify.sh . [--quick] [--only data|compile|tests|replay] [--missions a,b] [--seeds N]
```
Logs go to `%TEMP%\btnv-verify\` (`$TMPDIR/btnv-verify/`): `import.log`, `data.log`, `compile.log`, `tests.log`, `replay.log`, `replay.json`.

Load as needed:
- `references/headless-recipes.md`: CLI commands, the **-s autoload trap** and the runner/body pattern, absolute script paths, script-error scan, snapshot gotchas, how to write tests
- `references/determinism.md`: RNG inventory (seeded vs leaking), how the replay check works, how to fix a mismatch, balance baselines
- `scripts/verify.ps1` / `scripts/verify.sh`: the gate (preflight → import → data → compile → tests → replay)
- `scripts/validate_data.py`: data/*.json vs the `@export` vars in `src/` (unknown keys, types, enums, duplicate ids, parse errors), then `mission-architect/scripts/validate_campaign.py`
- `scripts/gd/replay_check.gd` + `replay_body.gd`: seeded double-run trace hash, win rate, turn-cap detection
- `scripts/known_failures.txt`: the 9 world tests that fail only because art and fixtures are missing in a partial checkout
- `templates/runner.gd`, `body.gd`, `test_snippet.gd.txt`, `github-actions-verify.yml` (optional CI, **ASK BRIAN**)

---

## When to run
- **Always** before saying "done" on any code, data, scene or shader change (other skills' checklists point here).
- After editing `data/*.json` or `data/maps/*.json`: `-Quick` at minimum.
- After touching combat, AI, abilities, statuses or RNG: the full gate, including `replay`. Note the win rates in the PR.
- Bug reports like "battle hangs" or "different result each time": `-Only replay -Missions <id> -Seeds 10`.

---

## Ground truth (box snapshot, Godot 4.7.2)
| Gate | Result |
|---|---|
| data | 0 errors over 12 buckets (classes 49, abilities 195, cards 15, statuses 33, items 70, characters 19, missions 3, loot 3, dispatch 6, quests 5, npcs 7, passives 19) + 6 maps; 4 campaign warnings |
| compile | `compile_all: 135 files, 0 failures` |
| tests | suite **641/0**; world **334/9** (all 9 are art/fixtures, see `known_failures.txt`); AI-vs-AI 19/36 |
| replay | 0 mismatches. Starting crew L6: m01 2/2, m02 1/2, **vault breach 0/2, seed 102 hits the 600-turn cap** (the vault door stays shut and Grisk stays shielded because no AI uses anchors, and headless sims create no `Interactions`) |
| time | full gate ~70 s |

Things that are **not** covered yet, so add tests when you touch them:
- explore↔battle round-trip
- save of `current_explore`
- Interactions in battle (anchor actions)
- NpcStages flows
- Forge `SECTIONS` coverage (passives missing)
- shader compile per material

---

## Hard rules
1. **No "done" without a green gate.** Report the summary table (`preflight/import/data/compile/tests/replay`) in your final message. If you couldn't run Godot, say so plainly and run at least `validate_data.py`.
2. **New failures block; known failures don't.** Only `known_failures.txt` patterns are allowed. Never add a pattern to hide a real failure. When art lands and a known test passes, delete its line.
3. **Never write into `data/` or the repo from verification.** Scratch maps and saves go to `user://`, `%TEMP%` or in-memory dicts. The gate's own logs go to the temp folder.
4. **-s scripts never name autoloads.** Use the runner/body pattern (`templates/runner.gd` + `body.gd`) and `await process_frame` first. A body that fails to compile must count as a failure, not a hang.
5. **Every battle in a test is seeded**, with `animate = false`, `autobattle = true`, and `stop_battle()` plus freeing units afterwards. The determinism test runs it twice and compares.
6. **Rules RNG comes from `CombatManager.rng`** (or an RNG passed in). Presentation code may use global `randf`. A replay mismatch is a bug in the rules path: fix it, don't reseed around it.
7. **Data typos are errors.** `apply_dict` drops unknown keys silently. `validate_data.py` must show 0 errors, and "did you mean" hints are usually right.
8. **Timeouts on everything headless.** The scripts already wrap calls, so keep that when adding steps.
9. **Don't "fix" the environment silently.** Missing `legacy/original_gd/.gdignore`, a missing Godot, or a wrong Godot version: report it with the exact fix and let Brian approve repo changes.
10. **Respect Windows.** Use the console Godot exe, forward slashes in `res://` and absolute `-s` paths, and PowerShell 5.1-compatible syntax in `.ps1` (no `&&`, `??` or ternaries).

---

## Workflow: verify a change
1. `verify.ps1 -Quick` while iterating (data + compile).
2. Full `verify.ps1` before finishing.
3. Any FAIL:
   - **data:** fix the JSON. Re-run `python .claude\skills\godot-verify\scripts\validate_data.py .`.
   - **compile:** open `compile.log` and fix the first error first (cascades are common).
   - **tests:** the `NEW FAIL …` lines are yours. Reproduce with `& $env:GODOT --headless --path . -s res://tests/run_tests.gd`.
   - **replay:** follow `references/determinism.md`. Use `--json`, find the first differing event, then hunt the RNG.
4. Paste the summary table and any balance numbers into your reply or PR.

## Workflow: add a test for new behaviour
1. Pick the file: logic in `tests/test_suite.gd`, world/renderer/Forge in `tests/test_world.gd`.
2. Use `check(cond, "what it proves")`. Start from `templates/test_snippet.gd.txt` for battles.
3. Call it from `run()`, then re-run the gate. The pass count must go up by the number of checks you added.

## Workflow: a one-off headless probe
Copy `templates/runner.gd` + `body.gd` into a temp folder, then run:
`& $env:GODOT --headless --path . -s C:/temp/probe/runner.gd -- --arg=1`
Delete the folder after use. Never leave probes in `tests/` unless they become real tests.

## Workflow: balance pass
`verify.ps1 -Only replay -Seeds 5` (default crew), then
`& $env:GODOT --headless --path . -s <abs>/gd/replay_check.gd -- --rosters=suite --seeds=3 --json=C:/temp/bal.json`.
Compare the win rate and average turns per mission before and after. Target bands are **ASK BRIAN**; don't invent them.

---

## Anti-patterns
- "Should work" without running the gate, or running it and not reporting the result.
- Editing `known_failures.txt` to get green.
- Unseeded battles in tests, or `rng.randomize()` in a rules path.
- `load()`-ing autoload-dependent code from a `-s` script's top level.
- Writing test maps to `data/maps/`, or saving over `user://` saves Brian plays with (use a distinct slot or name).
- Running the non-console Godot exe on Windows and trusting an empty log.
- Adding Python, PowerShell or GDScript dependencies (pip packages, modules) to the gate. It must run on a stock Windows box with Python 3 and Godot.

---

## Done checklist
- [ ] `verify` summary: preflight/import/data/compile/tests/replay all PASS (or SKIP with reason)
- [ ] 0 NEW test failures; known failures unchanged or reduced
- [ ] New behaviour has at least one `check()`; pass count went up
- [ ] Combat/AI/RNG change: replay 0 mismatches, plus win rate and average turns reported
- [ ] Data change: `validate_data.py` 0 errors, campaign warnings explained
- [ ] Nothing written into the repo by verification; temp probes deleted
