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

# R3 ACCEPTED: static var остаётся. Сброс через HexUtils.reset()
# на границе сессии (вызывается в Services.clear_session()).
# Полная миграция на инстанс-передачу
# HexGridConfig нецелесообразна: ~200 вызовов в горячих циклах A*/BFS,
# нулевой выигрыш, высокий риск регрессии.
static var _config: HexGridConfig = null

# hot-path (get_neighbor is called in A*/BFS). Cache the calibration
# flag in a static bool so the hot methods avoid the get_config() method call and
# property access. Recomputed only in calibrate(). Upgrade path: if HexGridConfig
# gains more per-tile-set fields that these methods need, fold them back here.
static var _shift_right: bool = true

static func get_config() -> HexGridConfig:
	if _config == null:
		_config = HexGridConfig.new()
	return _config

enum Terrain { WATER=0, SWAMP=1, SAND=2, GRASS=3, FOREST=4, MOUNTAIN=5, SNOW=6 }
const TERRAIN_NAMES := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]


static func calibrate(tm: TileMapLayer) -> void:
	if tm == null or tm.tile_set == null:
		return
	var a := tm.map_to_local(Vector2i(0, 0))
	var b := tm.map_to_local(Vector2i(0, 1))
	get_config().odd_row_shift_right = b.x > a.x
	_shift_right = get_config().odd_row_shift_right
	GameLogger.trace("calibrated: odd_row_shift_right = %s" % str(_shift_right), "HexUtils")


## R3: сброс статического состояния на границе сессии.
## Дефолты (_shift_right=true) совпадают с HexGridConfig; следующая calibrate()
## в MapGenerator/BattleView пересчитает флаг по фактическому тайл-сету.
static func reset() -> void:
	_config = null
	_shift_right = true


static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
	var odd := (cell.y & 1) == 1
	if _shift_right:
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
	if _shift_right:
		x = cell.x - int((r - (r & 1)) / 2)
	else:
		x = cell.x - int((r + (r & 1)) / 2)
	var z := r
	return Vector3i(x, -x - z, z)


static func cube_to_offset(c: Vector3i) -> Vector2i:
	var r := c.z
	var x: int
	if _shift_right:
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
	# TASK_06: обход кольца за O(r), а не O(r^2).
	# Идём по 6 кубическим направлениям от стартового угла кольца;
	# cube-координаты полностью не зависят от калибровки offset-сетки,
	# поэтому результат идентичен старому реализации.
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
