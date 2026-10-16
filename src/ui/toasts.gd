class_name Toasts
extends RefCounted
## Styles for on-screen notifications (data/toasts.json): each toast id can
## name a sound and a Lattice clip that plays as an animated icon beside the
## text. Used by QuestToasts (cards) and ExploreScene (street toasts); battle
## moments use cues (data/cues.json).

const PATH := "res://data/toasts.json"

static var _data: Dictionary = {}


static func style(id: String) -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {"_": {}}
	var s: Variant = _data.get(id)
	return s if s is Dictionary else {}


## Every toast id in the data file.
static func ids() -> Array:
	style("")  # loads the file
	return _data.keys().filter(func(k: String) -> bool: return not k.begins_with("_"))


## Plays the toast's sound; returns false if it has none (callers keep their default).
static func play_sfx(id: String, volume_db: float = -5.0) -> bool:
	var sfx := str(style(id).get("sfx", ""))
	if sfx == "":
		return false
	if sfx.begins_with("res://"):
		var st := ForgeStore.load_audio(sfx)
		if st == null:
			return false
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.volume_db = volume_db
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return false
		tree.root.add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
	else:
		AudioManager.play_sfx(sfx, volume_db)
	return true


## The toast's animated icon (a Control), or null if it has no anim.
static func anim_icon(id: String, size: float = 48.0) -> Control:
	var path := str(style(id).get("anim", ""))
	if path == "" or not LatticeClip.is_clip(path):
		return null
	var clip := LatticeClip.load_clip(path)
	if not clip.get("ok", false):
		return null
	var icon := ClipIcon.new()
	icon.clip = clip
	icon.custom_minimum_size = Vector2(size, size)
	return icon


## Draws a Lattice clip's current frame, fitted to its box.
class ClipIcon extends Control:
	var clip: Dictionary
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var tex := LatticeClip.frame_texture(clip, LatticeClip.frame_at(clip, _t))
		if tex == null:
			return
		var ts := tex.get_size()
		var k := minf(size.x / maxf(ts.x, 1.0), size.y / maxf(ts.y, 1.0))
		var sz := ts * k
		draw_texture_rect(tex, Rect2((size - sz) * 0.5, sz), false)
