class_name BalanceProbe
extends Node
## balance-core: MCP-автопрогонка ранней игры. Автоигрок играет канонический
## ранний цикл (сбор → выгрузка → стройка → рекрутка → бой) и собирает метрики.
## Hard-fail только на техсбоях; пороги метрик → warnings в отчёте.

const MAX_TURNS := 60
const BUILD_QUEUE := [&"barracks", &"market", &"farm", &"range"]
const REPORT_DIR := "user://balance_reports"
const THRESHOLDS := {
	"first_building_turn": 5,
	"first_recruit_turn": 10,
	"first_win_after_collision": 3,
	"losses_total": 1,
	"stuck_max": 3,
}
const MAX_ACTION_RETRIES := 3
## Любая потребность ниже порога → герой идёт на центр города и ждёт там
## реквери (в городе REST +0.26/ход, SOCIAL +0.22/ход — ~5 ходов до 0.5).
const NEED_RETURN_THRESHOLD := 0.5
const CampaignCityBalanceScenario := preload("res://scripts/balance/campaign_city_balance_scenario.gd")
## Враг в этом радиусе от центра города — угроза: герой перехватывает его
## до сбора/боев с другими. Без этого EnemyTurnProcessor захватывает город
## (total_collapse → DEFEAT), пока герой отвлёкся (headless: wizard, ход 15).
const CITY_DEFEND_RADIUS := 6

var seed_value: int = 42
var max_turns: int = MAX_TURNS  # autopilot-scenario-matrix: роль может переопределить
var done := false
var error_msg := ""
var turn := 0
var stuck := 0
var stuck_max_seen := 0
var first_building_turn := -1
var first_recruit_turn := -1
var first_collision_turn := -1
var first_win_turn := -1
var losses := 0
var battles_fought := 0
var _lost_enemy_cells: Dictionary = {}
var snapshots: Array = []
var warnings: Array = []
var campaign_city_report: Dictionary = {}
var _action_fails := 0
var _city_screen: Node = null
var _player_city: Variant = null  # City — RefCounted, не Node

func start_probe(world: Node, p_seed: int) -> Dictionary:
	ProbeFastMode.enabled = true
	seed_value = p_seed
	max_turns = MAX_TURNS
	turn = 0
	stuck = 0
	stuck_max_seen = 0
	first_building_turn = -1
	first_recruit_turn = -1
	first_collision_turn = -1
	first_win_turn = -1
	losses = 0
	battles_fought = 0
	_lost_enemy_cells.clear()
	snapshots = []
	warnings = []
	campaign_city_report = {}
	error_msg = ""
	done = false
	_world = world
	_hero = world.get_hero()
	_spawner = world.get_node_or_null("WorldSpawner")
	_res_chain = world._resource_chain
	var cities: Node = world.get_cities()
	if cities != null and not cities.cities.is_empty():
		_player_city = cities.cities[0]
	_city_screen = preload("res://scenes/ui/city_screen.tscn").instantiate()
	# В дереве, но невидим: _ready пройдёт (иначе get_node вернёт null).
	_city_screen.visible = false
	add_child(_city_screen)
	_city_screen.setup(_player_city, _hero, Vector2i.ZERO)
	if not GameEventBus.battle_won.is_connected(_on_battle_won):
		GameEventBus.battle_won.connect(_on_battle_won)
	if not GameEventBus.battle_lost.is_connected(_on_battle_lost):
		GameEventBus.battle_lost.connect(_on_battle_lost)
	set_process(true)
	return {"status": "probe_started", "turn": 0}

var _world: Node = null
var _hero: Node = null
var _spawner: Node = null
var _res_chain: Variant = null  # ResourceChainService — RefCounted

func _process(_delta: float) -> void:
	if done or _world == null:
		return
	if _hero == null or not is_instance_valid(_hero):
		_finish()
		return
	if _handle_battle():
		return
	if not _world.is_world_visible():
		return
	_step()

