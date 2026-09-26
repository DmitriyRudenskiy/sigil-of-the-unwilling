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

enum Terrain { WATER=0, SWAMP=1, SAND=2, GRASS=3, FOREST=4, MOUNTAIN=5, SNOW=6, RIVER=7, ROAD=8, DENSE_FOREST=9 }
const TERRAIN_NAMES := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow", "river", "road", "dense_forest"]

## Единый источник истины ориентации сетки — autoload HexGrid.shift_right
## (калибруется по TileMapLayer в HexGrid.calibrate). Статические методы ниже
## читают его по умолчанию; явный аргумент shift_right оставлен только как
## override для контекстов со своим состоянием (BattleState.hex_shift_right,
## MapGenerator.hex_shift_right) и для unit-тестов.
## Примечание: значения по умолчанию аргументов вычисляются один раз при
## загрузке скрипта, поэтому вызывается resolve_shift_right(null) с отложенным
## чтением состояния в момент фактического вызова без явного override.
static func default_shift_right() -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var hg: Node = (loop as SceneTree).root.get_node_or_null(^"HexGrid")
		if hg != null and "shift_right" in hg:
			return bool(hg.shift_right)
	return true

## Нормализация необязательного override: null -> текущее значение HexGrid.
static func resolve_shift_right(override: Variant) -> bool:
	if override == null:
		return default_shift_right()
	return bool(override)

static func get_neighbor(cell: Vector2i, bit: int, shift_right: Variant = null) -> Vector2i:
	shift_right = resolve_shift_right(shift_right)
	var odd := (cell.y & 1) == 1
	if shift_right:
		return cell + (T_ODD_RIGHT[bit] if odd else T_EVEN_RIGHT[bit])
	else:
		return cell + (T_EVEN_RIGHT[bit] if odd else T_ODD_RIGHT[bit])

static func get_all_neighbors(cell: Vector2i, shift_right: Variant = null) -> Array[Vector2i]:
	var sr := resolve_shift_right(shift_right)
	var r: Array[Vector2i] = []
	r.resize(6)
	for i in 6:
		r[i] = get_neighbor(cell, i, sr)
	return r

static func offset_to_cube(cell: Vector2i, shift_right: Variant = null) -> Vector3i:
	var sr := resolve_shift_right(shift_right)
	var r := cell.y
	var x: int
	if sr:
		x = cell.x - ((r - (r & 1)) >> 1)
	else:
		x = cell.x - ((r + (r & 1)) >> 1)
	var z := r
	return Vector3i(x, -x - z, z)

static func cube_to_offset(c: Vector3i, shift_right: Variant = null) -> Vector2i:
	var sr := resolve_shift_right(shift_right)
	var r := c.z
	var x: int
	if sr:
		x = c.x + ((r - (r & 1)) >> 1)
	else:
		x = c.x + ((r + (r & 1)) >> 1)
	return Vector2i(x, r)

static func hex_distance(a: Vector2i, b: Vector2i, shift_right: Variant = null) -> int:
	var sr := resolve_shift_right(shift_right)
	var ac := offset_to_cube(a, sr)
	var bc := offset_to_cube(b, sr)
	return max(max(absi(ac.x - bc.x), absi(ac.y - bc.y)), absi(ac.z - bc.z))

static func ring(center: Vector2i, r: int, shift_right: Variant = null) -> Array[Vector2i]:
	if r <= 0:
		return [center]

	var sr := resolve_shift_right(shift_right)
	var out: Array[Vector2i] = []

	var dirs := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	var cube := offset_to_cube(center, sr)
	var cur := cube + Vector3i(dirs[4].x, -dirs[4].x - dirs[4].y, dirs[4].y) * r
	for i in 6:
		for _j in r:
			out.append(cube_to_offset(cur, sr))
			cur += Vector3i(dirs[i].x, -dirs[i].x - dirs[i].y, dirs[i].y)
	return out

static func pos_to_idx(cell: Vector2i, w: int) -> int:
	return cell.y * w + cell.x

static func idx_to_pos(idx: int, w: int) -> Vector2i:
	# Целочисленное деление: float-путь (int(idx / float(w))) — лишняя операция
	# на горячем маршруте восстановления пути из came_from в HexPathfinding.
	return Vector2i(idx % w, idx / w)
