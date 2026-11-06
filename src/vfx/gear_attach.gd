class_name GearAttach
extends Node2D
## Attached gear: weapons, helmets and other pieces pinned to a body's anchor
## points per animation frame. One art set works on every body, because the
## body says where its hands and head are (its rig) and the art says where it
## is held (its grip).
##
## Lives as a child of the unit's AnimatedSprite2D (so it shares its scale and
## status-look material) and follows it every frame: animation, frame,
## facing and flip. Presentation only; nothing in rules reads it.
##
## The body's rig: <body folder>/rig.json
##   {"points": {"hand_r": {
##       "facing": {"SE": [x, y, z], "NE": [x, y, z], ...},     still default per facing
##       "anims":  {"attack_SE": [[x, y, z], [x, y, z], ...]}   one entry per frame
##    }, "hand_l": {...}, "head": {...}}}
##   x, y are pixels in the animation's cell (the source PNG, before scaling).
##   z > 0 draws the piece in front of the body, z < 0 behind. An optional
##   fourth number is the forearm angle in degrees (used by art with "rotate").
##   Lookup: this anim's frame, its last frame, then the facing default, then
##   the mirrored facing (x flipped). No rig, no point: the piece isn't drawn.
##
## The art set: an item's wear_path folder holding attach.json and pictures
##   <FACING>.png (any of N NE E SE S SW W NW; a missing side borrows its
##   mirror, flipped, then the nearest drawn facing), or one picture for all.
##   attach.json: {"point": "hand_r", "grip": [x, y], "grips": {"NE": [x, y]},
##                 "z": {"NE": -1}, "rotate": false, "order": 0, "cover": 2}
##   grip is the pixel held at the anchor point (the middle of a handle); z
##   overrides the rig's side per facing; order breaks ties between pieces on
##   the same side. cover > 0 redraws the body's own pixels within that many
##   pixels of the point on top of a piece in front, so the fist closes over
##   the handle instead of the weapon floating over the hand.
## A wear_path folder in PixelMatrix layout (<anim>/<FACING>_<Limb>.png) is a
## worn layer instead and goes through PixelMatrix.composite (see Unit).

const FACINGS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const MIRROR := {"NE": "NW", "NW": "NE", "E": "W", "W": "E", "SE": "SW", "SW": "SE", "N": "N", "S": "S"}
## Which side of the body the right hand sits on when no rig says (art faces
## the viewer on S/SE/SW: the right hand is nearer the camera on S, SE, E, NE).
const RIGHT_HAND_FRONT := {"S": 1, "SE": 1, "E": 1, "NE": 1, "N": -1, "NW": -1, "W": -1, "SW": -1}

static var _rigs: Dictionary = {}
static var _arts: Dictionary = {}

var body: AnimatedSprite2D
var rig: Dictionary = {}
## [{art: Dictionary, node: Sprite2D}]
var pieces: Array = []
var _state := ""


## Rig for a body folder ({} if it has none). Cached.
static func load_rig(body_dir: String) -> Dictionary:
	if _rigs.has(body_dir):
		return _rigs[body_dir]
	var out := {}
	var p := body_dir.path_join("rig.json")
	if body_dir != "" and FileAccess.file_exists(p):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary:
			out = d
	_rigs[body_dir] = out
	return out


static func clear_cache() -> void:
	_rigs.clear()
	_arts.clear()


## "attack_SE" → "SE"; "" if the name carries no facing.
static func facing_from_anim(anim: String) -> String:
	var f := anim.get_slice("_", anim.get_slice_count("_") - 1)
	return f if f in FACINGS else ""


