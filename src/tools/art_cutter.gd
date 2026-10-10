class_name ArtCutter
extends RefCounted
## Turns generated art into clean game sprites:
##   * key()      drops a flat background (magenta by default, or whatever
##                colour fills the corners), turns its darker shades (drop
##                shadows painted on the background) into soft black shadow,
##                and cleans the magenta fringe left around already-cut art
##   * pieces()   finds each separate item on a sheet (rects, reading order)
##   * screen_corners()  finds the dark glass on a blank display, as the four
##                corners Signage wants (u, v across the sprite's visible box)
##   * cut_file() all of it for one file, writing PNGs (+ .screen.json)
## Run over a folder with tools/art/cut_art.gd (see docs/design/ART_CUTTER.md).

const MAGENTA := Color8(213, 0, 172)
## How close (0–1 RGB distance) counts as background.
const KEY_TOL := 0.2
## Pixels this close to the edge get the magenta fringe cleaned.
const FRINGE_PX := 4
## Glass: within this of the panel's main colour.
const GLASS_TOL := 0.13


## Background colour of a sheet: the corners when they are opaque and agree,
## else magenta (already-cut art with a magenta halo).
static func background(img: Image) -> Color:
	var w := img.get_width() - 1
	var h := img.get_height() - 1
	var cs := [img.get_pixel(0, 0), img.get_pixel(w, 0), img.get_pixel(0, h), img.get_pixel(w, h)]
	for c: Color in cs:
		if c.a < 0.9 or _dist(c, cs[0]) > 0.08:
			return MAGENTA
	return cs[0]


static func key(src: Image, bg: Color = Color(0, 0, 0, 0)) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if bg.a == 0.0:
		bg = background(img)
	var w := img.get_width()
	var h := img.get_height()
	var bb := bg.r * bg.r + bg.g * bg.g + bg.b * bg.b
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if _dist(c, bg) < KEY_TOL:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# A darker shade of the background = shadow painted on it.
			var k := (c.r * bg.r + c.g * bg.g + c.b * bg.b) / maxf(bb, 0.001)
			var res := Vector3(c.r - k * bg.r, c.g - k * bg.g, c.b - k * bg.b).length()
			if k > 0.25 and k < 1.0 and res < 0.07:
				img.set_pixel(x, y, Color(0.02, 0.0, 0.04, (1.0 - k) * 0.9))
	_defringe(img, bg)
	return img


