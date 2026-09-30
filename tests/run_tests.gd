extends SceneTree
## Headless test runner:  godot --headless --path . -s res://tests/run_tests.gd


func _initialize() -> void:
	await process_frame  # autoloads finish _ready
	var suite: RefCounted = load("res://tests/test_suite.gd").new()
	var fails: int = await suite.run(self)
	var world_suite: RefCounted = load("res://tests/test_world.gd").new()
	fails += await world_suite.run(self)
	quit(1 if fails > 0 else 0)
