extends SceneTree
## AI behaviour probe: runs seeded AI-vs-AI battles headless and reports HOW the AI plays,
## not just who wins. Signal-based: needs no changes to game code.
##   godot --headless --path <repo> -s <abs>/ai_probe.gd -- [--missions=a,b] [--seeds=3] [--level=6] [--json=path]
## Per team: turns, actions/turn, AP left unused at turn end, idle turns (no ability),
## moves/turn, ms per turn (planning + resolution, animate off), top abilities, heals,
## turn-cap stalemates.
func _initialize() -> void:
	await process_frame
	var body: GDScript = load(get_script().resource_path.get_base_dir().path_join("ai_probe_body.gd"))
	if body == null or not body.can_instantiate():
		printerr("ai_probe: body does not compile")
		quit(2)
		return
	quit(await body.new().run(self, OS.get_cmdline_user_args()))
