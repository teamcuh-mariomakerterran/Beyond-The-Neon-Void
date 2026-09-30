extends Node

# VendorSystem.gd - Handles interaction and transactions in the Hub
# Bartender sells alcohol-themed healing items
# Drunken NPC sells weapons and gear

class_name VendorSystem

@export var bartender_inventory: Array[Dictionary] = [
	{"name": "Neon Gin", "price": 50, "effect": "heal_small", "desc": "A sharp, glowing tonic."},
	{"name": "Cyber-Sake", "price": 120, "effect": "heal_medium", "desc": "Traditional brew, digital aftertaste."},
	{"name": "Void Vodka", "price": 300, "effect": "heal_full", "desc": "Erases all pain and memories."}
]

@export var gear_vendor_inventory: Array[Dictionary] = [
	{"name": "Monofilament Blade", "price": 500, "slot": "weapon", "class": "Corporate Enforcer"},
{"name": "Neural Spike", "price": 400, "slot": "weapon", "class": "Hacker"},
	{"name": "Laser Carbine", "price": 600, "slot": "weapon", "class": "Gunslinger"},
	{"name": "Cyber-Deck", "price": 800, "slot": "accessory", "class": "Software Specialist"},
	{"name": "Heavy Plating", "price": 300, "slot": "armor", "class": "Tank"}
]

func purchase_item(item_index: int, vendor_type: String, target_unit: Unit = null) -> bool:
	var inventory = _get_inventory(vendor_type)
	var item_data = inventory[item_index]
	
	if CampaignManager.credits < item_data["price"]:
		return false
		
	if vendor_type == "gear" and target_unit:
		if item_data.has("class") and item_data["class"] != target_unit.class_name:
			return false 
			
	CampaignManager.credits -= item_data["price"]
	
	if target_unit and item_data.has("slot"):
		# Load the actual ItemResource based on the inventory name
		var item_res = load("res://Items/" + item_data["name"] + ".tres") 
		if item_res:
			var equip_manager = target_unit.get_node("EquipmentManager")
			equip_manager.equip_item(item_res)
	
	UIManager.update_credits_display()
	return true

func _get_inventory(type: String) -> Array:
	if type == "alcohol":
		return bartender_inventory
	return gear_vendor_inventory