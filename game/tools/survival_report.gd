extends SceneTree
## Когорта выживания — воспроизводимый носитель замера задачи 7.1/7.3 цикла
## `scenario-matrix-behavior-reliability`: десять прогонов базового автопилота на
## фиксированном наборе seed с лимитом 60 ходов.
##
## Запуск (headless, без тест-фреймворка):
##   godot --headless --path game -s res://tools/survival_report.gd
##   SURVIVAL_REPEAT=2 godot --headless --path game -s res://tools/survival_report.gd
##
## Почему отдельный инструмент, а режим в `matrix_report.gd`: матрица меряет
## «класс × роль» (5×11, seed = f(класс, роль)), когорта меряет один автопилот на
## десяти картах. У отчётов разные носители строк (`MATRIX|class=…` против
## `SURVIVAL|seed=…`) и разные пороги; склейка двух форм в одном файле означала бы,
## что порог роли и порог когорты можно перепутать строкой.
##
## Пороги (спека `balance-probe`, задача 7.3): выжить до 60-го хода обязано ≥8/10
## прогонов, среднее выживание ≥ 55 ходов, в каждом технически завершённом прогоне —
## хотя бы одно фактически выполненное взаимодействие (сбор/постройка/торговля).
## Недобор — **баланс-предупреждение** (`SURVIVAL-WARNING`), код выхода остаётся 0.
## Технические сбои (`SURVIVAL-ERRORS`, код 1) — только сломанные скрипты/подготовка
## мира: смерть героя и недостижение цели игровые, они не роняют прогон (D-259, D-260).
##
## Seed'ы берутся из носителя `ScenarioTargets.SURVIVAL` (версия 1): литералы, а не
## хеш, иначе когорта пересобиралась бы при каждом изменении списка классов.
##
## ВАЖНО: логика в `_initialize()`, не `_init()` — в `-s`-режиме идентификаторы
## autoload'ов резолвятся только после SceneTree::initialize() (тот же приём, что в
## `matrix_report.gd`); `ScenarioPilot` грузится `load()` по пути, потому что его скрипт
## ссылается на `Services`.

const WORLD_SCENE := "res://scenes/archive/world.tscn"
const SCENARIO_PILOT_GD := "res://scripts/probe/ScenarioPilot.gd"
const PILOT_SCENE := "res://scenes/probe/ScenarioPilot.tscn"
const FRAME_CAP := 30000
const ROLE_ID := "survival"

## Повторный прогон того же seed (задача 7.3 «проверить точное повторение каждого
## seed»). Как и в матрице, сравнение — по напечатанной строке целиком: печатается
## именно она, и именно её переносят в `tasks.md`. Повторы в сводку не входят.
var REPEAT := maxi(1, int(OS.get_environment("SURVIVAL_REPEAT")))

## `SURVIVAL_SEEDS=907,4517` — подмножество seed для дорогих экспериментов (teardown,
## сталлы боя). Носителем набора остаётся `ScenarioTargets.SURVIVAL`; переопределение
## видно из стартовой строки по полю `subset=`.
## `SURVIVAL_TRACE=1` — перед каждым прогоном и после teardown печатает состав `root`.
## Прошлое прогона под root — не «мусор на экране», а второй живой мир (замер 2026-10-26:
## после 60-ходового прогона под root переживали teardown `World`, `DestMarker` и анонимный
## `@Node2D@…`), и следующий профиль того же seed мерился уже в другом процессе по составу.
## Тот же класс дефекта, что D-255 (узел, переживший владельца), поэтому инструмент не
## положится на аккуратность игры: перед каждым прогоном он снимает с root всё, что не
## является автозагрузкой, и печатает снесённое (`SURVIVAL-SWEEP`) — молча подчищать значит
## прятать наблюдаемый дефект.
var SEED_SUBSET := OS.get_environment("SURVIVAL_SEEDS")
var TRACE := OS.get_environment("SURVIVAL_TRACE") == "1"
## Снимок узла-автозагрузки на старте: всё, что появилось под root позже, принадлежит
## прогонам, а не проекту.
var _autoloads: Array[String] = []

var _rows: Array[Dictionary] = []