func report() -> Dictionary:
	if campaign_city_report.is_empty():
		campaign_city_report = CampaignCityBalanceScenario.run()
	var rep := {
		"seed": seed_value,
		"turns": turn,
		"done": done,
		"error": error_msg,
		"first_building_turn": first_building_turn,
		"first_recruit_turn": first_recruit_turn,
		"first_collision_turn": first_collision_turn,
		"first_win_turn": first_win_turn,
		"losses": losses,
		"battles_fought": battles_fought,
		"stuck_max": stuck_max_seen,
		"thresholds": THRESHOLDS,
		"warnings": warnings,
		"campaign_city": campaign_city_report,
		"season": WorldSeasons.season_name(),
		"endgame": _world.get_endgame_state() if _world != null else {},
		"snapshots": snapshots,
	}
	return rep

# ── Бой: один авто-действие за кадр (паттерн test_battle_full_e2e) ──────────
func _handle_battle() -> bool:
	var b: Node = get_tree().root.get_node_or_null("Battle")
	if b == null or not b.has_method("get_battle_state"):
		return false
	var bs = b.get_battle_state()
	if bs == null or bs.battle_over:
		battles_fought += 1
		return true
	if first_collision_turn < 0:
		first_collision_turn = turn
	var unit = bs.active_unit
	if unit == null or not unit.is_alive():
		return true
	var executor: Node = b.get_node_or_null("BattleTurnExecutor")
	if executor == null:
		return true
	var enemy_side = BattleState.Side.DEFENDER if unit.side == BattleState.Side.ATTACKER else BattleState.Side.ATTACKER
	var enemy_units = bs.get_units_by_side(enemy_side)
	# 1) атака ближайшего в радиусе (ближний — сосед, дальнобойный — любой)
	var target = null
	var best := INF
	for e in enemy_units:
		if not e.is_alive():
			continue
		var d := HexUtils.hex_distance(unit.cell, e.cell, bs.hex_shift_right)
		if unit.is_ranged():
			if d > 1 and d < best:
				best = d
				target = e
		elif d == 1 and target == null:
			target = e
	if target != null:
		executor.request_attack(unit, target)
		return true
	# 2) сдвиг к ближайшему
	if not unit.has_moved:
		var nearest = null
		best = INF
		for e in enemy_units:
			if e.is_alive() and HexUtils.hex_distance(unit.cell, e.cell, bs.hex_shift_right) < best:
				best = HexUtils.hex_distance(unit.cell, e.cell, bs.hex_shift_right)
				nearest = e
		if nearest != null:
			var blocked = bs.build_all_blocked(unit, b.obstacles)
			var reachable = bs.get_reachable_for_unit(unit, func() -> Dictionary: return blocked)
			var best_cell := Vector2i(-1, -1)
			var best_d := best
			for c in reachable:
				var dc := HexUtils.hex_distance(c, nearest.cell, bs.hex_shift_right)
				if dc < best_d:
					best_d = dc
					best_cell = c
			if best_cell != Vector2i(-1, -1):
				executor.request_move(unit, best_cell)
				return true
	executor.request_wait()
	return true

