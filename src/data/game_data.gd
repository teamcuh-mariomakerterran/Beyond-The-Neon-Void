class_name GameData
extends Resource
## Campaign-wide asset mappings and tuning. The Neon Forge editor writes these
## through ContentDB; GameData is the in-memory index of "what goes where".

@export_group("Campaign Flow")
## Ordered mission ids defining the main story progression.
@export var mission_sequence: Array[String] = []

@export_group("Asset Mappings")
## character_id -> SpriteFrames / sheet path
@export var character_sprites: Dictionary = {}
## tile_id -> texture path
@export var tile_textures: Dictionary = {}
## prop_id -> texture / scene path
@export var prop_assets: Dictionary = {}
## scene / map id -> music id
@export var scene_music: Dictionary = {}

@export_group("Economy")
@export var global_price_modifier: float = 1.0
@export var sell_ratio: float = 0.5


func get_mission_id_by_index(index: int) -> String:
	if index >= 0 and index < mission_sequence.size():
		return mission_sequence[index]
	return ""
