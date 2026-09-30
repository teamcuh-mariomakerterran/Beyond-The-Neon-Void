@abstract
class_name GameResource
extends Resource
## Base for all content Resources (classes, abilities, items, cards, missions...).
##
## Content is authored as JSON in res://data (and later by the Neon Forge editor),
## then loaded into typed Resources by ContentDB. `apply_dict()` / `to_dict()` use
## the exported property list, so adding an @export var automatically makes it
## loadable, saveable and editable — no per-class serialization code.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""


## Fills exported properties from a Dictionary (typically parsed JSON).
## Unknown keys are ignored so older data files keep loading.
func apply_dict(data: Dictionary) -> GameResource:
	var props := _storage_properties()
	for key: String in data:
		if not props.has(key):
			continue
		_set_coerced(key, data[key], props[key])
	return self


## Serializes exported properties to a JSON-friendly Dictionary.
func to_dict() -> Dictionary:
	var out := {}
	var props := _storage_properties()
	for key: String in props:
		var v: Variant = get(key)
		if v is Object:
			continue
		var p: Dictionary = props[key]
		if p["type"] == TYPE_INT and p["hint"] == PROPERTY_HINT_ENUM:
			out[key] = _enum_name(p["hint_string"], v)
		else:
			out[key] = _to_json_value(v)
	return out


## Enum hint strings look like "ATTACK,MAGIC,HEAL" or "Melee:0,Ranged:1".
static func _enum_index(hint: String, name: String) -> int:
	var i := 0
	for part in hint.split(","):
		var bits := part.split(":")
		var value := int(bits[1]) if bits.size() > 1 else i
		if _norm(bits[0]) == _norm(name):
			return value
		i = value + 1
	push_warning("Unknown enum value '%s' (options: %s)" % [name, hint])
	return 0


static func _norm(s: String) -> String:
	return s.strip_edges().to_upper().replace(" ", "_")


static func _enum_name(hint: String, value: int) -> String:
	var i := 0
	for part in hint.split(","):
		var bits := part.split(":")
		var v := int(bits[1]) if bits.size() > 1 else i
		if v == value:
			return _norm(bits[0])
		i = v + 1
	return str(value)


func _storage_properties() -> Dictionary:
	var props := {}
	for p: Dictionary in get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			props[p["name"]] = p
	return props


func _set_coerced(key: String, value: Variant, prop: Dictionary) -> void:
	var type: int = prop["type"]
	match type:
		TYPE_INT:
			if value is String and prop["hint"] == PROPERTY_HINT_ENUM:
				set(key, _enum_index(prop["hint_string"], value))
			else:
				set(key, int(value))
		TYPE_FLOAT:
			set(key, float(value))
		TYPE_BOOL:
			set(key, bool(value))
		TYPE_STRING:
			set(key, str(value))
		TYPE_VECTOR2I:
			if value is Array and value.size() >= 2:
				set(key, Vector2i(int(value[0]), int(value[1])))
		TYPE_VECTOR2:
			if value is Array and value.size() >= 2:
				set(key, Vector2(float(value[0]), float(value[1])))
		TYPE_COLOR:
			if value is String:
				set(key, Color.from_string(value, Color.WHITE))
			elif value is Array and value.size() >= 3:
				set(key, Color(value[0], value[1], value[2], value[3] if value.size() > 3 else 1.0))
		TYPE_ARRAY:
			if value is Array:
				var target: Array = get(key)
				target.clear()
				if target.is_typed() and target.get_typed_builtin() == TYPE_INT:
					for v: Variant in value:
						target.append(int(v))
				elif target.is_typed() and target.get_typed_builtin() == TYPE_OBJECT:
					pass  # Resource arrays are resolved by ContentDB via *_ids fields.
				else:
					target.assign(value)
		TYPE_DICTIONARY:
			if value is Dictionary:
				set(key, value.duplicate(true))
		TYPE_OBJECT:
			pass  # Object references are stored as ids / paths in JSON.
		_:
			set(key, value)


func _to_json_value(v: Variant) -> Variant:
	if v is Vector2i or v is Vector2:
		return [v.x, v.y]
	if v is Color:
		return v.to_html()
	if v is Array:
		var arr := []
		for e: Variant in v:
			if e is Object:
				continue
			arr.append(_to_json_value(e))
		return arr
	if v is Dictionary:
		return v.duplicate(true)
	if v is Object:
		return null
	return v
