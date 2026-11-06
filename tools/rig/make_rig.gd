extends SceneTree
## Writes rig.json (hand / head anchor points per frame) for unit folders.
## godot --headless --path . -s res://tools/rig/make_rig.gd -- <body folder> [<more>] [--force]
## Free and local (RigEstimate). Body folders are PixelLab or PixelMatrix units.
##
## --dump <dir> [--anims a,b] [--first]: instead, save the frames the game plays as
## <dir>/<unit>/<anim>__<frame>.png plus index.json ({unit: body folder}), for
## tools/pixellab/skeleton_rig.py (PixelLab skeleton points, 0.1 generation a frame).
func _initialize() -> void:
	await process_frame
	# Loaded here, not preloaded: autoloads must exist first (the -s trap).
	var est: GDScript = load("res://src/vfx/rig_estimate.gd")
	var args := OS.get_cmdline_user_args()
	var force := args.has("--force")
	var dump := _opt(args, "--dump")
	var only := _opt(args, "--anims").split(",", false)
	var index := {}
	var skip := ["--dump", "--anims"]
	for i in args.size():
		var a: String = args[i]
		if a.begins_with("--") or (i > 0 and str(args[i - 1]) in skip):
			continue
		if dump != "":
			var n: int = est.dump_frames(a, dump.path_join(a.get_file()), only, args.has("--first"))
			index[a.get_file()] = a
			print("%s: dumped %d frames" % [a, n])
			continue
		var rig: Dictionary = est.write_for(a, force)
		var n := 0
		for anim: String in (rig.get("points", {}).get("hand_r", {}).get("anims", {}) as Dictionary):
			n += 1
		print("%s: %s (%d anims)" % [a, "ok" if not rig.is_empty() else "FAILED", n])
	if dump != "":
		var f := FileAccess.open(dump.path_join("index.json"), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(index, "\t"))
	quit()


func _opt(args: PackedStringArray, name: String) -> String:
	var i := args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""
