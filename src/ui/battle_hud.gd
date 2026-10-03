class_name BattleHUD
extends CanvasLayer
## Battle interface, built in code on the NeonTheme:
##   top strip     CT turn-order forecast (who acts next, charged casts included)
##   bottom-left   active unit card: portrait slot, HP/MP bars, AP pips, stats
##   bottom-mid    command bar: Move, abilities (cost + disabled reasons), End Turn
##   right         tile / target inspector with hit% and damage forecast
##   left          combat log
## It emits intent signals; BattleMap decides what they mean.

signal move_pressed
signal ability_pressed(ability: Ability)
signal end_turn_pressed
signal continue_pressed

var _order_row: HBoxContainer
var _unit_panel: PanelContainer
var _unit_name: Label
var _unit_class: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _mp_bar: ProgressBar
var _mp_label: Label
var _ap_row: HBoxContainer
var _stats_label: Label
var _status_label: Label
var _cmd_bar: HBoxContainer
var _inspect_panel: PanelContainer
var _inspect_text: RichTextLabel
var _log: RichTextLabel
var _banner: Label
var _results: PanelContainer
var _toast: Label
var _mode_label: Label


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = NeonTheme.get_theme()
	add_child(root)
	_build_turn_order(root)
	_build_unit_panel(root)
	_build_command_bar(root)
	_build_inspector(root)
	_build_log(root)
	_build_banner(root)
	UIManager.register_hud(self)
	EventBus.log_message.connect(add_log)


func _exit_tree() -> void:
	UIManager.unregister_hud(self)


# --- Layout ----------------------------------------------------------------

func _build_turn_order(root: Control) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.VIOLET, 0.4)))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.position.y = 14
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(NeonTheme.label("TURN ORDER  //  CT CLOCK", 11, NeonTheme.TEXT_DIM))
	_order_row = HBoxContainer.new()
	_order_row.add_theme_constant_override("separation", 6)
	v.add_child(_order_row)


func _build_unit_panel(root: Control) -> void:
	_unit_panel = PanelContainer.new()
	_unit_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_unit_panel.offset_left = 18
	_unit_panel.offset_bottom = -18
	_unit_panel.offset_top = -210
	_unit_panel.offset_right = 400
	_unit_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_unit_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_unit_panel.add_child(v)
	_unit_name = NeonTheme.label("—", 24)
	_unit_class = NeonTheme.label("", 13, NeonTheme.TEXT_DIM)
	v.add_child(_unit_name)
	v.add_child(_unit_class)
	var hp_row := HBoxContainer.new()
	_hp_bar = NeonTheme.bar(NeonTheme.GREEN, 12)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_label = NeonTheme.label("", 13)
	_hp_label.custom_minimum_size.x = 96
	hp_row.add_child(NeonTheme.label("HP", 12, NeonTheme.TEXT_DIM))
	hp_row.add_child(_hp_bar)
	hp_row.add_child(_hp_label)
	v.add_child(hp_row)
	var mp_row := HBoxContainer.new()
	_mp_bar = NeonTheme.bar(NeonTheme.VIOLET, 8)
	_mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mp_label = NeonTheme.label("", 13)
	_mp_label.custom_minimum_size.x = 96
	mp_row.add_child(NeonTheme.label("MP", 12, NeonTheme.TEXT_DIM))
	mp_row.add_child(_mp_bar)
	mp_row.add_child(_mp_label)
	v.add_child(mp_row)
	_ap_row = HBoxContainer.new()
	v.add_child(_ap_row)
	_stats_label = NeonTheme.label("", 13, NeonTheme.TEXT_DIM)
	v.add_child(_stats_label)
	_status_label = NeonTheme.label("", 13, NeonTheme.AMBER)
	v.add_child(_status_label)
	_unit_panel.visible = false


func _build_command_bar(root: Control) -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	wrap.offset_bottom = -22
	wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wrap.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(wrap)
	_mode_label = NeonTheme.label("", 13, NeonTheme.CYAN)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(_mode_label)
	_cmd_bar = HBoxContainer.new()
	_cmd_bar.add_theme_constant_override("separation", 6)
	_cmd_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(_cmd_bar)


func _build_inspector(root: Control) -> void:
	_inspect_panel = PanelContainer.new()
	_inspect_panel.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.CYAN, 0.5)))
	_inspect_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_inspect_panel.offset_right = -18
	_inspect_panel.offset_top = 110
	_inspect_panel.offset_left = -330
	_inspect_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(_inspect_panel)
	_inspect_text = RichTextLabel.new()
	_inspect_text.bbcode_enabled = true
	_inspect_text.fit_content = true
	_inspect_text.scroll_active = false
	_inspect_text.custom_minimum_size = Vector2(290, 0)
	_inspect_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_panel.add_child(_inspect_text)
	_inspect_panel.visible = false


