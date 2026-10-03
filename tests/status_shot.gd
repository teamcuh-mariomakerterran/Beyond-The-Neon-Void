extends SceneTree
## Docs screenshot: one unit per status look.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1600x900 -s res://tests/status_shot.gd -- <unit png> <out.png>
func _initialize() -> void:
	await process_frame
	var b: RefCounted = load("res://tests/status_shot_body.gd").new()
	await b.run(self)
	quit()
