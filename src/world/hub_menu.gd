extends Control
## The Neon Gutter — the crew's dive bar and the game's hub (menu version).
##
## Tabs: Missions, Crew (jobs + terminal), Bar & Shops, Dispatch, Forge, Save.
## A walkable hub (the old HubWorld.gd idea) can replace this later; every tab
## just calls the same systems, so nothing here is throwaway logic.

var _content: VBoxContainer
var _coins: Label
var _ticker: Label
var _ticker_lines: Array[String] = []
var _selected_char: String = ""
var _tab: String = "missions"


func _ready() -> void:
	theme = NeonTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = NeonTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	_build_top(root)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	pad.add_child(body)
	root.add_child(pad)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 250
	nav.add_theme_constant_override("separation", 8)
	body.add_child(nav)
	for entry in [["missions", "MISSIONS"], ["crew", "CREW & TERMINAL"], ["shops", "BAR & SHOPS"], ["dispatch", "DISPATCH"], ["forge", "FORGE"], ["system", "SAVE / QUIT"]]:
		var b := Button.new()
		b.text = entry[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 46
		var id: String = entry[0]
		b.pressed.connect(func() -> void: _show(id))
		nav.add_child(b)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	_build_ticker(root)
	EventBus.soul_coins_changed.connect(func(_t: int) -> void: _refresh_top())
	EventBus.broadcast_line.connect(func(_c: String, text: String) -> void: _ticker_lines.push_front(text))
	DispatchManager.assignment_resolved.connect(func(_a: Dictionary, _s: bool, _r: Dictionary) -> void: if _tab == "dispatch": _show("dispatch"))
	GameManager.hub_visits_count += 1
	AudioManager.play_music("neon_gutter")
	_selected_char = GameManager.active_party[0] if not GameManager.active_party.is_empty() else ""
	_show("missions")


# --- Frame -----------------------------------------------------------------

func _build_top(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", NeonTheme.panel_box(NeonTheme.GREEN, Color(0.04, 0.02, 0.08, 0.95)))
	root.add_child(bar)
	var h := HBoxContainer.new()
	bar.add_child(h)
	var title := NeonTheme.label("THE NEON GUTTER", 30, Color(0.4, 2.0, 1.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title)
	_coins = NeonTheme.label("", 18, NeonTheme.AMBER)
	h.add_child(_coins)
	_refresh_top()


func _refresh_top() -> void:
	if _coins:
		_coins.text = "◈ %d SOUL COINS    ⌗ %d MICROCHIPS    ⏲ HOUR %d" % [GameManager.soul_coins, GameManager.microchips, CampaignManager.world_clock]


func _build_ticker(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", NeonTheme.panel_box(NeonTheme.MAGENTA, Color(0.1, 0.01, 0.05, 0.95)))
	bar.clip_contents = true
	root.add_child(bar)
	_ticker = NeonTheme.label("", 15, Color(1.6, 0.6, 1.0))
	bar.add_child(_ticker)
	for r: Dictionary in ContentDB.rumors.values():
		if r.get("channel") == "news":
			_ticker_lines.append(str(r["text"]))
	_ticker_lines.shuffle()
	_next_ticker()


func _next_ticker() -> void:
	if _ticker_lines.is_empty():
		return
	var line: String = _ticker_lines.pop_front()
	_ticker_lines.append(line)
	_ticker.text = "DOCTRINE NEWS  ▸  " + line
	_ticker.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_ticker, "modulate:a", 1.0, 0.4)
	t.tween_interval(6.0)
	t.tween_property(_ticker, "modulate:a", 0.0, 0.4)
	t.tween_callback(_next_ticker)


func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()


func _h(text: String, color: Color = NeonTheme.CYAN) -> void:
	_content.add_child(NeonTheme.label(text, 24, color))


func _p(text: String, color: Color = NeonTheme.TEXT_DIM, size: int = 15) -> Label:
	var l := NeonTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable, disabled: bool = false, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.tooltip_text = tip
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_content.add_child(h)
	return h


func _toast(text: String) -> void:
	_refresh_top()
	var l := _p(text, NeonTheme.AMBER, 16)
	_content.move_child(l, 0)


func _show(tab: String) -> void:
	_tab = tab
	_clear()
	_refresh_top()
	match tab:
		"missions": _tab_missions()
		"crew": _tab_crew()
		"shops": _tab_shops()
		"dispatch": _tab_dispatch()
		"forge": _tab_forge()
		"system": _tab_system()


# --- Tabs ------------------------------------------------------------------

func _tab_missions() -> void:
	_h("JOB BOARD")
	_p("Pinned behind the bar under a coaster that says 'NOT A JOB BOARD'.")
	for mid in CampaignManager.unlocked_missions:
		var m := ContentDB.get_mission(mid)
		if m == null:
			continue
		var panel := PanelContainer.new()
		_content.add_child(panel)
		var v := VBoxContainer.new()
		panel.add_child(v)
		v.add_child(NeonTheme.label(("✔ " if CampaignManager.is_completed(mid) else "") + m.display_name.to_upper(), 20, NeonTheme.GREEN))
		var brief := NeonTheme.label(m.briefing, 14, NeonTheme.TEXT_DIM)
		brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(brief)
		v.add_child(NeonTheme.label("%s   //   Win: %s" % [m.get_total_reward_text(), m.win_condition.replace("_", " ")], 13, NeonTheme.AMBER))
		_btn(v, "DEPLOY THE CREW", func() -> void: CampaignManager.start_mission(mid), GameManager.get_party_members().is_empty())


func _tab_crew() -> void:
	_h("THE CREW")
	var pick := _row()
	for id: String in GameManager.roster:
		var c: CharacterData = GameManager.roster[id]
		var in_party := GameManager.active_party.has(id)
		var b := _btn(pick, ("★ " if in_party else "") + c.display_name.split(" ")[0] + (" (out)" if c.is_dispatched else ""), func() -> void: _selected_char = id; _show("crew"))
		if id == _selected_char:
			b.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.25), NeonTheme.GREEN))
	var c := GameManager.get_character(_selected_char)
	if c == null:
		return
	var st := c.get_stats()
	var cls := ContentDB.get_class_res(c.class_id)
	_p("%s — LV %d %s   (class LV %d)" % [c.display_name, st.level, cls.display_name if cls else c.class_id, c.get_class_level(c.class_id)], NeonTheme.TEXT, 18)
	_p(c.bio)
	var calc := st.duplicate_stats()
	calc.calculate(cls)
	_p("HP %d  MP %d  ATK %d  DEF %d  MAG %d  SPD %d  MOVE %d  JUMP %d" % [calc.get_stat("max_hp"), calc.get_stat("max_mp"), calc.get_stat("attack"), calc.get_stat("defense"), calc.get_stat("magic"), calc.get_stat("speed"), calc.get_stat("move"), calc.get_stat("jump")], NeonTheme.CYAN)
	var party_row := _row()
	var in_party := GameManager.active_party.has(c.id)
	_btn(party_row, "REMOVE FROM PARTY" if in_party else "ADD TO PARTY", func() -> void:
		var ids := GameManager.active_party.duplicate()
		if in_party: ids.erase(c.id)
		elif ids.size() < GameManager.MAX_PARTY_SIZE: ids.append(c.id)
		GameManager.set_active_party(ids)
		_show("crew"))
	_h("JOBS", NeonTheme.VIOLET)
	var grid := GridContainer.new()
	grid.columns = 4
	_content.add_child(grid)
	for jc in ClassLibrary.get_all_classes():
		var unlocked := c.get_class_level(jc.id) > 0 or ClassLibrary.is_unlocked_for(jc.id, c)
		if jc.is_hidden and not unlocked:
			var secret := Button.new()
			secret.text = "??? SECRET"
			secret.disabled = true
			grid.add_child(secret)
			continue
		var req := ", ".join(jc.unlock_requirements.keys().map(func(k: String) -> String: return "%s %d" % [ContentDB.get_class_res(k).display_name, jc.unlock_requirements[k]]))
		var label := "%s%s" % [jc.display_name, (" L%d" % c.get_class_level(jc.id)) if c.get_class_level(jc.id) > 0 else ""]
		var jb := _btn(grid, ("▶ " if jc.id == c.class_id else "") + label, func() -> void:
			ProgressionSystem.change_class(c, jc.id)
			_show("crew"), not unlocked, "%s\n%s\nRequires: %s" % [jc.display_name, jc.description, req if req != "" else "—"])
		jb.custom_minimum_size.x = 210
	_h("TERMINAL  —  SLOT MICROCHIPS", NeonTheme.VIOLET)
	_p("Every chip was pried from someone who used to know this. Try not to think about it.")
	if cls:
		for aid in cls.learnable_ability_ids:
			var a := ContentDB.get_ability(aid)
			if a == null:
				continue
			var r := _row()
			var known := c.learned_ability_ids.has(aid)
			var cost_txt := "BLUE MAGIC — take the hit to learn" if a.absorb_only else "%d chips" % a.chip_cost
			_btn(r, "LEARNED" if known else "LEARN (%s)" % cost_txt, func() -> void:
				var err := ProgressionSystem.learn_ability(c, aid)
				_show("crew")
				_toast(err if err != "" else "%s learned %s." % [c.display_name, a.display_name]), known or a.absorb_only or GameManager.microchips < a.chip_cost)
			r.add_child(NeonTheme.label("%s — %s" % [a.display_name, a.description], 14, NeonTheme.TEXT if known else NeonTheme.TEXT_DIM))


