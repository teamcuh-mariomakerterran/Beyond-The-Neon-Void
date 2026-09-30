class_name CutsceneDoc
extends RefCounted
## A loaded PARALLAX cutscene (from tools/cutscene_builder).
##
## Accepts both files the builder writes:
##   *.parallax.json   project save: {version, project: P, assets:[{id,name,src}], sounds:[...]}
##                     images/sounds embedded as data URLs — self-contained.
##   *.cutscene.json   engine recipe: {format:"parallax-cutscene", shots, assets:[{key,file}]}
##                     art referenced by file name; we look it up in the project.
## Everything is normalized to the builder's internal project shape (P) with the
## builder's own defaults (newShot/newLayer), so the renderer mirrors
## cutscene-builder.html line for line. Timing helpers (pv, ease, warp) are
## direct ports of the builder's functions.

const TAU := PI * 2.0

var name: String = "untitled"
var w: int = 320
var h: int = 180
var fps: int = 30
var vars: Dictionary = {}
var shots: Array = []
var units: Array = []   # [{id, name, actions: {name: {asset, frameW, frameH, frames, fps, pivotX, pivotY, groundOffsetY, attach}}}]
var slots: Array = []   # [{name, unit}]
var textures: Dictionary = {}  # asset key -> Texture2D
var sounds: Dictionary = {}    # sound key -> AudioStream
var source_path: String = ""
var warnings: Array[String] = []

const LAYER_DEFAULTS := {
	"kind": "image", "name": "Layer", "asset": "", "slot": "", "action": "idle", "palette": "", "k": null,
	"visible": true, "attach": "", "group": "", "maskLayer": "", "maskInvert": false, "maskSource": false,
	"x": 0.0, "y": 0.0, "scale": 1.0, "opacity": 1.0, "anchor": "bottom", "flipH": false, "flipV": false,
	"speedX": 0.0, "speedY": 0.0, "parallax": 1.0, "tileX": false, "tileY": false,
	"bobAmp": 0.0, "bobSpeed": 1.0, "tint": "#ff4fa3", "tintAmt": 0.0, "bright": 1.0, "sat": 1.0,
	"contrast": 1.0, "hue": 0.0, "blur": 0.0, "blend": "source-over", "color": "#1a1030",
	"frameW": 32, "frameH": 32, "frameCount": 0, "fps": 12.0, "loop": true, "pingpong": false,
	"delay": 0.0, "hideBefore": true, "holdLast": true, "startFrame": 0, "stopScale": 0.0,
	"mblur": 0.0, "mblurSamples": 5,
	"insL": 8, "insR": 8, "insT": 8, "insB": 8, "boxW": 200.0, "boxH": 64.0, "edgeMode": "stretch",
	"fxMode": "shimmer", "amp": 3.0, "freq": 6.0, "speed": 2.0, "band": 1.0, "fxW": 160.0, "fxH": 90.0, "falloff": 1.0,
	"wrap": false, "wrapW": 200.0, "lineH": 1.35, "reveal": 0.0, "revealDelay": 0.0,
	"text": "TEXT", "fontMode": "system", "fontFam": "monospace", "fontSize": 16.0,
	"textColor": "#ffffff", "outline": 1.0, "outlineColor": "#000000", "align": "center", "tracking": 0.0,
	"glyphW": 8, "glyphH": 8, "charset": " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ",
}
const CAM_DEFAULTS := {"panX": 0.0, "panY": 0.0, "zoom0": 1.0, "zoom1": 1.0, "ease": "out", "shake": 0.0,
	"shakeFreq": 22.0, "shakeDecay": true, "follow": "", "followAmt": 1.0, "followX": 0.5, "followY": 0.6, "k": null}
const FX_DEFAULTS := {"bright": 1.0, "contrast": 1.0, "sat": 1.0, "hue": 0.0, "flash": 0.0, "flashColor": "#ffffff",
	"flashDur": 0.18, "vignette": 0.0, "scan": 0.0, "grain": 0.0, "bars": 0.0, "tint": "#3ee0d8", "tintAmt": 0.0, "chroma": 0.0, "k": null}
