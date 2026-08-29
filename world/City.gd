class_name City
extends RefCounted
## Чистая модель города: население (3 состояния), районы, уникальные здания,
## еда/рост, одобрение, безопасность. Не зависит от узлов Godot —
## UI подписывается на сигналы (паттерн BattleState).

signal population_changed
signal boroughs_changed
signal buildings_changed
signal storage_changed
signal status_message(text: String)

enum Faction { DEFAULT, NECROPHAGE, ALLAYI, CULTISTS }

const _YIELD_KEYS := [&"food", &"industry", &"dust", &"science", &"influence"]

var uid := 0
var display_name := ""
var center := Vector2i(-1, -1)
var faction: int = Faction.DEFAULT
var stronghold_level := 1
var is_capital := false

var pop: Array[PopUnit] = []
var boroughs: Array[Borough] = []
var buildings: Array[UniqueBuilding] = []
## Спец. площадки региона: Vector2i -> StringName (см. BuildingDefs.SITE_*).
var special_sites: Dictionary = {}

var food_stockpile := 0.0
var storage: Dictionary = {}  # StringName -> float (industry, gold, ...)
var starving := false
# --- Экономика (M1) ---
## Хранилище ресурсов цепочек производства. Отдельно от легасийного storage:
## legacy-контур (City.process_turn, build costs) не тронут.
var resource_ctx: ResourceContext = null

## Провайдер FIDSI тайлов: Callable(cell) -> {food, industry, dust, science, influence}.
var tile_yield_fn: Callable = func(_cell: Vector2i) -> Dictionary: return {}

# --- Город (M3) ---
## Дороги: Vector2i -> true. Строит игрок (UI, M3+); логистика читает их.
var roads: Dictionary = {}
## Текущий масштаб города (ScaleShiftManager, 0..3).
var scale_tier := 0
## Мультипликаторы фазы города (CityTurnProcessor, M3): для экономики.
var auto_resource_mult := 1.0
var upkeep_mult := 1.0

var _uid_seq := 0

# Exploited cells cache (invalidated on borough/building changes)
var _exploited_cache: Dictionary = {}
var _exploited_dirty: bool = true

func _invalidate_exploited() -> void:
	_exploited_dirty = true


# ==================== НАСЕЛЕНИЕ: ПОДСЧЁТЫ ====================
func pop_total() -> int:
	return pop.size()


func pop_capped() -> int:
	## Рабочие + последователи — учитываются в лимите крепости. Ополченцы — нет (ТЗ 3.3).
	var n := 0
	for u in pop:
		if u.state != PopUnit.State.MILITIA:
			n += 1
	return n


func pop_cap() -> int:
	var idx := clampi(stronghold_level, 1, CityBalance.POP_CAP_BY_STRONGHOLD.size()) - 1
	return CityBalance.POP_CAP_BY_STRONGHOLD[idx]


func over_limit() -> int:
	return maxi(0, pop_capped() - pop_cap())


func count_state(s: PopUnit.State) -> int:
	var n := 0
	for u in pop:
		if u.state == s:
			n += 1
	return n


func free_followers() -> int:
	## Свободные последователи: доступны для найма войск и улучшений зданий.
	var n := 0
	for u in pop:
		if u.is_free_follower():
			n += 1
	return n


func find_pop(p_uid: int) -> PopUnit:
	for u in pop:
		if u.uid == p_uid:
			return u
	return null


## Удаляет фигурку (смерть/эмиграция, M2: Демография).
## Возвращает удалённую PopUnit или null, если uid не найден.
func remove_pop(p_uid: int) -> PopUnit:
	var u := find_pop(p_uid)
	if u == null:
		return null
	pop.erase(u)
	_invalidate_exploited()
	population_changed.emit()
	return u


# ==================== ЭКОНОМИКА (M1) ====================
func ensure_resource_ctx(defs: Array = []) -> ResourceContext:
	## Ленивая инициализация контекста ресурсов. defs — из ResourceRegistry
	## (даёт лимиты); при пустом массиве все id безлимитные (INF).
	if resource_ctx == null:
		resource_ctx = ResourceContext.new()
		resource_ctx.setup(defs)
	return resource_ctx


func get_building_at(cell: Vector2i) -> UniqueBuilding:
	for b in buildings:
		if b.cell == cell:
			return b
	return null


func get_logistics_multiplier(cell: Vector2i) -> float:
	## M3: LogisticsCalculator — затухание по дистанции до тела города
	## (центр/районы) + бонус за дорогу (на клетке или в соседней).
	return LogisticsCalculator.compute(self, cell)


