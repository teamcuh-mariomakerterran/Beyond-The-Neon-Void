extends Node2D

# CameraManager is an Autoload that manages the main Camera2D
# It handles screen shake and smooth transitions to emphasize combat impact.

@export var shake_intensity: float = 0.0
@export var shake_duration: float = 0.0
@export var zoom_speed: float = 5.0

var target_camera: Camera2D
var default_zoom: Vector2 = Vector2(1, 1)
var target_zoom: Vector2 = Vector2(1, 1)

func _ready() -> void:
	# We wait for the scene to load and find the main camera
	await get_tree().process_frame
	target_camera = get_viewport().get_camera_2d()
	if target_camera:
		default_zoom = target_camera.zoom

func _process(delta: float) -> void:
	if not target_camera:
		return

	# Handle Smooth Zoom
	target_camera.zoom = target_camera.zoom.lerp(target_zoom, delta * zoom_speed)

	# Handle Screen Shake
	if shake_duration > 0:
		shake_duration -= delta
		var offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		target_camera.offset = offset
	else:
		target_camera.offset = Vector2.ZERO
		shake_intensity = 0.0

## Triggers a screen shake effect
func shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration

## Smoothly zooms the camera to a specific level
func set_zoom(zoom_value: float) -> void:
	target_zoom = Vector2(zoom_value, zoom_value)

## Resets zoom to default
func reset_zoom() -> void:
	target_zoom = default_zoom