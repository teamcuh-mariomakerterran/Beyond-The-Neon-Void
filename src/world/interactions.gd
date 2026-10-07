class_name Interactions
extends RefCounted
## Interaction anchors: things a unit (battle) or the player (explore) can use
## on a cell, painted with the World Painter's MASKS tab and saved in
## WorldMap.anchors. One anchor:
##   {id, cell: [x, y], kind, label, hidden, scope: "both"|"battle"|"explore",
##    ap: 1, reach: 1, once, enabled, requires_flag, requires_item, consume_item,
##    sequence: "", step: 0,            switches pressed in order (1, 2, 3…)
##    actions: [{do, arg}],             what happens (ACTIONS below)
##    fail_actions: [{do, arg}],        pressed out of order (sequence reset)
##    npc_id,                           kind "npc": the NPC's stages run
##    trap: {damage, status, hostile: "player"|"enemy", disarm: 0–1}}
##
## Runtime: one Interactions per scene, set up with the map, its grid and a
## host node. Pure state (used, sequence progress, open doors, revealed traps)
## lives here; anything scene-specific is asked of the host if it has it:
##   ix_toast(text, color)  ix_units() -> Array  ix_group_changed(group, open)
##   ix_spawn(character_id, cell, team)  ix_npc(npc_id)  ix_anchor_changed(anchor)
##   run_trigger(do, arg)   (explore: dialog / cutscene / battle / teleport / music)

const YELLOW := Color(1.0, 0.85, 0.15)
## kind -> {name, glyph, verb, color}
const KINDS := {
	"terminal": {"name": "Terminal", "glyph": "▣", "verb": "HACK", "color": Color(1.0, 0.85, 0.15)},
	"switch": {"name": "Switch", "glyph": "⏻", "verb": "FLIP", "color": Color(1.0, 0.7, 0.1)},
	"loot": {"name": "Hidden loot", "glyph": "✦", "verb": "SEARCH", "color": Color(1.0, 0.95, 0.4)},
	"trap": {"name": "Wire trap", "glyph": "⚠", "verb": "DISARM", "color": Color(1.0, 0.35, 0.2)},
	"door": {"name": "Door / shutter", "glyph": "▯", "verb": "OPEN", "color": Color(0.9, 0.8, 0.3)},
	"transition": {"name": "Way in", "glyph": "⇲", "verb": "ENTER", "color": Color(0.5, 1.0, 0.6)},
	"npc": {"name": "NPC hook", "glyph": "☺", "verb": "TALK", "color": Color(0.4, 0.9, 1.0)},
	"device": {"name": "Device", "glyph": "◎", "verb": "ACTIVATE", "color": Color(1.0, 0.6, 0.9)},
	"medstation": {"name": "Med station", "glyph": "✚", "verb": "HEAL", "color": Color(0.4, 1.0, 0.6)},
	"intel": {"name": "Data cache", "glyph": "⌬", "verb": "DOWNLOAD", "color": Color(0.6, 0.8, 1.0)},
	"examine": {"name": "Examine", "glyph": "?", "verb": "EXAMINE", "color": Color(0.85, 0.85, 0.85)},
}
const ACTIONS := ["open", "close", "toggle", "reveal", "unshield", "status", "cleanse", "give", "take",
	"coins", "chips", "damage", "heal", "ap", "spawn", "flag", "unflag", "enable", "disable", "arm",
	"toast", "news", "cue", "dialog", "npc", "cutscene", "battle", "teleport", "music"]