func _tab_shops() -> void:
	_h("BAR & SHOPS")
	for vid: String in ContentDB.vendors:
		var v: Dictionary = ContentDB.vendors[vid]
		_p(str(v.get("name", vid)).to_upper(), NeonTheme.GREEN, 19)
		_p("\"%s\"" % v.get("greeting", ""))
		for s in VendorSystem.available_stock(vid):
			var sid: String = s["id"]
			var item := ContentDB.get_item(sid)
			var card := ContentDB.get_card(sid)
			var nm := item.display_name if item else (card.display_name if card else sid)
			var desc := item.description if item else (card.description if card else "")
			var r := _row()
			_btn(r, "BUY  ◈%d" % s["price"], func() -> void:
				var err := VendorSystem.buy_item(vid, sid)
				_show("shops")
				_toast(err if err != "" else "Bought %s." % nm), GameManager.soul_coins < int(s["price"]))
			r.add_child(NeonTheme.label("%s%s — %s" % [nm, "" if int(s["qty_left"]) < 0 else " (%d left)" % s["qty_left"], desc], 14))
	_h("SELL JUNK", NeonTheme.VIOLET)
	for id: String in GameManager.stack_items:
		var item := ContentDB.get_item(id)
		if item == null or item.category != ItemResource.Category.MATERIAL:
			continue
		var r := _row()
		_btn(r, "SELL 1  ◈%d" % roundi(item.value * 0.5), func() -> void: VendorSystem.sell_stack(id, 1); _show("shops"))
		r.add_child(NeonTheme.label("%s x%d%s" % [item.display_name, GameManager.stack_items[id], "  (junk)" if item.material_grade == 0 else ""], 14))


