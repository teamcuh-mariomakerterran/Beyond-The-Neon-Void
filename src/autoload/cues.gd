extends Node
## Cues — gameplay says WHAT happened ("hit.crit", "kill.boss", "victory"),
## data/cues.json says how it FEELS. Gameplay never touches the camera,
## time scale or overlays itself.
##
##   Cues.fire("hit.crit", {"unit": target, "amount": 120})
##
## The most specific defined name runs: "hit.crit.fire" → "hit.crit" → "hit".
## Time scale and zoom punch go through a small override stack, so a hit-stop
## landing during a kill slow-mo never restores the wrong speed: the effective
## value is always the strongest live entry, and the base comes back when the
## last one ends. All timing is real time (unaffected by slow-mo).
## New step types: Cues.register("name", func(step, ctx): ...).

const DATA := "res://data/cues.json"
const HEARTBEAT := preload("res://src/vfx/heartbeat.gdshader")
const LOW_HP := 0.25

signal fired(cue_id: String, resolved: String, ctx: Dictionary)

var cues: Dictionary = {}
var handlers: Dictionary = {}
var history: Array[String] = []  # last fired cues, newest last (dev console)
var _stack := {"time_scale": [], "zoom": []}  # [{value, start, end, shape}]
var _base_time_scale := 1.0
var _owns_time := false
var _layer: CanvasLayer
var _flash: ColorRect
var _vignette: ColorRect
var _bars: Array[ColorRect] = []
var _low_hp := 0.0
var _low_hp_goal := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload()
	_build_overlay()
	for pair: Array in [["shake", _do_shake], ["hitstop", _do_hitstop], ["slowmo", _do_slowmo], ["zoom", _do_zoom],
			["flash", _do_flash], ["vfx", _do_vfx], ["sfx", _do_sfx], ["headline", _do_headline],
			["letterbox", _do_letterbox], ["title", _do_title], ["log", _do_log]]:
		handlers[pair[0]] = pair[1]
	EventBus.unit_damaged.connect(_on_damaged)
	EventBus.unit_healed.connect(func(u: Node, _a: int) -> void:
		fire("heal", {"unit": u})
		_check_low_hp())
	EventBus.unit_died.connect(_on_died)
	EventBus.unit_status_applied.connect(func(u: Node, sid: String) -> void: fire("status." + sid, {"unit": u, "status": sid}))
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_ended.connect(func(won: bool, _id: String) -> void:
		_low_hp_goal = 0.0
		fire("victory" if won else "defeat", {}))


func reload() -> void:
	cues.clear()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	if d is Dictionary:
		for k: String in d:
			if not k.begins_with("_") and d[k] is Array:
				cues[k] = d[k]


func register(step: String, fn: Callable) -> void:
	handlers[step] = fn


## The cue name that would run for `cue_id`, or "" if none is defined.
func resolve(cue_id: String) -> String:
	var parts := cue_id.split(".")
	while not parts.is_empty():
		var k := ".".join(parts)
		if cues.has(k):
			return k
		parts.resize(parts.size() - 1)
	return ""


func fire(cue_id: String, ctx: Dictionary = {}) -> void:
	history.append(cue_id)
	if history.size() > 40:
		history.pop_front()
	var key := resolve(cue_id)
	fired.emit(cue_id, key, ctx)
	if key == "":
		return
	for step: Variant in cues[key]:
		if not (step is Dictionary):
			continue
		var delay := float(step.get("delay", 0.0))
		if delay > 0.0:
			get_tree().create_timer(delay, true, false, true).timeout.connect(_run.bind(step, ctx))
		else:
			_run(step, ctx)


## Steps that only make sense on screen. Battles resolved without animation
## (auto-resolve, tests) skip them so game speed and camera are never touched.
const PRESENTATION := ["shake", "hitstop", "slowmo", "zoom", "flash", "letterbox", "title", "vfx", "sfx"]


func _run(step: Dictionary, ctx: Dictionary) -> void:
	if not CombatManager.animate and str(step.get("do", "")) in PRESENTATION:
		return
	var fn: Callable = handlers.get(str(step.get("do", "")), Callable())
	if fn.is_valid():
		fn.call(step, ctx)


