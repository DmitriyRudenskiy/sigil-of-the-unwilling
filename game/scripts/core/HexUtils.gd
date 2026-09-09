extends RefCounted
class_name HexUtils

const T_ODD_RIGHT := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]
const T_EVEN_RIGHT := [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

enum Terrain { WATER=0, SWAMP=1, SAND=2, GRASS=3, FOREST=4, MOUNTAIN=5, SNOW=6 }
const TERRAIN_NAMES := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]

static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
	var odd := (cell.y & 1) == 1
	if HexGrid.shift_right:
		return cell + (T_ODD_RIGHT[bit] if odd else T_EVEN_RIGHT[bit])
	else:
		return cell + (T_EVEN_RIGHT[bit] if odd else T_ODD_RIGHT[bit])

static func get_all_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	r.resize(6)
	for i in 6:
		r[i] = get_neighbor(cell, i)
	return r

static func offset_to_cube(cell: Vector2i) -> Vector3i:
	var r := cell.y
	var x: int
	if HexGrid.shift_right:
		x = cell.x - int((r - (r & 1)) / 2)
	else:
		x = cell.x - int((r + (r & 1)) / 2)
	var z := r
	return Vector3i(x, -x - z, z)

static func cube_to_offset(c: Vector3i) -> Vector2i:
	var r := c.z
	var x: int
	if HexGrid.shift_right:
		x = c.x + int((r - (r & 1)) / 2)
	else:
		x = c.x + int((r + (r & 1)) / 2)
	return Vector2i(x, r)

static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := offset_to_cube(a)
	var bc := offset_to_cube(b)
	return max(max(absi(ac.x - bc.x), absi(ac.y - bc.y)), absi(ac.z - bc.z))

static func ring(center: Vector2i, r: int) -> Array[Vector2i]:
	if r <= 0:
		return [center]

	var out: Array[Vector2i] = []

	var dirs := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	var cube := offset_to_cube(center)
	var cur := cube + Vector3i(dirs[4].x, -dirs[4].x - dirs[4].y, dirs[4].y) * r
	for i in 6:
		for _j in r:
			out.append(cube_to_offset(cur))
			cur += Vector3i(dirs[i].x, -dirs[i].x - dirs[i].y, dirs[i].y)
	return out

static func pos_to_idx(cell: Vector2i, w: int) -> int:
	return cell.y * w + cell.x

static func idx_to_pos(idx: int, w: int) -> Vector2i:
	return Vector2i(idx % w, idx / w)
