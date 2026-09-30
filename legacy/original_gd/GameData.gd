extends Resource
class_name GameData

@export_group("Campaign Flow")
## Ordered list of mission resources defining the story progression
@export var mission_sequence: Array[MissionResource] = []

@export_group("Asset Mappings")
## Maps a CharacterID (String) to a 3D model file path
@export var character_models: Dictionary = {}
## Maps a CharacterID to a dictionary of animation clip names
@export var animation_libraries: Dictionary = {}
## Maps TileID to the corresponding texture/material path
@export var tile_textures: Dictionary = {}
## Maps PropID to the mesh file path
@export var prop_meshes: Dictionary = {}

@export_group("Economy & Vendors")
## Maps VendorID to a list of ItemResources they sell
@export var vendor_inventories: Dictionary = {}
## Global price multiplier for items
@export var global_price_modifier: float = 1.0

@export_group("Bestiary")
## Maps EnemyID to their base stats and loot tables
@export var enemy_database: Dictionary = {}

@export_group("Cutscenes")
## Maps SceneID to the specific cutscene sequence data
@export var cutscene_registry: Dictionary = {}

# Helper method to get a mission by its index in the campaign
func get_mission_by_index(index: int) -> MissionResource:
	if index >= 0 and index < mission_sequence.size():
		return mission_sequence[index]
	return null

# Helper to retrieve model path for a specific character
func get_model_for_character(char_id: String) -> String:
	return character_models.get(char_id, "")

# Helper to retrieve texture for a specific tile
func get_texture_for_tile(tile_id: String) -> String:
	return tile_textures.get(tile_id, "")