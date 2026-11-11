class_name GameMenus
extends RefCounted
## The game's menus, built once and used everywhere: the title menu opens them
## over its animated background, and PixelMenuLayer opens them over the hub,
## the streets, the world map and battles (the pause menu). All are
## PixelScreens, so they share one look, one font and one set of sounds.


## PAUSED: resume, options, save, load, quit to title (+ any extra rows, e.g.
## "LEAVE AREA" in the streets: [[label, Callable]] before QUIT).
static func pause(layer: PixelMenuLayer, can_save: bool, extra: Array = []) -> PixelScreen:
	var s := PixelScreen.new()
	s.title = "PAUSED"
	s.add_row("RESUME", s.close)
	s.add_row("OPTIONS", func() -> void: layer.push(options()))
	if can_save:
		s.add_row("SAVE GAME", func() -> void: layer.push(save_game()))
	s.add_row("LOAD GAME", func() -> void: layer.push(load_game(func(slot: int) -> void:
		layer.close_all()
		if SaveManager.load_game(slot):
			AudioManager.play_ui("save_loaded")
			CampaignManager.resume())))
	for e: Array in extra:
		var cb: Callable = e[1]
		s.add_row(str(e[0]), func() -> void:
			layer.close_all()
			cb.call())
	s.add_row("QUIT TO TITLE", func() -> void:
		layer.close_all()
		SceneManager.change_scene(SceneManager.MAIN_MENU))
	return s


static func options() -> PixelScreen:
	var s := PixelScreen.new()
	s.title = "OPTIONS"
	var onoff := func(key: String) -> Callable: return func() -> String: return "ON" if bool(SettingsFlags.value_of(key)) else "OFF"
	var flip := func(key: String) -> Callable: return func() -> void:
		SettingsFlags.set_value(key, not bool(SettingsFlags.value_of(key)))
		SettingsFlags.save()
	s.add_row("FULLSCREEN", flip.call("fullscreen"), onoff.call("fullscreen"))
	_volume_row(s, "MUSIC", "music_db", func() -> void: AudioManager.apply_music_volume())
	_volume_row(s, "SOUND FX", "sfx_db", func() -> void: AudioManager.play_ui("menu_move"))
	s.add_row("BATTLE SPEED", flip.call("fast_battles"), func() -> String: return "FAST" if SettingsFlags.fast_battles else "NORMAL")
	s.add_row("FREE MOVEMENT", flip.call("free_move"), onoff.call("free_move"))
	s.add_row("REDUCE MOTION", flip.call("reduce_motion"), onoff.call("reduce_motion"))
	s.add_row("BATTLE BARKS", flip.call("barks"), onoff.call("barks"))
	s.add_row("AUTO ADDITIONS", flip.call("auto_additions"), onoff.call("auto_additions"))
	s.add_row("BACK", s.close)
	return s


## A 0–10 volume row: left / right step it, the bar shows the level.
static func _volume_row(s: PixelScreen, label: String, key: String, after: Callable) -> void:
	var level := func() -> int:
		if key == "sfx_db" and not SettingsFlags.sfx:
			return 0
		return SettingsFlags.db_level(float(SettingsFlags.value_of(key)))
	var step := func(d: int) -> void:
		var lv := clampi(int(level.call()) + d, 0, SettingsFlags.VOLUME_STEPS)
		if key == "sfx_db":
			SettingsFlags.sfx = lv > 0
		SettingsFlags.set_value(key, SettingsFlags.level_db(maxi(lv, 1)) if key == "sfx_db" else SettingsFlags.level_db(lv))
		SettingsFlags.save()
		after.call()
	var r := s.add_row(label, Callable(), Callable(), func() -> void: step.call(-1), func() -> void: step.call(1))
	r["level"] = level
	r["steps"] = SettingsFlags.VOLUME_STEPS


## LOAD GAME: every slot with its summary; `on_load(slot)` loads it.
static func load_game(on_load: Callable) -> PixelScreen:
	var s := PixelScreen.new()
	s.title = "LOAD GAME"
	for slot: int in SaveManager.SLOTS:
		var sum := SaveManager.slot_summary(slot)
		var r := s.add_row(slot_name(slot), func() -> void: on_load.call(slot))
		r["enabled"] = func() -> bool: return not sum.is_empty()
		r["detail"] = func() -> String: return slot_line(sum)
	s.add_row("BACK", s.close)
	if SaveManager.latest_slot() < 0:
		AudioManager.play_ui("no_save")
	return s


## SAVE GAME: slots 1–3 (the quick save is F5); saving shows the new summary.
static func save_game() -> PixelScreen:
	var s := PixelScreen.new()
	s.title = "SAVE GAME"
	for slot: int in SaveManager.SLOTS:
		if slot == SaveManager.QUICK_SLOT:
			continue
		var r := s.add_row(slot_name(slot), func() -> void:
			if SaveManager.save_game(slot):
				AudioManager.play_ui("save_loaded"))
		r["detail"] = func() -> String: return slot_line(SaveManager.slot_summary(slot))
	s.add_row("BACK", s.close)
	return s


static func credits(path: String = "res://data/credits.json") -> PixelScreen:
	var s := PixelScreen.new()
	s.title = "CREDITS"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	for l: Variant in (data.get("lines", []) if data is Dictionary else []):
		s.lines.append(str(l))
	if s.lines.is_empty():
		s.lines.append("# BEYOND: THE NEON VOID")
	return s


static func slot_name(slot: int) -> String:
	return "QUICK SAVE" if slot == SaveManager.QUICK_SLOT else "SLOT %d" % slot


## "ROOK DANNICK  CH 1  11-10 14:22" (or EMPTY).
static func slot_line(sum: Dictionary) -> String:
	if sum.is_empty():
		return "EMPTY"
	var at := str(sum.get("saved_at", ""))
	var when := "%s %s" % [at.substr(5, 5), at.substr(11, 5)] if at.length() >= 16 else at
	var who := str(sum.get("leader", "")).to_upper()
	return "%s  CH %d  %s" % [who, int(sum.get("chapter", 1)), when]
