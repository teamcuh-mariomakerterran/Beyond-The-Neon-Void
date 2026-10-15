class_name BattleStats
extends RefCounted
## Who did what in the current battle: damage dealt and taken, kills, heals,
## crits, misses, biggest hit. Fed by EventBus (credit goes to the unit whose
## turn it is), read by the results screen (Shift Report) and NewsReacts.
## CombatManager owns one and resets it every battle.

## Funny titles for the results screen, best stat first.
const TITLES := {
	"kills": ["Body Count", "Closing Time", "Last Call for Them"],
	"dealt": ["Heavy Hitter", "Overtime Pay", "Property Damage"],
	"heals": ["Designated Driver", "Patch Job", "Bar Medic"],
	"taken": ["Human Sandbag", "Took One for the Team", "Load-Bearing Friend"],
	"crits": ["Lucky Bastard", "Weak-Spot Enthusiast"],
}

var rows: Dictionary = {}  # unit instance id -> row (see _row)
var _listening := false


func reset() -> void:
	rows.clear()
	if not _listening:
		_listening = true
		EventBus.unit_damaged.connect(_on_damaged)
		EventBus.unit_healed.connect(_on_healed)
		EventBus.unit_died.connect(_on_died)
		EventBus.unit_missed.connect(func(_u: Node) -> void: _bump(CombatManager.active_unit, "misses", 1))


func _row(u: Node) -> Dictionary:
	var k := u.get_instance_id()
	if not rows.has(k):
		var cd: CharacterData = u.get("data")
		rows[k] = {"name": u.display_name() if u.has_method("display_name") else str(u.name),
			"id": cd.id if cd else "", "team": int(u.get("team")),
			"dealt": 0, "taken": 0, "kills": 0, "heals": 0, "crits": 0, "misses": 0, "biggest": 0}
	return rows[k]


func _bump(u: Node, key: String, amt: int) -> void:
	if u == null or not is_instance_valid(u) or not u.has_method("is_alive"):
		return
	var r := _row(u)
	r[key] = int(r[key]) + amt


func _on_damaged(target: Node, amount: int, crit: bool) -> void:
	_bump(target, "taken", amount)
	var by := CombatManager.active_unit
	if by and is_instance_valid(by) and by != target and int(by.get("team")) != int(target.get("team")):
		_bump(by, "dealt", amount)
		if crit:
			_bump(by, "crits", 1)
		var r := _row(by)
		r["biggest"] = maxi(int(r["biggest"]), amount)


func _on_healed(target: Node, amount: int) -> void:
	var by := CombatManager.active_unit
	if amount > 0 and by and is_instance_valid(by) and int(by.get("team")) == int(target.get("team")):
		_bump(by, "heals", amount)


func _on_died(dead: Node) -> void:
	var by := CombatManager.active_unit
	if by and is_instance_valid(by) and by != dead and int(by.get("team")) != int(dead.get("team")):
		_bump(by, "kills", 1)


## Rows for one team, best first (kills, then damage, then heals).
func team_rows(team: int) -> Array:
	var out: Array = rows.values().filter(func(r: Dictionary) -> bool: return int(r["team"]) == team)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return score(a) > score(b))
	return out


static func score(r: Dictionary) -> float:
	return int(r["kills"]) * 60.0 + int(r["dealt"]) + int(r["heals"]) * 0.8 + int(r["taken"]) * 0.15


## Best performer on `team` ({} if nobody did anything).
func mvp(team: int = 0) -> Dictionary:
	var t := team_rows(team)
	return t[0] if not t.is_empty() and score(t[0]) > 0.0 else {}


## A title for a row: named after the stat it stands out most in (seeded pick).
static func title_for(r: Dictionary, rng: RandomNumberGenerator) -> String:
	var best := "dealt"
	var best_v := -1.0
	for k: String in ["kills", "heals", "crits", "taken", "dealt"]:
		var weight: float = {"kills": 80.0, "heals": 1.2, "crits": 40.0, "taken": 0.5, "dealt": 1.0}[k]
		var v := float(r.get(k, 0)) * weight
		if v > best_v:
			best_v = v
			best = k
	var opts: Array = TITLES[best]
	return opts[rng.randi() % opts.size()]