## Anchor point `point` for `anim` frame `frame`: Vector3(x, y, z) in cell
## pixels, or null when the rig doesn't place it. `facing` is the drawn facing
## (the anim's own, before any flip).
static func point_at(p_rig: Dictionary, point: String, anim: String, frame: int, facing: String = "", cell_w: float = 0.0) -> Variant:
	var pts: Dictionary = (p_rig.get("points", {}) as Dictionary).get(point, {})
	if pts.is_empty():
		return null
	if facing == "":
		facing = facing_from_anim(anim)
	var per_frame: Variant = (pts.get("anims", {}) as Dictionary).get(anim)
	if per_frame is Array and not (per_frame as Array).is_empty():
		var arr: Array = per_frame
		return _vec(arr[clampi(frame, 0, arr.size() - 1)])
	# Still-pose points are in the rig's own cell ("cell"). Skeleton-mode takes
	# draw the same body centred on a bigger canvas, so shift by the padding.
	var rig_cell := float(p_rig.get("cell", 0))
	if rig_cell <= 0.0:
		rig_cell = cell_w
	var pad := (cell_w - rig_cell) * 0.5 if cell_w > 0.0 and rig_cell > 0.0 else 0.0
	var by_facing: Dictionary = pts.get("facing", {})
	if by_facing.has(facing):
		var f: Variant = _vec(by_facing[facing])
		return (f as Vector3) + Vector3(pad, pad, 0) if f != null else null
	var m := str(MIRROR.get(facing, ""))
	if m != "" and m != facing and by_facing.has(m):
		var v: Variant = _vec(by_facing[m])
		if v != null and rig_cell > 0.0:
			var w: Vector3 = v
			return Vector3(rig_cell - w.x + pad, w.y + pad, w.z)
	return null


## Forearm angle (degrees) for the same lookup, 0 if the rig has none.
static func angle_at(p_rig: Dictionary, point: String, anim: String, frame: int) -> float:
	var pts: Dictionary = (p_rig.get("points", {}) as Dictionary).get(point, {})
	var per_frame: Variant = (pts.get("anims", {}) as Dictionary).get(anim)
	var raw: Variant = null
	if per_frame is Array and not (per_frame as Array).is_empty():
		raw = (per_frame as Array)[clampi(frame, 0, (per_frame as Array).size() - 1)]
	else:
		raw = (pts.get("facing", {}) as Dictionary).get(facing_from_anim(anim))
	return float((raw as Array)[3]) if raw is Array and (raw as Array).size() > 3 else 0.0


static func _vec(v: Variant) -> Variant:
	if not v is Array or (v as Array).size() < 2:
		return null
	var a: Array = v
	return Vector3(float(a[0]), float(a[1]), float(a[2]) if a.size() > 2 else 1.0)


## True if `dir` is an attach art set (attach.json, or facing pictures at its top).
static func is_art(dir: String) -> bool:
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return false
	if FileAccess.file_exists(dir.path_join("attach.json")):
		return true
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() == "png" and f.get_basename() in FACINGS:
			return true
	return false


## {dir, point, grip: Vector2, grips: {facing: Vector2}, z: {facing: int},
##  rotate, order, pics: {facing: path}, any: path}. Cached.
static func load_art(dir: String) -> Dictionary:
	if _arts.has(dir):
		return _arts[dir]
	var meta: Dictionary = {}
	if FileAccess.file_exists(dir.path_join("attach.json")):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("attach.json")))
		meta = d if d is Dictionary else {}
	var pics := {}
	var any := ""
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			if f.get_extension().to_lower() != "png":
				continue
			if f.get_basename() in FACINGS:
				pics[f.get_basename()] = dir.path_join(f)
			elif any == "":
				any = dir.path_join(f)
	var grips := {}
	for k: String in (meta.get("grips", {}) as Dictionary):
		grips[k] = _v2(meta["grips"][k])
	var out := {"dir": dir, "point": str(meta.get("point", "hand_r")), "grip": _v2(meta.get("grip", [0, 0])),
		"grips": grips, "z": meta.get("z", {}), "rotate": bool(meta.get("rotate", false)),
		"order": int(meta.get("order", 0)), "cover": int(meta.get("cover", 0)), "pics": pics, "any": any}
	_arts[dir] = out
	return out


