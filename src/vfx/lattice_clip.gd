class_name LatticeClip
extends RefCounted
## Reads Grok's "lattice.clip" animation exports: a JSON next to a PNG strip.
##   cell [w,h], frames, rects[{x,y,w,h}], fps / frameMs, holds, tickSequence,
##   loop, anchor [x,y] (ground contact pixel), sourceArt.footprint {w,h},
##   phaseSeed, emitters {beacons, windows, pointLights, neon, vents},
##   textures.strip, overlayClip (optional FX layer drawn on top).
## Objects can use the .json as their asset: the renderer plays it with the
## right anchor, footprint and timing, desynced per instance, and hangs small
## real lights on the clip's beacons / windows.

const FORMAT := "lattice.clip"

static var _cache: Dictionary = {}


static func is_clip(path: String) -> bool:
	if not path.ends_with(".json") or not FileAccess.file_exists(path):
		return false
	var head := FileAccess.get_file_as_string(path).left(200)
	return head.contains('"' + FORMAT + '"')


## The clip JSON for a strip / static PNG (name_strip.png → name.json), or "".
static func find_for_png(png: String) -> String:
	var base := png.get_basename()
	var stem := base.trim_suffix("_strip")
	for cand in [stem + "_clip.json", stem + ".json", base + ".json"]:
		if is_clip(cand):
			return cand
	return ""


## Parsed clip (cached): {ok, tex, rects, seq, ms, total, loop, anchor, cell,
## footprint, phase, emitters, overlay, title, bbox}.
## `dir` picks one facing out of a "dirs-rows" sheet (N, NE … NW).
## Rules follow Lattice's CLIP_FORMAT_GUIDE: holds are tick multipliers,
## missing loop = false, anchor falls back to pivot then bottom-centre.
static func load_clip(path: String, facing_dir: String = "") -> Dictionary:
	var key := path + "#" + facing_dir
	if _cache.has(key):
		return _cache[key]
	var out := {"ok": false}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (d is Dictionary) or str(d.get("format", "")) != FORMAT or str(d.get("kind", "")) == "combined":
		_cache[key] = out
		return out
	var dir := path.get_base_dir()
	var strip := str((d.get("textures", {}) as Dictionary).get("strip", ""))
	var tex := ForgeStore.load_texture(dir.path_join(strip)) if strip != "" else null
	if tex == null:
		_cache[key] = out
		return out
	var cell: Array = d.get("cell", [tex.get_width(), tex.get_height()])
	var rects: Array[Rect2] = []
	var rows := str(d.get("layout", "")) == "dirs-rows"
	if rows and facing_dir == "":
		facing_dir = str((d.get("dirOrder", ["SE"]) as Array)[3 if (d.get("dirOrder", []) as Array).size() > 3 else 0])
	for r: Dictionary in d.get("rects", []):
		if rows and str(r.get("dir", "")) != facing_dir:
			continue
		rects.append(Rect2(float(r["x"]), float(r["y"]), float(r["w"]), float(r["h"])))
	if rects.is_empty():
		# No rects: slice a horizontal (or vertical) strip by cell size.
		var n := int(d.get("frames", 1))
		var vertical := str(d.get("layout", "horizontal")) == "vertical"
		for i in n:
			rects.append(Rect2(0 if vertical else i * float(cell[0]), i * float(cell[1]) if vertical else 0, float(cell[0]), float(cell[1])))
	if rects.is_empty():
		_cache[key] = out
		return out
	tex = _keyed(path, tex, d, rects)
	var frame_ms := float(d.get("frameMs", 1000.0 / maxf(float(d.get("fps", 10)), 0.1)))
	var seq: Array = d.get("tickSequence") if d.get("tickSequence") is Array else range(rects.size())
	var holds: Variant = d.get("holds")
	var ms: Array = []
	for k in seq.size():
		var h := frame_ms
		var fi := int(seq[k])
		if holds is Array and fi < (holds as Array).size() and holds[fi] != null:
			h = frame_ms * maxf(roundf(float(holds[fi])), 1.0)  # ticks, never ms
		ms.append(h)
	var total := 0.0
	for m: float in ms:
		total += m
	var foot: Dictionary = (d.get("sourceArt", {}) as Dictionary).get("footprint", {}) if d.get("sourceArt") is Dictionary else {}
	if d.get("gameFootprint") is Dictionary:  # our grid's tiles, if the animator sets it
		foot = d["gameFootprint"]
	var anchor := anchor_of(d)
	var bbox: Array = d.get("buildingBBox", [0, 0, cell[0], cell[1]])
	out = {"ok": true, "tex": tex, "rects": rects, "seq": seq, "ms": ms, "total": maxf(total, 1.0),
		"loop": d.get("loop") == true, "anchor": anchor, "kind": base_kind(d), "facing": str(d.get("facing")) if d.get("facing") != null else facing_dir,
		"is_overlay": overlay_flag(d), "next": str(d.get("endsOn", d.get("next", ""))) if (d.get("endsOn", d.get("next")) is String) else "",
		"cell": Vector2(float(cell[0]), float(cell[1])), "footprint": maxi(int(foot.get("w", 1)), int(foot.get("h", 1))),
		"frame_ms": frame_ms, "phase": float(d.get("phaseSeed", 0)) / 1000.0, "emitters": d.get("emitters", {}) if d.get("emitters") is Dictionary else {},
		"overlay": "", "title": str(d.get("title", d.get("name", ""))), "bbox": bbox, "sort_bias": int(d.get("sortBias", 0))}
	var ov := str(d.get("overlayClip", "")) if d.get("overlayClip") != null else ""
	if ov != "" and is_clip(dir.path_join(ov)):
		out["overlay"] = dir.path_join(ov)
	_cache[key] = out
	return out


