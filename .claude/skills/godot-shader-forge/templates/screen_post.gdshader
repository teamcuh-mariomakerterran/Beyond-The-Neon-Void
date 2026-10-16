shader_type canvas_item;
render_mode unshaded;
// TEMPLATE: screen-reading overlay (post / shockwave / glitch family). Put it on a
// full-rect ColorRect in a CanvasLayer BELOW the HUD (HD2DPost sits on layer 5; HUD layers
// are >= 10). For non-full-screen shapes, copy VFXScreen's approach (UV-space mask).
// * filter_linear_mipmap is required for textureLod blur; without it LOD is ignored.
// * `intensity` is the master knob: Cues/VFX tween it, and reduce_motion scales it down.
// * Output alpha = how much of the effect covers the screen; 0 must be a perfect no-op.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float aberration = 0.004;      // RGB split in UV
uniform vec4 tint : source_color = vec4(0.25, 1.0, 1.4, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - 0.5;
	float k = aberration * intensity;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * k).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * k).b;
	col = mix(col, col * tint.rgb, 0.25 * intensity);
	COLOR = vec4(col, intensity);
}
