class_name Barks
extends Node
## Battle barks: short lines over a unit's head (plus the recorded voice line,
## if one is set) when something happens: crits, kills, a friend going down,
## dropping low, the battle starting / ending, being buzzed.
##
## Lines come from (first match wins): the character's own `barks` field
## (CHARACTERS tab), then data/barks.json under the character id,
## "class:<class_id>", then "team:0" / "team:1". A BattleMap adds one of these;
## it listens to EventBus and never changes the fight. Bubbles only show in
## animated battles (tests and auto-resolve stay silent but still pick lines).

signal barked(unit: Node, event: String, line: Dictionary)

## Chance that an event barks at all (a line's own "chance" overrides).
const CHANCE := {"battle_start": 1.0, "victory": 1.0, "low_hp": 1.0, "ally_down": 0.9, "kill": 0.8,
	"crit": 0.7, "shield_down": 1.0, "buzzed": 0.5, "big_hit": 0.4, "heal": 0.4, "miss": 0.35, "turn_start": 0.08}
## Seconds a unit stays quiet after barking, and between any two barks.
const UNIT_COOLDOWN := 6.0
const GLOBAL_GAP := 1.2
const LOW_HP := 0.3
const BIG_HIT := 0.3

var world: Node2D  # where bubbles go (BattleMap.world)
var rng := RandomNumberGenerator.new()
var _quiet_until: Dictionary = {}  # unit instance id -> time
var _next_any: float = 0.0
var _low_said: Dictionary = {}  # unit instance id -> true
var _voice: AudioStreamPlayer
var last: Dictionary = {}  # {unit, event, line} (tests / dev console)


func _ready() -> void:
	rng.randomize()
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	EventBus.battle_started.connect(func(_id: String) -> void: _opening())
	EventBus.battle_ended.connect(func(victory: bool, _id: String) -> void: _closing(victory))
	EventBus.unit_damaged.connect(_on_damaged)
	EventBus.unit_died.connect(_on_died)
	EventBus.unit_missed.connect(func(_u: Node) -> void: say(CombatManager.active_unit, "miss"))
	EventBus.unit_healed.connect(func(u: Node, amt: int) -> void:
		if amt > 0 and CombatManager.active_unit and CombatManager.active_unit != u:
			say(CombatManager.active_unit, "heal"))
	EventBus.turn_started.connect(func(u: Node) -> void:
		say(u, "buzzed" if u.has_method("has_status") and u.has_status("buzzed") else "turn_start"))
	EventBus.unit_status_removed.connect(func(u: Node, sid: String) -> void:
		if sid == "shielded":
			say(u, "shield_down", true))


## Lines a unit has for an event: [{text, voice, chance?}].
static func lines_for(unit: Node, event: String) -> Array:
	var cd: CharacterData = unit.get("data") if unit else null
	if cd == null:
		return []
	var own: Array = []
	for b: Dictionary in cd.barks:
		if str(b.get("event", "")) == event and str(b.get("text", "")) != "":
			own.append({"text": str(b["text"]), "voice": str(b.get("voice_path", "")), "chance": b.get("chance")})
	if not own.is_empty():
		return own
	for key: String in [cd.id, "class:" + cd.class_id, "team:%d" % int(unit.get("team"))]:
		var set: Variant = ContentDB.barks.get(key)
		if set is Dictionary and (set as Dictionary).get(event) is Array:
			var out: Array = []
			for l: Variant in set[event]:
				if l is String:
					out.append({"text": l, "voice": ""})
				elif l is Dictionary:
					out.append({"text": str(l.get("text", "")), "voice": str(l.get("voice", l.get("voice_path", ""))), "chance": l.get("chance")})
			if not out.is_empty():
				return out
	return []


