class_name HD2DPost
extends CanvasLayer
## "HD-2D" post stack (the Octopath Traveler look) for the isometric view:
##   tilt-shift depth of field  — sharp band at the focus, soft top/bottom,
##                                so the world reads as a lit miniature
##   bloom                       — bright pixels bleed light
##   distance haze               — the top of the screen fades into air
##   god rays                    — slow diagonal light shafts
##   grade                       — warmth, tint, contrast, saturation, lift
##   vignette + film grain
## A map picks a preset (WorldMap "post") and may override any parameter.
## Sits between the world and the HUD: put HUD CanvasLayers on layer >= 10.

const PRESETS := {
	"off": {},
	"hd2d_warm": {"dof": 3.2, "focus_band": 0.16, "falloff": 0.30, "bloom": 0.55, "threshold": 0.62,
		"haze": 0.35, "haze_color": "#d9a066", "rays": 0.18, "ray_color": "#ffd9a0",
		"warmth": 0.18, "tint": "#ffffff", "contrast": 1.08, "saturation": 1.12, "lift": 0.02,
		"vignette": 0.55, "grain": 0.035},
	"neon_noir": {"dof": 2.6, "focus_band": 0.18, "falloff": 0.32, "bloom": 0.85, "threshold": 0.55,
		"haze": 0.30, "haze_color": "#3a1d5c", "rays": 0.0, "ray_color": "#ff3fb4",
		"warmth": -0.08, "tint": "#e8dcff", "contrast": 1.12, "saturation": 1.2, "lift": 0.0,
		"vignette": 0.65, "grain": 0.05},
	"toxic_haze": {"dof": 2.4, "focus_band": 0.15, "falloff": 0.3, "bloom": 0.6, "threshold": 0.58,
		"haze": 0.5, "haze_color": "#7f9a3a", "rays": 0.1, "ray_color": "#cfff7a",
		"warmth": 0.05, "tint": "#e9ffd8", "contrast": 1.05, "saturation": 0.95, "lift": 0.03,
		"vignette": 0.6, "grain": 0.06},
	"dream": {"dof": 4.5, "focus_band": 0.10, "falloff": 0.22, "bloom": 0.9, "threshold": 0.5,
		"haze": 0.45, "haze_color": "#f2c6e0", "rays": 0.3, "ray_color": "#ffffff",
		"warmth": 0.05, "tint": "#fff0fb", "contrast": 0.98, "saturation": 1.05, "lift": 0.05,
		"vignette": 0.4, "grain": 0.02},
	"cinematic": {"dof": 2.0, "focus_band": 0.22, "falloff": 0.35, "bloom": 0.45, "threshold": 0.65,
		"haze": 0.2, "haze_color": "#8aa0c0", "rays": 0.08, "ray_color": "#ffe8c0",
		"warmth": 0.06, "tint": "#ffffff", "contrast": 1.15, "saturation": 1.0, "lift": 0.0,
		"vignette": 0.7, "grain": 0.04},
}

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float dof = 3.0;          // max blur (mip level)
uniform float focus_y = 0.5;      // screen-space focus line (0 top .. 1 bottom)
uniform float focus_band = 0.16;  // half-height of the sharp band
uniform float falloff = 0.3;      // distance over which blur ramps in
uniform float bloom = 0.5;
uniform float threshold = 0.62;
uniform float haze = 0.3;
uniform vec4 haze_color : source_color = vec4(0.85, 0.63, 0.4, 1.0);
uniform float rays = 0.15;
uniform vec4 ray_color : source_color = vec4(1.0, 0.85, 0.63, 1.0);
uniform float warmth = 0.15;
uniform vec4 tint : source_color = vec4(1.0);
uniform float contrast = 1.08;
uniform float saturation = 1.1;
uniform float lift = 0.02;
uniform float vignette = 0.55;
uniform float grain = 0.03;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	// Tilt-shift: blur grows with distance from the focus band (top grows faster,
	// like a camera tilted down at a miniature).
	float d = abs(uv.y - focus_y) - focus_band;
	float top_bias = uv.y < focus_y ? 1.15 : 1.0;
	float lod = clamp(d / max(falloff, 0.001), 0.0, 1.0) * dof * top_bias;
	vec3 col = textureLod(screen_tex, uv, lod).rgb;
	// Bloom from a wide mip: only what's brighter than the threshold.
	vec3 wide = textureLod(screen_tex, uv, 4.0).rgb + textureLod(screen_tex, uv, 5.5).rgb * 0.6;
	col += max(wide - vec3(threshold), vec3(0.0)) * bloom;
	// Atmospheric haze toward the top of the screen (farther away in iso).
	float h = smoothstep(focus_y, 0.0, uv.y) * haze;
	col = mix(col, haze_color.rgb * (0.6 + 0.4 * dot(col, vec3(0.333))), h);
	// Slow diagonal god rays from the top.
	if (rays > 0.0) {
		float r = sin((uv.x * 7.0 + uv.y * 3.0) + TIME * 0.15) * 0.5 + 0.5;
		r *= sin((uv.x * 17.0 + uv.y * 5.0) - TIME * 0.09) * 0.5 + 0.5;
		r = pow(r, 6.0) * smoothstep(0.85, 0.0, uv.y);
		col += ray_color.rgb * r * rays;
	}
	// Grade.
	col += vec3(warmth * 0.12, warmth * 0.03, -warmth * 0.10);
	col *= tint.rgb;
	col = (col - 0.5) * contrast + 0.5 + lift;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	// Vignette + grain.
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * vignette * 1.6;
	col += (hash(uv * 1024.0 + fract(TIME)) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var params: Dictionary = {}


func _init() -> void:
	layer = 5


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
	_apply()


## preset: a PRESETS key; overrides: any parameter, e.g. {"dof": 4.0}.
func configure(preset: String, overrides: Dictionary = {}) -> void:
	params = (PRESETS.get(preset, {}) as Dictionary).duplicate()
	params.merge(overrides, true)
	visible = not params.is_empty()
	_apply()


## Screen-space y (0..1) of what should be sharp — the player or the cursor.
func set_focus(screen_y: float) -> void:
	if _mat:
		_mat.set_shader_parameter("focus_y", clampf(screen_y, 0.05, 0.95))


func _apply() -> void:
	if _mat == null:
		return
	for k: String in params:
		var v: Variant = params[k]
		if v is String and str(v).begins_with("#"):
			v = Color(str(v))
		_mat.set_shader_parameter(k, v)


## Builds the stack for a map dict (`post`: "preset" or {"preset": ..., overrides}).
static func for_map(post: Variant) -> HD2DPost:
	var preset := ""
	var overrides := {}
	if post is String:
		preset = post
	elif post is Dictionary:
		preset = str(post.get("preset", "hd2d_warm"))
		overrides = (post as Dictionary).duplicate()
		overrides.erase("preset")
	if preset == "" or preset == "off" or not PRESETS.has(preset):
		return null
	var p := HD2DPost.new()
	p.configure(preset, overrides)
	return p
