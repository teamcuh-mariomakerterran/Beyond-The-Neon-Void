extends CanvasLayer

@onready var fade_rect: ColorRect = $ColorRect
var fade_tween: Tween

func _ready() -> void:
	# Ensure the overlay is invisible and covers the screen
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func fade_out(duration: float = 0.5) -> Signal:
	# Fade to black
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return fade_tween.finished

func fade_in(duration: float = 0.5) -> Signal:
		# Fade back to transparent
	if fade_tween:
		fade_tween.kill()
		
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return fade_tween.finished