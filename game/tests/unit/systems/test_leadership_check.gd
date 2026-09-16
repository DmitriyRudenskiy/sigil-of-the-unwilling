extends BaseTest

# social-stats-weapon-tech: LeadershipCheck (D3)

const LeadershipCheck = preload("res://scripts/systems/LeadershipCheck.gd")

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

func test_immigration_modifier_thresholds() -> void:
	# cha 1..3 -> 0.5, cha 4..5 -> 0.65, cha 6..7 -> 0.8, cha 10 -> 1.0, cha 12 -> 1.1, cha 15 -> 1.2, cha 17 -> 1.35, cha 20 -> 1.5
	assert_float(LeadershipCheck.immigration_modifier(1)).is_equal(0.5)
	assert_float(LeadershipCheck.immigration_modifier(3)).is_equal(0.5)
	assert_float(LeadershipCheck.immigration_modifier(4)).is_equal(0.65)
	assert_float(LeadershipCheck.immigration_modifier(6)).is_equal(0.8)
	assert_float(LeadershipCheck.immigration_modifier(10)).is_equal(1.0)
	assert_float(LeadershipCheck.immigration_modifier(12)).is_equal(1.1)
	assert_float(LeadershipCheck.immigration_modifier(15)).is_equal(1.2)
	assert_float(LeadershipCheck.immigration_modifier(17)).is_equal(1.35)
	assert_float(LeadershipCheck.immigration_modifier(20)).is_equal(1.5)
	# за пределами таблицы — кламп
	assert_float(LeadershipCheck.immigration_modifier(0)).is_equal(0.5)
	assert_float(LeadershipCheck.immigration_modifier(99)).is_equal(1.5)

func test_max_army_stacks_min_3() -> void:
	assert_int(LeadershipCheck.max_army_stacks(1)).is_equal(3)  # таблица 1 -> min 3
	assert_int(LeadershipCheck.max_army_stacks(7)).is_equal(3)
	assert_int(LeadershipCheck.max_army_stacks(10)).is_equal(3)
	assert_int(LeadershipCheck.max_army_stacks(11)).is_equal(4)
	assert_int(LeadershipCheck.max_army_stacks(17)).is_equal(6)
	assert_int(LeadershipCheck.max_army_stacks(20)).is_equal(7)
	assert_int(LeadershipCheck.max_army_stacks(99)).is_equal(7)

func test_recruit_quality_thresholds() -> void:
	assert_float(LeadershipCheck.recruit_quality(1)).is_equal(0.8)
	assert_float(LeadershipCheck.recruit_quality(6)).is_equal(1.0)
	assert_float(LeadershipCheck.recruit_quality(11)).is_equal(1.1)
	assert_float(LeadershipCheck.recruit_quality(14)).is_equal(1.2)
	assert_float(LeadershipCheck.recruit_quality(17)).is_equal(1.25)
	assert_float(LeadershipCheck.recruit_quality(99)).is_equal(1.25)

func test_recruit_check_success_high_cha() -> void:
	# cha 20, rep 20, militia (DC 10): почти всегда успех
	var refused: int = 0
	for seed in 50:
		var out := LeadershipCheck.recruit_check(_rng(seed), 20, 20, 1, "militia")
		if str(out["outcome"]) == "refused":
			refused += 1
	assert_int(refused).is_equal(0)

func test_recruit_check_refused_low_cha_hard_dc() -> void:
	# cha 2, rep -20, champion (DC 20): почти всегда отказ
	var refused: int = 0
	for seed in 50:
		var out := LeadershipCheck.recruit_check(_rng(seed), 2, -20, 1, "champion")
		if str(out["outcome"]) == "refused":
			refused += 1
	assert_bool(refused > 30)

func test_recruit_check_rumor_near_dc() -> void:
	# total чуть ниже DC -> rumor с rep_delta -5
	var saw_rumor: bool = false
	for seed in 60:
		var out := LeadershipCheck.recruit_check(_rng(seed), 10, 0, 0, "veteran")
		if str(out["outcome"]) == "rumor":
			saw_rumor = true
			assert_int(int(out["rep_delta"])).is_equal(-5)
	assert_bool(saw_rumor)

func test_recruit_check_critical_natural_1() -> void:
	# d20=1 -> critical, rep -10
	var saw_critical: bool = false
	for seed in 60:
		var out := LeadershipCheck.recruit_check(_rng(seed), 2, -20, 0, "champion")
		if int(out["d20"]) == 1:
			saw_critical = true
			assert_that(out["outcome"]).is_equal("critical")
			assert_int(int(out["rep_delta"])).is_equal(-10)
	assert_bool(saw_critical)

func test_recruit_check_rep_bonus_bounds() -> void:
	# rep 100 -> +3, rep -100 -> -3 (кламп)
	var hi := LeadershipCheck.recruit_check(_rng(5), 10, 100, 0, "militia")
	var lo := LeadershipCheck.recruit_check(_rng(5), 10, -100, 0, "militia")
	assert_int(int(hi["total"]) - int(lo["total"])).is_equal(6)

func test_recruit_check_offers_bonus_capped() -> void:
	var a := LeadershipCheck.recruit_check(_rng(9), 10, 0, 3, "militia")
	var b := LeadershipCheck.recruit_check(_rng(9), 10, 0, 10, "militia")
	assert_int(int(a["total"])).is_equal(int(b["total"]))

func test_recruit_check_determinism() -> void:
	var a := LeadershipCheck.recruit_check(_rng(42), 12, 5, 2, "hunter")
	var b := LeadershipCheck.recruit_check(_rng(42), 12, 5, 2, "hunter")
	assert_dict(a).is_equal(b)

func test_unknown_difficulty_defaults_10() -> void:
	var out := LeadershipCheck.recruit_check(_rng(3), 10, 0, 0, "nonexistent")
	assert_int(int(out["dc"])).is_equal(10)
