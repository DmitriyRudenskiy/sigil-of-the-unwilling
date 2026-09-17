extends BaseTest

# Фаза 4 settlement-system: Demand/Decadence, Hostility, шторм, победа/поражение

const Settlement = preload("res://scripts/settlement/Settlement.gd")
const Rep = preload("res://scripts/settlement/SettlementReputation.gd")
const Num = preload("res://scripts/constants/GameNumbersSettlement.gd")

func _settle() -> Variant:
	var s: Variant = Settlement.new()
	s.add_settler("human")
	s.add_settler("lizard")
	return s

func test_demand_generates_points() -> void:
	var s: Variant = _settle()
	for st in s.state["settlers"]:
		st["resolve"] = 40.0  # > human demand 30
	Rep.on_day_passed(s, _rng(1))
	var rep: Dictionary = s.state["reputation"]["human"]
	assert_that(int(rep["points"])).is_equal(1)
	# порог снижен на Decadence (4): 30 -> 26
	assert_that(int(rep["demand_threshold"])).is_equal(26)

func test_low_resolve_no_points() -> void:
	var s: Variant = _settle()
	for st in s.state["settlers"]:
		st["resolve"] = 5.0
	Rep.on_day_passed(s, _rng(1))
	assert_that(int(s.state["reputation"]["human"]["points"])).is_equal(0)

func test_hostility_formula() -> void:
	var s: Variant = _settle()
	s.state["day"] = 30  # 1 год
	s.state["glades_opened"] = 2
	s.add_building("woodcutters_camp", Vector2i(1, 0))
	Rep.on_day_passed(s, _rng(1))
	# год 2 + поселенцы 2*1 + glades 2*3 + лесорубы 1 = 11
	assert_that(int(s.state["hostility"])).is_equal(11)

func test_small_hearth_reduces_hostility() -> void:
	var s: Variant = _settle()
	s.add_building("small_hearth", Vector2i(1, 0))
	s.add_building("small_hearth", Vector2i(2, 0))
	Rep.on_day_passed(s, _rng(1))
	# 2 поселенца - 4 = 0 (maxi 0)
	assert_that(int(s.state["hostility"])).is_equal(0)

func test_storm_causes_exodus() -> void:
	var s: Variant = _settle()
	for st in s.state["settlers"]:
		st["resolve"] = 1.0  # ниже STORM_EXODUS_RESOLVE после штрафа
	Rep.on_day_passed(s, _rng(99), true)
	assert_that(s.state["settlers"].size()).is_equal(0)
	assert_that(s.state["defeat"]).is_equal("no_settlers")

func test_storm_burns_woodcutters() -> void:
	var s: Variant = _settle()
	for st in s.state["settlers"]:
		st["resolve"] = 50.0
	s.add_building("woodcutters_camp", Vector2i(1, 0))
	Rep.on_day_passed(s, _rng(99), true)
	assert_that(s.buildings_of("woodcutters_camp").size()).is_equal(0)

func test_defeat_instability() -> void:
	var s: Variant = _settle()
	for st in s.state["settlers"]:
		st["resolve"] = 500.0  # выживут шторм
	s.state["glades_opened"] = 50  # hostility = 100+
	Rep.on_day_passed(s, _rng(1))
	assert_that(s.state["defeat"]).is_equal("instability")

func test_victory_at_goal() -> void:
	var s: Variant = _settle()
	s.state["reputation"] = {"human": {"points": Num.REPUTATION_GOAL, "demand_threshold": 0, "decadence_spent": 0}}
	assert_bool(Rep.victory_reached(s))

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r
