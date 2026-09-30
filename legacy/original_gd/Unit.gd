extends CharacterBody2D

class_name Unit

signal health_changed(current_hp, max_hp)
signal ap_changed(current_ap, max_ap)
signal unit_died

@export var stats: UnitStats
@export var behavior: AIBehavior
@export var class_resource: ClassResource

var current_hp: int
var current_ap: int
var active_effects: Array[StatusEffect] = []
var abilities: Array[Ability] = []
var is_moving: bool = false

@onready var hud = $UnitHUD
@onready var ray = $RayCast2D
@onready var equipment_manager = $EquipmentManager

func _ready() -> void:
	if stats:
		current_hp = stats.max_hp
		current_ap = stats.max_ap
		_update_hud()
	
	if hud:
		hud.setup_bars(current_hp, stats.max_hp if stats else 100)
	
	if equipment_manager:
		equipment_manager.equipment_changed.connect(_on_equipment_changed)

func _on_equipment_changed() -> void:
	refresh_effective_stats()
	_update_hud()

func refresh_effective_stats() -> void:
	if stats:
		stats.calculate_final_stats()
		_update_hud()

func _update_hud() -> void:
	health_changed.emit(current_hp, stats.max_hp if stats else 0)
	ap_changed.emit(current_ap, stats.max_ap if stats else 0)
	if hud:
		hud.update_bars(current_hp, current_ap)

func spend_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		_update_hud()
		return true
	return false

func take_damage(amount: int, cover_value: int = 0) -> int:
	var final_damage = max(1, amount - cover_value)
	current_hp -= final_damage
	_update_hud()
	
	if current_hp <= 0:
		die()
	
return final_damage

func die() -> void:
	set_physics_process(false)
	# Trigger death animation or sound via signals
	CombatManager.handle_unit_death(self)

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, stats.max_hp if stats else 100)
	_update_hud()

func apply_status_effect(effect: StatusEffect) -> void:
	active_effects.append(effect)
	_update_hud()

func play_animation(anim_name: String) -> void:
	# Assuming Unit has an AnimationPlayer node
	var ap = get_node_or_null("AnimationPlayer")
	if ap:
		ap.play(anim_name)

func hit_flash() -> void:
	# Visual feedback for taking damage
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		sprite.modulate = Color.RED
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

