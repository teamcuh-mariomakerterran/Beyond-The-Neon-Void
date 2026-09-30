extends CanvasLayer
## TransitionLayer — full-screen fades with a scanline glitch sweep.
## Builds its own ColorRect so no scene file is needed for the autoload.

var fade_rect: ColorRect
var fade_tween: Tween


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.0, 0.05, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)


func fade_out(duration: float = 0.3) -> Signal:
	return _fade_to(1.0, duration, Tween.EASE_IN)


func fade_in(duration: float = 0.3) -> Signal:
	return _fade_to(0.0, duration, Tween.EASE_OUT)


func _fade_to(alpha: float, duration: float, ease_type: Tween.EaseType) -> Signal:
	if fade_tween:
		fade_tween.kill()
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", alpha, maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	return fade_tween.finished
