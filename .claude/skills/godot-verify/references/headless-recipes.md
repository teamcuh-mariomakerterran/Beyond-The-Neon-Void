# Headless Godot 4.7 recipes for BTNV

## Binaries
- **Windows:** use `Godot_v4.7.2-stable_win64_console.exe`, which prints to the terminal. The plain `…win64.exe` is a GUI-subsystem build: output gets lost and exit codes are unreliable in pipes.
- Point `$env:GODOT` at it once: `setx GODOT "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"` (open a new terminal afterwards).
- Box/Linux: `Godot_v4.7.2-stable_linux.x86_64`.

## The commands the repo already supports (README / test headers)
```powershell
& $env:GODOT --headless --path . --import                         # fresh clone: builds .godot\ (class_name cache)
& $env:GODOT --headless --path . -s res://tests/compile_all.gd     # loads every .gd/.tscn under src, scenes, tests
& $env:GODOT --headless --path . -s res://tests/run_tests.gd       # test_suite.gd + test_world.gd
```
- `compile_all` prints `compile_all: N files, M failures` and exits 1 on failure (135 files on the snapshot).
- `run_tests` prints `=== P passed, F failed ===` (suite) and `=== world: P passed, F failed ===`, and exits 1 if anything fails.

Measured on the box snapshot (Godot 4.7.2):
| Step | Result |
|---|---|
| import | 4.5 s |
| compile_all | 135 files, 0 failures |
| suite | 641 / 0 |
| world | 334 / 9, all 9 from missing art or fixtures (`scripts/known_failures.txt`) |
| AI-vs-AI | player side 19/36 |
| full `verify.sh` | ~70 s |

## The -s script rule (learned the hard way)
A `-s` SceneTree script **compiles before autoload names are registered**. Naming `ContentDB`, `CombatManager`, etc. in it is a compile error. Use the two-file pattern the repo uses (`run_tests.gd` → `test_suite.gd`):

```gdscript
# runner.gd  (no autoload names in here)
extends SceneTree
func _initialize() -> void:
	await process_frame                                  # autoloads finish _ready
	var body: GDScript = load(get_script().resource_path.get_base_dir().path_join("body.gd"))
	if body == null or not body.can_instantiate():
		printerr("cannot load body"); quit(2); return
	quit(await body.new().run(self, OS.get_cmdline_user_args()))
```
```gdscript
# body.gd  (autoloads are fine here)
extends RefCounted
func run(tree: SceneTree, args: PackedStringArray) -> int:
	print(ContentDB.get_mission("m01_the_brew_plan") != null)
	return 0
```
- **Absolute script paths work** (`-s C:/…/.claude/skills/godot-verify/scripts/gd/replay_check.gd`), so skill scripts run without being copied into `res://`. Use forward slashes.
- Args after `--` arrive via `OS.get_cmdline_user_args()`.
- A body that fails to compile loads as `null`. Count it as a failure; never hang.

## Script-error scan
After any Godot run, grep the log for `SCRIPT ERROR|Parse Error|Compile Error|Failed to load script`. `compile_all` misses runtime errors. The tests log contains one known `SCRIPT ERROR` (`test_world.gd:430`, `'tex'` on a Dictionary) that is downstream of the missing lattice fixture.

## Gotchas found on the snapshot
- **`legacy/original_gd/.gdignore` missing:** Godot parses the 2025 legacy scripts (`AIBehavior.gd`, `Ability.gd`, …), which register duplicate `class_name`s and break autoload compilation. The snapshot copy lacked it (dotfiles may simply not have been copied). If it's missing in the real repo, add the empty file (with Brian's OK).
- **Missing art:** the snapshot has no icon packs or lattice fixtures, so 9 world tests fail. On Brian's full checkout they should pass. Delete lines from `known_failures.txt` once they do.
- **Fresh clone or a new `class_name` file:** the global class cache lives in `.godot/`. Run `--import` after cloning **and after adding any new `class_name` script**. Otherwise the new name is unknown, `load()` of code that uses it returns `null`, and an unguarded `-s` runner **hangs** because `quit()` is never reached. `verify` imports on every full run.
- **Timeouts:** a battle that never ends is capped by `CombatManager.MAX_TURNS = 600`. Wrap every headless call in a timeout anyway (`verify` does).

## Writing a new test
- **Pure logic** goes in `tests/test_suite.gd`: add `func test_x() -> void:` and call it from `run()`. Use `check(cond, "message")`, and `await` for anything that needs frames (pattern: `test_battles`).
- **World, renderer or Forge** tests go in `tests/test_world.gd` (same `check` pattern).
- **Battles:** copy `_run_battle(mission_id, classes, seed)`. Always pass a seed, set `CombatManager.animate = false` and `autobattle = true`, free units and call `stop_battle()` after.
- **Never write to `data/`** from tests. Use `user://` or in-memory dictionaries (`WorldMap.from_dict`, `ContentDB` getters).
- Templates: `templates/test_snippet.gd.txt`, `templates/runner.gd`, `templates/body.gd`.