func _tab_dispatch() -> void:
	_h("DISPATCH BOARD")
	_p("Send someone out on an errand. They come back with loot, a story, or both. Timers keep running while the game is closed.")
	for id: String in DispatchManager.active:
		var a: Dictionary = DispatchManager.active[id]
		var m := ContentDB.get_dispatch_mission(a["mission_id"])
		var who := GameManager.get_character(a["character_id"])
		_p("⏳ %s — %s  (%d min left)" % [who.display_name if who else "?", m.display_name if m else "?", ceili(DispatchManager.time_left(id) / 60.0)], NeonTheme.AMBER)
	for rec: Dictionary in DispatchManager.completed_log.slice(-3):
		var rw: Dictionary = rec["rewards"]
		_p("%s %s — %s %s" % ["✔" if rec["success"] else "✘", rec["character_id"], rw.get("text", ""), ("  Heard: \"%s\"" % rw["rumor"]) if rw.get("rumor", "") != "" else ""], NeonTheme.GREEN if rec["success"] else NeonTheme.MAGENTA, 14)
	var who := GameManager.get_character(_selected_char)
	_p("Sending: %s  (pick in the Crew tab)" % (who.display_name if who else "nobody"), NeonTheme.CYAN)
	for m: DispatchMission in ContentDB.get_all("dispatch_missions"):
		var r := _row()
		var err := DispatchManager.can_dispatch(m.id, _selected_char)
		var chance := DispatchManager.success_chance(m, who) if who else 0.0
		_btn(r, "SEND (%d%%)" % roundi(chance * 100), func() -> void: DispatchManager.start_dispatch(m.id, _selected_char); _show("dispatch"), err != "", err)
		r.add_child(NeonTheme.label("%s — %d min — %s" % [m.display_name, roundi(m.duration_minutes), m.description], 14))


func _tab_forge() -> void:
	_h("THE FORGE")
	_p("Feed materials to gear to level it (max 50). At level 10+ it can EVOLVE. Evolve early for a quick boost — or wait: every level past 10 adds +2% permanent potential to the evolved item.")
	for uid: String in GameManager.item_instances:
		var inst: Dictionary = GameManager.item_instances[uid]
		var item := ContentDB.get_item(inst["item_id"])
		if item == null:
			continue
		var r := _row()
		r.add_child(NeonTheme.label("%s  LV%d  (%d/%d xp)  potential x%.2f" % [item.display_name, inst["level"], inst["xp"], ForgeManager.xp_to_next(inst["level"]), float(inst.get("potential", 1.0))], 14))
		var feed := {}
		for mid: String in GameManager.stack_items:
			var mat := ContentDB.get_item(mid)
			if mat and mat.category == ItemResource.Category.MATERIAL and mat.material_grade <= 1:
				feed[mid] = 1
				break
		_btn(r, "FEED MATERIAL", func() -> void: ForgeManager.upgrade(uid, feed); _show("forge"), feed.is_empty())
		for recipe in ForgeManager.get_evolutions(uid):
			var to := ContentDB.get_item(recipe["to"])
			var err := ForgeManager.can_evolve(uid, recipe)
			_btn(r, "EVOLVE → %s" % (to.display_name if to else recipe["to"]), func() -> void: ForgeManager.evolve(uid, recipe); _show("forge"), err != "", err)


func _tab_system() -> void:
	_h("SAVE / QUIT")
	var r := _row()
	for slot in [1, 2, 3]:
		_btn(r, "SAVE SLOT %d" % slot, func() -> void: SaveManager.save_game(slot); _toast("Saved to slot %d." % slot))
	var r2 := _row()
	for slot in [1, 2, 3]:
		_btn(r2, "LOAD SLOT %d" % slot, func() -> void: SaveManager.load_game(slot); _show("missions"), not SaveManager.has_save_file(slot))
	_btn(_content, "TITLE SCREEN", func() -> void: SceneManager.change_scene(SceneManager.MAIN_MENU))
