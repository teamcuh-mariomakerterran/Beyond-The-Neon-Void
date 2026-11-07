extends SceneTree
## Captures a unit raising a gun and firing twice, every frame, for GIFs.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 600x600 --fixed-fps 30 -s res://tests/aim_shot.gd -- <unit folder> <weapon art> <out dir>
func _initialize() -> void:
	await process_frame
	var b: RefCounted = load("res://tests/aim_shot_body.gd").new()
	await b.run(self)
	quit()
