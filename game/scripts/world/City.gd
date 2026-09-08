class_name City
extends CityData
## R2: тонкий фасад над CityData (состояние) + CityService (операции); API не меняется.

signal status_message(text: String)


func _invalidate_exploited() -> void: _yield_calc.invalidate()

func get_yield() -> Dictionary:
	return _yield_calc.calculate(self)

func get_logistics_multiplier(cell: Vector2i) -> float:
	return LogisticsCalculator.compute(self, cell)

# ─── Делегирование в CityService ─────────────────────────────────
func pop_total() -> int: return CityService.pop_total(self)
func pop_capped() -> int: return CityService.pop_capped(self)
func pop_cap() -> int: return CityService.pop_cap(self)
func over_limit() -> int: return CityService.over_limit(self)
func count_state(s: PopUnit.State) -> int: return CityService.count_state(self, s)
func free_followers() -> int: return CityService.free_followers(self)
func garrison_count() -> int: return CityService.garrison_count(self)
func garrison_size() -> int: return CityService.garrison_size(self)
func patrol_count() -> int: return CityService.patrol_count(self)
func safety() -> int: return CityService.safety(self)
func reputation_band() -> int: return CityService.reputation_band(self)
func housing_capacity(state: int) -> int: return CityService.housing_capacity(self, state)
func housing_total() -> int: return CityService.housing_total(self)
func free_housing(state: int) -> int: return CityService.free_housing(self, state)
func immigrant_state() -> int: return CityService.immigrant_state(self)
func approval() -> int: return CityService.approval(self)
func find_pop(p_uid: int) -> PopUnit: return CityService.find_pop(self, p_uid)
func get_building_at(cell: Vector2i) -> UniqueBuilding: return CityService.get_building_at(self, cell)
func cell_is_built(cell: Vector2i) -> bool: return CityService.cell_is_built(self, cell)
func has_road(cell: Vector2i) -> bool: return CityService.has_road(self, cell)
func building_max_distance() -> int: return CityService.building_max_distance(self)
func ring_of(cell: Vector2i) -> int: return CityService.ring_of(self, cell)
func get_great_temple_level() -> int: return CityService.get_great_temple_level(self)
func can_resurrect(required: Dictionary) -> bool: return CityService.can_resurrect(self, required)
func add_migrant(state: int = PopUnit.State.WORKER, turn: int = -1) -> PopUnit:
	return CityService.add_migrant(self, state, turn)
func _add_pop(state: PopUnit.State, turn: int, tile := Vector2i(-1, -1)) -> PopUnit:
	return CityService.add_migrant(self, state, turn, tile)
func remove_pop(p_uid: int) -> PopUnit: return CityService.remove_pop(self, p_uid)
func set_patrol(p_uid: int, on: bool) -> bool: return CityService.set_patrol(self, p_uid, on)
func add_road(cell: Vector2i) -> void: CityService.add_road(self, cell)
func remove_road(cell: Vector2i) -> void: CityService.remove_road(self, cell)
func add_followers(n: int, turn := -1) -> int: return CityService.add_followers(self, n, turn)
func send_followers_to(other: City, n: int) -> int: return CityService.send_followers_to(self, other, n)
func disband_followers(n: int) -> int: return CityService.disband_followers(self, n)
func recruit_followers(n: int) -> int: return CityService.recruit_followers(self, n)

# ─── Рабочие клетки ────────────────────────────────────────────
func _is_adjacent_to_city_body(cell: Vector2i) -> bool:
	if HexUtils.hex_distance(cell, center) == 1:
		return true
	for b in boroughs:
		if HexUtils.hex_distance(cell, b.cell) == 1:
			return true
	return false

func is_worker_tile_free(tile: Vector2i, except_uid := -1) -> bool:
	if tile.x < 0:
		return false
	if cell_is_built(tile):
		return false
	if not _is_adjacent_to_city_body(tile):
		return false
	for u in pop:
		if u.uid != except_uid and u.state == PopUnit.State.WORKER and u.tile == tile:
			return false
	return true

func first_free_worker_tile() -> Vector2i:
	for nb in HexUtils.get_all_neighbors(center):
		if is_worker_tile_free(nb):
			return nb
	for b in boroughs:
		for nb in HexUtils.get_all_neighbors(b.cell):
			if is_worker_tile_free(nb):
				return nb
	return Vector2i(-1, -1)

