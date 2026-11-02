extends SceneTree

## `diag_hero_needs.gd` — почему герой умер от потребности (T-321).
##
## Матричный отчёт (`tools/matrix_report.gd`) говорит «что»: `reason=unsuccessored_death`.
## Этот инструмент говорит «почему»: гоняет одну ячейку роли и печатает бюджет REST —
## сколько ходов герой простоял в городе (+рекорвери), сколько раз добыл ресурс
## (−`ExtractRules.rest_cost`) и куда за ход сместилась шкала. Без этих чисел
## «герой переволнулся» и «герою не хватило удачи в маршруте» неразличимы.
##
## Запуск (из `game/`):
##     godot --headless --path . -s res://tools/diag_hero_needs.gd
##     DIAG_ROLE=builder DIAG_CLASS=rogue DIAG_TURNS=90 DIAG_VERBOSE=1 … — то же с трассой
##
## Строки: `NEEDS|…` — конфиг и итог, `NEEDS-TURN|…` — ход (только с `DIAG_VERBOSE`).
##
## Ловушка, из-за которой инструмент обязан ходить динамическими вызовами: статическая
## ссылка на `LoadCalculator`/`HeroInventory` из `-s`-скрипта тянет компиляцию
## `artifact.gd`, а там автозагрузка `Services` на момент компиляции не видна — артефакты
## не загружаются (`Invalid call. Nonexistent function 'from_dict'`), и прогон тихо
## становится другим: вместо `unsuccessored_death` на том же seed вышел `total_collapse`.

const WORLD_SCENE := "res://scenes/archive/world.tscn"
const SCENARIO_PILOT_GD := "res://scripts/probe/scenario_pilot.gd"
const PILOT_SCENE := "res://scenes/probe/ScenarioPilot.tscn"
const FRAME_CAP := 30000
## Индекс REST в словаре потребностей (`NeedType.ID.REST`).
const REST := 0

var _role := "builder"
var _cls := "rogue"
var _turns := 90
var _verbose := false

var _extract := 0
var _extract_last := 0
var _ticks := 0
var _in_city_ticks := 0
var _rest_first := -1.0
var _rest_last := -1.0
var _prev_rest := -1.0
var _prev_in_city := false
var _delta_in_sum := 0.0
var _delta_in_n := 0
var _delta_out_sum := 0.0
var _delta_out_n := 0
var _attack := -1


func _on_extracted(_cell, _resource_id, _amount: int) -> void:
	_extract += 1


func _initialize() -> void:
	_role = "builder" if OS.get_environment("DIAG_ROLE") == "" else OS.get_environment("DIAG_ROLE")
	_cls = "rogue" if OS.get_environment("DIAG_CLASS") == "" else OS.get_environment("DIAG_CLASS")
	_turns = 90 if OS.get_environment("DIAG_TURNS") == "" else int(OS.get_environment("DIAG_TURNS"))
	_verbose = OS.get_environment("DIAG_VERBOSE") != ""
	OS.set_environment("MCP_TEST", "1")  # иначе мир сам убьёт процесс через 1 с (см. matrix_report)
	await process_frame
	await process_frame
	var seed_value: int = ScenarioTargets.seed_for(_cls, _role)
	var pilot_tool = load(SCENARIO_PILOT_GD)  # без типизации: static-вызов динамическим
	var prep: Dictionary = pilot_tool.call("prepare_world", seed_value, _cls)
	print("NEEDS|role=%s|class=%s|seed=%d|prepare=%s" % [
		_role, _cls, seed_value, str(prep.get("status", "?"))])
	if prep.get("status") != "prepared":
		quit(1)
		return
	var world: Node = load(WORLD_SCENE).instantiate()
	root.add_child(world)
	for _i in 40:
		await process_frame
		if world.get_hero() != null and world.get_map_gen() != null:
			break
	var pilot: Node = load(PILOT_SCENE).instantiate()
	root.add_child(pilot)
	var started: Dictionary = pilot.start_scenario(world, seed_value, _role, _cls)
	print("NEEDS|start=%s|turns=%d" % [str(started.get("status", "?")), _turns])
	if started.get("status") != "scenario_started":
		quit(1)
		return
	pilot.max_turns = _turns
	# Счётчик добычи: именно она снимает REST вне города, и без её частоты
	# «структурный перекос» неотличим от «не повезло с маршрутом».
	var router: Array[Node] = []
	_collect_signal_host(world, "resource_extracted_at", router)
	if router.is_empty():
		print("NEEDS|router=NOT_FOUND (счётчик добычи молчит)")
	else:
		router[0].connect("resource_extracted_at", _on_extracted)
	var last_turn := int(pilot.turn)
	for _frame in FRAME_CAP:
		if pilot.done or not is_instance_valid(pilot._hero):
			break
		await process_frame
		if int(pilot.turn) != last_turn:
			_snap(pilot)
			last_turn = int(pilot.turn)
	print("NEEDS|end|turn=%d|done=%s" % [int(pilot.turn), str(bool(pilot.done))])
	_snap(pilot, "final")
	var span: int = maxi(1, _ticks)
	print("NEEDS|budget|ticks=%d|in_city=%d(%.0f%%)|extracts=%d|per_turn=%.2f|attack=%d|rest=%.2f→%.3f|drift=%+.4f/ход|Δв_городе=%s|Δвне=%s" % [
		_ticks, _in_city_ticks, 100.0 * float(_in_city_ticks) / float(span), _extract,
		float(_extract) / float(span), _attack, _rest_first, _rest_last,
		(_rest_last - _rest_first) / float(span),
		_mean(_delta_in_sum, _delta_in_n), _mean(_delta_out_sum, _delta_out_n)])
	print("NEEDS|endgame=", str(world.get_endgame_state()))
	quit(0)


