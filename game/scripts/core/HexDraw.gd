extends RefCounted
class_name HexDraw


static func points(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var ang := deg_to_rad(60.0 * i - 90.0)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts


static func points_at(center: Vector2, radius: float) -> PackedVector2Array:
	var raw := points(radius)
	var result := PackedVector2Array()
	for p in raw:
		result.append(center + p)
	return result
