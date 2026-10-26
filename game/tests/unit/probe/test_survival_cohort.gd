extends BaseTest

## Когорта выживания (задача 7.1, `scenario-matrix-behavior-reliability`): носитель
## набора seed и роль-измеритель.
##
## До этих тестов у когорты не было ничего: ни зафиксированного набора карт, ни
## проверяемой формы отчёта. Замер «8/10 выжили» без носителя seed неотличим от
## «выжили на тех картах, что сегодня выдаёт хеш» — набор обязан быть литералом,
## а его инварианты — тестом (ср. `test_scenario_pilot.gd` про детерминированность
## `seed_for`).
##
## Отдельно зафиксировано, что когорта **не шестая роль матрицы**: `role_ids()`
## обязана оставаться пятеричной, иначе матрица 5×11 молча станет 6×11 и все пороги
## ролей поедут.

const COHORT_TURNS := 60
const COHORT_GOAL_SURVIVED := 8
const COHORT_GOAL_AVG_TURNS := 55


func _role() -> ScenarioRole:
	return ScenarioPilot.make_role("survival", ScenarioTargets.role("survival"))


func _pilot(snaps: Array, p_turn: int = COHORT_TURNS) -> _FakeSurvivalPilot:
	var pilot := _FakeSurvivalPilot.new()
	pilot.snapshots = snaps
	pilot.turn = p_turn
	add_child(pilot)
	auto_free(pilot)
	return pilot


func test_cohort_carrier_is_a_versioned_set_of_literals() -> void:
	var seeds: Array = ScenarioTargets.survival_seeds()
	assert_that(seeds.size()).is_equal(10)
	var seen := {}
	for s in seeds:
		var v: int = int(s)
		assert_bool(bool(v > 0)).is_true().override_failure_message("seed обязан быть положительным")
		# `seed_for()` возвращает hash + 1000000: пересечения когорты с матрицей
		# означали бы, что один и тот же прогон попадает в два разных замера.
		assert_bool(bool(v < 1000000)).is_true() \
			.override_failure_message("seed когорты лежит в диапазоне seed_for() — прогоны столкнутся")
		assert_bool(not seen.has(v)).is_true().override_failure_message("duplicate seed %d" % v)
		seen[v] = true
	var target: Dictionary = ScenarioTargets.role("survival")
	assert_that(int(target.get("max_turns", -1))).is_equal(COHORT_TURNS)
	assert_that(int(target.get("survival_goal", -1))).is_equal(COHORT_GOAL_SURVIVED)
	assert_that(int(target.get("average_turns_goal", -1))).is_equal(COHORT_GOAL_AVG_TURNS)
	assert_bool(bool(int(target.get("version", 0)) >= 1)).is_true() \
		.override_failure_message("без версии набора «среднее 55» в разных замерах значит разные карты")
	assert_bool(HeroClasses.CLASSES.has(str(target.get("class", "")))).is_true() \
		.override_failure_message("класс когорты обязан существовать в реестре классов")


func test_cohort_is_not_a_sixth_matrix_role() -> void:
	# Матрица обязана остаться 5×11: когорта обслуживается тем же интерфейсом цели,
	# но в реестр ролей не входит.
	assert_that(ScenarioTargets.role_ids().size()).is_equal(5)
	assert_bool(bool(ScenarioTargets.role_ids().has("survival"))).is_false()
	assert_bool(bool(ScenarioTargets.role("survival").has("seeds"))).is_true()
	assert_bool(bool(ScenarioTargets.role("nope").is_empty())).is_true()


func test_goal_never_finishes_the_run_early() -> void:
	var role := _role()
	var pilot := _pilot([{"turn": COHORT_TURNS, "combat_hp": 100}], COHORT_TURNS)
	# Выживание = дожить до конца заказа, а не «достичь» чего-то на середине: любой
	# ранний финиш свернул бы когорту до счёта ходов.
	assert_bool(role.goal_met(pilot)).is_false()