static func fill(text: String, ctx: Dictionary) -> String:
	var u: Variant = ctx.get("unit")
	var name := ""
	var title := ""
	if is_instance_valid(u) and u is Node and u.get("data") != null:
		name = str(u.data.display_name)
		title = str(u.data.get("boss_title")) if u.data.get("boss_title") else ""
	return text.format({"name": name.to_upper(), "title": title, "amount": str(ctx.get("amount", "")), "status": str(ctx.get("status", ""))})


# --- Combat listeners -----------------------------------------------------------

func _on_damaged(u: Node, amount: int, crit: bool) -> void:
	var max_hp := maxf(float(u.get_stat("max_hp")) if u.has_method("get_stat") else 100.0, 1.0)
	var weight := ".crit" if crit else (".heavy" if amount / max_hp >= 0.3 else "")
	var player := int(u.get("team")) == Unit.Team.PLAYER
	fire(("hurt" if player else "hit") + weight, {"unit": u, "amount": amount})
	_check_low_hp()


func _on_died(u: Node) -> void:
	var boss: bool = u.get("data") != null and bool(u.data.get("is_boss"))
	if int(u.get("team")) == Unit.Team.PLAYER:
		fire("ally_down", {"unit": u})
	else:
		fire("kill.boss" if boss else "kill", {"unit": u})
	_check_low_hp()


func _on_battle_started(_id: String) -> void:
	for u: Node in CombatManager.units:
		if u.get("data") != null and bool(u.data.get("is_boss")) and int(u.get("team")) != Unit.Team.PLAYER:
			fire("boss.intro", {"unit": u})
			break
	_check_low_hp()


## Heartbeat vignette while any of the player's crew is under 25% HP.
func _check_low_hp() -> void:
	var low := false
	for u: Node in CombatManager.units:
		if is_instance_valid(u) and int(u.get("team")) == Unit.Team.PLAYER and u.is_alive():
			if float(u.current_hp) / maxf(float(u.get_stat("max_hp")), 1.0) < LOW_HP:
				low = true
	_low_hp_goal = 1.0 if low else 0.0


# --- Override stack --------------------------------------------------------------

## Pushes an override on `channel` ("time_scale" or "zoom") for `dur` seconds.
## shape: "hold" (flat), "punch" (snap in, ease out), "ease" (hold, ease back).
func push(channel: String, value: float, dur: float, shape: String = "hold") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if channel == "time_scale" and not _owns_time:
		_base_time_scale = Engine.time_scale
		_owns_time = true
	(_stack[channel] as Array).append({"value": value, "start": now, "end": now + dur, "shape": shape})


func effective(channel: String, base: float) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var best := base
	for e: Dictionary in _stack[channel]:
		var p := clampf((now - float(e["start"])) / maxf(float(e["end"]) - float(e["start"]), 0.001), 0.0, 1.0)
		var k := 1.0
		match str(e["shape"]):
			"punch": k = p / 0.15 if p < 0.15 else 1.0 - smoothstep(0.15, 1.0, p)
			"ease": k = 1.0 if p < 0.6 else 1.0 - smoothstep(0.6, 1.0, p)
		var v := lerpf(base, float(e["value"]), k)
		# time scale: the slowest wins. zoom: the biggest punch wins.
		if (channel == "time_scale" and v < best) or (channel == "zoom" and v > best):
			best = v
	return best


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for ch: String in _stack:
		_stack[ch] = (_stack[ch] as Array).filter(func(e: Dictionary) -> bool: return float(e["end"]) > now)
	if _owns_time:
		Engine.time_scale = effective("time_scale", _base_time_scale)
		if (_stack["time_scale"] as Array).is_empty():
			Engine.time_scale = _base_time_scale
			_owns_time = false
	var cam := get_viewport().get_camera_2d() if get_viewport() else null
	if cam and "punch" in cam:
		cam.set("punch", effective("zoom", 1.0))
	var real := delta / maxf(Engine.time_scale, 0.001)
	_low_hp = move_toward(_low_hp, _low_hp_goal, real * 1.5)
	if _vignette:
		_vignette.visible = _low_hp > 0.001
		(_vignette.material as ShaderMaterial).set_shader_parameter("intensity", _low_hp)


