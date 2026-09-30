class_name CutsceneLayerItem
extends Node2D
## Draws one PARALLAX layer for the current frame — a port of the builder's
## drawLayer / drawTextLayer / drawPanel / drawDistort. Placement math (anchor,
## parallax, speed drift, bob, groups, pivots, attach points, tiling, motion
## blur, anim frame selection) follows cutscene-builder.html exactly.
##
## Approximations (Godot canvas has no CSS filters / canvas composite ops):
##  * blend: lighter/screen -> additive, multiply -> multiply, overlay/soft-light -> normal
##  * blur is ignored; palette swaps are ignored (logged once)

var view: CutsceneShotView
var L: Dictionary
var forced: bool = false  # drawing as a mask source / masked child
var _t: float = 0.0
var _freeze: float = 0.0
var _mat: ShaderMaterial

const LAYER_SHADER := """
shader_type canvas_item;
render_mode %s;
uniform float bright = 1.0;
uniform float contrast = 1.0;
uniform float sat = 1.0;
uniform float hue = 0.0;
uniform vec3 tint = vec3(1.0);
uniform float tint_amt = 0.0;
vec3 hue_rotate(vec3 c, float deg) {
	float a = radians(deg);
	float cs = cos(a); float sn = sin(a);
	mat3 m = mat3(
		vec3(0.213 + cs*0.787 - sn*0.213, 0.213 - cs*0.213 + sn*0.143, 0.213 - cs*0.213 - sn*0.787),
		vec3(0.715 - cs*0.715 - sn*0.715, 0.715 + cs*0.285 + sn*0.140, 0.715 - cs*0.715 + sn*0.715),
		vec3(0.072 - cs*0.072 + sn*0.928, 0.072 - cs*0.072 - sn*0.283, 0.072 + cs*0.928 + sn*0.072));
	return m * c;
}
void fragment() {
	vec4 c = COLOR;  // Godot 4: COLOR already = texture × modulate
	c.rgb = mix(c.rgb, tint, tint_amt);
	c.rgb *= bright;
	c.rgb = (c.rgb - 0.5) * contrast + 0.5;
	float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	c.rgb = mix(vec3(l), c.rgb, sat);
	if (hue != 0.0) { c.rgb = hue_rotate(c.rgb, hue); }
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), c.a);
}
"""

static var _shader_cache: Dictionary = {}


static func blend_mode_for(blend: String) -> String:
	match blend:
		"lighter", "screen": return "blend_add"
		"multiply": return "blend_mul"
	return "blend_mix"


func setup(p_view: CutsceneShotView, p_layer: Dictionary, p_forced: bool = false) -> void:
	view = p_view
	L = p_layer
	forced = p_forced
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mode := blend_mode_for(str(L.get("blend", "source-over")))
	if not _shader_cache.has(mode):
		var sh := Shader.new()
		sh.code = LAYER_SHADER % mode
		_shader_cache[mode] = sh
	_mat = ShaderMaterial.new()
	_mat.shader = _shader_cache[mode]
	material = _mat


func pv(key: String) -> Variant:
	return CutsceneDoc.pv(L, key, _t)


func pvf(key: String, fallback: float = 0.0) -> float:
	return CutsceneDoc.pvf(L, key, _t, fallback)


## Called by the shot view once per frame before redraw. Returns false if hidden.
func update_frame(t: float, freeze: float) -> void:
	_t = t
	_freeze = freeze
	if freeze > 0.0 and float(L.get("stopScale", 0)) != 0.0:
		_t += freeze * float(L["stopScale"])
	var op := pvf("opacity", 1.0) * (1.0 if forced else view.group_alpha(L, _t))
	visible = (bool(L.get("visible", true)) or forced) and op > 0.0 and (forced or not bool(L.get("maskSource", false)))
	modulate = Color(1, 1, 1, clampf(op, 0.0, 1.0))
	if _mat:
		_mat.set_shader_parameter("bright", pvf("bright", 1.0))
		_mat.set_shader_parameter("contrast", pvf("contrast", 1.0))
		_mat.set_shader_parameter("sat", pvf("sat", 1.0))
		_mat.set_shader_parameter("hue", pvf("hue", 0.0))
		var tc := Color(str(L.get("tint", "#ff4fa3")))
		_mat.set_shader_parameter("tint", Vector3(tc.r, tc.g, tc.b))
		_mat.set_shader_parameter("tint_amt", pvf("tintAmt", 0.0))
	queue_redraw()


