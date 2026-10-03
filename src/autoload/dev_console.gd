extends CanvasLayer
## DevConsole — the developer's command line, in dev builds only.
## ` (backtick) toggles it. Anything that isn't a command is evaluated as a
## GDScript expression with every autoload in scope:
##   CombatManager.active_unit.current_hp
##   GameManager.soul_coins * 2
## Tab completes commands and content ids. Up/Down walk history.
## `watch <expr>` pins a live readout in the corner (`unwatch` clears).
## Every EventBus log line and cue is mirrored here.

const MAX_LINES := 400
const AUTOLOADS := ["EventBus", "ContentDB", "ClassLibrary", "GameManager", "SaveManager", "CampaignManager", "QuestManager",
	"SceneManager", "CameraManager", "Cues", "AudioManager", "CombatManager", "DispatchManager", "ForgeManager", "VendorSystem", "UIManager"]

var enabled := OS.is_debug_build()
var commands: Dictionary = {}  # name -> {fn, help, args (completion source)}
var history: Array[String] = []
var watches: Array[String] = []
var _hist_i := -1
var _panel: PanelContainer
var _out: RichTextLabel
var _in: LineEdit
var _watch_label: Label
var _lines: Array[String] = []


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	_register_all()
	EventBus.log_message.connect(func(t: String) -> void: print_line("[color=#8a86a8]· %s[/color]" % t))
	Cues.fired.connect(func(id: String, key: String, _c: Dictionary) -> void:
		if visible:
			print_line("[color=#6a6688]cue %s%s[/color]" % [id, "" if key == id else (" → " + key if key != "" else " (undefined)")]))


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_QUOTELEFT:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		_in.grab_focus()
		_in.clear()


# --- Commands --------------------------------------------------------------------

## Where Tab looks for a command's argument.
const ARG_SOURCES := {"give": "items", "kill": "targets", "status": "statuses", "passive": "passives", "cue": "cues",
	"tp": "maps", "spawn": "characters", "help": "commands", "heal": "targets"}


func register(name: String, help: String, fn: Callable) -> void:
	commands[name] = {"fn": fn, "help": help}


