shader_type canvas_item;
// Beyond's in-world screen: turns a feed texture into a physical display.
// mode 0 LED billboard (round lit dots), 1 LCD panel (pixel cells),
// 2 CRT (curved glass, scanlines, RGB mask), 3 hologram (translucent, rolling bands).
// Brightness above 1 blooms through the HDR glow, so screens light the street.

uniform int mode = 0;
uniform vec2 cells = vec2(64.0, 32.0);   // resolution of the physical panel
uniform float brightness = 1.6;
uniform float seed = 0.0;
uniform float power : hint_range(0.0, 1.0) = 1.0;  // 0 = off, animates on boot
uniform vec4 tint : source_color = vec4(1.0);

float hash(float n) { return fract(sin(n * 91.3458 + seed * 17.13) * 47453.5453); }

void fragment() {
	vec2 uv = UV;
	float t = TIME + seed * 13.0;
	// Rare tear: one band of rows slides sideways.
	float tear_on = step(0.985, hash(floor(t * 6.0)));
	float band = step(abs(uv.y - hash(floor(t * 6.0) + 3.0)), 0.06);
	uv.x += tear_on * band * 0.05;
	float alpha = 1.0;
	vec3 col;
	if (mode == 2) {
		vec2 c = uv * 2.0 - 1.0;
		c *= 1.0 + 0.09 * dot(c.yx, c.yx);
		uv = c * 0.5 + 0.5;
		uv = clamp(uv, vec2(0.0), vec2(1.0));
	}
	vec2 grid = uv * cells;
	vec2 cell = floor(grid);
	vec2 f = fract(grid);
	vec2 cuv = (cell + 0.5) / cells;
	if (mode == 0) {
		col = texture(TEXTURE, cuv).rgb;
		float d = length(f - 0.5);
		float led = smoothstep(0.48, 0.22, d);
		col = col * led * brightness + col * 0.06;
	} else if (mode == 1) {
		col = texture(TEXTURE, cuv).rgb;
		float gap = step(0.1, f.x) * step(0.1, f.y);
		col *= (0.7 + 0.3 * gap) * brightness * 0.85;
	} else if (mode == 2) {
		col = texture(TEXTURE, uv).rgb;
		col *= 0.72 + 0.28 * sin(uv.y * cells.y * 6.2831);
		float m = mod(floor(grid.x * 3.0), 3.0);
		col *= vec3(m == 0.0 ? 1.15 : 0.85, m == 1.0 ? 1.15 : 0.85, m == 2.0 ? 1.15 : 0.85);
		col *= brightness;
		vec2 v = uv * (1.0 - uv);
		col *= pow(max(v.x * v.y * 16.0, 0.0), 0.25);  // dark curved edges
	} else {
		col = texture(TEXTURE, uv).rgb * brightness;
		col *= 0.75 + 0.25 * sin(uv.y * 160.0 - t * 9.0);
		col += vec3(0.1, 0.5, 0.6) * 0.15 * step(0.97, fract(uv.y * 3.0 - t * 0.7));
		alpha = 0.6 + 0.15 * hash(floor(t * 24.0));
	}
	col *= 0.93 + 0.07 * hash(floor(t * 30.0));
	// Boot: a bright line opens into the picture.
	float open = smoothstep(0.0, 1.0, power);
	float line = 1.0 - smoothstep(0.0, max(open * 0.5, 0.004), abs(UV.y - 0.5));
	col = mix(vec3(0.0), col, step(abs(UV.y - 0.5), open * 0.5)) + vec3(1.5) * line * (1.0 - open);
	COLOR = vec4(col * tint.rgb, alpha * max(open, 0.2));
}