static func _v2(v: Variant) -> Vector2:
	return Vector2(float(v[0]), float(v[1])) if v is Array and (v as Array).size() >= 2 else Vector2.ZERO


## Picture for a facing: [path, flip_h, source facing]. Own picture, else the
## mirror's flipped, else the nearest drawn facing round the compass, else the
## single picture. ["", false, ""] if the set is empty.
static func art_for(art: Dictionary, facing: String) -> Array:
	var pics: Dictionary = art.get("pics", {})
	if pics.has(facing):
		return [pics[facing], false, facing]
	var m := str(MIRROR.get(facing, ""))
	if m != facing and pics.has(m):
		return [pics[m], true, m]
	var i := FACINGS.find(facing)
	if i >= 0:
		for step in range(1, 5):
			for f: String in [FACINGS[(i + step) % 8], FACINGS[(i - step + 8) % 8]]:
				if pics.has(f):
					return [pics[f], false, f]
	var any := str(art.get("any", ""))
	if any != "":
		return [any, facing in ["W", "NW", "SW"], ""]
	return ["", false, ""]


## Where a piece sits and how it is drawn this frame, in the body sprite's
## local pixels: {pos: Vector2, flip: bool, front: bool, angle: float, path}
## or {} when it isn't shown. `flip` is the body's flip_h, `offset` its offset
## (centered off), `cell` the anim's cell size.
static func place(p_rig: Dictionary, art: Dictionary, anim: String, frame: int, flip: bool, offset: Vector2, cell: Vector2) -> Dictionary:
	var drawn := facing_from_anim(anim)
	var point := str(art.get("point", "hand_r"))
	var p: Variant = point_at(p_rig, point, anim, frame, drawn, cell.x)
	if p == null:
		return {}
	var v: Vector3 = p
	# A flipped body (SW drawn as mirrored SE) keeps the drawn facing's art,
	# side and z, mirrored, so the piece stays in the same hand on screen.
	var pic := art_for(art, drawn)
	if str(pic[0]) == "":
		return {}
	var grip: Vector2 = (art.get("grips", {}) as Dictionary).get(str(pic[2]), art.get("grip", Vector2.ZERO))
	var x := (cell.x - v.x) if flip else v.x
	var z := v.z
	var zo: Dictionary = art.get("z", {})
	if zo.has(drawn):
		z = float(zo[drawn])
	var ang := angle_at(p_rig, point, anim, frame) if bool(art.get("rotate", false)) else 0.0
	return {"pos": offset + Vector2(x, v.y), "grip": grip, "flip": flip != bool(pic[1]),
		"front": z >= 0.0, "angle": -ang if flip else ang, "path": str(pic[0]),
		"point": Vector2(v.x, v.y), "cover": cover_rect(Vector2(v.x, v.y), int(art.get("cover", 0)), cell,
			point_at(p_rig, point.replace("hand", "elbow"), anim, frame, drawn, cell.x) if point.begins_with("hand") else null) if z >= 0.0 else Rect2()}


## The patch of the body (cell pixels, unflipped) redrawn over a held piece:
## a square of radius `r` round the point, stretched to the elbow when the rig
## has one (elbow_r / elbow_l), so the forearm in front covers the handle too.
## Clipped to the cell. Empty if r <= 0.
static func cover_rect(point: Vector2, r: int, cell: Vector2, elbow: Variant = null) -> Rect2:
	if r <= 0:
		return Rect2()
	var rect := Rect2(point.x - r, point.y - r, r * 2 + 1, r * 2 + 1)
	if elbow is Vector3:
		var e: Vector3 = elbow
		rect = rect.merge(Rect2(e.x - r, e.y - r, r * 2 + 1, r * 2 + 1))
	return rect.intersection(Rect2(Vector2.ZERO, cell)) if cell != Vector2.ZERO else rect