# --- Step handlers -------------------------------------------------------------

func _motion_ok() -> bool:
	return not SettingsFlags.reduce_motion


func _do_shake(step: Dictionary, _ctx: Dictionary) -> void:
	EventBus.camera_shake.emit(float(step.get("amp", 4.0)), float(step.get("dur", 0.15)))


func _do_hitstop(step: Dictionary, _ctx: Dictionary) -> void:
	push("time_scale", 0.05, float(step.get("ms", 70)) / 1000.0)


func _do_slowmo(step: Dictionary, _ctx: Dictionary) -> void:
	if _motion_ok():
		push("time_scale", float(step.get("scale", 0.5)), float(step.get("dur", 0.4)), "ease")


func _do_zoom(step: Dictionary, _ctx: Dictionary) -> void:
	if _motion_ok():
		push("zoom", float(step.get("amt", 1.05)), float(step.get("dur", 0.25)), "punch")


func _do_flash(step: Dictionary, _ctx: Dictionary) -> void:
	if _flash == null:
		return
	var c := Color(str(step.get("color", "#ffffff")))
	c.a = float(step.get("alpha", 0.2)) * (0.5 if SettingsFlags.reduce_motion else 1.0)
	_flash.color = c
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_flash, "color:a", 0.0, float(step.get("dur", 0.2)))


func _do_vfx(step: Dictionary, ctx: Dictionary) -> void:
	var u: Variant = ctx.get("unit")
	if is_instance_valid(u) and u is Node2D and (u as Node2D).get_parent():
		VFX.spawn((u as Node2D).get_parent(), str(step.get("id", "")), (u as Node2D).position)


func _do_sfx(step: Dictionary, _ctx: Dictionary) -> void:
	EventBus.play_sfx.emit(str(step.get("id", "")))


func _do_headline(step: Dictionary, ctx: Dictionary) -> void:
	EventBus.broadcast_line.emit("news", fill(str(step.get("text", "")), ctx))


func _do_log(step: Dictionary, ctx: Dictionary) -> void:
	EventBus.log_message.emit(fill(str(step.get("text", "")), ctx))


func _do_letterbox(step: Dictionary, _ctx: Dictionary) -> void:
	var dur := float(step.get("dur", 2.0))
	for i in _bars.size():
		var bar := _bars[i]
		bar.visible = true
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(bar, "custom_minimum_size:y", 90.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_interval(maxf(dur - 0.7, 0.0))
		tw.tween_property(bar, "custom_minimum_size:y", 0.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: bar.visible = false)


## Boss name card: the name slams in, the epithet types under it.
func _do_title(step: Dictionary, ctx: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := Label.new()
	big.text = fill(str(step.get("text", "")), ctx)
	big.add_theme_font_size_override("font_size", 64)
	big.add_theme_color_override("font_color", Color(1.0, 0.25, 0.45))
	big.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.08))
	big.add_theme_constant_override("outline_size", 10)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Label.new()
	sub.text = fill(str(step.get("sub", "")), ctx)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.visible_ratio = 0.0
	box.add_child(big)
	box.add_child(sub)
	_layer.add_child(box)
	box.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(400, 60)
	box.custom_minimum_size = Vector2(800, 120)
	box.pivot_offset = Vector2(400, 60)
	box.scale = Vector2(1.8, 1.8)
	box.modulate.a = 0.0
	var dur := float(step.get("dur", 2.0))
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.12)
	tw.tween_property(sub, "visible_ratio", 1.0, 0.5)
	tw.tween_interval(maxf(dur - 1.0, 0.1))
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)


# --- Overlay ----------------------------------------------------------------------

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 9  # above the world and HD-2D post (5), below HUDs (10+)
	add_child(_layer)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = HEARTBEAT
	_vignette.material = m
	_vignette.visible = false
	_layer.add_child(_vignette)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_layer.add_child(_flash)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN
		bar.visible = false
		_layer.add_child(bar)
		_bars.append(bar)
