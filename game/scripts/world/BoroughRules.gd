class_name BoroughRules
extends RefCounted
## Чистые правила районов: стоимость, лимиты по фракции, повышение уровней.


static func pop_ratio(faction: int) -> float:
	match faction:
		City.Faction.NECROPHAGE, City.Faction.ALLAYI:
			return CityBalance.BOROUGH_POP_RATIO_WIDE
		_:
			return CityBalance.BOROUGH_POP_RATIO_DEFAULT


static func max_boroughs(city: City) -> int:
	## 1 район на POP_RATIO населения (допущение №5: вся численность).
	return int(floor(float(city.pop_total()) / pop_ratio(city.faction)))


static func cost(city: City) -> float:
	return CityBalance.BOROUGH_BASE_COST \
		+ CityBalance.BOROUGH_COST_STEP * city.boroughs.size()


static func same_level_neighbors(city: City, b: Borough) -> int:
	var n := 0
	for nb in HexUtils.get_all_neighbors(b.cell):
		for other in city.boroughs:
			if other.cell == nb and other.level == b.level:
				n += 1
				break
	return n


static func can_level_up(city: City, b: Borough) -> bool:
	if b.level >= CityBalance.BOROUGH_MAX_LEVEL:
		return false
	# Уровень 3 доступен только Культистам (по ТЗ 4.1).
	if b.level == 2 and city.faction != City.Faction.CULTISTS:
		return false
	return same_level_neighbors(city, b) >= CityBalance.BOROUGH_LEVELUP_NEIGHBORS


static func process_level_ups(city: City) -> int:
	## Повышает уровни районов (каскадом). Возвращает число повышений.
	var total := 0
	for _pass in CityBalance.BOROUGH_MAX_LEVEL:
		var raised := 0
		for b in city.boroughs:
			if can_level_up(city, b):
				b.level += 1
				raised += 1
		total += raised
		if raised == 0:
			break
	return total
