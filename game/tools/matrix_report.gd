extends SceneTree
## Отчёт по матрице «класс × роль» — воспроизводимый носитель замеров цикла
## `scenario-matrix-behavior-reliability` (задачи 9.2 «семь exhaustion-смертельных
## профилей Торговца» и 2.4 «оборот при неизменной gold_goal=1000»).
##
## Запуск (headless, без тест-фреймворка):
##   godot --headless --path game -s res://tools/matrix_report.gd -- <role> [turns] [class,...]
##   godot --headless --path game -s res://tools/matrix_report.gd -- trader 90
##   godot --headless --path game -s res://tools/matrix_report.gd -- trader 90 druid,fighter
## Трасса медленных ходов (для ячеек, упирающихся в предохранитель): `MATRIX_TRACE=1`
##
## Флаг MCP_TEST инструмент ставит сам: `WorldSaveLoadService.handle_headless_exit()`
## при headless и НЕ-тестовом запуске завершает процесс через секунду — живой игре это
## правильно, автопрогону нельзя. `Platform.is_test_framework_run()` читает ту же
## переменную в рантайме, поэтому установки из `_initialize()` хватает.
##
## Печатает по строке на класс (`MATRIX|key=value|...`) и строку `MATRIX-SUMMARY|...`.
## Числа из этих строк переносится в `openspec/.../tasks.md` и в отчёт цикла, поэтому
## инструмент коммитится: локальные прогоны вне git — не хранилище (D-192).
##
## Почему один процесс на всю матрицу: раньше второй world-профиль того же процесса
## зависал на осиротевшем узле `Battle` под root и матрицу приходилось резать на
## батчи по одному профилю (**T-204**, фикс владения — D-255). Порядок классов фиксирован
## (`HeroClasses.CLASSES` отсортирован), чтобы отчёт повторялся байт в байт.
##
## ВАЖНО: логика в `_initialize()`, не `_init()` — в `-s`-режиме autoload-
## идентификаторы резолвятся только после SceneTree::initialize() (тот же приём,
## что в `tools/diag_biome_resources.gd`).

const WORLD_SCENE := "res://scenes/archive/world.tscn"
## `ScenarioPilot` грузится в рантайме, а не через `class_name`: скрипт ссылается на
## autoload `Services`, а скрипт инструмента компилируется на старте — до регистрации
## autoload'ов (тот же приём и та же ловушка, что в `tools/diag_biome_resources.gd`).
const SCENARIO_PILOT_GD := "res://scripts/probe/ScenarioPilot.gd"
const PILOT_SCENE := "res://scenes/probe/ScenarioPilot.tscn"
const FRAME_CAP := 30000
const DEFAULT_TURNS := 90
## Порог «медленного хода» для трассы (`MATRIX_TRACE=1`): на здоровых профилях ход
## укладывается в ~330 кадров, а ячейка Ranger/Trader (2026-10-25) жигала по 1500.
## Трасса печатает только превысившие ходы — по ней и ищутся ячейки, упирающиеся в
## предохранитель FRAME_CAP (неполные прогоны 9.3).
const SLOW_TURN_FRAMES := 400

var _rows: Array[Dictionary] = []


func _initialize() -> void:
	OS.set_environment("MCP_TEST", "1")  # см. шапку: иначе мир сам убьёт процесс через 1 с
	# `_initialize()` отрабатывает до первого кадра, а реестр `Services` наполняется в
	# `_ready()` автозагрузок: без кадра-двух `Services.resolve(&"persistence")` пустой,
	# и `prepare_world` отвечает «persistence не найден».
	for _warmup in 5:
		await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("MATRIX-ERROR|нужен роль-аргумент: -- <role> [turns] [class,...]")
		quit(2)
		return
	var role_id := args[0]
	var turns := DEFAULT_TURNS
	if args.size() > 1:
		turns = maxi(1, int(args[1]))
	var classes: Array = HeroClasses.CLASSES.keys()
	classes.sort()
	if args.size() > 2:
		classes = Array(args[2].split(","))
	print("MATRIX-START|role=%s|turns=%d|classes=%d" % [role_id, turns, classes.size()])
	for class_id in classes:
		var row := await _run_profile(role_id, class_id, turns)
		print("MATRIX|" + _row_to_line(row))
	print("MATRIX-SUMMARY|" + _row_to_line(_summarize(role_id, turns)))
	quit(0)


