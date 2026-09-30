extends RefCounted
class_name HexDraw

# TASK_21: кэш базового полигона — overlay перерисовывает видимые гексы при панировании,
# раньше каждый вызов аллоцировал PackedVector2Array. Геометрия (7 точек, замкнутый
# polyline) сохранена; вызывающие стороны не мутируют возвращённый массив.
static var _points_cache: Dictionary = {}

static func points(radius: float) -> PackedVector2Array:
	if _points_cache.has(radius):
		return _points_cache[radius]
	var pts := PackedVector2Array()
	for i in 7:
		var ang := deg_to_rad(60.0 * i - 90.0)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	_points_cache[radius] = pts
	return pts

static func reset_cache() -> void:
	_points_cache.clear()

static func points_at(center: Vector2, radius: float) -> PackedVector2Array:
	var raw := points(radius)
	var result := PackedVector2Array()
	for p in raw:
		result.append(center + p)
	return result