# ── Мир: одно действие за кадр ──────────────────────────────────────────────
func _step() -> void:
	if not is_instance_valid(_hero) or _hero.is_alive == false:
		_finish()
		return
	var progress := false

	# 0. Потребности: ниже порога — на центр города и ждать реквери.
	# Вне города чистый спад −0.01/ход (+ штрафы за добычу/перегруз) —
	# без возвратов герой умирает от истощения (headless-прогон:
	# DEFEAT на 52-м ходу при активном исследовании).
	if _needs_low():
		if _hero_cell() == _city_center():
			_end_turn()  # ход в городе: потребности восстанавливаются
			return
		if _walk_to(_city_center()):
			return
		var home_t: Vector2i = _explore_target(_city_center())
		if home_t != Vector2i(-1, -1) and _walk_to(home_t):
			return
		# Город сейчас недоступен (туман/блок) — обычный цикл; спад небольшой
		# (−0.01/ход), город обычно рядом. Застрянет — _commit в шагах ниже.

	# 0.5. Защита города: враг в радиусе от центра — перехватить (город без
	# защиты падает: EnemyTurnProcessor марширует к нему, total_collapse).
	var threat: Vector2i = _nearest_city_threat()
	if threat != Vector2i(-1, -1):
		var mv_t: Node = _hero.get_component("Movement")
		if mv_t != null and not mv_t.is_moving():
			if mv_t.move_to_cell(threat):
				_commit(true)
				return
			var probe_t: Vector2i = _explore_target(threat)
			if probe_t != Vector2i(-1, -1) and _walk_to(probe_t):
				return

	# 1. Сбор: ближайший ресурсный узел
	var res_cell := _nearest_resource()
	if res_cell != Vector2i(-1, -1):
		var mv: Node = _hero.get_component("Movement")
		if mv != null and mv.is_moving():
			return  # движение в кадре — не дёргаем контроллер
		if mv != null:
			if mv.get_current_cell() == res_cell:
				# Уже у узла: сбор через игровую цепочку (WorldSpawner +
				# GameEventBus → WorldEventRouter кладёт в рюкзак героя).
				# ResourceNodeManager-узлы в resource_cells не генерируются —
				# try_discover/try_extract всегда NODE_NOT_FOUND (headless-баг
				# balance-core, исправлен в autopilot-scenario-matrix).
				var collected: bool = _try_collect_at(res_cell)
				_action_fails = 0
				progress = collected
			elif _walk_to(res_cell):
				# Дошли, доживая ходами (MP восстанавливается каждый ход).
				_action_fails = 0
				progress = true
			else:
				# Узел в тумане/недосягаем — идём к границе тумана в его сторону
				# (ход к границе расширяет поле зрения, FOG_HERO_SIGHT = 3).
				var probe_cell: Vector2i = _explore_target(res_cell)
				if probe_cell != Vector2i(-1, -1) and _walk_to(probe_cell):
					_action_fails = 0
					progress = true
				else:
					_action_fails += 1
					if _action_fails >= MAX_ACTION_RETRIES:
						_action_fails = 0
						mv.cancel_pending(false)
						res_cell = Vector2i(-1, -1)  # ничего досягаемого — пропускаем до хода
		# Не удалось уехать — продолжаем к стройке/бою в этом же кадре.

	# 2. Выгрузка в городе (рядом с центром игрока)
	if _player_city != null and _hero_cell().distance_to(_city_center()) < 2.0:
		var moved := _unload_backpack()
		if moved > 0:
			_commit(true)
			return
		_try_level_up_city()

	# 3. Стройка: приоритетный список
	var built := _try_build()
	if built:
		_commit(true)
		return

	# 4. Рекрутка
	var recruited := _try_recruit()
	if recruited:
		_commit(true)
		return

	# 5. Бой: ближайший враг в пределах досягаемости
	var enemy_cell := _nearest_enemy()
	if enemy_cell != Vector2i(-1, -1):
		var mv2: Node = _hero.get_component("Movement")
		if mv2 != null and mv2.is_moving():
			return
		if mv2 != null and mv2.move_to_cell(enemy_cell):
			# Путь к врагу начат; контакт (или затык) разберём в следующем кадре.
			_action_fails = 0
			_commit(true)
			return
		if mv2 != null:
			if mv2.get_controller().reach_problem(enemy_cell) == "unreachable":
				var enemy_frontier: Vector2i = _explore_target(enemy_cell)
				if enemy_frontier != Vector2i(-1, -1) and _walk_to(enemy_frontier):
					_action_fails = 0
					_commit(true)
					return
			_action_fails += 1
			if _action_fails >= MAX_ACTION_RETRIES:
				_action_fails = 0
				mv2.cancel_pending(false)
				enemy_cell = Vector2i(-1, -1)
		_commit(true if enemy_cell != Vector2i(-1, -1) else false)
		if enemy_cell != Vector2i(-1, -1):
			return

	# 6. Нечего делать — ход
	_end_turn()

