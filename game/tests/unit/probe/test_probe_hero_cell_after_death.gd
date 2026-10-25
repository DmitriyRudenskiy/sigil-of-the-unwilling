extends BaseTest

# T-207: `_hero_cell()` на освобождённом герое ронял процесс (SIGSEGV), а не возвращал
# «героя нет».
#
# Как это выглядело (матричный прогон `traveler 90`, 2026-10-26, `mx_traveler.log`):
# после второй строки матрицы Godot падал с `handle_crash: Program crashed with signal 11`,
# бэктрейс `balance_probe.gd:669 _hero_cell ← TravelerRole.gd:65 goal_met ←
# TravelerRole.gd:68 metrics ← matrix_report.gd:133`. Профиль уже завершился
# (`_process` видит невалидного героя и делает `_finish()`), но **отчёт матрицы читает
# метрики после конца прогона** — и чтение `_hero.get_component(...)` с освобождённого
# экземпляра не имеет право на существование. Из-за падения процесса матрица не досчиталась
# девяти классов Traveler, а ячейки Traveler/Druid и Traveler/Chanter из задачи 9.3 годами
# выглядели «неполными».
#
# Почему страж возвращает `(-1, -1)`, а не `Vector2i.ZERO`: ноль — настоящая клетка карты,
# и `TravelerRole.goal_met()` (`_hero_cell() == _target`) объявлял бы прибытие в стартовую
# точку. `(-1, -1)` — уже используемый в ролях страж «цели нет» (`_target == (-1, -1)`),
# поэтому `goal_met()` лжёт в меньшую сторону по построению.
#
# Гард берёг бы и AdventurerRole: он единственный проверял `is_instance_valid` (строка 91),
# остальные роли читали `pilot._hero` вслепую. Кейс 6 — про TravelerRole как реального
# потребителя стража: `metrics()` обязан отдавать «не дошёл, 0 HP, 0 дистанции» вместо
# падения.


const _PROBE := "res://scripts/probe/balance_probe.gd"


class HeroStub extends Node:
	## Движение — тот же узел: `get_component("Movement")` в герое возвращает компонент по
	## имени, тесту достаточно отдать себя.
	var cell := Vector2i(7, -3)

	func get_component(_component: String) -> Node:
		return self

	func get_current_cell() -> Vector2i:
		return cell


class HeroWithoutMovement extends Node:
	## Герой без движения: компонент не найден, но герой — живой.
	func get_component(_component: String) -> Node:
		return null


func _probe() -> Node:
	var probe: Node = make_node(load(_PROBE))
	add_child(probe)
	return probe


## 1. Героя не было никогда — «клетки нет», а не «клетка (0,0)».
func test_missing_hero_has_no_cell() -> void:
	var probe := _probe()
	probe._hero = null
	assert_bool(probe._hero_cell() == Vector2i(-1, -1)).is_true().override_failure_message(
		"без героя `_hero_cell()` обязан возвращать страж (-1,-1), иначе goal_met путает «нет героя» с «прибыл»"
	)


## 2. Живой герой: страж не должен съедать нормальный путь — иначе он «всегда страж».
func test_alive_hero_reports_its_cell() -> void:
	var probe := _probe()
	var hero := HeroStub.new()
	add_child(hero)
	probe._hero = hero
	assert_bool(probe._hero_cell() == Vector2i(7, -3)).is_true().override_failure_message(
		"живой герой теряет клетку: страж стал вместо чтения"
	)


## 3. Освобождённый герой — то, на чём процесс падал.
func test_freed_hero_has_no_cell() -> void:
	var probe := _probe()
	var hero := HeroStub.new()
	add_child(hero)
	probe._hero = hero
	var cell_before: Vector2i = probe._hero_cell()
	assert_bool(cell_before == Vector2i(7, -3)).is_true()
	hero.free()
	assert_bool(probe._hero_cell() == Vector2i(-1, -1)).is_true().override_failure_message(
		"освобождённый герой обязан читаться как «героя нет», а не падать в get_component"
	)


## 4. Роль не объявляет прибытие без героя: цель существует, героя нет.
func test_traveler_role_does_not_claim_arrival_without_hero() -> void:
	var probe := _probe()
	var hero := HeroStub.new()
	add_child(hero)
	probe._hero = hero
	hero.free()
	var role := TravelerRole.new()
	role._target = Vector2i(3, 4)
	role._start = Vector2i(0, 0)
	assert_bool(role.goal_met(probe)).is_false().override_failure_message(
		"без героя прибытие недостижимо: страж (-1,-1) не равен ни одной цели"
	)


## 5. Метрики после конца прогона: ноль вместо падения процесса.
func test_traveler_role_metrics_survive_dead_hero() -> void:
	var probe := _probe()
	var hero := HeroStub.new()
	add_child(hero)
	probe._hero = hero
	hero.free()
	var role := TravelerRole.new()
	role._target = Vector2i(3, 4)
	role._start = Vector2i(1, 1)
	var metrics: Dictionary = role.metrics(probe)
	assert_bool(bool(metrics.get("arrived", true))).is_false()
	assert_int(int(metrics.get("hp", -1))).is_equal(0)
	assert_int(int(metrics.get("distance", -1))).is_equal(0)


## 6. Отрицательный контроль к кейсу 2: тот же герой, но без компонента движения, — это
# «клетки нет» по-старому (ZERO), и он отличается от стража «героя нет». Два разных
# отсутствия читаются по-разному иначе кейс 1 неотличим от регресса в Movement.
func test_hero_without_movement_differs_from_no_hero() -> void:
	var probe := _probe()
	var hero := HeroWithoutMovement.new()
	add_child(hero)
	probe._hero = hero
	assert_bool(probe._hero_cell() == Vector2i.ZERO).is_true().override_failure_message(
		"герой без Movement исторически даёт (0,0) — это не тот случай, что «героя нет»"
	)
