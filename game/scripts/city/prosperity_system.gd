class_name ProsperitySystem
extends RefCounted

static func recalculate(city: City) -> float:
	var v := GameNumbers.PROSPERITY_BASE
	if city.net_food() >= 0.0:
		v += GameNumbers.PROSPERITY_FOOD_BONUS
	else:
		v -= GameNumbers.PROSPERITY_FOOD_BONUS
	if float(city.storage.get(&"industry", 0.0)) >= GameNumbers.PROSPERITY_GOLD_REQ:
		v += GameNumbers.PROSPERITY_GOLD_BONUS
	var bld: float = 0.0
	for building in city.buildings:
		if building != null:
			bld += GameNumbers.PROSPERITY_BLD_PER
	v += minf(bld, GameNumbers.PROSPERITY_BLD_CAP)
	var cap := city.pop_cap()
	if cap > 0 and float(city.pop_capped()) / float(cap) >= GameNumbers.PROSPERITY_POP_RATIO:
		v += GameNumbers.PROSPERITY_POP_BONUS
	v += float(city.reputation) / 10.0
	v = clampf(v, GameNumbers.PROSPERITY_MIN, GameNumbers.PROSPERITY_MAX)
	city.prosperity = v
	return v

static func gold_bonus(city: City) -> float:
	return city.prosperity * GameNumbers.PROSPERITY_GOLD_PER_PT

static func reputation_mod(city: City) -> int:
	if city.prosperity >= GameNumbers.PROSPERITY_REP_HIGH:
		return 1
	if city.prosperity <= GameNumbers.PROSPERITY_REP_LOW:
		return -1
	return 0

static func level_pop_req(level: int) -> int:
	return GameNumbers.PROSPERITY_LEVEL_POP_BASE + GameNumbers.PROSPERITY_LEVEL_POP_STEP * (level - 1)

## Ранняя игра: порог процветания для перехода на следующий уровень (early-game-foundation)
static func level_up_req(level: int) -> float:
	var idx := clampi(level - 2, 0, GameNumbers.PROSPERITY_LEVEL_REQS.size() - 1)
	return GameNumbers.PROSPERITY_LEVEL_REQS[idx]

static func level_buildings_req(level: int) -> int:
	return GameNumbers.PROSPERITY_LEVEL_BLD_PER * level

static func build_radius_for_level(level: int) -> int:
	var l := clampi(level, GameNumbers.CITY_LEVEL_MIN, GameNumbers.CITY_LEVEL_MAX)
	return mini(GameNumbers.BUILDING_MAX_DIST_BASE + (l - 1), GameNumbers.PROSPERITY_MAX_RADIUS)

static func can_level_up(city: City) -> Dictionary:
	var reasons: Array[String] = []
	if city.level >= GameNumbers.CITY_LEVEL_MAX:
		return {"ok": false, "reasons": ["Максимальный уровень"]}
	var req: float = level_up_req(city.level)
	if city.prosperity < req:
		reasons.append("Процветание: %.0f/%.0f" % [city.prosperity, req])
	if city.pop_capped() < level_pop_req(city.level):
		reasons.append("Население: %d/%d" % [city.pop_capped(), level_pop_req(city.level)])
	var bld := 0
	for building in city.buildings:
		if building != null:
			bld += 1
	if bld < level_buildings_req(city.level):
		reasons.append("Здания: %d/%d" % [bld, level_buildings_req(city.level)])
	return {"ok": reasons.is_empty(), "reasons": reasons}

static func try_level_up(city: City) -> bool:
	var check := can_level_up(city)
	if not bool(check.ok):
		return false
	city.level += 1
	return true
