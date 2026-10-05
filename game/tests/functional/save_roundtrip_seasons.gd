extends BaseTest
## save-load-coverage-expansion 3.2: WorldSeasons._turns_in_season (static)
## переживает save/load через WorldStateDelta.season_turns.

const _WorldStateDelta = preload("res://scripts/world/world_state_delta.gd")


func before_test() -> void:
	WorldSeasons.reset()


func after_test() -> void:
	WorldSeasons.reset()


func test_season_turns_roundtrip_through_delta() -> void:
	# 47 ходов → season_index = (47-1) % 3 = 1 (Морось; Q-M26: 1 ход = 1 сезон)
	for i in 47:
		WorldSeasons.advance_turn()
	var idx_before := WorldSeasons.season_index()
	var hostility_before := WorldSeasons.hostility_mult()

	# save: persistence кладёт счётчик в world-state
	var delta := _WorldStateDelta.new()
	delta.season_turns = WorldSeasons.get_turns()
	var dict := delta.serialize()

	# load: новый процесс (эмуляция — сбросим static)
	WorldSeasons.reset()
	assert_that(WorldSeasons.get_turns()).is_equal(0)

	var delta2 := _WorldStateDelta.new()
	delta2.deserialize(dict)
	WorldSeasons.set_turns(delta2.season_turns)

	assert_that(WorldSeasons.get_turns()).is_equal(47)
	assert_that(WorldSeasons.season_index()).is_equal(idx_before)
	assert_float(WorldSeasons.hostility_mult()).is_equal(hostility_before)


func test_legacy_save_without_season_turns_defaults_zero() -> void:
	# Сейв до 3.2 не имеет ключа season_turns — трактуем как 0 (сезон сбрасывается).
	WorldSeasons.advance_turn()
	WorldSeasons.advance_turn()
	var delta := _WorldStateDelta.new()
	var dict := delta.serialize()
	dict.erase("season_turns")  # эмуляция legacy-формата

	var delta2 := _WorldStateDelta.new()
	delta2.deserialize(dict)
	assert_that(delta2.season_turns).is_equal(0)

	WorldSeasons.set_turns(delta2.season_turns)
	assert_that(WorldSeasons.season_index()).is_equal(0)
	assert_float(WorldSeasons.hostility_mult()).is_equal(WorldSeasons.HOSTILITY_BASE)


func test_set_turns_clamps_negative() -> void:
	WorldSeasons.set_turns(-5)
	assert_that(WorldSeasons.get_turns()).is_equal(0)


func test_season_mult_preserved_across_roundtrip() -> void:
	# Морось (индекс 1): множитель продуктивности 1.2; 26 ходов → (26-1) % 3 = 1 (Q-M26)
	for i in 26:
		WorldSeasons.advance_turn()
	var mult_before := WorldSeasons.production_mult()

	var delta := _WorldStateDelta.new()
	delta.season_turns = WorldSeasons.get_turns()
	var dict := delta.serialize()

	WorldSeasons.reset()
	var delta2 := _WorldStateDelta.new()
	delta2.deserialize(dict)
	WorldSeasons.set_turns(delta2.season_turns)

	assert_float(WorldSeasons.production_mult()).is_equal(mult_before)
	assert_float(WorldSeasons.production_mult()).is_equal(1.2)