func _try_build() -> bool:
	if _city_screen == null:
		return false
	for def_id in BUILD_QUEUE:
		var check: CityCheck = _city_screen.build_pressed(def_id)
		if check.ok:
			if first_building_turn < 0:
				first_building_turn = turn
			return true
	return false

func _try_recruit() -> bool:
	if _city_screen == null:
		return false
	var check: CityCheck = _city_screen.recruit_pressed()
	if check.ok:
		if first_recruit_turn < 0:
			first_recruit_turn = turn
		return true
	return false

func _try_level_up_city() -> void:
	if _city_screen == null or _player_city == null:
		return
	var check: CityCheck = _city_screen.level_up_pressed()
	if check.ok:
		snapshots.append({"turn": turn, "city_level_up": int(_player_city.level)})

func _unload_backpack() -> int:
	if _player_city == null or _hero.strategic_resources == null:
		return 0
	var total: int = _hero.strategic_resources.total()
	if total <= 0:
		return 0
	var moved := 0
	for rid in _hero.strategic_resources.get_all():
		var amount: int = int(_hero.strategic_resources.get_all()[rid])
		if amount > 0:
			var actual: int = _hero.remove_strategic_resource(rid, amount)
			if actual > 0:
				_player_city.storage[rid] = float(_player_city.storage.get(rid, 0.0)) + float(actual)
				moved += actual
	if moved > 0 and _player_city.has_signal("storage_changed"):
		_player_city.storage_changed.emit()
	return moved

func _nearest_resource() -> Vector2i:
	# Только реально собируемые узлы (маркер WorldSpawner на клетке).
	var cells: Array = []
	for c in _map().resource_cells.keys():
		if _spawner == null or int(_spawner.get_res_type_at(c)) >= 0:
			cells.append(c)
	return _nearest_cell(cells)

## Сбор через игровую цепочку: WorldSpawner удаляет маркер, GameEventBus
## доставляет ресурс в рюкзак героя (WorldEventRouter._on_resource_extracted).
func _try_collect_at(cell: Vector2i) -> bool:
	if _spawner == null:
		return false
	var rt: int = int(_spawner.get_res_type_at(cell))
	if rt < 0:
		return false
	var removed: bool = _spawner.remove_resource_at(cell)
	var rid: StringName = ResourceIcons.res_type_id(rt)
	if rid != &"":
		GameEventBus.resource_extracted.emit(cell, rid, ResourceIcons.res_type_amount(rt))
	return removed

## Дойти до клетки, доживая ходами: move_to_cell идёт на остаток MP,
## после do_end_turn MP восстанавливается — двигаемся дальше по тому же пути.
func _walk_to(cell: Vector2i) -> bool:
	var mv: Node = _hero.get_component("Movement")
	if mv == null:
		return false
	for _i in 60:  # ponytail: жёсткий потолок итераций — 60 ходов на один маршрут
		if mv.is_moving():
			return true  # кадр движения — разберёмся в следующем кадре
		if mv.get_current_cell() == cell:
			return true
		var ctrl: Node = mv.get_controller()
		if ctrl != null and ctrl.reach_problem(cell) == "unreachable":
			return false  # пути нет (туман/блок) — не сжигаем ходы зацикливанием
		if mv.move_to_cell(cell):
			continue  # путь на остаток MP начат; дойдём в следующих кадрах
		# MP кончились — дожить ход (MP восстановится) и пробовать снова
		var was_cell: Vector2i = mv.get_current_cell()
		var move_points_before: float = mv.get_move_points()
		_end_turn()
		if done:
			return false
		if mv.get_current_cell() == was_cell:
			if mv.get_move_points() > move_points_before:
				continue  # ход восстановил MP; повторить цель до ухода в обходной цикл
			return false  # не сдвинулся и MP не восстановились — маршрут мёртв
	return mv.get_current_cell() == cell

