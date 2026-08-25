extends RefCounted
class_name HexUtils
## Pointy-top, odd-r offset. Doc bits [E,NE,NW,W,SW,SE] = bits [0,1,2,3,4,5]

const DIR_EVEN_ROW := [
	Vector2i(1, 0),   # E
	Vector2i(1, -1),  # NE
	Vector2i(0, -1),  # NW
	Vector2i(-1, 0),  # W
	Vector2i(0, 1),   # SW
	Vector2i(1, 1),   # SE
]
const DIR_ODD_ROW := [
	Vector2i(1, 0),   # E
	Vector2i(0, -1),  # NE
	Vector2i(-1, -1), # NW
	Vector2i(-1, 0),  # W
	Vector2i(-1, 1),  # SW
	Vector2i(0, 1),   # SE
]

enum Terrain { WATER=0, SAND=1, GRASS=2, FOREST=3, MOUNTAIN=4, SNOW=5 }
const TERRAIN_NAMES := ["water","sand","grass","forest","mountain","snow"]

static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
	if cell.y % 2 == 0:
		return cell + DIR_EVEN_ROW[bit]
	return cell + DIR_ODD_ROW[bit]

static func get_all_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for i in 6:
		r.append(get_neighbor(cell, i))
	return r

@warning_ignore("integer_division")
static func offset_to_cube(cell: Vector2i) -> Vector3i:
	var x := cell.x - (cell.y - (cell.y & 1)) / 2
	var z := cell.y
	return Vector3i(x, -x - z, z)

@warning_ignore("integer_division")
static func cube_to_offset(c: Vector3i) -> Vector2i:
	return Vector2i(c.x + (c.z - (c.z & 1)) / 2, c.z)

static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := offset_to_cube(a)
	var bc := offset_to_cube(b)
	return maxi(maxi(absi(ac.x - bc.x), absi(ac.y - bc.y)), absi(ac.z - bc.z))

static func compute_terrain_mask(grid: Dictionary, cell: Vector2i, tid: int, w: int, h: int) -> int:
	var mask := 0
	for bit in 6:
		var n := get_neighbor(cell, bit)
		if n.x < 0 or n.x >= w or n.y < 0 or n.y >= h:
			continue
		if grid.has(n) and grid[n] > tid:
			mask |= (1 << bit)
	return mask

static func bfs_path(start: Vector2i, goal: Vector2i, blocked: Dictionary, w: int, h: int) -> Array[Vector2i]:
	if start == goal:
		return [start]
	var queue: Array[Vector2i] = [start]
	var from: Dictionary = {start: start}
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()   # <-- FIX: явный тип вместо :=
		if cur == goal:
			break
		for bit in 6:
			var nxt := get_neighbor(cur, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt) or from.has(nxt):
				continue
			from[nxt] = cur
			queue.append(nxt)
	if not from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var c := goal
	while c != start:
		path.append(c)
		c = from[c]
	path.append(start)
	path.reverse()
	return path

static func bfs_reachable(start: Vector2i, steps: int, blocked: Dictionary, w: int, h: int) -> Dictionary:
	var result := {start: 0}
	var queue: Array[Vector2i] = [start]
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()   # <-- FIX: явный тип вместо :=
		var dist: int = result[cur]
		if dist >= steps:
			continue
		for bit in 6:
			var nxt := get_neighbor(cur, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt) or result.has(nxt):
				continue
			result[nxt] = dist + 1
			queue.append(nxt)
	result.erase(start)
	return result
