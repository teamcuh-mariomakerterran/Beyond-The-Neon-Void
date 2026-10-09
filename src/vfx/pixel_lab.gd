class_name PixelLab
extends RefCounted
## Units from PixelLab character exports. A character is a folder holding one
## or more export zips (or their unpacked folders):
##   <export>/metadata.json
##   <export>/<state>/rotations/<direction>.png             8 still poses
##   <export>/<state>/animations/<Anim>/<direction>/frame_000.png …
## Directions are south, south-east, … (animations usually only the four
## diagonals, which are exactly the battle facings). Zips dropped in the
## folder are unpacked once into <folder>/extracted/<zip name>/.
##
## Each animation is matched to a game action from its state / animation name
## (walking → walk, shooting / kick / uppercut → attack, taking hit → hit,
## heal / item → cast, idle / breathing → idle, jump, wave, death…). An
## optional <folder>/pixellab.json overrides the picks and timing:
##   {"actions": {"attack": "attack_kick/Roundhouse_Kick", "idle": "idle_breathing/Breathing_Idle"},
##    "fps": 10, "fps_by_action": {"walk": 12}, "scale": 1.5, "loop": {"attack": false}}
## Animations not picked for an action stay playable under their own slug
## (e.g. "uppercut_SE"). Still rotations fill idle for facings an idle
## animation doesn't cover. Result has the same shape as LatticeClip.unit_set.

const DIRS := {"south": "S", "south-east": "SE", "east": "E", "north-east": "NE",
	"north": "N", "north-west": "NW", "west": "W", "south-west": "SW"}
## Checked in order; the first keyword hit names the action.
const KEYWORDS := [
	["death", ["death", "dying", "die_", "collapse", "dead"]],
	["hit", ["taking_hit", "take_hit", "hurt", "flinch", "knockback", "got_hit"]],
	["cast", ["heal", "item", "potion", "cast", "spell", "throwing_up"]],
	["attack", ["shoot", "shooting", "gun", "fire", "blast", "attack", "kick", "uppercut", "punch", "slash", "swing", "strike", "stab", "wind-up"]],
	["jump", ["jump", "leap"]],
	["wave", ["wave", "waving", "wavi", "hand_in_the_air"]],
	["run", ["run", "sprint", "dash"]],
	["walk", ["walk", "stride", "strides", "march", "step"]],
	["idle", ["idle", "breath", "standing", "looking", "tablet", "stand"]],
]
## One-shot actions (everything else loops).
const ONE_SHOT := ["attack", "cast", "hit", "death", "jump", "wave"]
## Battle units are drawn this many times the tile width / 128 (art is ~60 px
## tall, so ~90 px on a 128-wide tile).
const DEFAULT_SCALE := 1.5

static var _cache: Dictionary = {}
static var _roots: Dictionary = {}


## True if `dir` holds PixelLab exports (zips or unpacked). Cached.
static func is_root(dir: String) -> bool:
	if _roots.has(dir):
		return _roots[dir]
	_roots[dir] = _is_root(dir)
	return _roots[dir]


static func _is_root(dir: String) -> bool:
	if dir == "" or dir.get_extension() != "" or not DirAccess.dir_exists_absolute(dir):
		return false
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() == "zip" and _zip_is_pixellab(dir.path_join(f)):
			return true
	return not _exports(dir).is_empty()


static func _zip_is_pixellab(path: String) -> bool:
	var z := ZIPReader.new()
	if z.open(path) != OK:
		return false
	var ok := false
	for f in z.get_files():
		if f.ends_with("metadata.json") or f.contains("/rotations/"):
			ok = true
			break
	z.close()
	return ok


## Unpacks any zips not unpacked yet. Only .png / .json, no path escapes.
static func unpack(dir: String) -> int:
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() != "zip":
			continue
		var target := dir.path_join("extracted").path_join(f.get_basename().replace(" ", "_").replace("(", "").replace(")", ""))
		if DirAccess.dir_exists_absolute(target):
			continue
		var z := ZIPReader.new()
		if z.open(dir.path_join(f)) != OK:
			continue
		for entry in z.get_files():
			var ext := entry.get_extension().to_lower()
			if entry.ends_with("/") or not ext in ["png", "json"] or entry.contains("..") or entry.begins_with("/"):
				continue
			var out := target.path_join(entry)
			DirAccess.make_dir_recursive_absolute(out.get_base_dir())
			var fa := FileAccess.open(out, FileAccess.WRITE)
			if fa:
				fa.store_buffer(z.read_file(entry))
				fa.close()
		z.close()
		n += 1
	return n


