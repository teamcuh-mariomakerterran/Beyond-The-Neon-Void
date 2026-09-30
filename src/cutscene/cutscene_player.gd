class_name CutscenePlayer
extends CanvasLayer
## Plays a PARALLAX cutscene over the game.
##
##     var cs := CutscenePlayer.play(self, "res://data/cutscenes/intro.parallax.json",
##             {"SPEAKER": "ROOK", "PLACE": "SUPPLY WORKS"}, {"ATTACKER": "Rook"})
##     await cs.finished
##
## Pipeline per frame (mirrors cutscene-builder.html renderFrame):
##   shot layers → [stage SubViewport] → post/grade shader (zoom, shake, grade,
##   wash, vignette, scanlines, grain, flash, letterbox) → transition shader
##   (with the previous shot's last frame) → scaled to the screen, pixel-crisp.
## Shot `events` are emitted as `event_fired` (and on EventBus.cutscene_event) so
## the game can react — e.g. shake the battle camera on "impact".

signal finished(skipped: bool)
signal event_fired(event_name: String, data: Variant)

const TRANSITIONS := ["cut", "fade", "crossfade", "flash", "wipeL", "wipeR", "wipeU", "wipeD", "slideL", "slideR", "slideU", "iris", "dissolve"]

const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D src : filter_nearest;
uniform vec2 size = vec2(320.0, 180.0);
uniform vec4 bg : source_color = vec4(0.02, 0.02, 0.05, 1.0);
uniform float zoom = 1.0;
uniform vec2 shake = vec2(0.0);
uniform float bright = 1.0;
uniform float contrast = 1.0;
uniform float sat = 1.0;
uniform float hue = 0.0;
uniform vec3 wash = vec3(0.24, 0.88, 0.85);
uniform float wash_amt = 0.0;
uniform float vignette = 0.0;
uniform float scan = 0.0;
uniform float grain = 0.0;
uniform float t = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_a = 0.0;
uniform float bars = 0.0;
vec3 hue_rotate(vec3 c, float deg) {
	float a = radians(deg); float cs = cos(a); float sn = sin(a);
	mat3 m = mat3(
		vec3(0.213 + cs*0.787 - sn*0.213, 0.213 - cs*0.213 + sn*0.143, 0.213 - cs*0.213 - sn*0.787),
		vec3(0.715 - cs*0.715 - sn*0.715, 0.715 + cs*0.285 + sn*0.140, 0.715 - cs*0.715 + sn*0.715),
		vec3(0.072 - cs*0.072 + sn*0.928, 0.072 - cs*0.072 - sn*0.283, 0.072 + cs*0.928 + sn*0.072));
	return m * c;
}
vec3 overlay(vec3 b, vec3 s) {
	return mix(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b));
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 px = floor(UV * size) + 0.5;
	vec2 dsz = size * zoom;
	vec2 d = floor((size - dsz) * 0.5 + shake + 0.5);
	vec2 suv = (px - d) / dsz;
	vec3 col;
	if (suv.x < 0.0 || suv.y < 0.0 || suv.x > 1.0 || suv.y > 1.0) {
		col = bg.rgb;
	} else {
		col = texture(src, suv).rgb;
		col *= bright;
		col = (col - 0.5) * contrast + 0.5;
		float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
		col = mix(vec3(l), col, sat);
		if (hue != 0.0) { col = hue_rotate(col, hue); }
		col = clamp(col, 0.0, 1.0);
	}
	if (wash_amt > 0.0) { col = mix(col, overlay(col, wash), wash_amt); }
	if (vignette > 0.0) {
		vec2 c = size * 0.5;
		float r0 = min(size.x, size.y) * 0.25;
		float r1 = max(size.x, size.y) * 0.72;
		float a = vignette * clamp((length(px - c) - r0) / (r1 - r0), 0.0, 1.0);
		col = mix(col, vec3(0.0), a);
	}
	if (scan > 0.0 && mod(floor(px.y), 2.0) < 0.5) { col = mix(col, vec3(0.0), scan); }
	if (grain > 0.0) {
		float g = hash(floor(px) + vec2(mod(floor(t * 14.0), 5.0) * 17.0, 3.0));
		col = mix(col, overlay(col, vec3(g)), grain);
	}
	if (flash_a > 0.0) { col = mix(col, flash_color.rgb, flash_a); }
	if (bars > 0.0) {
		float bh = floor(size.y * bars * 0.5 + 0.5);
		if (px.y < bh || px.y > size.y - bh) { col = vec3(0.0); }
	}
	COLOR = vec4(col, 1.0);
}
"""

const TRANSITION_SHADER := """
shader_type canvas_item;
uniform sampler2D cur : filter_nearest;
uniform sampler2D prev : filter_nearest;
uniform vec2 size = vec2(320.0, 180.0);
uniform int kind = 0;
uniform float p = 1.0;
uniform bool has_prev = false;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
float hash(vec2 q) { return fract(sin(dot(q, vec2(12.9898, 78.233))) * 43758.5453); }
vec3 at(sampler2D tex, vec2 px) { return texture(tex, px / size).rgb; }
void fragment() {
	vec2 px = floor(UV * size) + 0.5;
	vec3 c = at(cur, px);
	vec3 o = has_prev ? at(prev, px) : c;
	vec3 outc = c;
	if (kind == 1 || kind == 3) {            // fade / flash
		vec3 base = (p < 0.5 && has_prev) ? o : c;
		float a = p < 0.5 ? p * 2.0 : (1.0 - p) * 2.0;
		outc = mix(base, color.rgb, a);
	} else if (kind == 2) {                  // crossfade
		outc = has_prev ? mix(o, c, p) : c;
	} else if (kind >= 4 && kind <= 7) {     // wipes
		bool inside = kind == 4 ? px.x < size.x * p : kind == 5 ? px.x > size.x - size.x * p
			: kind == 6 ? px.y < size.y * p : px.y > size.y - size.y * p;
		outc = inside ? c : o;
	} else if (kind >= 8 && kind <= 10) {    // slides
		vec2 off_prev = kind == 8 ? vec2(-size.x * p, 0.0) : kind == 9 ? vec2(size.x * p, 0.0) : vec2(0.0, -size.y * p);
		vec2 off_cur = kind == 8 ? vec2(size.x - size.x * p, 0.0) : kind == 9 ? vec2(-size.x + size.x * p, 0.0) : vec2(0.0, size.y - size.y * p);
		vec2 cp = px - off_cur;
		vec2 pp = px - off_prev;
		if (cp.x >= 0.0 && cp.y >= 0.0 && cp.x < size.x && cp.y < size.y) { outc = at(cur, cp); }
		else if (has_prev && pp.x >= 0.0 && pp.y >= 0.0 && pp.x < size.x && pp.y < size.y) { outc = at(prev, pp); }
		else { outc = color.rgb; }
	} else if (kind == 11) {                 // iris
		float r = length(size) * 0.55 * p;
		outc = length(px - size * 0.5) < r ? c : (has_prev ? o : color.rgb);
	} else if (kind == 12) {                 // dissolve (4px cells)
		float h = hash(floor(px / 4.0));
		outc = h < p ? c : (has_prev ? o : color.rgb);
	}
	COLOR = vec4(outc, 1.0);
}
"""

var doc: CutsceneDoc
var time: float = 0.0
var skippable: bool = true
var playing: bool = false
var _order: Array[int] = []
var _cur_stage: Dictionary
var _prev_stage: Dictionary
var _final_vp: SubViewport
var _final_mat: ShaderMaterial
var _display: TextureRect
var _audio_cursor := {"shot": -1, "t": -1.0}
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var _skip_hint: Label


## Convenience: create, add to the tree and start. Source = path or CutsceneDoc.
static func play(parent: Node, source: Variant, p_vars: Dictionary = {}, slot_bindings: Dictionary = {}) -> CutscenePlayer:
	var d: CutsceneDoc = source if source is CutsceneDoc else CutsceneDoc.load_file(str(source))
	var cs := CutscenePlayer.new()
	parent.add_child(cs)
	if d == null:
		cs.call_deferred("_finish", true)
		return cs
	for k: String in p_vars:
		d.vars[k] = p_vars[k]
	for s: String in slot_bindings:
		d.bind_slot(s, str(slot_bindings[s]))
	cs.start(d)
	return cs


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func start(p_doc: CutsceneDoc) -> void:
	doc = p_doc
	for wmsg in doc.warnings:
		push_warning("Cutscene '%s': %s" % [doc.name, wmsg])
	_order = doc.play_order()
	var size := Vector2i(doc.w, doc.h)
	_cur_stage = _make_stage(size)
	_prev_stage = _make_stage(size)
	_final_vp = _make_vp(size)
	var rect := ColorRect.new()
	rect.size = Vector2(size)
	_final_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TRANSITION_SHADER
	_final_mat.shader = sh
	_final_mat.set_shader_parameter("cur", _cur_stage["out"].get_texture())
	_final_mat.set_shader_parameter("prev", _prev_stage["out"].get_texture())
	_final_mat.set_shader_parameter("size", Vector2(size))
	rect.material = _final_mat
	_final_vp.add_child(rect)
	# Screen: black letterbox + the stage scaled to fit, nearest-neighbour.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(black)
	_display = TextureRect.new()
	_display.texture = _final_vp.get_texture()
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(_display)
	_skip_hint = NeonTheme.label("▸ skip", 13, Color(1, 1, 1, 0.35))
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.position -= Vector2(70, 30)
	_skip_hint.visible = skippable
	root.add_child(_skip_hint)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	time = 0.0
	playing = true
	render(0.0)


func _make_vp(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.disable_3d = true
	# The builder works in plain sRGB; the project's HDR-2D (for neon glow)
	# would store these buffers in linear light and darken every cutscene.
	vp.use_hdr_2d = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


## A stage = shot layers (inner) → post/grade shader (out).
func _make_stage(size: Vector2i) -> Dictionary:
	var inner := _make_vp(size)
	var view := CutsceneShotView.new()
	inner.add_child(view)
	var out := _make_vp(size)
	var rect := ColorRect.new()
	rect.size = Vector2(size)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = POST_SHADER
	mat.shader = sh
	mat.set_shader_parameter("src", inner.get_texture())
	mat.set_shader_parameter("size", Vector2(size))
	rect.material = mat
	out.add_child(rect)
	return {"inner": inner, "view": view, "out": out, "mat": mat}


func _process(delta: float) -> void:
	if not playing:
		return
	time += delta
	if time >= doc.total_time():
		_finish(false)
		return
	render(time)


func _unhandled_input(event: InputEvent) -> void:
	if not playing or not skippable:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_finish(true)


## Where is `t` on the timeline? {"i": shot index, "local": real local, "step": order index}
func shot_at(t: float) -> Dictionary:
	var acc := 0.0
	for k in _order.size():
		var i := _order[k]
		var r := CutsceneDoc.shot_real(doc.shots[i])
		if t < acc + r or k == _order.size() - 1:
			return {"i": i, "local": clampf(t - acc, 0.0, r), "step": k}
		acc += r
	return {"i": 0, "local": 0.0, "step": 0}


## Renders the frame at timeline time `t` (also used for scrubbing / previews).
func render(t: float) -> void:
	var at := shot_at(t)
	var i: int = at["i"]
	var S: Dictionary = doc.shots[i]
	var real_local: float = at["local"]
	var local := CutsceneDoc.warp(S, real_local)
	var freeze := real_local - local
	_render_stage(_cur_stage, i, local, freeze)
	var T: Dictionary = S["tin"]
	var kind := TRANSITIONS.find(str(T["type"]))
	var tdur := float(T["dur"])
	if kind > 0 and tdur > 0.0 and real_local < tdur:
		var step: int = at["step"]
		var has_prev := step > 0
		if has_prev:
			var pi := _order[step - 1]
			_render_stage(_prev_stage, pi, float(doc.shots[pi]["dur"]), 0.0)
		var col := Color(str(T["color"]))
		if kind == 3 and str(T["color"]).to_lower() == "#000000":
			col = Color.WHITE
		_final_mat.set_shader_parameter("kind", kind)
		_final_mat.set_shader_parameter("p", clampf(real_local / tdur, 0.0, 1.0))
		_final_mat.set_shader_parameter("has_prev", has_prev)
		_final_mat.set_shader_parameter("color", col)
	else:
		_final_mat.set_shader_parameter("kind", 0)
	_fire_cues(i, local)


func _render_stage(stage: Dictionary, index: int, t: float, freeze: float) -> void:
	var view: CutsceneShotView = stage["view"]
	view.show_shot(doc, index)
	view.render_at(t, freeze)
	var S: Dictionary = doc.shots[index]
	var F: Dictionary = S["fx"]
	var C: Dictionary = S["cam"]
	var dur := float(S["dur"])
	var p := clampf(t / dur, 0.0, 1.0) if dur > 0.0 else 0.0
	var e := CutsceneDoc.ease_fn(p, str(C.get("ease", "out")))
	var z0 := CutsceneDoc.pvf(C, "zoom0", t, 1.0)
	var zoom := z0 + (CutsceneDoc.pvf(C, "zoom1", t, 1.0) - z0) * e
	var shk := CutsceneDoc.pvf(C, "shake", t)
	var shake := Vector2.ZERO
	if shk > 0.0:
		var dec := (1.0 - p) if bool(C.get("shakeDecay", true)) else 1.0
		var sf := float(C.get("shakeFreq", 22))
		shake = Vector2(sin(t * sf) * shk * dec, cos(t * sf * 1.37 + 1.1) * shk * dec)
	var m: ShaderMaterial = stage["mat"]
	m.set_shader_parameter("bg", Color(str(S["bg"])))
	m.set_shader_parameter("zoom", zoom)
	m.set_shader_parameter("shake", shake)
	m.set_shader_parameter("bright", CutsceneDoc.pvf(F, "bright", t, 1.0))
	m.set_shader_parameter("contrast", CutsceneDoc.pvf(F, "contrast", t, 1.0))
	m.set_shader_parameter("sat", CutsceneDoc.pvf(F, "sat", t, 1.0))
	m.set_shader_parameter("hue", CutsceneDoc.pvf(F, "hue", t))
	var wc := Color(str(F.get("tint", "#3ee0d8")))
	m.set_shader_parameter("wash", Vector3(wc.r, wc.g, wc.b))
	m.set_shader_parameter("wash_amt", CutsceneDoc.pvf(F, "tintAmt", t))
	m.set_shader_parameter("vignette", CutsceneDoc.pvf(F, "vignette", t))
	m.set_shader_parameter("scan", CutsceneDoc.pvf(F, "scan", t))
	m.set_shader_parameter("grain", CutsceneDoc.pvf(F, "grain", t))
	m.set_shader_parameter("t", t)
	var fl := CutsceneDoc.pvf(F, "flash", t)
	var fdur := float(F.get("flashDur", 0.18))
	m.set_shader_parameter("flash_a", fl * (1.0 - t / fdur) if fl > 0.0 and t < fdur and fdur > 0.0 else 0.0)
	m.set_shader_parameter("flash_color", Color(str(F.get("flashColor", "#ffffff"))))
	m.set_shader_parameter("bars", CutsceneDoc.pvf(F, "bars", t))


## Audio cues + engine events crossing (last, now] — port of fireAudio().
func _fire_cues(index: int, content: float) -> void:
	var S: Dictionary = doc.shots[index]
	var from := float(_audio_cursor["t"]) if int(_audio_cursor["shot"]) == index else -1.0
	for ev: Dictionary in S["events"]:
		var et := float(ev.get("t", 0))
		if et > from and et <= content:
			event_fired.emit(str(ev.get("name", "")), ev.get("data"))
			if EventBus.has_signal("cutscene_event"):
				EventBus.cutscene_event.emit(str(ev.get("name", "")), ev.get("data"))
	for m: Dictionary in S["audio"]:
		var mt := float(m.get("t", 0))
		if mt > from and mt <= content:
			var stream: AudioStream = doc.sounds.get(str(m.get("key", "")))
			if stream == null:
				stream = AudioManager._find(AudioManager.SFX_DIR, str(m.get("key", "")))
			if stream:
				var p := _sfx[_sfx_i]
				_sfx_i = (_sfx_i + 1) % _sfx.size()
				p.stream = stream
				p.volume_db = linear_to_db(clampf(float(m.get("vol", 1.0)), 0.001, 1.0))
				p.play()
	_audio_cursor = {"shot": index, "t": content}


func _finish(skipped: bool) -> void:
	if not playing and doc != null:
		return
	playing = false
	finished.emit(skipped)
	queue_free()
