extends GdUnitTestSuite

const _Endgame = preload("res://scripts/systems/EndgameController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _GameSession = preload("res://scripts/core/GameSession.gd")
const _SaveData = preload("res://scripts/core/SaveData.gd")

class _MockBattle:
	extends Node
	signal enemy_stack_defeated(cell: Vector2i, army: Array)

class _MockEnemyProc:
	extends Node
	signal enemy_village_captured(city: City)

class _MockPersistence:
	extends Node
	var session: GameSession
	var chronicle = null

	func get_date() -> Dictionary:
		return {"month": 3, "week": 2, "day": 1}

class _MockMap:
	extends Node
	var enemy_stacks: Dictionary = {}

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

func _make_cities(player_count: int) -> CityManager:
	var mgr := _CityManager.new()
	mgr.name = "CitiesUnderTest"
	add_child(mgr)
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
	add_child(_ec)
	add_child(_battle)
	add_child(_enemy_proc)
	add_child(_map)
	add_child(_persistence)
	add_child(_world)
	_ec.setup(_world, _battle, _map, _cities, _persistence, _enemy_proc)
	_ended_cb = func(_r: String, _reason: StringName, s: Dictionary) -> void:
		_ended_count += 1
		_last_summary = s
	GameEventBus.game_ended.connect(_ended_cb)

func after_test() -> void:
	if _ended_cb.is_valid():
		GameEventBus.game_ended.disconnect(_ended_cb)
	_ended_cb = Callable()
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

func test_death_without_successor_is_defeat() -> void:
	_setup_endgame()
	_world.hero = TestFactories.make_hero()
	_world.hero.followers = []

	GameEventBus.hero_died.emit(&"battle")

	assert_that(_session().state).is_equal(GameSession.GameState.DEFEAT)
	assert_that(_session().end_reason).is_equal("unsuccessored_death")
	assert_that(_ended_count).is_equal(1)
	assert_that(_last_summary.get("result")).is_equal("DEFEAT")
	assert_that(_last_summary.get("reason")).is_equal("unsuccessored_death")

func test_death_with_successor_keeps_run_running() -> void:
	_setup_endgame()
	_world.hero = TestFactories.make_hero()
	var f := _Follower.new()
	f.uid = 1
	f.path = &"archivist"
	_world.hero.followers = [f]

	GameEventBus.hero_died.emit(&"battle")

	assert_that(_session().state).is_equal(GameSession.GameState.RUNNING)
	assert_that(_ended_count).is_equal(0)

func test_last_city_captured_is_defeat() -> void:
	_setup_endgame()
	var city: City = _cities.cities[0]
	city.owner = &"enemy"

	_enemy_proc.enemy_village_captured.emit(city)

	assert_that(_session().state).is_equal(GameSession.GameState.DEFEAT)
	assert_that(_session().end_reason).is_equal("total_collapse")

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

	assert_that(_session().state).is_equal(GameSession.GameState.RUNNING)

func test_turn_ended_fallback_collapse() -> void:
	_setup_endgame()
	for c in _cities.cities:
		c.owner = &"enemy"

	GameEventBus.turn_ended.emit(5, 3)

	assert_that(_session().state).is_equal(GameSession.GameState.DEFEAT)
	assert_that(_session().end_reason).is_equal("total_collapse")

func test_turn_ended_with_cities_stays_running() -> void:
	_setup_endgame()
	GameEventBus.turn_ended.emit(5, 3)
	assert_that(_session().state).is_equal(GameSession.GameState.RUNNING)

func test_glory_threshold_is_victory() -> void:
	_setup_endgame()
	_cities.current_turn = 42
	_cities.add_glory(300.0, &"test")
	assert_that(_session().state).is_equal(GameSession.GameState.RUNNING)
	_cities.add_glory(200.0, &"test")

	assert_that(_session().state).is_equal(GameSession.GameState.VICTORY)
	assert_that(_session().end_reason).is_equal("path_completed")
	assert_that(_last_summary.get("turns")).is_equal(42)
	assert_that(_last_summary.get("glory")).is_equal(500)

func test_last_enemy_stack_defeated_is_victory() -> void:
	_setup_endgame()
	_map.enemy_stacks = {Vector2i(3, 4): {}}
	_map.enemy_stacks.erase(Vector2i(3, 4))

	_battle.enemy_stack_defeated.emit(Vector2i(3, 4), [])

	assert_that(_session().state).is_equal(GameSession.GameState.VICTORY)
	assert_that(_session().end_reason).is_equal("domination")

func test_stack_survives_stays_running() -> void:
	_setup_endgame()
	_map.enemy_stacks = {Vector2i(3, 4): {}, Vector2i(5, 6): {}}

	_battle.enemy_stack_defeated.emit(Vector2i(3, 4), [])

	assert_that(_session().state).is_equal(GameSession.GameState.RUNNING)

func test_first_terminal_condition_wins_and_sticky() -> void:
	_setup_endgame()
	for c in _cities.cities:
		c.owner = &"enemy"
	GameEventBus.turn_ended.emit(5, 3)
	assert_that(_session().state).is_equal(GameSession.GameState.DEFEAT)

	_world.hero = TestFactories.make_hero()
	_world.hero.followers = []
	GameEventBus.hero_died.emit(&"battle")
	_cities.add_glory(9999.0, &"test")

	assert_that(_session().end_reason).is_equal("total_collapse")
	assert_that(_ended_count).is_equal(1)

func test_summary_counters() -> void:
	_setup_endgame()
	GameEventBus.battle_won.emit(Vector2i(1, 1))
	GameEventBus.battle_won.emit(Vector2i(2, 2))
	GameEventBus.battle_lost.emit(Vector2i(3, 3))
	var succ := TestFactories.make_hero()
	GameEventBus.hero_successor.emit(succ)
	succ.free()

	for c in _cities.cities:
		c.owner = &"enemy"
	GameEventBus.turn_ended.emit(7, 1)

	assert_that(_last_summary.get("battles_won")).is_equal(2)
	assert_that(_last_summary.get("battles_lost")).is_equal(1)
	assert_that(_last_summary.get("generations")).is_equal(2)
	assert_that(_last_summary.get("date", {}).get("month")).is_equal(3)
	assert_that(_last_summary.get("cities_owned")).is_equal(0)

func test_session_serialize_roundtrip() -> void:
	var s := _GameSession.new()
	s.state = GameSession.GameState.DEFEAT
	s.end_reason = "unsuccessored_death"
	s.battles_won = 3
	s.battles_lost = 1
	s.successions = 2

	var d2: GameSession = _GameSession.new()
	d2.deserialize(s.serialize())

	assert_that(d2.state).is_equal(GameSession.GameState.DEFEAT)
	assert_that(d2.end_reason).is_equal("unsuccessored_death")
	assert_that(d2.battles_won).is_equal(3)
	assert_that(d2.battles_lost).is_equal(1)
	assert_that(d2.successions).is_equal(2)
	assert_bool(d2.is_terminal()).is_true()

func test_session_defaults_running() -> void:
	var s := _GameSession.new()
	assert_that(s.state).is_equal(GameSession.GameState.RUNNING)
	assert_bool(s.is_terminal()).is_false()

func test_save_v5_roundtrip_with_session() -> void:
	var d := _SaveData.new()
	d.run_seed = 777
	d.hero = {"cell": {"x": 3, "y": 4}, "path_id": "archivist"}
	d.session = {"state": 2, "end_reason": "total_collapse",
		"battles_won": 4, "battles_lost": 2, "successions": 1}

	var data := d.to_dict()
	assert_that(data["version"]).is_equal(_SaveData.CURRENT_VERSION)

	var d2 := _SaveData.new()
	d2.from_dict(data)
	assert_that(d2.version).is_equal(_SaveData.CURRENT_VERSION)
	assert_that(d2.session.get("state")).is_equal(2)
	assert_that(d2.session.get("end_reason")).is_equal("total_collapse")

func test_migrate_v4_to_v5_defaults() -> void:
	var v4 := {"version": 4, "run_seed": 99,
		"hero": {"cell": {"x": 1, "y": 1}, "path_id": "archivist"},
		"world": {}, "cities": [], "characters": [],
		"successor": {}, "legend": {}}
	var d := _SaveData.new()
	d.from_dict(v4)
	assert_that(d.version).is_equal(_SaveData.CURRENT_VERSION)
	assert_bool(d.session is Dictionary).is_true()
	assert_that(d.run_seed).is_equal(99)
	var s := _GameSession.new()
	s.deserialize(d.session)
	assert_that(s.state).is_equal(GameSession.GameState.RUNNING)

func test_double_setup_does_not_duplicate_counters() -> void:
	_setup_endgame()
	_ec.setup(_world, _battle, _map, _cities, _persistence, _enemy_proc)
	GameEventBus.battle_won.emit(Vector2i(1, 1))
	GameEventBus.battle_lost.emit(Vector2i(2, 2))
	GameEventBus.hero_successor.emit(_world.hero)
	assert_that(_persistence.session.battles_won).is_equal(1)
	assert_that(_persistence.session.battles_lost).is_equal(1)
	assert_that(_persistence.session.successions).is_equal(1)
