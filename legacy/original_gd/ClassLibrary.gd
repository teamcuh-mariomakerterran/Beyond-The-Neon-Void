extends Node

# ClassLibrary: A centralized database for the 20 cyberpunk classes.
# Each class is defined here as a set of base stats and roles.
# In a full production, these would be separate .tres files, but for 
# the prototype, we initialize them here.

class ClassData:
	var class_name: String
	var role: String # Melee, Ranged, Support, Utility, Tank
	var base_hp: int
	var base_mp: int
	var base_attack: int
	var base_defense: int
	var special_ability: String
	var stat_multipliers: Dictionary = {
		"attack": 1.0,
		"defense": 1.0,
		"agility": 1.0,
		"intellect": 1.0
	}

var library: Dictionary = {}
var role_map: Dictionary = {} # Maps role (e.g. "Tank") to list of class names

func _ready():
	initialize_classes()

func initialize_classes():
	var classes = [
		# BASE CLASSES
		["Digital Healer", "Support", 80, 120, 10, 20, "Nanite Mend"],
		["Hacker", "Support", 70, 150, 15, 15, "System Override"],
		["Digital Summoner", "Utility", 90, 130, 20, 15, "Hologram Burst"],
		["Droid Master", "Utility", 100, 100, 25, 25, "Build Droid"],
		["Smuggler", "Utility", 85, 90, 30, 20, "Shadow Step"],
		["Gunslinger", "Ranged", 90, 80, 45, 15, "Plasma Burst"],
		["Cyber-Sniper", "Ranged", 70, 70, 60, 10, "Neural Link Shot"],
		["Net-Runner", "Ranged", 80, 140, 35, 15, "Data Spike"],
		["Corporate Enforcer", "Melee", 120, 50, 35, 40, "Boardroom Sweep"],
		["Street Samurai", "Melee", 110, 60, 40, 30, "Neon Slash"],
["Riot Guard", "Tank", 150, 40, 20, 50, "Shield Bash"],
		["Bio-Medic", "Support", 80, 100, 30, 60, "Nanite Heal"],
		["Drone Pilot", "Ranged", 70, 80, 40, 40, "Swarm Attack"],
		["Digital Summoner", "Special", 70, 110, 30, 30, "Holo-Projection"],
		["Droid Master", "Special", 100, 60, 40, 30, "Deploy Sentry"],
		["Grapple Specialist", "Utility", 80, 70, 50, 40, "High-Ground Leap"],
		["Time Mage", "Special", 60, 160, 30, 20, "Chronos Shift"],
		["Ninja", "Utility", 85, 80, 60, 30, "Shadow Clone"],
		["Sniper", "Ranged", 60, 70, 70, 10, "Piercing Round"],
		["Green Mage", "Support", 80, 120, 30, 40, "Nature's Pulse"],
		["Alchemist", "Special", 70, 90, 40, 50, "Transmute"],
		["Trickster", "Utility", 75, 85, 50, 40, "Mirror Image"],
		["Gladiator", "Melee", 130, 60, 30, 30, "Arena Strike"],
		["White Monk", "Support", 100, 80, 40, 60, "Pure Palm"],
		["Defender", "Tank", 160, 50, 20, 60, "Iron Wall"],
		["Parivir", "Special", 80, 100, 50, 40, "Spirit Blade"],
		["Blue Mage", "Special", 70, 130, 30, 30, "Spell Mimic"],
		["Assassin", "Melee", 80, 70, 65, 20, "Death Mark"],
		["Tinker", "Special", 70, 80, 40, 60, "Gadget Burst"],
		["Samurai", "Melee", 110, 60, 55, 30, "Iai Strike"],
		["Bard", "Support", 80, 120, 25, 25, "Inspiring Melody"],
		["Dark Knight", "Tank", 140, 80, 40, 40, "Abyssal Aegis"],
		["Geomancer", "Special", 70, 110, 35, 30, "Terra Shift"],
		["Berserker", "Melee", 120, 40, 60, 10, "Frenzy Slash"],
		["Agent", "Utility", 85, 90, 45, 30, "Tactical Breach"],
		["Dancer", "Support", 75, 100, 30, 30, "Rhythmic Step"],
		["Heritor", "Special", 90, 100, 35, 35, "Ancestral Call"],
		["Necromancer", "Special", 65, 140, 40, 20, "Soul Harvest"],
		["Space Mage", "Ranged", 60, 160, 50, 20, "Cosmic Flare"],
		["Rune Lord", "Special", 80, 110, 45, 40, "Rune Inscription"],
		["Deck Stacker", "Utility", 80, 100, 30, 30, "Card Draw"],
		["Neon Samurai", "Melee", 100, 60, 50, 25, "Ion Slash"],
		["Void Technician", "Utility", 75, 130, 30, 35, "Gravity Well"],
		["Plasma Vanguard", "Tank", 140, 70, 35, 50, "Thermal Shield"],
		["Synapse Weaver", "Support", 70, 150, 20, 20, "Neural Link"]
	]


	for data in classes:
		var cls = ClassData.new()
		cls.class_name = data[0]
		cls.role = data[1]
		cls.base_hp = data[2]
		cls.base_mp = data[3]
		cls.base_attack = data[4]
		cls.base_defense = data[5]
		cls.special_ability = data[6]
		
		# Assign multipliers based on role to ensure scaling logic works
		match cls.role:
			"Tank": cls.stat_multipliers = {"attack": 0.8, "defense": 1.5, "agility": 0.7, "intellect": 0.9}
			"Melee": cls.stat_multipliers = {"attack": 1.3, "defense": 1.1, "agility": 1.1, "intellect": 0.7}
			"Ranged": cls.stat_multipliers = {"attack": 1.2, "defense": 0.8, "agility": 1.2, "intellect": 1.0}
			"Support": cls.stat_multipliers = {"attack": 0.7, "defense": 1.0, "agility": 1.0, "intellect": 1.4}
			"Utility": cls.stat_multipliers = {"attack": 1.0, "defense": 1.0, "agility": 1.3, "intellect": 1.1}
			"Special": cls.stat_multipliers = {"attack": 1.1, "defense": 0.9, "agility": 1.0, "intellect": 1.5}
			_: cls.stat_multipliers = {"attack": 1.0, "defense": 1.0, "agility": 1.0, "intellect": 1.0}
			
		library[cls.class_name] = cls
		
		if not role_map.has(cls.role):
			role_map[cls.role] = []
		role_map[cls.role].append(cls.class_name)

func get_class(class_name: String) -> ClassData:
	return library.get(class_name)

func get_random_class_by_role(role: String) -> ClassData:
	var options = role_map.get(role, [])
	if options.is_empty(): return null
	return get_class(options.pick_random())

func get_all_classes() -> Dictionary:
	return library

func get_multipliers(class_name: String) -> Dictionary:
	var cls = get_class(class_name)
	return cls.stat_multipliers if cls else {}