func _register_all() -> void:
	register("help", "List commands, or `help <cmd>`.", _cmd_help)
	register("clear", "Clear the console.", func(_a: Array) -> String:
		_lines.clear()
		_out.clear()
		return "")
	register("give", "give <item_id> [qty] — add items.", func(a: Array) -> String:
		if a.is_empty() or ContentDB.get_item(a[0]) == null:
			return _err("Unknown item. Tab completes ids.")
		GameManager.give_item(a[0], int(a[1]) if a.size() > 1 else 1)
		return "Gave %s ×%d." % [a[0], int(a[1]) if a.size() > 1 else 1])
	register("chips", "chips <n> — add microchips.", func(a: Array) -> String:
		GameManager.add_microchips(int(a[0]) if not a.is_empty() else 10)
		return "Microchips: %d" % GameManager.microchips)
	register("coins", "coins <n> — add soul coins.", func(a: Array) -> String:
		GameManager.add_soul_coins(int(a[0]) if not a.is_empty() else 1000)
		return "Soul coins: %d" % GameManager.soul_coins)
	register("flag", "flag <name> [value] — set a story flag (no value = true). `flag` alone lists them.", func(a: Array) -> String:
		if a.is_empty():
			return ", ".join(GameManager.story_flags.keys().map(func(k: String) -> String: return "%s=%s" % [k, GameManager.story_flags[k]]))
		var v: Variant = true if a.size() < 2 else (false if a[1] in ["false", "0", "off"] else (str_to_var(a[1]) if str_to_var(a[1]) != null else a[1]))
		GameManager.set_story_flag(a[0], v)
		return "%s = %s" % [a[0], v])
	register("heal", "heal [all] — full HP/MP for the active unit (or the whole crew).", func(a: Array) -> String:
		var n := 0
		for u in _targets("crew" if a.has("all") or a.has("crew") else "active"):
			u.current_hp = u.get_stat("max_hp")
			u.current_mp = u.get_stat("max_mp")
			u.refresh_stats()
			n += 1
		return "Healed %d unit(s)." % n)
	register("kill", "kill [enemies|active|all] — remove units from the fight.", func(a: Array) -> String:
		var n := 0
		for u in _targets(a[0] if not a.is_empty() else "enemies"):
			u.take_damage(u.current_hp + 9999)
			n += 1
		return "Killed %d unit(s)." % n)
	register("win", "Win the current battle.", func(_a: Array) -> String:
		if CombatManager.state == CombatManager.State.IDLE or CombatManager.grid == null:
			return _err("No battle running.")
		CombatManager._finish(true)
		return "Victory.")
	register("lose", "Lose the current battle.", func(_a: Array) -> String:
		if CombatManager.grid == null:
			return _err("No battle running.")
		CombatManager._finish(false)
		return "Defeat.")
	register("status", "status <status_id> [active|enemies|all] — apply a status.", func(a: Array) -> String:
		if a.is_empty() or ContentDB.get_status(a[0]) == null:
			return _err("Unknown status.")
		var n := 0
		for u in _targets(a[1] if a.size() > 1 else "active"):
			if u.apply_status(a[0]):
				n += 1
		return "%s on %d unit(s)." % [a[0], n])
	register("passive", "passive <passive_id> — equip on the active unit (any slot, learned or not).", func(a: Array) -> String:
		var p := ContentDB.get_passive(a[0]) if not a.is_empty() else null
		var u: Node = CombatManager.active_unit
		if p == null or u == null:
			return _err("Need a passive id and an active unit.")
		u.data.set(p.slot + "_id", p.id)
		u.refresh_stats()
		return "%s equipped %s (%s)." % [u.display_name(), p.display_name, p.slot])
	register("cue", "cue <cue_id> — fire a cue (`cue` alone lists recent ones).", func(a: Array) -> String:
		if a.is_empty():
			return " · ".join(Cues.history.slice(-15))
		Cues.fire(a[0], {"unit": CombatManager.active_unit} if CombatManager.active_unit else {})
		return "Fired %s → %s" % [a[0], Cues.resolve(a[0])])
	register("news", "news <text> — push a headline to every news screen.", func(a: Array) -> String:
		EventBus.broadcast_line.emit("news", " ".join(a))
		return "Headline queued.")
	register("time", "time <scale> — game speed (1 = normal).", func(a: Array) -> String:
		Engine.time_scale = clampf(float(a[0]) if not a.is_empty() else 1.0, 0.05, 8.0)
		return "time_scale = %.2f" % Engine.time_scale)
	register("tp", "tp <map_id> [x,y] — walk a map (explore).", func(a: Array) -> String:
		if a.is_empty() or ContentDB.get_map(a[0]).is_empty():
			return _err("Unknown map.")
		var at := Vector2i(-1, -1)
		if a.size() > 1 and a[1].contains(","):
			at = Vector2i(int(a[1].split(",")[0]), int(a[1].split(",")[1]))
		toggle()
		CampaignManager.explore(a[0], -1, at)
		return "→ " + a[0])
	register("spawn", "spawn <character_id> <x,y> [enemy|player] — drop a unit into the battle.", func(a: Array) -> String:
		if a.size() < 2 or ContentDB.get_character(a[0]) == null or not a[1].contains(","):
			return _err("spawn <character_id> <x,y> [enemy|player]")
		var team := Unit.Team.PLAYER if a.size() > 2 and a[2] == "player" else Unit.Team.ENEMY
		var u := CombatManager.spawn_unit(a[0], Vector2i(int(a[1].split(",")[0]), int(a[1].split(",")[1])), team, 5, team == Unit.Team.ENEMY)
		return ("Spawned %s." % a[0]) if u else _err("Cell blocked or no battle."))
	register("set", "set <Autoload.property> <value> — e.g. set GameManager.soul_coins 500", func(a: Array) -> String:
		if a.size() < 2 or not a[0].contains("."):
			return _err("set <Autoload.property> <value>")
		var obj := get_node_or_null("/root/" + a[0].get_slice(".", 0))
		var prop: String = a[0].get_slice(".", 1)
		if obj == null or not prop in obj:
			return _err("No such property.")
		var v: Variant = str_to_var(" ".join(a.slice(1)))
		obj.set(prop, v if v != null else " ".join(a.slice(1)))
		return "%s = %s" % [a[0], obj.get(prop)])
	register("watch", "watch <expression> — pin a live readout (e.g. watch Engine.get_frames_per_second()).", func(a: Array) -> String:
		watches.append(" ".join(a))
		return "Watching %d expression(s)." % watches.size())
	register("unwatch", "Clear all watches.", func(_a: Array) -> String:
		watches.clear()
		return "Watches cleared.")
	register("fps", "Toggle an FPS watch.", func(_a: Array) -> String:
		var e := "Engine.get_frames_per_second()"
		if watches.has(e):
			watches.erase(e)
		else:
			watches.append(e)
		return "")
	register("reload", "Reload all content JSON, cues and status looks.", func(_a: Array) -> String:
		ContentDB.reload()
		Cues.reload()
		StatusLook._looks.clear()
		Signage._text.clear()
		return "Content reloaded.")
	register("units", "List units in the battle.", func(_a: Array) -> String:
		var rows: Array[String] = []
		for u: Node in CombatManager.units:
			if is_instance_valid(u):
				rows.append("%s%s [%s] HP %d/%d @ %s %s" % ["▶ " if u == CombatManager.active_unit else "", u.display_name(), ["crew", "enemy", "neutral"][clampi(u.team, 0, 2)],
					u.current_hp, u.get_stat("max_hp"), u.cell, StatusLook.status_ids(u)])
		return "\n".join(rows) if not rows.is_empty() else "No battle running.")


