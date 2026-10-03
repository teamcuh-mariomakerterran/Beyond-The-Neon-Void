class_name CableNet
extends Node2D
## Overhead cables strung between buildings, generated from wherever the
## buildings actually stand, so moving or deleting one in the World Painter
## re-strings the city. Anchors are roof-edge points on each structure:
## automatic (found from the art's roofline) or hand-placed in the editor.
## Spans = a minimum spanning tree (every building connected, no redundant
## runs) plus a few extra short spans for density. Each span sags with its
## length and sways on its own phase. A few are live neon with a travelling
## pulse, and some carry hanging junk (lanterns, flags, shoes).
##
## Map settings (WorldMap.cables): {enabled, live, extra, sway, color, debris}.
## Object settings: "cables": "auto" (default) | "none" | [[u, v], …] with
## u, v as 0–1 fractions of the sprite's visible box.

const SEG_PER_SPAN := 14
const SAG_RATIO := 0.18
const SWAY_SPEED := 0.6
const MAX_LINKS := 3  # spans per anchor
const LIVE_COLORS := [Color(0.25, 1.0, 1.0), Color(1.0, 0.25, 0.8), Color(1.0, 0.7, 0.2)]

var renderer: WorldRenderer
var spans: Array[Dictionary] = []  # {a, b, sag, phase, live, color, junk}
var anchors: Array[Dictionary] = []  # {pos, owner}
var _dirty := 2
var show_anchors := false  # World Painter anchor editing
static var _auto_cache: Dictionary = {}  # asset -> Array of uv


func _ready() -> void:
	z_as_relative = false
	z_index = 4000  # one layer above the city (first pass, per the design note)


func mark_dirty() -> void:
	_dirty = 2  # objects compute their boxes when they first draw: wait a frame


static func settings_of(w: WorldMap) -> Dictionary:
	var s: Dictionary = {"enabled": w.kind in ["city", "hub"], "live": 0.12, "extra": 0.15, "sway": 2.0, "color": "#0a0a12", "debris": true}
	s.merge(w.cables, true)
	return s


func _process(_d: float) -> void:
	if _dirty > 0:
		_dirty -= 1
		if _dirty == 0:
			rebuild()
	if not spans.is_empty() or show_anchors:
		queue_redraw()


func rebuild() -> void:
	spans.clear()
	anchors.clear()
	if renderer == null or renderer.world == null:
		return
	var w := renderer.world
	var s := settings_of(w)
	if not bool(s["enabled"]):
		queue_redraw()
		return
	for o: Dictionary in w.objects:
		var node: WorldRenderer.WorldSprite = renderer.object_node(str(o.get("id", "")))
		if node == null or not node.visible:
			continue
		for p: Vector2 in anchor_points(node, w):
			anchors.append({"pos": p, "owner": str(o["id"])})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(w.id + "_cables")
	for pair: Array in link_anchors(anchors, w.tile_width * 5.0, float(s["extra"]), rng):
		var a: Vector2 = anchors[pair[0]]["pos"]
		var b: Vector2 = anchors[pair[1]]["pos"]
		var live := rng.randf() < float(s["live"])
		var junk := ""
		if bool(s["debris"]):
			var r := rng.randf()
			junk = "lanterns" if r < 0.07 else ("flags" if r < 0.13 else ("shoes" if r < 0.16 else ""))
		spans.append({"a": a, "b": b, "sag": a.distance_to(b) * SAG_RATIO, "phase": rng.randf() * TAU,
			"live": live, "color": LIVE_COLORS[rng.randi() % LIVE_COLORS.size()], "junk": junk})
	queue_redraw()


