class_name CharacterData
extends GameResource
## A roster member (party character, recruitable, or authored NPC/enemy template).
## Persistent between battles; a battle Unit is spawned from it.

@export var class_id: String = "street_samurai"
## FFT-style secondary command set: the class whose learned abilities are also usable.
@export var secondary_class_id: String = ""
@export var portrait_path: String = ""
@export var sprite_sheet_path: String = ""
@export var sprite_frames_path: String = ""
@export var team: int = 0
@export var is_unique: bool = true
@export var bio: String = ""

@export_group("Stats")
@export var base_stats: Dictionary = {"strength": 10, "agility": 10, "intelligence": 10, "vitality": 10, "level": 1}
@export var experience: int = 0
## {class_id: level}
@export var class_levels: Dictionary = {}
## {class_id: xp}
@export var class_xp: Dictionary = {}

@export_group("Abilities")
@export var learned_ability_ids: Array[String] = []

@export_group("Gear")
## {slot: item_instance_uid}
@export var equipment: Dictionary = {}
## Weapon families this character personally specializes in (stat + ability XP bonus).
@export var weapon_specialties: Array[String] = []
@export var deck: Dictionary = {}

@export_group("AI (enemies / guests)")
@export var ai_behavior: String = "aggressive"

@export_group("Status")
@export var is_dispatched: bool = false


func get_stats() -> UnitStats:
	return UnitStats.from_dict(base_stats)


func set_stats(stats: UnitStats) -> void:
	base_stats = stats.to_dict()


func get_class_level(cid: String) -> int:
	return int(class_levels.get(cid, 0))


func get_deck() -> DeckResource:
	var d := DeckResource.from_dict(deck)
	d.owner_id = id
	return d
