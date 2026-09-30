extends Label

func _ready():
	# Simple float up and fade out animation
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 50, 0.8).set_trans(Tween.TRANS_OUT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(queue_free)

func setup(text_value: String, is_critical: bool = false):
	text = text_value
	if is_critical:
		modulate = Color.GOLD
		scale = Vector2(1.5, 1.5)
	elif text_value == "MISS":
		modulate = Color.SAGE # Using a distinct color for misses
		scale = Vector2(1.2, 1.2)
	else:
		modulate = Color.WHITE
	
	# Ensure text is centered and visible
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Ensure text is centered and visible
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER