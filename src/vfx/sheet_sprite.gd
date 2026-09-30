class_name SheetSprite
extends Sprite2D
## Animated sprite for tiles, details and objects (the `anim` dict of
## WORLD_FORMAT.md): either one sprite sheet (hframes × vframes) or a list of
## frame textures, at `fps`, with mode loop | pingpong | once | random_start.
##
## Renderers that draw tiles themselves (draw_texture_rect in _draw) share the
## same clock through the static frame_at(); cell_phase() gives each cell a
## stable random offset so rows of water don't pulse in sync.

signal finished

const MODES := ["loop", "pingpong", "once", "random_start"]

## Frame textures (list mode). Empty → sheet mode using hframes/vframes.
var frames: Array[Texture2D] = []
var fps: float = 8.0
var mode: String = "loop"
## Seconds added to the clock (random_start picks one on _ready).
var phase: float = 0.0
var playing: bool = true
var _time: float = 0.0
var _last: int = -1


## Builds a sprite from a texture / path (sheet) or an array of textures/paths
## (frames). anim = {hframes, vframes, fps, mode, frames:[paths]}; a non-empty
## anim.frames overrides texture_or_frames.
static func from_anim(texture_or_frames: Variant, anim: Dictionary = {}) -> SheetSprite:
	var s := SheetSprite.new()
	var list: Array = []
	var anim_frames: Variant = anim.get("frames", [])
	if anim_frames is Array and not anim_frames.is_empty():
		list = anim_frames
	elif texture_or_frames is Array:
		list = texture_or_frames
	if list.size() > 0:
		for f: Variant in list:
			var t := _as_texture(f)
			if t:
				s.frames.append(t)
		if not s.frames.is_empty():
			s.texture = s.frames[0]
	else:
		s.texture = _as_texture(texture_or_frames)
		s.hframes = maxi(int(anim.get("hframes", 1)), 1)
		s.vframes = maxi(int(anim.get("vframes", 1)), 1)
	s.fps = float(anim.get("fps", 8.0))
	s.mode = str(anim.get("mode", "loop"))
	if not MODES.has(s.mode):
		s.mode = "loop"
	return s


static func _as_texture(v: Variant) -> Texture2D:
	if v is Texture2D:
		return v
	if v is String or v is StringName:
		return ForgeStore.load_texture(str(v))
	return null


## Frame index at `time` seconds for a `count`-frame animation.
## loop / random_start wrap, pingpong bounces (0 1 2 3 2 1 0 ...), once holds
## the last frame. `phase` is a time offset in seconds.
static func frame_at(time: float, count: int, fps: float, mode: String, phase: float = 0.0) -> int:
	if count <= 1 or fps <= 0.0:
		return 0
	var step := int(floor(maxf(time + phase, 0.0) * fps))
	match mode:
		"once":
			return mini(step, count - 1)
		"pingpong":
			var period := count * 2 - 2
			var i := step % period
			return i if i < count else period - i
		_:
			return step % count


## Stable per-cell phase (seconds within one cycle) for random_start tiles.
static func cell_phase(cell: Vector2i, count: int, fps: float) -> float:
	if fps <= 0.0 or count <= 1:
		return 0.0
	var h := absi(hash(cell)) % 1000
	return float(h) / 1000.0 * float(count) / fps


func _ready() -> void:
	if mode == "random_start" and phase == 0.0:
		phase = randf() * float(frame_count()) / maxf(fps, 0.001)
	_show(current_frame())


func _process(delta: float) -> void:
	if not playing or frame_count() <= 1:
		return
	_time += delta
	var i := current_frame()
	if i != _last:
		_show(i)
		if mode == "once" and i == frame_count() - 1:
			playing = false
			finished.emit()


func frame_count() -> int:
	return frames.size() if not frames.is_empty() else hframes * vframes


func current_frame() -> int:
	return frame_at(_time, frame_count(), fps, mode, phase)


## Restarts from frame 0 (keeps the phase).
func restart() -> void:
	_time = 0.0
	playing = true
	_show(current_frame())


## Texture of frame i: the frame texture, or an AtlasTexture of the sheet cell.
func frame_texture(i: int) -> Texture2D:
	if not frames.is_empty():
		return frames[clampi(i, 0, frames.size() - 1)]
	var sheet := texture
	if sheet == null or hframes * vframes <= 1:
		return sheet
	var fw := sheet.get_width() / hframes
	var fh := sheet.get_height() / vframes
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2((i % hframes) * fw, (i / hframes) % vframes * fh, fw, fh)
	return at


## The texture currently shown (for custom _draw renderers).
func current_texture() -> Texture2D:
	return frame_texture(current_frame())


func _show(i: int) -> void:
	_last = i
	if not frames.is_empty():
		texture = frames[clampi(i, 0, frames.size() - 1)]
	elif hframes * vframes > 1:
		frame = clampi(i, 0, hframes * vframes - 1)
