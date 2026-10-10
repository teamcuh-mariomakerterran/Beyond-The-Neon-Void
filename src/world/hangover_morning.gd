class_name HangoverMorning
extends Control
## The morning after a chapter's last job: the crew is still at the Neon
## Gutter. A tiny turn-based social round:
##   1. SEATING: swap who sits where (neighbours and whoever's across matter)
##   2. ROUNDS (3): each crew member, in seat order, does one thing:
##        TOAST         +4 bond with everyone next to / across from them
##        ROAST <who>   friends laugh (+8); strangers: it lands (+6) or it's too soon (−3)
##        BUY A ROUND   60 ◈: everyone +2 with everyone, the buyer +2 more
##        NURSE IT      shakes off the hangover, +1 with neighbours
##   3. RESULTS: bond changes, level-ups and the Bar Stories they unlock
## Bonds feed Duo Techs (Last Call). Data: data/bar_stories.json.

const SCENE := "res://scenes/hub/hangover_morning.tscn"
const SEATS := 6
const ROUNDS := 3
const ROUND_COST := 60
const TOAST_XP := 4
const ROAST_FRIEND_XP := 8
const ROAST_LAND_XP := 6
const ROAST_FLOP_XP := -3

enum Phase { SEATING, ROUNDS, RESULTS }

var phase: Phase = Phase.SEATING
## seat index -> character id ("" = empty stool)
var seats: Array[String] = []
var round_no: int = 1
var turn_seat: int = 0
var rng := RandomNumberGenerator.new()
var _start_xp: Dictionary = {}  # pair key -> xp at the start
var _ups: Array = []  # [a, b, level]
var _picked: int = -1  # seating / roast target pick
var _roasting: bool = false
var _pops: Array = []  # floating text: {pos, text, color, t}
var _flash: Dictionary = {}  # seat -> time
var _panel: VBoxContainer
var _title: Label
var _log: RichTextLabel


func _ready() -> void:
	rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = NeonTheme.get_theme()
	var crew: Array[String] = []
	for c: CharacterData in GameManager.get_party_members():
		crew.append(c.id)
	setup(crew)
	_build_ui()
	_refresh()
	AudioManager.play_music("neon_gutter")
	Sfx.ambience("hangover_morning")


## Seats the crew (first SEATS of them) in party order. Public for tests.
func setup(crew: Array) -> void:
	seats.clear()
	for i in SEATS:
		seats.append(str(crew[i]) if i < crew.size() else "")
	_start_xp.clear()
	for i in crew.size():
		for j in range(i + 1, crew.size()):
			var k := Bonds.key(str(crew[i]), str(crew[j]))
			_start_xp[k] = Bonds.xp(str(crew[i]), str(crew[j]))


# --- Rules (UI-free, tested headlessly) --------------------------------------------

## Seats next to `s` on the same side, plus the one straight across.
static func neighbors(s: int) -> Array[int]:
	var out: Array[int] = []
	var side := s / 3
	var col := s % 3
	if col > 0: out.append(s - 1)
	if col < 2: out.append(s + 1)
	out.append(col + (0 if side == 1 else 3))
	return out


func neighbor_ids(s: int) -> Array[String]:
	var out: Array[String] = []
	for n in neighbors(s):
		if seats[n] != "":
			out.append(seats[n])
	return out


func swap(a: int, b: int) -> void:
	var t := seats[a]
	seats[a] = seats[b]
	seats[b] = t


func _add(a: String, b: String, n: int) -> void:
	var lv := Bonds.add(a, b, n)
	if lv >= 0:
		_ups.append([a, b, lv])


func toast(s: int) -> String:
	var me := seats[s]
	var n := TOAST_XP / 2 if GameManager.hungover.has(me) else TOAST_XP
	for o in neighbor_ids(s):
		_add(me, o, n)
	return "%s raises a glass%s. \"To not being dead!\"" % [_n(me), " and winces" if n < TOAST_XP else ""]


## Returns [text, xp] for the roast of seat `t` by seat `s`.
func roast(s: int, t: int) -> Array:
	var me := seats[s]
	var them := seats[t]
	var xp := ROAST_FRIEND_XP
	var text := "%s roasts %s. The table loses it." % [_n(me), _n(them)]
	if Bonds.level(me, them) == 0:
		if rng.randf() < 0.6:
			xp = ROAST_LAND_XP
			text = "%s roasts %s. It lands. Grudging respect." % [_n(me), _n(them)]
		else:
			xp = ROAST_FLOP_XP
			text = "%s roasts %s. Too soon. Way too soon." % [_n(me), _n(them)]
	_add(me, them, xp)
	return [text, xp]


