class_name Signage
extends Node
## Living screens. Any object can carry a screen (its four corners on the
## sprite, so skewed isometric panels line up), showing a feed through
## screen.gdshader as an LED board, LCD panel, CRT or hologram.
##
## Feeds are shared channels, so twenty news screens cost one render:
##   news        live headlines (EventBus.broadcast_line "news"/"rumor") + news rumours
##   propaganda  Doctrine slogans (data/signage.json)
##   ads         ad copy + any PNGs in res://assets/signage/ads/
##   stats       live numbers: soul coins, the crew, local time
##   gossip      street rumours and graffiti
##   custom      the object's own text
##
## Object data: "screen": {corners: [[u,v]×4 TL,TR,BR,BL], feed, mode, text,
## bright, cells}. u, v are 0–1 across the sprite's visible box.

const FEEDS := ["news", "propaganda", "ads", "stats", "gossip", "custom"]
const MODES := ["led", "lcd", "crt", "holo"]
const FEED_COLORS := {"news": Color(1.0, 0.75, 0.3), "propaganda": Color(1.0, 0.25, 0.3), "ads": Color(1.0, 0.35, 0.85),
	"stats": Color(0.4, 1.0, 0.6), "gossip": Color(0.6, 0.85, 1.0), "custom": Color(0.3, 1.0, 1.0)}
const DEFAULT_CORNERS := [[0.3, 0.3], [0.7, 0.3], [0.7, 0.5], [0.3, 0.5]]
const SHADER := preload("res://src/vfx/screen.gdshader")
const AD_DIR := "res://assets/signage/ads"

## Newest first. Anything can push here; the news feed shows it next.
static var headlines: Array[String] = []
static var _text: Dictionary = {}
var _channels: Dictionary = {}


static func push_headline(text: String) -> void:
	headlines.push_front(text)
	if headlines.size() > 24:
		headlines.resize(24)


static func _on_broadcast(channel: String, text: String) -> void:
	if channel in ["news", "rumor"]:
		push_headline(text)


func _ready() -> void:
	if not EventBus.broadcast_line.is_connected(Signage._on_broadcast):
		EventBus.broadcast_line.connect(Signage._on_broadcast)


static func text_data() -> Dictionary:
	if _text.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/signage.json")) if FileAccess.file_exists("res://data/signage.json") else null
		_text = d if d is Dictionary else {}
	return _text


## What a feed shows right now: [{text} or {image}].
static func items(feed: String, custom: String = "") -> Array:
	var out: Array = []
	match feed:
		"news":
			for h in headlines.slice(0, 6):
				out.append({"text": h})
			for r: Variant in ContentDB.rumors.values():
				if r is Dictionary and str(r.get("channel", "")) == "news":
					out.append({"text": str(r["text"])})
		"gossip":
			for r: Variant in ContentDB.rumors.values():
				if r is Dictionary and str(r.get("channel", "")) in ["gossip", "graffiti"]:
					out.append({"text": str(r["text"])})
		"propaganda", "ads", "stats":
			for t: Variant in text_data().get(feed, []):
				out.append({"text": fill(str(t))})
			if feed == "ads" and DirAccess.dir_exists_absolute(AD_DIR):
				for f in DirAccess.get_files_at(AD_DIR):
					if f.get_extension().to_lower() in ["png", "webp", "jpg"]:
						out.append({"image": AD_DIR.path_join(f)})
		_:
			out.append({"text": custom if custom != "" else "· · ·"})
	if out.is_empty():
		out.append({"text": custom if custom != "" else feed.to_upper()})
	return out


## Live numbers for stats lines.
static func fill(t: String) -> String:
	if not t.contains("{"):
		return t
	var party: Array = GameManager.get_party_members()
	var leader := str(party[0].display_name).to_upper() if not party.is_empty() else "UNKNOWN"
	var now := Time.get_time_dict_from_system()
	return t.format({"soul_coins": str(GameManager.soul_coins), "leader": leader, "party_size": str(party.size()),
		"time": "%02d:%02d" % [now["hour"], now["minute"]]})


## The shared render of one feed.
func channel(feed: String, custom: String = "") -> Channel:
	var key := feed + "|" + custom
	if not _channels.has(key):
		var c := Channel.new()
		c.feed = feed
		c.custom = custom
		add_child(c)
		_channels[key] = c
	return _channels[key]


## A low-res offscreen board that cycles through a feed's items: long text
## scrolls as a marquee, short text sits centred, images fill the frame.
class Channel extends SubViewport:
	var feed := "news"
	var custom := ""
	var board: Board

	func _ready() -> void:
		size = Vector2i(192, 96)
		transparent_bg = false
		render_target_update_mode = SubViewport.UPDATE_ALWAYS
		board = Board.new()
		board.feed = feed
		board.custom = custom
		board.size = Vector2(size)
		add_child(board)


