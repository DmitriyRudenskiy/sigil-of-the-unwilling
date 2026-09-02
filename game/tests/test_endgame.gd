extends "res://tests/test_base.gd"
## endgame-conditions: терминальные состояния забега.
## Триггеры EndgameController (первое условие wins, sticky), GameSession
## state + сериализация, SaveData v5, итоговый отчёт.

const _Endgame = preload("res://scripts/systems/EndgameController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _GameSession = preload("res://scripts/core/GameSession.gd")
const _SaveData = preload("res://scripts/core/SaveData.gd")

## Мок бой-координатора: только сигнал enemy_stack_defeated.
class _MockBattle:
	extends Node
	signal enemy_stack_defeated(cell: Vector2i, army: Array)


## Мок enemy-процессора: только сигнал enemy_village_captured.
class _MockEnemyProc:
	extends Node
	signal enemy_village_captured(city: City)


## Мок persistence: session + get_date (то, что использует Endgame).
class _MockPersistence:
	extends Node
	var session: GameSession
	# legend-chronicle: EndgameController._append_chronicle_entry читает
	# persistence.chronicle; null — запись пропускается (как в раннем return).
	var chronicle = null

	func get_date() -> Dictionary:
		return {"month": 3, "week": 2, "day": 1}


## Мок map_gen: только enemy_stacks.
class _MockMap:
	extends Node
	var enemy_stacks: Dictionary = {}


## Мок world_ctrl: только get_hero.
class _MockWorld:
	extends Node
	var hero: HeroController

	func get_hero() -> HeroController:
		return hero


var _ec = null
var _world: _MockWorld
var _cities: CityManager
var _battle: _MockBattle
var _enemy_proc: _MockEnemyProc
var _map: _MockMap
var _persistence: _MockPersistence
var _ended_count := 0
var _last_summary: Dictionary = {}
var _ended_cb: Callable = Callable()


func _make_hero(path := &"archivist") -> HeroController:
	var h := _Hero.new()
	h.path_id = path
	return h


func _make_cities(player_count: int) -> CityManager:
	var mgr := _CityManager.new()
	mgr.name = "CitiesUnderTest"
	root.add_child(mgr)
	for i in player_count:
		var c := _City.new()
		c.uid = 10 + i
		c.display_name = &"City%d" % i
		c.owner = &"player"
		c.is_capital = (i == 0)
		mgr.register_city(c)
	return mgr


func _setup_endgame() -> void:
	_ended_count = 0
	_last_summary = {}
	var session := _GameSession.new()
	_persistence = _MockPersistence.new()
	_persistence.session = session
	_world = _MockWorld.new()
	_cities = _make_cities(1)
	_battle = _MockBattle.new()
	_enemy_proc = _MockEnemyProc.new()
	_map = _MockMap.new()
	_ec = _Endgame.new()
	_ec.name = "EndgameUnderTest"
	root.add_child(_ec)
	root.add_child(_battle)
	root.add_child(_enemy_proc)
	root.add_child(_map)
	root.add_child(_persistence)
	root.add_child(_world)
	_ec.setup(_world, _battle, _map, _cities, _persistence, _enemy_proc)
	# Bus-сигнал: коннектим/дисконнектим каждый тест (bus живёт весь ран).
	_ended_cb = func(_r: String, _reason: StringName, s: Dictionary) -> void:
		_ended_count += 1
		_last_summary = s
	GameEventBus.game_ended.connect(_ended_cb)


func after_each() -> void:
	if _ended_cb.is_valid():
		GameEventBus.game_ended.disconnect(_ended_cb)
	_ended_cb = Callable()
	# Герой — сначала (он мог быть в дереве/в моках).
	if _world != null and _world.hero != null and is_instance_valid(_world.hero):
		_world.hero.free()
	if _ec != null and is_instance_valid(_ec):
		_ec.free()
	for n in [_battle, _enemy_proc, _world, _map, _persistence, _cities]:
		if n != null and is_instance_valid(n):
			n.free()
	_ec = null
	_battle = null
	_enemy_proc = null
	_world = null
	_map = null
	_persistence = null
	_cities = null


func _session() -> GameSession:
	return _persistence.session


# ==================== ПОРАЖЕНИЕ: СМЕРТЬ БЕЗ ПРЕЕМНИКА ====================

func test_death_without_successor_is_defeat() -> void:
	_setup_endgame()
	_world.hero = _make_hero()
	_world.hero.followers = []

	GameEventBus.hero_died.emit(&"battle")

	assert_eq(_session().state, GameSession.GameState.DEFEAT, "state is DEFEAT")
	assert_eq(_session().end_reason, "unsuccessored_death", "reason recorded")
	assert_eq(_ended_count, 1, "game_ended emitted exactly once")
	assert_eq(_last_summary.get("result"), "DEFEAT", "summary result")
	assert_eq(_last_summary.get("reason"), "unsuccessored_death", "summary reason")


func test_death_with_successor_keeps_run_running() -> void:
	_setup_endgame()
	_world.hero = _make_hero()
	var f := _Follower.new()
	f.uid = 1
	f.path = &"archivist"
	_world.hero.followers = [f]

	GameEventBus.hero_died.emit(&"battle")

	assert_eq(_session().state, GameSession.GameState.RUNNING, "run continues with successor")
	assert_eq(_ended_count, 0, "no game_ended")


# ==================== ПОРАЖЕНИЕ: ТОТАЛЬНЫЙ КОЛЛАПС ====================

func test_last_city_captured_is_defeat() -> void:
	_setup_endgame()
	var city: City = _cities.cities[0]
	city.owner = &"enemy"

	_enemy_proc.enemy_village_captured.emit(city)

	assert_eq(_session().state, GameSession.GameState.DEFEAT, "collapse → DEFEAT")
	assert_eq(_session().end_reason, "total_collapse", "reason is total_collapse")


func test_city_captured_but_other_alive_stays_running() -> void:
	_setup_endgame()
	var c2 := _City.new()
	c2.uid = 11
	c2.display_name = &"City2"
	c2.owner = &"player"
	c2.is_capital = false
	_cities.register_city(c2)
	var city: City = _cities.cities[0]
	city.owner = &"enemy"

	_enemy_proc.enemy_village_captured.emit(city)

	assert_eq(_session().state, GameSession.GameState.RUNNING, "second city alive → RUNNING")


func test_turn_ended_fallback_collapse() -> void:
	_setup_endgame()
	for c in _cities.cities:
		c.owner = &"enemy"

	GameEventBus.turn_ended.emit(5, 3)

	assert_eq(_session().state, GameSession.GameState.DEFEAT, "fallback collapse → DEFEAT")
	assert_eq(_session().end_reason, "total_collapse", "reason is total_collapse")


func test_turn_ended_with_cities_stays_running() -> void:
	_setup_endgame()
	GameEventBus.turn_ended.emit(5, 3)
	assert_eq(_session().state, GameSession.GameState.RUNNING, "cities alive → RUNNING")


# ==================== ПОБЕДА: СЛАВА ====================

func test_glory_threshold_is_victory() -> void:
	_setup_endgame()
	_cities.current_turn = 42
	_cities.add_glory(300.0, &"test")
	assert_eq(_session().state, GameSession.GameState.RUNNING, "below threshold → RUNNING")
	_cities.add_glory(200.0, &"test")

	assert_eq(_session().state, GameSession.GameState.VICTORY, "threshold → VICTORY")
	assert_eq(_session().end_reason, "path_completed", "reason is path_completed")
	assert_eq(_last_summary.get("turns"), 42, "summary turns")
	assert_eq(_last_summary.get("glory"), 500, "summary glory")


# ==================== ПОБЕДА: ДОМИНАЦИЯ ====================

func test_last_enemy_stack_defeated_is_victory() -> void:
	_setup_endgame()
	_map.enemy_stacks = {Vector2i(3, 4): {}}
	# В мире боевой координатор удаляет стек ДО emit'а сигнала.
	_map.enemy_stacks.erase(Vector2i(3, 4))

	_battle.enemy_stack_defeated.emit(Vector2i(3, 4), [])

	assert_eq(_session().state, GameSession.GameState.VICTORY, "no stacks left → VICTORY")
	assert_eq(_session().end_reason, "domination", "reason is domination")


func test_stack_survives_stays_running() -> void:
	_setup_endgame()
	_map.enemy_stacks = {Vector2i(3, 4): {}, Vector2i(5, 6): {}}

	_battle.enemy_stack_defeated.emit(Vector2i(3, 4), [])

	assert_eq(_session().state, GameSession.GameState.RUNNING, "stacks remain → RUNNING")


# ==================== STICKY: ПЕРВОЕ УСЛОВИЕ WINS ====================

func test_first_terminal_condition_wins_and_sticky() -> void:
	_setup_endgame()
	# Сначала коллапс.
	for c in _cities.cities:
		c.owner = &"enemy"
	GameEventBus.turn_ended.emit(5, 3)
	assert_eq(_session().state, GameSession.GameState.DEFEAT, "collapse first")

	# Потом смерть без преемника — состояние не меняется, сигнал не дублируется.
	_world.hero = _make_hero()
	_world.hero.followers = []
	GameEventBus.hero_died.emit(&"battle")
	_cities.add_glory(9999.0, &"test")

	assert_eq(_session().end_reason, "total_collapse", "reason unchanged")
	assert_eq(_ended_count, 1, "game_ended emitted exactly once")


# ==================== ОТЧЁТ: СЧЁТЧИКИ ====================

func test_summary_counters() -> void:
	_setup_endgame()
	GameEventBus.battle_won.emit(Vector2i(1, 1))
	GameEventBus.battle_won.emit(Vector2i(2, 2))
	GameEventBus.battle_lost.emit(Vector2i(3, 3))
	var succ := _make_hero()
	GameEventBus.hero_successor.emit(succ)
	succ.free()  # не в дереве — освобождаем явно (иначе утечка в ObjectDB)

	for c in _cities.cities:
		c.owner = &"enemy"
	GameEventBus.turn_ended.emit(7, 1)

	assert_eq(_last_summary.get("battles_won"), 2, "battles_won counted")
	assert_eq(_last_summary.get("battles_lost"), 1, "battles_lost counted")
	assert_eq(_last_summary.get("generations"), 2, "generations = successions + 1")
	assert_eq(_last_summary.get("date", {}).get("month"), 3, "summary date from persistence")
	assert_eq(_last_summary.get("cities_owned"), 0, "cities_owned counted")


# ==================== GAMESESSION: СОСТОЯНИЕ И СЕРИАЛИЗАЦИЯ ====================

func test_session_serialize_roundtrip() -> void:
	var s := _GameSession.new()
	s.state = GameSession.GameState.DEFEAT
	s.end_reason = "unsuccessored_death"
	s.battles_won = 3
	s.battles_lost = 1
	s.successions = 2

	var d2: GameSession = _GameSession.new()
	d2.deserialize(s.serialize())

	assert_eq(d2.state, GameSession.GameState.DEFEAT, "state roundtrip")
	assert_eq(d2.end_reason, "unsuccessored_death", "reason roundtrip")
	assert_eq(d2.battles_won, 3, "battles_won roundtrip")
	assert_eq(d2.battles_lost, 1, "battles_lost roundtrip")
	assert_eq(d2.successions, 2, "successions roundtrip")
	assert_true(d2.is_terminal(), "terminal flag roundtrip")


func test_session_defaults_running() -> void:
	var s := _GameSession.new()
	assert_eq(s.state, GameSession.GameState.RUNNING, "default RUNNING")
	assert_false(s.is_terminal(), "default not terminal")


# ==================== SAVE v5 ====================

func test_save_v5_roundtrip_with_session() -> void:
	var d := _SaveData.new()
	d.run_seed = 777
	d.hero = {"cell": {"x": 3, "y": 4}, "path_id": "archivist"}
	d.session = {"state": 2, "end_reason": "total_collapse",
		"battles_won": 4, "battles_lost": 2, "successions": 1}

	var data := d.to_dict()
	assert_eq(data["version"], _SaveData.CURRENT_VERSION, "save version is current")

	var d2 := _SaveData.new()
	d2.from_dict(data)
	assert_eq(d2.version, _SaveData.CURRENT_VERSION, "loaded version is current")
	assert_eq(d2.session.get("state"), 2, "session state preserved")
	assert_eq(d2.session.get("end_reason"), "total_collapse", "session reason preserved")


func test_migrate_v4_to_v5_defaults() -> void:
	# v4-сейв (succession) без session.
	var v4 := {"version": 4, "run_seed": 99,
		"hero": {"cell": {"x": 1, "y": 1}, "path_id": "archivist"},
		"world": {}, "cities": [], "characters": [],
		"successor": {}, "legend": {}}
	var d := _SaveData.new()
	d.from_dict(v4)
	assert_eq(d.version, _SaveData.CURRENT_VERSION, "v4 migrated to current")
	assert_true(d.session is Dictionary, "session defaulted to dict")
	assert_eq(d.run_seed, 99, "run_seed preserved through migration")
	# Сессия, восстановленная из пустого session, — RUNNING.
	var s := _GameSession.new()
	s.deserialize(d.session)
	assert_eq(s.state, GameSession.GameState.RUNNING, "empty session → RUNNING")
