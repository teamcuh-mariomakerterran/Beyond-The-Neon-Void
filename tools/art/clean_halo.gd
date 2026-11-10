extends SceneTree
## Cleans the light outline round sprites that are already cut out:
##   * a white halo (outside the art) is erased, starting from the empty space
##     and going at most N pixels in (default 2): white inside the art stays
##   * a light rim on the art's own edge (the line that shows where walls and
##     tiles meet) takes the colour of the pixel just inside it, so tiles keep
##     their size. --no-rim skips this.
## Writes cleaned copies; the originals stay as they are.
##
##   godot --headless -s tools/art/clean_halo.gd -- <in file or folder> <out folder> [--depth=3] [--no-rim]

const EXT := ["png", "webp"]

var _rim := true


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var paths := Array(args).filter(func(a: String) -> bool: return not a.begins_with("--"))
	var depth := 2
	_rim = not "--no-rim" in args
	for a: String in args:
		if a.begins_with("--depth="):
			depth = maxi(int(a.get_slice("=", 1)), 1)
	if paths.size() < 2:
		print("usage: godot --headless -s tools/art/clean_halo.gd -- <in> <out> [--depth=3]")
		quit(1)
		return
	var n := _run(str(paths[0]), str(paths[1]), depth)
	print("cleaned %d sprites" % n)
	quit(0)


func _run(src: String, out: String, depth: int) -> int:
	if FileAccess.file_exists(src):
		var img := Image.load_from_file(src)
		if img == null:
			return 0
		var px := ArtCutter.remove_halo(img, depth)
		var rim := ArtCutter.fix_rim(img) if _rim else 0
		DirAccess.make_dir_recursive_absolute(out)
		img.save_png(out.path_join(src.get_file().get_basename() + ".png"))
		print("%s: %d halo pixels erased, %d rim pixels recoloured" % [src.get_file(), px, rim])
		return 1
	var n := 0
	for f in DirAccess.get_files_at(src):
		if f.get_extension().to_lower() in EXT:
			n += _run(src.path_join(f), out, depth)
	for sub in DirAccess.get_directories_at(src):
		n += _run(src.path_join(sub), out.path_join(sub), depth)
	return n
