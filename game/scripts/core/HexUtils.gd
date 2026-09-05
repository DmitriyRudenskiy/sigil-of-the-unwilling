extends RefCounted
class_name HexUtils
## Гекс-утилиты с АВТОКАЛИБРОВКОЙ чётности строк под реальный layout TileMapLayer.
## Порядок doc-битов: [E, NE, NW, W, SW, SE] = 0..5

# Таблицы соседей (Red Blob Games), odd-r и even-r
const T_ODD_RIGHT := [  # нечётная строка смещена ВПРАВО
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]
const T_EVEN_RIGHT := [  # чётная строка (при odd-r)
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

# Калибруется по реальному TileMapLayer (см. calibrate)
static var _config: HexGridConfig = null

static func get_config() -> HexGridConfig:
	if _config == null:
		_config = HexGridConfig.new()
	return _config

enum Terrain { WATER=0, SWAMP=1, SAND=2, GRASS=3, FOREST=4, MOUNTAIN=5, SNOW=6 }
const TERRAIN_NAMES := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]


static func calibrate(tm: TileMapLayer) -> void:
	## Определяет, в какую сторону смещены НЕЧЁТНЫЕ строки в реальном рендере
	if tm == null or tm.tile_set == null:
		return
	var a := tm.map_to_local(Vector2i(0, 0))
	var b := tm.map_to_local(Vector2i(0, 1))
	get_config().odd_row_shift_right = b.x > a.x
	GameLogger.trace("calibrated: odd_row_shift_right = %s" % str(get_config().odd_row_shift_right), "HexUtils")


static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
	var odd := (cell.y & 1) == 1
	var table: Array
	if get_config().odd_row_shift_right:
		table = T_ODD_RIGHT if odd else T_EVEN_RIGHT
	else:
		table = T_EVEN_RIGHT if odd else T_ODD_RIGHT
	return cell + table[bit]


static func get_all_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for i in 6:
		r.append(get_neighbor(cell, i))
	return r


@warning_ignore("integer_division")
static func offset_to_cube(cell: Vector2i) -> Vector3i:
	var r := cell.y
	var x: int
	if get_config().odd_row_shift_right:
		x = cell.x - (r - (r & 1)) / 2
	else:
		x = cell.x - (r + (r & 1)) / 2
	var z := r
	return Vector3i(x, -x - z, z)


@warning_ignore("integer_division")
static func cube_to_offset(c: Vector3i) -> Vector2i:
	var r := c.z
	var x: int
	if get_config().odd_row_shift_right:
		x = c.x + (r - (r & 1)) / 2
	else:
		x = c.x + (r + (r & 1)) / 2
	return Vector2i(x, r)


static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := offset_to_cube(a)
	var bc := offset_to_cube(b)
	return max(max(absi(ac.x - bc.x), absi(ac.y - bc.y)), absi(ac.z - bc.z))


## city-in-world: детерминированное кольцо клеток на расстоянии r от центра
## (r <= 0 → [center]). Порядок обхода: строки сверху вниз, внутри строки
## слева направо. Для автоматической расстановки зданий (CityScreen).
static func ring(center: Vector2i, r: int) -> Array[Vector2i]:
	if r <= 0:
		return [center]
	var out: Array[Vector2i] = []
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var c := Vector2i(x, y)
			if hex_distance(center, c) == r:
				out.append(c)
	return out


static func pos_to_idx(cell: Vector2i, w: int) -> int:
	return cell.y * w + cell.x


static func idx_to_pos(idx: int, w: int) -> Vector2i:
	return Vector2i(idx % w, idx / w)
