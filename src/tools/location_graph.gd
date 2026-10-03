class_name LocationGraph
extends Control
## World Painter "LINKS" view: every map as a node, columns by kind
## (world → city/hub → interior → encounter/event), arrows for location
## doors and region teleports. Broken links point at a red ghost node.
## Click a node to open that map.

signal map_chosen(id: String)

const TIER := {"world": 0, "city": 1, "hub": 1, "interior": 2, "event": 3, "encounter": 3}
const KIND_COLORS := {"world": Color(0.3, 1.0, 0.85), "city": Color(1.0, 0.75, 0.3), "hub": Color(1.0, 0.45, 0.85),
	"interior": Color(0.6, 0.55, 1.0), "encounter": Color(1.0, 0.35, 0.35), "event": Color(0.9, 0.9, 0.5)}
const NODE_SIZE := Vector2(170, 46)
const GAP := Vector2(90, 18)

var current := ""
var nodes: Dictionary = {}  # id -> {kind, name, rect: Rect2, missing: bool}
var edges: Array = []  # {from, to, label, how: "door"|"teleport", broken}
var _hover := ""


## Links out of one map dict: location doors and teleport triggers.
static func links_of(id: String, d: Dictionary) -> Array:
	var out: Array = []
	for o: Variant in d.get("objects", []):
		if o is Dictionary and (o as Dictionary).get("location") is Dictionary:
			var loc: Dictionary = o["location"]
			var t := str(loc.get("target_map", ""))
			if t != "":
				out.append({"from": id, "to": t, "label": str(loc.get("name", "")), "how": "door"})
	for r: Variant in d.get("regions", []):
		if not (r is Dictionary):
			continue
		for t: Variant in (r as Dictionary).get("triggers", []):
			if t is Dictionary and str(t.get("do", "")) == "teleport":
				var target := str(t.get("arg", "")).split(":")[0]
				if target != "":
					out.append({"from": id, "to": target, "label": str(r.get("name", "")), "how": "teleport"})
	return out


## `maps`: id -> map dict (ContentDB.maps). `live` replaces the saved copy of
## the map being edited, so unsaved links show up too.
func build(maps: Dictionary, live: Dictionary = {}) -> void:
	nodes.clear()
	edges.clear()
	var all := maps.duplicate()
	if not live.is_empty():
		all[str(live.get("id", ""))] = live
	for id: String in all:
		var d: Dictionary = all[id]
		if int(d.get("format", 1)) < 2 and str(d.get("kind", "")) == "":
			d = {"kind": "encounter"}
		nodes[id] = {"kind": str(d.get("kind", "encounter")), "name": str(d.get("name", id)), "missing": false}
		edges.append_array(links_of(id, d))
	for e: Dictionary in edges:
		e["broken"] = not nodes.has(e["to"])
		if e["broken"] and not nodes.has(e["to"]):
			nodes[e["to"]] = {"kind": "encounter", "name": "missing", "missing": true}
	_layout()
	queue_redraw()


func _layout() -> void:
	var cols: Array = [[], [], [], []]
	var ids := nodes.keys()
	ids.sort()
	for id: String in ids:
		cols[int(TIER.get(nodes[id]["kind"], 3))].append(id)
	var h := 0.0
	for x in cols.size():
		for y in (cols[x] as Array).size():
			var pos := Vector2(24 + x * (NODE_SIZE.x + GAP.x), 40 + y * (NODE_SIZE.y + GAP.y))
			nodes[cols[x][y]]["rect"] = Rect2(pos, NODE_SIZE)
			h = maxf(h, pos.y + NODE_SIZE.y + 24)
	custom_minimum_size = Vector2(24 + 4 * (NODE_SIZE.x + GAP.x), h)


func incoming(id: String) -> int:
	var n := 0
	for e: Dictionary in edges:
		if e["to"] == id:
			n += 1
	return n