## Вражеский отряд в CITY_DEFEND_RADIUS от центра города (ближайший к городу).
func _nearest_city_threat() -> Vector2i:
	var city_c: Vector2i = _city_center()
	if city_c == Vector2i(-1000, -1000):
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in _map().enemy_stacks.keys():
		if _lost_enemy_cells.has(c):
			continue
		var dc: int = HexUtils.hex_distance(c, city_c)
		if dc <= CITY_DEFEND_RADIUS and dc < best_d:
			best_d = dc
			best = c
	return best

## Любая потребность ниже NEED_RETURN_THRESHOLD.
func _needs_low() -> bool:
	if _hero == null:
		return false
	var nc: Variant = _hero.get("needs_comp")
	if nc == null:
		return false
	for id in NeedType.all_ids():
		if float(nc.get_need(id)) < NEED_RETURN_THRESHOLD:
			return true
	return false

## Ближайшая к `toward` изведанная клетка на границе тумана (у неё есть
## неизведанный сосед) и досягаемая: шаг к ней расширяет поле зрения.
## Без этого герой не находит узлы дальше FOG_HERO_SIGHT от пройденного пути.
func _explore_target(toward: Vector2i) -> Vector2i:
	var vis = _map().visibility  # VisibilityMap — RefCounted, не Node (типизация крашит)
	if vis == null or toward == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var ctrl: Node = _hero.get_component("Movement").get_controller()
	var current: Vector2i = _hero.get_component("Movement").get_current_cell()
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in _map().terrain_grid:
		if c == current or not vis.is_explored(c) or not _map().is_walkable(c):
			continue
		var at_edge := false
		for nb in HexUtils.get_all_neighbors(c, _map().hex_shift_right):
			if vis.is_in_bounds(nb) and not vis.is_explored(nb):
				at_edge = true
				break
		if not at_edge:
			continue
		var d := HexUtils.hex_distance(c, toward)
		if d >= best_d:
			continue
		if ctrl != null and ctrl.reach_problem(c) == "unreachable":
			continue
		best_d = d
		best = c
	return best

func _nearest_enemy() -> Vector2i:
	var cells: Array = _map().enemy_stacks.keys()
	# Только 1-е кольцо: ранняя прогонка не лезет к монстрам
	var out: Array = []
	for c in cells:
		if _lost_enemy_cells.has(c):
			continue
		if HexUtils.hex_distance(c, _start_cell()) < MapSpawner.THREAT_RING2_RADIUS:
			out.append(c)
	return _nearest_cell(out)

func _nearest_cell(cells: Array) -> Vector2i:
	var here := _hero_cell()
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in cells:
		var d := HexUtils.hex_distance(c, here)
		if d > 0 and d < best_d:
			best_d = d
			best = c
	return best

func _end_turn() -> void:
	_world.do_end_turn()
	turn += 1
	# Мир может завершиться (победит/проигрыш) — дальше ходы не имеют смысла.
	if _world.is_terminal():
		_snapshot()
		_finish()
		return
	if turn % 5 == 0:
		_snapshot()
	if turn >= max_turns:
		_finish()

func _commit(progress: bool) -> void:
	stuck = 0 if progress else stuck + 1
	stuck_max_seen = maxi(stuck_max_seen, stuck)
	if stuck >= THRESHOLDS["stuck_max"] * 2:
		_fail("затык %d действий без прогресса (ход %d)" % [stuck, turn])

