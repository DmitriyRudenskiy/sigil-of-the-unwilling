extends GdUnitTestSuite
## WorldSaveLoadService: delegation to persistence + endgame state.

class _StubPersistence:
	var world_delta = null
	var saved_hero = null
	var saved_cities = null
	var saved_chars: Array = []
	var last_save: SaveData = null
	var session: GameSession

	func save_game(hero, cities, chars) -> bool:
		saved_hero = hero
		saved_cities = cities
		saved_chars = chars
		return true

	func load_game() -> SaveData:
		return last_save

	func last_save_dict() -> Dictionary:
		return {"last": true}


class _StubCities extends Node:
	var cities: Array = []


var _hero: Node
var _cities: _StubCities

func before_test() -> void:
	_hero = Node.new()
	_cities = _StubCities.new()

func after_test() -> void:
	for n in [_hero, _cities]:
		if n != null and is_instance_valid(n):
			n.free()
	_hero = null
	_cities = null


func _make_service(p: _StubPersistence) -> WorldSaveLoadService:
	var svc := WorldSaveLoadService.new()
	svc.setup(get_tree(), p, null, _hero, _cities,
		"world_delta", null, null, null, null)
	return svc


func test_save_game_delegates_to_persistence() -> void:
	var p := _StubPersistence.new()
	_cities.cities = [1, 2]
	var svc := WorldSaveLoadService.new()
	svc.setup(get_tree(), p, null, _hero, _cities, "delta", null, null, null, null)

	var ok: bool = svc.save_game()
	assert_bool(ok).is_true()
	assert_that(p.saved_hero).is_equal(_hero)
	assert_that(p.saved_cities).is_equal(_cities.cities)
	assert_that(p.saved_chars.size()).is_equal(0)
	assert_that(p.world_delta).is_equal("delta")


func test_load_game_returns_persistence_data() -> void:
	var p := _StubPersistence.new()
	var data := SaveData.new()
	p.last_save = data
	var svc := _make_service(p)
	assert_that(svc.load_game()).is_equal(data)


func test_get_last_save_dict_delegates() -> void:
	var p := _StubPersistence.new()
	var svc := _make_service(p)
	assert_that(svc.get_last_save_dict()).is_equal({"last": true})


func test_endgame_state_running() -> void:
	var p := _StubPersistence.new()
	p.session = GameSession.new()
	p.session.state = GameSession.GameState.RUNNING
	var svc := _make_service(p)
	var st: Dictionary = svc.get_endgame_state()
	assert_that(st["state"]).is_equal("RUNNING")
	assert_bool(svc.is_terminal()).is_false()


func test_endgame_state_victory() -> void:
	var p := _StubPersistence.new()
	p.session = GameSession.new()
	p.session.state = GameSession.GameState.VICTORY
	p.session.end_reason = "boss"
	var svc := _make_service(p)
	var st: Dictionary = svc.get_endgame_state()
	assert_that(st["state"]).is_equal("VICTORY")
	assert_that(st["end_reason"]).is_equal("boss")
	assert_bool(svc.is_terminal()).is_true()


func test_endgame_state_no_session() -> void:
	var p := _StubPersistence.new()
	var svc := _make_service(p)
	var st: Dictionary = svc.get_endgame_state()
	assert_that(st["state"]).is_equal("RUNNING")
	assert_bool(svc.is_terminal()).is_false()