func _initialize() -> void:
	OS.set_environment("MCP_TEST", "1")  # иначе мир сам завершит процесс через 1 с
	for _warmup in 5:
		await process_frame
	for c in root.get_children():
		_autoloads.append(str(c.name))
	var seeds: Array = ScenarioTargets.survival_seeds()
	if SEED_SUBSET != "":
		seeds = []
		for raw in SEED_SUBSET.split(","):
			if str(raw).strip_edges() != "":
				seeds.append(int(str(raw).strip_edges()))
	var turns: int = ScenarioTargets.survival_turns()
	var class_id: String = ScenarioTargets.survival_class()
	var target: Dictionary = ScenarioTargets.role(ROLE_ID)
	if seeds.is_empty():
		print("SURVIVAL-ERRORS|n=1|прогон=носитель|ScenarioTargets.SURVIVAL.seeds пуст")
		quit(2)
		return
	print("SURVIVAL-START|version=%s|seeds=%d|turns=%d|class=%s%s" % [
		str(target.get("version", "?")), seeds.size(), turns, class_id,
		"|subset=" + SEED_SUBSET if SEED_SUBSET != "" else ""])
	var broken: Array[String] = []
	for seed_value in seeds:
		_trace("pre", int(seed_value))
		var row := await _run_profile(int(seed_value), turns, class_id)
		print("SURVIVAL|" + _row_to_line(row))
		_rows.append(row)
		if str(row.get("error", "")) != "":
			broken.append("%d(%s)" % [int(seed_value), row.error])
		if REPEAT > 1:
			await _determinism_check(int(seed_value), turns, class_id, row)
	var summary := _summarize(target)
	print("SURVIVAL-SUMMARY|" + _row_to_line(summary))
	if not broken.is_empty():
		print("SURVIVAL-ERRORS|n=%d|seeds=%s" % [broken.size(), ",".join(broken)])
		quit(1)
		return
	if not bool(summary.get("meets_goals", true)):
		# Игровой недобор: отчёт обязан быть видимым, но не техническим падением.
		print("SURVIVAL-WARNING|выживание %d/%d при цели %d, среднее %.1f хода(ов) при цели %d" % [
			int(summary.get("survived", 0)), int(summary.get("runs", 0)),
			int(summary.get("goal_survived", 0)), float(summary.get("avg_turns", 0.0)),
			int(summary.get("goal_avg_turns", 0))])
	quit(0)


## Инвариант «один мир за раз» — механизмом, а не аккуратностью. Забытый `await` у
## проверки детерминизма (замер 2026-10-26) давал ровно обратное: `_determinism_check`
## уходил в параллель, следующий seed стартовал живым миром раньше, чем предыдущий
## прогон завершился, строка прерванного прогона оказывалась пустой (её хеш — md5 пустой
## строки `d41d8cd9…`), а «повтор того же seed» расходился. В матрице тот `await` стоит,
## поэтому её 22/22 совпадений остаются в силе.
static var _run_in_flight := false


static func claim_single_run(seed_value: int) -> String:
	if _run_in_flight:
		return "прогон seed=%d начат до конца предыдущего: два мира в одном процессе " % seed_value \
			+ "двигают общий RNG и друг друга"
	_run_in_flight = true
	return ""


static func release_single_run() -> void:
	_run_in_flight = false


## Обёртка, а не «внутренность»: захват обязан случиться до создания мира, а снятие —
## на любом выходе.
func _run_profile(seed_value: int, turns: int, class_id: String) -> Dictionary:
	var clash := claim_single_run(seed_value)
	if clash != "":
		push_error(clash)
		var broken := _empty_row(seed_value)
		broken.error = clash
		return broken
	var row := await _run_one(seed_value, turns, class_id)
	release_single_run()
	return row


func _empty_row(seed_value: int) -> Dictionary:
	return {
		"seed": seed_value, "turns": -1, "done": false, "error": "",
		"state": "?", "reason": "", "survived": false,
		"death_turn": -1, "death_cause": "", "successions": 0,
		"gathers": 0, "builds": 0, "recruits": 0, "trades": 0, "interactions": 0,
		"battles": 0, "losses": 0, "recovery_turns": 0, "hostility": 0.0,
	}


func _run_one(seed_value: int, turns: int, class_id: String) -> Dictionary:
	_sweep(seed_value)
	var row := _empty_row(seed_value)
	var pilot_tool = load(SCENARIO_PILOT_GD)  # без типизации: static-вызов динамическим
	var prep: Dictionary = pilot_tool.call("prepare_world", seed_value, class_id)
	if prep.get("status") != "prepared":
		row.error = "prepare_world: %s" % str(prep.get("error", "?"))
		return row
	var world: Node = load(WORLD_SCENE).instantiate()
	root.add_child(world)
	for _i in 40:
		await process_frame
		if world.get_hero() != null and world.get_map_gen() != null:
			break
	var pilot: Node = load(PILOT_SCENE).instantiate()
	root.add_child(pilot)
	var started: Dictionary = pilot.start_scenario(world, seed_value, ROLE_ID, class_id)
	if started.get("status") != "scenario_started":
		row.error = "start_scenario: %s" % str(started.get("error", "?"))
		pilot.queue_free()
		world.queue_free()
		await _teardown()
		return row
	pilot.max_turns = turns
	for _frame in FRAME_CAP:
		if pilot.done or not is_instance_valid(pilot._hero):
			break
		await process_frame
	var rep: Dictionary = pilot.report()
	var metrics: Dictionary = rep.get("role_metrics", {})
	var endgame: Dictionary = rep.get("endgame", {})
	row.turns = int(rep.get("turns", -1))
	row.done = bool(rep.get("done", false))
	row.error = str(rep.get("error", ""))
	row.state = str(endgame.get("state", "?"))
	row.reason = str(endgame.get("end_reason", ""))
	row.survived = bool(metrics.get("survived", false))
	row.death_turn = int(metrics.get("death_turn", -1))
	row.death_cause = str(metrics.get("death_cause", ""))
	row.successions = int(rep.get("successions", 0))
	row.gathers = int(metrics.get("gathers", 0))
	row.builds = int(metrics.get("builds", 0))
	row.recruits = int(metrics.get("recruits", 0))
	row.trades = int(metrics.get("trades", 0))
	# «Фактически выполненное взаимодействие» по спеке = сбор/постройка/торговля.
	# Рекрутка в список не входит и печатается отдельным полем.
	row.interactions = int(row.gathers) + int(row.builds) + int(row.trades)
	row.battles = int(metrics.get("battles", 0))
	row.losses = int(metrics.get("losses", 0))
	row.recovery_turns = int(metrics.get("recovery_turns", 0))
	row.hostility = float(metrics.get("hostility", 0.0))
	pilot.queue_free()
	world.queue_free()
	await _teardown()
	_trace("post", seed_value)
	return row


