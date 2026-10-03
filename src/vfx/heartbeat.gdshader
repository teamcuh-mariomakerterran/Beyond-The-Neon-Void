shader_type canvas_item;
// Low-HP warning: a red vignette that beats like a heart (lub-dub, rest).

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float bpm = 72.0;
uniform vec4 color : source_color = vec4(0.9, 0.05, 0.2, 1.0);

void fragment() {
	float beat_t = fract(TIME * bpm / 60.0);
	float lub = exp(-pow((beat_t - 0.05) * 18.0, 2.0));
	float dub = exp(-pow((beat_t - 0.25) * 18.0, 2.0)) * 0.7;
	float beat = 0.45 + 0.55 * max(lub, dub);
	vec2 c = UV - 0.5;
	float edge = smoothstep(0.25, 0.75, length(c * vec2(1.0, 1.25)));
	COLOR = vec4(color.rgb, edge * beat * intensity * 0.65);
}
