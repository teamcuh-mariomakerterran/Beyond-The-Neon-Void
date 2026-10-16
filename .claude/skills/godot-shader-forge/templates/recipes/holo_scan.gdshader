shader_type canvas_item;
// RECIPE: hologram for comms portraits, Lattice previews, briefing tables, decoys/echoes
// (the `echo` special). Hard scanlines + stepped roll band + per-row jitter. Shares the look
// of screen.gdshader mode 3; prefer reusing screen.gdshader for world signage.
uniform vec4 holo_color : source_color = vec4(0.25, 0.82, 1.0, 1.0);
uniform float glow = 1.5;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float line_px = 2.0;
varying vec2 local;
varying vec4 v_mod;
float hash11(float n) { return fract(sin(n * 91.3458) * 47453.5453); }
void vertex() { local = VERTEX; v_mod = COLOR; }
void fragment() {
	float t = floor(TIME * 15.0) / 15.0;
	float row = floor(local.y / line_px);
	float jit = (hash11(row + floor(t * 4.0)) - 0.5) * step(0.93, hash11(floor(t * 4.0))) * 3.0;
	vec4 c = texture(TEXTURE, UV + vec2(jit * TEXTURE_PIXEL_SIZE.x, 0.0)) * v_mod;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 holo = holo_color.rgb * (0.35 + lum * 1.2) * glow;
	float scan = mod(row, 2.0) < 1.0 ? 1.0 : 0.55;
	float roll = step(0.94, fract(local.y / 40.0 - t * 0.6));
	vec3 col = mix(c.rgb, holo * scan + holo_color.rgb * roll * 0.8, amount);
	COLOR = vec4(col, c.a * mix(1.0, 0.78 + roll * 0.2, amount));
}
