shader_type canvas_item;
// Full-screen "the HUD was lying" glitch: RGB split, tearing bands, scanlines.
// strength 0..1 is tweened up and back down by whoever plays it.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength = 0.0;
uniform float seed = 0.0;

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 38.0 + seed * 7.0);
	float tear = (rnd(vec2(band, floor(TIME * 24.0))) - 0.5) * 0.06 * strength;
	tear *= step(0.55, rnd(vec2(band * 1.7, seed)));
	uv.x += tear;
	float split = 0.012 * strength;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(split, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(split, 0.0)).b;
	float scan = 0.85 + 0.15 * sin(SCREEN_UV.y * 900.0);
	col *= mix(1.0, scan, strength);
	col += vec3(0.25, 0.0, 0.35) * strength * step(0.97, rnd(vec2(band, TIME)));
	COLOR = vec4(col, 1.0);
}
