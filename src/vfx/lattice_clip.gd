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
	for cand in [base.trim_suffix("_strip") + ".json", base + ".json"]:
		if is_clip(cand):
			return cand
	return ""


## Parsed clip (cached): {ok, tex, rects, seq, ms, total, loop, anchor, cell,
## footprint, phase, emitters, overlay, title, bbox}.
static func load_clip(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var out := {"ok": false}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (d is Dictionary) or str(d.get("format", "")) != FORMAT:
		_cache[path] = out
		return out
	var dir := path.get_base_dir()
	var strip := str((d.get("textures", {}) as Dictionary).get("strip", ""))
	var tex := ForgeStore.load_texture(dir.path_join(strip)) if strip != "" else null
	if tex == null:
		_cache[path] = out
		return out
	var cell: Array = d.get("cell", [tex.get_width(), tex.get_height()])
	var rects: Array[Rect2] = []
	for r: Dictionary in d.get("rects", []):
		rects.append(Rect2(float(r["x"]), float(r["y"]), float(r["w"]), float(r["h"])))
	if rects.is_empty():
		# No rects: slice a horizontal (or vertical) strip by cell size.
		var n := int(d.get("frames", 1))
		var vertical := str(d.get("layout", "horizontal")) == "vertical"
		for i in n:
			rects.append(Rect2(0 if vertical else i * float(cell[0]), i * float(cell[1]) if vertical else 0, float(cell[0]), float(cell[1])))
	var frame_ms := float(d.get("frameMs", 1000.0 / maxf(float(d.get("fps", 10)), 0.1)))
	var seq: Array = d.get("tickSequence") if d.get("tickSequence") is Array else range(rects.size())
	var holds: Variant = d.get("holds")
	var ms: Array = []
	for k in seq.size():
		var h := frame_ms
		if holds is Array and k < (holds as Array).size():
			var v := float(holds[k])
			h = v if v > 10.0 else frame_ms * maxf(v, 0.0)  # ms, or a multiplier of frameMs
		ms.append(h)
	var total := 0.0
	for m: float in ms:
		total += m
	var foot: Dictionary = (d.get("sourceArt", {}) as Dictionary).get("footprint", {}) if d.get("sourceArt") is Dictionary else {}
	var anchor: Array = d.get("anchor", [float(cell[0]) * 0.5, float(cell[1])])
	var bbox: Array = d.get("buildingBBox", [0, 0, cell[0], cell[1]])
	out = {"ok": true, "tex": tex, "rects": rects, "seq": seq, "ms": ms, "total": maxf(total, 1.0),
		"loop": bool(d.get("loop", true)), "anchor": Vector2(float(anchor[0]), float(anchor[1])),
		"cell": Vector2(float(cell[0]), float(cell[1])), "footprint": maxi(int(foot.get("w", 1)), int(foot.get("h", 1))),
		"phase": float(d.get("phaseSeed", 0)) / 1000.0, "emitters": d.get("emitters", {}) if d.get("emitters") is Dictionary else {},
		"overlay": "", "title": str(d.get("title", d.get("name", ""))), "bbox": bbox, "sort_bias": int(d.get("sortBias", 0))}
	var ov := str(d.get("overlayClip", "")) if d.get("overlayClip") != null else ""
	if ov != "" and is_clip(dir.path_join(ov)):
		out["overlay"] = dir.path_join(ov)
	_cache[path] = out
	return out


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
		for p: Array in em.get(key, []):
			pts.append(Vector2(float(p[0]), float(p[1])))
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