## ==================== ДОРОГИ (M3) ====================
func has_road(cell: Vector2i) -> bool:
	return roads.has(cell)


func add_road(cell: Vector2i) -> void:
	if not roads.has(cell):
		roads[cell] = true
		buildings_changed.emit()


func remove_road(cell: Vector2i) -> void:
	if roads.erase(cell):
		buildings_changed.emit()

# ==================== НАСЕЛЕНИЕ: УПРАВЛЕНИЕ ====================
func request_switch(p_uid: int, new_state: PopUnit.State, new_tile := Vector2i(-1, -1)) -> bool:
	## Переключение состояния: бесплатно, вступает в силу в начале следующего хода.
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


func set_patrol(p_uid: int, on: bool) -> bool:
	## Назначение ополченца на патрулирование (подрежим милиции, мгновенно).
	var u := find_pop(p_uid)
	if u == null or u.state != PopUnit.State.MILITIA:
		return false
	u.patrol = on
	population_changed.emit()
	return true


func garrison_size() -> int:
	## Все ополченцы при осаде автоматически встают в гарнизон:
	## WorldController при старте осадного боя собирает из них стеки для BattleFlow.
	return count_state(PopUnit.State.MILITIA)


func patrol_count() -> int:
	var n := 0
	for u in pop:
		if u.state == PopUnit.State.MILITIA and u.patrol:
			n += 1
	return n


func safety() -> int:
	return patrol_count() * CityBalance.SAFETY_PER_PATROL_MILITIA


func add_followers(n: int, turn := -1) -> int:
	## Приток последователей (циклический приток и т.п.). Лимит не блокирует
	## прибытие (ТЗ 3.3) — возвращается переполнение, разбор руками.
	for i in n:
		_add_pop(PopUnit.State.FOLLOWER, turn)
	population_changed.emit()
	return over_limit()


func send_followers_to(other: City, n: int) -> int:
	## Перевод свободных последователей в другой город (снятие перелимита).
	var moved := _take_free_followers(n, other)
	if moved > 0:
		population_changed.emit()
		other.population_changed.emit()
	return moved


func disband_followers(n: int) -> int:
	## Распустить последователей (уходят, по ТЗ 3.3).
	var removed := _take_free_followers(n, null)
	if removed > 0:
		population_changed.emit()
	return removed


func recruit_followers(n: int) -> int:
	## Списать последователей на найм войск (каждый отряд требует своих, ТЗ 3.1).
	return _take_free_followers(n, null)


func _take_free_followers(n: int, relocate_to: City) -> int:
	var taken := 0
	for u in pop.duplicate():
		if taken >= n:
			break
		if not u.is_free_follower():
			continue
		pop.erase(u)
		if relocate_to != null:
			u.uid = relocate_to._uid_seq
			relocate_to._uid_seq += 1
			relocate_to.pop.append(u)
		taken += 1
	return taken


func _add_pop(state: PopUnit.State, turn: int, tile := Vector2i(-1, -1)) -> PopUnit:
	var u := PopUnit.new()
	u.uid = _uid_seq
	_uid_seq += 1
	u.state = state
	u.tile = tile
	u.born_turn = turn
	pop.append(u)
	return u


# ==================== КЛЕТКИ ====================
func cell_is_built(cell: Vector2i) -> bool:
	if cell == center:
		return true
	for b in boroughs:
		if b.cell == cell:
			return true
	for bl in buildings:
		if bl.cell == cell:
			return true
	return false


func _is_adjacent_to_city_body(cell: Vector2i) -> bool:
	## Клетка «вокруг города или района» — сосед центра или любого района (ТЗ 3.1).
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
	## Первая свободная клетка для рабочего (для UI-кнопки «→ Рабочий»).
	for nb in HexUtils.get_all_neighbors(center):
		if is_worker_tile_free(nb):
			return nb
	for b in boroughs:
		for nb in HexUtils.get_all_neighbors(b.cell):
			if is_worker_tile_free(nb):
				return nb
	return Vector2i(-1, -1)


# ==================== ЭКОНОМИКА ====================
func _ensure_exploited_cache() -> void:
	if not _exploited_dirty:
		return
	_exploited_cache.clear()
	for b in boroughs:
		for nb in HexUtils.get_all_neighbors(b.cell):
			if not cell_is_built(nb):
				_exploited_cache[nb] = true
	for u in pop:
		if u.state == PopUnit.State.WORKER and u.tile.x >= 0 and not cell_is_built(u.tile):
			_exploited_cache[u.tile] = true
	_exploited_dirty = false