## Unpacked export folders under `dir` (any depth ≤ 3) that contain states.
static func _exports(dir: String) -> Array[String]:
	var out: Array[String] = []
	_find_states(dir, 0, out)
	return out


## Collects state folders (those with a rotations/ or animations/ child).
static func _find_states(dir: String, depth: int, out: Array[String]) -> void:
	if depth > 4:
		return
	var subs := DirAccess.get_directories_at(dir)
	if subs.has("rotations") or subs.has("animations"):
		out.append(dir)
		return
	for s in subs:
		_find_states(dir.path_join(s), depth + 1, out)


static func _facing(dir_name: String) -> String:
	# "north-west-04ffe800" (a re-roll) → north-west.
	for k: String in DIRS:
		if dir_name == k:
			return DIRS[k]
	for k2: String in ["north-west", "north-east", "south-west", "south-east"]:
		if dir_name.begins_with(k2 + "-"):
			return DIRS[k2]
	for k3: String in ["north", "south", "east", "west"]:
		if dir_name.begins_with(k3 + "-"):
			return DIRS[k3]
	return ""


## Game action for a state + animation name ("" = none recognised).
static func classify(state: String, anim: String) -> String:
	var a := anim.to_lower()
	var s := state.to_lower()
	# The animation's own name speaks first, then the state's.
	for text: String in [a, s]:
		for kw: Array in KEYWORDS:
			for word: String in kw[1]:
				if text.contains(word):
					return kw[0]
	return ""


static func slug(text: String) -> String:
	var t := text.to_lower()
	var out := ""
	for ch in t:
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_").left(28)


## Every animation found: [{state, anim, key: "state/Anim", action, facings: {F: [paths]}, rot: {F: path}}].
static func scan(dir: String) -> Array:
	var out: Array = []
	var states := _exports(dir)
	states.sort()
	for st_dir in states:
		var state := st_dir.get_file()
		var rot := {}
		var rd := st_dir.path_join("rotations")
		if DirAccess.dir_exists_absolute(rd):
			for f in DirAccess.get_files_at(rd):
				var fc := _facing(f.get_basename())
				if f.get_extension().to_lower() == "png" and fc != "":
					rot[fc] = rd.path_join(f)
		var ad := st_dir.path_join("animations")
		var anims: PackedStringArray = DirAccess.get_directories_at(ad) if DirAccess.dir_exists_absolute(ad) else PackedStringArray()
		if anims.is_empty():
			# A pose with no animation (e.g. "shooting"): its still rotations
			# make a one-frame version in all 8 directions.
			var still := {}
			for fc0: String in rot:
				still[fc0] = [rot[fc0]]
			out.append({"state": state, "anim": "", "key": state, "action": classify(state, ""), "facings": still, "rot": rot, "still": true})
		for an in anims:
			var facings := {}
			for dname in DirAccess.get_directories_at(ad.path_join(an)):
				var fc2 := _facing(dname)
				if fc2 == "" or facings.has(fc2):
					continue
				var frames: Array = []
				var fdir := ad.path_join(an).path_join(dname)
				var files := Array(DirAccess.get_files_at(fdir)).filter(func(x: String) -> bool: return x.get_extension().to_lower() == "png")
				files.sort()
				for ff: String in files:
					frames.append(fdir.path_join(ff))
				if not frames.is_empty():
					facings[fc2] = frames
			out.append({"state": state, "anim": an, "key": state + "/" + an, "action": classify(state, an), "facings": facings, "rot": rot})
	return out


static func _read_conf(dir: String) -> Dictionary:
	var p := dir.path_join("pixellab.json")
	if not FileAccess.file_exists(p):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


## Which animation plays each action: the config's picks, else the first
## match (states sorted by name), preferring states named after the action.
static func pick_actions(entries: Array, conf: Dictionary = {}) -> Dictionary:
	var picks := {}
	var forced: Dictionary = conf.get("actions", {})
	for action: String in forced:
		for e: Dictionary in entries:
			if e["key"] == str(forced[action]) or e["state"] == str(forced[action]):
				if not (e["facings"] as Dictionary).is_empty():
					picks[action] = e
					break
	# Real animations first, one-frame poses only where nothing moves.
	for still_pass in [false, true]:
		for e: Dictionary in entries:
			var a := str(e["action"])
			if a == "" or picks.has(a) or forced.has(a) or (e["facings"] as Dictionary).is_empty():
				continue
			if bool(e.get("still", false)) != still_pass:
				continue
			picks[a] = e
	# A run can stand in for a missing walk.
	if not picks.has("walk") and picks.has("run"):
		picks["walk"] = picks["run"]
	return picks


