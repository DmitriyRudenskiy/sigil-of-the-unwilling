extends BaseTest

## Проверки маршрута Путешественника (задача 5.3 цикла
## `scenario-matrix-behavior-reliability`: «добавить проверки повторного биома,
## прибытия и недостижимого маршрута»). До этого ни один из трёх случаев не был
## закрыт тестом: роль жила только в матричных прогонах, а прогон показывает
## результат, но не отличает «не выбрал цель», «не дошёл» и «счётчик биомов
## считает клетки вместо типов» (задача 5.1).
##
## Пилот — заглушка: `_walk_to` здесь **телепортирует** героя в запрошенную клетку.
## Это не упрощение «чтобы прошло», а граница теста: настоящее движение и MP проверяются
## в `test_scenario_pilot.gd` и матрицей, а здесь предмет проверки — политика роли
## (выбор цели, счётчик типов террейна, фиксация прибытия, отказ на пустой карте).

var _target_conf: Dictionary = ScenarioTargets.role("traveler")


func _role() -> TravelerRole:
	var role := TravelerRole.new()
	role.target = _target_conf
	return role


func _pilot() -> _FakeTravelerPilot:
	var pilot := _FakeTravelerPilot.new()
	add_child(pilot)
	auto_free(pilot)
	return pilot


## Кольцо [25, 40) из проходимых клеток вокруг старта — тот же класс карты, который
## `_pick_target` умеет выбирать. Клетки перебираются тем же `hex_distance`, которым
## пользуется роль, поэтому тест не зависит от того, чётная раскладка или нечётная.
func _ring_pilot(radius_from: int, radius_to: int) -> _FakeTravelerPilot:
	var pilot := _pilot()
	for x in range(-radius_to - 1, radius_to + 2):
		for y in range(-radius_to - 1, radius_to + 2):
			var c := Vector2i(x, y)
			var d: int = HexUtils.hex_distance(c, Vector2i.ZERO)
			if d <= radius_to:
				pilot.map.terrain_grid[c] = 0
				if d >= radius_from:
					pilot.map.walkable.append(c)
	return pilot


func test_picked_target_lies_in_the_route_ring() -> void:
	var pilot := _ring_pilot(25, 40)
	var role := _role()

	role.act(pilot)

	assert_bool(role._target != Vector2i(-1, -1)).is_true() \
		.override_failure_message("на кольце [25,40) цель обязана найтись")
	var d: int = HexUtils.hex_distance(role._target, Vector2i.ZERO)
	assert_bool(d >= 25 and d < 40).is_true() \
		.override_failure_message("дистанция цели вне кольца role.target: %d" % d)
	assert_that(int(role.metrics(pilot).get("distance_goal", -1))).is_equal(25)


func test_repeated_biome_does_not_grow_the_counter() -> void:
	# Задача 5.1: «повторный биом не должен увеличивать счётчик». Стартовая и целевая
	# клетки одного террейна, акт повторяется трижды — счётчик остаётся единицей.
	var pilot := _ring_pilot(1, 2)
	pilot.map.terrain_grid[pilot.hero_cell] = 7
	var role := _role()
	role._start = pilot.hero_cell
	role._target = Vector2i(1, 0)
	pilot.map.terrain_grid[Vector2i(1, 0)] = 7

	role.act(pilot)
	role.act(pilot)
	role.act(pilot)

	assert_that(int(role.metrics(pilot).get("biomes", -1))).is_equal(1)


func test_new_terrain_type_grows_the_counter_once() -> void:
	var pilot := _ring_pilot(1, 2)
	var role := _role()
	role._start = pilot.hero_cell
	role._target = Vector2i(1, 0)
	pilot.map.terrain_grid[pilot.hero_cell] = 7
	pilot.map.terrain_grid[Vector2i(1, 0)] = 2

	role.act(pilot)   # террейна старта ещё нет в списке → +1, телепорт к цели
	role.act(pilot)   # тот же террейн цели → не растёт
	role.act(pilot)

	assert_that(int(role.metrics(pilot).get("biomes", -1))).is_equal(2)


func test_arrival_is_recorded_only_on_the_target_cell() -> void:
	var pilot := _ring_pilot(1, 2)
	var role := _role()
	role._start = pilot.hero_cell
	role._target = Vector2i(4, 1)

	assert_bool(role.goal_met(pilot)).is_false() \
		.override_failure_message("прибытие не фиксируется до входа в клетку цели")
	assert_bool(bool(role.metrics(pilot).get("arrived", true))).is_false() \
		.override_failure_message("метрика arrived обязана следовать за goal_met")

	pilot.hero_cell = Vector2i(4, 1)
	assert_bool(role.goal_met(pilot)).is_true() \
		.override_failure_message("клетка цели = прибытие")
	assert_bool(bool(role.metrics(pilot).get("arrived", false))).is_true() \
		.override_failure_message("метрика arrived не стала константой")


func test_unreachable_map_fails_the_run_instead_of_stalling() -> void:
	# Карта без единой проходимой клетки: цель выбрать не из чего, и роль обязана
	# признать поражение забега, а не жечь ходы (задача 5.3, «недостижимый маршрут»).
	var pilot := _pilot()
	var role := _role()

	assert_bool(role.act(pilot)).is_true() \
		.override_failure_message("act обязан вернуть true — кадр обработан ролью")
	assert_that(pilot.errors.size()).is_equal(1)
	assert_bool(String(pilot.errors[0]).contains("нет проходимой цели")).is_true() \
		.override_failure_message("причина отказа обязана называть маршрут, а не молчать")
	assert_bool(role.goal_met(pilot)).is_false() \
		.override_failure_message("на недостижимой карте прибытия быть не может")


func test_empty_ring_falls_back_to_the_farthest_walkable() -> void:
	# Кольца [25,40) нет вовсе (малая карта): роль обязана взять самую дальнюю
	# проходимую клетку, а не объявить маршрут недостижимым (иначе 5.3 «недостижимый
	# маршрут» станет дефолтом на каждой маленькой карте).
	var pilot := _ring_pilot(1, 5)
	var role := _role()

	role.act(pilot)

	assert_bool(role._target != Vector2i(-1, -1)).is_true() \
		.override_failure_message("пустое кольцо — не повод отказываться от маршрута")
	assert_that(HexUtils.hex_distance(role._target, Vector2i.ZERO)).is_equal(5)


func test_goal_ignores_the_biome_threshold() -> void:
	# ПИН НАХОДКИ (задача 5.2 требует «порог 2 уникальных биома», а `goal_met` смотрит
	# только на клетку цели): дошёл с одним биомом = цель достигнута. Если порог решат
	# встроить в цель, этот кейс покраснеет и заставит пересчитать задачи 5.x и матрицу.
	var pilot := _ring_pilot(1, 2)
	var role := _role()
	role._start = pilot.hero_cell
	role._target = Vector2i(1, 0)
	pilot.map.terrain_grid[pilot.hero_cell] = 7
	pilot.map.terrain_grid[Vector2i(1, 0)] = 7
	pilot.hero_cell = Vector2i(1, 0)
	role.act(pilot)  # один акт, чтобы счётчик биомов вообще был наполнен

	assert_bool(role.goal_met(pilot)).is_true() \
		.override_failure_message("цель сейчас = только клетка B; биомы не входят в цель")
	assert_that(int(role.metrics(pilot).get("biomes", -1))).is_equal(1)
	assert_that(int(role.metrics(pilot).get("biome_goal", -1))).is_equal(2)


class _FakeHero extends RefCounted:
	var combat_hp: int = 30


class _FakeTravelerMap extends RefCounted:
	var terrain_grid: Dictionary = {}
	var walkable: Array[Vector2i] = []

	func is_walkable(cell: Vector2i) -> bool:
		return walkable.has(cell)

	func get_terrain_id(cell: Vector2i) -> int:
		return int(terrain_grid.get(cell, -1))


class _FakeTravelerPilot extends Node:
	var map := _FakeTravelerMap.new()
	var _hero := _FakeHero.new()
	var hero_cell := Vector2i.ZERO
	var turn := 1
	var errors: Array[String] = []
	var end_turns := 0
	var _world = null

	func _map() -> _FakeTravelerMap:
		return map

	func _hero_cell() -> Vector2i:
		return hero_cell

	func _needs_low() -> bool:
		return false

	func _city_center() -> Vector2i:
		return Vector2i.ZERO

	## Телепорт: движение и MP — предмет других тестов, здесь важна только клетка.
	func _walk_to(cell: Vector2i) -> bool:
		if not map.is_walkable(cell):
			return false
		hero_cell = cell
		return true

	func _explore_target(_toward: Vector2i) -> Vector2i:
		return Vector2i(-1, -1)

	func _end_turn() -> void:
		end_turns += 1

	func _fail(reason: String) -> void:
		errors.append(reason)
