class_name HexAutotiler
extends RefCounted

const N := 1
const E := 2
const S := 4
const W := 8

const _SIDE_ORDER := ["N", "E", "S", "W"]
const _SIDE_BITS := { "N": N, "E": E, "S": S, "W": W }

var atlas: TileAtlas


func _init(atlas_: TileAtlas) -> void:
	atlas = atlas_


static func make_grid(w: int, h: int, base: int, blobs: Array, rng: RandomNumberGenerator) -> Dictionary:
	var grid := {}
	for y in h:
		for x in w:
			grid[Vector2i(x, y)] = base
	for b in blobs:
		var c: Vector2i = b["c"]
		var r: int = b["r"]
		var t: int = b["t"]
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var d := Vector2i(x, y).distance_to(c)
				if d <= r or (d <= r + 1.0 and rng.randf() < 0.45):
					if x >= 0 and y >= 0 and x < w and y < h:
						grid[Vector2i(x, y)] = t
	return grid


func apply(layer: TileMapLayer, grid: Dictionary, origin: Vector2i = Vector2i.ZERO,
		rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
	layer.clear()
	for cell in grid:
		var c: Vector2i = cell
		var me: int = grid[c]
		var choice := _choose(me, grid, c, rng)
		layer.set_cell(origin + c, TileAtlas.SOURCE_ID, choice["atlas"], choice["alt"])


func choose_tile(me: int, grid: Dictionary, c: Vector2i,
		rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
	return _choose(me, grid, c, rng)


func choose(biome: int, grid: Dictionary, c: Vector2i,
		rng: RandomNumberGenerator = null) -> Dictionary:
	return choose_tile(biome, grid, c, rng)


func _choose(me: int, grid: Dictionary, c: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var m := _mask(me, grid, c)
	if m == 0:
		return _base(me, rng)
	if me == TileAtlas.Biome.ROAD:
		return _road_tile(me, grid, c)
	if m == (N | E | S | W):
		return _base(me, rng)
	var other := _other_biom(me, grid, c)
	if other == TileAtlas.Biome.ROAD:
		return _road_tile(me, grid, c)
	var n := _popcount(m)
	if n == 1:
		return _choose_one(me, other, grid, c, m, rng)
	elif n == 2:
		return _choose_two(me, other, m, rng)
	elif n == 3:
		return _choose_three(me, other, grid, c, rng)
	return _base(me, rng)


func _base(biome: int, rng: RandomNumberGenerator) -> Dictionary:
	return { "atlas": atlas.base_coords(biome, rng), "alt": 0 }


func _mask(me: int, grid: Dictionary, c: Vector2i) -> int:
	var m := 0
	for side in _SIDE_ORDER:
		var p := c + _delta(side)
		if grid.has(p) and grid[p] != me:
			m |= _SIDE_BITS[side]
	return m


func _other_biom(me: int, grid: Dictionary, c: Vector2i) -> int:
	for side in _SIDE_ORDER:
		var p := c + _delta(side)
		if grid.has(p) and grid[p] != me:
			return grid[p]
	return me


func _choose_one(me: int, other: int, grid: Dictionary, c: Vector2i, m: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var side := _side_of_bit(m)
	var p := atlas.pick(me, other, "edge", side)
	if p.is_empty():
		var corner := _diag_corner_of_other(me, grid, c, side)
		p = atlas.pick(me, other, "diag", corner)
	if not p.is_empty():
		return p
	return _base(me, rng)


func _choose_two(me: int, other: int, m: int, rng: RandomNumberGenerator) -> Dictionary:
	var sides := _sides_of_mask(m)
	if sides.size() == 2 and _adjacent(sides[0], sides[1]):
		var corner := _corner_between(sides[0], sides[1])
		var p := atlas.pick(me, other, "diag", corner)
		if not p.is_empty():
			return p
	return _base(me, rng)


func _choose_three(me: int, other: int, grid: Dictionary, c: Vector2i,
		rng: RandomNumberGenerator) -> Dictionary:
	var me_side := _side_of(me, grid, c)
	var u := _diag_corner_of_me(me, grid, c, me_side)
	var p := atlas.pick(me, other, "diag", atlas.opposite("diag", u))
	if not p.is_empty():
		return p
	return _base(me, rng)


func _adjacent(a: String, b: String) -> bool:
	var ia := _SIDE_ORDER.find(a)
	var ib := _SIDE_ORDER.find(b)
	var d := (ia - ib + 4) % 4
	return d == 1 or d == 3


func _corner_between(a: String, b: String) -> String:
	match a + b:
		"NE", "EN": return "NE"
		"ES", "SE": return "SE"
		"SW", "WS": return "SW"
		"NW", "WN": return "NW"
	return "NE"


func _diag_corners_of_side(side: String) -> Array:
	match side:
		"N": return ["NW", "NE"]
		"E": return ["NE", "SE"]
		"S": return ["SE", "SW"]
		"W": return ["NW", "SW"]
	return ["NW", "NE"]


func _diag_corner_of_other(me: int, grid: Dictionary, c: Vector2i, side: String) -> String:
	for cn in _diag_corners_of_side(side):
		var p := c + _delta(cn)
		if grid.has(p) and grid[p] != me:
			return cn
	return _diag_corners_of_side(side)[0]


func _diag_corner_of_me(me: int, grid: Dictionary, c: Vector2i, side: String) -> String:
	for cn in _diag_corners_of_side(side):
		var p := c + _delta(cn)
		if grid.has(p) and grid[p] == me:
			return cn
	return _diag_corners_of_side(side)[0]


func _side_of(me: int, grid: Dictionary, c: Vector2i) -> String:
	for side in ["S", "E", "W", "N"]:
		var p := c + _delta(side)
		if grid.has(p) and grid[p] == me:
			return side
	return "N"


func _road_tile(me: int, grid: Dictionary, c: Vector2i) -> Dictionary:
	var alt := 0
	if me == TileAtlas.Biome.ROAD:
		alt = _road_own_alt(grid, c)
	else:
		alt = _road_neighbor_alt(grid, c)
	return { "atlas": Vector2i(3, 1), "alt": alt }


func _road_own_alt(grid: Dictionary, c: Vector2i) -> int:
	var road := TileAtlas.Biome.ROAD
	var nw := _biom_at(grid, c + Vector2i(-1, -1))
	var ne := _biom_at(grid, c + Vector2i(1, -1))
	var se := _biom_at(grid, c + Vector2i(1, 1))
	var sw := _biom_at(grid, c + Vector2i(-1, 1))
	if nw == road or se == road:
		return 0
	if ne == road or sw == road:
		return 1
	return 0


func _road_neighbor_alt(grid: Dictionary, c: Vector2i) -> int:
	var road := TileAtlas.Biome.ROAD
	var nw := _biom_at(grid, c + Vector2i(-1, -1))
	var ne := _biom_at(grid, c + Vector2i(1, -1))
	var se := _biom_at(grid, c + Vector2i(1, 1))
	var sw := _biom_at(grid, c + Vector2i(-1, 1))
	if nw == road or se == road:
		return 0
	if ne == road or sw == road:
		return 1
	for side in _SIDE_ORDER:
		var p := c + _delta(side)
		if grid.has(p) and grid[p] == road:
			return 1 if side == "E" or side == "W" else 0
	return 0


func _biom_at(grid: Dictionary, c: Vector2i) -> int:
	return grid[c] if grid.has(c) else -1


func _side_of_bit(m: int) -> String:
	if m == N:
		return "N"
	if m == E:
		return "E"
	if m == S:
		return "S"
	return "W"


func _sides_of_mask(m: int) -> Array:
	var out := []
	for side in _SIDE_ORDER:
		if (m & _SIDE_BITS[side]) != 0:
			out.append(side)
	return out


func _popcount(m: int) -> int:
	var n := 0
	var x := m
	while x > 0:
		n += x & 1
		x >>= 1
	return n


func _delta(d: String) -> Vector2i:
	match d:
		"N": return Vector2i(0, -1)
		"E": return Vector2i(1, 0)
		"S": return Vector2i(0, 1)
		"W": return Vector2i(-1, 0)
		"NW": return Vector2i(-1, -1)
		"NE": return Vector2i(1, -1)
		"SE": return Vector2i(1, 1)
		"SW": return Vector2i(-1, 1)
	return Vector2i.ZERO