func _cmd_help(a: Array) -> String:
	if not a.is_empty() and commands.has(a[0]):
		return str(commands[a[0]]["help"])
	var names := commands.keys()
	names.sort()
	var rows: Array[String] = []
	for n: String in names:
		rows.append("[color=#3ff6ff]%s[/color]  %s" % [n, commands[n]["help"]])
	return "\n".join(rows) + "\nAnything else is evaluated as an expression, e.g. [color=#ffd27a]GameManager.soul_coins[/color]."


func _targets(which: String) -> Array:
	var out: Array = []
	for u: Node in CombatManager.units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		match which:
			"active":
				if u == CombatManager.active_unit:
					out.append(u)
			"enemies":
				if u.team != Unit.Team.PLAYER:
					out.append(u)
			"crew":
				if u.team == Unit.Team.PLAYER:
					out.append(u)
			_:
				out.append(u)
	return out


func _err(t: String) -> String:
	return "[color=#ff4f7a]%s[/color]" % t


## Runs one line: a command, or an expression. Returns what it printed.
func run(line: String) -> String:
	line = line.strip_edges()
	if line == "":
		return ""
	history.append(line)
	_hist_i = -1
	var parts := line.split(" ", false)
	var cmd := parts[0].to_lower()
	var out := ""
	if commands.has(cmd):
		out = str(commands[cmd]["fn"].call(Array(parts.slice(1))))
	else:
		out = evaluate(line)
	print_line("[color=#ffd27a]> %s[/color]" % line)
	if out != "":
		print_line(out)
	return out


## GDScript expression with every autoload (and Engine/OS via the language).
func evaluate(expr: String) -> String:
	var e := Expression.new()
	var names := PackedStringArray()
	var values: Array = []
	for n: String in AUTOLOADS:
		var node := get_node_or_null("/root/" + n)
		if node:
			names.append(n)
			values.append(node)
	for pair: Array in [["Engine", Engine], ["OS", OS], ["Time", Time], ["Input", Input], ["DisplayServer", DisplayServer]]:
		names.append(pair[0])
		values.append(pair[1])
	if e.parse(expr, names) != OK:
		return _err(e.get_error_text())
	var v: Variant = e.execute(values, self, false)
	if e.has_execute_failed():
		return _err(e.get_error_text())
	return var_to_str(v) if not (v is Object) else str(v)