## Ground-contact pixel: anchor, else pivot ([x,y] or {x,y}), else bottom-centre.
static func anchor_of(d: Dictionary) -> Vector2:
	var a: Variant = d.get("anchor")
	if a == null:
		a = d.get("pivot")
	if a is Array and (a as Array).size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	if a is Dictionary:
		return Vector2(float(a.get("x", 0)), float(a.get("y", 0)))
	var cell: Array = d.get("cell", [0, 0])
	return Vector2(int(cell[0]) >> 1, int(cell[1]) - 1)


## Kind with "_overlay" dropped and Lattice's aliases folded:
## attack/aim/fire → aim_fire, research/upgrading → ambient, destroying/destroyed → building_destroy.
static func base_kind(d: Dictionary) -> String:
	var k := str(d.get("kind", "")) if d.get("kind") != null else ""
	k = k.trim_suffix("_overlay")
	match k:
		"attack", "aim", "fire": return "aim_fire"
		"research", "upgrading": return "ambient"
		"destroying", "destroyed": return "building_destroy"
	return k


static func overlay_flag(d: Dictionary) -> bool:
	return str(d.get("kind", "")).ends_with("_overlay") or d.get("overlay") == true or d.get("overlayOf") != null


## FX-only twins (overlays, damage stages) shouldn't show up as placeable objects.
static func is_overlay(path: String) -> bool:
	if path.ends_with("_overlay_clip.json"):
		return true
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return d is Dictionary and overlay_flag(d)


