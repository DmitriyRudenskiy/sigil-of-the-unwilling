extends SceneTree
## Диагностика когорты выживания (задача 7.2 цикла `scenario-matrix-behavior-reliability`):
## почему базовый автопилот за 60 ходов не нанимает ни одного отряда (`recruits=0` во всех
## десяти прогонах `docs/mvp/matrix/2026-10-26/survival-60-seeds.txt`) и почему город
## переходит в `total_collapse`.
##
##   godot --headless --path game -s res://tools/diag_recruit_block.gd
##   DIAG_SEED=10007 DIAG_TURNS=40 godot --headless --path game -s res://tools/diag_recruit_block.gd
##
## Проверки найма читаются **без совершения найма**: `CityScreen.recruit_pressed()` — это
## действие (успех списывает серебро и выдаёт отряд), а не предпроверка, поэтому диагностика
## повторяет её предусловия через `CityService.recruit_military`-гейты и печатает причину.
## Строка `DIAG|…` — снимок состояния, а не вердикт: вердикт выносится в тред задачи 7.2.

const WORLD_SCENE := "res://scenes/archive/world.tscn"
const SCENARIO_PILOT_GD := "res://scripts/probe/ScenarioPilot.gd"
const PILOT_SCENE := "res://scenes/probe/ScenarioPilot.tscn"
const LEADERSHIP_CHECK_GD := "res://scripts/systems/leadership_check.gd"

var _seed := int(OS.get_environment("DIAG_SEED"))
var _turns := int(OS.get_environment("DIAG_TURNS"))
var _every := int(OS.get_environment("DIAG_EVERY"))
var _last_turn := -1


func _initialize() -> void:
	OS.set_environment("MCP_TEST", "1")
	if _seed <= 0:
		_seed = 4517
	if _turns <= 0:
		_turns = 35
	if _every <= 0:
		_every = 5
	for _warmup in 5:
		await process_frame
	var pilot_tool = load(SCENARIO_PILOT_GD)
	var prep: Dictionary = pilot_tool.call("prepare_world", _seed, "fighter")
	print("DIAG-PREP|%s" % str(prep))
	if prep.get("status") != "prepared":
		print("DIAG|error=prepare_world:%s" % str(prep.get("error", "?")))
		quit(2)
		return
	var world: Node = load(WORLD_SCENE).instantiate()
	root.add_child(world)
	for _i in 40:
		await process_frame
		if world.get_hero() != null and world.get_map_gen() != null:
			break
	print("DIAG-WARMUP|frames_used|hero=%s|mapgen=%s" % [
		str(world.get_hero() != null), str(world.get_map_gen() != null)])
	var pilot: Node = load(PILOT_SCENE).instantiate()
	root.add_child(pilot)
	var started: Dictionary = pilot.start_scenario(world, _seed, "survival", "fighter")
	print("DIAG-START_SCENARIO|%s" % str(started))
	pilot.max_turns = _turns
	print("DIAG-START|seed=%d|turns=%d|class=fighter" % [_seed, _turns])
	for _frame in 30000:
		if pilot.done or not is_instance_valid(pilot._hero):
			break
		if int(pilot.turn) != _last_turn and int(pilot.turn) % _every == 0:
			_last_turn = int(pilot.turn)
			_dump(pilot)
		await process_frame
	_dump(pilot)
	var rep: Dictionary = pilot.report()
	print("DIAG-END|seed=%d|turns=%d|endgame=%s" % [
		_seed, int(rep.get("turns", -1)), str(rep.get("endgame", {}))])
	quit(0)


