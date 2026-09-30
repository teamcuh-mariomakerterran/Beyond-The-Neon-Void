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
	EventBus.play_sfx.connect(play_sfx)


func _find(dir: String, id: String) -> AudioStream:
	for ext in EXTENSIONS:
		var p := dir.path_join(id + "." + ext)
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
	return null


func play_music(music_id: String, fade: float = 1.2) -> void:
	if music_id == current_music_id:
		return
	current_music_id = music_id
	var stream := _find(MUSIC_DIR, music_id) if music_id != "" else null
	var old := _music_a if _music_a.playing else _music_b
	var nxt := _music_b if old == _music_a else _music_a
	var t := create_tween().set_parallel(true)
	if old.playing:
		t.tween_property(old, "volume_db", -40.0, fade)
		t.chain().tween_callback(old.stop)
	if stream:
		nxt.stream = stream
		nxt.volume_db = -40.0
		nxt.play()
		create_tween().tween_property(nxt, "volume_db", 0.0, fade)


func play_sfx(sfx_id: String) -> void:
	var stream := _find(SFX_DIR, sfx_id)
	if stream == null:
		return
	var p := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()