func _exploited_cells() -> Dictionary:
	## Эксплуатируемые клетки: соседи каждого района (автоматически, ТЗ 4.1)
	## ∪ клетки, занятые рабочими. Застройка (районы/центр/здания) дохода не даёт.
	_ensure_exploited_cache()
	return _exploited_cache


func get_yield() -> Dictionary:
	var total := {}
	for k in _YIELD_KEYS:
		total[k] = 0.0
	for cell in _exploited_cells().keys():
		var y: Dictionary = tile_yield_fn.call(cell)
		for k in _YIELD_KEYS:
			total[k] = float(total[k]) + float(y.get(k, 0.0))
	return total


func food_consumption() -> float:
	return count_state(PopUnit.State.WORKER) * CityBalance.FOOD_PER_WORKER \
		+ count_state(PopUnit.State.MILITIA) * CityBalance.FOOD_PER_MILITIA \
		+ count_state(PopUnit.State.FOLLOWER) * CityBalance.FOOD_PER_FOLLOWER


func net_food() -> float:
	return float(get_yield()[&"food"]) - food_consumption()


func growth_threshold() -> float:
	## Порог = 5 × N^2.75; N = рабочие + последователи (ополченцы не участвуют, ТЗ 3.2).
	return CityBalance.GROWTH_THRESHOLD_BASE \
		* pow(float(maxi(1, pop_capped())), CityBalance.GROWTH_THRESHOLD_EXP)


func approval() -> int:
	var a := 0
	for b in boroughs:
		a += b.net_approval()
	if starving:
		a -= CityBalance.STARVING_APPROVAL_PENALTY
	return a


# ==================== ХОД ГОРОДА ====================
func process_turn(turn: int) -> Dictionary:
	## Вызывается CityManager.on_turn_ended() раз в ход. Порядок:
	## переключения фигурок → еда → рождения → уровни районов → склад.
	var switched := 0
	for u in pop:
		if u.apply_pending():
			switched += 1

	# Workers may have changed tiles, invalidate cache
	_invalidate_exploited()

	var nf := net_food()
	food_stockpile = maxf(0.0, food_stockpile + nf)
	starving = nf < 0.0

	var births := 0
	while pop_capped() < pop_cap() and food_stockpile >= growth_threshold():
		food_stockpile -= growth_threshold()
		_add_pop(PopUnit.State.FOLLOWER, turn)
		births += 1

	var level_ups := BoroughRules.process_level_ups(self)

	# Промышленность и прочее накапливаются в складе (расход на строительство).
	var y := get_yield()
	for k in [&"industry", &"dust", &"science", &"influence"]:
		storage[k] = float(storage.get(k, 0.0)) + float(y[k])

	if switched > 0 or births > 0:
		population_changed.emit()
	if level_ups > 0:
		boroughs_changed.emit()
	storage_changed.emit()
	return {
		"births": births, "level_ups": level_ups,
		"starving": starving, "net_food": nf, "switched": switched,
	}


# ==================== РАЙОНЫ ====================
func can_build_borough(cell: Vector2i) -> Dictionary:
	if cell == center:
		return _fail("Клетка занята центром города")
	if cell_is_built(cell):
		return _fail("Клетка уже застроена")
	if not _is_adjacent_to_city_body(cell):
		return _fail("Район должен примыкать к городу или району")
	if boroughs.size() >= BoroughRules.max_boroughs(self):
		return _fail("Лимит районов: 1 район на %d населения" % int(BoroughRules.pop_ratio(faction)))
	var cost := BoroughRules.cost(self)
	if float(storage.get(&"industry", 0.0)) < cost:
		return _fail("Промышленность: %.0f/%.0f" % [float(storage.get(&"industry", 0.0)), cost])
	return {"ok": true, "cost": cost, "reason": ""}


func build_borough(cell: Vector2i) -> bool:
	var check := can_build_borough(cell)
	if not check.ok:
		status_message.emit(check.reason)
		return false
	storage[&"industry"] = float(storage.get(&"industry", 0.0)) - float(check.cost)
	var b := Borough.new()
	b.cell = cell
	b.level = 1
	b.uid = _uid_seq
	_uid_seq += 1
	boroughs.append(b)
	BoroughRules.process_level_ups(self)  # новый район мог дать соседям 4-го
	_invalidate_exploited()
	boroughs_changed.emit()
	storage_changed.emit()
	return true


