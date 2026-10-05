extends BaseTest
## Q-M26 (владелец 2026-10-05): 1 ход = 1 сезон; TURN_LENGTH аннулирован как
## «дней в ходе»; DAYS_PER_SEASON = 20 — баланс-конфиг (07-balance §2).

func before_test() -> void:
	WorldSeasons.reset()

func after_test() -> void:
	WorldSeasons.reset()


func test_season_equals_turn() -> void:
	# Ход 1 = Ясный, ход 2 = Морось, ход 3 = Буря, ход 4 = Ясный (цикл 3).
	for expected in [0, 1, 2, 0, 1, 2]:
		WorldSeasons.advance_turn()
		assert_that(WorldSeasons.season_index()).is_equal(expected)
	assert_that(WorldSeasons.season_name()).is_equal("Буря")
	assert_float(WorldSeasons.production_mult()).is_equal(0.4)
	assert_float(WorldSeasons.enemy_mult()).is_equal(1.25)


func test_turn_21_is_storm() -> void:
	# Финальный ход кампании (21) = Буря: (21-1) % 3 = 2.
	for i in 21:
		WorldSeasons.advance_turn()
	assert_that(WorldSeasons.season_index()).is_equal(2)
	assert_that(WorldSeasons.season_name()).is_equal("Буря")


func test_initial_state_is_clear() -> void:
	assert_that(WorldSeasons.season_index()).is_equal(0)
	assert_that(WorldSeasons.season_name()).is_equal("Ясный сезон")
	assert_float(WorldSeasons.production_mult()).is_equal(1.0)


func test_days_per_season_constant() -> void:
	# Баланс-конфиг (07-balance §2): 1 ход = 20 дней. Единственная конверсия.
	assert_int(WorldSeasons.DAYS_PER_SEASON).is_equal(20)


func test_set_turns_roundtrip() -> void:
	WorldSeasons.set_turns(47)
	assert_that(WorldSeasons.get_turns()).is_equal(47)
	# (47-1) % 3 = 1 → Морось
	assert_that(WorldSeasons.season_index()).is_equal(1)
	assert_float(WorldSeasons.production_mult()).is_equal(1.2)
	WorldSeasons.set_turns(-5)
	assert_that(WorldSeasons.get_turns()).is_equal(0)
