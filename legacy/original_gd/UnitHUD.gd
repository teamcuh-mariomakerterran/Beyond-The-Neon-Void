extends PanelContainer

class_name UnitHUD

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $VBoxContainer/HPBar
@onready var mp_bar: ProgressBar = $VBoxContainer/MPBar
@onready var class_label: Label = $VBoxContainer/ClassLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var ap_label: Label = $VBoxContainer/APLabel
@onready var status_container: HBoxContainer = $VBoxContainer/StatusIcons
@onready var abilities_container: HBoxContainer = $VBoxContainer/AbilitiesContainer

func update_status_icons(effects: Array):
	for child in status_container.get_children():
		child.queue_free()
	for effect in effects:
		var icon = TextureRect.new()
		icon.texture = effect.icon
		icon.expand_flags_horizontal = Control.SIZE_SHRINK_CENTER
		status_container.add_child(icon)



func _ready() -> void:
	hide()
	var unit = get_parent() as Unit
	if unit:
		unit.damaged.connect(_on_unit_damaged)

func _on_unit_damaged(amount: int) -> void:
	var unit = get_parent() as Unit
	if unit:
		# Smoothly animate the HP bar reduction
		var tween = create_tween()
		tween.tween_property(hp_bar, "value", unit.current_hp, 0.3).set_trans(Tween.TRANS_CUBIC)

func _process(_delta: float) -> void:
	# Ensure the HUD always faces the camera or stays anchored if needed
	# In a 2D context, this usually means updating position to follow the unit
	var unit = get_parent() as Unit
	if unit and unit is Node2D:
		position = unit.position + Vector2(0, -40) # Offset above head

func update_unit_data(unit: Unit) -> void:
	if unit.has_method("get_active_status_effects"):
		update_status_icons(unit.get_active_status_effects())
	
	_update_abilities(unit)
	
	name_label.text = unit.unit_name
	class_label.text = unit.class_resource.class_name
	
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.current_hp
	
	mp_bar.max_value = unit.max_mp
	mp_bar.value = unit.current_mp

	if unit.stats:
		stats_label.text = "STR: %s | AGI: %s | INT: %s | VIT: %s" % [
			str(unit.stats.strength), 
			str(unit.stats.agility), 
			str(unit.stats.intelligence), 
			str(unit.stats.vitality)
		]
	
	ap_label.text = "AP: %s / %s" % [unit.current_ap, unit.max_ap]
	
	# Color health bar based on percentage
	var health_pct = unit.current_hp / float(unit.max_hp)
	if health_pct < 0.3:
		hp_bar.modulate = Color.RED
	elif health_pct < 0.6:
		hp_bar.modulate = Color.YELLOW
	else:
		hp_bar.modulate = Color.WHITE
		
	show()

func _update_abilities(unit: Unit) -> void:
	for child in abilities_container.get_children():
		child.queue_free()
		
	for ability in unit.abilities:
		var btn = Button.new()
		btn.text = ability.name
		btn.pressed.connect(_on_ability_selected.bind(ability))
		abilities_container.add_child(btn)

func _on_ability_selected(ability: Ability) -> void:
	# Inform the CombatManager that this ability has been chosen
	# This triggers the transition to the Targeting state
	CombatManager.select_ability(ability)
	# visually indicate selection
	ability_buttons_highlight(ability.name)

func ability_buttons_highlight(ability_name: String) -> void:
	for btn in ability_buttons:
		btn.modulate = Color.WHITE if btn.text == ability_name else Color.GRAY



func _on_target_confirmed(target_pos: Vector2i) -> void:
	# This is called by the manager to signal UI updates
	# like playing a sound or showing a target marker
	pass


func _on_ap_changed(new_ap: int) -> void:
	$APLabel.text = "AP: " + str(new_ap)

func _on_hp_changed(new_hp: int) -> void:
	$HPLabel.text = "HP: " + str(new_hp)


func hide_hud() -> void:
	# Use a tween for smooth sliding out if desired, otherwise simple hide
	hide()