## Edge pixels still tinted like the background: bright ones go, dark ones
## become a neutral outline.
static func _defringe(img: Image, bg: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dist := _edge_distance(img)
	for y in h:
		for x in w:
			var d: int = dist[y * w + x]
			if d == 0 or d > FRINGE_PX:
				continue
			var c := img.get_pixel(x, y)
			if c.a < 0.95 or not _tinted(c, bg):
				continue
			if c.r + c.b > 0.7 and d <= 2:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var v := minf((c.r + c.g + c.b) / 3.0 * 0.6, 0.18)
				img.set_pixel(x, y, Color(v, v * 0.95, v * 1.1, c.a))


static func _tinted(c: Color, bg: Color) -> bool:
	if bg.g > 0.3 or c.g > 0.4:
		return false
	var lo := minf(c.r, c.b)
	return lo - c.g > 0.05 and lo > c.g * 1.8 + 0.02 and absf(c.r - c.b) < maxf(c.r, c.b) * 0.75


## Distance (steps, 4-neighbour) from each opaque pixel to transparency; 0 = transparent.
static func _edge_distance(img: Image) -> PackedInt32Array:
	var w := img.get_width()
	var h := img.get_height()
	var out := PackedInt32Array()
	out.resize(w * h)
	var q: Array[int] = []
	for y in h:
		for x in w:
			var i := y * w + x
			if img.get_pixel(x, y).a < 0.05:
				out[i] = 0
			elif x == 0 or y == 0 or x == w - 1 or y == h - 1 or img.get_pixel(x - 1, y).a < 0.05 or img.get_pixel(x + 1, y).a < 0.05 \
					or img.get_pixel(x, y - 1).a < 0.05 or img.get_pixel(x, y + 1).a < 0.05:
				out[i] = 1
				q.append(i)
			else:
				out[i] = 1 << 20
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var d := out[i]
		if d >= FRINGE_PX:
			continue
		var x := i % w
		var y := i / w
		for n: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
			if n >= 0 and out[n] > d + 1:
				out[n] = d + 1
				q.append(n)
	return out


## Bounding rects of the separate items (connected opaque pixels, merged when
## closer than `gap`), smaller than `min_px` pixels dropped, in reading order.
static func pieces(img: Image, gap: int = 4, min_px: int = 60) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for p: Dictionary in find_pieces(img, gap, min_px)["pieces"]:
		out.append(p["rect"])
	return out


## {pieces: [{rect, ids}] in reading order, map: label per pixel (0 = none)}.
## A piece's pixels are those whose label is in its ids.
static func find_pieces(img: Image, gap: int = 4, min_px: int = 60) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedInt32Array()
	seen.resize(w * h)
	var found: Array = []  # [Rect2i, count, ids]
	for y0 in h:
		for x0 in w:
			var i0 := y0 * w + x0
			if seen[i0] or img.get_pixel(x0, y0).a < 0.5:
				continue
			var label := found.size() + 1
			seen[i0] = label
			var stack: Array[int] = [i0]
			var r := Rect2i(x0, y0, 1, 1)
			var n := 0
			while not stack.is_empty():
				var i: int = stack.pop_back()
				var x := i % w
				var y := i / w
				n += 1
				r = r.expand(Vector2i(x, y))
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						var j := ny * w + nx
						if not seen[j] and img.get_pixel(nx, ny).a >= 0.5:
							seen[j] = label
							stack.append(j)
			found.append([Rect2i(r.position, r.size + Vector2i.ONE), n, [label]])
	# Soft pixels (shadow, edge halo) join the item they touch.
	var q: Array[int] = []
	for i in w * h:
		if seen[i] != 0:
			q.append(i)
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var x := i % w
		var y := i / w
		for n: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
			if n >= 0 and seen[n] == 0 and img.get_pixel(n % w, n / w).a > 0.0:
				seen[n] = seen[i]
				q.append(n)
	# Fold specks into the item they nearly touch (a bottle's cap, a loose
	# rung); two real items never merge, however close.
	var merged := true
	while merged:
		merged = false
		for a in found.size():
			for b in range(a + 1, found.size()):
				var small := mini(int(found[a][1]), int(found[b][1])) < maxi(int(found[a][1]), int(found[b][1])) / 12
				if small and (found[a][0] as Rect2i).grow(gap).intersects(found[b][0]):
					found[a] = [(found[a][0] as Rect2i).merge(found[b][0]), int(found[a][1]) + int(found[b][1]), found[a][2] + found[b][2]]
					found.remove_at(b)
					merged = true
					break
			if merged:
				break
	var keep: Array = []
	for f: Array in found:
		if int(f[1]) >= min_px:
			keep.append(f)
	# Reading order: rows (items whose vertical centres overlap), then left to right.
	keep.sort_custom(func(p: Array, q: Array) -> bool: return (p[0] as Rect2i).get_center().y < (q[0] as Rect2i).get_center().y)
	var rows: Array = []
	for f: Array in keep:
		var r: Rect2i = f[0]
		if rows.is_empty() or r.position.y > (rows[-1][0][0] as Rect2i).end.y - (rows[-1][0][0] as Rect2i).size.y / 3:
			rows.append([f])
		else:
			rows[-1].append(f)
	var ordered: Array = []
	for row: Array in rows:
		row.sort_custom(func(p: Array, q: Array) -> bool: return (p[0] as Rect2i).position.x < (q[0] as Rect2i).position.x)
		for f: Array in row:
			ordered.append({"rect": f[0], "ids": f[2]})
	return {"pieces": ordered, "map": seen}


## The display's glass as [[u,v] TL, TR, BR, BL] across the visible box, or []
## if there's no big dark panel. Isometric panels have vertical sides, so the
## corners are the top / bottom of the glass at its leftmost and rightmost columns.
static func screen_corners(img: Image) -> Array:
	var used := img.get_used_rect()
	if used.size.x < 4 or used.size.y < 4:
		return []
	var w := img.get_width()
	var top := PackedInt32Array()
	var bot := PackedInt32Array()
	top.resize(w)
	bot.resize(w)
	top.fill(-1)
	var total := 0
	var ref := glass_color(img, used)
	for x in range(used.position.x, used.end.x):
		var run_best := [-1, -1]
		var start := -1
		for y in range(used.position.y, used.end.y + 1):
			var g := y < used.end.y and _glass(img.get_pixel(x, y), ref)
			if g and start < 0:
				start = y
			elif not g and start >= 0:
				if y - start > run_best[1] - run_best[0]:
					run_best = [start, y]
				start = -1
		if run_best[0] >= 0 and run_best[1] - run_best[0] >= used.size.y * 0.15:
			top[x] = run_best[0]
			bot[x] = run_best[1]
			total += run_best[1] - run_best[0]
	var cols: Array[int] = []
	for x in w:
		if top[x] >= 0:
			cols.append(x)
	if cols.size() < used.size.x * 0.15 or total < used.get_area() * 0.08:
		return []
	# The glass's top and bottom edges are straight lines: fit each over the
	# middle of the panel (bevels and stray frame pixels sit at the ends).
	var x0 := cols[int(cols.size() * 0.02)]
	var x1 := cols[int(cols.size() * 0.98) - 1]
	if x0 - used.position.x <= 1 and used.end.x - 1 - x1 <= 1:
		return []  # "glass" right to both sides: no frame, so not a display
	var t_fit := _fit(cols, top, 0.15, 0.85)
	var b_fit := _fit(cols, bot, 0.15, 0.85)
	var uv := func(px: float, line: Vector2) -> Array:
		var py := line.x * px + line.y
		return [snappedf(clampf((px - used.position.x) / used.size.x, 0, 1), 0.001), snappedf(clampf((py - used.position.y) / used.size.y, 0, 1), 0.001)]
	return [uv.call(x0, t_fit), uv.call(x1 + 1, t_fit), uv.call(x1 + 1, b_fit), uv.call(x0, b_fit)]


## Least-squares line y = a·x + b through ys[x] for the columns between the
## `lo` and `hi` fractions of `cols`, as Vector2(a, b).
static func _fit(cols: Array[int], ys: PackedInt32Array, lo: float, hi: float) -> Vector2:
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	var n := 0.0
	for k in range(int(cols.size() * lo), maxi(int(cols.size() * hi), int(cols.size() * lo) + 1)):
		var x := float(cols[k])
		var y := float(ys[cols[k]])
		sx += x
		sy += y
		sxx += x * x
		sxy += x * y
		n += 1.0
	var den := n * sxx - sx * sx
	if absf(den) < 0.001:
		return Vector2(0, sy / maxf(n, 1.0))
	var a := (n * sxy - sx * sy) / den
	return Vector2(a, (sy - a * sx) / n)


## The glass colour: the commonest colour in the middle of the sprite.
static func glass_color(img: Image, used: Rect2i) -> Color:
	var counts := {}
	var mid := Rect2i(used.position + used.size * 3 / 10, used.size * 4 / 10)
	for y in range(mid.position.y, mid.end.y):
		for x in range(mid.position.x, mid.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.9:
				var k := (c.r8 >> 3) << 10 | (c.g8 >> 3) << 5 | (c.b8 >> 3)
				counts[k] = int(counts.get(k, 0)) + 1
	var best := -1
	for k: int in counts:
		if best < 0 or counts[k] > counts[best]:
			best = k
	if best < 0:
		return Color.BLACK
	return Color8(((best >> 10) & 31) * 8 + 4, ((best >> 5) & 31) * 8 + 4, (best & 31) * 8 + 4)


static func _glass(c: Color, ref: Color) -> bool:
	return c.a > 0.9 and _dist(c, ref) < GLASS_TOL


static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Key + cut one file into `out_dir`. A sheet with several items gives
## <prefix>_01.png …; a single item gives <prefix>.png. `names` (reading
## order) replaces the numbers. `screens` also writes <name>.screen.json.
## Returns the written paths.
static func cut_file(path: String, out_dir: String, prefix: String, names: PackedStringArray = [], screens: bool = false, pad: int = 2) -> Array[String]:
	var src := Image.load_from_file(path)
	var out: Array[String] = []
	if src == null:
		return out
	var img := key(src)
	var found := find_pieces(img)
	var map: PackedInt32Array = found["map"]
	var rects: Array[Rect2i] = []
	for p: Dictionary in found["pieces"]:
		rects.append(p["rect"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	for k in rects.size():
		var name := prefix
		if k < names.size() and names[k].strip_edges() != "":
			name = names[k].strip_edges()
		elif rects.size() > 1:
			name = "%s_%02d" % [prefix, k + 1]
		var r := rects[k].grow(pad).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var piece := img.get_region(r)
		if rects.size() > 1:
			_mask(piece, r.position, map, img.get_width(), found["pieces"][k]["ids"])
		var file := out_dir.path_join(name + ".png")
		piece.save_png(file)
		out.append(file)
		var side := out_dir.path_join(name + ".screen.json")
		var corners := screen_corners(piece) if screens else []
		if not corners.is_empty():
			var f := FileAccess.open(side, FileAccess.WRITE)
			f.store_string(JSON.stringify({"corners": corners, "feed": "ads", "mode": "lcd"}, "\t") + "\n")
		elif FileAccess.file_exists(side):
			DirAccess.remove_absolute(side)  # re-cut: no glass any more
	return out


## Clear pixels of other items that fall inside this item's box.
static func _mask(piece: Image, at: Vector2i, map: PackedInt32Array, w: int, ids: Array) -> void:
	for y in piece.get_height():
		for x in piece.get_width():
			var l := map[(at.y + y) * w + at.x + x]
			if not ids.has(l):
				piece.set_pixel(x, y, Color(0, 0, 0, 0))
