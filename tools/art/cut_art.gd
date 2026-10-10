extends SceneTree
## Cuts generated art into game sprites (see docs/design/ART_CUTTER.md).
##
##   godot --headless -s tools/art/cut_art.gd -- <in> <out> [--screens]
##
## <in> is an image or a folder. Every image is keyed (magenta / flat
## background → transparent, painted shadows → soft shadow, pink fringe
## cleaned) and split into one PNG per item. Sub-folders keep their names
## under <out>. Folders whose name has "screen" or "sign" in it (or
## --screens) also get <name>.screen.json: the glass corners for living
## signage, picked up when the prop is placed in the World Painter.
## A sheet can name its items: <sheet>.names.txt, one name per line, in
## reading order (rows top to bottom, left to right). Originals are never touched.

const EXT := ["png", "webp", "jpg", "jpeg"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var flags := Array(args).filter(func(a: String) -> bool: return a.begins_with("--"))
	var paths := Array(args).filter(func(a: String) -> bool: return not a.begins_with("--"))
	if paths.size() < 2:
		print("usage: godot --headless -s tools/art/cut_art.gd -- <in> <out> [--screens]")
		quit(1)
		return
	var n := _run(_abs(paths[0]), _abs(paths[1]), "--screens" in flags)
	print("cut %d sprites" % n)
	quit(0)


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p


func _run(src: String, out: String, screens: bool) -> int:
	if FileAccess.file_exists(src):
		return _one(src, out, screens)
	var n := 0
	var d := DirAccess.open(src)
	if d == null:
		push_error("can't open " + src)
		return 0
	for f in d.get_files():
		if f.get_extension().to_lower() in EXT:
			n += _one(src.path_join(f), out, screens)
	for sub in d.get_directories():
		var s := screens or "screen" in sub.to_lower() or "sign" in sub.to_lower()
		n += _run(src.path_join(sub), out.path_join(sub.to_snake_case()), s)
	return n


func _one(file: String, out: String, screens: bool) -> int:
	var prefix := file.get_file().get_basename().to_snake_case().replace(" ", "_").replace("-", "_")
	var names := PackedStringArray()
	var nf := file.get_basename() + ".names.txt"
	if FileAccess.file_exists(nf):
		names = FileAccess.get_file_as_string(nf).strip_edges().split("\n")
	var t := Time.get_ticks_msec()
	var made := ArtCutter.cut_file(file, out, prefix, names, screens)
	print("%s → %d (%d ms)" % [file.get_file(), made.size(), Time.get_ticks_msec() - t])
	return made.size()
