extends RefCounted
class_name HexDraw
## Статические утилиты для рисования гексов.
## Генерирует PackedVector2Array вершин; вызывающий рисует через draw_polyline().


static var _cached: Array[PackedVector2Array] = []


## Вершины правильного гекса (pointy-top), радиус r, центр в origin.
static func points(radius: float) -> PackedVector2Array:
	if _cached.size() >= 4 and _cached[3] != null:
		# Кэш для фиксированных радиусов (36, 38, 40) — не нужен, просто генерируем
		pass
	var pts := PackedVector2Array()
	for i in 7:
		var ang := deg_to_rad(60.0 * i - 90.0)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts


## Вершины с заданным центром на экране
static func points_at(center: Vector2, radius: float) -> PackedVector2Array:
	var raw := points(radius)
	var result := PackedVector2Array()
	for p in raw:
		result.append(center + p)
	return result