## Два кадра, а не один: `queue_free` исполняется по концу кадра, и следующий мир,
## созданный через один кадр, застаёт предыдущий живым — тот успевает двинуть свой ход
## вместе с глобальным RNG, и «тот же seed» перестаёт быть тем же seed'ом. Матрица
## платила за это тем же классом дефекта (D-255: узел, переживший свой мир).
func _teardown() -> void:
	await process_frame
	await process_frame


## Состав `root` до прогона и после teardown (только с `SURVIVAL_TRACE=1`).
func _trace(stage: String, seed_value: int) -> void:
	if not TRACE:
		return
	var kids: Array[String] = []
	for c in root.get_children():
		kids.append(str(c.name))
	print("SURVIVAL-TRACE|stage=%s|seed=%d|root_children=%d|%s" % [
		stage, seed_value, kids.size(), ",".join(kids)])


## Снять с root всё, что оставил предыдущий прогон. Узлы снимаются `remove_child` +
## `free` (не `queue_free`): к следующему кадру под root не должно остаться ничего,
## что двигает мир, — иначе «повтор того же seed» проверяется в процессе, состав
## которого каждый раз новый.
func _sweep(seed_value: int) -> void:
	var swept: Array[String] = []
	for c in root.get_children():
		if str(c.name) in _autoloads or not is_instance_valid(c):
			continue
		swept.append(str(c.name))
		root.remove_child(c)
		c.free()
	if not swept.is_empty():
		print("SURVIVAL-SWEEP|seed=%d|swept=%d|%s" % [
			seed_value, swept.size(), ",".join(swept)])


func _determinism_check(seed_value: int, turns: int, class_id: String, first: Dictionary) -> void:
	var base := _row_to_line(first)
	var hashes: PackedStringArray = PackedStringArray([base.md5_text().substr(0, 8)])
	var same := true
	for n in REPEAT - 1:
		var again := await _run_profile(seed_value, turns, class_id)
		var line := _row_to_line(again)
		hashes.append(line.md5_text().substr(0, 8))
		if line != base:
			same = false
			print("SURVIVAL-DIFF|seed=%d|run=%d" % [seed_value, n + 2])
			print("SURVIVAL-ROW-A|" + base)
			print("SURVIVAL-ROW-B|" + line)
	print("SURVIVAL-DETERMINISM|seed=%d|runs=%d|same=%s|hashes=%s" % [
		seed_value, REPEAT, str(same), ",".join(hashes)])


func _summarize(target: Dictionary) -> Dictionary:
	return summarize(_rows, target)


## Пороги когорты (задача 7.3) вынесены в static-функцию от чистых данных: иначе
## «недобор обязан быть виден» проверялось бы только глазами по строке запуска,
## а мутация `survived >= goal` → `true` краснела бы только на ручном прогоне.
## Вызов — `load("res://tools/survival_report.gd").summarize(...)`.
static func summarize(rows: Array, target: Dictionary) -> Dictionary:
	var runs := rows.size()
	var survived := 0
	var turn_sum := 0
	var min_interactions := 999999
	var no_interaction_seeds: Array[String] = []
	for r in rows:
		if bool(r.get("survived", false)):
			survived += 1
		turn_sum += int(r.get("turns", 0))
		var inter: int = int(r.get("interactions", 0))
		min_interactions = mini(min_interactions, inter)
		if inter == 0:
			no_interaction_seeds.append(str(r.get("seed", "?")))
	var avg := float(turn_sum) / float(maxi(1, runs))
	var goal_survived := int(target.get("survival_goal", 8))
	var goal_avg := int(target.get("average_turns_goal", 55))
	var s := {
		"runs": runs,
		"survived": survived,
		"avg_turns": avg,
		"goal_survived": goal_survived,
		"goal_avg_turns": goal_avg,
		"min_interactions": 0 if min_interactions == 999999 else min_interactions,
		"no_interaction_seeds": ",".join(no_interaction_seeds),
	}
	s["meets_goals"] = bool(
		survived >= goal_survived
		and avg >= float(goal_avg)
		and no_interaction_seeds.is_empty())
	return s


func _row_to_line(row: Dictionary) -> String:
	var keys: Array = row.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%s" % [str(k), str(row[k])])
	return "|".join(parts)
