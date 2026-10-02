class_name VFXLight
extends VFXPart
## Short PointLight2D pulse so effects light the floor and units around them.
## Keys: color, energy, radius (px), attack, power (decay curve), flicker.

var light: PointLight2D


func _setup() -> void:
	light = PointLight2D.new()
	light.name = "Light"
	light.texture = VFX.texture("light")
	light.color = col("color", "$main")
	light.texture_scale = num("radius", 120.0) * 2.0 / float(light.texture.get_width())
	light.blend_mode = Light2D.BLEND_MODE_SUB if str(d.get("mode", "add")) == "sub" else Light2D.BLEND_MODE_ADD
	light.energy = 0.0
	light.range_z_min = -4096
	light.range_z_max = 4096
	add_child(light)


func _update(_lt: float, _dt: float) -> void:
	var e := envelope(num("attack", 0.03), num("power", 1.8))
	var fl := num("flicker", 0.0)
	if fl > 0.0:
		e *= 1.0 - fl * rng.randf()
	light.energy = num("energy", 1.6) * e
	light.enabled = light.energy > 0.01
