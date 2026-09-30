class_name DamageText
extends Label
## Floating combat number: rises, pops, fades. Criticals are bigger and gold.


static func spawn(parent: Node, world_pos: Vector2, text_value: String, color: Color = Color.WHITE, is_critical: bool = false) -> DamageText:
	var dt := DamageText.new()
	parent.add_child(dt)
	dt.setup(world_pos, text_value, color, is_critical)
	return dt


func setup(world_pos: Vector2, text_value: String, color: Color, is_critical: bool) -> void:
	text = text_value
	z_as_relative = false
	z_index = 4090
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 26 if is_critical else 20)
	add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.05))
	add_theme_constant_override("outline_size", 6)
	modulate = Color(1.9, 1.5, 0.4) if is_critical else color
	size = Vector2(120, 30)
	position = world_pos + Vector2(-60, -80) + Vector2(randf_range(-10, 10), 0)
	pivot_offset = size * 0.5
	scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.25, 1.25) if is_critical else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", position.y - 40, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.35)
	t.tween_callback(queue_free)
