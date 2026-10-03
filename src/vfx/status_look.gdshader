shader_type canvas_item;
// Beyond's unit status look: one shader, every status, blended by StatusLook.
// Works on the unit's placeholder drawing and on its sprite (use_parent_material).
// Coordinates are the node's local pixels with the feet at y = 0, so cracks,
// glitch rows and the banish sink line stay put while the sprite animates.

uniform float grey : hint_range(0.0, 1.0) = 0.0;       // petrify: drain colour…
uniform float crack : hint_range(0.0, 1.0) = 0.0;      // …and craze it like stone
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amt : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed = 0.0;                       // tint breathes (Hz)
uniform float pulse_amt : hint_range(0.0, 1.0) = 0.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;    // brightness jitter (burning, shocked)
uniform float heat : hint_range(0.0, 1.0) = 0.0;       // rising ember bands
uniform float glitch : hint_range(0.0, 1.0) = 0.0;     // row tears + RGB split (short circuit)
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;   // eaten away with a glowing edge (fading)
uniform float frost : hint_range(0.0, 1.0) = 0.0;      // cold sheen + sparkles (stop)
uniform float scan : hint_range(0.0, 1.0) = 0.0;       // hologram scanlines
uniform float shimmer : hint_range(0.0, 1.0) = 0.0;    // cloaked ripple (hidden)
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;
uniform float darken : hint_range(0.0, 1.0) = 0.0;
uniform float sink_px = 0.0;                           // banish: pulled down through the floor

varying vec2 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Distance to the nearest cell border of a jittered grid: thin lines = cracks.
float crackle(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + vec2(hash(i + o), hash(i + o + 17.0)) - f;
			float d = dot(c, c);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return sqrt(d2) - sqrt(d1);
}

void vertex() {
	local = VERTEX;
	VERTEX.y += sink_px;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// Glitch: whole rows jump sideways in bursts.
	float burst = step(1.0 - glitch * 0.6, hash(vec2(floor(t * 14.0), 3.0)));
	float row = floor(local.y / 3.0);
	float shift = (hash(vec2(row, floor(t * 14.0))) - 0.5) * 6.0 * glitch * burst;
	uv.x += shift * TEXTURE_PIXEL_SIZE.x;
	vec4 c = texture(TEXTURE, uv) * COLOR;
	if (glitch > 0.0) {
		float split = (1.5 + 2.0 * burst) * glitch * TEXTURE_PIXEL_SIZE.x;
		c.r = texture(TEXTURE, uv + vec2(split, 0.0)).r * COLOR.r;
		c.b = texture(TEXTURE, uv - vec2(split, 0.0)).b * COLOR.b;
	}
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Tint, breathing with the pulse.
	float amt = tint_amt * (1.0 - pulse_amt + pulse_amt * (0.5 + 0.5 * sin(t * pulse_speed * 6.2831)));
	c.rgb = mix(c.rgb, tint.rgb * (0.35 + lum * 1.3), clamp(amt, 0.0, 1.0));
	// Stone: grey, slightly cool, with crack lines that grow with `crack`.
	vec3 stone = vec3(0.55, 0.56, 0.6) * (0.35 + lum * 0.9);
	c.rgb = mix(c.rgb, stone, grey);
	if (crack > 0.0) {
		float k = crackle(local / 7.0);
		float line = 1.0 - smoothstep(0.02, 0.07 + 0.05 * crack, k);
		c.rgb *= 1.0 - line * 0.55 * crack;
	}
	// Frost: icy sheen and the odd glint.
	if (frost > 0.0) {
		c.rgb = mix(c.rgb, vec3(0.65, 0.9, 1.1) * (0.4 + lum), frost * 0.45);
		float glint = step(0.985, hash(floor(local / 2.0) + floor(t * 3.0)));
		c.rgb += vec3(1.4, 1.8, 2.0) * glint * frost;
	}
	// Fire: jittery brightness and bands of heat climbing the body.
	if (flicker > 0.0) {
		c.rgb *= 1.0 + flicker * 0.3 * (hash(vec2(floor(t * 18.0), 1.0)) - 0.5) * 2.0;
	}
	if (heat > 0.0) {
		float band = 0.5 + 0.5 * sin(local.y * 0.35 + t * 9.0 + noise(local * 0.2 + t) * 3.0);
		c.rgb += vec3(1.6, 0.55, 0.12) * heat * 0.35 * band * c.a;
	}
	if (scan > 0.0) {
		c.rgb *= 1.0 - scan * 0.35 * step(0.5, fract(local.y * 0.5 - t * 4.0));
		c.rgb += tint.rgb * scan * 0.12;
	}
	c.rgb *= 1.0 - darken;
	// Dissolve: noise threshold with a hot edge.
	if (dissolve > 0.0) {
		float n = noise(local * 0.22 + vec2(0.0, t * 0.6));
		if (n < dissolve) { discard; }
		c.rgb += tint.rgb * 2.2 * (1.0 - smoothstep(0.0, 0.07, n - dissolve));
	}
	if (shimmer > 0.0) {
		c.a *= 1.0 - shimmer * (0.55 + 0.25 * sin(local.x * 0.25 + local.y * 0.1 + t * 3.0));
	}
	c.a *= alpha_mul;
	// Banish: everything below the floor line is gone.
	if (sink_px > 0.0 && local.y + sink_px > 0.5) { discard; }
	COLOR = c;
}
