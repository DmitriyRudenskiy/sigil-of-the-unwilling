class_name LogisticsCalculator
extends RefCounted
## M3: Логистика города. Множитель эффективности здания:
##  - базовое затухание по дистанции до «тела города» (центр/районы):
##    первая клетка рядом — полный 1.0, дальше минус FALLOFF за клетку;
##  - дорога (на клетке здания или в соседней) даёт бонус — логистика
##    может превышать базовую 1.0 (максимум ROAD_MAX).
##
## Чистая статическая логика: город задаётся параметром, автолоадов нет —
## тестится headless. Зовётся из City.get_logistics_multiplier().

const DIST_FALLOFF := 0.15  # за клетку начиная со 2-го кольца
const MIN_MULT := 0.25
const MAX_MULT := 1.0
const ROAD_BONUS := 0.15
const ROAD_MAX := 1.5


## Множитель логистики для клетки (здания).
static func compute(city: City, cell: Vector2i) -> float:
	var base: float = distance_multiplier(city, cell)
	if has_road_near(city, cell):
		return minf(base + ROAD_BONUS, ROAD_MAX)
	return base


## Базовое затухание по дистанции до ближайшей части тела города.
static func distance_multiplier(city: City, cell: Vector2i) -> float:
	var d: int = distance_to_body(city, cell)
	var falloff: float = float(maxi(0, d - 1)) * DIST_FALLOFF
	return clampf(1.0 - falloff, MIN_MULT, MAX_MULT)


## Минимальная гекс-дистанция до центра или любого района.
static func distance_to_body(city: City, cell: Vector2i) -> int:
	var best: int = HexUtils.hex_distance(cell, city.center)
	for b in city.boroughs:
		best = mini(best, HexUtils.hex_distance(cell, b.cell))
	return best


## Дорога на самой клетке или в одной из соседних.
static func has_road_near(city: City, cell: Vector2i) -> bool:
	if city.has_road(cell):
		return true
	for nb in HexUtils.get_all_neighbors(cell):
		if city.has_road(nb):
			return true
	return false
