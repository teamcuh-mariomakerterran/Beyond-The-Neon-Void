# Change plan: <short title>

**Ask (verbatim from Brian):** "<quote>"
**Owner skill(s):** neon-void-architect + <specialist>
**Date:** <YYYY-MM-DD>

## 1. What changes for the player
<1–3 sentences. What they see, do or feel differently.>

## 2. Files
| File | Change | Why |
|---|---|---|
| `src/...` | | |
| `data/...json` | | |
| `tests/test_world.gd` | add `test_<feature>()` | |

## 3. Data
- New/changed `@export` fields (Resource, name, type, default = old behaviour):
- New JSON keys / files (with `_note` schema line if plain-dict):
- ForgeForm: REFS / CHOICES / HELP entries needed?

## 4. Signals & cues
- New EventBus signals (name, typed args, emitter, listeners), or "none, reusing `<signal>`":
- New cue ids (`data/cues.json`):

## 5. State & saves
- New persistent state, and where it lives (story flag key pattern / SaveManager block):
- Save round-trip test updated?

## 6. Headless & determinism
- Works with `CombatManager.animate = false`?
- Uses `CombatManager.rng` only (no new RNGs)?

## 7. Tests & verification
- Tests added:
- Gate: compile_all ☐ run_tests ☐ validate_data ☐ (+ screenshot harness if visual ☐)

## 8. ASK BRIAN
- <decision>: options A / B / C, recommendation, and what's blocked until answered.

## 9. Docs to update
- `docs/design/<doc>.md` section:
- README (tests count / feature list):
- ROADMAP "Built <date>":
