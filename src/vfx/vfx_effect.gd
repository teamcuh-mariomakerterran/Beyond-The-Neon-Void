class_name VFXEffect
extends Node2D
## Root of one spawned VFX: owns the clock, builds the parts, fires the
## shake / hit-stop cues and frees itself when every part has ended.
## Spawn through VFX.spawn(); call step(dt) to drive it by hand (VFX.paused).

signal finished
## Emitted when a projectile part arrives (or at the effect's impact_at).
signal impacted(at: Vector2)

var effect_id: String = ""
var def: Dictionary = {}
var params: Dictionary = {}
var palette: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Seconds since spawn.
var time: float = 0.0
## Local-space target point (params.to − at), or a default offset.
var target_local := Vector2(150, -30)
var has_target := false
## Local-space chain targets (params.targets − at).
var targets_local: Array[Vector2] = []
var parts: Array[VFXPart] = []
var _end_time: float = 0.1
var _cues: Array = []  # [time, kind, payload], fired once
var _done := false


func setup(p_id: String, p_def: Dictionary, at: Vector2, p_params: Dictionary) -> void:
	effect_id = p_id
	def = p_def
	params = p_params
	position = at
	if params.has("seed"):
		rng.seed = int(params["seed"])
	else:
		rng.randomize()
	var sc := float(params.get("scale", 1.0))
	scale = Vector2(sc, sc)
	z_as_relative = false
	z_index = int(params.get("z", def.get("z", VFX.DEFAULT_Z)))
	palette = (def.get("palette", {}) as Dictionary).duplicate()
	if params.has("palette") and params["palette"] is Dictionary:
		palette.merge(params["palette"], true)
	if params.has("color"):
		palette["main"] = params["color"]
	if params.get("to") is Vector2:
		target_local = (params["to"] - at) / sc
		has_target = true
	for t: Variant in params.get("targets", []):
		if t is Vector2:
			targets_local.append((t - at) / sc)
	if has_target and targets_local.is_empty():
		targets_local.append(target_local)
	elif not has_target and not targets_local.is_empty():
		target_local = targets_local[0]
		has_target = true
	var wants_shake: bool = params.get("shake", true)
	if wants_shake and def.has("shake"):
		var sh: Array = def["shake"]
		_cues.append([float(def.get("shake_delay", 0.0)), "shake", [float(sh[0]) * sc, float(sh[1])]])
	if params.get("hit_stop", true) and def.has("hit_stop"):
		_cues.append([float(def.get("hit_stop_delay", 0.0)), "hit_stop", float(def["hit_stop"])])
	var imp := VFX.impact_time(effect_id) if VFX.has_effect(effect_id) else 0.0
	_cues.append([float(def.get("impact_at", imp)), "impact", null])
	for pd: Dictionary in def.get("parts", []):
		var anc := str(pd.get("anchor", "at"))
		if anc.length() >= 2 and anc[0] == "t" and anc.substr(1).is_valid_int():
			if int(anc.substr(1)) >= maxi(targets_local.size(), 1):
				continue  # chain hop without a target
		var part := _make_part(str(pd.get("type", "sim")))
		if part == null:
			push_warning("VFX %s: unknown part type '%s'" % [effect_id, pd.get("type")])
			continue
		part.configure(self, pd)
		add_child(part)
		parts.append(part)
		_end_time = maxf(_end_time, part.end_time())
	_end_time = minf(_end_time, 12.0)


static func _make_part(type: String) -> VFXPart:
	match type:
		"sim": return VFXSim.new()
		"burst": return VFXSim.make_burst()
		"lightning": return VFXLightning.new()
		"flash", "ring", "pillar", "decal", "tear", "scan", "streaks": return VFXShape.new()
		"shockwave", "glitch": return VFXScreen.new()
		"light": return VFXLight.new()
		"trail": return VFXTrail.new()
	return null


func _ready() -> void:
	step(0.0)


func _process(delta: float) -> void:
	if not VFX.paused:
		step(delta)


## Advances the effect by `dt` seconds (also fires cues and frees at the end).
func step(dt: float) -> void:
	if _done:
		return
	time += dt
	for c: Array in _cues:
		if c[1] != "" and time >= float(c[0]):
			_fire(str(c[1]), c[2])
			c[1] = ""
	for p in parts:
		if is_instance_valid(p):
			p.advance(time - p.delay, dt)
	if time >= _end_time:
		_done = true
		finished.emit()
		queue_free()


## Simulates `seconds` in small steps (screenshots, tests, scrubbing).
func advance_to(seconds: float, fps: float = 60.0) -> void:
	var dt := 1.0 / fps
	while time + dt <= seconds and not _done:
		step(dt)


func is_done() -> bool:
	return _done


func end_time() -> float:
	return _end_time


func _fire(kind: String, payload: Variant) -> void:
	match kind:
		"shake": VFX.shake(payload[0], payload[1])
		"hit_stop": VFX.hit_stop(payload)
		"impact": impacted.emit(position + target_local * scale.x if has_target else position)


## Colour helper for parts: palette lookups + params.color.
func color(v: Variant, fallback := Color.WHITE) -> Color:
	return VFX.parse_color(v, palette, fallback)


## Local-space point for an anchor name: "at" (origin), "to", "mid".
func anchor(name: String) -> Vector2:
	match name:
		"to": return target_local
		"mid": return target_local * 0.5
		"at": return Vector2.ZERO
	if name.length() >= 2 and name[0] == "t" and name.substr(1).is_valid_int():
		var i := int(name.substr(1))
		if i < targets_local.size():
			return targets_local[i]
		return target_local
	return Vector2.ZERO
