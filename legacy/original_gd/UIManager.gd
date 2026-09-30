extends Node

@onready var action_menu = $CanvasLayer/ActionMenu
@onready var unit_info_panel = $CanvasLayer/UnitInfoPanel
@onready var combat_log = $CanvasLayer/CombatLog
@onready var vendor_menu = $CanvasLayer/VendorMenu
@onready var turn_label = $CanvasLayer/TurnLabel
@onready var end_turn_button = $CanvasLayer/EndTurnButton

var current_selected_unit: Unit = null

func _ready() -> void:
	action_menu.hide()
	unit_info_panel.hide()
	vendor_menu.hide()
	turn_label.text = "Preparing Battle..."
	end_turn_button.hide()
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	# Initialize turn state
	set_turn_phase(false, "Battle Start")

func update_selected_unit(unit: Unit) -> void:
	current_selected_unit = unit
	if unit:
		show_unit_info(unit)
		show_action_menu(unit)
	else:
		hide_action_menu()
		unit_info_panel.hide()

func equip_item_to_unit(unit: Unit, item: ItemResource) -> void:
	if unit and unit.has_node("EquipmentManager"):
		var eq_manager = unit.get_node("EquipmentManager")
		eq_manager.equip_item(item)
		# Trigger a UI refresh for stats
		show_unit_info(unit)

func show_unit_info(unit: Unit) -> void:
	unit_info_panel.show()
	unit_info_panel.get_node("NameLabel").text = unit.unit_name
	unit_info_panel.get_node("ClassLabel").text = unit.class_resource.class_name
	unit_info_panel.get_node("HPLabel").text = "HP: %d/%d" % [unit.current_hp, unit.max_hp]
	if unit.stats:
		var stats_text = "STR: %d | AGI: %d | INT: %d | VIT: %d" % [
			unit.stats.strength, unit.stats.agility, unit.stats.intelligence, unit.stats.vitality
		]
		unit_info_panel.get_node("StatsLabel").text = stats_text

func show_action_menu(unit: Unit) -> void:
	action_menu.show()
	var ability_list = unit.class_resource.abilities
	var container = action_menu.get_node("VBoxContainer")
	
	for child in container.get_children():
		child.queue_free()
		
	var move_btn = Button.new()
	move_btn.text = "Move"
	move_btn.disabled = (unit.current_ap <= 0)
	move_btn.pressed.connect(_on_move_selected)
	container.add_child(move_btn)
	
	var wait_btn = Button.new()
	wait_btn.text = "Wait"
	wait_btn.pressed.connect(_on_wait_selected)
	container.add_child(wait_btn)
	
	for ability in ability_list:
		var btn = Button.new()
		btn.text = "%s (%d AP)" % [ability.name, ability.ap_cost]
		btn.disabled = (unit.current_ap < ability.ap_cost)
		btn.pressed.connect(_on_ability_selected.bind(ability))
		container.add_child(btn)

func hide_action_menu() -> void:
	action_menu.hide()

func add_log_message(message: String) -> void:
	var label = Label.new()
	label.text = message
	var log_container = combat_log.get_node("VBoxContainer")
	log_container.add_child(label)
	
	if log_container.get_child_count() > 15:
		var old_msg = log_container.get_child(0)
		log_container.remove_child(old_msg)
		old_msg.queue_free()

func update_unit_stats(unit: Unit) -> void:
	# This is a fallback method if a specific stats_label exists
	var stats_label = get_node_or_null("StatsLabel")
	if stats_label:
		stats_label.text = "Unit: %s\nHP: %d/%d\nMP: %d/%d" % [
			unit.unit_name, 
			unit.current_hp, 
			unit.max_hp, 
			unit.current_mp, 
			unit.max_mp
		]

func show_notification(text: String) -> void:
	var notify = Label.new()
	notify.text = text
	notify.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(notify)
	
	var tween = create_tween()
	tween.tween_property(notify, "position", notify.position + Vector2(0, -100), 1.0)
	tween.parallel().tween_property(notify, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func(): notify.queue_free())

func open_vendor(items: Array) -> void:
	vendor_menu.show()
	var container = vendor_menu.get_node("VBoxContainer")
	for child in container.get_children():
		child.queue_free()

	for item in items:
		var item_row = VendorItemRow.instantiate()
		item_row.setup(item)
		# Connect the buy signal to the VendorSystem
		item_row.buy_pressed.connect(func(): VendorSystem.buy_item(item))
		container.add_child(item_row)

func close_vendor() -> void:
	vendor_menu.hide()

func show_combat_log(message: String) -> void:
	var log_entry = Label.new()
	log_entry.text = message
	log_entry.modulate = Color(1, 1, 1, 1)
	combat_log_panel.add_child(log_entry)
	
	var tween = create_tween()
	tween.tween_property(log_entry, "modulate:a", 0.0, 3.0).set_delay(2.0)
	tween.finished.connect(func(): log_entry.queue_free())

func update_ap_display(current_ap: int, max_ap: int) -> void:
	# Updates the AP counter in the UI to reflect remaining action points
	var ap_label = get_node_or_null("CanvasLayer/APLabel")
	if ap_label:
		ap_label.text = "AP: %d / %d" % [current_ap, max_ap]

func update_player_stats(stats: PlayerStats) -> void:
	# Legacy support for full player stat block
	var hp_label = get_node_or_null("CanvasLayer/HPLabel")
	var ap_label = get_node_or_null("CanvasLayer/APLabel")
	if hp_label: hp_label.text = "HP: %d/%d" % [stats.current_hp, stats.max_hp]
	if ap_label: ap_label.text = "AP: %d/%d" % [stats.current_ap, stats.max_ap]

func set_turn_phase(is_player_turn: bool, phase_name: String) -> void:
	turn_label.text = phase_name
	end_turn_button.visible = is_player_turn
	# Ensure the turn label is clearly visible and centered
	turn_label.modulate = Color(1, 1, 1, 1)
	show_notification(phase_name)

func _on_end_turn_pressed() -> void:
	CombatManager.end_turn()