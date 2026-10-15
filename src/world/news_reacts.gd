class_name NewsReacts
extends RefCounted
## The Doctrine news desk spins every battle. After a fight 1–3 headlines go
## to the ticker (hub), the living screens' news feed (Signage) and the dev
## console log, picked from data/news_reacts.json by what happened: win or
## loss, which mission, a boss down, flawless or a close call, the MVP, and
## now and then an intercepted Veil feed. Seeded from the battle's RNG so a
## replayed battle reads the same.

const PATH := "res://data/news_reacts.json"
## Chance of the extra lines (MVP wanted poster, Veil feed).
const MVP_CHANCE := 0.45
const VEIL_CHANCE := 0.3
## HP fraction left on the crew that counts as flawless / a close call.
const FLAWLESS := 0.85
const CLOSE_CALL := 0.25

static var _data: Dictionary = {}
## The most recent spin (tests / dev console).
static var last: Array[String] = []


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {}
	return _data


## Headlines for a finished battle (doesn't broadcast; see react()).
## facts: {victory, mission_id, place, fallen, crew, mvp, boss, hp_left (0–1), turns}
static func headlines(facts: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var d := data()
	var out: Array[String] = []
	var won := bool(facts.get("victory", false))
	var key := ("win:" if won else "loss:") + str(facts.get("mission_id", ""))
	var main: Array = d.get(key, d.get("win" if won else "loss", []))
	if not main.is_empty():
		out.append(_fill(str(main[rng.randi() % main.size()]), facts, rng))
	if won and str(facts.get("boss", "")) != "":
		out.append(_pick(d, "boss_down", facts, rng))
	if won:
		var hp := float(facts.get("hp_left", 0.5))
		if hp >= FLAWLESS:
			out.append(_pick(d, "flawless", facts, rng))
		elif hp <= CLOSE_CALL:
			out.append(_pick(d, "close_call", facts, rng))
	if won and str(facts.get("mvp", "")) != "" and rng.randf() < MVP_CHANCE:
		out.append(_pick(d, "mvp", facts, rng))
	if rng.randf() < VEIL_CHANCE:
		out.append(_pick(d, "veil", facts, rng))
	return out.filter(func(t: String) -> bool: return t != "")


## Spin the battle that just ended and put it on the air.
static func react(report: Dictionary) -> Array[String]:
	var facts := facts_from(report)
	var rng := RandomNumberGenerator.new()
	rng.seed = CombatManager.rng.seed + 7919
	last = headlines(facts, rng)
	for t in last:
		Signage.push_headline(t)
		EventBus.broadcast_line.emit("news", t)
	return last


## What the news desk knows about the battle in CombatManager.
static func facts_from(report: Dictionary) -> Dictionary:
	var m := CombatManager.mission
	var place := m.display_name if m else "an undisclosed location"
	var fallen := 0
	var crew := 0
	var hp := 0.0
	var hp_max := 0.0
	var boss := ""
	for u: Node in CombatManager.units:
		if not is_instance_valid(u):
			continue
		var cd: CharacterData = u.get("data")
		if int(u.get("team")) == Unit.Team.PLAYER:
			crew += 1
			hp += maxf(float(u.current_hp), 0.0)
			hp_max += float(u.get_stat("max_hp"))
		elif not u.is_alive():
			fallen += 1
			if cd and cd.is_boss:
				boss = (cd.boss_title + " " if cd.boss_title != "" else "") + cd.display_name
	var mvp: Dictionary = report.get("mvp", {})
	return {"victory": bool(report.get("victory", false)), "mission_id": str(report.get("mission_id", "")),
		"place": place, "fallen": fallen, "crew": crew, "boss": boss,
		"mvp": str(mvp.get("name", "")), "hp_left": hp / maxf(hp_max, 1.0), "turns": CombatManager.turn_number}


static func _pick(d: Dictionary, key: String, facts: Dictionary, rng: RandomNumberGenerator) -> String:
	var lines: Array = d.get(key, [])
	return "" if lines.is_empty() else _fill(str(lines[rng.randi() % lines.size()]), facts, rng)


static func _fill(t: String, facts: Dictionary, rng: RandomNumberGenerator) -> String:
	for k: String in ["place", "fallen", "crew", "mvp", "boss", "turns"]:
		t = t.replace("{%s}" % k, str(facts.get(k, "")))
	return t.replace("{lie}", str(rng.randi_range(3, 9) * [7, 11, 13, 50][rng.randi() % 4]))