func buy_round(s: int) -> String:
	if not GameManager.spend_soul_coins(ROUND_COST):
		return ""
	var me := seats[s]
	var at_table: Array[String] = []
	for id in seats:
		if id != "":
			at_table.append(id)
	for i in at_table.size():
		for j in range(i + 1, at_table.size()):
			_add(at_table[i], at_table[j], 2)
	for o in at_table:
		if o != me:
			_add(me, o, 2)
	return "%s buys a round. The bartender looks almost happy." % _n(me)


func nurse(s: int) -> String:
	var me := seats[s]
	GameManager.hungover.erase(me)
	for o in neighbor_ids(s):
		_add(me, o, 1)
	return "%s nurses a coffee in silence. Quiet solidarity." % _n(me)


## Next seat with somebody in it; wraps into the next round.
func advance() -> void:
	var tries := 0
	while tries < SEATS * 2:
		turn_seat += 1
		if turn_seat >= SEATS:
			turn_seat = 0
			round_no += 1
		tries += 1
		if round_no > ROUNDS:
			phase = Phase.RESULTS
			return
		if seats[turn_seat] != "":
			return


func first_turn() -> void:
	phase = Phase.ROUNDS
	round_no = 1
	turn_seat = 0
	if seats[0] == "":
		advance()


## Bond changes this morning: [{a, b, from, to}] (changed pairs only).
func changes() -> Array:
	var out: Array = []
	for k: String in _start_xp:
		var p := k.split("|")
		var now := Bonds.xp(p[0], p[1])
		if now != int(_start_xp[k]):
			out.append({"a": p[0], "b": p[1], "from": int(_start_xp[k]), "to": now})
	return out


## Bar Stories unlocked by current bonds and not yet told.
static func stories_ready() -> Array:
	var out: Array = []
	for st: Variant in _stories():
		if st is Dictionary and not GameManager.check_story_flag("barstory:" + str(st["id"])) \
				and Bonds.level(str(st["a"]), str(st["b"])) >= int(st.get("level", 1)):
			out.append(st)
	return out


static func _stories() -> Array:
	var p := "res://data/bar_stories.json"
	if not FileAccess.file_exists(p):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d.get("stories", []) if d is Dictionary else []


## Morning's over: the bar empties, the flag clears.
func finish() -> void:
	GameManager.story_flags.erase("hangover_pending")


static func _n(id: String) -> String:
	var c := GameManager.get_character(id)
	return c.display_name.split(" ")[0] if c else id


# --- Presentation --------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.015, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)
	_title = NeonTheme.label("", 30, NeonTheme.AMBER)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 24
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.AMBER, 0.5)))
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -380
	side.offset_right = -16
	side.offset_top = 90
	side.offset_bottom = -16
	add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	side.add_child(sv)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 6)
	sv.add_child(_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 13)
	sv.add_child(_log)


## Table centre and scale (the room left of the side panel).
func _table() -> Array:
	var k := clampf(size.y / 900.0, 0.7, 1.6)
	return [Vector2((size.x - 400.0) * 0.5, size.y * 0.58), k]


func _seat_pos(s: int) -> Vector2:
	var t := _table()
	var c: Vector2 = t[0]
	var k: float = t[1]
	var along := Vector2(150, 75) * k
	var off := Vector2(110, -55) * k
	# Seats 0-2 on the far side, 3-5 on the near side, facing each other.
	return c + along * float(s % 3 - 1) + off * (1.0 if s / 3 == 0 else -1.0)