func node_at(p: Vector2) -> String:
	for id: String in nodes:
		if (nodes[id]["rect"] as Rect2).has_point(p):
			return id
	return ""


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := node_at(ev.position)
		if h != _hover:
			_hover = h
			tooltip_text = "" if h == "" else "%s · %s · %d link(s) in" % [h, nodes[h]["kind"], incoming(h)]
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var id := node_at(ev.position)
		if id != "" and not nodes[id]["missing"]:
			map_chosen.emit(id)


func _draw() -> void:
	var font := get_theme_default_font()
	for x in 4:
		draw_string(font, Vector2(24 + x * (NODE_SIZE.x + GAP.x), 26), ["WORLD", "CITY / HUB", "INTERIOR", "ENCOUNTER / EVENT"][x], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.65, 0.9))
	for e: Dictionary in edges:
		var a: Rect2 = nodes[e["from"]]["rect"]
		var b: Rect2 = nodes[e["to"]]["rect"]
		var p0 := Vector2(a.end.x, a.get_center().y) if b.position.x > a.position.x else Vector2(a.position.x, a.get_center().y)
		var p1 := Vector2(b.position.x, b.get_center().y) if b.position.x > a.position.x else Vector2(b.end.x, b.get_center().y)
		if is_equal_approx(a.position.x, b.position.x):
			p0 = Vector2(a.end.x, a.get_center().y)
			p1 = Vector2(b.end.x, b.get_center().y)
		var col := Color(1, 0.3, 0.3) if e["broken"] else (Color(0.4, 1, 0.9, 0.8) if e["how"] == "door" else Color(1, 0.8, 0.3, 0.8))
		if _hover != "" and e["from"] != _hover and e["to"] != _hover:
			col.a *= 0.25
		var bend := maxf(absf(p1.x - p0.x) * 0.5, 50.0) * (1.0 if p1.x >= p0.x and not is_equal_approx(a.position.x, b.position.x) else -1.0)
		if is_equal_approx(a.position.x, b.position.x):
			bend = 60.0
		var pts := PackedVector2Array()
		for i in 21:
			var t := i / 20.0
			var c1 := p0 + Vector2(bend, 0)
			var c2 := p1 + Vector2(-bend if not is_equal_approx(a.position.x, b.position.x) else bend, 0)
			pts.append(p0.bezier_interpolate(c1, c2, p1, t))
		draw_polyline(pts, col, 2.0 if e["how"] == "door" else 1.5, true)
		var dir := (pts[20] - pts[18]).normalized()
		draw_colored_polygon(PackedVector2Array([p1, p1 - dir * 9 + dir.orthogonal() * 5, p1 - dir * 9 - dir.orthogonal() * 5]), col)
		if str(e["label"]) != "" and (_hover == "" or e["from"] == _hover or e["to"] == _hover):
			draw_string(font, pts[10] + Vector2(-30, -4), str(e["label"]).left(18), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	for id: String in nodes:
		var n: Dictionary = nodes[id]
		var r: Rect2 = n["rect"]
		var kc: Color = Color(1, 0.3, 0.3) if n["missing"] else KIND_COLORS.get(n["kind"], Color.WHITE)
		var lonely: bool = not n["missing"] and incoming(id) == 0 and not _has_out(id) and n["kind"] != "encounter"
		draw_rect(r, Color(0.08, 0.05, 0.14, 0.95))
		draw_rect(r, Color(kc, 0.35 if lonely else 1.0), false, 3.0 if id == current or id == _hover else 1.5)
		if id == current:
			draw_rect(r.grow(4), Color(kc, 0.4), false, 1.0)
		draw_string(font, r.position + Vector2(10, 19), id.left(22), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5 if lonely else 1.0))
		var sub := "MISSING MAP" if n["missing"] else ("%s%s" % [n["kind"], "  · not linked" if lonely else ""])
		draw_string(font, r.position + Vector2(10, 37), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(kc, 0.8))


func _has_out(id: String) -> bool:
	for e: Dictionary in edges:
		if e["from"] == id:
			return true
	return false
