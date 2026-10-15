class_name SettingsFlags
extends RefCounted
## Accessibility / debug toggles readable from anywhere.

static var reduce_motion: bool = false
static var fast_battles: bool = false
## Sync Blade Additions resolve automatically at ~70% strength (no timing).
static var auto_additions: bool = false
## Icon style: "painted" (detailed, frameless) or "framed" (orange bevel tiles).
static var icon_style: String = "painted"
## Battle barks: speech bubbles (and recorded voice lines) on crits, kills…
static var barks: bool = true
## Sound effects + ambience on/off, and their volume offset (dB).
static var sfx: bool = true
static var sfx_db: float = 0.0
## Battle animations at this speed when fast_battles is on.
const FAST_SPEED := 1.6

const PATH := "user://settings.cfg"
const KEYS := ["reduce_motion", "fast_battles", "auto_additions", "icon_style", "barks", "sfx", "sfx_db"]


## Settings survive restarts (GameManager loads them at startup).
static func save() -> void:
	var cfg := ConfigFile.new()
	for k: String in KEYS:
		cfg.set_value("settings", k, value_of(k))
	cfg.save(PATH)


static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k: String in KEYS:
		if cfg.has_section_key("settings", k):
			set_value(k, cfg.get_value("settings", k))


static func value_of(k: String) -> Variant:
	match k:
		"reduce_motion": return reduce_motion
		"fast_battles": return fast_battles
		"auto_additions": return auto_additions
		"icon_style": return icon_style
		"barks": return barks
		"sfx": return sfx
		"sfx_db": return sfx_db
	return null


static func set_value(k: String, v: Variant) -> void:
	match k:
		"reduce_motion": reduce_motion = bool(v)
		"fast_battles": fast_battles = bool(v)
		"auto_additions": auto_additions = bool(v)
		"icon_style": icon_style = str(v) if str(v) in ["painted", "framed"] else "painted"
		"barks": barks = bool(v)
		"sfx": sfx = bool(v)
		"sfx_db": sfx_db = clampf(float(v), -30.0, 6.0)