func _mean(sum: float, n: int) -> String:
	return "нет данных" if n == 0 else "%+.3f" % (sum / float(n))


func _collect_signal_host(node: Node, sig: String, out: Array[Node]) -> void:
	if node.has_signal(sig):
		out.append(node)
	for c in node.get_children():
		_collect_signal_host(c, sig, out)


func _snap(pilot: Node, tag: String = "") -> void:
	var hero = pilot._hero
	if hero == null or not is_instance_valid(hero):
		print("NEEDS|hero=gone|turn=%d|снимок остановлен (герой умер или сменился)" % int(pilot.turn))
		return
	var needs_txt := "?"
	var needs_comp = hero.get_component("Needs")
	if needs_comp != null:
		var nd: Dictionary = needs_comp.get_needs()
		var rest := float(nd.get(REST, 0.0))
		if _rest_first < 0.0:
			_rest_first = rest
		if _prev_rest >= 0.0:
			if _prev_in_city:
				_delta_in_sum += rest - _prev_rest
				_delta_in_n += 1
			else:
				_delta_out_sum += rest - _prev_rest
				_delta_out_n += 1
		_prev_rest = rest
		_rest_last = rest
		var parts: Array[String] = []
		for k in nd.keys():
			parts.append("%s=%.3f(ноль %d)" % [str(k), float(nd[k]),
				int(needs_comp.needs.zero_streak.get(k, 0))])
		needs_txt = " ".join(parts)
	var cell := "?"
	var mov = hero.get_component("Movement")
	if mov != null:
		cell = str(mov.get_current_cell())
	var pop := -1
	var in_city := false
	if hero.city_manager != null and mov != null:
		var city = hero.city_manager.city_at(mov.get_current_cell())
		in_city = city != null
		if city != null:
			pop = city.pop.size()
	if _attack < 0 and hero.stats != null:
		_attack = int(hero.stats.get("attack", 0))
	_ticks += 1
	if in_city:
		_in_city_ticks += 1
	_prev_in_city = in_city
	var per_turn_extracts := _extract - _extract_last
	_extract_last = _extract
	if not _verbose:
		return
	print("NEEDS-TURN|turn=%d|alive=%s|cell=%s|in_city=%s|pop=%d|battles=%d|extracts=%d|needs %s|%s" % [
		int(pilot.turn), str(bool(hero.is_alive)), cell, str(in_city), pop,
		int(pilot.battles_fought), per_turn_extracts, needs_txt, tag])
	_extract_last = _extract