## Indices into `pts` to join: a minimum spanning forest over spans no longer
## than `max_span` between different owners, plus `extra` × that many short
## extra spans so the web reads dense instead of tree-like.
static func link_anchors(pts: Array, max_span: float, extra: float, rng: RandomNumberGenerator) -> Array:
	var n := pts.size()
	var out: Array = []
	var links := PackedInt32Array()
	links.resize(n)
	var done := PackedByteArray()
	done.resize(n)
	var ok := func(i: int, j: int) -> bool:
		return pts[i]["owner"] != pts[j]["owner"] and (pts[i]["pos"] as Vector2).distance_to(pts[j]["pos"]) <= max_span
	# Prim's, restarted per island so far-apart blocks each get their own web.
	for start in n:
		if done[start]:
			continue
		done[start] = 1
		var best_d := PackedFloat32Array()
		var best_from := PackedInt32Array()
		best_d.resize(n)
		best_from.resize(n)
		for j in n:
			best_d[j] = INF
			best_from[j] = -1
			if not done[j] and ok.call(start, j):
				best_d[j] = (pts[start]["pos"] as Vector2).distance_to(pts[j]["pos"])
				best_from[j] = start
		while true:
			var pick := -1
			for j in n:
				if not done[j] and best_from[j] >= 0 and (pick < 0 or best_d[j] < best_d[pick]):
					pick = j
			if pick < 0:
				break
			done[pick] = 1
			out.append([best_from[pick], pick])
			links[best_from[pick]] += 1
			links[pick] += 1
			for j in n:
				if not done[j] and ok.call(pick, j):
					var d := (pts[pick]["pos"] as Vector2).distance_to(pts[j]["pos"])
					if d < best_d[j]:
						best_d[j] = d
						best_from[j] = pick
	# Density: the shortest unused cross-building pairs, capped per anchor.
	var have := {}
	for e: Array in out:
		have[Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))] = true
	var cand: Array = []
	for i in n:
		for j in range(i + 1, n):
			if not have.has(Vector2i(i, j)) and ok.call(i, j) and (pts[i]["pos"] as Vector2).distance_to(pts[j]["pos"]) <= max_span * 0.75:
				cand.append([(pts[i]["pos"] as Vector2).distance_to(pts[j]["pos"]) * rng.randf_range(0.8, 1.2), i, j])
	cand.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var budget := ceili(out.size() * extra)
	for c: Array in cand:
		if budget <= 0:
			break
		if links[c[1]] < MAX_LINKS and links[c[2]] < MAX_LINKS:
			out.append([c[1], c[2]])
			links[c[1]] += 1
			links[c[2]] += 1
			budget -= 1
	return out


## World-space roof anchors for one placed object.
static func anchor_points(node: WorldRenderer.WorldSprite, w: WorldMap) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var o: Dictionary = node.data
	var r: Rect2 = node._rect
	if r.size.x <= 1.0:
		return out
	var mode: Variant = o.get("cables", "auto")
	var uvs: Array = []
	if mode is Array:
		uvs = mode
	elif str(mode) == "auto":
		# Only real buildings: tall enough to carry wires overhead.
		if not (str(o.get("kind", "")) in ["structure", "location"]) or r.size.y < w.tile_width * 1.1:
			return out
		uvs = auto_uvs(node, r.size.y > w.tile_width * 2.4)
	var flip := bool(o.get("flip", false))
	for uv: Variant in uvs:
		if not (uv is Array) or (uv as Array).size() < 2:
			continue
		var u := float(uv[0])
		if flip:
			u = 1.0 - u
		out.append(node.position + r.position + Vector2(u * r.size.x, float(uv[1]) * r.size.y))
	return out


## Roofline anchors read from the art: the first solid pixel from the top in
## columns near each side (and the middle for extra-tall buildings).
static func auto_uvs(node: WorldRenderer.WorldSprite, tall: bool) -> Array:
	var asset := str(node.data.get("asset", ""))
	var key := asset + ("|tall" if tall else "")
	if _auto_cache.has(key):
		return _auto_cache[key]
	var img: Image = null
	var region := Rect2i()
	if not node._clip.is_empty() and node._clip.get("ok", false):
		var tex: Texture2D = node._clip["tex"]
		img = tex.get_image()
		var r0: Rect2 = (node._clip["rects"] as Array)[0]
		var bb: Array = node._clip.get("bbox", [0, 0, r0.size.x, r0.size.y])
		region = Rect2i(int(r0.position.x + float(bb[0])), int(r0.position.y + float(bb[1])), int(float(bb[2]) - float(bb[0])), int(float(bb[3]) - float(bb[1])))
	else:
		var tex := ForgeStore.load_texture(asset)
		if tex:
			img = tex.get_image()
			region = Rect2i(WorldRenderer.fit_rect(tex))
	var out: Array = []
	if img == null or region.size.x < 2 or region.size.y < 2:
		out = [[0.15, 0.12], [0.85, 0.12]]
	else:
		if img.is_compressed():
			img = img.duplicate()
			img.decompress()
		for u: float in ([0.14, 0.5, 0.86] if tall else [0.16, 0.84]):
			var x := clampi(region.position.x + int(u * region.size.x), 0, img.get_width() - 1)
			var v := 0.15
			for y in range(region.position.y, mini(region.end.y, img.get_height())):
				if img.get_pixel(x, y).a > 0.5:
					v = float(y - region.position.y) / region.size.y + 0.015
					break
			out.append([u, snappedf(v, 0.001)])
	_auto_cache[key] = out
	return out


