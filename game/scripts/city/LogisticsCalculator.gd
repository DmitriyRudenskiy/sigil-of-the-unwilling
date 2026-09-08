class_name LogisticsCalculator
extends RefCounted



static func compute(city: City, cell: Vector2i) -> float:
	var base: float = distance_multiplier(city, cell)
	if has_road_near(city, cell):
		return minf(base + GameNumbers.LOGISTICS_ROAD_BONUS, GameNumbers.LOGISTICS_ROAD_MAX)
	return base


static func distance_multiplier(city: City, cell: Vector2i) -> float:
	var d: int = distance_to_body(city, cell)
	var falloff: float = float(maxi(0, d - 1)) * GameNumbers.LOGISTICS_DIST_FALLOFF
	return clampf(1.0 - falloff, GameNumbers.LOGISTICS_MIN_MULT, GameNumbers.LOGISTICS_MAX_MULT)


static func distance_to_body(city: City, cell: Vector2i) -> int:
	var best: int = HexUtils.hex_distance(cell, city.center)
	for b in city.boroughs:
		best = mini(best, HexUtils.hex_distance(cell, b.cell))
	return best


static func has_road_near(city: City, cell: Vector2i) -> bool:
	if city.has_road(cell):
		return true
	for nb in HexUtils.get_all_neighbors(cell):
		if city.has_road(nb):
			return true
	return false
