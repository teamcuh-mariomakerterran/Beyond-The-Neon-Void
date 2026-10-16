shader_type canvas_item;
// RECIPE: angular death/teleport dissolve. Instead of soft noise (status_look `dissolve`), the
// body breaks into straight-edged triangular shards that drift out along a direction and burn
// at the edge: rigid "Blizzard/McFarlane" read, not smoke. Drive `progress` 0 -> 1.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 burn_color : source_color = vec4(1.0, 0.18, 0.53, 1.0);
uniform float glow = 2.5;
uniform vec2 drift = vec2(0.6, -1.0);
uniform float shard_px = 5.0;
varying vec2 local;
varying vec4 v_mod;
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
void vertex() { local = VERTEX; v_mod = COLOR; }
void fragment() {
	// Triangulated grid: split each square cell on its diagonal -> two shard ids.
	vec2 g = local / shard_px;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float tri = step(f.x, f.y);
	float id = hash21(cell + tri * 31.7);
	float local_p = clamp((progress * 1.4 - id * 0.4), 0.0, 1.0);
	// Shards fly: sample the art from where this pixel's shard came from.
	vec2 off = drift * local_p * local_p * 18.0 * TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV - off) * v_mod;
	float alive = step(local_p, 0.85);
	float edge = smoothstep(0.55, 0.85, local_p);
	c.rgb = mix(c.rgb, burn_color.rgb * glow, edge);
	COLOR = vec4(c.rgb, c.a * alive);
}