const ACTION_HINT := {
	"open": "mask group (door cells)", "close": "mask group", "toggle": "mask group",
	"reveal": "radius in cells (empty = whole map): strips cloaked / hidden",
	"unshield": "character id (empty = everyone shielded)",
	"status": "status_id@self|allies|enemies|all|boss", "cleanse": "status_id@target",
	"give": "item_id or item_id:qty", "take": "item_id or item_id:qty",
	"coins": "soul coins", "chips": "microchips",
	"damage": "amount or 25% (to whoever used it)", "heal": "amount or 40%", "ap": "+AP for the user",
	"spawn": "character_id@x,y[@enemy|player]", "flag": "story flag", "unflag": "story flag",
	"enable": "anchor id", "disable": "anchor id", "arm": "trap anchor id (rewire: hostile to enemies)",
	"toast": "text", "news": "ticker line", "cue": "cue id (data/cues.json)",
	"dialog": "NPC id or a line of text", "npc": "NPC id (runs its stages)",
	"cutscene": "res://data/cutscenes/….json", "battle": "mission id",
	"teleport": "map_id, map_id:spawn#, or x,y on this map", "music": "res://assets/music/….ogg",
}
const CLOAK_STATUSES := ["cloaked", "hidden"]

var world: WorldMap
var grid: IsometricGrid
var host: Object
var scene: String = "battle"  # "battle" | "explore"
var used: Dictionary = {}  # anchor id -> true
var progress: Dictionary = {}  # sequence -> next step expected
var open_groups: Dictionary = {}  # group -> true
var revealed: Dictionary = {}  # anchor id -> true (hidden anchors found)
var enabled_over: Dictionary = {}  # anchor id -> bool
var trap_hostile: Dictionary = {}  # anchor id -> "player"|"enemy"|"none"
var rng := RandomNumberGenerator.new()


## A fresh anchor with sensible defaults for its kind.
static func make(cell: Vector2i, kind: String) -> Dictionary:
	var a := {"id": "", "cell": [cell.x, cell.y], "kind": kind, "label": "", "hidden": false, "scope": "both",
		"ap": 1, "reach": 1, "once": false, "enabled": true, "requires_flag": "", "requires_item": "",
		"consume_item": false, "sequence": "", "step": 0, "actions": [], "fail_actions": []}
	match kind:
		"loot":
			a["hidden"] = true
			a["once"] = true
			a["reach"] = 0
			a["actions"] = [{"do": "give", "arg": ""}]
		"trap":
			a["hidden"] = true
			a["once"] = true
			a["trap"] = {"damage": 25, "status": "shocked", "hostile": "player", "disarm": 0.75}
		"door":
			a["actions"] = [{"do": "toggle", "arg": ""}]
		"switch", "terminal":
			a["actions"] = [{"do": "toggle", "arg": ""}]
		"transition":
			a["reach"] = 0
			a["ap"] = 0
			a["scope"] = "explore"
			a["actions"] = [{"do": "teleport", "arg": ""}]
		"npc":
			a["npc_id"] = ""
			a["ap"] = 0
		"device":
			a["actions"] = [{"do": "reveal", "arg": ""}]
		"medstation":
			a["once"] = true
			a["actions"] = [{"do": "heal", "arg": "40%"}]
		"intel":
			a["once"] = true
			a["actions"] = [{"do": "chips", "arg": "1"}]
		"examine":
			a["ap"] = 0
			a["actions"] = [{"do": "toast", "arg": ""}]
	return a


static func kind_info(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS["examine"])


static func cell_of(a: Dictionary) -> Vector2i:
	return Vector2i(int(a["cell"][0]), int(a["cell"][1]))


## Short label for prompts and the editor ("HACK Terminal").
static func title(a: Dictionary) -> String:
	var info := kind_info(str(a.get("kind", "")))
	return str(a.get("label", "")) if str(a.get("label", "")) != "" else str(info["name"])


func setup(p_world: WorldMap, p_grid: IsometricGrid, p_host: Object = null, p_scene: String = "battle") -> Interactions:
	world = p_world
	grid = p_grid
	host = p_host
	scene = p_scene
	rng.randomize()
	return self


# --- Queries -------------------------------------------------------------------

func is_enabled(a: Dictionary) -> bool:
	return bool(enabled_over.get(str(a["id"]), a.get("enabled", true)))