func _refresh() -> void:
	for ch in _panel.get_children():
		ch.queue_free()
	match phase:
		Phase.SEATING:
			_title.text = "☀ HANGOVER MORNING"
			_panel.add_child(_wrap("The crew never went home. Pick who sits where: click two people (or a person and an empty stool) to swap. Neighbours and whoever's across the table are who you'll bond with."))
			_button("START THE MORNING", func() -> void:
				first_turn()
				_refresh())
		Phase.ROUNDS:
			var me := seats[turn_seat]
			_title.text = "ROUND %d / %d  ·  %s" % [round_no, ROUNDS, _n(me).to_upper()]
			_panel.add_child(_wrap("%s's move.%s" % [_n(me), "  (hungover)" if GameManager.hungover.has(me) else ""]))
			if _roasting:
				_panel.add_child(_wrap("Roast who? Click someone next to or across from %s." % _n(me)))
				_button("NEVER MIND", func() -> void:
					_roasting = false
					_refresh())
				return
			_button("TOAST  (+%d with neighbours)" % TOAST_XP, func() -> void: _act(toast(turn_seat)))
			var roast_cb := func() -> void:
				_roasting = true
				_refresh()
			_button("ROAST SOMEONE", roast_cb, neighbor_ids(turn_seat).is_empty())
			_button("BUY A ROUND  (%d ◈ · you have %d)" % [ROUND_COST, GameManager.soul_coins], func() -> void: _act(buy_round(turn_seat)), GameManager.soul_coins < ROUND_COST)
			_button("NURSE IT", func() -> void: _act(nurse(turn_seat)))
		Phase.RESULTS:
			_title.text = "LAST NIGHT, RECONSTRUCTED"
			var ch := changes()
			if ch.is_empty():
				_panel.add_child(_wrap("Nobody said anything worth remembering."))
			for c: Dictionary in ch:
				var d := int(c["to"]) - int(c["from"])
				_panel.add_child(_wrap("%s & %s  %+d  ·  %s" % [_n(c["a"]), _n(c["b"]), d, Bonds.level_name(c["a"], c["b"])], NeonTheme.GREEN if d > 0 else NeonTheme.MAGENTA))
			for up: Array in _ups:
				_panel.add_child(_wrap("▲ %s & %s are now %s%s" % [_n(up[0]), _n(up[1]), Bonds.NAMES[int(up[2])], "  — DUO TECH unlocked" if int(up[2]) == Bonds.DUO_LEVEL else ""], NeonTheme.AMBER))
			for st: Dictionary in stories_ready():
				_button("📖 BAR STORY: " + str(st.get("title", "")), func() -> void: _tell(st))
			_button("BACK TO THE BAR", func() -> void:
				finish()
				CampaignManager.return_to_hub())


func _tell(st: Dictionary) -> void:
	GameManager.set_story_flag("barstory:" + str(st["id"]))
	var box := UIManager.get_dialogue_box()
	for l: Variant in st.get("lines", []):
		if l is Dictionary:
			box.say(_n(str(l.get("who", ""))) if str(l.get("who", "")) != "" else "", str(l.get("text", "")))
		else:
			box.say("", str(l))
	await box.finished
	_refresh()


func _act(text: String) -> void:
	if text == "":
		return
	_log.append_text(text + "\n")
	_flash[turn_seat] = Time.get_ticks_msec() / 1000.0
	_pop(_seat_pos(turn_seat) + Vector2(0, -70), "♪" if text.contains("glass") else "!", NeonTheme.AMBER)
	_roasting = false
	advance()
	_refresh()
	queue_redraw()


func _pop(at: Vector2, text: String, col: Color) -> void:
	_pops.append({"pos": at, "text": text, "color": col, "t": Time.get_ticks_msec() / 1000.0})


