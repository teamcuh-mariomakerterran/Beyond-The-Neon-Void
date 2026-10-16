<!-- Paste into the repo root CLAUDE.md (Beyond-The-Neon-Void). Keep it short; skills hold the depth. -->

# Beyond: The Neon Void: notes for Claude

Cyberpunk turn-based tactics RPG, a spiritual successor to Final Fantasy Tactics, set in the world of **The Black Doctrine**. Godot **4.7.2** standard, GDScript only.

## Always
- Load the `neon-void-architect` skill first, then the specialist skill for the task (its routing table).
- Run `py -3 .claude/skills/neon-void-architect/scripts/repo_facts.py .` at session start. Trust it over memory.
- **Data first:** content is JSON in `data/`, loaded by `ContentDB` into `GameResource` subclasses; Neon Forge (F1) edits the same files. New field means an `@export` var (it becomes loadable, saveable and Forge-editable automatically).
- **EventBus** (`src/autoload/event_bus.gd`) is the contract between systems. Rules emit signals or `Cues.fire(...)` names; they never call tweens, camera, sfx or `Engine.time_scale` directly.
- **Headless-safe:** respect `CombatManager.animate`. Tests run battles with `animate=false, autobattle=true`.
- Persistent state goes in `GameManager.story_flags` (namespaced keys) or in SaveManager with a round-trip test.
- Static typing, tabs, `##` file headers, `class_name` on everything except autoloads.
- Every feature gets a `test_<feature>()` in `tests/test_world.gd` or `tests/test_suite.gd`.

## Verify before saying done
```
godot --headless --path . --import
godot --headless --path . -s res://tests/compile_all.gd
godot --headless --path . -s res://tests/run_tests.gd
py -3 .claude/skills/godot-verify/scripts/validate_data.py .
```
Or run the whole gate: `powershell -ExecutionPolicy Bypass -File .claude/skills/godot-verify/scripts/verify.ps1`

## Never
- TileMap, a second grid, a second currency, `.tres` saves, `class_name` on autoloads.
- New `RandomNumberGenerator.new()` in rules code (use `CombatManager.rng`).
- Moving or renaming originals in shared Black Doctrine asset folders.
- Editing `legacy/original_gd/` (reference only, `.gdignore`d).
- Inventing canon names or lore. Use `franchise-bible`, mark proposals `[BNV PROPOSAL]`.

## ASK BRIAN (open decisions; do not pick)
Facings (cardinal in code vs 4 diagonals in art) · tile scale (128×64 v2 vs 64×32 v1/BD) · Veil vs Viel · Lattice `holds` unit · progression model (`unlocks_mission_ids` vs `GameData.mission_sequence`).

## Docs to read before design work
`docs/design/ROADMAP.md` (Brian's calls) · `BIG_IDEAS.md` (status tags) · `WORLD_FORMAT.md` · `TACTICAL_MASKS.md` · `docs/research/WORLD_MAP_FF8_FF9.md` · `docs/lore/LORE_DIGEST.md`.
