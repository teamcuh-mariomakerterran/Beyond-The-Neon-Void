extends Node
## ClassLibrary — the class registry (the "Registry" step of the Class bridge).
##
## Classes are authored in res://data/classes.json and loaded by ContentDB.
## This autoload answers class questions: lookups, roles, FFT-style unlocks.

## The 19 playable classes, in menu order. See docs/design/CLASSES.md.
const CLASS_ORDER: Array[String] = [
	"street_samurai", "gunslinger", "hacker", "digital_healer", "riot_guard", "smuggler",
	"corporate_enforcer", "cyber_sniper", "drone_pilot", "grapple_specialist", "neural_saboteur", "void_technician", "synapse_weaver",
	"plasma_vanguard", "droid_master",
	"vector_knight", "chrono_stitcher", "cartographer", "deck_stacker",
]

const DEFAULT_CLASS := "street_samurai"

var role_map: Dictionary = {}  # Role name -> Array[String] of class ids


func _ready() -> void:
	ContentDB.content_reloaded.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	role_map.clear()
	for cls: ClassResource in ContentDB.get_all("classes"):
		var role := cls.role_name()
		if not role_map.has(role):
			role_map[role] = []
		role_map[role].append(cls.id)


func get_class_res(class_id: String) -> ClassResource:
	return ContentDB.get_class_res(class_id)


func get_default_class() -> ClassResource:
	return get_class_res(DEFAULT_CLASS)


func get_all_classes() -> Array[ClassResource]:
	var out: Array[ClassResource] = []
	for id in CLASS_ORDER:
		var c := get_class_res(id)
		if c:
			out.append(c)
	for c: ClassResource in ContentDB.get_all("classes"):  # editor-added classes
		if not out.has(c):
			out.append(c)
	return out


func get_random_class_by_role(role: String) -> ClassResource:
	var options: Array = role_map.get(role, [])
	return get_class_res(options.pick_random()) if not options.is_empty() else null


func get_multipliers(class_id: String) -> Dictionary:
	var cls := get_class_res(class_id)
	return cls.multipliers if cls else {}


## True if `character` meets the class's level prerequisites and story flag.
func is_unlocked_for(class_id: String, character: CharacterData) -> bool:
	var cls := get_class_res(class_id)
	if cls == null:
		return false
	if cls.unlock_flag != "" and not GameManager.check_story_flag(cls.unlock_flag):
		return false
	for req: String in cls.unlock_requirements:
		if character.get_class_level(req) < int(cls.unlock_requirements[req]):
			return false
	return true


func unlocked_classes_for(character: CharacterData) -> Array[ClassResource]:
	var out: Array[ClassResource] = []
	for c in get_all_classes():
		if is_unlocked_for(c.id, character):
			out.append(c)
	return out
