class_name InfoFilter
extends RefCounted
## The Lying HUD (Doctrine Overlay), for the one warped zone that has it
## (MissionResource.lying_hud). While the zone's Doctrine Relay stands, what
## the HUD shows is state data, not the truth:
##   * forecasts skew up to SKEW in the Doctrine's favour (your hits look less
##     likely and weaker, theirs look surer and harder)
##   * some Doctrine units show up as "Civilian" (name, neutral bars)
## The real numbers still decide everything: only what you *see* lies.
## See through it: a unit carrying the Clear Eyes chip (acc_clear_eyes) reads
## true numbers; hacking a relay terminal (anchor action "relay") or destroying
## the relay unit (character "doctrine_relay") drops the overlay for everyone.

const SKEW := 0.25
const CLEAR_EYES := "acc_clear_eyes"
const RELAY_ID := "doctrine_relay"
const DISGUISE := "Civilian"

var active: bool = false
var disguised: Array = []


## Does this unit read true numbers (Clear Eyes chip equipped)?
static func sees_truth(unit: Node) -> bool:
	if unit == null or not ("equipment" in unit) or unit.equipment == null:
		return false
	for slot: String in unit.equipment.slots:
		var inst: Variant = unit.equipment.slots[slot]
		if inst is Dictionary and str((inst as Dictionary).get("item_id", "")) == CLEAR_EYES:
			return true
	return false


## How hard this pair is lied about (0.35–1.0 of SKEW), stable per pair so the
## numbers don't flicker while you hover.
static func _weight(a: Node, b: Node) -> float:
	var h := absi(hash(str(a.get("name")) + ">" + str(b.get("name")))) % 1000
	return 0.35 + 0.65 * float(h) / 999.0


## The forecast the HUD shows `viewer` (normally the attacker you control).
func skew(f: Dictionary, attacker: Node, target: Node, viewer: Node = null) -> Dictionary:
	if not active or sees_truth(viewer if viewer else attacker):
		return f
	var out := f.duplicate()
	var amt := SKEW * _weight(attacker, target)
	var crew_attacking := int(attacker.get("team")) == 0
	if float(f.get("hit", 0.0)) > 0.0:
		out["hit"] = clampf(float(f["hit"]) + (-amt if crew_attacking else amt), 0.05, 0.99)
	var dmg := int(f.get("damage", 0))
	if dmg > 0:
		out["damage"] = maxi(roundi(dmg * (1.0 - amt if crew_attacking else 1.0 + amt)), 1)
		out["kill"] = int(out["damage"]) >= int(target.get("current_hp"))
	out["lie"] = true
	return out


## Puts the "Civilian" mask on about a third of the Doctrine (never the relay
## or a boss). Deterministic per unit name.
func disguise(units: Array) -> void:
	disguised.clear()
	for u: Node in units:
		if int(u.get("team")) != 1 or not is_instance_valid(u):
			continue
		var cd: CharacterData = u.get("data")
		if cd == null or cd.id == RELAY_ID or cd.is_boss:
			continue
		if absi(hash(str(u.name) + cd.id)) % 3 == 0:
			u.disguise = DISGUISE
			disguised.append(u)


## The relay is down: masks off, true numbers from here on.
func drop() -> void:
	active = false
	for u: Node in disguised:
		if is_instance_valid(u):
			u.disguise = ""
			if u.has_method("refresh_stats"):
				u.refresh_stats()
	disguised.clear()