func _run_profile(role_id: String, class_id: String, turns: int) -> Dictionary:
	var seed_value: int = ScenarioTargets.seed_for(class_id, role_id)
	var row := {"class": class_id, "seed": seed_value, "turns": -1, "done": false,
		"error": "", "deals": 0, "gold": 0, "margin": 0, "market": false,
		"attempts": 0, "block": "", "battles": 0, "state": "?", "reason": "", "survived": false}
	var pilot_tool = load(SCENARIO_PILOT_GD)  # без типизации: static-вызов динамическим вызовом
	var prep: Dictionary = pilot_tool.call("prepare_world", seed_value, class_id)
	if prep.get("status") != "prepared":
		row.error = str(prep.get("error", "?"))
		return row
	var world: Node = load(WORLD_SCENE).instantiate()
	root.add_child(world)
	for _i in 40:
		await process_frame
		if world.get_hero() != null and world.get_map_gen() != null:
			break
	var pilot: Node = load(PILOT_SCENE).instantiate()
	root.add_child(pilot)
	var started: Dictionary = pilot.start_scenario(world, seed_value, role_id, class_id)
	if started.get("status") != "scenario_started":
		row.error = str(started.get("error", "?"))
		pilot.queue_free()
		world.queue_free()
		await process_frame
		return row
	pilot.max_turns = turns
	var trace := OS.get_environment("MATRIX_TRACE") != ""
	var last_turn := int(pilot.turn)
	var frames_this_turn := 0
	var battles_at_turn_start := 0
	for _frame in FRAME_CAP:
		if pilot.done or not is_instance_valid(pilot._hero):
			break
		await process_frame
		frames_this_turn += 1
		if trace and frames_this_turn % 1000 == 0:
			print("MATRIX-BEAT|" + _row_to_line(_battle_beat(class_id, last_turn, frames_this_turn, pilot)))
			print("MATRIX-BURST|class=%s|%s" % [class_id, await _burst(pilot)])
		if int(pilot.turn) != last_turn:
			if trace and frames_this_turn > SLOW_TURN_FRAMES:
				print("MATRIX-SLOW|class=%s|turn=%d|frames=%d|cell=%s|battles=%d|stuck=%d" % [
					class_id, last_turn, frames_this_turn, str(pilot._hero_cell()),
					int(pilot.battles_fought) - battles_at_turn_start, int(pilot.stuck)])
			last_turn = int(pilot.turn)
			frames_this_turn = 0
			battles_at_turn_start = int(pilot.battles_fought)
	if trace and frames_this_turn > SLOW_TURN_FRAMES:
		print("MATRIX-SLOW|class=%s|turn=%d|frames=%d|cell=%s|battles=%d|stuck=%d|unfinished=true" % [
			class_id, last_turn, frames_this_turn, str(pilot._hero_cell()),
			int(pilot.battles_fought) - battles_at_turn_start, int(pilot.stuck)])
	var metrics: Dictionary = pilot.role.metrics(pilot)
	var endgame: Dictionary = world.get_endgame_state()
	row.turns = int(pilot.turn)
	row.done = bool(pilot.done)
	row.error = str(pilot.error_msg)
	row.deals = int(metrics.get("deals", 0))
	row.gold = int(metrics.get("gold", 0))
	row.margin = int(metrics.get("margin", 0))
	row.market = bool(metrics.get("market_available", false))
	row.attempts = int(metrics.get("market_build_attempts", -1))
	row.block = str(metrics.get("market_build_block_reason", ""))
	row.battles = int(pilot.battles_fought)
	row.state = str(endgame.get("state", "?"))
	row.reason = str(endgame.get("end_reason", ""))
	row.survived = bool(metrics.get("survived", false))
	_rows.append(row)
	# Тот же порядок, что в тестах: сначала владельцы пилота и мира снимаются, затем
	# два кадра на освобождение — следующий профиль не должен застать живые узлы.
	pilot.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	return row


