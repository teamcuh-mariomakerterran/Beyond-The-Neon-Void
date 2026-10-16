extends SceneTree
## Seeded battle replay + balance check for Beyond The Neon Void.
## Runs each (mission, roster, seed) battle TWICE headless and compares an event
## trace hash: any difference = non-determinism (an unseeded RNG in the rules path).
##
##   godot --headless --path <repo> -s <abs path>/replay_check.gd -- [options]
##     --missions=m01_the_brew_plan,m02_shift_change   (default: every mission in ContentDB)
##     --seeds=3            seeds per roster (101, 102, ...)
##     --level=6            party level (enemies use their mission level)
##     --rosters=default    "default" = starting crew classes, "suite" = the 6 test_suite rosters
##     --json=<path>        also write a JSON report
##     --no-twice           skip the replay comparison (balance numbers only)
##
## Works from any folder: the body is loaded after autoloads exist (a -s script
## compiles before autoload names are registered, so it must not name them).

func _initialize() -> void:
	await process_frame
	var body_path: String = get_script().resource_path.get_base_dir().path_join("replay_body.gd")
	var body_script: GDScript = load(body_path)
	if body_script == null or not body_script.can_instantiate():
		printerr("replay_check: cannot load ", body_path)
		quit(2)
		return
	var code: int = await body_script.new().run(self, OS.get_cmdline_user_args())
	quit(code)
