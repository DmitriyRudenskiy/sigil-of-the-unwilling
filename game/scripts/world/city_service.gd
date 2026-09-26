class_name CityService
extends RefCounted

const LeadershipCheck = preload("res://scripts/systems/leadership_check.gd")
const WeaponTechService = preload("res://scripts/systems/weapon_tech_service.gd")

# social-stats-weapon-tech: управляемый rng для проверок найма
static var _rng := RandomNumberGenerator.new()
static var _rng_override: RandomNumberGenerator = null

static func set_rng(rng: RandomNumberGenerator) -> void:
	_rng_override = rng

static func _recruit_difficulty(city_level: int) -> String:
	if city_level >= 7:
		return "veteran"
	if city_level >= 4:
		return "hunter"
	return "militia"

static func pop_total(c: CityData) -> int:
	return c.pop.size()
static func pop_capped(c: CityData) -> int:
	var n := 0
	for u in c.pop:
		if u.state != PopUnit.State.MILITIA:
			n += 1
	return n
static func pop_cap(c: CityData) -> int:
	var idx := clampi(c.stronghold_level, 1, GameNumbers.POP_CAP_BY_STRONGHOLD.size()) - 1
	return GameNumbers.POP_CAP_BY_STRONGHOLD[idx] + housing_total(c)
static func over_limit(c: CityData) -> int:
	return maxi(0, pop_capped(c) - pop_cap(c))
static func count_state(c: CityData, s: PopUnit.State) -> int:
	var n := 0
	for u in c.pop:
		if u.state == s:
			n += 1
	return n
static func free_followers(c: CityData) -> int:
	var n := 0
	for u in c.pop:
		if u.is_free_follower():
			n += 1
	return n
static func garrison_count(c: CityData) -> int:
	return count_state(c, PopUnit.State.MILITIA)
static func garrison_size(c: CityData) -> int:
	return count_state(c, PopUnit.State.MILITIA)
static func patrol_count(c: CityData) -> int:
	var n := 0
	for u in c.pop:
		if u.state == PopUnit.State.MILITIA and u.patrol:
			n += 1
	return n
static func safety(c: CityData) -> int:
	return patrol_count(c) * GameNumbers.SAFETY_PER_PATROL
static func reputation_band(c: CityData) -> int:
	return ReputationSystem.band(c.reputation)
static func housing_capacity(c: CityData, state: int) -> int:
	var n := 0
	for building in c.buildings:
		if building == null or building.def == null:
			continue
		n += int(building.def.housing.get(state, 0))
	return n
static func housing_total(c: CityData) -> int:
	var n := 0
	for state in PopUnit.State.values():
		n += housing_capacity(c, state)
	return n
static func free_housing(c: CityData, state: int) -> int:
	var slots := housing_capacity(c, state)
	if state == PopUnit.State.WORKER:
		slots += GameNumbers.BASE_SETTLEMENT_HOUSING
	return slots - count_state(c, state)
static func immigrant_state(c: CityData) -> int:
	if free_housing(c, PopUnit.State.WORKER) > 0:
		return PopUnit.State.WORKER
	if free_housing(c, PopUnit.State.MILITIA) > 0:
		return PopUnit.State.MILITIA
	if free_housing(c, PopUnit.State.SCHOLAR) > 0:
		return PopUnit.State.SCHOLAR
	return -1
static func approval(c: CityData) -> int:
	var a := 0
	for borough in c.boroughs:
		a += borough.net_approval()
	if c.starving:
		a -= GameNumbers.STARVING_APPROVAL_PENALTY
	return a
static func find_pop(c: CityData, p_uid: int) -> PopUnit:
	for u in c.pop:
		if u.uid == p_uid:
			return u
	return null
static func get_building_at(c: CityData, cell: Vector2i) -> UniqueBuilding:
	for building in c.buildings:
		if building.cell == cell:
			return building
	return null