## [x,y], {x,y} or {frame,x,y} → Vector2.
static func point(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Dictionary:
		return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
	return Vector2.INF


## Opaque strips ("Background is the art's own opaque near-black", or a
## "bgKey" colour) get their background keyed out: flood-filled in from the
## frame edges on frame 0, so dark pixels *inside* the building survive, then
## that mask is applied to every frame. Cached in user://lattice_keyed.
const KEY_DIR := "user://lattice_keyed"
const KEY_TOL := 10  # max per-channel distance (0-255) from the background colour


static func _keyed(path: String, tex: Texture2D, d: Dictionary, rects: Array[Rect2]) -> Texture2D:
	if d.get("bgKey") == false or rects.is_empty():
		return tex
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var r0 := Rect2i(rects[0])
	var corners := [r0.position, Vector2i(r0.end.x - 1, r0.position.y), Vector2i(r0.position.x, r0.end.y - 1), r0.end - Vector2i.ONE]
	var bg: Color
	if d.get("bgKey") is String:
		bg = Color(str(d["bgKey"]))
	else:
		# Auto: all four corners opaque and the same colour → that's a backdrop.
		bg = img.get_pixelv(corners[0])
		for c: Vector2i in corners:
			var px := img.get_pixelv(c)
			if px.a < 0.99 or absf(px.r - bg.r) * 255.0 > KEY_TOL or absf(px.g - bg.g) * 255.0 > KEY_TOL or absf(px.b - bg.b) * 255.0 > KEY_TOL:
				return tex
	var stamp := "%s_%d_%d" % [path.get_file().get_basename(), FileAccess.get_modified_time(path), FileAccess.get_modified_time(path.get_base_dir().path_join(str((d.get("textures", {}) as Dictionary).get("strip", ""))))]
	var cached := KEY_DIR.path_join(stamp + ".png")
	if FileAccess.file_exists(cached):
		var ci := Image.load_from_file(ProjectSettings.globalize_path(cached))
		if ci and ci.get_size() == img.get_size():
			return ImageTexture.create_from_image(ci)
	var frame_mask := key_mask(img.get_region(r0), bg)
	var mask := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for r: Rect2 in rects:
		mask.blit_rect(frame_mask, Rect2i(Vector2i.ZERO, frame_mask.get_size()), Vector2i(r.position))
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.blit_rect_mask(img, mask, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	DirAccess.make_dir_recursive_absolute(KEY_DIR)
	out.save_png(cached)
	return ImageTexture.create_from_image(out)


## Mask (opaque = keep) for one frame: background pixels connected to the
## frame edge within KEY_TOL of `bg` are cleared.
static func key_mask(frame: Image, bg: Color) -> Image:
	var w := frame.get_width()
	var h := frame.get_height()
	var src := frame.get_data()
	var br := bg.r8
	var bgg := bg.g8
	var bb := bg.b8
	var gone := PackedByteArray()
	gone.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if gone[i] != 0:
			continue
		var o := i * 4
		if absi(src[o] - br) > KEY_TOL or absi(src[o + 1] - bgg) > KEY_TOL or absi(src[o + 2] - bb) > KEY_TOL:
			continue
		gone[i] = 1
		var x := i % w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if i >= w: stack.append(i - w)
		if i < w * (h - 1): stack.append(i + w)
	var m := PackedByteArray()
	m.resize(w * h * 4)
	for i in w * h:
		var v := 0 if gone[i] != 0 else 255
		m[i * 4] = v
		m[i * 4 + 1] = v
		m[i * 4 + 2] = v
		m[i * 4 + 3] = v
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, m)


## Index into clip.rects for time `t` (seconds), honouring holds and order.
static func frame_at(clip: Dictionary, t: float, phase: float = 0.0) -> int:
	var seq: Array = clip["seq"]
	if seq.is_empty():
		return 0
	var ms: Array = clip["ms"]
	var total: float = clip["total"]
	var at := (t + phase) * 1000.0
	if clip["loop"]:
		at = fposmod(at, total)
	elif at >= total:
		return int(seq[seq.size() - 1])
	for k in seq.size():
		at -= float(ms[k])
		if at < 0.0:
			return int(seq[k])
	return int(seq[seq.size() - 1])


static func frame_texture(clip: Dictionary, index: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = clip["tex"]
	var rects: Array = clip["rects"]
	at.region = rects[clampi(index, 0, rects.size() - 1)]
	return at


## Up to `max_lights` light points (in clip pixels) — beacons first, then
## windows — with the strip colour under each, for real PointLight2Ds.
static func light_points(clip: Dictionary, max_lights: int = 6) -> Array:
	var out: Array = []
	var em: Dictionary = clip.get("emitters", {})
	var pts: Array = []
	for key in ["beacons", "windows"]:
		var lst: Variant = em.get(key, [])
		if lst is Array:
			for p: Variant in lst:
				var v := point(p)
				if v != Vector2.INF:
					pts.append(v)
	if pts.is_empty():
		return out
	var img: Image = (clip["tex"] as Texture2D).get_image()
	if img and img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var step := maxf(float(pts.size()) / max_lights, 1.0)
	var i := 0.0
	var r0: Rect2 = (clip["rects"] as Array)[0]
	while int(i) < pts.size() and out.size() < max_lights:
		var p: Vector2 = pts[int(i)]
		var col := Color(0.4, 1.0, 1.0)
		if img:
			var px := Vector2i(r0.position + p).clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
			col = img.get_pixelv(px)
			col.a = 1.0
			if col.get_luminance() < 0.25:
				col = col.lightened(0.5)
		out.append({"pos": p, "color": col})
		i += step
	return out


# ── Units: a folder of per-action, per-facing clips → one SpriteFrames ──

const FACINGS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
static var _units: Dictionary = {}
static var _name_rx: RegEx


## Our action name for a clip kind (or file token): aim_fire → attack, hurt → hit.
static func action_name(kind: String) -> String:
	match kind:
		"aim_fire", "attack", "fire", "aim": return "attack"
		"hurt": return "hit"
	return kind


## Splits "gv_g04_SE_idle_clip.json" → ["gv_g04", "SE", "idle"], or [] if it
## doesn't follow the <unit>_<FACING>_<action>_clip.json naming.
static func split_name(file: String) -> Array:
	if _name_rx == null:
		_name_rx = RegEx.create_from_string("^(.+)_(N|NE|E|SE|S|SW|W|NW)_([A-Za-z0-9_]+?)_clip\\.json$")
	var m := _name_rx.search(file)
	return [] if m == null else [m.get_string(1), m.get_string(2), m.get_string(3)]


## Every clip for the unit that `json_path` belongs to: sibling files with the
## same prefix (plus the matching gold_vehicles_damage pack, if it exists), or
## all facings of a dirs-rows sheet. Overlays are skipped (full clips already
## contain them). Returns {ok, frames: SpriteFrames, anchors {anim: Vector2},
## cells {anim: Vector2}, next {anim: anim}}; anims are "<action>_<FACING>",
## or just "<action>" for facing-agnostic clips.
static func unit_set(json_path: String) -> Dictionary:
	if _units.has(json_path):
		return _units[json_path]
	var out := {"ok": false, "frames": SpriteFrames.new(), "anchors": {}, "cells": {}, "next": {}}
	var sf: SpriteFrames = out["frames"]
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	var files: Array[String] = []
	var parts := split_name(json_path.get_file())
	if parts.is_empty():
		files.append(json_path)
	else:
		var sources := [[json_path.get_base_dir(), str(parts[0])]]
		var dmg_dir := json_path.get_base_dir().replace("gold_vehicles", "gold_vehicles_damage")
		if dmg_dir != json_path.get_base_dir():
			sources.append([dmg_dir, str(parts[0]).replace("gv_", "gvd_")])
		for src: Array in sources:
			if not DirAccess.dir_exists_absolute(str(src[0])):
				continue
			for f in DirAccess.get_files_at(str(src[0])):
				var p := split_name(f)
				if not p.is_empty() and p[0] == src[1]:
					files.append(str(src[0]).path_join(f))
	for f in files:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary) or overlay_flag(d):
			continue
		var dirs: Array = [""]
		if str(d.get("layout", "")) == "dirs-rows":
			dirs = d.get("dirOrder", FACINGS)
		for dir: String in dirs:
			var c := load_clip(f, dir)
			if not c.get("ok", false):
				continue
			var p := split_name(f.get_file())
			var action := action_name(str(c["kind"]) if str(c["kind"]) != "" else (str(p[2]) if not p.is_empty() else "idle"))
			var facing := str(c["facing"]) if str(c["facing"]) != "" else (str(p[1]) if not p.is_empty() else "")
			var anim := action + ("_" + facing if facing != "" else "")
			if sf.has_animation(anim):
				continue
			sf.add_animation(anim)
			sf.set_animation_speed(anim, 1000.0 / float(c["frame_ms"]))
			sf.set_animation_loop(anim, bool(c["loop"]))
			var seq: Array = c["seq"]
			for k in seq.size():
				sf.add_frame(anim, frame_texture(c, int(seq[k])), float(c["ms"][k]) / float(c["frame_ms"]))
			out["anchors"][anim] = c["anchor"]
			out["cells"][anim] = c["cell"]
			if str(c["next"]) != "":
				var np := split_name(str(c["next"]) + "_clip.json")
				if not np.is_empty():
					out["next"][anim] = action_name(str(np[2])) + "_" + str(np[1])
	out["ok"] = not sf.get_animation_names().is_empty()
	_units[json_path] = out
	return out


## Grid direction (battle facing) → screen diagonal of the 2:1 iso projection.
static func facing_of(dir: Vector2i) -> String:
	match dir:
		Vector2i(1, 0): return "SE"
		Vector2i(0, 1): return "SW"
		Vector2i(-1, 0): return "NW"
		Vector2i(0, -1): return "NE"
	return "SE"


const MIRROR := {"SE": "SW", "SW": "SE", "NE": "NW", "NW": "NE", "E": "W", "W": "E"}


## Best animation in `set` for `action` facing `facing`: [anim, flip_h], or
## ["", false]. Falls back to the mirrored diagonal (flipped), then any
## facing, then a facing-agnostic clip. "cast" falls back to "attack".
static func resolve(us: Dictionary, action: String, facing: String) -> Array:
	var sf: SpriteFrames = us["frames"]
	for a in [action, "attack"] if action == "cast" else [action]:
		if sf.has_animation(a + "_" + facing):
			return [a + "_" + facing, false]
		if MIRROR.has(facing) and sf.has_animation(a + "_" + str(MIRROR[facing])):
			return [a + "_" + str(MIRROR[facing]), true]
		for f in ["SE", "SW", "NE", "NW", "S", "E", "W", "N"]:
			if sf.has_animation(a + "_" + f):
				return [a + "_" + f, false]
		if sf.has_animation(a):
			return [a, false]
	return ["", false]


## Plays `action` on a sprite built from unit_set(): picks the facing, and
## offsets so the clip's anchor pixel sits on the node origin (mirrored too).
static func play_on(spr: AnimatedSprite2D, us: Dictionary, action: String, facing: String) -> bool:
	var r := resolve(us, action, facing)
	if str(r[0]) == "":
		return false
	var anim := str(r[0])
	var anchor: Vector2 = us["anchors"][anim]
	var cell: Vector2 = us["cells"][anim]
	spr.centered = false
	spr.flip_h = bool(r[1])
	spr.offset = -Vector2(cell.x - anchor.x if spr.flip_h else anchor.x, anchor.y)
	if spr.animation != anim or not spr.is_playing():
		spr.play(anim)
	return true