func _build_log(root: Control) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.VIOLET, 0.25), Color(0.04, 0.02, 0.08, 0.7)))
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	p.offset_left = 18
	p.offset_top = 110
	p.offset_right = 420
	p.offset_bottom = 300
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 13)
	p.add_child(_log)


func _build_banner(root: Control) -> void:
	_banner = NeonTheme.label("", 54, NeonTheme.GREEN)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", NeonTheme.BG)
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)
	_toast = NeonTheme.label("", 18, NeonTheme.AMBER)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 96
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)


# --- Updates ---------------------------------------------------------------

func show_unit(unit: Node, commands_enabled: bool) -> void:
	_unit_panel.visible = unit != null
	for c in _cmd_bar.get_children():
		c.queue_free()
	if unit == null:
		return
	var col := NeonTheme.team_color(unit.team)
	_unit_panel.add_theme_stylebox_override("panel", NeonTheme.panel_box(col))
	_unit_name.text = unit.display_name()
	_unit_name.add_theme_color_override("font_color", col)
	var cls: ClassResource = unit.class_res()
	_unit_class.text = "LV %d  %s  //  %s" % [unit.get_stat("level"), cls.display_name.to_upper() if cls else "?", ["CREW", "DOCTRINE", "NEUTRAL"][clampi(unit.team, 0, 2)]]
	refresh_unit(unit)
	if not commands_enabled:
		return
	var move_btn := _cmd("MOVE", "Move up to %d tiles (jump %d)." % [unit.get_stat("move"), unit.get_stat("jump")])
	move_btn.disabled = not unit.can_move()
	move_btn.pressed.connect(func() -> void: move_pressed.emit())
	for a: Ability in unit.get_abilities():
		var cost := []
		if a.ap_cost > 0: cost.append("%dAP" % (unit.ap_cost_of(a) if unit and unit.has_method("ap_cost_of") else a.ap_cost))
		if a.mp_cost > 0: cost.append("%dMP" % (unit.mp_cost_of(a) if unit and unit.has_method("mp_cost_of") else a.mp_cost))
		if a.hp_cost_pct > 0: cost.append("%d%%HP" % roundi(a.hp_cost_pct * 100))
		if a.charge_ticks > 0: cost.append("⌛%d" % a.charge_ticks)
		var label := a.display_name.to_upper()
		if a is CardResource:
			label = "🂠 " + label
		var tip := "%s\n%s\nRange %d-%d%s" % [a.display_name, a.description, a.range_min, a.effective_range_max(unit), ("  AoE %d" % a.aoe_radius) if a.aoe_radius > 0 else ""]
		var b := _cmd("%s  %s" % [label, " ".join(cost)], tip)
		b.disabled = not unit.can_act() or not unit.can_afford(a)
		b.pressed.connect(func() -> void: ability_pressed.emit(a))
	var end := _cmd("END TURN", "Finish this unit's turn. Waiting without acting returns you sooner on the CT clock.")
	end.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(0.2, 0.03, 0.1, 0.95), NeonTheme.MAGENTA))
	end.pressed.connect(func() -> void: end_turn_pressed.emit())


func _cmd(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	_cmd_bar.add_child(b)
	return b


func refresh_unit(unit: Node) -> void:
	if unit == null or not _unit_panel.visible:
		return
	_hp_bar.max_value = unit.get_stat("max_hp")
	_hp_bar.value = unit.current_hp
	_hp_label.text = "%d / %d" % [unit.current_hp, unit.get_stat("max_hp")]
	_mp_bar.max_value = maxi(unit.get_stat("max_mp"), 1)
	_mp_bar.value = unit.current_mp
	_mp_label.text = "%d / %d" % [unit.current_mp, unit.get_stat("max_mp")]
	for c in _ap_row.get_children():
		c.queue_free()
	_ap_row.add_child(NeonTheme.label("AP ", 12, NeonTheme.TEXT_DIM))
	for i in unit.get_stat("max_ap"):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 8)
		pip.color = NeonTheme.CYAN if i < unit.current_ap else Color(1, 1, 1, 0.12)
		_ap_row.add_child(pip)
	_ap_row.add_child(NeonTheme.label("   MOVE " + ("✓" if unit.has_moved else "○"), 12, NeonTheme.TEXT_DIM))
	_stats_label.text = "ATK %d  DEF %d  MAG %d  RES %d  SPD %d  EVA %d%%" % [unit.get_stat("attack"), unit.get_stat("defense"), unit.get_stat("magic"), unit.get_stat("resistance"), unit.get_stat("speed"), unit.get_stat("evasion")]
	var st := []
	for inst in unit.statuses:
		st.append("%s(%d)" % [inst.effect.display_name, inst.turns_left] if not inst.effect.is_permanent else inst.effect.display_name)
	_status_label.text = "  ".join(st)


