extends Node
class_name EquipmentManager

signal equipment_changed

@export var weapon_slot: ItemResource
@export var armor_slot: ItemResource
@export var accessory_slot: ItemResource
@export var trinket_slot: ItemResource

var owner_unit: Unit

func _ready() -> void:
	# Expects to be a child of the Unit node
	var parent = get_parent()
	if parent is Unit:
		owner_unit = parent
	else:
		push_error("EquipmentManager must be a child of a Unit node.")

func equip_item(item: ItemResource) -> bool:
	if not item:
		return false
	
	var slot_to_update: String = ""
	
	# Determine slot based on item category
	match item.category:
		"Weapon":
			slot_to_update = "weapon"
		"Armor":
			slot_to_update = "armor"
		"Accessory":
			slot_to_update = "accessory"
		"Trinket":
			slot_to_update = "trinket"
		_:
			return false
	
	# Perform the swap
	var old_item = _get_slot_value(slot_to_update)
	_set_slot_value(slot_to_update, item)
	
	equipment_changed.emit()
	return true

func unequip_item(slot_name: String) -> ItemResource:
	var item = _get_slot_value(slot_name)
	_set_slot_value(slot_name, null)
	equipment_changed.emit()
	return item

func get_total_stat_bonus(stat_name: String) -> float:
	var total = 0.0
	var slots = [weapon_slot, armor_slot, accessory_slot, trinket_slot]
	
	for item in slots:
		if item != null:
			total += item.stats.get(stat_name, 0.0)
	
	return total

# Internal helpers to handle the slots without exposing raw variables
func _get_slot_value(slot: String) -> ItemResource:
	match slot:
		"weapon":
			return weapon_slot
		"armor":
			return armor_slot
		"accessory":
			return accessory_slot
		"trinket":
			return trinket_slot
	return null

func _set_slot_value(slot: String, item: ItemResource) -> void:
	match slot:
		"weapon":
			weapon_slot = item
		"armor":
			armor_slot = item
		"accessory":
			accessory_slot = item
		"trinket":
			trinket_slot = item