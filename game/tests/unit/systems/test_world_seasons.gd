extends BaseTest
## Q-M26 (закрыто, 10-я итерация §2.3) + Q-M27 (закрыто, 11-я итерация §1.1):
## 1 ход = 1 сезон, цикл 4 (Весна→Лето→Осень→Зима), ход 1 = Весна,
## season_index = (turns − 1) % 4, DAYS_PER_SEASON = 20 (баланс-конфиг,
## 07-balance §2; независимые день-константы запрещены).
## Q-M29 (закрыто, 12-я итерация §1: вариант (а) — формула — канон, «зима» — описка):
## ход 21 = Весна (20 % 4 = 0); зимние ходы 4/8/12/16/20 — enemy_mult 1.25;
## финальный рейд (21) — без сезонного бонуса, сложность тиром волны (K-T5).
## I1: детерминизм (без ГСЧ).

func before_test() -> void:
	WorldSeasons.reset()

func after_test() -> void:
	WorldSeasons.reset()


func test_season_equals_turn_four_cycle() -> void:
	# Ход 1 = Весна, 2 = Лето, 3 = Осень, 4 = Зима, 5 = Весна (год, GDD §6).
	for expected in [0, 1, 2, 3, 0, 1, 2, 3]:
		WorldSeasons.advance_turn()
		assert_that(WorldSeasons.season_index()).is_equal(expected)
	assert_that(WorldSeasons.season_name()).is_equal("Зима")
	assert_float(WorldSeasons.production_mult()).is_equal(0.4)
	assert_float(WorldSeasons.enemy_mult()).is_equal(1.25)


func test_turn21_is_spring_per_formula() -> void:
	# Канон (Q-M29, закрыто, 12-я итерация §1, вариант (а)): формула (turns − 1) % 4 —
	# канон; ход 21 → 20 % 4 = 0 → Весна. «Ход 21 = зима» в резолюции Q-M27 — описка.
	# Финальный рейд (21) — без сезонного бонуса, сложность тиром волны (K-T5);
	# зимние ходы 4/8/12/16/20 — enemy_mult 1.25 (07-balance §6).
	for i in 21:
		WorldSeasons.advance_turn()
	assert_that(WorldSeasons.season_index()).is_equal(0)
	assert_that(WorldSeasons.season_name()).is_equal("Весна")
	# Зима — ход 20 (канун финала): последний зимний ход кампании.
	WorldSeasons.set_turns(20)
	assert_that(WorldSeasons.season_name()).is_equal("Зима")


func test_initial_state_is_spring() -> void:
	# Ход 0 (до первого advance) — первый сезон, без отрицательного индекса.
	assert_that(WorldSeasons.season_index()).is_equal(0)
	assert_that(WorldSeasons.season_name()).is_equal("Весна")


func test_days_per_season_balance_config() -> void:
	# Баланс-конфиг 07-balance §2: 1 ход = 20 дней (Q-M26).
	assert_int(WorldSeasons.DAYS_PER_SEASON).is_equal(20)
	assert_bool(WorldSeasons.DAYS_PER_SEASON > 0).is_true()


func test_season_mults_from_balance_table() -> void:
	# Числа — 07-balance §6 (сезонная таблица): перенос 3-сезонной
	# (Ясный→весна 1.0/1.0, Морось→лето 1.2/1.0, Буря→зима 0.4/1.25),
	# осень нейтральная. Якорь: зима < весна (GDD §6).
	WorldSeasons.set_turns(1)  # Весна
	assert_float(WorldSeasons.production_mult()).is_equal(1.0)
	assert_float(WorldSeasons.enemy_mult()).is_equal(1.0)
	WorldSeasons.set_turns(2)  # Лето
	assert_float(WorldSeasons.production_mult()).is_equal(1.2)
	WorldSeasons.set_turns(3)  # Осень
	assert_float(WorldSeasons.production_mult()).is_equal(1.0)
	WorldSeasons.set_turns(4)  # Зима
	assert_float(WorldSeasons.production_mult()).is_equal(0.4)
	assert_float(WorldSeasons.enemy_mult()).is_equal(1.25)
	# Якорь: зима < весна (GDD §6 «зима сокращает сбор еды»).
	var winter: Dictionary = WorldSeasons.SEASONS[3]
	var spring: Dictionary = WorldSeasons.SEASONS[0]
	assert_float(spring["prod_mult"]).is_greater(winter["prod_mult"])
