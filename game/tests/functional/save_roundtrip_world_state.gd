extends BaseTest
## save-load-coverage-expansion 4.1: roundtrip для оставшихся строк матрицы
## (doc/SAVE_MATRIX.md): GameSession, Chronicle, Shards, Characters.

const _Chronicle = preload("res://scripts/core/chronicle.gd")
const _CharacterRegistry = preload("res://scripts/demographics/character_registry.gd")
const _Character = preload("res://scripts/demographics/character.gd")


func test_game_session_roundtrip() -> void:
	var s := GameSession.new()
	s.state = GameSession.GameState.DEFEAT
	s.end_reason = "hero_died"
	s.battles_won = 5
	s.battles_lost = 3
	s.successions = 2

	var dict := s.serialize()
	var s2 := GameSession.new()
	s2.deserialize(dict)

	assert_that(s2.state).is_equal(GameSession.GameState.DEFEAT)
	assert_that(s2.end_reason).is_equal("hero_died")
	assert_that(s2.battles_won).is_equal(5)
	assert_that(s2.battles_lost).is_equal(3)
	assert_that(s2.successions).is_equal(2)

	# Legacy: пустой/отсутствующий блок → RUNNING
	var s3 := GameSession.new()
	s3.deserialize({})
	assert_that(s3.state).is_equal(GameSession.GameState.RUNNING)


func test_chronicle_roundtrip() -> void:
	var ch := _Chronicle.new()
	ch.append({"type": "hero_born", "name": "Арагорн", "race": "human"})
	ch.append({"type": "hero_died", "name": "Арагорн", "cause": "battle"})
	assert_that(ch.entries.size()).is_equal(2)

	var arr := ch.to_array()
	var ch2 := _Chronicle.new()
	ch2.from_array(arr)

	assert_that(ch2.entries.size()).is_equal(2)
	assert_that(str(ch2.entries[0].get("name", ""))).is_equal("Арагорн")
	assert_that(str(ch2.entries[1].get("cause", ""))).is_equal("battle")


func test_shards_memory_roundtrip() -> void:
	var mem: Dictionary = {
		"shard_1": {"id": "shard_1", "progress": 2, "max": 5, "unlocked": true},
		"shard_2": {"id": "shard_2", "progress": 0, "max": 3, "unlocked": false},
	}
	var dict := mem.duplicate(true)

	# JSON-цикл (как в SaveData.shards)
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(dict))
	assert_that(roundtrip.size()).is_equal(2)
	assert_that(int(roundtrip["shard_1"]["progress"])).is_equal(2)
	assert_bool(bool(roundtrip["shard_1"]["unlocked"])).is_true()
	assert_bool(bool(roundtrip["shard_2"]["unlocked"]) == false).is_true()


func test_character_registry_roundtrip() -> void:
	var reg := _CharacterRegistry.new()
	var c1 := _Character.new()
	c1.uid = 1
	c1.name = "Мира"
	c1.alive = true
	c1.pop_uid = 10
	var c2 := _Character.new()
	c2.uid = 2
	c2.name = "Бор"
	c2.alive = false
	c2.pop_uid = -1
	reg._characters[c1.uid] = c1
	reg._by_pop[c1.pop_uid] = c1.uid
	reg._characters[c2.uid] = c2
	reg._uid_seq = 3
	assert_that(reg.serialize().size()).is_equal(2)

	var data := reg.serialize()
	var reg2 := _CharacterRegistry.new()
	reg2.deserialize(data)

	var chars := reg2.serialize()
	assert_that(chars.size()).is_equal(2)
	var by_name := {}
	for d in chars:
		by_name[str(d.get("name", ""))] = d
	assert_bool(by_name.has("Мира")).is_true()
	assert_bool(by_name.has("Бор")).is_true()
	assert_bool(bool(by_name["Мира"].get("alive", false))).is_true()
	assert_bool(bool(by_name["Бор"].get("alive", true)) == false).is_true()
	# Живой персонаж находитcя через _by_pop после load
	assert_that(reg2.get_by_pop(10).name).is_equal("Мира")
	# uid-последовательность не регрессирует после load
	assert_that(reg2._uid_seq).is_equal(3)
	var next_uid: int = reg2._next_uid()
	assert_that(next_uid).is_equal(3)
