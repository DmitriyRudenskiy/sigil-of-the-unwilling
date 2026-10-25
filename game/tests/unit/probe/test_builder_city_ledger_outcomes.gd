extends BaseTest

## Проверки фактических исходов City-реестра у Городостроителя (задача 6.3 цикла
## `scenario-matrix-behavior-reliability`: «добавить тесты фактических City/ledger
## outcomes»). До этого роль проверялась только формой словаря метрик
## (`test_scenario_pilot.gd > test_builder_metrics_shape`): что ключи есть — и ничего
## о том, что цель читается из живого реестра города, а не из счётчика роли, и что
## происходит, когда города у прогона нет вовсе.
##
## Город — настоящий `City` (RefCounted), а не заглушка: предмет теста именно связка
## «поле реестра → цель роли», подмена её фейком ничего бы не проверяла.

func _role() -> ScenarioRole:
	return ScenarioPilot.make_role("builder", ScenarioTargets.role("builder"))


func _city(level: int, buildings: int) -> City:
	var city := City.new()
	city.level = level
	for i in buildings:
		city.buildings.append(UniqueBuilding.new())
	return city


func _pilot(city) -> _FakeBuilderPilot:
	var pilot := _FakeBuilderPilot.new()
	pilot._player_city = city
	add_child(pilot)
	auto_free(pilot)
	return pilot


func test_goal_reads_the_live_city_ledger_not_a_role_counter() -> void:
	var city := _city(1, 0)
	var role := _role()
	var pilot := _pilot(city)

	assert_bool(role.goal_met(pilot)).is_false() \
		.override_failure_message("город 1 уровня без зданий не может быть целью")

	city.level = 2
	assert_bool(role.goal_met(pilot)).is_false() \
		.override_failure_message("уровня 2 мало: зданий в реестре нет")

	city.buildings.append(UniqueBuilding.new())
	assert_bool(role.goal_met(pilot)).is_false() \
		.override_failure_message("одного здания мало при buildings_goal = 2")

	city.buildings.append(UniqueBuilding.new())
	assert_bool(role.goal_met(pilot)).is_true() \
		.override_failure_message("уровень 2 + два здания = цель (носитель ScenarioTargets)")


func test_goal_ignores_population() -> void:
	# ПИН НАХОДКИ (задача 6.3 перечисляет «население ≥8, уровень ≥2, здания ≥2», а
	# `goal_met` смотрит только на уровень и здания): город из 0 резидентов считается
	# достигнутой целью. Если население решат включить в цель, кейс покраснеет.
	var city := _city(2, 2)
	var role := _role()
	var pilot := _pilot(city)

	assert_bool(role.goal_met(pilot)).is_true() \
		.override_failure_message("цель сейчас не включает население — это факт носителя")
	assert_that(int(role.metrics(pilot).get("population", -1))).is_equal(0)
	assert_that(int(role.metrics(pilot).get("population_goal", -1))).is_equal(8)


func test_goal_and_metrics_are_total_without_a_city() -> void:
	# Матрица гоняет роли и на профилях, где город не привязался (`_player_city == null`);
	# падение автопилота в отчёте выглядит как «профиль не дошёл», а не как дефект роли
	# (тот же класс, что D-257: метрика обязана быть тотальной по «города нет»).
	var role := _role()
	var pilot := _pilot(null)

	assert_bool(role.goal_met(pilot)).is_false() \
		.override_failure_message("без города цели быть не может, и падать тоже нельзя")
	var m: Dictionary = role.metrics(pilot)
	assert_that(int(m.get("population", -1))).is_equal(0)
	assert_that(int(m.get("city_level", -1))).is_equal(0)
	assert_that(int(m.get("buildings", -1))).is_equal(0)
	assert_bool(bool(m.has("survived"))).is_true()


func test_metrics_report_the_ledger_not_assumptions() -> void:
	var city := _city(3, 2)
	var role := _role()
	var pilot := _pilot(city)
	var m: Dictionary = role.metrics(pilot)

	assert_that(int(m.get("city_level", -1))).is_equal(city.level)
	assert_that(int(m.get("buildings", -1))).is_equal(city.buildings.size())
	assert_that(int(m.get("population", -999))).is_equal(city.pop_total())
	# Цели эхом берутся из конфига: отчёт обязан показывать те же числа, по которым
	# считается goal_met, иначе «недобор» в матрице считается по одной мере, а цель —
	# по другой (прецедент T-123 про rare_goal).
	assert_that(int(m.get("city_level_goal", -1))).is_equal(2)
	assert_that(int(m.get("buildings_goal", -1))).is_equal(2)
	assert_that(int(m.get("population_goal", -1))).is_equal(8)


func test_missing_target_keys_double_the_goal_silently() -> void:
	# ПИН ХРУПКОСТИ (билет к T-211 того же класса): у `goal_met` значения по умолчанию
	# (здания 4, население 30) отличаются от носителя `ScenarioTargets` (2 и 8). Если
	# ключ из носителя пропадёт, цель станет вдвое выше **молча**, и матрица отчитается
	# недобором там, где ничего не менялось.
	var city := _city(2, 2)
	var role := _role()
	role.target = {}
	var pilot := _pilot(city)

	assert_bool(role.goal_met(pilot)).is_false() \
		.override_failure_message("без ключа носителя цель требует 4 здания — это дефолт кода, а не носитель")
	city.buildings.append(UniqueBuilding.new())
	city.buildings.append(UniqueBuilding.new())
	assert_bool(role.goal_met(pilot)).is_true() \
		.override_failure_message("4 здания — порог дефолта; сам дефолт зафиксирован этим кейсом")
	assert_that(int(role.metrics(pilot).get("population_goal", -1))).is_equal(30)


class _FakeBuilderPilot extends Node:
	## Имя поля реального автопилота: роль читает `_player_city`, и фейк обязан называть
	## его так же, иначе проверка «роль читает живой реестр» проверяла бы пустоту.
	var _player_city = null
	var turn := 1
	var _world = null

	func _city_center() -> Vector2i:
		return Vector2i.ZERO
