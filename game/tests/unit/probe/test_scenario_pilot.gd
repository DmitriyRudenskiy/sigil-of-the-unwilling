extends BaseTest
## autopilot-scenario-matrix: ScenarioPilot + ScenarioTargets + роли — юнит-тесты.

func test_role_targets_table() -> void:
	var ids: Array = ScenarioTargets.role_ids()
	assert_bool(bool(ids.size() == 5)).is_true()
	assert_bool(bool(ScenarioTargets.role("collector").has("rare_goal"))).is_true()
	assert_bool(bool(ScenarioTargets.role("traveler").has("distance_goal"))).is_true()
	assert_bool(bool(ScenarioTargets.role("trader").has("gold_goal"))).is_true()
	assert_bool(bool(ScenarioTargets.role("adventurer").has("kill_goal"))).is_true()
	assert_bool(bool(ScenarioTargets.role("builder").has("population_goal"))).is_true()
	assert_bool(bool(ScenarioTargets.role("unknown").is_empty())).is_true()

func test_max_turns() -> void:
	assert_bool(bool(ScenarioTargets.max_turns("collector") == 60)).is_true()
	assert_bool(bool(ScenarioTargets.max_turns("traveler") == 90)).is_true()
	assert_bool(bool(ScenarioTargets.max_turns("builder") == 90)).is_true()
	assert_bool(bool(ScenarioTargets.max_turns("nope") == 60)).is_true()

func test_seed_deterministic_and_distinct() -> void:
	var s1: int = ScenarioTargets.seed_for("wizard", "collector")
	var s2: int = ScenarioTargets.seed_for("wizard", "collector")
	var s3: int = ScenarioTargets.seed_for("rogue", "collector")
	var s4: int = ScenarioTargets.seed_for("wizard", "traveler")
	assert_bool(bool(s1 == s2)).is_true()
	assert_bool(bool(s1 != s3)).is_true()
	assert_bool(bool(s1 != s4)).is_true()
	assert_bool(bool(s1 > 0)).is_true()

func test_make_role_all_five() -> void:
	var ids: Array = ["collector", "traveler", "trader", "adventurer", "builder"]
	for id in ids:
		var role: ScenarioRole = ScenarioPilot.make_role(str(id), ScenarioTargets.role(str(id)))
		assert_bool(bool(role != null)).is_true()
		assert_bool(bool(str(role.id) == str(id))).is_true()
		assert_bool(bool(not role.target.is_empty())).is_true()

func test_make_role_unknown() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("nope", {})
	assert_bool(bool(role == null)).is_true()

func test_pilot_extends_balance_probe() -> void:
	var pilot := ScenarioPilot.new()
	assert_bool(bool(pilot is BalanceProbe)).is_true()
	pilot.free()

func test_collector_metrics_shape() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("collector", ScenarioTargets.role("collector"))
	var pilot: _FakePilot = auto_free(_FakePilot.new())
	var m: Dictionary = role.metrics(pilot)
	assert_bool(bool(m.has("rare_extracted"))).is_true()
	# T-123: цель эхом берётся из конфига — тест проверяет проводку echo,
	# а не хардкод числа (вердикт: баг теста — ждал 20 при rare_goal=10 с
	# дня рождения обоих файлов; полупустой assert скрывал это всегда).
	assert_bool(bool(int(m.get("rare_goal", -1)) == int(ScenarioTargets.role("collector").get("rare_goal", -99)))).is_true()
	assert_bool(bool(m.has("resources_per_day"))).is_true()
	assert_bool(bool(m.has("survived"))).is_true()
	# Задача 4.2 (2026-10-26): отчёт обязан различать узлы и единицы — «50» в замере
	# было одним золотым узлом (T-303). Ключи без этого теста жили бы только в коде роли.
	assert_bool(bool(m.has("rare_nodes"))).is_true()
	assert_bool(bool(m.has("resource_nodes_extracted"))).is_true()
	assert_bool(bool(m.has("rare_targets_seen"))).is_true()

func test_collector_collect_target_prefers_rare() -> void:
	# Редкий узел дальше, обычный ближе — политика должна выбрать редкий.
	var role: ScenarioRole = ScenarioPilot.make_role("collector", ScenarioTargets.role("collector"))
	var pilot: _FakePilot = auto_free(_FakePilot.new())
	pilot.sp.set_res(Vector2i(1, 0), 0)  # обычный (wood) — рядом
	pilot.sp.set_res(Vector2i(5, 0), 4)  # редкий (crystal) — дальше
	pilot.map_f.resource_cells = {Vector2i(1, 0): true, Vector2i(5, 0): true}
	pilot.hero.cell = Vector2i(0, 0)
	var t: Vector2i = role.collect_target(pilot)
	pilot.free()
	assert_bool(bool(t == Vector2i(5, 0))).is_true()

func test_collector_collect_target_none_when_no_rare() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("collector", ScenarioTargets.role("collector"))
	var pilot: _FakePilot = auto_free(_FakePilot.new())
	pilot.sp.set_res(Vector2i(1, 0), 0)
	pilot.map_f.resource_cells = {Vector2i(1, 0): true}
	var t = role.collect_target(pilot)
	pilot.free()
	assert_bool(bool(t == null)).is_true()

func test_traveler_metrics_shape() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("traveler", ScenarioTargets.role("traveler"))
	var pilot: _FakePilot = auto_free(_FakePilot.new())
	var m: Dictionary = role.metrics(pilot)
	pilot.free()
	assert_bool(bool(m.has("arrived"))).is_true()
	assert_bool(bool(m.has("biomes"))).is_true()
	assert_bool(bool(int(m.get("distance_goal", -1)) == int(ScenarioTargets.role("traveler").get("distance_goal", -99)))).is_true()
	assert_bool(bool(int(m.get("biome_goal", -1)) == int(ScenarioTargets.role("traveler").get("biome_goal", -99)))).is_true()

