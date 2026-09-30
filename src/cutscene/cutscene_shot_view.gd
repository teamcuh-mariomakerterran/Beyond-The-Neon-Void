class_name CutsceneShotView
extends Node2D
## Renders one shot's layer stack at a given content time (port of renderShot):
## background fill, camera pan / follow, then layers back → front. Lives inside
## a SubViewport sized to the cutscene stage (e.g. 320×180).

var doc: CutsceneDoc
var shot: Dictionary = {}
var shot_index: int = -1
var cam: Vector2 = Vector2.ZERO
var placements: Dictionary = {}
var _items: Array[CutsceneLayerItem] = []
var _by_id: Dictionary = {}


func show_shot(p_doc: CutsceneDoc, index: int) -> void:
	if p_doc == doc and index == shot_index:
		return
	doc = p_doc
	shot_index = index
	shot = doc.shots[index]
	for c in get_children():
		c.queue_free()
	_items.clear()
	_by_id.clear()
	var layers: Array = shot["layers"]
	for L: Dictionary in layers:
		_by_id[str(L["id"])] = L
	# Array is front-first; add children back → front so later draws on top.
	for i in range(layers.size() - 1, -1, -1):
		var L: Dictionary = layers[i]
		var mask_id := str(L.get("maskLayer", ""))
		if mask_id != "" and _by_id.has(mask_id) and mask_id != str(L["id"]) and not bool(L.get("maskInvert", false)):
			# Mask: the mask layer's alpha clips the masked layer (clip_children).
			var host := _make(_by_id[mask_id], true)
			host.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			add_child(host)
			var child := _make(L, true)
			child.set_meta("mask_opacity_from", L)
			host.add_child(child)
			_items.append(host)
			_items.append(child)
		else:
			var item := _make(L, false)
			add_child(item)
			_items.append(item)


func _make(L: Dictionary, forced: bool) -> CutsceneLayerItem:
	var item: CutsceneLayerItem = CutsceneDistortItem.new() if str(L["kind"]) == "distort" else CutsceneLayerItem.new()
	item.setup(self, L, forced)
	return item


func render_at(t: float, freeze: float) -> void:
	placements.clear()
	var C: Dictionary = shot["cam"]
	var dur := float(shot["dur"])
	var p := clampf(t / dur, 0.0, 1.0) if dur > 0.0 else 0.0
	var e := CutsceneDoc.ease_fn(p, str(C.get("ease", "out")))
	cam = Vector2(-CutsceneDoc.pvf(C, "panX", t) * e, -CutsceneDoc.pvf(C, "panY", t) * e)
	var follow := str(C.get("follow", "")) if C.get("follow") != null else ""
	if follow != "":
		for item in _items:
			if str(item.L["id"]) == follow and not item.forced:
				item._t = t
				var c: Variant = item.centre()
				if c is Vector2:
					var amt := CutsceneDoc.pvf(C, "followAmt", t, 1.0)
					cam.x += (doc.w * float(C.get("followX", 0.5)) - c.x) * amt
					cam.y += (doc.h * float(C.get("followY", 0.6)) - c.y) * amt
				break
	for item in _items:
		item.update_frame(t, freeze)
		if item.has_meta("mask_opacity_from"):
			var L: Dictionary = item.get_meta("mask_opacity_from")
			item.modulate.a = clampf(CutsceneDoc.pvf(L, "opacity", item._t, 1.0) * group_alpha(L, item._t), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if doc:
		draw_rect(Rect2(0, 0, doc.w, doc.h), Color(str(shot.get("bg", "#05060e"))))


# --- Groups (port of groupChain / groupScale / groupAlpha / groupOffset) ----

func _group_chain(L: Dictionary) -> Array:
	var out := []
	var gname := str(L.get("group", "")) if L.get("group") != null else ""
	if gname == "":
		return out
	var groups: Array = shot["groups"]
	var seen := {}
	var g: Variant = _find_group(groups, gname)
	var guard := 0
	while g != null and guard < 16:
		guard += 1
		if seen.has(g["name"]):
			break
		seen[g["name"]] = true
		out.append(g)
		g = _find_group(groups, str(g["parent"])) if g.get("parent") != null and str(g["parent"]) != "" else null
	return out


static func _find_group(groups: Array, gname: String) -> Variant:
	for g: Dictionary in groups:
		if str(g.get("name", "")) == gname:
			return g
	return null


func group_scale(L: Dictionary, t: float) -> float:
	var s := 1.0
	for g: Dictionary in _group_chain(L):
		var v := CutsceneDoc.pvf(g, "scale", t, 1.0)
		s *= v if v != 0.0 else 1.0
	return s


func group_alpha(L: Dictionary, t: float) -> float:
	var a := 1.0
	for g: Dictionary in _group_chain(L):
		if g.get("visible", true) == false:
			return 0.0
		a *= CutsceneDoc.pvf(g, "opacity", t, 1.0)
	return a


func group_offset(L: Dictionary, t: float) -> Vector2:
	var chain := _group_chain(L)
	var off := Vector2.ZERO
	for i in chain.size():
		var m := 1.0
		for j in range(i + 1, chain.size()):
			var sv := CutsceneDoc.pvf(chain[j], "scale", t, 1.0)
			m *= sv if sv != 0.0 else 1.0
		off += Vector2(CutsceneDoc.pvf(chain[i], "x", t), CutsceneDoc.pvf(chain[i], "y", t)) * m
	return off
