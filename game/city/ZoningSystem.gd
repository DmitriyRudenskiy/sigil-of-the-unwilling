class_name ZoningSystem
extends RefCounted
## M3: Зонирование города. Правила размещения зон и множитель зоны
## для здания (агломерация, «рынок рядом с домами», «завод у дороги»).
##
## Зону здания задаёт UniqueBuilding.zone_type (UI-слой при постройке
## спрашивает can_place()). Сами зоны дохода в легасийный контур не
## вмешиваются — эффект только через zone_multiplier в цепочках (M1).

enum ZoneType {
	NONE = 0,        # не участвует в зонировании
	RESIDENTIAL = 1, # жилые кварталы
	COMMERCIAL = 2,  # торговля, рынок
	INDUSTRIAL = 3,  # производство, мастерские
	SPECIAL = 4,     # только на спец. площадках
}

const INDUSTRIAL_MIN_DISTANCE := 2   # от центра города
const AGGLOMERATION_COUNT := 2       # соседей той же зоны для бонуса
const AGGLOMERATION_BONUS := 0.10
const COMMERCIAL_MARKET_BONUS := 0.10  # коммерция рядом с жильём
const INDUSTRIAL_ROAD_BONUS := 0.10    # производство рядом с дорогой
const MAX_ZONE_MULT := 1.5


## Можно ли разместить зону на клетке. Возвращает {ok: bool, reason: String}.
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
			if HexUtils.hex_distance(cell, city.center) < INDUSTRIAL_MIN_DISTANCE:
				return _fail("Производство — не ближе %d клеток от центра" % INDUSTRIAL_MIN_DISTANCE)
			return _ok()
		ZoneType.SPECIAL:
			if not city.special_sites.has(cell):
				return _fail("Требуется специальная площадка")
			return _ok()
		_:
			return _fail("Неизвестный тип зоны")


## Множитель зоны для здания на клетке (1.0 = без бонусов).
static func zone_multiplier(city: City, cell: Vector2i, zone: int) -> float:
	if zone == ZoneType.NONE:
		return 1.0
	var mult := 1.0
	if adjacent_same_zone_count(city, cell, zone) >= AGGLOMERATION_COUNT:
		mult += AGGLOMERATION_BONUS
	if zone == ZoneType.COMMERCIAL and adjacent_zone_count(city, cell, ZoneType.RESIDENTIAL) > 0:
		mult += COMMERCIAL_MARKET_BONUS
	if zone == ZoneType.INDUSTRIAL and LogisticsCalculator.has_road_near(city, cell):
		mult += INDUSTRIAL_ROAD_BONUS
	return minf(mult, MAX_ZONE_MULT)


## Сколько соседних зданий той же зоны вокруг клетки (без самой клетки).
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