# ==================== УНИКАЛЬНЫЕ ЗДАНИЯ ====================
func can_build_building(def: UniqueBuilding.Def, cell: Vector2i) -> Dictionary:
	if def == null or def.levels.is_empty():
		return _fail("Нет определения здания")
	if cell == center or cell_is_built(cell):
		return _fail("Клетка занята")
	if def.requires_site:
		if not special_sites.has(cell):
			return _fail("Здание требует специальной площадки")
	else:
		if not _within_build_distance(cell):
			return _fail("Не дальше %d клеток от города или района" % CityBalance.BUILDING_MAX_BUILD_DISTANCE)
	var req: UniqueBuilding.LevelReq = def.levels[0]
	return _check_req(req)


func build_building(def: UniqueBuilding.Def, cell: Vector2i) -> UniqueBuilding:
	var check := can_build_building(def, cell)
	if not check.ok:
		status_message.emit(check.reason)
		return null
	var req: UniqueBuilding.LevelReq = def.levels[0]
	_spend_req(req)
	var bld := UniqueBuilding.new()
	bld.def = def
	bld.cell = cell
	bld.level = 1
	bld.uid = _uid_seq
	_uid_seq += 1
	_assign_followers(bld, req.followers)
	buildings.append(bld)
	_invalidate_exploited()
	buildings_changed.emit()
	storage_changed.emit()
	population_changed.emit()
	return bld


func can_upgrade_building(bld: UniqueBuilding, hero_cell := Vector2i(-1, -1)) -> Dictionary:
	## hero_cell < 0 — не проверять присутствие героя (для UI-превью).
	if bld == null or not buildings.has(bld):
		return _fail("Здание не найдено")
	if bld.level >= CityBalance.BUILDING_MAX_LEVEL:
		return _fail("Максимальный уровень")
	var req := bld.next_level_req()
	if req == null:
		return _fail("Нет требований для следующего уровня")
	var check := _check_req(req)
	if not check.ok:
		return check
	if hero_cell.x >= 0 and hero_cell != bld.cell:
		return _fail("Герой должен находиться на клетке здания")
	return check


func perform_upgrade(bld: UniqueBuilding) -> bool:
	## Списывает ресурсы и закрепляет последователей. Вызывает WorldController
	## после проверки героя (герой тратит ход там же).
	var check := can_upgrade_building(bld)
	if not check.ok:
		status_message.emit(check.reason)
		return false
	var req := bld.next_level_req()
	_spend_req(req)
	_assign_followers(bld, req.followers)
	bld.level += 1
	buildings_changed.emit()
	storage_changed.emit()
	population_changed.emit()
	return true


func get_great_temple_level() -> int:
	for b in buildings:
		if b.def != null and b.def.id == &"great_temple":
			return b.level
	return 0


func _within_build_distance(cell: Vector2i) -> bool:
	if HexUtils.hex_distance(cell, center) <= CityBalance.BUILDING_MAX_BUILD_DISTANCE:
		return true
	for b in boroughs:
		if HexUtils.hex_distance(cell, b.cell) <= CityBalance.BUILDING_MAX_BUILD_DISTANCE:
			return true
	return false


func _check_req(req: UniqueBuilding.LevelReq) -> Dictionary:
	if float(storage.get(&"industry", 0.0)) < req.industry:
		return _fail("Промышленность: %.0f/%.0f" % [float(storage.get(&"industry", 0.0)), req.industry])
	if req.special_amount > 0.0 \
			and float(storage.get(req.special_resource, 0.0)) < req.special_amount:
		return _fail("%s: %.0f/%.0f" % [
			String(req.special_resource),
			float(storage.get(req.special_resource, 0.0)), req.special_amount,
		])
	if free_followers() < req.followers:
		return _fail("Свободных последователей: %d/%d" % [free_followers(), req.followers])
	return {"ok": true, "cost": req.industry, "reason": ""}


func _spend_req(req: UniqueBuilding.LevelReq) -> void:
	storage[&"industry"] = float(storage.get(&"industry", 0.0)) - req.industry
	if req.special_amount > 0.0:
		storage[req.special_resource] = float(storage.get(req.special_resource, 0.0)) - req.special_amount


func _assign_followers(bld: UniqueBuilding, n: int) -> void:
	var left := n
	for u in pop:
		if left <= 0:
			break
		if u.is_free_follower():
			u.assigned_to = bld.uid
			left -= 1
	bld.assigned_followers += n - left


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "cost": 0.0, "reason": reason}