# --- Placement (port of place()) ------------------------------------------

func anchor_y(dh: float) -> float:
	var H := float(view.doc.h)
	match str(L.get("anchor", "bottom")):
		"top": return 0.0
		"center": return (H - dh) / 2.0
	return H - dh


func place_at(t: float, dw: float, dh: float) -> Vector2:
	var par := CutsceneDoc.pvf(L, "parallax", t, 1.0)
	var bob_amp := CutsceneDoc.pvf(L, "bobAmp", t)
	var bob := sin(t * CutsceneDoc.pvf(L, "bobSpeed", t, 1.0) * TAU) * bob_amp if bob_amp != 0.0 else 0.0
	var go := view.group_offset(L, t)
	return Vector2(
		CutsceneDoc.pvf(L, "x", t) + CutsceneDoc.pvf(L, "speedX", t) * t + view.cam.x * par + go.x,
		anchor_y(dh) + CutsceneDoc.pvf(L, "y", t) + CutsceneDoc.pvf(L, "speedY", t) * t + view.cam.y * par + bob + go.y)


func frame_info() -> Dictionary:
	var r := view.doc.resolve_slot(L)
	if not r.is_empty():
		var act: Dictionary = r["act"]
		return {"fw": maxi(int(act.get("frameW", 32)), 1), "fh": maxi(int(act.get("frameH", 32)), 1),
			"count": int(act.get("frames", 0)), "fps": float(act.get("fps", 12)),
			"pivotX": act.get("pivotX"), "pivotY": act.get("pivotY"), "ground": float(act.get("groundOffsetY", 0)),
			"attach": act.get("attach", {}), "asset": r["asset"]}
	return {"fw": maxi(int(L.get("frameW", 32)), 1), "fh": maxi(int(L.get("frameH", 32)), 1),
		"count": int(L.get("frameCount", 0)), "fps": float(L.get("fps", 12)),
		"pivotX": null, "pivotY": null, "ground": 0.0, "attach": {}, "asset": str(L.get("asset", ""))}


func texture() -> Texture2D:
	var fi := frame_info()
	return view.doc.textures.get(fi["asset"])


## Centre of the layer ignoring camera — used by camera follow.
func centre() -> Variant:
	var kind := str(L["kind"])
	if kind == "solid":
		return Vector2(view.doc.w / 2.0, view.doc.h / 2.0)
	var tex := texture()
	var sw: float
	var sh: float
	if kind == "panel":
		sw = pvf("boxW", 200)
		sh = pvf("boxH", 64)
	elif tex == null:
		return null
	elif kind == "anim":
		var fi := frame_info()
		sw = fi["fw"]
		sh = fi["fh"]
	else:
		sw = tex.get_width()
		sh = tex.get_height()
	var scl := pvf("scale", 1.0) * view.group_scale(L, _t)
	var dw := sw if kind == "panel" else sw * scl
	var dh := sh if kind == "panel" else sh * scl
	var saved := view.cam
	view.cam = Vector2.ZERO
	var b := place_at(_t, dw, dh)
	view.cam = saved
	return b + Vector2(dw, dh) / 2.0


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	match str(L["kind"]):
		"solid":
			draw_rect(Rect2(0, 0, view.doc.w, view.doc.h), Color(str(L.get("color", "#1a1030"))))
		"text":
			_draw_text()
		"panel":
			_draw_panel()
		"distort":
			pass  # handled by CutsceneDistortItem
		_:
			_draw_image()


