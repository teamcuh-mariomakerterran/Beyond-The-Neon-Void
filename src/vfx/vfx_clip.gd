class_name VFXClip
extends VFXPart
## A Lattice clip (lattice.clip JSON + strip) played as one layer of a VFX
## effect: Lattice's spell, impact and summon animations inside the
## data-driven effects. Keys (plus the common VFXPart ones):
##   path    res:// path of the *_clip.json (required)
##   scale   size multiplier (1 = the clip's own pixels)
##   speed   playback rate (1 = as authored)
##   loop    keep looping for `life` (default: play once)
##   face    flip to face the target (default true for clips anchored "at")
##   glow    colour multiplier (above 1 blooms through the HDR glow)
## Blend defaults to "mix" (Lattice FX are authored for normal blending).
## The impact moment is the clip's first hits[] frame, else frame 0
## (Lattice's rule), so damage numbers land with the animation.

var _clip: Dictionary = {}
var _spr: Sprite2D


func default_blend() -> String:
	return "mix"


func _setup() -> void:
	_clip = LatticeClip.load_clip(str(d.get("path", "")))
	if not _clip.get("ok", false):
		push_warning("VFX clip: can't load " + str(d.get("path", "")))
		life = 0.01
		return
	if d.has("loop"):
		_clip = _clip.merged({"loop": bool(d["loop"])}, true)  # a copy: the cache stays as authored
	var speed := maxf(num("speed", 1.0), 0.05)
	if not d.has("life"):
		life = float(_clip["total"]) / 1000.0 / speed
	_spr = Sprite2D.new()
	_spr.centered = false
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc := num("scale", 1.0)
	_spr.scale = Vector2(sc, sc)
	var anchor: Vector2 = _clip["anchor"]
	_spr.offset = -anchor
	var face: bool = d.get("face", str(d.get("anchor", "at")) == "at")
	if face and fx.has_target and fx.target_local.x < 0.0:
		_spr.flip_h = true
		_spr.offset.x = -(float(_clip["cell"].x) - anchor.x)
	_spr.modulate = Color(glow, glow, glow, 1.0)
	_spr.use_parent_material = true
	add_child(_spr)


func _update(lt: float, _dt: float) -> void:
	if _spr == null:
		return
	var tt := lt * maxf(num("speed", 1.0), 0.05)
	_spr.texture = LatticeClip.frame_texture(_clip, LatticeClip.frame_at(_clip, tt))


## Seconds into this part when it hits (first hits[] frame, else frame 0).
static func hit_time(p: Dictionary) -> float:
	var clip := LatticeClip.load_clip(str(p.get("path", "")))
	if not clip.get("ok", false):
		return 0.0
	var frame := 0
	var hits: Array = clip.get("hits", [])
	if not hits.is_empty() and hits[0] is Dictionary:
		frame = int(hits[0].get("frame", 0))
	var seq: Array = clip["seq"]
	var ms: Array = clip["ms"]
	var at := 0.0
	for k in seq.size():
		if int(seq[k]) == frame:
			break
		at += float(ms[k])
	return at / 1000.0 / maxf(float(p.get("speed", 1.0)), 0.05)
