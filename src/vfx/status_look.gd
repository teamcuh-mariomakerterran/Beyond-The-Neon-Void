class_name StatusLook
extends RefCounted
## Shows a unit's statuses on its body: one shader (status_look.gdshader)
## driven by data/status_looks.json. Stacked statuses blend: numbers take the
## strongest value, the tint comes from the highest priority. Changes ease in
## (petrify creeps over the body; banish drags the unit down through the floor).

const SHADER := preload("res://src/vfx/status_look.gdshader")
const DATA := "res://data/status_looks.json"
const NUMS := ["grey", "crack", "tint_amt", "pulse_speed", "pulse_amt", "flicker", "heat", "glitch", "dissolve", "frost", "scan", "shimmer", "darken", "sink"]
const SINK_PX := 72.0  # banish depth at sink = 1, in unit-local pixels

static var _looks: Dictionary = {}


static func looks() -> Dictionary:
	if _looks.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
		if d is Dictionary:
			for k: String in d:
				if not k.begins_with("_") and d[k] is Dictionary:
					_looks[k] = d[k]
	return _looks


## The blended look for a set of status ids.
static func combine(ids: Array) -> Dictionary:
	var out := {"tint": Color.WHITE, "freeze": false, "priority": -1}
	for k: String in NUMS:
		out[k] = 0.0
	var all := looks()
	for id: Variant in ids:
		var l: Dictionary = all.get(str(id), {})
		if l.is_empty():
			continue
		for k: String in NUMS:
			if l.has(k):
				out[k] = maxf(float(out[k]), float(l[k]))
		var pr := int(l.get("priority", 10))
		if l.has("tint") and pr > int(out["priority"]):
			out["tint"] = Color(str(l["tint"]))
			out["priority"] = pr
		if bool(l.get("freeze", false)):
			out["freeze"] = true
	return out


static func status_ids(unit: Node) -> Array:
	var ids: Array = []
	for inst: Variant in unit.get("statuses"):
		ids.append(str(inst.effect.id))
	ids.sort()
	return ids


## Re-applies the look if the unit's statuses changed. Cheap to call often.
static func update(unit: CanvasItem, animate: bool = true) -> void:
	var ids := status_ids(unit)
	var key := ",".join(ids)
	if unit.get_meta("status_look_key", "") == key and unit.material != null:
		return
	unit.set_meta("status_look_key", key)
	var goal := combine(ids)
	var mat := unit.material as ShaderMaterial
	if mat == null or mat.shader != SHADER:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		unit.material = mat
	var spr: Variant = unit.get("sprite")
	if spr is AnimatedSprite2D:
		(spr as AnimatedSprite2D).use_parent_material = true
		(spr as AnimatedSprite2D).speed_scale = 0.0 if goal["freeze"] else 1.0
	mat.set_shader_parameter("tint", goal["tint"])
	var from: Dictionary = unit.get_meta("status_look_now", {})
	if not animate or not unit.is_inside_tree():
		_apply(mat, goal, goal, 1.0)
		unit.set_meta("status_look_now", goal)
		return
	var dur := 0.7 if float(goal["sink"]) != float(from.get("sink", 0.0)) else 0.4
	var tw := unit.create_tween()
	tw.tween_method(func(f: float) -> void: _apply(mat, from, goal, f), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)
	unit.set_meta("status_look_now", goal)


static func _apply(mat: ShaderMaterial, a: Dictionary, b: Dictionary, f: float) -> void:
	for k: String in NUMS:
		var v := lerpf(float(a.get(k, 0.0)), float(b[k]), f)
		if k == "sink":
			mat.set_shader_parameter("sink_px", v * SINK_PX)
		else:
			mat.set_shader_parameter(k, v)
	# Glitch/dissolve-heavy looks also thin the unit a touch when banished.
	mat.set_shader_parameter("alpha_mul", lerpf(1.0, 0.85, clampf(float(b["sink"]) * f, 0.0, 1.0)))
