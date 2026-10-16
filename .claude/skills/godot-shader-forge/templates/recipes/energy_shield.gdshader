shader_type canvas_item;
// RECIPE: hex-cell energy shield bubble for `shielded` (e.g. Foreman Grisk in Vault Breach).
// Draw it on a separate Sprite2D/ColorRect child sized around the unit (not the unit body),
// so it can flicker and shatter independently. `hit` spikes on impact (tween 1 -> 0 in 0.25 s);
// `break_t` 0 -> 1 shatters it into angular shards when the core switches unshield.
uniform vec4 shield_color : source_color = vec4(0.25, 0.82, 1.0, 1.0);
uniform float glow = 1.6;
uniform float hit : hint_range(0.0, 1.0) = 0.0;
uniform float break_t : hint_range(0.0, 1.0) = 0.0;
uniform float cells = 9.0;
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec4 hex(vec2 p) {  // returns (local xy, cell id)
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	return vec4(g, p - g);
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	if (d > 1.0) { discard; }
	float rim = smoothstep(0.82, 1.0, d);
	vec4 hx = hex(q * cells * 0.5);
	vec2 ap = abs(hx.xy);
	float hd = max(dot(ap, normalize(vec2(1.0, 1.7320508))), ap.x);  // hex distance, 0.5 at the cell border
	float edge = smoothstep(0.42, 0.5, hd);
	float id = hash21(hx.zw);
	float t = floor(TIME * 10.0) / 10.0;
	float sweep = step(0.92, fract(id + t * 0.35));
	float a = rim * 0.55 + edge * 0.35 + sweep * 0.25 + hit * 0.6;
	// Shatter: cells drop out by id as break_t rises, with a hot edge on the survivors.
	float gone = step(id, break_t);
	a *= 1.0 - gone;
	vec3 col = shield_color.rgb * glow * (1.0 + hit * 1.5) + vec3(1.0) * edge * step(id, break_t + 0.1) * break_t * 2.0;
	COLOR = vec4(col, clamp(a, 0.0, 1.0) * (1.0 - break_t * 0.3));
}