func _button(text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(cb)
	_panel.add_child(b)
	return b


func _wrap(text: String, col: Color = NeonTheme.TEXT) -> Label:
	var l := NeonTheme.label(text, 14, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 330
	return l


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit := -1
	for s in SEATS:
		if _seat_pos(s).distance_to(mb.position) < 44:
			hit = s
	if hit < 0:
		return
	if phase == Phase.SEATING:
		if _picked < 0:
			_picked = hit
		else:
			swap(_picked, hit)
			_picked = -1
		queue_redraw()
	elif phase == Phase.ROUNDS and _roasting and neighbors(turn_seat).has(hit) and seats[hit] != "":
		var r := roast(turn_seat, hit)
		_pop(_seat_pos(hit) + Vector2(0, -70), "HA!" if int(r[1]) > 0 else "…", NeonTheme.GREEN if int(r[1]) > 0 else NeonTheme.MAGENTA)
		_act(str(r[0]))


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := NeonTheme.mono()
	var now := Time.get_ticks_msec() / 1000.0
	var t := _table()
	var c: Vector2 = t[0]
	var k: float = t[1]
	var room_w := size.x - 400.0
	# Back wall + bar shelf full of bottles.
	draw_rect(Rect2(0, 0, room_w, size.y * 0.42), Color(0.06, 0.03, 0.09))
	draw_rect(Rect2(0, size.y * 0.42 - 6, room_w, 6), Color(0.9, 0.4, 1.2, 0.6))
	for row in 2:
		var y := size.y * (0.2 + row * 0.1)
		draw_rect(Rect2(30, y, room_w * 0.55, 5), Color(0.35, 0.18, 0.1))
		for i in 22:
			var h := 18.0 + float((i * 37 + row * 11) % 14)
			var hue := fmod(float(i * 0.13 + row * 0.31), 1.0)
			var bc := Color.from_hsv(hue, 0.55, 0.9, 0.8)
			draw_rect(Rect2(40 + i * room_w * 0.024, y - h, 9, h), bc)
			draw_rect(Rect2(42 + i * room_w * 0.024, y - h - 5, 5, 5), bc.darkened(0.3))
	# The window: morning sun, far too bright for anyone here.
	var win := Rect2(room_w * 0.66, size.y * 0.08, room_w * 0.26, size.y * 0.26)
	draw_rect(win, Color(2.2, 1.9, 1.3))
	draw_rect(Rect2(win.position.x + win.size.x * 0.5 - 3, win.position.y, 6, win.size.y), Color(0.1, 0.06, 0.1))
	draw_rect(Rect2(win.position.x, win.position.y + win.size.y * 0.5 - 3, win.size.x, 6), Color(0.1, 0.06, 0.1))
	var beam_a := 0.10 + 0.03 * sin(now * 0.7)
	draw_colored_polygon(PackedVector2Array([win.position, win.position + Vector2(win.size.x, 0), c + Vector2(260, 260) * k, c + Vector2(-160, 260) * k]), Color(1.6, 1.4, 0.9, beam_a))
	for i in 24:
		var ph := float(i) * 1.7
		var mote := Vector2(win.position.x + fmod(ph * 37.0 + now * 9.0, win.size.x + 220.0) - 110.0, win.end.y + fmod(ph * 53.0 + now * 14.0, size.y * 0.45))
		draw_circle(mote, 1.6, Color(2.0, 1.8, 1.2, 0.35 + 0.25 * sin(now * 2.0 + ph)))
	# Neon sign, flickering like it's also hungover.
	var flick := 0.0 if fmod(now, 3.7) < 0.08 or fmod(now, 5.3) < 0.05 else 1.0
	var sign := "THE NEON GUTTER"
	for g in [6.0, 3.0]:
		draw_string(font, Vector2(42 + g * 0.2, 96), sign, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(2.0, 0.3, 1.4, 0.12 * flick))
	draw_string(font, Vector2(40, 94), sign, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(2.4, 0.5, 1.8, (0.6 + 0.4 * sin(now * 2.0)) * flick))
	draw_string(font, Vector2(44, 122), "OPEN (TECHNICALLY)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 1.8, 2.0, 0.8 * flick))
	# Floor: an iso grid fading out.
	for i in range(-6, 7):
		var a0 := c + Vector2(150, 75) * k * float(i) + Vector2(-110, 55) * k * 4.0
		var a1 := c + Vector2(150, 75) * k * float(i) + Vector2(110, -55) * k * 4.0
		draw_line(a0, a1, Color(0.5, 0.3, 0.8, 0.07), 1.0)
		var b0 := c + Vector2(110, -55) * k * float(i) + Vector2(-150, -75) * k * 4.0
		var b1 := c + Vector2(110, -55) * k * float(i) + Vector2(150, 75) * k * 4.0
		draw_line(b0, b1, Color(0.5, 0.3, 0.8, 0.07), 1.0)
	# The table: an iso slab between the two rows of stools.
	var along := Vector2(150, 75) * k
	var off := Vector2(110, -55) * k
	var corners := PackedVector2Array([c - along * 1.55 - off * 0.5, c - along * 1.55 + off * 0.5, c + along * 1.55 + off * 0.5, c + along * 1.55 - off * 0.5])
	var drop := Vector2(0, 22 * k)
	draw_colored_polygon(PackedVector2Array([corners[0], corners[3], corners[3] + drop, corners[0] + drop]), Color(0.14, 0.07, 0.05))
	draw_colored_polygon(PackedVector2Array([corners[3], corners[2], corners[2] + drop, corners[3] + drop]), Color(0.1, 0.05, 0.04))
	draw_colored_polygon(corners, Color(0.3, 0.16, 0.09))
	corners.append(corners[0])
	draw_polyline(corners, Color(1.4, 0.7, 0.35, 0.9), 2.0)
	# Last night's wreckage: mugs, a tipped bottle, a coaster plan.
	for i in 6:
		var mug := c + along * (-1.2 + i * 0.48) + off * (0.18 if i % 2 == 0 else -0.2) + Vector2(sin(now * 1.3 + i) * 1.5, 0)
		draw_rect(Rect2(mug - Vector2(6, 12) * k, Vector2(12, 14) * k), Color(1.6, 1.2, 0.45, 0.85))
		draw_rect(Rect2(mug - Vector2(6, 15) * k, Vector2(12, 4) * k), Color(2.0, 2.0, 1.8, 0.7))
	# Bond lines between neighbours, brighter the closer they are.
	for s in SEATS:
		for n in neighbors(s):
			if n > s and seats[s] != "" and seats[n] != "":
				var lv := Bonds.level(seats[s], seats[n])
				draw_dashed_line(_seat_pos(s), _seat_pos(n), Color(1.6, 0.9, 0.3, 0.15 + 0.2 * lv), 1.0 + lv, 6.0)
	for s in SEATS:
		var p := _seat_pos(s)
		var id := seats[s]
		# Stool.
		draw_line(p + Vector2(0, 20) * k, p + Vector2(0, 48) * k, Color(0.5, 0.45, 0.6), 4.0)
		draw_circle(p + Vector2(0, 20) * k, 24 * k, Color(0.16, 0.1, 0.22))
		if id == "":
			draw_arc(p, 30 * k, 0, TAU, 28, Color(0.6, 0.5, 0.8, 0.4), 1.5)
			continue
		var col := Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.55, 1.0)
		var lit := float(_flash.get(s, -9.0))
		var glow := clampf(1.0 - (now - lit) * 2.0, 0.0, 1.0)
		var bob := sin(now * 1.6 + s) * 2.0 * k
		var pp := p + Vector2(0, bob)
		var active := phase == Phase.ROUNDS and s == turn_seat
		if active or s == _picked:
			draw_arc(pp, (40 + sin(now * 6.0) * 2.0) * k, 0, TAU, 32, NeonTheme.AMBER, 3.0)
		draw_circle(pp, (30 + 4 * glow) * k, Color(col.r * (0.7 + glow), col.g * (0.7 + glow), col.b * (0.7 + glow), 0.95))
		var cd := GameManager.get_character(id)
		var tex: Texture2D = ForgeStore.load_texture(cd.portrait_path) if cd and cd.portrait_path != "" else null
		if tex:
			draw_texture_rect(tex, Rect2(pp - Vector2(26, 26) * k, Vector2(52, 52) * k), false)
		else:
			draw_string(font, pp + Vector2(-15, 8) * k, _n(id).left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * k), NeonTheme.BG)
		draw_string(font, pp + Vector2(-50, 56) * k, _n(id), HORIZONTAL_ALIGNMENT_CENTER, 100 * k, int(14 * k), NeonTheme.TEXT)
		if GameManager.hungover.has(id):
			for z in 3:
				var zt := fmod(now * 0.6 + z * 0.33, 1.0)
				draw_string(font, pp + Vector2(22 + zt * 14, -24 - zt * 30) * k, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int((12 + zt * 8) * k), Color(0.6, 0.7, 1.4, 1.0 - zt))
	for p2: Dictionary in _pops.duplicate():
		var age := now - float(p2["t"])
		if age > 1.2:
			_pops.erase(p2)
			continue
		var col2: Color = p2["color"]
		draw_string(font, p2["pos"] + Vector2(0, -40 * age), str(p2["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(col2, 1.0 - age / 1.2))
	# Hangover vignette: the edges are too much right now.
	draw_rect(Rect2(0, 0, room_w, size.y), Color(0, 0, 0, 0.0))
