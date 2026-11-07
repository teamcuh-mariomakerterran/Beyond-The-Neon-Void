extends SceneTree
## Captures a unit hopping up a ledge, frame by frame, for before/after GIFs.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 900x600 --fixed-fps 30 -s res://tests/hop_shot.gd -- <unit folder> <out dir> <jump|walk>
func _initialize() -> void:
	await process_frame
	var b: RefCounted = load("res://tests/hop_shot_body.gd").new()
	await b.run(self)
	quit()