func _draw_image() -> void:
	var fi := frame_info()
	var tex: Texture2D = view.doc.textures.get(fi["asset"])
	if tex == null:
		return
	var sx := 0.0
	var sy := 0.0
	var sw := float(tex.get_width())
	var sh := float(tex.get_height())
	if str(L["kind"]) == "anim":
		var fw: int = fi["fw"]
		var fh: int = fi["fh"]
		var cols := maxi(1, tex.get_width() / fw)
		var rows := maxi(1, tex.get_height() / fh)
		var start := int(L.get("startFrame", 0))
		var avail := maxi(1, cols * rows - start)
		var total := maxi(1, mini(int(fi["count"]), avail) if int(fi["count"]) > 0 else avail)
		var lt := _t - float(L.get("delay", 0))
		if lt < 0.0 and bool(L.get("hideBefore", true)):
			return
		var raw := int(floor(maxf(0.0, lt) * float(fi["fps"])))
		var f: int
		if bool(L.get("pingpong", false)) and total > 1:
			var per := total * 2 - 2
			var k := ((raw % per) + per) % per
			f = k if k < total else per - k
		elif bool(L.get("loop", true)):
			f = ((raw % total) + total) % total
		else:
			f = mini(raw, total - 1)
		if not bool(L.get("loop", true)) and not bool(L.get("pingpong", false)) and not bool(L.get("holdLast", true)) and raw >= total:
			return
		f += start
		sx = (f % cols) * fw
		sy = (f / cols) * fh
		sw = fw
		sh = fh
	var scl := pvf("scale", 1.0) * view.group_scale(L, _t)
	var dw := maxf(1.0, sw * scl)
	var dh := maxf(1.0, sh * scl)
	var b := place_at(_t, dw, dh)
	if str(L["kind"]) == "anim" and (fi["pivotX"] != null or fi["pivotY"] != null or float(fi["ground"]) != 0.0):
		var pxv := sw / 2.0 if fi["pivotX"] == null else float(fi["pivotX"])
		var pyv := sh if fi["pivotY"] == null else float(fi["pivotY"])
		b.x += dw / 2.0 - pxv * scl
		b.y += dh - pyv * scl + float(fi["ground"]) * scl
	var att := str(L.get("attach", ""))
	if att != "" and view.placements.has(att):
		var p: Vector2 = view.placements[att]
		b = p + Vector2(pvf("x"), pvf("y")) - Vector2(dw, dh) / 2.0
	var attach: Dictionary = fi["attach"] if fi["attach"] is Dictionary else {}
	for k: String in attach:
		var ap: Dictionary = attach[k]
		var pt := Vector2(b.x + (dw - float(ap.get("x", 0)) * scl if bool(L.get("flipH", false)) else float(ap.get("x", 0)) * scl), b.y + float(ap.get("y", 0)) * scl)
		view.placements[str(L["id"]) + "@" + k] = pt
		if str(L.get("slot", "")) != "":
			view.placements["%s.%s@%s" % [L["slot"], L.get("action", "idle"), k]] = pt
	var region := Rect2(sx, sy, sw, sh)
	# Motion blur: sample the layer's own path over the previous frame.
	var mb_d := Vector2.ZERO
	var mb_n := 1
	if float(L.get("mblur", 0)) > 0.0:
		var dt := 1.0 / maxf(1.0, view.doc.fps)
		var prev := place_at(maxf(0.0, _t - dt), dw, dh)
		mb_d = (b - prev) * float(L["mblur"])
		if mb_d.length() < 0.6:
			mb_d = Vector2.ZERO
		else:
			mb_n = clampi(int(L.get("mblurSamples", 5)), 2, 12)
	var W := float(view.doc.w)
	var H := float(view.doc.h)
	var xs: Array[float] = []
	var ys: Array[float] = []
	if bool(L.get("tileX", false)):
		var x0 := fposmod(b.x, dw) - dw
		var x := x0
		while x < W:
			xs.append(x)
			x += dw
	else:
		xs.append(b.x)
	if bool(L.get("tileY", false)):
		var y0 := fposmod(b.y, dh) - dh
		var y := y0
		while y < H:
			ys.append(y)
			y += dh
	else:
		ys.append(b.y)
	var fh := bool(L.get("flipH", false))
	var fv := bool(L.get("flipV", false))
	for x in xs:
		for y in ys:
			for i in mb_n:
				var f := 0.0 if mb_n < 2 else float(i) / (mb_n - 1) - 1.0
				var pos := Vector2(roundf(x), roundf(y)) + mb_d * f
				var a := 1.0 if mb_n < 2 else 1.0 / mb_n
				draw_set_transform(pos + Vector2(dw if fh else 0.0, dh if fv else 0.0), 0.0, Vector2(-1.0 if fh else 1.0, -1.0 if fv else 1.0))
				draw_texture_rect_region(tex, Rect2(0, 0, dw, dh), region, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)


