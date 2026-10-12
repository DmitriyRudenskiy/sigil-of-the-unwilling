extends BaseTest

const FactionReputation = preload("res://scripts/systems/faction_reputation.gd")
## quests-reputation-system 1.3: уровни, модификаторы, бонусы, clamp, история.

func test_bands() -> void:
	assert_bool(bool(FactionReputation.band(-100) == FactionReputation.Band.ENEMY)).is_true()
	assert_bool(bool(FactionReputation.band(-50) == FactionReputation.Band.ENEMY)).is_true()
	assert_bool(bool(FactionReputation.band(-49) == FactionReputation.Band.HOSTILE)).is_true()
	assert_bool(bool(FactionReputation.band(-10) == FactionReputation.Band.HOSTILE)).is_true()
	assert_bool(bool(FactionReputation.band(-9) == FactionReputation.Band.NEUTRAL)).is_true()
	assert_bool(bool(FactionReputation.band(0) == FactionReputation.Band.NEUTRAL)).is_true()
	assert_bool(bool(FactionReputation.band(9) == FactionReputation.Band.NEUTRAL)).is_true()
	assert_bool(bool(FactionReputation.band(10) == FactionReputation.Band.FRIENDLY)).is_true()
	assert_bool(bool(FactionReputation.band(49) == FactionReputation.Band.FRIENDLY)).is_true()
	assert_bool(bool(FactionReputation.band(50) == FactionReputation.Band.ALLY)).is_true()
	assert_bool(bool(FactionReputation.band(100) == FactionReputation.Band.ALLY)).is_true()

func test_band_names() -> void:
	assert_bool(bool(FactionReputation.band_name(-50) == "Враг")).is_true()
	assert_bool(bool(FactionReputation.band_name(-10) == "Недруг")).is_true()
	assert_bool(bool(FactionReputation.band_name(0) == "Нейтрал")).is_true()
	assert_bool(bool(FactionReputation.band_name(10) == "Друг")).is_true()
	assert_bool(bool(FactionReputation.band_name(50) == "Союзник")).is_true()

func test_price_multipliers() -> void:
	assert_bool(bool(is_equal_approx(FactionReputation.price_multiplier(100), 0.8))).is_true()
	assert_bool(bool(is_equal_approx(FactionReputation.price_multiplier(10), 0.9))).is_true()
	assert_bool(bool(is_equal_approx(FactionReputation.price_multiplier(0), 1.0))).is_true()
	assert_bool(bool(is_equal_approx(FactionReputation.price_multiplier(-10), 1.25))).is_true()
	assert_bool(bool(is_equal_approx(FactionReputation.price_multiplier(-50), 1.5))).is_true()

func test_can_hire() -> void:
	assert_bool(FactionReputation.can_hire(10))
	assert_bool(FactionReputation.can_hire(100))
	assert_bool(FactionReputation.can_hire(9) == false)
	assert_bool(FactionReputation.can_hire(-100) == false)

func test_initial_state_race_bonus() -> void:
	var s: Dictionary = FactionReputation.initial_state("elf", "fighter")
	assert_bool(bool(int(s["elf"]) == 10)).is_true()
	assert_bool(bool(int(s["human"]) == 0)).is_true()
	assert_bool(bool(s.size() == 6)).is_true()

func test_initial_state_class_bonus() -> void:
	var s: Dictionary = FactionReputation.initial_state("human", "priest")
	assert_bool(bool(int(s["godlike"]) == 5)).is_true()
	var s2: Dictionary = FactionReputation.initial_state("human", "fighter")
	assert_bool(bool(int(s2["godlike"]) == 0)).is_true()

func test_initial_state_combined() -> void:
	var s: Dictionary = FactionReputation.initial_state("godlike", "priest")
	assert_bool(bool(int(s["godlike"]) == 15)).is_true()

func test_apply_clamp() -> void:
	var s := {"human": 90}
	FactionReputation.apply(s, "human", 50, "elf")
	assert_bool(bool(int(s["human"]) == 100)).is_true()
	var s2 := {"human": -90}
	FactionReputation.apply(s2, "human", -50, "elf")
	assert_bool(bool(int(s2["human"]) == -100)).is_true()

func test_apply_race_bonus() -> void:
	var s := {"elf": 0}
	FactionReputation.apply(s, "elf", 10, "elf")
	# 10 * 1.1 = 11
	assert_bool(bool(int(s["elf"]) == 11)).is_true()
	# Неродная фракция — без бонуса
	var s2 := {"elf": 0}
	FactionReputation.apply(s2, "elf", 10, "human")
	assert_bool(bool(int(s2["elf"]) == 10)).is_true()
	# Отрицательный дельта не получает бонуса
	var s3 := {"elf": 0}
	FactionReputation.apply(s3, "elf", -10, "elf")
	assert_bool(bool(int(s3["elf"]) == -10)).is_true()

func test_history_limit() -> void:
	var h := []
	for i in range(25):
		FactionReputation.log(h, "human", 1, "test")
	assert_bool(bool(h.size() == 20)).is_true()
	# Старые записи отброшены
	assert_bool(bool(str(h[0]).begins_with("human|1|test"))).is_true()
	assert_bool(bool(str(h[19]).begins_with("human|1|test"))).is_true()

func test_event_deltas() -> void:
	assert_bool(bool(FactionReputation.event_delta("quest_done") > 0)).is_true()
	assert_bool(bool(FactionReputation.event_delta("quest_failed") < 0)).is_true()
	assert_bool(bool(FactionReputation.event_delta("escort_dead") == -20)).is_true()
	assert_bool(bool(FactionReputation.event_delta("unknown_event") == 0)).is_true()
