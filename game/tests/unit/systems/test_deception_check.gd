extends BaseTest

const DeceptionCheck = preload("res://scripts/systems/DeceptionCheck.gd")

# social-stats-weapon-tech: DeceptionCheck (D2)

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

func test_chance_low_int_high_risk() -> void:
	# int 5, base 10, без компенсации: 10 + (10-5)*4 = 30
	assert_int(DeceptionCheck.chance(5, 2, 2, 2, 10)).is_equal(30)

func test_chance_wis_compensates() -> void:
	# int 5, wis 14: 30 - 4*2 = 22
	assert_int(DeceptionCheck.chance(5, 14, 2, 2, 10)).is_equal(22)

func test_chance_only_best_compensator_counts() -> void:
	# wis 14 (+4), cha 16 (+6), luk 6 (0) -> max 6 -> 30 - 12 = 18
	assert_int(DeceptionCheck.chance(5, 14, 16, 6, 10)).is_equal(18)

func test_chance_bounds_5_85() -> void:
	# int 1, base 85: 85 + 36 = 121 -> 85
	assert_int(DeceptionCheck.chance(1, 1, 1, 1, 85)).is_equal(85)
	# int 20, wis 20, base 5: 5 - 40 - 20 = -55 -> 5
	assert_int(DeceptionCheck.chance(20, 20, 2, 2, 5)).is_equal(5)

func test_no_deception_when_roll_above_chance() -> void:
	# int 20, wis 20: шанс 5 -> почти всегда не обман
	var deceived: int = 0
	for seed in 50:
		var r := _rng(seed)
		var out: Dictionary = DeceptionCheck.roll(r, 20, 20, 2, 2, 10, 10)
		if bool(out["deceived"]):
			deceived += 1
	assert_bool(deceived <= 3)

func test_deception_happens_with_low_int() -> void:
	# int 2, luk 2, wis 2: шанс 42 -> часть бросков обман
	var deceived: int = 0
	for seed in 50:
		var r := _rng(seed)
		var out: Dictionary = DeceptionCheck.roll(r, 2, 2, 2, 2, 35, 10)
		if bool(out["deceived"]):
			deceived += 1
	assert_bool(deceived > 5)

func test_severity_range_on_deception() -> void:
	# d20-слой, trap_dc 20, int 2: при обмане severity в пределах 1..4
	var saw_deception: bool = false
	for seed in 60:
		var r := _rng(seed)
		var out: Dictionary = DeceptionCheck.roll(r, 2, 2, 2, 2, 85, 20)
		if bool(out["deceived"]):
			saw_deception = true
			assert_bool(int(out["severity"]) >= 1)
			assert_bool(int(out["severity"]) <= 4)
	assert_bool(saw_deception).override_failure_message("no deception in 60 seeds")

func test_critical_margin_gives_severe_or_worse() -> void:
	# d20=1, int 2, wis 2, luk 2, trap_dc 20: margin = 1 - 8 - 20 = -27 -> critical (4)
	var r := _rng(1)
	var out: Dictionary = DeceptionCheck.roll(r, 2, 2, 2, 2, 85, 20)
	if bool(out["deceived"]):
		# при luck 2 save невозможен, при wis 2 notice 0% -> severity >= 3 (margin <= -5)
		assert_int(int(out["severity"])).is_gte(3)

func test_wis_notice_reduces_severity() -> void:
	# wis 20: chance notice = 50% -> если deceived, severity должен быть 1
	var seen_soft: int = 0
	for seed in 40:
		var r := _rng(seed)
		var out: Dictionary = DeceptionCheck.roll(r, 2, 20, 2, 2, 85, 20)
		if bool(out["deceived"]):
			if int(out["severity"]) == 1:
				seen_soft += 1
	assert_bool(seen_soft >= 1)

func test_luk_saves_or_reveals() -> void:
	# luk 20: 50% спас -> revealed
	var revealed: int = 0
	for seed in 40:
		var r := _rng(seed)
		var out: Dictionary = DeceptionCheck.roll(r, 2, 2, 2, 20, 85, 20)
		if bool(out["revealed"]):
			revealed += 1
	assert_bool(revealed >= 1)

func test_cha_discount() -> void:
	var out: Dictionary = DeceptionCheck.roll(_rng(7), 10, 10, 16, 2, 10, 10)
	assert_bool(float(out["discount"]) > 0.0)
	var out2: Dictionary = DeceptionCheck.roll(_rng(7), 10, 10, 10, 2, 10, 10)
	assert_int(int(float(out2["discount"]) * 100)).is_equal(0)

func test_determinism_by_seed() -> void:
	var a: Dictionary = DeceptionCheck.roll(_rng(42), 6, 12, 14, 10, 35, 14)
	var b: Dictionary = DeceptionCheck.roll(_rng(42), 6, 12, 14, 10, 35, 14)
	assert_dict(a).is_equal(b)

func test_severity_labels_exist() -> void:
	assert_that(DeceptionCheck.severity_label(1)).is_not_empty().override_failure_message("label1")
	assert_that(DeceptionCheck.severity_label(4)).is_not_empty().override_failure_message("label4")
	assert_that(DeceptionCheck.severity_label(99)).is_empty().override_failure_message("label99")
