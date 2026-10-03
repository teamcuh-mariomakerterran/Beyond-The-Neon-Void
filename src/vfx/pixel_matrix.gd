class_name PixelMatrix
extends RefCounted
## Units from Grok's PixelMatrix exports. A character is a folder:
##   <root>/<anim>/<FACING>.png            whole body (optional)
##   <root>/<anim>/<FACING>_<Limb>.png     limb layers (Head, Torso, Hips,
##                                          LeftArm, RightArm, LeftLeg, RightLeg)
##   <root>/pm.json                         optional {"anchor": [x, y], "fps": 10, "loop": {"attack": false}}
## Strips are horizontal rows of square cells (cell = strip height).
## Layers are composited ONCE per anim + facing, back to front in the
## facing's depth order (arms/legs swap sides as the body turns), so a unit
## costs one sprite at runtime. Gear folders with the same layout slot each
## piece directly above its limb, so armour never clips when units turn.
## The result plugs into the same unit code as Lattice packs (LatticeClip.play_on).

const LIMBS := ["Head", "Torso", "Hips", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
## Back-to-front draw order per facing (from Grok's PixelMatrix spec).
const DEPTH := {
	"SE": ["RightArm", "RightLeg", "Hips", "Torso", "Head", "LeftArm", "LeftLeg"],
	"SW": ["LeftArm", "LeftLeg", "Hips", "Torso", "Head", "RightArm", "RightLeg"],
	"S": ["RightArm", "LeftArm", "Hips", "Torso", "Head", "RightLeg", "LeftLeg"],
	"E": ["RightArm", "RightLeg", "Hips", "Torso", "Head", "LeftArm", "LeftLeg"],
	"W": ["LeftArm", "LeftLeg", "Hips", "Torso", "Head", "RightArm", "RightLeg"],
	"NE": ["LeftLeg", "LeftArm", "Head", "Torso", "Hips", "RightLeg", "RightArm"],
	"NW": ["RightLeg", "RightArm", "Head", "Torso", "Hips", "LeftLeg", "LeftArm"],
	"N": ["LeftArm", "RightArm", "Head", "Torso", "Hips", "LeftLeg", "RightLeg"],
}
const FACINGS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

static var _cache: Dictionary = {}


## "PM_96_SE_walk.png" → {res: 96, facing: "SE", anim: "walk", layer: ""};
## a fifth part is a layer ("PM_96_SE_walk_LeftArm.png"). {} if not PixelMatrix.
static func parse_export(file: String) -> Dictionary:
	var base := file.get_file().get_basename()
	var parts := base.split("_")
	if parts.size() < 4 or parts[0] != "PM" or not parts[1].is_valid_int() or not parts[2] in FACINGS:
		return {}
	return {"res": int(parts[1]), "facing": parts[2], "anim": parts[3], "layer": "_".join(parts.slice(4))}


## True if `dir` looks like a PixelMatrix character folder.
static func is_root(dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(dir):
		return false
	for sub in DirAccess.get_directories_at(dir):
		for f in DirAccess.get_files_at(dir.path_join(sub)):
			if f.get_extension().to_lower() == "png" and f.get_basename().split("_")[0] in FACINGS:
				return true
	return false


## {anim: {facing: {layer ("" = body): path}}}
static func scan(root: String) -> Dictionary:
	var out := {}
	if not DirAccess.dir_exists_absolute(root):
		return out
	for anim in DirAccess.get_directories_at(root):
		for f in DirAccess.get_files_at(root.path_join(anim)):
			if f.get_extension().to_lower() != "png":
				continue
			var bits := f.get_basename().split("_")
			if not bits[0] in FACINGS:
				continue
			var layer := "_".join(bits.slice(1))
			if not out.has(anim):
				out[anim] = {}
			if not out[anim].has(bits[0]):
				out[anim][bits[0]] = {}
			out[anim][bits[0]][layer] = root.path_join(anim).path_join(f)
	return out


## Draw order for one facing: body first, then limbs back to front, each
## limb's gear right after it, then anything unrecognised on top.
static func layer_order(facing: String, layers: Array) -> Array:
	var order: Array = []
	if layers.has(""):
		order.append("")
	var depth: Array = DEPTH.get(facing, DEPTH["SE"])
	for limb: String in depth:
		if layers.has(limb):
			order.append(limb)
		for l: String in layers:
			if l.begins_with(limb + "_") and not order.has(l):
				order.append(l)  # gear for this limb, e.g. "Torso_armor"
	for l: String in layers:
		if not order.has(l):
			order.append(l)
	return order


static func _image(path: String) -> Image:
	var tex := ForgeStore.load_texture(path)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## One strip per anim + facing with all layers (and gear) flattened in depth order.
static func composite(root: String, anim: String, facing: String, gear_roots: Array = []) -> Image:
	var layers: Dictionary = (scan(root).get(anim, {}) as Dictionary).get(facing, {}).duplicate()
	for g: String in gear_roots:
		var gl: Dictionary = (scan(g).get(anim, {}) as Dictionary).get(facing, {})
		for l: String in gl:
			var gi := gear_roots.find(g)
			layers[(l + "_gear%d" % gi) if l in LIMBS else ("gear%d%s" % [gi, l])] = gl[l]
	var out: Image = null
	for l: String in layer_order(facing, layers.keys()):
		var img := _image(layers[l])
		if img == null:
			continue
		if out == null:
			out = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return out


## Same shape as LatticeClip.unit_set: {ok, frames, anchors, cells, next}.
## Anims are named "<action>_<FACING>" (attack/aim_fire → attack, hurt → hit).
static func unit_set(root: String, gear_roots: Array = []) -> Dictionary:
	var key := root + "|" + ",".join(gear_roots)
	if _cache.has(key):
		return _cache[key]
	var out := {"ok": false, "frames": SpriteFrames.new(), "anchors": {}, "cells": {}, "next": {}}
	var sf: SpriteFrames = out["frames"]
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	var meta: Dictionary = {}
	if FileAccess.file_exists(root.path_join("pm.json")):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("pm.json")))
		meta = d if d is Dictionary else {}
	var data := scan(root)
	for anim: String in data:
		for facing: String in data[anim]:
			var strip := composite(root, anim, facing, gear_roots)
			if strip == null or strip.get_height() == 0:
				continue
			var cell := strip.get_height()
			var n := maxi(strip.get_width() / cell, 1)
			var tex := ImageTexture.create_from_image(strip)
			var name := LatticeClip.action_name(anim) + "_" + facing
			sf.add_animation(name)
			sf.set_animation_speed(name, float(meta.get("fps", 10)))
			var loops: Dictionary = meta.get("loop", {})
			sf.set_animation_loop(name, bool(loops.get(anim, not anim in ["attack", "aim_fire", "hurt", "hit", "death", "cast"])))
			for i in n:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(i * cell, 0, cell, cell)
				sf.add_frame(name, at)
			var anc: Array = meta.get("anchor", [cell * 0.5, cell - 1])
			out["anchors"][name] = Vector2(float(anc[0]), float(anc[1]))
			out["cells"][name] = Vector2(cell, cell)
	out["ok"] = not sf.get_animation_names().is_empty()
	_cache[key] = out
	return out
