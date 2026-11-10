extends SceneTree
## Which wall height (1, 2 or 3 tiles) a building-kit sheet was built at.
## The stair piece climbs exactly one tile, so its back edge is the yardstick;
## the tallest wall edge divided by it is the set's height. Only reads.
##
##   godot --headless -s tools/art/kit_height.gd -- <sheet or folder of sheets>

const EXT := ["png", "webp"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: godot --headless -s tools/art/kit_height.gd -- <sheet or folder>")
		quit(1)
		return
	var src: String = args[0]
	var files: Array[String] = []
	if FileAccess.file_exists(src):
		files.append(src)
	else:
		for f in DirAccess.get_files_at(src):
			if f.get_extension().to_lower() in EXT:
				files.append(src.path_join(f))
	files.sort()
	for f in files:
		var r := measure(Image.load_from_file(f))
		if r.is_empty():
			print("%s: no stair piece found (can't tell)" % f.get_file())
		else:
			print("%s: height %d  (stair rises %d px, tallest wall %d px)" % [f.get_file(), r["height"], r["rise"], r["wall"]])
	quit(0)


## {height, rise, wall} for a sheet, or {} without a recognisable stair.
static func measure(src: Image) -> Dictionary:
	if src == null:
		return {}
	var img := ArtCutter.key(src)
	var rises: Array[int] = []
	var wall := 0
	for r: Rect2i in ArtCutter.pieces(img):
		var l := _edge(img, r.position.x + 2, r)
		var rt := _edge(img, r.end.x - 3, r)
		var hi := maxi(l, rt)
		var lo := mini(l, rt)
		if hi >= 12 and lo * 10 <= hi * 3:
			rises.append(hi)  # a ramp shape: one side tall, the other at floor level
		elif lo * 10 >= hi * 7:
			wall = maxi(wall, lo)  # both sides tall: a wall or block
	if rises.is_empty() or wall == 0:
		return {}
	rises.sort()
	var rise := rises[rises.size() / 2]
	return {"height": clampi(roundi(float(wall) / rise), 1, 3), "rise": rise, "wall": wall}


## Opaque run (top to bottom) of one column inside a piece.
static func _edge(img: Image, x: int, r: Rect2i) -> int:
	var top := -1
	var bot := -1
	for y in range(r.position.y, r.end.y):
		if img.get_pixel(x, y).a > 0.5:
			if top < 0:
				top = y
			bot = y
	return bot - top + 1 if top >= 0 else 0