func is_used(a: Dictionary) -> bool:
	if used.has(str(a["id"])):
		return true
	return scene == "explore" and bool(a.get("once", false)) and GameManager.check_story_flag(_once_flag(a))


func _once_flag(a: Dictionary) -> String:
	return "anchor:%s:%s" % [world.id if world else "", str(a["id"])]


## Shown on the map (hidden loot and armed traps stay invisible until found).
func is_visible(a: Dictionary) -> bool:
	if not bool(a.get("hidden", false)) or revealed.has(str(a["id"])):
		return is_enabled(a) and not is_used(a)
	return false


func hostile_to(a: Dictionary) -> String:
	return str(trap_hostile.get(str(a["id"]), (a.get("trap", {}) as Dictionary).get("hostile", "player")))


## Why this anchor can't be used right now ("" = it can).
func blocker(a: Dictionary, actor: Node = null) -> String:
	if not is_enabled(a):
		return "Offline."
	if is_used(a):
		return "Already used."
	var sc := str(a.get("scope", "both"))
	if sc != "both" and sc != scene:
		return "Not here."
	var f := str(a.get("requires_flag", ""))
	if f != "" and not GameManager.check_story_flag(f):
		return "Locked."
	var item := str(a.get("requires_item", ""))
	if item != "" and GameManager.get_stack_count(item) <= 0:
		var it := ContentDB.get_item(item)
		return "Needs %s." % (it.display_name if it else item)
	if actor and scene == "battle" and "current_ap" in actor and int(actor.current_ap) < ap_cost(a):
		return "Not enough AP."
	return ""


func ap_cost(a: Dictionary) -> int:
	return int(a.get("ap", 1)) if scene == "battle" else 0


func in_reach(a: Dictionary, from: Vector2i) -> bool:
	var c := cell_of(a)
	return absi(c.x - from.x) + absi(c.y - from.y) <= int(a.get("reach", 1))


## Anchors the unit / player standing on `from` could use now, nearest first.
func usable_from(from: Vector2i, actor: Node = null) -> Array:
	var out: Array = []
	if world == null:
		return out
	for a: Dictionary in world.anchors:
		if in_reach(a, from) and blocker(a, actor) == "" and not _armed_hidden_trap(a):
			out.append(a)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return _dist(cell_of(x), from) < _dist(cell_of(y), from))
	return out


func _armed_hidden_trap(a: Dictionary) -> bool:
	return str(a.get("kind", "")) == "trap" and not is_visible(a)


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Sequence switches that are already pressed (they glow in order).
func is_lit(a: Dictionary) -> bool:
	var seq := str(a.get("sequence", ""))
	return seq != "" and int(a.get("step", 0)) < int(progress.get(seq, 1))


func sequence_length(seq: String) -> int:
	var n := 0
	for a: Dictionary in world.anchors:
		if str(a.get("sequence", "")) == seq:
			n = maxi(n, int(a.get("step", 0)))
	return n


# --- Use -----------------------------------------------------------------------

## Use an anchor. verb "" = the kind's default; traps take "disarm" or
## "rewire". Returns {ok, text}.
func interact(a: Dictionary, actor: Node = null, verb: String = "") -> Dictionary:
	var why := blocker(a, actor)
	if why != "":
		_toast(why, NeonTheme.MAGENTA)
		return {"ok": false, "text": why}
	if actor and scene == "battle" and "current_ap" in actor:
		actor.current_ap = maxi(int(actor.current_ap) - ap_cost(a), 0)
		if actor.has_signal("ap_changed"):
			actor.ap_changed.emit(actor.current_ap, actor.get_stat("max_ap"))
	var item := str(a.get("requires_item", ""))
	if item != "" and bool(a.get("consume_item", false)):
		GameManager.remove_stack_item(item)
	if str(a.get("kind", "")) == "trap":
		return _work_trap(a, actor, verb)
	var seq := str(a.get("sequence", ""))
	if seq != "":
		var want := int(progress.get(seq, 1))
		if int(a.get("step", 0)) != want:
			progress[seq] = 1
			_toast("WRONG ORDER — SEQUENCE RESET", NeonTheme.MAGENTA)
			_cue("sequence.fail", actor)
			run_actions(a.get("fail_actions", []), actor, a)
			_changed(a)
			return {"ok": false, "text": "reset"}
		progress[seq] = want + 1
		var total := sequence_length(seq)
		if want >= total:
			_toast("SEQUENCE COMPLETE", YELLOW)
			_cue("sequence.complete", actor)
		else:
			_toast("%s  %d / %d" % [title(a).to_upper(), want, total], YELLOW)
			_cue("sequence.step", actor)
	_mark_used(a)
	run_actions(a.get("actions", []), actor, a)
	if str(a.get("kind", "")) == "npc" and str(a.get("npc_id", "")) != "" and host and host.has_method("ix_npc"):
		host.ix_npc(str(a["npc_id"]))  # the NPC's own stages (NPCS tab)
	_changed(a)
	return {"ok": true, "text": title(a)}