## Builds a GearAttach under `spr` for the given art folders (skips folders
## that aren't attach art). Returns null when there's nothing to attach.
static func attach_to(spr: AnimatedSprite2D, body_dir: String, art_dirs: Array) -> GearAttach:
	var r := load_rig(body_dir)
	var arts: Array = []
	for d: String in art_dirs:
		if is_art(d):
			arts.append(load_art(d))
	if r.is_empty() or arts.is_empty():
		return null
	arts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	var g := GearAttach.new()
	g.name = "GearAttach"
	g.body = spr
	g.rig = r
	spr.add_child(g)
	for a: Dictionary in arts:
		# Pieces are the body's own children so show_behind_parent puts them
		# behind the body; tree order (art "order") stacks pieces on one side.
		var s := Sprite2D.new()
		s.name = "Gear_" + str(a["dir"]).get_file()
		s.centered = false
		s.use_parent_material = true
		s.visible = false
		spr.add_child(s)
		# The fist: a window onto the body's current frame, drawn over the piece.
		var c := Sprite2D.new()
		c.name = s.name + "_Hand"
		c.centered = false
		c.use_parent_material = true
		c.visible = false
		spr.add_child(c)
		g.pieces.append({"art": a, "node": s, "cover": c})
	g.sync()
	return g


func _process(_dt: float) -> void:
	sync()


func _exit_tree() -> void:
	for pc: Dictionary in pieces:
		for k: String in ["node", "cover"]:
			var n: Node = pc.get(k)
			if is_instance_valid(n):
				n.queue_free()
	pieces.clear()


## Follows the body: cheap when nothing changed.
func sync() -> void:
	if body == null or body.sprite_frames == null:
		return
	var anim := str(body.animation)
	var key := "%s|%d|%s|%s" % [anim, body.frame, body.flip_h, body.offset]
	if key == _state:
		return
	_state = key
	var cell := Vector2.ZERO
	var tex := body.sprite_frames.get_frame_texture(body.animation, body.frame) if body.sprite_frames.has_animation(body.animation) else null
	if tex:
		cell = tex.get_size()
	for pc: Dictionary in pieces:
		var s: Sprite2D = pc["node"]
		var cv: Sprite2D = pc["cover"]
		cv.visible = false
		var pl := place(rig, pc["art"], anim, body.frame, body.flip_h, body.offset, cell)
		if pl.is_empty():
			s.visible = false
			continue
		s.texture = ForgeStore.load_texture(str(pl["path"]))
		if s.texture == null:
			s.visible = false
			continue
		s.visible = true
		s.flip_h = bool(pl["flip"])
		var grip: Vector2 = pl["grip"]
		var w := float(s.texture.get_width())
		# The grip pixel lands on the point; flipped art holds the mirrored pixel.
		s.offset = -Vector2(w - grip.x if s.flip_h else grip.x, grip.y)
		s.position = pl["pos"]
		s.rotation_degrees = float(pl["angle"])
		s.show_behind_parent = not bool(pl["front"])
		var cr: Rect2 = pl["cover"]
		if cr.has_area() and tex:
			_show_cover(cv, tex, cr, cell, body.flip_h, body.offset)


## Points `cv` at the region `cr` of the body frame `tex`, placed where the
## body draws it (mirrored when the body is flipped).
func _show_cover(cv: Sprite2D, tex: Texture2D, cr: Rect2, cell: Vector2, flip: bool, offset: Vector2) -> void:
	var at := AtlasTexture.new()
	if tex is AtlasTexture:
		var src := tex as AtlasTexture
		at.atlas = src.atlas
		at.region = Rect2(src.region.position + cr.position, cr.size)
	else:
		at.atlas = tex
		at.region = cr
	cv.texture = at
	cv.flip_h = flip
	cv.position = offset + Vector2(cell.x - cr.position.x - cr.size.x if flip else cr.position.x, cr.position.y)
	cv.visible = true