# --- Text ------------------------------------------------------------------

func _font() -> Font:
	var fam := str(L.get("fontFam", "monospace")).to_lower()
	if fam.contains("mono") or fam.contains("courier") or fam.contains("pixel"):
		return NeonTheme.mono()
	return NeonTheme.font(NeonTheme.FONT_BODY)


func _advance(font: Font, fsize: int, ch: String, sc: float) -> float:
	if str(L.get("fontMode", "system")) == "bitmap":
		return (float(L.get("glyphW", 8)) + float(L.get("tracking", 0))) * sc
	return font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + float(L.get("tracking", 0)) * sc


func _layout(font: Font, fsize: int, text: String, sc: float) -> Array[String]:
	var hard := text.replace("\r", "").split("\n")
	var out: Array[String] = []
	if not bool(L.get("wrap", false)):
		out.assign(hard)
		return out
	var limit := maxf(8.0, float(L.get("wrapW", 200)))
	var re := RegEx.create_from_string("\\s+|\\S+")
	for para in hard:
		var line := ""
		var wsum := 0.0
		for m in re.search_all(para):
			var tok := m.get_string()
			var tw := 0.0
			for ch in tok:
				tw += _advance(font, fsize, ch, sc)
			if wsum + tw > limit and line.strip_edges() != "":
				out.append(line.rstrip(" \t"))
				line = tok.lstrip(" \t")
				wsum = 0.0
				for ch in line:
					wsum += _advance(font, fsize, ch, sc)
			else:
				line += tok
				wsum += tw
		out.append(line.rstrip(" \t"))
	return out


func _draw_text() -> void:
	var text := view.doc.subst(str(L.get("text", "")).replace("\\n", "\n"))
	if text == "":
		return
	var sc := pvf("scale", 1.0) * view.group_scale(L, _t)
	if sc == 0.0:
		sc = 1.0
	var bitmap := str(L.get("fontMode", "system")) == "bitmap"
	var font := _font()
	var fsize := maxi(1, roundi(float(L.get("fontSize", 16)) * sc))
	var lines := _layout(font, fsize, text, sc)
	var shown := lines
	var reveal := float(L.get("reveal", 0))
	if reveal > 0.0:
		var at := _t - float(L.get("revealDelay", 0))
		if at <= 0.0:
			return
		var budget := int(floor(at * reveal))
		shown = []
		for ln in lines:
			if budget <= 0:
				break
			shown.append(ln if ln.length() <= budget else ln.substr(0, budget))
			budget -= ln.length()
		if shown.is_empty():
			return
	var lh := (float(L.get("glyphH", 8)) if bitmap else float(L.get("fontSize", 16))) * sc * float(L.get("lineH", 1.35))
	var max_w := 0.0
	for ln in lines:
		var lw := 0.0
		for ch in ln:
			lw += _advance(font, fsize, ch, sc)
		max_w = maxf(max_w, lw)
	var block_h := maxf(1.0, lh * lines.size())
	var b := place_at(_t, max_w, block_h)
	var W := float(view.doc.w)
	match str(L.get("align", "center")):
		"center": b.x += (W - max_w) / 2.0
		"right": b.x += W - max_w
	b = b.round()
	var tex: Texture2D = view.doc.textures.get(str(L.get("asset", ""))) if bitmap else null
	if bitmap and tex == null:
		return
	var gw := float(L.get("glyphW", 8))
	var gh := float(L.get("glyphH", 8))
	var cols := maxi(1, int(tex.get_width() / maxf(1.0, gw))) if tex else 1
	var charset := str(L.get("charset", ""))
	var color := Color(str(L.get("textColor", "#ffffff")))
	var outline := float(L.get("outline", 0))
	var ocolor := Color(str(L.get("outlineColor", "#000000")))
	# Canvas textBaseline "top" = top of the em box: the baseline sits at the
	# font's ascent share of the em, not at its full (line-gap padded) ascent.
	var fa := font.get_ascent(fsize)
	var fd := font.get_descent(fsize)
	var ascent := fsize * fa / maxf(fa + fd, 1.0)
	for i in shown.size():
		var ln: String = shown[i]
		var lw := 0.0
		for ch in ln:
			lw += _advance(font, fsize, ch, sc)
		var cx := b.x
		match str(L.get("align", "center")):
			"center": cx = b.x + (max_w - lw) / 2.0
			"right": cx = b.x + (max_w - lw)
		var cy := b.y + i * lh
		for ch in ln:
			if bitmap:
				var idx := charset.find(ch.to_upper())
				if idx >= 0:
					draw_texture_rect_region(tex, Rect2(roundf(cx), roundf(cy), roundf(gw * sc), roundf(gh * sc)), Rect2((idx % cols) * gw, (idx / cols) * gh, gw, gh))
			else:
				if outline > 0.0:
					draw_string_outline(font, Vector2(cx, cy + ascent), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, int(outline * 2.0), ocolor)
				draw_string(font, Vector2(cx, cy + ascent), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color)
			cx += _advance(font, fsize, ch, sc)


