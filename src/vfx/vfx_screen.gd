class_name VFXScreen
extends VFXPart
## Screen-space layers that read hint_screen_texture:
##  shockwave  radius, squash, thickness (0..1 of radius), strength (UV
##             refraction), rim (colour, HDR ok), dark (0..1 darkens inside
##             the band — void rings), chroma (RGB split), ease
##  glitch     size [w,h], slices, amount (UV shift), split (RGB offset),
##             tint, rate (re-rolls per second), bars

const SHOCK_CODE := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float progress = 0.0;
uniform float thickness = 0.18;
uniform float strength = 0.02;
uniform vec4 rim = vec4(1.0);
uniform float fade = 1.0;
uniform float dark = 0.0;
uniform float chroma = 0.6;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float x = (d - progress) / max(thickness, 0.001);
	float band = exp(-x * x * 2.0);
	vec2 dir = p / max(d, 0.0001);
	dir.y *= 0.5;
	vec2 off = dir * strength * fade * x * band;
	vec3 col;
	col.r = texture(screen_tex, SCREEN_UV - off * (1.0 + chroma)).r;
	col.g = texture(screen_tex, SCREEN_UV - off).g;
	col.b = texture(screen_tex, SCREEN_UV - off * (1.0 - chroma)).b;
	col *= 1.0 - dark * band * fade;
	float edge = exp(-pow((d - progress) / max(thickness * 0.28, 0.001), 2.0));
	col += rim.rgb * edge * fade * rim.a;
	float outside = 1.0 - smoothstep(0.92, 1.0, d);
	COLOR = vec4(col, clamp(band * 1.6 + edge, 0.0, 1.0) * outside);
}
"""

const GLITCH_CODE := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float slices = 14.0;
uniform float amount = 0.02;
uniform float split = 0.006;
uniform float seed_t = 0.0;
uniform float intensity = 1.0;
uniform vec4 tint = vec4(0.25, 1.0, 1.4, 1.0);
uniform float bars = 0.5;
float h(vec2 v) { return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float band = floor(UV.y * slices);
	float r = h(vec2(band, seed_t));
	float r2 = h(vec2(band + 17.0, seed_t * 1.37));
	float on = step(0.45, r);
	float shift = (r2 - 0.5) * 2.0 * amount * on * intensity;
	vec2 suv = SCREEN_UV + vec2(shift, 0.0);
	float sp = split * intensity * (0.5 + r);
	vec3 col;
	col.r = texture(screen_tex, suv + vec2(sp, 0.0)).r;
	col.g = texture(screen_tex, suv).g;
	col.b = texture(screen_tex, suv - vec2(sp, 0.0)).b;
	float bar = step(1.0 - bars * 0.35, r2) * on;
	col += tint.rgb * bar * 0.6 * intensity;
	float scan = 0.85 + 0.15 * sin(UV.y * 220.0);
	col *= scan;
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.08, e.x) * smoothstep(0.0, 0.05, e.y);
	float a = intensity * edge * (0.55 + 0.45 * on);
	COLOR = vec4(col, a);
}
"""

static var _shock_shader: Shader
static var _glitch_shader: Shader

var _mat: ShaderMaterial
var _glitch := false
var _white: Texture2D


func default_blend() -> String:
	return "mix"


func _setup() -> void:
	# Draw before the effect's other layers so the screen copy holds the scene
	# under the effect rather than chopping our own particles.
	if not d.has("z"):
		z_index = -1
	_glitch = str(d.get("type", "")) == "glitch"
	_mat = ShaderMaterial.new()
	if _glitch:
		if _glitch_shader == null:
			_glitch_shader = Shader.new()
			_glitch_shader.code = GLITCH_CODE
		_mat.shader = _glitch_shader
		_mat.set_shader_parameter("slices", num("slices", 14.0))
		_mat.set_shader_parameter("amount", num("amount", 0.02))
		_mat.set_shader_parameter("split", num("split", 0.006))
		_mat.set_shader_parameter("bars", num("bars", 0.5))
		var tc := col("tint", "$main")
		_mat.set_shader_parameter("tint", Vector4(tc.r, tc.g, tc.b, tc.a))
	else:
		if _shock_shader == null:
			_shock_shader = Shader.new()
			_shock_shader.code = SHOCK_CODE
		_mat.shader = _shock_shader
		_mat.set_shader_parameter("thickness", num("thickness", 0.18))
		_mat.set_shader_parameter("dark", num("dark", 0.0))
		_mat.set_shader_parameter("chroma", num("chroma", 0.6))
		var rc := col("rim", "$main")
		_mat.set_shader_parameter("rim", Vector4(rc.r, rc.g, rc.b, rc.a))
	material = _mat
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)


func _update(lt: float, _dt: float) -> void:
	var u := clampf(lt / life, 0.0, 1.0)
	if _glitch:
		var rate := num("rate", 20.0)
		_mat.set_shader_parameter("seed_t", floor(lt * rate) + rng.randf() * 0.0)
		var inten := envelope(num("attack", 0.04), 1.0)
		# Stutter: drop out for a frame now and then.
		if fmod(lt * rate * 0.37, 1.0) > 0.86:
			inten *= 0.25
		_mat.set_shader_parameter("intensity", inten)
	else:
		var ease_u := 1.0 - pow(1.0 - u, num("ease", 2.2))
		var p1 := 0.92 - num("thickness", 0.18) * 0.3
		var p0 := num("p0", 0.05)
		if bool(d.get("reverse", false)):
			_mat.set_shader_parameter("progress", lerpf(p1, p0, ease_u))
		else:
			_mat.set_shader_parameter("progress", lerpf(p0, p1, ease_u))
		_mat.set_shader_parameter("fade", pow(1.0 - u, num("power", 1.3)))
		_mat.set_shader_parameter("strength", num("strength", 0.025))


func _draw() -> void:
	if t < 0.0:
		return
	if _glitch:
		var s := vec("size", Vector2(70, 100))
		draw_texture_rect(_white, Rect2(-s.x * 0.5, -s.y, s.x, s.y), false)
	else:
		var r := num("radius", 90.0)
		var sq := num("squash", 0.5)
		draw_texture_rect(_white, Rect2(-r, -r * sq, r * 2, r * 2 * sq), false)