func _mark_used(a: Dictionary) -> void:
	if not bool(a.get("once", false)):
		return
	used[str(a["id"])] = true
	if scene == "explore":
		GameManager.set_story_flag(_once_flag(a))


## Disarm (chance) or rewire (turn it on the enemy). A botched disarm sets it off.
func _work_trap(a: Dictionary, actor: Node, verb: String) -> Dictionary:
	var t: Dictionary = a.get("trap", {})
	revealed[str(a["id"])] = true
	if verb == "rewire":
		trap_hostile[str(a["id"])] = "enemy" if actor == null or _team_name(actor) == "player" else "player"
		_toast("TRAP REWIRED", YELLOW)
		_changed(a)
		return {"ok": true, "text": "rewired"}
	if rng.randf() <= float(t.get("disarm", 0.75)):
		used[str(a["id"])] = true
		_toast("TRAP DISARMED", NeonTheme.GREEN)
		_changed(a)
		return {"ok": true, "text": "disarmed"}
	_toast("DISARM FAILED", NeonTheme.MAGENTA)
	_spring(a, actor)
	return {"ok": false, "text": "sprung"}


## A unit stepped on `cell`: armed traps hostile to it go off. Returns the
## traps that fired.
func on_enter(cell: Vector2i, unit: Node) -> Array:
	var fired: Array = []
	if world == null:
		return fired
	for a: Dictionary in world.anchors_at(cell):
		if str(a.get("kind", "")) != "trap" or not is_enabled(a) or used.has(str(a["id"])):
			continue
		var hostile := hostile_to(a)
		if hostile == "none" or (unit and hostile != _team_name(unit)):
			continue
		_spring(a, unit)
		fired.append(a)
	return fired


func _spring(a: Dictionary, unit: Node) -> void:
	var t: Dictionary = a.get("trap", {})
	used[str(a["id"])] = true
	revealed[str(a["id"])] = true
	_toast("TRAP!", NeonTheme.MAGENTA)
	_cue("trap.spring", unit)
	if unit and unit.has_method("take_damage") and int(t.get("damage", 0)) > 0:
		unit.take_damage(int(t["damage"]))
	if unit and unit.has_method("apply_status") and str(t.get("status", "")) != "":
		unit.apply_status(str(t["status"]))
	run_actions(a.get("actions", []), unit, a)
	_changed(a)


## Reveal hidden anchors within `radius` of `cell` (scanners, smoke devices).
func reveal_anchors(cell: Vector2i, radius: int) -> int:
	var n := 0
	for a: Dictionary in world.anchors:
		if bool(a.get("hidden", false)) and not revealed.has(str(a["id"])) and _dist(cell_of(a), cell) <= radius:
			revealed[str(a["id"])] = true
			n += 1
			_changed(a)
	return n


# --- Actions -------------------------------------------------------------------

func run_actions(list: Variant, actor: Node, a: Dictionary = {}) -> void:
	if not list is Array:
		return
	for act: Variant in list:
		if act is Dictionary:
			run_action(str(act.get("do", "")), str(act.get("arg", "")), actor, a)


