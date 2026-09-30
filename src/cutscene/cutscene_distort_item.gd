class_name CutsceneDistortItem
extends CutsceneLayerItem
## Distort layers displace what's already drawn beneath them (heat shimmer,
## shockwave ripple, scanline warp) — port of drawDistort(), done with a
## screen-reading shader instead of canvas pixel copies.

const DISTORT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 rect;          // x, y, w, h in stage pixels
uniform int mode = 0;       // 0 shimmer, 1 ripple, 2 warp
uniform float amp = 3.0;
uniform float freq = 6.0;
uniform float speed = 2.0;
uniform float band = 1.0;
uniform float falloff = 1.0;
uniform float t = 0.0;
varying vec2 local_px;
void vertex() { local_px = VERTEX; }
void fragment() {
	vec2 p = local_px - rect.xy;
	float b = max(1.0, band);
	vec2 q = floor(p / b) * b;
	vec2 shift = vec2(0.0);
	if (mode == 1) {
		vec2 c = rect.zw * 0.5;
		vec2 d = q - c;
		float r = max(length(d), 1.0);
		float max_r = max(length(c), 1.0);
		float fall = falloff > 0.0 ? max(0.0, 1.0 - r / max_r) : 1.0;
		float push = sin(r / max(1.0, freq) - t * speed * TAU) * amp * fall;
		shift = (d / r) * push;
	} else if (mode == 2) {
		float cyc = sin((q.y / max(1.0, freq) + t * speed) * TAU);
		shift.x = cyc > 0.82 ? amp : (cyc < -0.82 ? -amp : 0.0);
	} else {
		float fall = falloff > 0.0 ? (1.0 - q.y / rect.w) : 1.0;
		shift.x = sin((q.y / max(1.0, freq)) + t * speed * TAU) * amp * fall;
	}
	vec2 src = p - shift;
	if (src.x < 0.0 || src.y < 0.0 || src.x >= rect.z || src.y >= rect.w) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(screen_tex, SCREEN_UV - shift * SCREEN_PIXEL_SIZE);
	}
}
"""

static var _distort_shader: Shader


func setup(p_view: CutsceneShotView, p_layer: Dictionary, p_forced: bool = false) -> void:
	view = p_view
	L = p_layer
	forced = p_forced
	if _distort_shader == null:
		_distort_shader = Shader.new()
		_distort_shader.code = DISTORT_SHADER.replace("TAU", "6.28318530718")
	_mat = null
	var m := ShaderMaterial.new()
	m.shader = _distort_shader
	material = m


func update_frame(t: float, freeze: float) -> void:
	super(t, freeze)
	var m := material as ShaderMaterial
	var dw := maxf(2.0, pvf("fxW", 160))
	var dh := maxf(2.0, pvf("fxH", 90))
	var b := place_at(_t, dw, dh).round()
	m.set_shader_parameter("rect", Vector4(b.x, b.y, dw, dh))
	m.set_shader_parameter("mode", {"ripple": 1, "warp": 2}.get(str(L.get("fxMode", "shimmer")), 0))
	m.set_shader_parameter("amp", pvf("amp", 3))
	m.set_shader_parameter("freq", pvf("freq", 6))
	m.set_shader_parameter("speed", pvf("speed", 2))
	m.set_shader_parameter("band", pvf("band", 1))
	m.set_shader_parameter("falloff", float(L.get("falloff", 1)))
	m.set_shader_parameter("t", _t)
	visible = visible and pvf("amp", 3) > 0.0


func _draw() -> void:
	var dw := maxf(2.0, pvf("fxW", 160))
	var dh := maxf(2.0, pvf("fxH", 90))
	var b := place_at(_t, dw, dh).round()
	var r := Rect2(b, Vector2(dw, dh)).intersection(Rect2(0, 0, view.doc.w, view.doc.h))
	if r.size.x > 0 and r.size.y > 0:
		draw_rect(r, Color.WHITE)
