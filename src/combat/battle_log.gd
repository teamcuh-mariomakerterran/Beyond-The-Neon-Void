class_name BattleLog
extends RefCounted
## (From the tactics-combat-core skill template, installed.)
## Structured, engine-neutral record of a battle: header (seed, mission, units)
## plus one event per rules outcome, captured from EventBus. Foundation for
## replays, bug repro files, the Lying HUD's InfoFilter tests and the
## engine-port parity contract (engine-port-contracts/references/battle-log-v1.md).
##
## Usage (CombatManager.start_battle, after seeding):
##   log = BattleLog.new(); log.begin(mission.id if mission else "", seed_value, units)
## In _finish():  log.end(p_victory, turn_number)  then  log.save("user://logs/last_battle.json")

const VERSION := 1

var header: Dictionary = {}
var events: Array[Dictionary] = []
var _tick_source: Callable = func() -> int: return 0
var _connected := false


func begin(mission_id: String, seed_value: int, units: Array[Node], tick_source: Callable = Callable()) -> void:
	events.clear()
	if tick_source.is_valid():
		_tick_source = tick_source
	var roster: Array[Dictionary] = []
	for u in units:
		roster.append(_unit_ref(u, true))
	header = {"version": VERSION, "mission": mission_id, "seed": seed_value, "units": roster,
		"engine": "godot-%s" % Engine.get_version_info().get("string", "")}
	_connect()


func end(victory: bool, turns: int) -> void:
	header["victory"] = victory
	header["turns"] = turns
	header["hash"] = digest()
	_disconnect()


func digest() -> String:
	return JSON.stringify(events).sha256_text()


func to_dict() -> Dictionary:
	return {"header": header, "events": events}


func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "  "))
	return OK


func _add(type: String, data: Dictionary) -> void:
	data["t"] = type
	data["tick"] = _tick_source.call()
	data["i"] = events.size()
	events.append(data)


func _unit_ref(u: Node, full: bool = false) -> Dictionary:
	if not is_instance_valid(u):
		return {"id": "?"}
	var d: Variant = u.get("data")
	var c: Vector2i = u.get("cell")
	var r := {"id": d.id if d else str(u.name), "team": int(u.get("team")), "cell": [c.x, c.y]}
	if full:
		r["level"] = int(u.call("get_stat", "level")) if u.has_method("get_stat") else 0
		r["class"] = d.class_id if d else ""
	return r


func _connect() -> void:
	if _connected:
		return
	_connected = true
	EventBus.turn_started.connect(_on_turn)
	EventBus.unit_moved.connect(_on_move)
	EventBus.ability_used.connect(_on_ability)
	EventBus.unit_damaged.connect(_on_damage)
	EventBus.unit_healed.connect(_on_heal)
	EventBus.unit_missed.connect(_on_miss)
	EventBus.unit_died.connect(_on_died)
	EventBus.unit_status_applied.connect(_on_status_on)
	EventBus.unit_status_removed.connect(_on_status_off)


func _disconnect() -> void:
	if not _connected:
		return
	_connected = false
	EventBus.turn_started.disconnect(_on_turn)
	EventBus.unit_moved.disconnect(_on_move)
	EventBus.ability_used.disconnect(_on_ability)
	EventBus.unit_damaged.disconnect(_on_damage)
	EventBus.unit_healed.disconnect(_on_heal)
	EventBus.unit_missed.disconnect(_on_miss)
	EventBus.unit_died.disconnect(_on_died)
	EventBus.unit_status_applied.disconnect(_on_status_on)
	EventBus.unit_status_removed.disconnect(_on_status_off)


func _on_turn(u: Node) -> void: _add("turn", {"unit": _unit_ref(u)})
func _on_move(u: Node, a: Vector2i, b: Vector2i) -> void: _add("move", {"unit": _unit_ref(u), "from": [a.x, a.y], "to": [b.x, b.y]})
func _on_ability(u: Node, ab: Resource, c: Vector2i) -> void: _add("ability", {"unit": _unit_ref(u), "ability": ab.get("id") if ab else "", "cell": [c.x, c.y]})
func _on_damage(u: Node, n: int, crit: bool) -> void: _add("damage", {"unit": _unit_ref(u), "amount": n, "crit": crit})
func _on_heal(u: Node, n: int) -> void: _add("heal", {"unit": _unit_ref(u), "amount": n})
func _on_miss(u: Node) -> void: _add("miss", {"unit": _unit_ref(u)})
func _on_died(u: Node) -> void: _add("death", {"unit": _unit_ref(u)})
func _on_status_on(u: Node, s: String) -> void: _add("status+", {"unit": _unit_ref(u), "status": s})
func _on_status_off(u: Node, s: String) -> void: _add("status-", {"unit": _unit_ref(u), "status": s})