# --- 9-slice panels --------------------------------------------------------

func _draw_panel() -> void:
	var tex: Texture2D = view.doc.textures.get(str(L.get("asset", "")))
	if tex == null:
		return
	var aw := float(tex.get_width())
	var ah := float(tex.get_height())
	var sc := pvf("scale", 1.0) * view.group_scale(L, _t)
	var l := maxf(0.0, float(L.get("insL", 8)))
	var r := maxf(0.0, float(L.get("insR", 8)))
	var tp := maxf(0.0, float(L.get("insT", 8)))
	var bt := maxf(0.0, float(L.get("insB", 8)))
	if l + r >= aw or tp + bt >= ah:
		return
	var dw := maxf((l + r) * sc + 1.0, pvf("boxW", 200))
	var dh := maxf((tp + bt) * sc + 1.0, pvf("boxH", 64))
	var p := place_at(_t, dw, dh).round()
	var sxs := [0.0, l, aw - r]
	var sws := [l, aw - l - r, r]
	var sys := [0.0, tp, ah - bt]
	var shs := [tp, ah - tp - bt, bt]
	var dxs := [0.0, l * sc, dw - r * sc]
	var dws := [l * sc, dw - (l + r) * sc, r * sc]
	var dys := [0.0, tp * sc, dh - bt * sc]
	var dhs := [tp * sc, dh - (tp + bt) * sc, bt * sc]
	var tile := str(L.get("edgeMode", "stretch")) == "tile"
	for i in 3:
		for j in 3:
			if sws[j] <= 0 or shs[i] <= 0 or dws[j] <= 0 or dhs[i] <= 0:
				continue
			var corner := i != 1 and j != 1
			if not tile or corner:
				draw_texture_rect_region(tex, Rect2(roundf(p.x + dxs[j]), roundf(p.y + dys[i]), ceilf(dws[j]), ceilf(dhs[i])), Rect2(sxs[j], sys[i], sws[j], shs[i]))
			else:
				var step_x: float = sws[j] * sc
				var step_y: float = shs[i] * sc
				var y := 0.0
				while y < dhs[i]:
					var x := 0.0
					while x < dws[j]:
						var cw: float = minf(step_x, dws[j] - x)
						var ch: float = minf(step_y, dhs[i] - y)
						draw_texture_rect_region(tex, Rect2(roundf(p.x + dxs[j] + x), roundf(p.y + dys[i] + y), ceilf(cw), ceilf(ch)), Rect2(sxs[j], sys[i], sws[j] * (cw / step_x), shs[i] * (ch / step_y)))
						x += step_x
					y += step_y
