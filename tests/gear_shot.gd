extends SceneTree
## Before/after screenshots for attached gear (weapons on hand points).
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1600x900 -s res://tests/gear_shot.gd -- closeup <out.png> [weapon art] [unit folder ...]
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1920x1080 -s res://tests/gear_shot.gd -- battle <out.png> [weapon art|-]
func _initialize() -> void:
	await process_frame
	var b: RefCounted = load("res://tests/gear_shot_body.gd").new()
	await b.run(self)
	quit()
