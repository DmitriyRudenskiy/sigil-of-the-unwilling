class_name CityService
extends RefCounted
## R2: операции города (сплит City.gd). Чистое состояние — CityData,
## фасад City делегирует сюда. Сигналы эмитятся на CityData (City наследует).
# ─── Запросы ───────────────────────────────────────────────────
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
	for b in c.buildings:
		if b == null or b.def == null:
			continue
		n += int(b.def.housing.get(state, 0))
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
	for b in c.boroughs:
		a += b.net_approval()
	if c.starving:
		a -= GameNumbers.STARVING_APPROVAL_PENALTY
	return a
static func find_pop(c: CityData, p_uid: int) -> PopUnit:
	for u in c.pop:
		if u.uid == p_uid:
			return u
	return null
static func get_building_at(c: CityData, cell: Vector2i) -> UniqueBuilding:
	for b in c.buildings:
		if b.cell == cell:
			return b
	return null
static func cell_is_built(c: CityData, cell: Vector2i) -> bool:
	if cell == c.center:
		return true
	for b in c.boroughs:
		if b.cell == cell:
			return true
	for bl in c.buildings:
		if bl.cell == cell:
			return true
	return false
static func has_road(c: CityData, cell: Vector2i) -> bool:
	return c.roads.has(cell)
static func building_max_distance(c: CityData) -> int:
	return ProsperitySystem.build_radius_for_level(c.level)
static func ring_of(c: CityData, cell: Vector2i) -> int:
	return HexUtils.hex_distance(cell, c.center)
static func get_great_temple_level(c: CityData) -> int:
	for b in c.buildings:
		if b.def != null and b.def.id == &"great_temple":
			return b.level
	return 0
static func can_resurrect(c: CityData, required: Dictionary) -> bool:
	if get_great_temple_level(c) < 1:
		return false
	for key in required:
		if not c.storage.has(key):
			return false
		if float(c.storage.get(key, 0.0)) < float(required[key]):
			return false
	return true
# ─── Мутации ──────────────────────────────────────────────────
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

# ─── R5: инлайн-методы City.gd (защита, переключение состояния) ──
static func defense_strength(city: City) -> int:
	var d := count_state(city, PopUnit.State.MILITIA) * GameNumbers.RAID_DEF_PER_MILITIA
	for b in city.buildings:
		if b != null and b.def != null and b.def.id == &"walls":
			d += b.level * GameNumbers.RAID_DEF_PER_WALL
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
