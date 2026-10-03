class_name DamageText
extends Label
## Floating combat number with weight:
##   damage — pops in, arcs out to one side and drops; size grows with how big
##            the hit was (share of max HP). Criticals: gold, bigger, shake.
##   heal   — "+N" floats straight up, soft and green.
##   miss   — slides sideways and fades.
## Several numbers on the same unit in a row stack instead of overlapping.

static var _stack: Dictionary = {}  # unit position key -> [count, time]


static func spawn(parent: Node, world_pos: Vector2, text_value: String, color: Color = Color.WHITE, is_critical: bool = false, weight: float = 0.3) -> DamageText:
	var dt := DamageText.new()
	parent.add_child(dt)
	dt.setup(world_pos, text_value, color, is_critical, weight)
	return dt


func setup(world_pos: Vector2, text_value: String, color: Color, is_critical: bool, weight: float = 0.3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var k := "%d,%d" % [int(world_pos.x), int(world_pos.y)]
	var st: Array = _stack.get(k, [0, 0.0])
	var n: int = st[0] + 1 if now - float(st[1]) < 0.6 else 0
	_stack[k] = [n, now]
	var heal := text_value.begins_with("+")
	var miss := text_value == "MISS"
	text = text_value + ("!" if is_critical else "")
	z_as_relative = false
	z_index = 4090
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fs := int(lerpf(18.0, 34.0, clampf(weight, 0.0, 1.0)))
	add_theme_font_size_override("font_size", fs + (8 if is_critical else 0))
	add_theme_font_override("font", NeonTheme.bold())
	add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.05))
	add_theme_constant_override("outline_size", 7)
	modulate = Color(2.2, 1.7, 0.4) if is_critical else color
	size = Vector2(160, 44)
	pivot_offset = size * 0.5
	position = world_pos + Vector2(-80, -86 - n * 22)
	scale = Vector2(0.3, 0.3)
	var t := create_tween()
	if miss:
		t.tween_property(self, "scale", Vector2.ONE, 0.1)
		t.tween_property(self, "position:x", position.x + 36.0 * (1 if randf() < 0.5 else -1), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.15)
	elif heal:
		t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "position:y", position.y - 46, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.4)
	else:
		# Pop, then a little arc: out to the side, up, and a short fall.
		var side := randf_range(18.0, 36.0) * (1 if randf() < 0.5 else -1)
		var pop := Vector2(1.45, 1.45) if is_critical else Vector2(1.15, 1.15)
		t.tween_property(self, "scale", pop, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "scale", Vector2.ONE * (1.15 if is_critical else 1.0), 0.12)
		t.parallel().tween_property(self, "position:x", position.x + side, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "position:y", position.y - 34, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "position:y", position.y - 18, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.12)
		if is_critical:
			var wob := create_tween().set_loops(4)
			wob.tween_property(self, "rotation", 0.09, 0.04)
			wob.tween_property(self, "rotation", -0.09, 0.04)
	t.tween_callback(queue_free)
