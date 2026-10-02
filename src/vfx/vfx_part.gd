class_name VFXPart
extends Node2D
## Base of every VFX layer. Common keys: type, delay, life, pos [x,y] (offset
## from the anchor), anchor ("at" | "to" | "mid"), blend ("add" | "mix"),
## z (relative z offset), glow (colour multiplier).

var fx: VFXEffect
var d: Dictionary = {}
var delay: float = 0.0
var life: float = 1.0
## Local time since this part started (negative while delayed).
var t: float = -1.0
var rng := RandomNumberGenerator.new()
var glow: float = 1.0


func configure(effect: VFXEffect, p_def: Dictionary) -> void:
	fx = effect
	d = p_def
	delay = float(d.get("delay", 0.0))
	life = maxf(float(d.get("life", 1.0)), 0.01)
	glow = float(d.get("glow", 1.0))
	rng.seed = effect.rng.randi()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	position = fx.anchor(str(d.get("anchor", "at"))) + vec("pos", Vector2.ZERO)
	z_index = int(d.get("z", 0))
	if str(d.get("blend", default_blend())) == "add":
		material = VFX.additive()
	visible = false
	_setup()


func default_blend() -> String:
	return "add"


## Override: build state.
func _setup() -> void:
	pass


## Override: advance to local time `lt`.
func _update(_lt: float, _dt: float) -> void:
	pass


func end_time() -> float:
	return delay + life


func advance(lt: float, dt: float) -> void:
	if lt < 0.0:
		return
	t = lt
	visible = lt <= life + 0.0001
	_update(lt, dt if lt >= dt else lt)
	queue_redraw()


## 0..1 progress through life.
func k() -> float:
	return clampf(t / life, 0.0, 1.0)


# --- Key readers -------------------------------------------------------------

func num(key: String, def_v: float) -> float:
	return float(d.get(key, def_v))


func vec(key: String, def_v: Vector2) -> Vector2:
	var v: Variant = d.get(key)
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return def_v


## [min, max] range (or a single number) → random value.
func rnd(key: String, def_min: float, def_max: float = NAN) -> float:
	var v: Variant = d.get(key)
	if v is Array and (v as Array).size() >= 2:
		return rng.randf_range(float(v[0]), float(v[1]))
	if v is float or v is int:
		return float(v)
	return def_min if is_nan(def_max) else rng.randf_range(def_min, def_max)


func col(key: String, def_v: Variant = "#ffffff") -> Color:
	var c := fx.color(d.get(key, def_v))
	return Color(c.r * glow, c.g * glow, c.b * glow, c.a)


## A list of colours (gradient stops) from `key`; single values become [c].
func cols(key: String, def_v: Array = ["#ffffff"]) -> PackedColorArray:
	var v: Variant = d.get(key, def_v)
	var out := PackedColorArray()
	if v is Array and not (v as Array).is_empty() and not (v[0] is float or v[0] is int):
		for c: Variant in v:
			var cc := fx.color(c)
			out.append(Color(cc.r * glow, cc.g * glow, cc.b * glow, cc.a))
	else:
		var cc := fx.color(v)
		out.append(Color(cc.r * glow, cc.g * glow, cc.b * glow, cc.a))
	return out


static func sample(stops: PackedColorArray, x: float) -> Color:
	if stops.size() == 1:
		return stops[0]
	var f := clampf(x, 0.0, 1.0) * (stops.size() - 1)
	var i := mini(int(f), stops.size() - 2)
	return stops[i].lerp(stops[i + 1], f - i)


## Attack/decay envelope: 0→1 over `attack`, then eases to 0 at life.
func envelope(attack: float = 0.05, power: float = 1.6) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	return pow(clampf(1.0 - (t - attack) / maxf(life - attack, 0.0001), 0.0, 1.0), power)
