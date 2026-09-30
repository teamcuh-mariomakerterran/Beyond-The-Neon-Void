class_name IsometricGrid
extends RefCounted
## Logical battle grid: cells with height, terrain, cover and occupants, plus the
## 2:1 isometric projection, height-aware pathfinding, line of sight and cover.
##
## Pure data (no nodes) so the AI, tests and the map editor can use it headless.
## BattleMap renders it; CombatManager mutates it.

const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const COVER_NONE := 0
const COVER_HALF := 1
const COVER_FULL := 2
const MAX_HEIGHT := 12
## Height (in levels) of a standing unit's eyes, used for line of sight.
const EYE_HEIGHT := 1.5

var width: int = 0
var depth: int = 0
var tile_width: float = 64.0
var tile_height: float = 32.0
## Screen pixels per height level.
var height_step: float = 16.0
var origin: Vector2 = Vector2.ZERO

var _cells: Dictionary = {}  # Vector2i -> Cell
## Fallen units by cell — targets for revive / reanimate.
var _corpses: Dictionary = {}


class Cell extends RefCounted:
	var coords: Vector2i
	var height: int = 0
	var terrain: String = "concrete"
	var tile_id: String = ""
	var walkable: bool = true
	var move_cost: int = 1
	var cover: int = COVER_NONE
	var blocks_los: bool = false
	var hazard: String = ""
	var hazard_turns: int = 0
	var prop_id: String = ""
	var occupant: Node = null

	func to_dict() -> Dictionary:
		var d := {"x": coords.x, "y": coords.y, "h": height, "t": terrain}
		if tile_id != "": d["tile"] = tile_id
		if not walkable: d["walkable"] = false
		if move_cost != 1: d["cost"] = move_cost
		if cover != COVER_NONE: d["cover"] = cover
		if blocks_los: d["blocks_los"] = true
		if hazard != "": d["hazard"] = hazard; d["hazard_turns"] = hazard_turns
		if prop_id != "": d["prop"] = prop_id
		return d


# --- Setup -----------------------------------------------------------------

func setup(p_width: int, p_depth: int, terrain: String = "concrete") -> void:
	width = p_width
	depth = p_depth
	_cells.clear()
	for x in width:
		for y in depth:
			var c := Cell.new()
			c.coords = Vector2i(x, y)
			c.terrain = terrain
			_cells[c.coords] = c


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < depth


func get_cell(cell: Vector2i) -> Cell:
	return _cells.get(cell)


func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_cells.keys())
	return out


func get_height(cell: Vector2i) -> int:
	var c := get_cell(cell)
	return c.height if c else 0


func set_height(cell: Vector2i, h: int) -> void:
	var c := get_cell(cell)
	if c:
		c.height = clampi(h, 0, MAX_HEIGHT)


func is_walkable(cell: Vector2i) -> bool:
	var c := get_cell(cell)
	return c != null and c.walkable


# --- Occupancy -------------------------------------------------------------

func get_occupant(cell: Vector2i) -> Node:
	var c := get_cell(cell)
	if c == null or c.occupant == null or not is_instance_valid(c.occupant):
		return null
	return c.occupant


func set_occupant(cell: Vector2i, unit: Node) -> void:
	var c := get_cell(cell)
	if c:
		c.occupant = unit


func clear_occupant(cell: Vector2i, unit: Node = null) -> void:
	var c := get_cell(cell)
	if c and (unit == null or c.occupant == unit):
		c.occupant = null


func move_occupant(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var unit := get_occupant(from_cell)
	clear_occupant(from_cell)
	set_occupant(to_cell, unit)


func add_corpse(cell: Vector2i, unit: Node) -> void:
	_corpses[cell] = unit


func get_corpse(cell: Vector2i) -> Node:
	var u: Node = _corpses.get(cell)
	return u if u != null and is_instance_valid(u) else null


func remove_corpse(cell: Vector2i) -> void:
	_corpses.erase(cell)


func corpse_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_corpses.keys())
	return out


# --- Projection ------------------------------------------------------------

## World position of the centre of a cell's top face.
func grid_to_world(cell: Vector2i, include_height: bool = true) -> Vector2:
	var x := (cell.x - cell.y) * tile_width * 0.5
	var y := (cell.x + cell.y) * tile_height * 0.5
	if include_height:
		y -= get_height(cell) * height_step
	return origin + Vector2(x, y)


## Inverse projection ignoring height (ground plane).
func world_to_grid_flat(world_pos: Vector2) -> Vector2i:
	var p := world_pos - origin
	var gx := (p.x / (tile_width * 0.5) + p.y / (tile_height * 0.5)) * 0.5
	var gy := (p.y / (tile_height * 0.5) - p.x / (tile_width * 0.5)) * 0.5
	return Vector2i(roundi(gx), roundi(gy))