func _dump(pilot: Node) -> void:
	var world: Node = pilot._world
	var city = pilot._player_city
	var screen: Node = pilot._city_screen
	var hero = world.get_hero()
	var parts: Array[String] = []
	parts.append("turn=%d" % int(pilot.turn))
	parts.append("builds=%d" % int(pilot.builds_done))
	parts.append("recruits=%d" % int(pilot.recruits_done))
	parts.append("gathers=%d" % int(pilot.extracted_nodes))
	if hero == null:
		parts.append("hero=dead")
		print("DIAG|" + "|".join(parts))
		return
	parts.append("hp=%.0f" % float(hero.get("combat_hp")))
	parts.append("needs=%s" % _needs(hero))
	var army = hero.get_army()
	var stacks: int = army.army.size() if army != null else -1
	var cha: int = int(hero.stats.get("cha", 2))
	var cap: int = mini(load(LEADERSHIP_CHECK_GD).max_army_stacks(cha), GameNumbers.HERO_ARMY_MAX_STACKS)
	parts.append("army=%d/%d" % [stacks, cap])
	parts.append("cha=%d" % cha)
	if city == null:
		parts.append("city=null")
		print("DIAG|" + "|".join(parts))
		return
	parts.append("owner=%s" % str(city.owner))
	parts.append("level=%d" % int(city.level))
	parts.append("bld=%d" % int(city.buildings.size()))
	parts.append("mil=%d" % _military_count(city))
	parts.append("silver=%.0f" % float(city.storage.get("silver", 0.0)))
	parts.append("food=%.1f" % float(city.food_stockpile))
	parts.append("pop=%d" % int(city.pop_total()))
	parts.append("player_cities=%d" % _player_cities(world))
	parts.append("hero_cell=%d,%d" % [int(pilot._hero_cell().x), int(pilot._hero_cell().y)])
	parts.append("center=%d,%d" % [int(pilot._city_center().x), int(pilot._city_center().y)])
	parts.append("hero_dist=%.1f" % float(pilot._hero_cell().distance_to(pilot._city_center())))
	parts.append("recruit_block=%s" % _recruit_block(screen, city, hero))
	parts.append("silver_nearest=%s" % _nearest_named(world, &"silver", pilot._city_center()))
	print("DIAG|" + "|".join(parts))


## Расстояние от центра города до ближайшего узла данного ресурса (или `none`). Нужно,
## чтобы отличить «серебра на карте нет» от «политика ближайшего узла до него не доходит»:
## зонд идёт к ближайшему узлу любого типа, а серебро — редкий узел.
func _nearest_named(world, wanted: StringName, from: Vector2i) -> String:
	var mg = world.get_map_gen()
	var spawner: Node = world.get_node_or_null("WorldSpawner")
	if mg == null or spawner == null:
		return "no_map"
	var icons = load("res://scripts/data/resource_icons.gd")
	var hex = load("res://scripts/core/hex_utils.gd")
	var shift: bool = bool(mg.hex_shift_right)
	var best := -1
	for c in mg.resource_cells.keys():
		var rt: int = int(spawner.get_res_type_at(c))
		if rt < 0 or icons.res_type_id(rt) != wanted:
			continue
		var d: int = int(hex.hex_distance(from, c, shift))
		if best < 0 or d < best:
			best = d
	return str(best) if best >= 0 else "none"


## Предусловия найма без совершения найма (см. заголовок файла).
func _recruit_block(screen: Node, city, hero) -> String:
	if screen == null:
		return "no_screen"
	if screen.hero == null:
		return "no_hero_binding"
	var bld = _military_building(city)
	if bld == null:
		return "no_military_building"
	var chain: Dictionary = bld.def.military_chain
	var costs: Array = chain.get("costs", [])
	var idx: int = clampi(int(bld.level) - 1, 0, maxi(costs.size() - 1, 0))
	var cost: Dictionary = costs[idx] if idx < costs.size() else {}
	for key in cost:
		if float(city.storage.get(key, 0.0)) < float(cost[key]):
			return "cost %s %.0f/%.0f" % [str(key), float(city.storage.get(key, 0.0)), float(cost[key])]
	var army = hero.get_army()
	if army == null:
		return "no_army"
	var cha: int = int(hero.stats.get("cha", 2))
	var cap: int = mini(load(LEADERSHIP_CHECK_GD).max_army_stacks(cha), GameNumbers.HERO_ARMY_MAX_STACKS)
	if int(army.army.size()) >= cap:
		return "army_full %d/%d" % [int(army.army.size()), cap]
	return "ok_or_d20"


func _military_building(city):
	for b in city.buildings:
		if b != null and b.def != null and not b.def.military_chain.is_empty():
			return b
	return null


func _military_count(city) -> int:
	var n := 0
	for b in city.buildings:
		if b != null and b.def != null and not b.def.military_chain.is_empty():
			n += 1
	return n


func _player_cities(world: Node) -> int:
	var mgr: Node = world.get_cities()
	if mgr == null:
		return -1
	var n := 0
	for c in mgr.cities:
		if c != null and c.owner == &"player":
			n += 1
	return n


func _needs(hero) -> String:
	var nc: Variant = hero.get("needs_comp")
	if nc == null:
		return "?"
	# `NeedType` статическим идентификатором в `-s`-инструменте ломает его компиляцию:
	# need_type.gd тянет стратегии → city.gd → city_service.gd, а там обращение к
	# автозагрузке `Services`, которой на момент компиляции инструмента ещё нет.
	var need_type = load("res://scripts/data/need_type.gd")
	var out: Array[String] = []
	for id in need_type.all_ids():
		out.append("%s=%.2f" % [str(id), float(nc.get_need(id))])
	return ",".join(out)