## Feet pixel of a frame: canvas centre x, lowest opaque row.
static func _feet(path: String) -> Vector2:
	var tex := ForgeStore.load_texture(path)
	if tex == null:
		return Vector2.ZERO
	var img := tex.get_image()
	if img == null:
		return Vector2(tex.get_width() * 0.5, tex.get_height())
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var used := img.get_used_rect()
	return Vector2(img.get_width() * 0.5, used.end.y - 1 if used.size.y > 0 else img.get_height())


## Same shape as LatticeClip.unit_set: {ok, frames, anchors, cells, next,
## per_tile (draw scale per tile width), actions {action: "state/Anim"}}.
static func unit_set(dir: String) -> Dictionary:
	if _cache.has(dir):
		return _cache[dir]
	unpack(dir)
	var conf := _read_conf(dir)
	var out := {"ok": false, "frames": SpriteFrames.new(), "anchors": {}, "cells": {}, "next": {}, "actions": {},
		"per_tile": float(conf.get("scale", DEFAULT_SCALE)) / 128.0}
	var sf: SpriteFrames = out["frames"]
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	var entries := scan(dir)
	var picks := pick_actions(entries, conf)
	var fps := float(conf.get("fps", 10))
	var fps_by: Dictionary = conf.get("fps_by_action", {})
	var loops: Dictionary = conf.get("loop", {})
	var used := {}
	for action: String in picks:
		var e: Dictionary = picks[action]
		out["actions"][action] = e["key"]
		used[e["key"]] = true
		_add(out, action, e, float(fps_by.get(action, fps)), bool(loops.get(action, not action in ONE_SHOT)))
	# Everything else under its own name, so abilities can ask for it.
	for e2: Dictionary in entries:
		if used.has(e2["key"]) or (e2["facings"] as Dictionary).is_empty() or bool(e2.get("still", false)):
			continue
		var nm := slug(str(e2["anim"]) if str(e2["anim"]) != "" else str(e2["state"]))
		if nm != "" and not sf.has_animation(nm + "_SE"):
			_add(out, nm, e2, fps, not str(e2["action"]) in ONE_SHOT)
	# Still poses: idle for any facing without one (all 8 directions).
	var still_src: Dictionary = {}
	for a2: String in ["idle", "walk", "run"]:
		if still_src.is_empty() and picks.has(a2):
			still_src = (picks[a2] as Dictionary).get("rot", {})
	if still_src.is_empty():
		for e3: Dictionary in entries:
			if not (e3["rot"] as Dictionary).is_empty():
				still_src = e3["rot"]
				break
	for fc: String in still_src:
		var nm2 := "idle_" + fc
		if sf.has_animation(nm2):
			continue
		var tex := ForgeStore.load_texture(str(still_src[fc]))
		if tex == null:
			continue
		sf.add_animation(nm2)
		sf.set_animation_loop(nm2, true)
		sf.add_frame(nm2, tex)
		out["anchors"][nm2] = _feet(str(still_src[fc]))
		out["cells"][nm2] = tex.get_size()
	out["ok"] = not sf.get_animation_names().is_empty()
	_cache[dir] = out
	return out


static func _add(out: Dictionary, action: String, e: Dictionary, fps: float, loop: bool) -> void:
	var sf: SpriteFrames = out["frames"]
	var facings: Dictionary = e["facings"]
	var rot: Dictionary = e["rot"]
	for fc: String in facings:
		var nm := action + "_" + fc
		if sf.has_animation(nm):
			continue
		var first: Texture2D = null
		sf.add_animation(nm)
		sf.set_animation_speed(nm, fps)
		sf.set_animation_loop(nm, loop)
		for p: String in facings[fc]:
			var tex := ForgeStore.load_texture(p)
			if tex:
				sf.add_frame(nm, tex)
				if first == null:
					first = tex
		if first == null:
			sf.remove_animation(nm)
			continue
		# Feet from the still pose of this state (jumps leave the ground).
		var ref := str(rot.get(fc, (facings[fc] as Array)[0]))
		out["anchors"][nm] = _feet(ref)
		out["cells"][nm] = first.get_size()