# Lock points to the 2:1 lattice so cables read like the pixel art does.
static func _snap(p: Vector2) -> Vector2:
	return Vector2(round(p.x * 0.5) * 2.0, round(p.y))


func _draw() -> void:
	if renderer == null:
		return
	if show_anchors:
		for an: Dictionary in anchors:
			draw_circle(an["pos"], 4.0, Color(0.3, 2.0, 1.8))
			draw_arc(an["pos"], 7.0, 0, TAU, 16, Color(0.3, 2.0, 1.8, 0.6), 1.5)
	if spans.is_empty():
		return
	var w := renderer.world
	var s := settings_of(w)
	var t := WorldRenderer.now()
	var base := Color(str(s["color"]))
	var width := maxf(1.5, w.tile_width / 64.0 * 1.25)
	var sway_amp := float(s["sway"]) * w.tile_width / 64.0
	var focus := renderer.cutaway_focus
	for sp: Dictionary in spans:
		var a: Vector2 = sp["a"]
		var b: Vector2 = sp["b"]
		var phase: float = sp["phase"]
		var pts := PackedVector2Array()
		for i in SEG_PER_SPAN + 1:
			var f := float(i) / SEG_PER_SPAN
			pts.append(_snap(curve(a, b, float(sp["sag"]), sway_amp, t * SWAY_SPEED + phase, f)))
		var fade := 1.0
		if focus != Vector2.INF and ((a + b) * 0.5).distance_to(focus) < w.tile_width * 2.5:
			fade = 0.3  # x-ray: wires near the player thin out
		var col: Color = Color(sp["color"]) * Color(1, 1, 1, 0.75) if sp["live"] else base
		col.a *= fade
		for i in SEG_PER_SPAN:
			draw_line(pts[i], pts[i + 1], col, width, false)
		if sp["live"]:
			# A packet of light running along the wire.
			var head := fposmod(t * 0.35 + phase, 1.6)
			for i in SEG_PER_SPAN:
				var f := (float(i) + 0.5) / SEG_PER_SPAN
				var k := clampf(1.0 - absf(f - head) * 6.0, 0.0, 1.0)
				if k > 0.0:
					var hot: Color = Color(sp["color"]) * (1.0 + 2.5 * k)
					hot.a = k * fade
					draw_line(pts[i], pts[i + 1], hot, width + 1.0, false)
		match str(sp["junk"]):
			"lanterns":
				for f: float in [0.3, 0.5, 0.7]:
					var p := pts[int(f * SEG_PER_SPAN)]
					var drop := Vector2(sin(t * 1.3 + phase + f * 5.0) * 1.5, w.tile_width * 0.08)
					draw_line(p, p + drop, base, 1.0, false)
					draw_circle(p + drop + Vector2(0, 3), w.tile_width * 0.035, Color(2.2, 0.9, 0.4, fade))
			"flags":
				for i in range(1, SEG_PER_SPAN, 2):
					var p := pts[i]
					var c: Color = LIVE_COLORS[i % LIVE_COLORS.size()] * Color(0.9, 0.9, 0.9, fade)
					var hang := w.tile_width * 0.06 + sin(t * 2.0 + i) * 1.5
					draw_colored_polygon(PackedVector2Array([p, pts[i + 1], (p + pts[i + 1]) * 0.5 + Vector2(0, hang)]), c)
			"shoes":
				var p := pts[SEG_PER_SPAN / 2]
				var swing := sin(t * 1.1 + phase) * 2.0
				for dx: float in [-3.0, 3.0]:
					var q := p + Vector2(dx + swing, w.tile_width * 0.09)
					draw_line(p, q, base, 1.0, false)
					draw_rect(Rect2(q, Vector2(5, 3)), Color(0.12, 0.1, 0.16, fade))


## Point at `f` (0–1) along a sagging, swaying span. Sag and sway are zero at
## both anchored ends and largest mid-span.
static func curve(a: Vector2, b: Vector2, sag: float, sway: float, sway_t: float, f: float) -> Vector2:
	var p := a.lerp(b, f)
	p.y += sag * 4.0 * f * (1.0 - f)
	p.y += sin(sway_t) * sway * sin(f * PI)
	return p
