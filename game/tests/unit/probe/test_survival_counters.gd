extends BaseTest

## Счётчики когорты выживания (задачи 7.1/7.3): «фактически выполненное взаимодействие»
## обязано считаться по успешным действиям, а не по первым ходам, и порог когорты
## обязан краснеть на недоборе, а не печатать «ok».
##
## Тесты грузят инструмент напрямую (`load("res://tools/survival_report.gd")`): пороги
## вынесены в static-функцию от данных именно ради того, чтобы мутация
## `survived >= goal` → `true` краснела здесь, а не в ручном прогоне (D-259: «мера без
## читателя — не мера»).

const REPORT_GD := "res://tools/survival_report.gd"
const TARGET := {"survival_goal": 8, "average_turns_goal": 55}


func _screen(build_ok: int, recruit_ok: int) -> _FakeCityScreen:
	var s := _FakeCityScreen.new()
	s.build_ok = build_ok
	s.recruit_ok = recruit_ok
	add_child(s)
	auto_free(s)
	return s


func _probe(screen: _FakeCityScreen) -> BalanceProbe:
	var probe := BalanceProbe.new()
	probe._city_screen = screen
	add_child(probe)
	auto_free(probe)
	return probe


func test_builds_done_counts_only_succesful_builds() -> void:
	var screen := _screen(2, 0)
	var probe := _probe(screen)
	probe.turn = 7

	assert_bool(probe._try_build()).is_true()
	assert_that(probe.builds_done).is_equal(1)
	assert_that(probe.first_building_turn).is_equal(7)

	assert_bool(probe._try_build()).is_true()
	assert_that(probe.builds_done).is_equal(2)
	# Первый ход стройки — это «когда началось», а не «сколько состоялось».
	assert_that(probe.first_building_turn).is_equal(7)

	assert_bool(probe._try_build()).is_false() \
		.override_failure_message("отказ стройки не должен считаться взаимодействием")
	assert_that(probe.builds_done).is_equal(2)


func test_recruits_done_counts_only_succesful_recruits() -> void:
	var screen := _screen(0, 1)
	var probe := _probe(screen)
	probe.turn = 3

	assert_bool(probe._try_recruit()).is_true()
	assert_that(probe.recruits_done).is_equal(1)
	assert_bool(probe._try_recruit()).is_false()
	assert_that(probe.recruits_done).is_equal(1)


func test_pilot_records_the_first_death_and_its_cause() -> void:
	var pilot := ScenarioPilot.new()
	add_child(pilot)
	auto_free(pilot)
	pilot.turn = 41

	GameEventBus.hero_died.emit(&"starvation")
	assert_that(pilot.hero_death_turn).is_equal(41)
	assert_that(pilot.hero_death_cause).is_equal("starvation")

	# Следующая гибель (после наследования) не должна затирать первую причину: отчёт
	# когорты отвечает «от чего умер бег», а не «чем он закончился».
	pilot.turn = 55
	GameEventBus.hero_died.emit(&"battle")
	assert_that(pilot.hero_death_turn).is_equal(41)
	assert_that(pilot.hero_death_cause).is_equal("starvation")


func test_summarize_passes_only_when_both_thresholds_hold() -> void:
	var s: Dictionary = load(REPORT_GD).summarize(_rows(8, 57.0), TARGET)
	assert_bool(bool(s.get("meets_goals", false))).is_true()
	assert_that(int(s.get("survived", -1))).is_equal(8)
	assert_that(int(s.get("runs", -1))).is_equal(10)


func test_summarize_flags_survival_shortfall() -> void:
	var s: Dictionary = load(REPORT_GD).summarize(_rows(7, 57.0), TARGET)
	assert_bool(bool(s.get("meets_goals", true))).is_false() \
		.override_failure_message("7/10 при цели 8/10 — недобор, а не успех")
	assert_that(int(s.get("goal_survived", -1))).is_equal(8)


func test_summarize_flags_average_shortfall() -> void:
	var s: Dictionary = load(REPORT_GD).summarize(_rows(8, 54.0), TARGET)
	assert_bool(bool(s.get("meets_goals", true))).is_false() \
		.override_failure_message("среднее 54 при цели 55 — недобор")


func test_summarize_flags_a_run_without_any_interaction() -> void:
	var rows := _rows(10, 60.0)
	rows[4]["interactions"] = 0
	var s: Dictionary = load(REPORT_GD).summarize(rows, TARGET)
	assert_bool(bool(s.get("meets_goals", true))).is_false() \
		.override_failure_message("прогон без взаимодействия не засчитывается (спека balance-probe)")
	assert_that(str(s.get("no_interaction_seeds", ""))).is_equal("seed-5")
	assert_that(int(s.get("min_interactions", -1))).is_equal(0)


## «Один мир за раз» — механизм, а не аккуратность. Забытый `await` у проверки
## детерминизма (замер 2026-10-26) запускал повтор параллельно: следующий seed поднимал
## свой мир, пока предыдущий прогон ещё шёл, строка прерванного прогона оказывалась
## пустой (её хеш — md5 пустой строки), а вердикт звучал как «seed не детерминирован».
func test_tool_refuses_a_second_run_while_one_is_in_flight() -> void:
	var tool = load(REPORT_GD)
	tool.release_single_run()
	assert_str(tool.claim_single_run(1)).is_empty()
	var second: String = tool.claim_single_run(2)
	assert_bool(second != "").is_true() \
		.override_failure_message("второй прогон при живом первом обязан быть отвергнут")
	assert_that(second).contains("seed=2")
	tool.release_single_run()
	assert_str(tool.claim_single_run(3)).is_empty()
	tool.release_single_run()


## 10 прогонов: `survived` штук дожили до 60, остальные — до 1-го хода; среднее
## подгоняется под `avg` подбором длины выживших.
func _rows(survived: int, avg: float) -> Array:
	var rows: Array = []
	var dead_turns := 1
	var n_dead := 10 - survived
	var need := avg * 10.0 - float(n_dead * dead_turns) - 0.0
	var alive_turns := int(need / float(maxi(1, survived))) if survived > 0 else 0
	for i in 10:
		var alive: bool = i < survived
		rows.append({
			"seed": "seed-%d" % (i + 1),
			"survived": alive,
			"turns": alive_turns if alive else dead_turns,
			"interactions": 3,
		})
	return rows


class _FakeCityScreen extends Node:
	var build_ok := 0
	var recruit_ok := 0

	func build_pressed(_def_id: StringName) -> CityCheck:
		if build_ok > 0:
			build_ok -= 1
			return CityCheck.success({})
		return CityCheck.fail("нет запасов")

	func recruit_pressed() -> CityCheck:
		if recruit_ok > 0:
			recruit_ok -= 1
			return CityCheck.success({})
		return CityCheck.fail("нет запасов")
