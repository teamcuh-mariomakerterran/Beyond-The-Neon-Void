class_name Glitch
extends CanvasLayer
## One-shot full-screen glitch (glitch.gdshader): Glitch.play(host, seconds).
## Used when the Lying HUD drops, and free for cutscenes / cues.

static func play(host: Node, dur: float = 0.8, peak: float = 1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var g := Glitch.new()
	g.layer = 95
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://src/vfx/glitch.gdshader")
	m.set_shader_parameter("seed", randf() * 100.0)
	r.material = m
	g.add_child(r)
	host.add_child(g)
	var t := g.create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("strength", v), 0.0, peak, dur * 0.25)
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("strength", v), peak, 0.0, dur * 0.75)
	t.tween_callback(g.queue_free)
