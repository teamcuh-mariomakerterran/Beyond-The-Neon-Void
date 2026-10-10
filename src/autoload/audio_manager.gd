extends Node
## AudioManager — music per scene/map (crossfaded) and pooled SFX.
##
## Music ids map to files under res://assets/music, SFX ids to res://assets/sfx.
## Missing files are silently skipped, so the game runs before audio lands.

const MUSIC_DIR := "res://assets/music"
const SFX_DIR := "res://assets/sfx"
const EXTENSIONS := ["ogg", "mp3", "wav"]
const SFX_POOL := 8

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i: int = 0
var current_music_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for p in [_music_a, _music_b]:
		p.bus = "Master"
		add_child(p)
	for i in SFX_POOL:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_sfx.append(s)
	EventBus.play_sfx.connect(func(id: String) -> void: play_sfx(id))
	get_tree().node_added.connect(_on_node_added)
	EventBus.character_leveled.connect(func(_id: String, _lv: int) -> void: Sfx.event("level_up", -4.0))
	EventBus.loot_discovered.connect(func(_s: String, _i: String, _m: String) -> void: Sfx.event("loot"))


func _find(dir: String, id: String) -> AudioStream:
	for ext in EXTENSIONS:
		var p := dir.path_join(id + "." + ext)
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
	return null


## `music_id` is a name under assets/music ("battle_supply_works") or a full
## path ("res://assets/music/x.ogg", what maps and region triggers store).
func play_music(music_id: String, fade: float = 1.2) -> void:
	if music_id == current_music_id:
		return
	current_music_id = music_id
	var stream: AudioStream = null
	if music_id.begins_with("res://") or music_id.begins_with("user://"):
		stream = ForgeStore.load_audio(music_id)
	elif music_id != "":
		stream = _find(MUSIC_DIR, music_id)
	var old := _music_a if _music_a.playing else _music_b
	var nxt := _music_b if old == _music_a else _music_a
	if old.playing:
		var t := create_tween()
		t.tween_property(old, "volume_db", -40.0, fade)
		t.tween_callback(old.stop)
	if stream:
		nxt.stream = stream
		nxt.volume_db = -40.0
		nxt.play()
		create_tween().tween_property(nxt, "volume_db", 0.0, fade)


## Plays a sound effect. `sfx_id` is a file name under assets/sfx without the
## extension ("gun_smg_2"), or a family ("gun_smg", "hit", "scream") — then a
## random variant (gun_smg_1, gun_smg_2…) plays, never the same one twice in a
## row. Missing ids are skipped quietly. `volume_db` / `pitch` tweak one play.
func play_sfx(sfx_id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if sfx_id == "" or not SettingsFlags.sfx:
		return
	var stream := _find(SFX_DIR, sfx_id)
	if stream == null:
		var pick := _variant(sfx_id)
		if pick == "":
			return
		stream = _find(SFX_DIR, pick)
		if stream == null:
			return
	var p := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = stream
	p.volume_db = volume_db + SettingsFlags.sfx_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()


var _families: Dictionary = {}  # "hit" -> ["hit_1", "hit_2", …]
var _last_pick: Dictionary = {}


## Every sfx id in a family ("hit" → hit_1…hit_13). Scanned once.
func variants(family: String) -> Array:
	if _families.is_empty():
		_scan_families()
	return _families.get(family, [])


func _scan_families() -> void:
	var rx := RegEx.create_from_string("^(.+?)_(\\d+)$")
	# Exported builds list "x.ogg.import" instead of "x.ogg": both count.
	for f in DirAccess.get_files_at(SFX_DIR):
		var file := f.trim_suffix(".import")
		if not file.get_extension().to_lower() in EXTENSIONS:
			continue
		var id := file.get_basename()
		var m := rx.search(id)
		if m == null:
			continue
		var fam := m.get_string(1)
		if not _families.has(fam):
			_families[fam] = []
		if not (_families[fam] as Array).has(id):
			_families[fam].append(id)
	for fam: String in _families:
		(_families[fam] as Array).sort()


func _variant(family: String) -> String:
	var list := variants(family)
	if list.is_empty():
		return ""
	var pick: String = list[randi() % list.size()]
	if list.size() > 1 and pick == str(_last_pick.get(family, "")):
		pick = list[(list.find(pick) + 1) % list.size()]
	_last_pick[family] = pick
	return pick


# --- Ambience ------------------------------------------------------------------

var _amb: AudioStreamPlayer
var current_ambience: String = ""


## Loops a background bed under the music ("amb_rain", "amb_bar"… a family
## picks one variant). "" fades it out.
func play_ambience(amb_id: String, volume_db: float = -10.0, fade: float = 1.5) -> void:
	if amb_id == current_ambience:
		return
	current_ambience = amb_id
	if _amb == null:
		_amb = AudioStreamPlayer.new()
		add_child(_amb)
	var t := create_tween()
	if _amb.playing:
		t.tween_property(_amb, "volume_db", -40.0, fade * 0.5)
		t.tween_callback(_amb.stop)
	if amb_id == "" or not SettingsFlags.sfx:
		return
	var stream := _find(SFX_DIR, amb_id)
	if stream == null:
		var pick := _variant(amb_id)
		stream = _find(SFX_DIR, pick) if pick != "" else null
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	t.tween_callback(func() -> void:
		_amb.stream = stream
		_amb.volume_db = -40.0
		_amb.play())
	t.tween_property(_amb, "volume_db", volume_db + SettingsFlags.sfx_db, fade)


# --- UI clicks -----------------------------------------------------------------

## Every button in the game ticks when pressed (and hovering a menu button
## blips quietly), so the UI sounds alive without wiring each screen.
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("silent"):
		var b := n as BaseButton
		b.pressed.connect(func() -> void: play_sfx("ui_beep", -10.0, 1.1))
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				play_sfx("ui_tone_1", -26.0, 1.6))
