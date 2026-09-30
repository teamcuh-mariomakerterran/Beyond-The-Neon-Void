class_name EquipmentManager
extends Node
## Equipment slots for a Unit. Holds ItemInstance dictionaries:
##   {"uid": String, "item_id": String, "level": int, "xp": int, "potential": float, "bonus": {stat: int}}
## Specialty weapons (class or character specialty) get +15% weapon stats and
## +25% ability XP (see ProgressionSystem).

signal equipment_changed

const SLOTS := ["weapon", "armor", "accessory", "trinket"]
const SPECIALTY_STAT_MULT := 1.15
const SPECIALTY_XP_MULT := 1.25

var slots: Dictionary = {"weapon": {}, "armor": {}, "accessory": {}, "trinket": {}}
var specialties: Array[String] = []


func equip_instance(instance: Dictionary) -> Dictionary:
	var item := ContentDB.get_item(instance.get("item_id", ""))
	if item == null or not item.is_equipment():
		return {}
	var slot := item.slot_name()
	var old: Dictionary = slots.get(slot, {})
	slots[slot] = instance
	equipment_changed.emit()
	return old


func unequip(slot: String) -> Dictionary:
	var old: Dictionary = slots.get(slot, {})
	slots[slot] = {}
	equipment_changed.emit()
	return old


func get_item(slot: String) -> ItemResource:
	var inst: Dictionary = slots.get(slot, {})
	return ContentDB.get_item(inst.get("item_id", "")) if not inst.is_empty() else null


func weapon_type() -> String:
	var w := get_item("weapon")
	return w.equip_type if w else ""


func weapon_range() -> int:
	var w := get_item("weapon")
	return w.weapon_range if w else 1


func is_specialized() -> bool:
	var t := weapon_type()
	return t != "" and specialties.has(t)


## Sum of every equipped item's bonuses: {stat: int}.
func get_total_bonus() -> Dictionary:
	var total := {}
	for slot: String in SLOTS:
		var inst: Dictionary = slots.get(slot, {})
		if inst.is_empty():
			continue
		var item := ContentDB.get_item(inst.get("item_id", ""))
		if item == null:
			continue
		var lvl := int(inst.get("level", 1))
		var potential := float(inst.get("potential", 1.0))
		var mult := SPECIALTY_STAT_MULT if slot == "weapon" and is_specialized() else 1.0
		var keys := item.stat_modifiers.keys()
		for k: Variant in item.stat_growth.keys():
			if not keys.has(k):
				keys.append(k)
		for stat: Variant in keys:
			var v := roundi(item.get_stat_bonus(stat, lvl) * potential * mult)
			total[stat] = int(total.get(stat, 0)) + v
		var bonus: Dictionary = inst.get("bonus", {})
		for stat: Variant in bonus:
			total[stat] = int(total.get(stat, 0)) + int(bonus[stat])
	return total


func get_total_stat_bonus(stat_name: String) -> int:
	return int(get_total_bonus().get(stat_name, 0))
