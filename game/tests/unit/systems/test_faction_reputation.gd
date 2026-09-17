extends BaseTest

const FactionReputation = preload("res://scripts/systems/FactionReputation.gd")
## quests-reputation-system 1.3: уровни, модификаторы, бонусы, clamp, история.

func test_bands() -> void:
	assert_that(FactionReputation.band(-100) == FactionReputation.Band.ENEMY)
	assert_that(FactionReputation.band(-50) == FactionReputation.Band.ENEMY)
	assert_that(FactionReputation.band(-49) == FactionReputation.Band.HOSTILE)
	assert_that(FactionReputation.band(-10) == FactionReputation.Band.HOSTILE)
	assert_that(FactionReputation.band(-9) == FactionReputation.Band.NEUTRAL)
	assert_that(FactionReputation.band(0) == FactionReputation.Band.NEUTRAL)
	assert_that(FactionReputation.band(9) == FactionReputation.Band.NEUTRAL)
	assert_that(FactionReputation.band(10) == FactionReputation.Band.FRIENDLY)
	assert_that(FactionReputation.band(49) == FactionReputation.Band.FRIENDLY)
	assert_that(FactionReputation.band(50) == FactionReputation.Band.ALLY)
	assert_that(FactionReputation.band(100) == FactionReputation.Band.ALLY)

func test_band_names() -> void:
	assert_that(FactionReputation.band_name(-50) == "Враг")
	assert_that(FactionReputation.band_name(-10) == "Недруг")
	assert_that(FactionReputation.band_name(0) == "Нейтрал")
	assert_that(FactionReputation.band_name(10) == "Друг")
	assert_that(FactionReputation.band_name(50) == "Союзник")

func test_price_multipliers() -> void:
	assert_that(is_equal_approx(FactionReputation.price_multiplier(100), 0.8))
	assert_that(is_equal_approx(FactionReputation.price_multiplier(10), 0.9))
	assert_that(is_equal_approx(FactionReputation.price_multiplier(0), 1.0))
	assert_that(is_equal_approx(FactionReputation.price_multiplier(-10), 1.25))
	assert_that(is_equal_approx(FactionReputation.price_multiplier(-50), 1.5))

func test_can_hire() -> void:
	assert_bool(FactionReputation.can_hire(10))
	assert_bool(FactionReputation.can_hire(100))
	assert_bool(FactionReputation.can_hire(9) == false)
	assert_bool(FactionReputation.can_hire(-100) == false)

func test_initial_state_race_bonus() -> void:
	var s: Dictionary = FactionReputation.initial_state("elf", "fighter")
	assert_that(int(s["elf"]) == 10)
	assert_that(int(s["human"]) == 0)
	assert_that(s.size() == 6)

func test_initial_state_class_bonus() -> void:
	var s: Dictionary = FactionReputation.initial_state("human", "priest")
	assert_that(int(s["godlike"]) == 5)
	var s2: Dictionary = FactionReputation.initial_state("human", "fighter")
	assert_that(int(s2["godlike"]) == 0)

func test_initial_state_combined() -> void:
	var s: Dictionary = FactionReputation.initial_state("godlike", "priest")
	assert_that(int(s["godlike"]) == 15)

func test_apply_clamp() -> void:
	var s := {"human": 90}
	FactionReputation.apply(s, "human", 50, "elf")
	assert_that(int(s["human"]) == 100)
	var s2 := {"human": -90}
	FactionReputation.apply(s2, "human", -50, "elf")
	assert_that(int(s2["human"]) == -100)

func test_apply_race_bonus() -> void:
	var s := {"elf": 0}
	FactionReputation.apply(s, "elf", 10, "elf")
	# 10 * 1.1 = 11
	assert_that(int(s["elf"]) == 11)
	# Неродная фракция — без бонуса
	var s2 := {"elf": 0}
	FactionReputation.apply(s2, "elf", 10, "human")
	assert_that(int(s2["elf"]) == 10)
	# Отрицательный дельта не получает бонуса
	var s3 := {"elf": 0}
	FactionReputation.apply(s3, "elf", -10, "elf")
	assert_that(int(s3["elf"]) == -10)

func test_history_limit() -> void:
	var h := []
	for i in range(25):
		FactionReputation.log(h, "human", 1, "test")
	assert_that(h.size() == 20)
	# Старые записи отброшены
	assert_that(str(h[0]).begins_with("human|1|test"))
	assert_that(str(h[19]).begins_with("human|1|test"))

func test_event_deltas() -> void:
	assert_that(FactionReputation.event_delta("quest_done") > 0)
	assert_that(FactionReputation.event_delta("quest_failed") < 0)
	assert_that(FactionReputation.event_delta("escort_dead") == -20)
	assert_that(FactionReputation.event_delta("unknown_event") == 0)