const ASSET_SEARCH_DIRS := ["res://assets/cutscenes", "res://assets"]


# --- Loading ---------------------------------------------------------------

static func load_file(path: String) -> CutsceneDoc:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("CutsceneDoc: cannot read " + path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("CutsceneDoc: not JSON: " + path)
		return null
	var doc := CutsceneDoc.new()
	doc.source_path = path
	doc.load_dict(parsed)
	return doc


func load_dict(d: Dictionary) -> void:
	if d.has("project"):
		_load_project(d)
	elif d.get("format", "") == "parallax-cutscene" or d.has("shots"):
		_load_engine(d)
	else:
		warnings.append("Unrecognized cutscene file.")
	for S: Dictionary in shots:
		_fill_shot(S)


func _load_project(d: Dictionary) -> void:
	var P: Dictionary = d["project"]
	name = str(P.get("name", "untitled"))
	w = int(P.get("w", 320))
	h = int(P.get("h", 180))
	fps = int(P.get("fps", 30))
	vars = P.get("vars", {})
	for a: Dictionary in d.get("assets", []):
		var tex := _texture_from_data_url(str(a.get("src", "")))
		if tex:
			textures[str(a["id"])] = tex
		else:
			warnings.append("Could not decode image '%s'" % a.get("name", a.get("id")))
	for s: Dictionary in d.get("sounds", []):
		var st := _audio_from_data_url(str(s.get("src", "")))
		if st:
			sounds[str(s["id"])] = st
	for u: Dictionary in P.get("units", []):
		var acts := {}
		var src_acts: Dictionary = u.get("actions", {})
		for k: String in src_acts:
			var a: Dictionary = src_acts[k].duplicate()
			a["asset"] = str(a.get("assetId", ""))
			acts[k] = a
		units.append({"id": str(u.get("id", "")), "name": str(u.get("name", "")), "actions": acts})
	slots = P.get("slots", [])
	shots = P.get("shots", [])
	for S: Dictionary in shots:
		for L: Dictionary in S.get("layers", []):
			L["asset"] = str(L.get("assetId", "")) if L.get("assetId") != null else ""
		var aud := []
		for m: Dictionary in S.get("audio", []):
			aud.append({"t": float(m.get("t", 0)), "key": str(m.get("auId", "")), "vol": float(m.get("vol", 1.0) if m.get("vol") != null else 1.0)})
		S["audio"] = aud


func _load_engine(d: Dictionary) -> void:
	name = str(d.get("name", "untitled"))
	w = int(d.get("width", 320))
	h = int(d.get("height", 180))
	fps = int(d.get("fps", 30))
	for v: Variant in d.get("variables", []):
		vars[str(v)] = "{%s}" % v
	for a: Dictionary in d.get("assets", []):
		var file := str(a.get("file", ""))
		var tex := _find_texture(file)
		if tex:
			textures[file] = tex
		else:
			warnings.append("Missing art: %s" % file)
	for s: Dictionary in d.get("sounds", []):
		var file := str(s.get("file", ""))
		var st := _find_audio(file)
		if st:
			sounds[file] = st
	var i := 0
	for u: Dictionary in d.get("units", []):
		var acts := {}
		var src_acts: Dictionary = u.get("actions", {})
		for k: String in src_acts:
			var a: Dictionary = src_acts[k].duplicate()
			var sheet := str(a.get("sheet", ""))
			a["asset"] = sheet
			if sheet != "" and not textures.has(sheet):
				var tex := _find_texture(sheet)
				if tex:
					textures[sheet] = tex
			acts[k] = a
		units.append({"id": "u%d" % i, "name": str(u.get("name", "")), "actions": acts})
		i += 1
	# Slots are bound by the game at play time; default = slot i -> unit i.
	var si := 0
	for s: Dictionary in d.get("slots", []):
		slots.append({"name": str(s.get("name", "")), "unit": "u%d" % si if si < units.size() else ""})
		si += 1
	for es: Dictionary in d.get("shots", []):
		var S := {
			"name": es.get("name", "Shot"), "dur": es.get("duration", 2.0), "bg": es.get("background", "#05060e"),
			"tin": es.get("transition_in", {}), "cam": es.get("camera", {}), "fx": es.get("grade", {}),
			"stops": es.get("stops", []), "groups": es.get("groups", []), "markers": es.get("markers", []),
			"branch": es.get("branch", []), "next": es.get("next"), "events": es.get("events", []),
			"layers": es.get("layers", []),
		}
		var aud := []
		for m: Dictionary in es.get("audio", []):
			aud.append({"t": float(m.get("t", 0)), "key": str(m.get("sound", "")), "vol": float(m.get("volume", 1.0) if m.get("volume") != null else 1.0)})
		S["audio"] = aud
		for L: Dictionary in S["layers"]:
			L["asset"] = str(L.get("asset", "")) if L.get("asset") != null else ""
			var sa := str(L.get("slotAction", ""))
			if sa != "":
				var parts := sa.split(".")
				L["slot"] = parts[0]
				L["action"] = parts[1] if parts.size() > 1 else "idle"
			if L["asset"] != "" and not textures.has(L["asset"]):
				var tex := _find_texture(L["asset"])
				if tex:
					textures[L["asset"]] = tex
		shots.append(S)


func _fill_shot(S: Dictionary) -> void:
	S["dur"] = float(S.get("dur", 2.0))
	S["bg"] = str(S.get("bg", "#05060e"))
	for key in ["stops", "groups", "markers", "branch", "events", "audio", "layers"]:
		if S.get(key) == null:
			S[key] = []
	var tin: Dictionary = S.get("tin", {}) if S.get("tin") is Dictionary else {}
	S["tin"] = {"type": str(tin.get("type", "cut")), "dur": float(tin.get("dur", 0.3)), "color": str(tin.get("color", "#000000"))}
	S["cam"] = _with_defaults(S.get("cam", {}), CAM_DEFAULTS)
	S["fx"] = _with_defaults(S.get("fx", {}), FX_DEFAULTS)
	var ids := 0
	for L: Dictionary in S["layers"]:
		for k: String in LAYER_DEFAULTS:
			if not L.has(k) or L[k] == null:
				if k != "k":
					L[k] = LAYER_DEFAULTS[k]
		if not L.has("id") or str(L["id"]) == "":
			L["id"] = "L%d" % ids
		ids += 1
	for g: Dictionary in S["groups"]:
		for k in ["x", "y"]:
			if not g.has(k): g[k] = 0.0
		for k in ["scale", "opacity"]:
			if not g.has(k): g[k] = 1.0


static func _with_defaults(d: Variant, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	if d is Dictionary:
		for k: String in d:
			if d[k] != null or k == "k":
				out[k] = d[k]
	return out


# --- Asset lookup ----------------------------------------------------------

static var _file_index: Dictionary = {}


func _find_texture(file: String) -> Texture2D:
	var p := _find_path(file, ["png", "webp", "jpg", "jpeg"])
	return ForgeStore.load_texture(p) if p != "" else null


func _find_audio(file: String) -> AudioStream:
	var p := _find_path(file, ["ogg", "wav", "mp3"])
	return ForgeStore.load_audio(p) if p != "" else null


## Looks next to the cutscene file first, then anywhere under res://assets.
func _find_path(file: String, exts: Array) -> String:
	if file == "":
		return ""
	var base := file.get_file()
	var stem := base.get_basename() if base.get_extension() != "" else base
	var dirs: Array[String] = []
	if source_path != "":
		dirs.append(source_path.get_base_dir())
		dirs.append(source_path.get_base_dir().path_join(source_path.get_file().get_basename().get_basename()))
		dirs.append(source_path.get_base_dir().path_join("assets"))
	for d in dirs:
		for e: String in exts:
			var p := d.path_join(stem + "." + e)
			if FileAccess.file_exists(p):
				return p
	if _file_index.is_empty():
		for root: String in ASSET_SEARCH_DIRS:
			_index_dir(root)
	for e: String in exts:
		var key := (stem + "." + e).to_lower()
		if _file_index.has(key):
			return _file_index[key]
	return ""


static func _index_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if not _file_index.has(f.to_lower()):
			_file_index[f.to_lower()] = dir.path_join(f)
	for sub in DirAccess.get_directories_at(dir):
		_index_dir(dir.path_join(sub))


static func reset_index() -> void:
	_file_index.clear()


static func _decode_data_url(url: String) -> Dictionary:
	if not url.begins_with("data:"):
		return {}
	var comma := url.find(",")
	if comma < 0:
		return {}
	var header := url.substr(5, comma - 5)
	var payload := url.substr(comma + 1)
	var bytes := Marshalls.base64_to_raw(payload) if header.ends_with(";base64") else payload.uri_decode().to_utf8_buffer()
	return {"mime": header.split(";")[0], "bytes": bytes}


static func _texture_from_data_url(url: String) -> Texture2D:
	var d := _decode_data_url(url)
	if d.is_empty():
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match str(d["mime"]):
		"image/png": err = img.load_png_from_buffer(d["bytes"])
		"image/webp": err = img.load_webp_from_buffer(d["bytes"])
		"image/jpeg", "image/jpg": err = img.load_jpg_from_buffer(d["bytes"])
		"image/svg+xml": err = img.load_svg_from_buffer(d["bytes"])
	return ImageTexture.create_from_image(img) if err == OK else null


static func _audio_from_data_url(url: String) -> AudioStream:
	var d := _decode_data_url(url)
	if d.is_empty():
		return null
	match str(d["mime"]):
		"audio/ogg", "audio/vorbis":
			return AudioStreamOggVorbis.load_from_buffer(d["bytes"])
		"audio/wav", "audio/x-wav", "audio/wave":
			return AudioStreamWAV.load_from_buffer(d["bytes"])
		"audio/mpeg", "audio/mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = d["bytes"]
			return mp3
	return null


# --- Builder math (ports) --------------------------------------------------

static func ease_fn(p: float, mode: String) -> float:
	match mode:
		"in": return p * p
		"out": return 1.0 - (1.0 - p) * (1.0 - p)
		"inout": return 2.0 * p * p if p < 0.5 else 1.0 - pow(-2.0 * p + 2.0, 2.0) / 2.0
	return p


static func bezier_ease(c: Array, p: float) -> float:
	if p <= 0.0: return 0.0
	if p >= 1.0: return 1.0
	var x1 := float(c[0]); var y1 := float(c[1]); var x2 := float(c[2]); var y2 := float(c[3])
	var cx := 3.0 * x1; var bx := 3.0 * (x2 - x1) - cx; var ax := 1.0 - cx - bx
	var cy := 3.0 * y1; var by := 3.0 * (y2 - y1) - cy; var ay := 1.0 - cy - by
	var u := p
	for _i in 8:
		var x := ((ax * u + bx) * u + cx) * u - p
		if absf(x) < 1e-6: break
		var dx := (3.0 * ax * u + 2.0 * bx) * u + cx
		if absf(dx) < 1e-6: break
		u -= x / dx
	u = clampf(u, 0.0, 1.0)
	return ((ay * u + by) * u + cy) * u


## Keyframed property value (the builder's pv()).
static func pv(o: Dictionary, key: String, t: float) -> Variant:
	var tracks: Variant = o.get("k")
	if not tracks is Dictionary or not tracks.has(key) or (tracks[key] as Array).is_empty():
		return o.get(key)
	var K: Array = tracks[key]
	if K.size() == 1 or t <= float(K[0]["t"]):
		return K[0]["v"]
	var last: Dictionary = K[K.size() - 1]
	if t >= float(last["t"]):
		return last["v"]
	for i in K.size() - 1:
		var a: Dictionary = K[i]
		var b: Dictionary = K[i + 1]
		if t >= float(a["t"]) and t <= float(b["t"]):
			var span := float(b["t"]) - float(a["t"])
			var q := 1.0 if span <= 0.0 else (t - float(a["t"])) / span
			var f := bezier_ease(a["c"], q) if a.get("c") is Array else ease_fn(q, str(a.get("e", "linear")))
			if a["v"] is float or a["v"] is int:
				return float(a["v"]) + (float(b["v"]) - float(a["v"])) * f
			return a["v"] if f < 1.0 else b["v"]
	return o.get(key)


static func pvf(o: Dictionary, key: String, t: float, fallback: float = 0.0) -> float:
	var v: Variant = pv(o, key, t)
	return float(v) if v is float or v is int else fallback


static func shot_real(S: Dictionary) -> float:
	var total := float(S["dur"])
	for s: Dictionary in S["stops"]:
		total += float(s.get("dur", 0))
	return total


## Real local time -> content time (hit-stop remap).
static func warp(S: Dictionary, lt: float) -> float:
	var stops: Array = S["stops"].duplicate()
	stops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var rem := lt
	for s: Dictionary in stops:
		var st := float(s["t"])
		var sd := float(s["dur"])
		if rem < st:
			return rem
		if rem < st + sd:
			return st
		rem -= sd
	return rem


func subst(text: String) -> String:
	var out := text
	for k: String in vars:
		out = out.replace("{%s}" % k, str(vars[k]))
	return out


func cond_true(c: Dictionary) -> bool:
	var cond := str(c.get("cond", "")).strip_edges()
	if cond == "":
		return true
	var re := RegEx.create_from_string("^\\s*(\\w+)\\s*(==|!=)\\s*(.*?)\\s*$")
	var m := re.search(cond)
	if m == null:
		return false
	var have := str(vars.get(m.get_string(1), ""))
	var want := m.get_string(3).trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	return have == want if m.get_string(2) == "==" else have != want


func shot_index_by_name(nm: Variant) -> int:
	if nm == null or str(nm) == "":
		return -1
	for i in shots.size():
		if str(shots[i].get("id", "")) == str(nm):
			return i
	for i in shots.size():
		if str(shots[i].get("name", "")) == str(nm):
			return i
	return -1


## Linear play order following branches with the current variables.
func play_order() -> Array[int]:
	var out: Array[int] = []
	var seen := {}
	var i := 0
	var guard := 0
	while i >= 0 and i < shots.size() and guard < 128:
		guard += 1
		if seen.has(i):
			break
		seen[i] = true
		out.append(i)
		var S: Dictionary = shots[i]
		var nx := -1
		for b: Dictionary in S["branch"]:
			if cond_true(b):
				nx = shot_index_by_name(b.get("to"))
				break
		if nx < 0 and S.get("next") != null:
			nx = shot_index_by_name(S["next"])
		i = nx if nx >= 0 else i + 1
	if out.is_empty():
		out.append(0)
	return out


func total_time() -> float:
	var t := 0.0
	for i in play_order():
		t += shot_real(shots[i])
	return t


## Unit/action a slotted layer resolves to: {"asset": key, "act": Dictionary} or {}.
func resolve_slot(L: Dictionary) -> Dictionary:
	var slot_name := str(L.get("slot", ""))
	if slot_name == "":
		return {}
	var unit_id := ""
	for s: Dictionary in slots:
		if str(s.get("name", "")) == slot_name:
			unit_id = str(s.get("unit", ""))
	for u: Dictionary in units:
		if str(u["id"]) == unit_id or str(u["name"]) == unit_id:
			var acts: Dictionary = u["actions"]
			var act: Dictionary = acts.get(str(L.get("action", "idle")), {})
			if act.is_empty() and not acts.is_empty():
				act = acts.values()[0]
			if act.is_empty():
				return {}
			return {"asset": str(act.get("asset", "")), "act": act}
	return {}


## Binds a slot to a unit by name at runtime (e.g. ATTACKER -> "Rook").
func bind_slot(slot_name: String, unit_name: String) -> void:
	for s: Dictionary in slots:
		if s["name"] == slot_name:
			s["unit"] = unit_name
			return
	slots.append({"name": slot_name, "unit": unit_name})