func test_adventurer_metrics_and_ring2_only() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("adventurer", ScenarioTargets.role("adventurer"))
	var pilot: _FakePilot = auto_free(_FakePilot.new())
	# Кольцо 2: 12..24 от старта (центр города = 0,0). (15,0) — в кольце, (5,0) — нет.
	pilot.map_f.enemy_stacks = {Vector2i(15, 0): true, Vector2i(5, 0): true}
	var t: Vector2i = role.enemy_target(pilot)
	pilot.free()
	assert_bool(bool(t == Vector2i(15, 0))).is_true()

func test_adventurer_metrics_shape() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("adventurer", ScenarioTargets.role("adventurer"))
	var pilot: _FakePilot = auto_free(_FakePilot.new())
	var m: Dictionary = role.metrics(pilot)
	pilot.free()
	assert_bool(bool(int(m.get("kills", -1)) == 0)).is_true()
	assert_bool(bool(int(m.get("kill_goal", 0)) == 5)).is_true()
	assert_bool(bool(m.has("survived"))).is_true()

func test_builder_metrics_shape() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("builder", ScenarioTargets.role("builder"))
	var pilot: _FakePilot = auto_free(_FakePilot.new())
	pilot.city.level = 2
	pilot.city.buildings = [1, 2, 3, 4]
	var m: Dictionary = role.metrics(pilot)
	# Цель: уровень 2 + 4 здания — достигнута
	assert_bool(bool(role.goal_met(pilot))).is_true()
	pilot.free()
	assert_bool(bool(m.has("population"))).is_true()
	assert_bool(bool(int(m.get("city_level", 0)) == 2)).is_true()
	assert_bool(bool(int(m.get("buildings", 0)) == 4)).is_true()
	assert_bool(bool(int(m.get("buildings_goal", -1)) == int(ScenarioTargets.role("builder").get("buildings_goal", -99)))).is_true()

func test_trader_metrics_shape() -> void:
	var role: ScenarioRole = ScenarioPilot.make_role("trader", ScenarioTargets.role("trader"))
	var pilot: _FakePilot = auto_free(_FakePilot.new())
	pilot._player_city = City.new()
	pilot._player_city.storage[&"industry"] = 1500.0
	var m: Dictionary = role.metrics(pilot)
	assert_bool(bool(int(m.get("gold", 0)) == 1500)).is_true()
	assert_bool(bool(int(m.get("gold_goal", 0)) == 1000)).is_true()
	assert_bool(bool(m.has("deals"))).is_true()
	assert_bool(bool(m.has("margin"))).is_true()
	assert_bool(bool(role.goal_met(pilot))).is_true()
	pilot.free()

# ── Фейки: утка под интерфейс BalanceProbe для политик ролей ───────────────

class _FakeSpawner extends Node:
	var _res: Dictionary = {}
	func set_res(cell: Vector2i, t: int) -> void: _res[cell] = t
	func get_res_type_at(cell: Vector2i) -> int: return int(_res.get(cell, -1))

class _FakeMap:
	var resource_cells: Dictionary = {}
	var enemy_stacks: Dictionary = {}
	func get_terrain_id(_cell: Vector2i) -> int: return 0
	func is_walkable(_cell: Vector2i) -> bool: return true

class _FakeHero extends Node:
	var cell: Vector2i = Vector2i.ZERO
	var combat_hp := 10
	func get_component(_id: StringName) -> Node: return null

class _FakeCity:
	var center: Vector2i = Vector2i.ZERO
	var level := 1
	var buildings: Array = []
	var storage: Dictionary = {}
	var pop: Array = []
	func pop_total() -> int: return pop.size()

class _FakePilot extends Node:
	var sp: _FakeSpawner = _FakeSpawner.new()
	var map_f: _FakeMap = _FakeMap.new()
	var hero: _FakeHero = _FakeHero.new()

	func _notification(what: int) -> void:
		# CI-4 гигиена: владелец пилота free'ится — его Node-поля за ним.
		if what == NOTIFICATION_PREDELETE:
			if sp != null and is_instance_valid(sp):
				sp.free()
			if hero != null and is_instance_valid(hero):
				hero.free()
	var city := _FakeCity.new()
	var _spawner: Node = null
	var _hero: Node = null
	var _player_city: Variant = null
	var _world: Node = null
	var turn := 1
	var extracted_total := 0
	var extracted_nodes := 0
	var _rare_count := 0
	var _rare_nodes := 0

	func _init() -> void:
		_spawner = sp
		_hero = hero
		_player_city = city

	func _map():
		return map_f

	func _hero_cell() -> Vector2i:
		return hero.cell

	func _city_center() -> Vector2i:
		return city.center

	func _needs_low() -> bool:
		return false

	func _walk_to(_c: Vector2i) -> bool:
		return false

	func _explore_target(_c: Vector2i) -> Vector2i:
		return Vector2i(-1, -1)

	func _end_turn() -> void:
		pass

	func _commit(_p: bool) -> void:
		pass

	func _fail(_m: String) -> void:
		pass

	func rare_count() -> int:
		return _rare_count

	## Зеркало реального пилота (задача 4.2, T-303): фейк обязан поспевать за
	## поверхностью, которую читают роли, иначе «форма метрик» проверялась бы на
	## устаревшем контракте.
	func rare_nodes() -> int:
		return _rare_nodes
