shader_type canvas_item;
// TEMPLATE: BTNV body/sprite shader. Copy to src/vfx/<name>.gdshader and rename the uniforms.
// Conventions (see SKILL.md):
//  * Modulate comes from vertex() in a varying. Never write texture(TEXTURE, uv) * COLOR in
//    fragment(): Godot 4's fragment COLOR already includes the texture (known-gaps #34).
//  * Coordinates are node-local pixels with the feet at y = 0 (`local`), so patterns stay put
//    while the sprite animates and frames change size. Same convention as status_look.gdshader.
//  * Stepped time (`fps`) matches pixel-art animation; continuous TIME looks "floaty" on 64x32 art.
//  * Every effect has an amount uniform that defaults to 0, so neutral = identical to the art
//    (check with scripts/gd/neutral_parity.gd).
//  * Colours: `source_color`; HDR comes from multipliers (`* glow`), so >1 values bloom
//    through the WorldEnvironment glow (hdr_2d on, glow_hdr_threshold 1.0).

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.18, 0.53, 1.0);  // NeonTheme.MAGENTA ff2e88
uniform float glow = 1.8;                                             // HDR multiplier (>1 blooms)
uniform float fps = 12.0;                                             // stepped animation rate

varying vec2 local;
varying vec4 v_mod;

float hash21(vec2 p) {  // integer-ish hash: stable across GPUs for pixel coords
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	local = VERTEX;
	v_mod = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * v_mod;
	float t = floor(TIME * fps) / fps;
	vec2 px = floor(local);                     // whole art pixels: hard edges, no smear
	// Example effect: hard-edged diagonal energy bands crawling up the body.
	float band = step(0.75, fract((px.y + px.x * 0.5) / 6.0 - t * 1.5));
	c.rgb = mix(c.rgb, edge_color.rgb * glow, band * amount * c.a);
	COLOR = c;
}
