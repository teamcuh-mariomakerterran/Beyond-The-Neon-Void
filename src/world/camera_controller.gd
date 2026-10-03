class_name CameraController
extends Camera2D
## Tactics camera: WASD / arrow pan, right- or middle-drag pan, wheel zoom,
## smooth follow of the active unit, and bounds so you can't lose the map.

@export var follow_target: Node2D
@export var lerp_speed: float = 6.0
@export var pan_speed: float = 700.0
@export var min_zoom: float = 0.6
@export var max_zoom: float = 2.4

var target_zoom: float = 1.3
## Zoom punch from Cues (1 = none). Applied on top of the player's zoom.
var punch: float = 1.0
var bounds: Rect2 = Rect2(-2000, -2000, 4000, 4000)
var _dragging: bool = false
var _manual_until: float = 0.0


func _ready() -> void:
	zoom = Vector2(target_zoom, target_zoom)


func _process(delta: float) -> void:
	var pan := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if pan != Vector2.ZERO:
		global_position += pan * pan_speed * delta / zoom.x
		_manual_until = Time.get_ticks_msec() / 1000.0 + 2.0
	elif follow_target and is_instance_valid(follow_target) and Time.get_ticks_msec() / 1000.0 > _manual_until:
		global_position = global_position.lerp(follow_target.global_position, clampf(lerp_speed * delta, 0.0, 1.0))
	global_position = global_position.clamp(bounds.position, bounds.end)
	var real := delta / maxf(Engine.time_scale, 0.001)  # punches keep pace through slow-mo
	var goal := target_zoom * punch
	zoom = zoom.lerp(Vector2(goal, goal), clampf(real * (24.0 if punch != 1.0 else 10.0), 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom + 0.12, min_zoom, max_zoom)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom - 0.12, min_zoom, max_zoom)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		global_position -= (event as InputEventMouseMotion).relative / zoom.x
		_manual_until = Time.get_ticks_msec() / 1000.0 + 3.0


## Glide to a point of interest (battle start, big ability).
func focus_on(point: Vector2, duration: float = 0.6) -> void:
	_manual_until = Time.get_ticks_msec() / 1000.0 + duration
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "global_position", point, duration)
