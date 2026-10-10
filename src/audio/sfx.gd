class_name Sfx
extends RefCounted
## What the game sounds like (data/sfx_events.json). Sfx.event("door") plays
## that event's sound family; Sfx.for_ability(...) picks a weapon / magic /
## blast sound for an attack. All of it goes through AudioManager.play_sfx,
## which chooses a random variant (hit_1 … hit_13).

static var _map: Dictionary = {}


static func map() -> Dictionary:
	if _map.is_empty():
		var p := "res://data/sfx_events.json"
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		_map = d if d is Dictionary else {"events": {}}
	return _map


static func event_sound(ev: String) -> String:
	return str((map().get("events", {}) as Dictionary).get(ev, ""))


static func event(ev: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var id := event_sound(ev)
	if id != "":
		AudioManager.play_sfx(id, volume_db, pitch)


## Sound family for an ability used by `unit` (ranged or not).
static func ability_sound(ability: Ability, unit: Node, ranged: bool) -> String:
	if ability.sfx_id != "":
		return ability.sfx_id
	var m := map()
	if ability.is_healing():
		return event_sound("heal")
	if ability.kind == Ability.Kind.BUFF:
		return event_sound("buff")
	if ability.kind == Ability.Kind.DEBUFF:
		return event_sound("debuff")
	if ability.aoe_radius > 0 and ability.kind in [Ability.Kind.ATTACK, Ability.Kind.MAGIC]:
		return str(m.get("area", "explosion"))
	var by_type: Dictionary = m.get("damage_type", {})
	if ability.kind == Ability.Kind.MAGIC or (ability.damage_type != "physical" and by_type.has(ability.damage_type) and ability.damage_type != "kinetic"):
		return str(by_type.get(ability.damage_type, "magic"))
	var weapon := weapon_type(unit)
	var by_weapon: Dictionary = m.get("weapon", {})
	if weapon != "" and by_weapon.has(weapon):
		var w := str(by_weapon[weapon])
		# A gun used point-blank still shoots; a blade at range is a thrown hit.
		return w
	return str(m.get("ranged_default" if ranged else "melee_default", "hit"))


static func weapon_type(unit: Node) -> String:
	if unit == null or not ("equipment" in unit) or unit.equipment == null:
		return ""
	var inst: Variant = unit.equipment.slots.get("weapon")
	if inst is Dictionary:
		var it := ContentDB.get_item(str((inst as Dictionary).get("item_id", "")))
		if it:
			return it.equip_type
	return ""


## Background bed for a map: rain if it has rain particles, crowd noise in a
## city, else nothing (data/sfx_events.json "ambience").
static func ambience_for_map(d: Dictionary) -> String:
	var amb: Dictionary = map().get("ambience", {})
	for cell_parts: Variant in (d.get("particles", {}) as Dictionary).values():
		for e: Variant in cell_parts:
			if e is Array and str(e[1]).contains("rain"):
				return str(amb.get("rain", ""))
	if str(d.get("kind", "")) == "city":
		return str(amb.get("city", ""))
	return ""


static func ambience(key: String) -> void:
	AudioManager.play_ambience(str((map().get("ambience", {}) as Dictionary).get(key, key)))