## Bark if the dice, cooldowns and the setting allow. Returns the line or {}.
func say(unit: Node, event: String, force: bool = false) -> Dictionary:
	if not SettingsFlags.barks or unit == null or not is_instance_valid(unit) or not unit.has_method("is_alive"):
		return {}
	if not unit.is_alive() and event != "victory":
		return {}
	var lines := lines_for(unit, event)
	if lines.is_empty():
		return {}
	var now := Time.get_ticks_msec() / 1000.0
	var uid := unit.get_instance_id()
	if not force and (now < _next_any or now < float(_quiet_until.get(uid, 0.0))):
		return {}
	var line: Dictionary = lines[rng.randi() % lines.size()]
	var chance := float(line["chance"]) if line.get("chance") != null else float(CHANCE.get(event, 0.5))
	if not force and rng.randf() > chance:
		return {}
	_quiet_until[uid] = now + UNIT_COOLDOWN
	_next_any = now + GLOBAL_GAP
	last = {"unit": unit, "event": event, "line": line}
	barked.emit(unit, event, line)
	if CombatManager.animate and world and is_instance_valid(world):
		var b := Bubble.new()
		b.text = str(line["text"])
		b.color = NeonTheme.team_color(int(unit.get("team")))
		b.position = (unit as Node2D).position + Vector2(0, -unit_height(unit))
		b.z_index = 3500
		world.add_child(b)
		var vp := str(line.get("voice", ""))
		if vp != "":
			var stream := ForgeStore.load_audio(vp)
			if stream:
				_voice.stream = stream
				_voice.play()
	return line


static func unit_height(unit: Node) -> float:
	var g: IsometricGrid = unit.get("grid")
	return (g.tile_height if g else 32.0) * 2.6


func _opening() -> void:
	var units := CombatManager.get_units()
	for team in [0, 1]:
		var pool := units.filter(func(u: Node) -> bool: return int(u.get("team")) == team and not lines_for(u, "battle_start").is_empty())
		if not pool.is_empty():
			_next_any = 0.0
			say(pool[rng.randi() % pool.size()], "battle_start", true)


func _closing(victory: bool) -> void:
	if not victory:
		return
	var crew := CombatManager.get_units().filter(func(u: Node) -> bool: return int(u.get("team")) == 0 and u.is_alive() and not lines_for(u, "victory").is_empty())
	if not crew.is_empty():
		_next_any = 0.0
		say(crew[rng.randi() % crew.size()], "victory", true)


func _on_damaged(target: Node, amount: int, crit: bool) -> void:
	var attacker := CombatManager.active_unit
	if crit and attacker and attacker != target:
		if not say(attacker, "crit").is_empty():
			return
	if not is_instance_valid(target) or not target.is_alive():
		return
	var mx := maxf(float(target.get_stat("max_hp")), 1.0)
	if target.current_hp <= mx * LOW_HP and not _low_said.has(target.get_instance_id()):
		_low_said[target.get_instance_id()] = true
		say(target, "low_hp", true)
	elif amount >= mx * BIG_HIT:
		say(target, "big_hit")


func _on_died(dead: Node) -> void:
	var killer := CombatManager.active_unit
	if killer and killer != dead and int(killer.get("team")) != int(dead.get("team")):
		if not say(killer, "kill").is_empty():
			return
	var friends := CombatManager.get_units().filter(func(u: Node) -> bool: return u != dead and u.is_alive() and int(u.get("team")) == int(dead.get("team")))
	if not friends.is_empty():
		say(friends[rng.randi() % friends.size()], "ally_down")


## Speech bubble: pops in, floats a little, fades.
class Bubble extends Node2D:
	var text: String = ""
	var color: Color = Color.WHITE
	var _born: float = 0.0
	const LIFE := 2.4

	func _ready() -> void:
		_born = Time.get_ticks_msec() / 1000.0
		scale = Vector2(0.6, 0.6)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(_d: float) -> void:
		var t := Time.get_ticks_msec() / 1000.0 - _born
		if t > LIFE:
			queue_free()
			return
		modulate.a = clampf((LIFE - t) / 0.4, 0.0, 1.0)
		position.y -= 6.0 * _d
		queue_redraw()

	func _draw() -> void:
		var font := NeonTheme.mono()
		var fs := 13
		var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 260.0)
		var lines := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, 260.0, fs)
		var h := lines.y + 10.0
		var box := Rect2(Vector2(-w * 0.5 - 8, -h - 8), Vector2(w + 16, h))
		draw_rect(box, Color(0.03, 0.02, 0.07, 0.88))
		draw_rect(box, color, false, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -8.5), Vector2(6, -8.5), Vector2(0, 0)]), color)
		draw_multiline_string(font, box.position + Vector2(8, 5 + fs), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, -1, Color(1, 1, 1))