static func cell_is_built(c: CityData, cell: Vector2i) -> bool:
	if cell == c.center:
		return true
	for borough in c.boroughs:
		if borough.cell == cell:
			return true
	for bl in c.buildings:
		if bl.cell == cell:
			return true
	return false
static func has_road(c: CityData, cell: Vector2i) -> bool:
	return c.roads.has(cell)
static func building_max_distance(c: CityData) -> int:
	return ProsperitySystem.build_radius_for_level(c.level)

## Ранняя игра: тир оружия по уровню города (early-game-foundation): 1-4 → T1, 5-8 → T2, 9-11 → T3
static func weapon_tier_for_city(level: int) -> int:
	if level >= 9:
		return 3
	if level >= 5:
		return 2
	return 1
static func ring_of(c: CityData, cell: Vector2i) -> int:
	return HexUtils.hex_distance(cell, c.center)
static func get_great_temple_level(c: CityData) -> int:
	for building in c.buildings:
		if building.def != null and building.def.id == &"great_temple":
			return building.level
	return 0
## Ранняя игра: военная рекрутка (early-game-foundation).
## Здание с military_chain рекрутирует отряд в армию героя; плата — ресурсы хранилища.
static func recruit_military(c: CityData, building: UniqueBuilding, hero: Node) -> CityCheck:
	if building == null or building.def == null:
		return CityCheck.fail("Нет здания")
	var chain: Dictionary = building.def.military_chain
	if chain.is_empty():
		return CityCheck.fail("Здание не рекрутирует войска")
	var costs: Array = chain.get("costs", [])
	var idx: int = clampi(building.level - 1, 0, maxi(costs.size() - 1, 0))
	var cost: Dictionary = costs[idx] if idx < costs.size() else {}
	for key in cost:
		if float(c.storage.get(key, 0.0)) < float(cost[key]):
			return CityCheck.fail("Не хватает %s: %.0f/%.0f" % [str(key), float(c.storage.get(key, 0.0)), float(cost[key])])
	if hero == null or not (hero is HeroController) or hero.get_army() == null:
		return CityCheck.fail("Нет героя")
	var army: Array = hero.get_army().army
	# social-stats-weapon-tech: cap стеков от харизмы героя (мин 3)
	var cha: int = int(hero.stats.get("cha", 2))
	var cap: int = mini(LeadershipCheck.max_army_stacks(cha), GameNumbers.HERO_ARMY_MAX_STACKS)
	if army.size() >= cap:
		return CityCheck.fail("Армия героя заполнена (%d/%d отрядов)" % [army.size(), cap])
	# d20-проверка найма: успех/слухи/отказ/крит-инцидент
	var check: Dictionary = LeadershipCheck.recruit_check(
		_rng_override if _rng_override != null else _rng, cha, c.reputation, 1, _recruit_difficulty(c.level))
	match str(check.get("outcome", "success")):
		"refused":
			return CityCheck.fail("Наёмники отказались (харизма/репутация)")
		"rumor":
			ReputationSystem.apply(c, float(check.get("rep_delta", -5)))
			return CityCheck.fail("Наём сорвался — пошли слухи (репутация -5)")
		"critical":
			ReputationSystem.apply(c, float(check.get("rep_delta", -10)))
			return CityCheck.fail("Крит-инцидент на найме (репутация -10)")
	for key in cost:
		c.storage[key] = float(c.storage.get(key, 0.0)) - float(cost[key])
	var unit_key := String(chain.get("unit_key", ""))
	# social-stats-weapon-tech: тир = max(fallback по уровню, tech по кузнице/ресурсам)
	var tier: int = WeaponTechService.city_weapon_tier(c, cha)
	var reg: Node = Services.resolve(&"units")
	var stack: UnitStack = reg.make_recruit_stack(unit_key, GameNumbers.RECRUIT_BATCH_SIZE, tier)
	if stack == null:
		return CityCheck.fail("Нет определения юнита: %s" % unit_key)
	# качество найма: множитель cha на базовые характеристики стека
	var quality: float = LeadershipCheck.recruit_quality(cha)
	if absf(quality - 1.0) > 0.001 and stack.stats != null:
		stack.stats.base_damage = int(round(float(stack.stats.base_damage) * quality))
		stack.stats.attack = int(round(float(stack.stats.attack) * quality))
	army.append(stack)
	return CityCheck.success({"unit": unit_key, "count": GameNumbers.RECRUIT_BATCH_SIZE, "tier": tier})