class Board extends Control:
	var feed := "news"
	var custom := ""
	var _items: Array = []
	var _i := 0
	var _t := 0.0
	var _img: Texture2D

	func _ready() -> void:
		_items = Signage.items(feed, custom)
		_i = absi(hash(feed + custom)) % _items.size()
		_load()

	func _load() -> void:
		var it: Dictionary = _items[_i % _items.size()]
		_img = ForgeStore.load_texture(str(it["image"])) if it.has("image") else null

	## How to fit a line on the panel: {lines, fs, scroll}. Short text shrinks
	## to sit still, slogans and ads may wrap onto two lines, and anything
	## longer (news) scrolls as a marquee.
	func layout(text: String) -> Dictionary:
		var font := get_theme_default_font()
		var room := size.x * 0.92
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		if w <= room or int(40.0 * room / w) >= 24:
			return {"lines": [text], "fs": mini(40, int(40.0 * room / w)), "scroll": false}
		if feed != "news" and text.contains(" "):
			var mid := text.length() / 2
			var cut := -1
			for d in text.length():
				for k: int in [mid - d, mid + d]:
					if cut < 0 and k > 0 and k < text.length() and text[k] == " ":
						cut = k
			var a := text.substr(0, cut)
			var b := text.substr(cut + 1)
			var wa := maxf(font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x, font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x)
			var fs := mini(36, int(40.0 * room / wa))
			if fs >= 18:
				return {"lines": [a, b], "fs": fs, "scroll": false}
		return {"lines": [text], "fs": 34, "scroll": true}

	func hold() -> float:
		var it: Dictionary = _items[_i % _items.size()]
		if it.has("text"):
			var lay := layout(str(it["text"]))
			if lay["scroll"]:
				var w := get_theme_default_font().get_string_size(str(it["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(lay["fs"])).x
				return (w + size.x) / 70.0  # one full scroll
		return 5.0

	func _process(delta: float) -> void:
		_t += delta
		if _t > hold():
			_t = 0.0
			_i += 1
			if _i % _items.size() == 0:
				_items = Signage.items(feed, custom)  # pick up fresh headlines / numbers
			_load()
		queue_redraw()

	func _draw() -> void:
		var col: Color = Signage.FEED_COLORS.get(feed, Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04))
		var it: Dictionary = _items[_i % _items.size()]
		var wipe := clampf(_t * 4.0, 0.0, 1.0)
		if _img:
			draw_texture_rect(_img, Rect2(Vector2.ZERO, size), false)
		else:
			var font := get_theme_default_font()
			var text := str(it.get("text", ""))
			var lay := layout(text)
			var fs: int = lay["fs"]
			var lines: Array = lay["lines"]
			if feed == "propaganda" and not lay["scroll"]:
				# Slogans pulse like a heartbeat.
				col = col.lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 5.0))
			var top := size.y * 0.5 - (lines.size() - 1) * fs * 0.5
			for li in lines.size():
				var line := str(lines[li])
				var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var x := size.x - _t * 70.0 if lay["scroll"] else (size.x - w) * 0.5
				draw_string(font, Vector2(x, top + li * fs + fs * 0.35), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			if feed == "news":
				draw_rect(Rect2(0, 0, size.x, 14), Color(col, 0.9))
				draw_string(font, Vector2(4, 12), "NEWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.02, 0.05))
		# New item wipes in from the top.
		if wipe < 1.0:
			draw_rect(Rect2(0, size.y * wipe, size.x, size.y * (1.0 - wipe)), Color(0.02, 0.01, 0.04))


## The physical screen on a building: a textured quad through screen.gdshader.
class ScreenQuad extends Node2D:
	var points := PackedVector2Array()
	var tex: Texture2D
	var _boot := 0.0

	func setup(screen: Dictionary, seed: float) -> void:
		var m := ShaderMaterial.new()
		m.shader = Signage.SHADER
		m.set_shader_parameter("mode", maxi(Signage.MODES.find(str(screen.get("mode", "led"))), 0))
		var cells := float(screen.get("cells", 64))
		m.set_shader_parameter("cells", Vector2(cells, cells * 0.5))
		m.set_shader_parameter("brightness", float(screen.get("bright", 1.6)))
		m.set_shader_parameter("seed", seed)
		material = m
		set_process(true)

	func _process(delta: float) -> void:
		if _boot < 1.0:
			_boot = minf(_boot + delta * 1.5, 1.0)
			(material as ShaderMaterial).set_shader_parameter("power", _boot)

	func _draw() -> void:
		if tex == null or points.size() != 4:
			return
		draw_polygon(points, PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)