## Tab completion: command names, then ids for the command's argument.
func complete(text: String) -> Array[String]:
	var parts := text.split(" ", true)
	var out: Array[String] = []
	if parts.size() <= 1:
		for n: String in commands:
			if n.begins_with(parts[0]):
				out.append(n)
		out.sort()
		return out
	var src := str(ARG_SOURCES.get(parts[0], ""))
	var pool: Array = []
	match src:
		"items": pool = ContentDB.get_all("items").map(func(r: GameResource) -> String: return r.id)
		"statuses": pool = ContentDB.get_all("status_effects").map(func(r: GameResource) -> String: return r.id)
		"passives": pool = ContentDB.get_all("passives").map(func(r: GameResource) -> String: return r.id)
		"characters": pool = ContentDB.get_all("characters").map(func(r: GameResource) -> String: return r.id)
		"maps": pool = ContentDB.maps.keys()
		"cues": pool = Cues.cues.keys()
		"commands": pool = commands.keys()
		"targets": pool = ["enemies", "active", "crew", "all"]
	for id: Variant in pool:
		if str(id).begins_with(parts[-1]):
			out.append(str(id))
	out.sort()
	return out


func print_line(t: String) -> void:
	_lines.append(t)
	if _lines.size() > MAX_LINES:
		_lines.pop_front()
	if _out:
		_out.append_text(t + "\n")


# --- UI --------------------------------------------------------------------------

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.custom_minimum_size.y = 340
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.01, 0.07, 0.93)
	sb.border_color = Color(0.25, 0.95, 1.0, 0.6)
	sb.border_width_bottom = 2
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	_out = RichTextLabel.new()
	_out.bbcode_enabled = true
	_out.scroll_following = true
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out.add_theme_font_override("normal_font", NeonTheme.mono())
	_out.add_theme_font_size_override("normal_font_size", 14)
	v.add_child(_out)
	_in = LineEdit.new()
	_in.placeholder_text = "command or expression — help · Tab completes · ` closes"
	_in.add_theme_font_override("font", NeonTheme.mono())
	_in.text_submitted.connect(func(t: String) -> void:
		run(t)
		_in.clear())
	_in.gui_input.connect(_on_input_key)
	v.add_child(_in)
	_watch_label = Label.new()
	_watch_label.anchor_left = 1.0
	_watch_label.anchor_right = 1.0
	_watch_label.offset_left = -560
	_watch_label.offset_right = -14
	_watch_label.offset_top = 352
	_watch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_watch_label.add_theme_font_override("font", NeonTheme.mono())
	_watch_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.7))
	_watch_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_watch_label.add_theme_constant_override("outline_size", 4)
	add_child(_watch_label)
	print_line("[color=#3ff6ff]BEYOND // DEV CONSOLE[/color]  type [color=#ffd27a]help[/color]")


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_UP, KEY_DOWN:
			if history.is_empty():
				return
			_hist_i = clampi((history.size() if _hist_i < 0 else _hist_i) + (-1 if event.keycode == KEY_UP else 1), 0, history.size() - 1)
			_in.text = history[_hist_i]
			_in.caret_column = _in.text.length()
			_in.accept_event()
		KEY_TAB:
			var opts := complete(_in.text)
			if opts.size() == 1:
				var parts := _in.text.split(" ", true)
				parts[parts.size() - 1] = opts[0]
				_in.text = " ".join(parts) + " "
				_in.caret_column = _in.text.length()
			elif opts.size() > 1:
				print_line("[color=#6a6688]%s[/color]" % "  ".join(opts.slice(0, 40)))
			_in.accept_event()
		KEY_QUOTELEFT:
			toggle()
			_in.accept_event()


func _process(_d: float) -> void:
	if watches.is_empty():
		_watch_label.text = ""
		return
	var rows: Array[String] = []
	for w in watches:
		rows.append("%s = %s" % [w, evaluate(w).replace("[color=#ff4f7a]", "").replace("[/color]", "")])
	_watch_label.text = "\n".join(rows)