func set_mode_hint(text: String) -> void:
	_mode_label.text = text


func update_turn_order(forecast: Array) -> void:
	for c in _order_row.get_children():
		c.queue_free()
	var i := 0
	for entry: Dictionary in forecast:
		var chip := PanelContainer.new()
		var who: Node = entry.get("unit")
		var text := ""
		var col := NeonTheme.AMBER
		if who and is_instance_valid(who):
			col = NeonTheme.team_color(who.team)
			text = who.display_name().split(" ")[0].left(10)
		elif entry.has("cast"):
			var cast: Dictionary = entry["cast"]
			text = "⌛ " + (cast["ability"] as Ability).display_name.left(12)
		chip.add_theme_stylebox_override("panel", NeonTheme.button_box(Color(col, 0.18) if i > 0 else Color(col, 0.45), col))
		var l := NeonTheme.label(text, 13 if i > 0 else 15, NeonTheme.TEXT)
		chip.add_child(l)
		_order_row.add_child(chip)
		i += 1


func show_inspect(text: String) -> void:
	_inspect_panel.visible = text != ""
	_inspect_text.text = text


func add_log(text: String) -> void:
	_log.append_text(text + "\n")


func show_banner(text: String, color: Color = NeonTheme.GREEN, hold: float = 0.8) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	# Stamp in (wide + flat → full), hold, then squeeze out.
	_banner.pivot_offset = _banner.size * 0.5
	var t := create_tween()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(1.8, 0.15)
	t.tween_property(_banner, "modulate:a", 1.0, 0.08)
	t.parallel().tween_property(_banner, "scale", Vector2(0.94, 1.08), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_banner, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(hold)
	t.tween_property(_banner, "scale", Vector2(1.25, 0.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_banner, "modulate:a", 0.0, 0.18)


func show_notification(text: String) -> void:
	_toast.text = text
	var t := create_tween()
	_toast.modulate.a = 1.0
	t.tween_interval(1.6)
	t.tween_property(_toast, "modulate:a", 0.0, 0.5)


func set_turn_indicator(text: String) -> void:
	show_banner(text)


## End-of-battle screen. `report` comes from CampaignManager.process_mission_completion.
func show_results(victory: bool, report: Dictionary) -> void:
	_cmd_bar.get_parent().visible = false
	_results = PanelContainer.new()
	_results.add_theme_stylebox_override("panel", NeonTheme.panel_box(NeonTheme.GREEN if victory else NeonTheme.MAGENTA, NeonTheme.PANEL_HI))
	_results.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	get_child(0).add_child(_results)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(460, 0)
	_results.add_child(v)
	v.add_child(NeonTheme.label("SHIFT'S OVER" if victory else "WIPED OUT", 40, NeonTheme.GREEN if victory else NeonTheme.MAGENTA))
	v.add_child(NeonTheme.label("Victory. Drinks are on the Doctrine." if victory else "The crew limps home. Nobody talks about it.", 16, NeonTheme.TEXT_DIM))
	if victory:
		v.add_child(NeonTheme.label("+%d Soul Coins" % int(report.get("soul_coins", 0)), 20, NeonTheme.AMBER))
		v.add_child(NeonTheme.label("+%d XP   +%d Microchips" % [int(report.get("xp", 0)), int(report.get("microchips", 0))], 18))
		var items: Dictionary = report.get("items", {})
		for id: String in items:
			var item := ContentDB.get_item(id)
			var nm := item.display_name if item else id
			v.add_child(NeonTheme.label("  • %s x%d" % [nm, items[id]], 15, NeonTheme.CYAN))
		var lvls: Dictionary = report.get("level_ups", {})
		for id: String in lvls:
			var c := GameManager.get_character(id)
			v.add_child(NeonTheme.label("  ▲ %s levelled up!" % (c.display_name if c else id), 15, NeonTheme.GREEN))
	var b := Button.new()
	b.text = "BACK TO THE NEON GUTTER"
	b.pressed.connect(func() -> void: continue_pressed.emit())
	v.add_child(b)