func run_action(what: String, arg: String, actor: Node = null, a: Dictionary = {}) -> void:
	match what:
		"open": set_group(arg, true)
		"close": set_group(arg, false)
		"toggle": set_group(arg, not open_groups.has(arg))
		"reveal":
			var r := int(arg) if arg.is_valid_int() else 9999
			var from := cell_of(a) if not a.is_empty() else Vector2i.ZERO
			var n := 0
			for u: Node in _units():
				if _dist(u.cell, from) > r:
					continue
				for s: String in CLOAK_STATUSES:
					if u.has_status(s):
						u.remove_status(s)
						n += 1
			n += reveal_anchors(from, r)
			_toast("SMOKE: %d REVEALED" % n if n > 0 else "SMOKE: NOTHING HIDING", NeonTheme.CYAN)
		"unshield":
			for u: Node in _units():
				if (arg == "" or (u.data and u.data.id == arg)) and u.has_status("shielded"):
					u.remove_status("shielded")
					_toast("%s: SHIELD DOWN" % u.display_name().to_upper(), YELLOW)
					_cue("shield.down", u)
		"status", "cleanse":
			var bits := arg.split("@")
			for u: Node in _targets(bits[1] if bits.size() > 1 else "self", actor):
				if what == "status":
					u.apply_status(bits[0])
				else:
					u.remove_status(bits[0])
		"give", "take":
			var parts := arg.split(":")
			if parts[0] == "":
				return
			var qty := int(parts[1]) if parts.size() > 1 else 1
			if what == "give":
				GameManager.give_item(parts[0], qty)
				var it := ContentDB.get_item(parts[0])
				_toast("FOUND: " + (it.display_name if it else parts[0]) + ("  ×%d" % qty if qty > 1 else ""), YELLOW)
			else:
				GameManager.remove_stack_item(parts[0], qty)
		"coins":
			GameManager.add_soul_coins(int(arg))
			_toast("+%s SOUL COINS" % arg, YELLOW)
		"chips":
			GameManager.add_microchips(int(arg))
			_toast("+%s MICROCHIPS" % arg, YELLOW)
		"damage", "heal":
			if actor == null or not actor.has_method("take_damage"):
				return
			var amt := _amount(arg, actor)
			if what == "damage":
				actor.take_damage(amt)
			else:
				actor.heal(amt)
		"ap":
			if actor and "current_ap" in actor:
				actor.current_ap = mini(int(actor.current_ap) + int(arg), actor.get_stat("max_ap") + int(arg))
				if actor.has_signal("ap_changed"):
					actor.ap_changed.emit(actor.current_ap, actor.get_stat("max_ap"))
		"spawn":
			var sp := arg.split("@")
			if sp.size() >= 2 and host and host.has_method("ix_spawn"):
				var xy := sp[1].split(",")
				host.ix_spawn(sp[0], Vector2i(int(xy[0]), int(xy[1]) if xy.size() > 1 else 0), sp[2] if sp.size() > 2 else "enemy")
		"flag": GameManager.set_story_flag(arg)
		"unflag": GameManager.set_story_flag(arg, false)
		"enable", "disable":
			var other := world.anchor_by_id(arg)
			if not other.is_empty():
				enabled_over[arg] = what == "enable"
				_changed(other)
		"arm":
			var trap := world.anchor_by_id(arg)
			if not trap.is_empty():
				trap_hostile[arg] = "enemy"
				enabled_over[arg] = true
				_changed(trap)
		"toast": _toast(arg if arg != "" else title(a), NeonTheme.CYAN)
		"news": EventBus.broadcast_line.emit("news", arg)
		"cue": _cue(arg, actor)
		"npc":
			if host and host.has_method("ix_npc"):
				host.ix_npc(arg if arg != "" else str(a.get("npc_id", "")))
		"teleport":
			if arg.count(",") == 1 and not arg.contains(":") and host and host.has_method("ix_teleport_local"):
				var t := arg.split(",")
				host.ix_teleport_local(actor, Vector2i(int(t[0]), int(t[1])))
			elif host and host.has_method("run_trigger"):
				host.run_trigger(what, arg)
		_:
			if host and host.has_method("run_trigger"):
				host.run_trigger(what, arg)


