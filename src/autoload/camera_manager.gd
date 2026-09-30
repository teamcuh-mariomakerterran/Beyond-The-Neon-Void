extends Node
## CameraManager — screen shake and zoom on whatever Camera2D is current.
## Listens to EventBus.camera_shake so abilities never need a camera reference.

@export var zoom_speed: float = 6.0

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var target_zoom: Vector2 = Vector2.ONE
var _zoom_override: bool = false


func _ready() -> void:
	EventBus.camera_shake.connect(shake)


func _camera() -> Camera2D:
	var vp := get_viewport()
	return vp.get_camera_2d() if vp else null


func _process(delta: float) -> void:
	var cam := _camera()
	if cam == null:
		return
	if _zoom_override:
		cam.zoom = cam.zoom.lerp(target_zoom, clampf(delta * zoom_speed, 0.0, 1.0))
	if shake_duration > 0.0:
		shake_duration -= delta
		cam.offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	else:
		cam.offset = Vector2.ZERO
		shake_intensity = 0.0


func shake(intensity: float, duration: float) -> void:
	if SettingsFlags.reduce_motion:
		return
	shake_intensity = maxf(shake_intensity, intensity)
	shake_duration = maxf(shake_duration, duration)


func set_zoom(zoom_value: float) -> void:
	target_zoom = Vector2(zoom_value, zoom_value)
	_zoom_override = true


func reset_zoom() -> void:
	_zoom_override = false
