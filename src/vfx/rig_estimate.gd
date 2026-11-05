class_name RigEstimate
extends RefCounted
## Builds a body's rig.json (GearAttach anchor points) from its own frames,
## locally and for free: no PixelLab credits. Works on any unit set
## (PixelLab, PixelMatrix, Lattice) because it reads the built SpriteFrames,
## so anim names match what the game plays.
##
## Per frame it reads the silhouette (alpha > 0.5):
##   head    the centre of the top 12% of the body
##   hand_r  the outermost pixel in the hand band (38-64% down the body) on the
##   hand_l  side that hand is on for the facing, lowest row of that reach
## and the side table GearAttach.RIGHT_HAND_FRONT for z. It's a first guess;
## hand-edit rig.json (or replace points with PixelLab keypoints) where a
## pose reads wrong. Points keep the 4th number (forearm angle) at 0.
##
## Run: godot --headless --path . -s res://tools/rig/make_rig.gd -- <body folder> [--force]

const ALPHA := 0.5
const HEAD_BAND := 0.12
const HAND_TOP := 0.38
const HAND_BOTTOM := 0.64
## Screen side (-1 left, +1 right) of the character's right hand per facing.
## Facing the viewer (S, SE, SW) the right hand is on screen-left.
const RIGHT_HAND_SIDE := {"S": -1, "SE": -1, "SW": -1, "E": 1, "N": 1, "NE": 1, "NW": 1, "W": -1}


## {head, hand_r, hand_l: Vector3} for one frame, {} if the frame is empty.
static func frame_points(img: Image, facing: String) -> Dictionary:
	if img == null:
		return {}
	var w := img.get_width()
	var h := img.get_height()
	var left := PackedInt32Array()
	var right := PackedInt32Array()
	left.resize(h)
	right.resize(h)
	var top := -1
	var bottom := -1
	for y in h:
		left[y] = -1
		right[y] = -1
		for x in w:
			if img.get_pixel(x, y).a > ALPHA:
				if left[y] < 0:
					left[y] = x
				right[y] = x
		if left[y] >= 0:
			if top < 0:
				top = y
			bottom = y
	if top < 0:
		return {}
	var bh := float(bottom - top + 1)
	# Head: mean x of the top band.
	var sx := 0.0
	var n := 0
	for y in range(top, mini(top + maxi(int(bh * HEAD_BAND), 1), bottom + 1)):
		if left[y] >= 0:
			sx += (left[y] + right[y]) * 0.5
			n += 1
	var head := Vector3(sx / maxf(n, 1), top + bh * HEAD_BAND * 0.6, 1.0)
	var y0 := top + int(bh * HAND_TOP)
	var y1 := top + int(bh * HAND_BOTTOM)
	var lx := _reach(left, y0, y1, -1)
	var rx := _reach(right, y0, y1, 1)
	var side := int(RIGHT_HAND_SIDE.get(facing, -1))
	var z_r := float(GearAttach.RIGHT_HAND_FRONT.get(facing, 1))
	var r := lx if side < 0 else rx
	var l := rx if side < 0 else lx
	return {"head": head, "hand_r": Vector3(r.x, r.y, z_r), "hand_l": Vector3(l.x, l.y, -z_r)}


## Outermost column in rows y0..y1 on one side (dir -1 = left edge), and the
## lowest row reaching within 1 px of it: Vector2(x, y).
static func _reach(edge: PackedInt32Array, y0: int, y1: int, dir: int) -> Vector2:
	var best := -1
	for y in range(y0, y1 + 1):
		if y < 0 or y >= edge.size() or edge[y] < 0:
			continue
		if best < 0 or (edge[y] < best if dir < 0 else edge[y] > best):
			best = edge[y]
	var row := y0
	for y in range(y0, y1 + 1):
		if y >= 0 and y < edge.size() and edge[y] >= 0 and absi(edge[y] - best) <= 1:
			row = y
	# One pixel inside the outline, where a grip would sit.
	return Vector2(best - dir, row)


static func _frame_image(sf: SpriteFrames, anim: StringName, i: int) -> Image:
	var tex := sf.get_frame_texture(anim, i)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	return img


## rig.json content for a unit set (LatticeClip.unit_set shape).
static func from_unit_set(us: Dictionary) -> Dictionary:
	var sf: SpriteFrames = us.get("frames")
	var pts := {"head": {"facing": {}, "anims": {}}, "hand_r": {"facing": {}, "anims": {}}, "hand_l": {"facing": {}, "anims": {}}}
	if sf == null:
		return {"points": pts}
	var names := sf.get_animation_names()
	names.sort()
	for anim: StringName in names:
		var facing := GearAttach.facing_from_anim(str(anim))
		var per := {"head": [], "hand_r": [], "hand_l": []}
		for i in sf.get_frame_count(anim):
			var fp := frame_points(_frame_image(sf, anim, i), facing)
			for k: String in per:
				var v: Vector3 = fp.get(k, Vector3.ZERO)
				(per[k] as Array).append([int(v.x), int(v.y), int(v.z)])
		for k: String in per:
			pts[k]["anims"][str(anim)] = per[k]
			# The idle's first frame is the still default for the facing.
			if facing != "" and str(anim).begins_with("idle_") and not (pts[k]["facing"] as Dictionary).has(facing):
				pts[k]["facing"][facing] = (per[k] as Array)[0] if not (per[k] as Array).is_empty() else [0, 0, 1]
	return {"source": "RigEstimate (silhouette)", "points": pts}


## Writes <dir>/rig.json for the body at `dir` unless one exists (force to
## overwrite). Returns the rig or {} on failure.
static func write_for(dir: String, force: bool = false) -> Dictionary:
	var path := dir.path_join("rig.json")
	if FileAccess.file_exists(path) and not force:
		return GearAttach.load_rig(dir)
	var us: Dictionary = {}
	if PixelLab.is_root(dir):
		us = PixelLab.unit_set(dir)
	elif PixelMatrix.is_root(dir):
		us = PixelMatrix.unit_set(dir)
	if not us.get("ok", false):
		return {}
	var rig := from_unit_set(us)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null or not f.store_string(JSON.stringify(rig, "\t") + "\n"):
		return {}
	f.close()
	GearAttach.clear_cache()
	return rig