## Open / close a mask group: its cells become walkable and lose their cover
## (doors, shutters, laser grids), objects tagged with the group hide.
func set_group(group: String, open: bool, quiet: bool = false) -> void:
	if group == "" or world == null:
		return
	if open:
		open_groups[group] = true
	else:
		open_groups.erase(group)
	if grid:
		for cell: Vector2i in world.group_cells(group):
			var c := grid.get_cell(cell)
			if c == null:
				continue
			var over: Dictionary = world.gameplay.get(cell, {})
			if open:
				IsometricGrid.apply_terrain_defaults(c, ContentDB.terrain)
				c.walkable = world.tiles.has(cell)
				c.cover = IsometricGrid.COVER_NONE
				c.blocks_los = false
			else:
				if over.has("walkable"): c.walkable = bool(over["walkable"])
				if over.has("cover"): c.cover = int(over["cover"])
				if over.has("blocks_los"): c.blocks_los = bool(over["blocks_los"])
	if not quiet:
		_toast(("%s OPEN" if open else "%s SEALED") % group.to_upper().replace("_", " "), YELLOW)
		_cue("door.open" if open else "door.close", null)
	if host and host.has_method("ix_group_changed"):
		host.ix_group_changed(group, open)


func is_open(group: String) -> bool:
	return open_groups.has(group)


func _amount(arg: String, unit: Node) -> int:
	if arg.ends_with("%"):
		return maxi(roundi(unit.get_stat("max_hp") * float(arg.trim_suffix("%")) / 100.0), 1)
	return maxi(int(arg), 0)


func _units() -> Array:
	if host and host.has_method("ix_units"):
		return host.ix_units()
	if scene == "battle" and CombatManager.state != CombatManager.State.IDLE:
		return CombatManager.units.filter(func(u: Node) -> bool: return is_instance_valid(u) and u.is_alive())
	return []


func _targets(who: String, actor: Node) -> Array:
	var out: Array = []
	for u: Node in _units():
		match who:
			"self": if u == actor: out.append(u)
			"allies": if actor and u.team == actor.team: out.append(u)
			"enemies": if actor == null or u.team != actor.team: out.append(u)
			"boss": if u.data and u.data.is_boss: out.append(u)
			_: out.append(u)
	return out


func _team_name(u: Node) -> String:
	return "player" if "team" in u and int(u.team) == 0 else "enemy"


func _toast(text: String, color: Color) -> void:
	if host and host.has_method("ix_toast"):
		host.ix_toast(text, color)
	else:
		EventBus.log_message.emit(text)


func _cue(id: String, unit: Node) -> void:
	if id != "":
		Cues.fire(id, {"unit": unit, "name": unit.display_name() if unit and unit.has_method("display_name") else ""})


func _changed(a: Dictionary) -> void:
	if host and host.has_method("ix_anchor_changed"):
		host.ix_anchor_changed(a)


# --- Save state (explore carries open doors between visits) -------------------

func get_state() -> Dictionary:
	return {"used": used.duplicate(), "progress": progress.duplicate(), "open": open_groups.duplicate(),
		"revealed": revealed.duplicate(), "enabled": enabled_over.duplicate(), "hostile": trap_hostile.duplicate()}


func set_state(d: Dictionary) -> void:
	used = d.get("used", {}).duplicate()
	progress = d.get("progress", {}).duplicate()
	revealed = d.get("revealed", {}).duplicate()
	enabled_over = d.get("enabled", {}).duplicate()
	trap_hostile = d.get("hostile", {}).duplicate()
	for g: String in d.get("open", {}):
		set_group(g, true, true)