## Сердцебиение медленного хода: где именно горят кадры — в бою (и на каком юните),
## в пути или в самом шаге политика. Показывается раз в 1000 кадров внутри хода.
func _battle_beat(class_id: String, turn_number: int, frames: int, pilot: Node) -> Dictionary:
	var b: Node = root.get_node_or_null("Battle")
	var bs = null
	var out := {"class": class_id, "turn": turn_number, "frames": frames,
		"battle": "none", "over": "", "idx": "", "unit": "", "left": "", "cell": "",
		"player": "", "timer": "", "queue": "", "attacked": "", "wait_req": ""}
	if b != null and b.has_method("get_battle_state"):
		bs = b.get_battle_state()
		out.battle = "node"
		if bs != null:
			out.over = str(bs.battle_over)
			out.idx = str(bs.turn_idx)
			out.left = "%.1f" % float(bs.turn_time_left)
			out.player = str(bs.is_player_turn)
			out.timer = str(bs.turn_timer_running)
			out.queue = str(bs.turn_queue.size())
			var u = bs.active_unit
			out.unit = "none" if u == null else "%s alive=%s moved=%s uid=%d cell=%s" % [
				str(u.side), str(u.is_alive()), str(u.get("has_moved")), int(u.uid), str(u.cell)]
			if u != null:
				out.attacked = str(u.get("has_attacked"))
	# Состояние исполнителя решает, кто именно стоит: WAITING_INPUT (3-й член
	# enum'а State = 2) с неотработанной политикой автоигрока или ANIMATING/TURN_START
	# с незавершённым await. Плюс вооружён ли часы хода и не стоит ли дерево на паузе
	# (Timer-узлы на дереве под паузой не тикают).
	var ex: Node = b.get_node_or_null("BattleTurnExecutor")
	if ex != null:
		out.player = "%s state=%s armed=%s" % [str(bs.is_player_turn) if bs != null else "",
			"%s paused=%s token=%s" % [str(ex.get_current_state()), str(ex.get("_paused")),
				str(ex.get("_pause_token"))], str(ex.is_turn_timer_armed())]
		var timers := 0
		for t in _collect_timers(ex):
			if not t.stopped:
				timers += 1
		var cs = b.get("_state")
		out.wait_req = "ctrl_proc=%s ctrl_state_same=%s ex_bs_same=%s exec_null=%s" % [
			str(b.is_processing()), str(cs == bs),
			str(ex.get("_battle_state") == bs), str(ex == null)]
	if pilot._hero != null and is_instance_valid(pilot._hero):
		out.cell = str(pilot._hero_cell())
	out.timer = "%s stall=%d/%s proc=%s" % [str(bs.turn_timer_running) if bs != null else "",
		int(pilot.get("_battle_stall_frames")), str(pilot.get("_battle_stall_key")),
		str(pilot.is_processing())]
	return out


## 12 кадров подряд: кто реально активен и каким объектом боя — когда ключ
## сталла «меняется каждый кадр», по этому следу видно, чередуются ли юниты или
## живут два BattleState.
func _burst(pilot: Node) -> String:
	var out := ""
	for i in 12:
		await process_frame
		var b: Node = root.get_node_or_null("Battle")
		if b == null or not b.has_method("get_battle_state"):
			out += "none "
			continue
		var bs = b.get_battle_state()
		if bs == null:
			out += "null "
			continue
		var u = bs.active_unit
		out += "%d:%d/%d:%d " % [bs.get_instance_id() % 100000, int(bs.turn_idx),
			0 if u == null else int(u.uid), 0 if u == null else int(_battles_fought(pilot))]
	return out.strip_edges()


func _battles_fought(pilot: Node) -> int:
	return int(pilot.battles_fought)


func _collect_timers(node: Node) -> Array[Timer]:
	var out: Array[Timer] = []
	for child in node.get_children():
		if child is Timer:
			out.append(child)
		out.append_array(_collect_timers(child))
	return out


func _summarize(role_id: String, turns: int) -> Dictionary:
	var s := {"class": "SUMMARY", "role": role_id, "turns": turns, "profiles": _rows.size()}
	var alive := 0
	var deals := 0
	var golds: Array[int] = []
	var margins: Array[int] = []
	for r in _rows:
		if r.survived:
			alive += 1
		deals += r.deals
		golds.append(r.gold)
		margins.append(r.margin)
	golds.sort()
	margins.sort()
	s["survived"] = "%d/%d" % [alive, _rows.size()]
	s["deals"] = deals
	s["gold_median"] = int(golds[golds.size() / 2]) if not golds.is_empty() else 0
	s["gold_max"] = int(golds[golds.size() - 1]) if not golds.is_empty() else 0
	s["margin_median"] = int(margins[margins.size() / 2]) if not margins.is_empty() else 0
	s["gold_goal_reached"] = "%d/%d" % [int(golds.filter(func(g) -> bool: return g >= 1000).size()), _rows.size()]
	return s


func _row_to_line(row: Dictionary) -> String:
	var keys := row.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%s" % [k, str(row[k])])
	return "|".join(parts)
