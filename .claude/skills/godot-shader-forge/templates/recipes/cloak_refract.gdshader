shader_type canvas_item;
// RECIPE: refractive cloak for `cloaked` / `hidden` (Choir Enforcers in Vault Breach). The
// body becomes a lens: the scene behind it shows through, displaced, with a thin edge. Reads
// the screen, so the sprite must draw ABOVE what it refracts (it does: units sort over tiles).
// Pair with gameplay: `reveal` anchors (device) strip it, so animate `amount` 1 -> 0 on reveal.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float strength = 0.006;
uniform vec4 edge_color : source_color = vec4(0.69, 0.3, 1.0, 1.0);  // NeonTheme.VIOLET b14dff
varying vec2 local;
void vertex() { local = VERTEX; }
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float t = floor(TIME * 12.0) / 12.0;
	vec2 wob = vec2(sin(local.y * 0.6 + t * 6.0), cos(local.x * 0.5 - t * 5.0));
	vec3 behind = textureLod(screen_tex, SCREEN_UV + wob * strength * amount, 1.0).rgb;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a * texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		* texture(TEXTURE, UV + vec2(0.0, px.y)).a * texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float edge = art.a * (1.0 - n);
	vec3 col = mix(COLOR.rgb, behind + edge_color.rgb * edge * 1.8, amount);
	COLOR = vec4(col, art.a * mix(COLOR.a, 1.0, amount));
}
