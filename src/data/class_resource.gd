class_name ClassResource
extends GameResource
## A job / class definition (the "Data" end of the Class bridge).
##
## ClassResource (data) -> ClassLibrary (registry) -> UnitStats (calculator) -> Unit (entity)
##
## Stat scaling is multiplicative: a unit's raw primary attributes are multiplied
## by `multipliers` of its current class (see UnitStats.calculate()).

enum Role { MELEE, RANGED, SUPPORT, UTILITY, TANK, SPECIAL }

@export var role: Role = Role.MELEE
## 1 = starter, 2 = advanced, 3 = elite, 4 = hidden.
@export var tier: int = 1
@export var icon_path: String = ""
@export var is_hidden: bool = false
## False for non-player chassis classes (droids, echoes, turrets).
@export var playable: bool = true
## Elemental damage taken multipliers, e.g. {"electric": 1.5, "cryo": 0.5}.
@export var element_modifiers: Dictionary = {}
## Card classes (Deck Stacker) fight with a deck instead of a weapon.
@export var uses_deck: bool = false

@export_group("Base stats")
@export var base_hp: int = 100
@export var base_mp: int = 20
@export var hp_growth: int = 10
@export var mp_growth: int = 3
@export var base_speed: int = 8
@export var move: int = 4
@export var jump: int = 2
@export var max_ap: int = 2

@export_group("Scaling")
## Multipliers applied to primary attributes: strength, agility, intelligence, vitality.
@export var multipliers: Dictionary = {"strength": 1.0, "agility": 1.0, "intelligence": 1.0, "vitality": 1.0}
## Primary attribute gains per level while in this class.
@export var growth: Dictionary = {"strength": 1, "agility": 1, "intelligence": 1, "vitality": 1}

@export_group("Equipment")
## Weapon families this class can equip, e.g. ["blade", "pistol"].
@export var weapon_types: Array[String] = []
## Families the class specializes in: small stat & ability-XP bonus when equipped.
@export var specialty_weapon_types: Array[String] = []
@export var armor_types: Array[String] = ["light"]

@export_group("Abilities")
## Always-available command set (the class's signature skills).
@export var innate_ability_ids: Array[String] = []
## Abilities purchasable with microchips at a terminal.
@export var learnable_ability_ids: Array[String] = []

@export_group("Unlocking")
## FFT-style requirements: {"street_samurai": 3, "hacker": 2} = class levels needed.
@export var unlock_requirements: Dictionary = {}
## Optional story flag required (hidden classes).
@export var unlock_flag: String = ""


func get_multiplier(stat: String) -> float:
	return float(multipliers.get(stat, 1.0))


func role_name() -> String:
	return Role.keys()[role].capitalize()
