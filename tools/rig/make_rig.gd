extends SceneTree
## Writes rig.json (hand / head anchor points per frame) for unit folders.
## godot --headless --path . -s res://tools/rig/make_rig.gd -- <body folder> [<more>] [--force]
## Free and local (RigEstimate). Body folders are PixelLab or PixelMatrix units.
func _initialize() -> void:
	await process_frame
	# Loaded here, not preloaded: autoloads must exist first (the -s trap).
	var est: GDScript = load("res://src/vfx/rig_estimate.gd")
	var args := OS.get_cmdline_user_args()
	var force := args.has("--force")
	for a: String in args:
		if a.begins_with("--"):
			continue
		var rig: Dictionary = est.write_for(a, force)
		var n := 0
		for anim: String in (rig.get("points", {}).get("hand_r", {}).get("anims", {}) as Dictionary):
			n += 1
		print("%s: %s (%d anims)" % [a, "ok" if not rig.is_empty() else "FAILED", n])
	quit()
