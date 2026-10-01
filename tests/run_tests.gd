extends SceneTree
## Headless test runner:  godot --headless --path . -s res://tests/run_tests.gd


func _initialize() -> void:
	await process_frame  # autoloads finish _ready
	var suite: RefCounted = load("res://tests/test_suite.gd").new()
	var fails: int = await suite.run(self)
	# A suite that fails to compile loads as null: count it, don't hang.
	var world_script: GDScript = load("res://tests/test_world.gd")
	if world_script == null or not world_script.can_instantiate():
		printerr("FAIL: tests/test_world.gd does not compile")
		fails += 1
	else:
		var world_suite: RefCounted = world_script.new()
		fails += await world_suite.run(self)
	quit(1 if fails > 0 else 0)
