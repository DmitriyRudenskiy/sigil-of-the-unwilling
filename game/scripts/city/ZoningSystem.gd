class_name ZoningSystem
extends RefCounted

enum ZoneType {
	NONE = 0,        
	RESIDENTIAL = 1, 
	COMMERCIAL = 2,  
	INDUSTRIAL = 3,  
	SPECIAL = 4,     
}



static func can_place(city: City, cell: Vector2i, zone: int) -> Dictionary:
	match zone:
		ZoneType.NONE:
			return _ok()
		ZoneType.RESIDENTIAL, ZoneType.COMMERCIAL:
			if cell == city.center:
				return _fail("Центр города недоступен для застройки")
			return _ok()
		ZoneType.INDUSTRIAL:
			if cell == city.center:
				return _fail("Центр города недоступен для застройки")
			if HexUtils.hex_distance(cell, city.center) < GameNumbers.ZONE_INDUSTRIAL_MIN_DIST:
				return _fail("Производство — не ближе %d клеток от центра" % GameNumbers.ZONE_INDUSTRIAL_MIN_DIST)
			return _ok()
		ZoneType.SPECIAL:
			if not city.special_sites.has(cell):
				return _fail("Требуется специальная площадка")
			return _ok()
		_:
			return _fail("Неизвестный тип зоны")


static func zone_multiplier(city: City, cell: Vector2i, zone: int) -> float:
	if zone == ZoneType.NONE:
		return 1.0
	var mult := 1.0
	if adjacent_same_zone_count(city, cell, zone) >= GameNumbers.ZONE_AGGLOMERATION_COUNT:
		mult += GameNumbers.ZONE_AGGLOMERATION_BONUS
	if zone == ZoneType.COMMERCIAL and adjacent_zone_count(city, cell, ZoneType.RESIDENTIAL) > 0:
		mult += GameNumbers.ZONE_COMMERCIAL_MARKET
	if zone == ZoneType.INDUSTRIAL and LogisticsCalculator.has_road_near(city, cell):
		mult += GameNumbers.ZONE_INDUSTRIAL_ROAD
	return minf(mult, GameNumbers.ZONE_MAX_MULT)


static func adjacent_same_zone_count(city: City, cell: Vector2i, zone: int) -> int:
	return adjacent_zone_count(city, cell, zone)


static func adjacent_zone_count(city: City, cell: Vector2i, zone: int) -> int:
	var n := 0
	for nb in HexUtils.get_all_neighbors(cell):
		var b: UniqueBuilding = city.get_building_at(nb)
		if b != null and b.zone_type == zone:
			n += 1
	return n


static func _ok() -> Dictionary:
	return {"ok": true, "reason": ""}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