func first_free_build_cell(def: UniqueBuilding.Def, bounds := Vector2i.ZERO) -> Vector2i:
	if def == null or def.levels.is_empty():
		return Vector2i(-1, -1)
	if def.requires_site:
		var sites: Array = special_sites.keys().duplicate()
		sites.sort()
		for s in sites:
			var cell := Vector2i(s)
			if bounds.x > 0 and bounds.y > 0:
				if cell.x < 0 or cell.y < 0 or cell.x >= bounds.x or cell.y >= bounds.y:
					continue
			if not cell_is_built(cell):
				return cell
		return Vector2i(-1, -1)
	var max_d := building_max_distance()
	for r in range(1, max_d + 1):
		for cell in HexUtils.ring(center, r):
			if bounds.x > 0 and bounds.y > 0:
				if cell.x < 0 or cell.y < 0 or cell.x >= bounds.x or cell.y >= bounds.y:
					continue
			if cell_is_built(cell):
				continue
			if not is_buildable_fn.call(cell):
				continue
			return cell
	return Vector2i(-1, -1)
func food_consumption() -> float:
	return CityGrowthService.food_consumption(self)

func net_food() -> float:
	return CityGrowthService.net_food(self)

func growth_threshold() -> float:
	return CityGrowthService.growth_threshold(self)

func process_turn(turn: int) -> Dictionary:
	var r := CityGrowthService.process_turn(self, turn)
	if r.switched > 0 or r.births > 0:
		population_changed.emit()
	if r.level_ups > 0:
		boroughs_changed.emit()
	storage_changed.emit()
	return r

func can_build_borough(cell: Vector2i) -> Dictionary:
	return CityBuildingService.can_build_borough(self, cell)

func build_borough(cell: Vector2i) -> bool:
	var r := CityBuildingService.build_borough(self, cell)
	if not r.ok:
		status_message.emit(r.reason)
		return false
	_invalidate_exploited()
	boroughs_changed.emit()
	storage_changed.emit()
	return true

func can_build_building(def: UniqueBuilding.Def, cell: Vector2i) -> Dictionary:
	return CityBuildingService.can_build_building(self, def, cell)

func build_building(def: UniqueBuilding.Def, cell: Vector2i) -> UniqueBuilding:
	var r := CityBuildingService.build_building(self, def, cell)
	if r.bld == null:
		status_message.emit(r.reason)
		return null
	_invalidate_exploited()
	buildings_changed.emit()
	storage_changed.emit()
	population_changed.emit()
	return r.bld

func can_upgrade_building(bld: UniqueBuilding, hero_cell := Vector2i(-1, -1)) -> Dictionary:
	return CityBuildingService.can_upgrade_building(self, bld, hero_cell)

func perform_upgrade(bld: UniqueBuilding) -> bool:
	var r := CityBuildingService.perform_upgrade(self, bld)
	if not r.ok:
		status_message.emit(r.reason)
		return false
	buildings_changed.emit()
	storage_changed.emit()
	population_changed.emit()
	return true

func request_switch(p_uid: int, new_state: PopUnit.State, new_tile := Vector2i(-1, -1)) -> bool:
	var u := find_pop(p_uid)
	if u == null:
		return false
	if new_state == PopUnit.State.WORKER and not is_worker_tile_free(new_tile, u.uid):
		status_message.emit("Клетка недоступна для рабочего")
		return false
	if not u.request_switch(new_state, new_tile):
		status_message.emit("Фигурка занята (уже переключается или закреплена за зданием)")
		return false
	_invalidate_exploited()
	population_changed.emit()
	return true

func defense_strength() -> int:
	var d := count_state(PopUnit.State.MILITIA) * GameNumbers.RAID_DEF_PER_MILITIA
	for b in buildings:
		if b != null and b.def != null and b.def.id == &"walls":
			d += b.level * GameNumbers.RAID_DEF_PER_WALL
	d += SpecializationSystem.defense_bonus(self)
	return d

func relocate(new_center: Vector2i, map_size: Vector2i = Vector2i(-1, -1), occupied_cells: Dictionary = {}) -> Dictionary:
	var r := CityBuildingService.relocate(self, new_center, map_size, occupied_cells)
	if r.ok:
		relocation_completed.emit(r.new_center)
	return r

func serialize() -> Dictionary: return CitySerializer.serialize(self)
func deserialize(data: Dictionary) -> void: CitySerializer.deserialize(self, data)
