shader_type canvas_item;
// RECIPE: hard pixel outline (selection, targeted, "marked", boss aura). 4-neighbour alpha
// test in texel space, so it is exactly 1 art pixel wide at any zoom. Angular, not a soft glow:
// the bloom comes from HDR (glow > 1), not from blur.
uniform vec4 outline_color : source_color = vec4(0.25, 0.82, 1.0, 1.0);  // NeonTheme.CYAN 3fd2ff
uniform float glow = 2.2;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float blink_hz = 0.0;   // 0 = steady; stepped blink otherwise
varying vec4 v_mod;
void vertex() { v_mod = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV) * v_mod;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float edge = step(0.5, n) * (1.0 - step(0.5, c.a));
	float on = blink_hz > 0.0 ? step(0.5, fract(TIME * blink_hz)) : 1.0;
	vec4 o = vec4(outline_color.rgb * glow, 1.0);
	COLOR = mix(c, o, edge * amount * on);
}
// NOTE: an outline needs 1 transparent texel of padding around the frame. Lattice strips
// built at 64x32 usually have it; Forge-sliced sheets may not. If not, add padding at import.