func test_interactions_count_probe_counters_not_first_turns() -> void:
	var pilot := _pilot([{"turn": 3, "combat_hp": 100}])
	pilot.extracted_nodes = 3
	pilot.builds_done = 2
	pilot.recruits_done = 1
	pilot.battles_fought = 4
	pilot.losses = 1
	var m: Dictionary = _role().metrics(pilot)
	assert_that(int(m.get("gathers", -1))).is_equal(3)
	assert_that(int(m.get("builds", -1))).is_equal(2)
	assert_that(int(m.get("recruits", -1))).is_equal(1)
	assert_that(int(m.get("battles", -1))).is_equal(4)
	assert_that(int(m.get("losses", -1))).is_equal(1)
	# Базовая политика не торгуется (сделку совершает TraderRole). Ноль обязан быть
	# напечатан, а не молча отсутствовать: спека требует счётчик завершённой торговли.
	assert_that(int(m.get("trades", -1))).is_equal(0)


func test_recovery_counts_snapshots_where_hp_grew() -> void:
	var snaps: Array = [
		{"turn": 1, "combat_hp": 100},
		{"turn": 2, "combat_hp": 100},
		{"turn": 3, "combat_hp": 90},
		{"turn": 4, "combat_hp": 95},
		{"turn": 5, "combat_hp": 95},
		{"turn": 6, "combat_hp": 99},
	]
	var m: Dictionary = _role().metrics(_pilot(snaps))
	# 100→100 и 95→95 — не восстановление; рост 90→95 и 95→99 — два.
	assert_that(int(m.get("recovery_turns", -1))).is_equal(2)


func test_death_and_survival_come_from_the_game_state() -> void:
	var role := _role()
	var running := _pilot([{"turn": 60, "combat_hp": 80}])
	running._world = _FakeWorld.new({"state": "RUNNING", "end_reason": ""})
	running.hero_death_turn = 12
	running.hero_death_cause = "starvation"
	var m_running: Dictionary = role.metrics(running)
	assert_bool(bool(m_running.get("survived", false))).is_true()
	assert_that(int(m_running.get("death_turn", -1))).is_equal(12)
	assert_that(str(m_running.get("death_cause", ""))).is_equal("starvation")

	var dead := _pilot([{"turn": 41, "combat_hp": 0}])
	dead._world = _FakeWorld.new({"state": "DEFEAT", "end_reason": "unsuccessored_death"})
	assert_bool(bool(role.metrics(dead).get("survived", true))).is_false() \
		.override_failure_message("DEFEAT не может читаться как выживание")


func test_successions_are_read_from_the_game_session() -> void:
	var pilot := _pilot([{"turn": 60, "combat_hp": 80}])
	var world := _FakeWorld.new({"state": "RUNNING", "end_reason": ""})
	world.session.successions = 2
	pilot._world = world
	# Второй копии счёта в пилоте нет: при расхождении должно быть понятно, кому верить.
	assert_that(int(_role().metrics(pilot).get("successions", -1))).is_equal(2)


func test_metrics_survive_a_pilot_without_a_world() -> void:
	var m: Dictionary = _role().metrics(_pilot([]))
	assert_that(int(m.get("turns_alive", -1))).is_equal(COHORT_TURNS)
	assert_that(int(m.get("successions", -1))).is_equal(0)
	assert_that(int(m.get("recovery_turns", -1))).is_equal(0)
	assert_bool(bool(m.get("survived", false))).is_true() \
		.override_failure_message("мира нет — DEFEAT не наступал; молчаливый false выдал бы техсбой за гибель")


class _FakeSurvivalPilot extends Node:
	var snapshots: Array = []
	var turn := 0
	var extracted_nodes := 0
	var builds_done := 0
	var recruits_done := 0
	var battles_fought := 0
	var losses := 0
	var hero_death_turn := -1
	var hero_death_cause := ""
	var _world = null


class _FakeSession extends RefCounted:
	var successions := 0


class _FakeWorld extends RefCounted:
	var endgame: Dictionary = {}
	var session := _FakeSession.new()

	func _init(p_endgame: Dictionary) -> void:
		endgame = p_endgame

	func get_endgame_state() -> Dictionary:
		return endgame

	func get_session() -> Variant:
		return session