## Height-aware picking: returns the front-most cell whose top face contains
## `world_pos`, or Vector2i(-1, -1) if none.
func pick_cell(world_pos: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_order := -INF
	var hw := tile_width * 0.5
	var hh := tile_height * 0.5
	for cell: Vector2i in _cells:
		var center := grid_to_world(cell)
		var d := world_pos - center
		if absf(d.x) / hw + absf(d.y) / hh <= 1.0:
			var order := float(cell.x + cell.y) + get_height(cell) * 0.01
			if order > best_order:
				best_order = order
				best = cell
	return best


## Draw-order key: larger = drawn later (in front).
static func draw_order(cell: Vector2i) -> int:
	return cell.x + cell.y


# --- Distance & ranges -----------------------------------------------------

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func cardinal_direction(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var d := to_cell - from_cell
	if d == Vector2i.ZERO:
		return Vector2i(1, 0)
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in DIRECTIONS:
		var n := cell + dir
		if in_bounds(n):
			out.append(n)
	return out


## Cells with min_r <= manhattan distance <= max_r from center.
func cells_in_range(center: Vector2i, min_r: int, max_r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-max_r, max_r + 1):
		var rem := max_r - absi(dx)
		for dy in range(-rem, rem + 1):
			var c := center + Vector2i(dx, dy)
			var dist := absi(dx) + absi(dy)
			if dist >= min_r and in_bounds(c):
				out.append(c)
	return out


# --- Pathfinding -----------------------------------------------------------

## Dijkstra flood from `start`. Returns {cell: {"cost": int, "prev": Vector2i}}.
## - Height changes greater than `jump` are impassable.
## - Units of other teams block movement; allies can be passed through.
## - Hazard cells cost +2 so the AI (and path preview) prefers avoiding them.
func flood(start: Vector2i, move: int, jump: int, team: int, ignore_units: bool = false) -> Dictionary:
	var result := {start: {"cost": 0, "prev": start}}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		# Pop lowest-cost cell (grids are small; a linear scan is fine).
		var best_i := 0
		for i in range(1, frontier.size()):
			if result[frontier[i]]["cost"] < result[frontier[best_i]]["cost"]:
				best_i = i
		var current: Vector2i = frontier[best_i]
		frontier.remove_at(best_i)
		var cur_cost: int = result[current]["cost"]
		for n in neighbors(current):
			var nc := get_cell(n)
			if nc == null or not nc.walkable:
				continue
			if absi(nc.height - get_height(current)) > jump:
				continue
			if not ignore_units:
				var occ := get_occupant(n)
				if occ != null and occ.get("team") != team:
					continue
			var step := nc.move_cost + (2 if nc.hazard != "" else 0)
			var new_cost := cur_cost + step
			if new_cost > move:
				continue
			if not result.has(n) or new_cost < result[n]["cost"]:
				result[n] = {"cost": new_cost, "prev": current}
				if not frontier.has(n):
					frontier.append(n)
	return result


## Cells a unit can end its move on (unoccupied, reachable).
func reachable_cells(start: Vector2i, move: int, jump: int, team: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var flooded := flood(start, move, jump, team)
	for cell: Vector2i in flooded:
		if cell == start or get_occupant(cell) == null:
			out.append(cell)
	return out


## Path from start to goal (inclusive of both), or [] if unreachable within `move`.
func find_path(start: Vector2i, goal: Vector2i, move: int, jump: int, team: int) -> Array[Vector2i]:
	var flooded := flood(start, move, jump, team)
	return path_from_flood(flooded, start, goal)


static func path_from_flood(flooded: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not flooded.has(goal):
		return path
	var cur := goal
	var guard := 0
	while cur != start and guard < 4096:
		path.push_front(cur)
		cur = flooded[cur]["prev"]
		guard += 1
	path.push_front(start)
	return path


# --- Line of sight & cover -------------------------------------------------

## Supercover line between cell centres, excluding the endpoints.
static func line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	if n == 0:
		return out
	for i in range(1, n):
		var t := float(i) / n
		var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if c != a and c != b and not out.has(c):
			out.append(c)
	return out


## True if nothing between a and b blocks sight. Blocking = a blocks_los cell or
## terrain rising above the sight line (eye height at both ends).
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var ha := get_height(a) + EYE_HEIGHT
	var hb := get_height(b) + EYE_HEIGHT
	var total := float(distance(a, b))
	if total <= 1.0:
		return true
	for c in line_cells(a, b):
		var cell := get_cell(c)
		if cell == null:
			continue
		if cell.blocks_los:
			return false
		var t := float(distance(a, c)) / total
		if float(cell.height) > lerpf(ha, hb, t):
			return false
	return true


## Directional cover the target gets against the attacker (XCOM-style): the
## neighbouring cell on the attacker's side must hold cover or rise above the
## target. Returns COVER_NONE / COVER_HALF / COVER_FULL.
func cover_against(target_cell: Vector2i, attacker_cell: Vector2i) -> int:
	if distance(target_cell, attacker_cell) <= 1:
		return COVER_NONE  # melee range: cover doesn't help
	var best := COVER_NONE
	var d := attacker_cell - target_cell
	var dirs: Array[Vector2i] = []
	if d.x != 0: dirs.append(Vector2i(signi(d.x), 0))
	if d.y != 0: dirs.append(Vector2i(0, signi(d.y)))
	var th := get_height(target_cell)
	for dir in dirs:
		var c := get_cell(target_cell + dir)
		if c == null:
			continue
		var cover := c.cover
		var rise := c.height - th
		if rise >= 2:
			cover = COVER_FULL
		elif rise == 1:
			cover = maxi(cover, COVER_HALF)
		best = maxi(best, cover)
	# Attackers standing well above the target shoot over cover.
	if get_height(attacker_cell) - th >= 3:
		best = maxi(best - 1, COVER_NONE)
	return best


# --- Hazards ---------------------------------------------------------------

func set_hazard(cell: Vector2i, hazard_type: String, turns: int) -> void:
	var c := get_cell(cell)
	if c:
		c.hazard = hazard_type
		c.hazard_turns = turns


func get_hazard(cell: Vector2i) -> String:
	var c := get_cell(cell)
	return c.hazard if c else ""


## Hazards count down in rounds, not seconds (the original used frame delta).
func tick_hazards() -> Array[Vector2i]:
	var cleared: Array[Vector2i] = []
	for cell: Vector2i in _cells:
		var c: Cell = _cells[cell]
		if c.hazard != "":
			c.hazard_turns -= 1
			if c.hazard_turns <= 0:
				c.hazard = ""
				cleared.append(cell)
	return cleared


## Swaps terrain data (not occupants) between two cells — Warp Coordinates.
func swap_cell_data(a: Vector2i, b: Vector2i) -> void:
	var ca := get_cell(a)
	var cb := get_cell(b)
	if ca == null or cb == null:
		return
	for prop in ["height", "terrain", "tile_id", "walkable", "move_cost", "cover", "blocks_los", "hazard", "hazard_turns", "prop_id"]:
		var tmp: Variant = ca.get(prop)
		ca.set(prop, cb.get(prop))
		cb.set(prop, tmp)


# --- Serialization (map files) --------------------------------------------

func to_dict() -> Dictionary:
	var cells := []
	for cell: Vector2i in _cells:
		cells.append(_cells[cell].to_dict())
	return {"width": width, "depth": depth, "tile_width": tile_width, "tile_height": tile_height, "height_step": height_step, "cells": cells}


func load_dict(data: Dictionary, terrain_defs: Dictionary = {}) -> void:
	setup(int(data.get("width", 12)), int(data.get("depth", 12)), str(data.get("default_terrain", "concrete")))
	tile_width = float(data.get("tile_width", tile_width))
	tile_height = float(data.get("tile_height", tile_height))
	height_step = float(data.get("height_step", height_step))
	for entry: Dictionary in data.get("cells", []):
		var coords := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var c := get_cell(coords)
		if c == null:
			continue
		c.height = clampi(int(entry.get("h", 0)), 0, MAX_HEIGHT)
		c.terrain = str(entry.get("t", c.terrain))
		apply_terrain_defaults(c, terrain_defs)
		c.tile_id = str(entry.get("tile", ""))
		if entry.has("walkable"): c.walkable = bool(entry["walkable"])
		if entry.has("cost"): c.move_cost = int(entry["cost"])
		if entry.has("cover"): c.cover = int(entry["cover"])
		if entry.has("blocks_los"): c.blocks_los = bool(entry["blocks_los"])
		c.hazard = str(entry.get("hazard", ""))
		c.hazard_turns = int(entry.get("hazard_turns", 0))
		c.prop_id = str(entry.get("prop", ""))


## Applies a terrain definition's defaults (walkable, cost, cover) to a cell.
static func apply_terrain_defaults(c: Cell, terrain_defs: Dictionary) -> void:
	var def: Dictionary = terrain_defs.get(c.terrain, {})
	c.walkable = bool(def.get("walkable", true))
	c.move_cost = int(def.get("move_cost", 1))
	c.cover = int(def.get("cover", COVER_NONE))
	c.blocks_los = bool(def.get("blocks_los", false))