static func can_resurrect(c: CityData, required: Dictionary) -> bool:
	if get_great_temple_level(c) < 1:
		return false
	for key in required:
		if not c.storage.has(key):
			return false
		if float(c.storage.get(key, 0.0)) < float(required[key]):
			return false
	return true

static func add_migrant(c: CityData, state: PopUnit.State, turn: int, tile := Vector2i(-1, -1)) -> PopUnit:
	var u := PopUnit.new()
	u.uid = c._uid_seq
	c._uid_seq += 1
	u.state = state
	u.tile = tile
	u.born_turn = turn
	c.pop.append(u)
	return u
static func remove_pop(c: CityData, p_uid: int) -> PopUnit:
	var u := find_pop(c, p_uid)
	if u == null:
		return null
	c.pop.erase(u)
	c.invalidate_yield()
	c.population_changed.emit()
	return u
static func set_patrol(c: CityData, p_uid: int, on: bool) -> bool:
	var u := find_pop(c, p_uid)
	if u == null or u.state != PopUnit.State.MILITIA:
		return false
	u.patrol = on
	c.population_changed.emit()
	return true
static func add_road(c: CityData, cell: Vector2i) -> void:
	if not c.roads.has(cell):
		c.roads[cell] = true
		c.buildings_changed.emit()
static func remove_road(c: CityData, cell: Vector2i) -> void:
	if c.roads.erase(cell):
		c.buildings_changed.emit()
static func add_followers(c: CityData, n: int, turn := -1) -> int:
	for i in n:
		add_migrant(c, PopUnit.State.FOLLOWER, turn)
	c.population_changed.emit()
	return over_limit(c)
static func send_followers_to(c: CityData, other: CityData, n: int) -> int:
	var moved := _take_free_followers(c, n, other)
	if moved > 0:
		c.population_changed.emit()
		other.population_changed.emit()
	return moved
static func disband_followers(c: CityData, n: int) -> int:
	var removed := _take_free_followers(c, n, null)
	if removed > 0:
		c.population_changed.emit()
	return removed
static func recruit_followers(c: CityData, n: int) -> int:
	return _take_free_followers(c, n, null)
static func _take_free_followers(c: CityData, n: int, relocate_to: CityData) -> int:
	var taken := 0
	for u in c.pop.duplicate():
		if taken >= n:
			break
		if not u.is_free_follower():
			continue
		c.pop.erase(u)
		if relocate_to != null:
			u.uid = relocate_to._uid_seq
			relocate_to._uid_seq += 1
			relocate_to.pop.append(u)
		taken += 1
	return taken

static func defense_strength(city: City) -> int:
	var d := count_state(city, PopUnit.State.MILITIA) * GameNumbers.RAID_DEF_PER_MILITIA
	for building in city.buildings:
		if building != null and building.def != null and building.def.id == &"walls":
			d += building.level * GameNumbers.RAID_DEF_PER_WALL
	d += SpecializationSystem.defense_bonus(city)
	return d

static func request_switch(
	city: City,
	p_uid: int,
	new_state: PopUnit.State,
	new_tile: Vector2i = Vector2i(-1, -1)
) -> CityCheck:
	var u := find_pop(city, p_uid)
	if u == null:
		return CityCheck.fail("")
	if new_state == PopUnit.State.WORKER and not CityBuildingService.is_worker_tile_free(city, new_tile, u.uid):
		return CityCheck.fail("Клетка недоступна для рабочего")
	if not u.request_switch(new_state, new_tile):
		return CityCheck.fail("Фигурка занята (уже переключается или закреплена за зданием)")
	return CityCheck.success()
