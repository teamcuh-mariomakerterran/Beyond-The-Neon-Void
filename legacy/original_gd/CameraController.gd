extends Camera2D

@export var follow_target: Node2D
@export var lerp_speed: float = 5.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0

var target_zoom: float = 1.0

func _ready() -> void:
	target_zoom = zoom.x

func _process(delta: float) -> void:
	if follow_target:
		# Smoothly interpolate position toward the target
		global_position = global_position.lerp(follow_target.global_position, lerp_speed * delta)
	
	# Smoothly interpolate zoom level
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), zoom_speed)

func _unhandled_input(event: InputEvent) -> void:
	# Handle zooming via mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom + 0.1, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom - 0.1, min_zoom, max_zoom)

func focus_on_target(target: Node2D, duration: float = 1.0) -> void:
	# Utility to snap or glide to a specific point of interest (e.g. a battle start)
	var tween = create_tween()
	tween.tween_property(self, "global_position", target.global_position, duration).set_trans(Tween.TRANS_SINE)
	tween.set_parallel(true)
	tween.tween_property(self, "zoom", Vector2(1.2, 1.2), duration)