func _snapshot() -> void:
	var snap := {
		"turn": turn,
		"hero_cell": [int(_hero_cell().x), int(_hero_cell().y)],
		"backpack": _hero.strategic_resources.total() if _hero.strategic_resources != null else 0,
		"army_stacks": _hero.get_army().army.size() if _hero.get_army() != null else 0,
		"combat_hp": int(_hero.combat_hp),
		"season": WorldSeasons.season_name(),
		"hostility": WorldSeasons.hostility_mult(),
	}
	if _player_city != null:
		snap["city_level"] = int(_player_city.level)
		snap["city_buildings"] = int(_player_city.buildings.size())
		snap["industry"] = float(_player_city.storage.get(&"industry", 0.0))
	if _world.is_terminal():
		snap["endgame"] = _world.get_endgame_state()
	snapshots.append(snap)

## Итоги боя учитываются по авторитетным событиям игрока, а не стороне ATTACKER:
## при вражеской атаке ATTACKER — противник.
func _on_battle_won(_cell: Vector2i) -> void:
	if done:
		return
	_lost_enemy_cells.erase(_cell)
	if first_win_turn < 0:
		first_win_turn = turn

func _on_battle_lost(cell: Vector2i) -> void:
	if done:
		return
	_lost_enemy_cells[cell] = true
	losses += 1

func _fail(msg: String) -> void:
	error_msg = msg
	done = true
	set_process(false)
	ProbeFastMode.enabled = false
	if GameEventBus.battle_won.is_connected(_on_battle_won):
		GameEventBus.battle_won.disconnect(_on_battle_won)
	if GameEventBus.battle_lost.is_connected(_on_battle_lost):
		GameEventBus.battle_lost.disconnect(_on_battle_lost)
	GameLogger.error("BalanceProbe: %s" % msg, "BalanceProbe")

func _finish() -> void:
	done = true
	set_process(false)
	ProbeFastMode.enabled = false
	if GameEventBus.battle_won.is_connected(_on_battle_won):
		GameEventBus.battle_won.disconnect(_on_battle_won)
	if GameEventBus.battle_lost.is_connected(_on_battle_lost):
		GameEventBus.battle_lost.disconnect(_on_battle_lost)
	_check_thresholds()
	_save_report()

func _check_thresholds() -> void:
	if first_building_turn > THRESHOLDS["first_building_turn"]:
		warnings.append("first_building_turn %d > %d" % [first_building_turn, THRESHOLDS["first_building_turn"]])
	if first_recruit_turn > THRESHOLDS["first_recruit_turn"]:
		warnings.append("first_recruit_turn %d > %d" % [first_recruit_turn, THRESHOLDS["first_recruit_turn"]])
	if first_collision_turn >= 0 and first_win_turn >= 0:
		var gap: int = first_win_turn - first_collision_turn
		if gap > THRESHOLDS["first_win_after_collision"]:
			warnings.append("first_win gap %d > %d" % [gap, THRESHOLDS["first_win_after_collision"]])
	if losses > THRESHOLDS["losses_total"]:
		warnings.append("losses %d > %d" % [losses, THRESHOLDS["losses_total"]])
	# Поражение до конца прогона — главный сигнал перкалa (город пал/герой мёртв).
	var endgame: Dictionary = _world.get_endgame_state() if _world != null else {}
	var end_state: String = str(endgame.get("state", ""))
	if end_state == "DEFEAT":
		warnings.append("DEFEAT on turn %d: %s" % [turn, str(endgame.get("end_reason", "?"))])

func report_path() -> String:
	return "%s/balance_%d.json" % [REPORT_DIR, seed_value]

func read_report_text() -> String:
	var p: String = report_path()
	if p == "" or not FileAccess.file_exists(p):
		return ""
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s

func _save_report() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	var f := FileAccess.open(report_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report(), "  "))
		f.close()

func _hero_cell() -> Vector2i:
	var mv: Node = _hero.get_component("Movement")
	return mv.get_current_cell() if mv != null else Vector2i.ZERO

func _map():
	return _world.get_map_gen()

func _city_center() -> Vector2i:
	return _player_city.center if _player_city != null else Vector2i(-1000, -1000)

func _start_cell() -> Vector2i:
	return _map().model.find_spawn_cell(_map().hex_shift_right)
