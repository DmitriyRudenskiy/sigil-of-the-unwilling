extends BaseTest

# Фаза 6 settlement-system: улучшения домов, Unified, торговля, Prestige

const Adv = preload("res://scripts/settlement/SettlementAdvanced.gd")
const Settlement = preload("res://scripts/settlement/Settlement.gd")
const Num = preload("res://scripts/constants/GameNumbersSettlement.gd")

func test_prestige_table_all_levels() -> void:
	for lvl in [1, 2, 5, 6, 7, 8, 9, 10]:
		assert_bool(Adv.prestige_modifiers(lvl).size() > 0).override_failure_message("prestige %d пуст" % lvl)
	assert_that(Adv.prestige_modifiers(3).size()).is_equal(0)

func test_prestige1_reputation_goal() -> void:
	assert_that(Adv.reputation_goal(0)).is_equal(Num.REPUTATION_GOAL)
	assert_that(Adv.reputation_goal(1)).is_equal(Num.REPUTATION_GOAL + 4)

func test_house_upgrade_capacity() -> void:
	var s: Variant = Settlement.new()
	var house: Dictionary = s.add_building("human_house", Vector2i(1, 0))
	assert_that(Adv.house_capacity(house, {})).is_equal(2)
	assert_that(Adv.house_capacity(house, {1: "resolve"})).is_equal(2)
	assert_that(Adv.house_capacity(house, {2: "capacity"})).is_equal(3)

func test_house_upgrade_choices() -> void:
	assert_that(Adv.HOUSE_UPGRADES[1].size()).is_equal(2)
	assert_that(Adv.HOUSE_UPGRADES[2].size()).is_equal(2)

func test_unified_bonus_smaller_than_service() -> void:
	const Resolve = preload("res://scripts/settlement/SettlementResolve.gd")
	assert_bool(Adv.UNIFIED_SERVICE_BONUS < Resolve.BONUS_SERVICE)

func test_trade_post_sells_for_amber() -> void:
	var s: Variant = Settlement.new()
	s.add_building("trading_post", Vector2i(1, 0))
	s.add_resource("planks", 4.0)
	var got := Adv.trade(s, {"planks": 4})
	assert_that(got).is_equal(8)
	assert_that(float(s.state["resources"]["amber"])).is_equal(8.0)

func test_trade_without_post() -> void:
	var s: Variant = Settlement.new()
	s.add_resource("planks", 4.0)
	assert_that(Adv.trade(s, {"planks": 4})).is_equal(0)

func test_prestige10_trade_discount() -> void:
	var s: Variant = Settlement.new()
	s.add_building("trading_post", Vector2i(1, 0))
	s.add_resource("planks", 4.0)
	var got := Adv.trade(s, {"planks": 4}, 10)
	assert_that(got).is_equal(4)  # 8 * 0.5

func test_rainpunk_bonus() -> void:
	var s: Variant = Settlement.new()
	var b: Dictionary = s.add_building("lumber_mill", Vector2i(1, 0))
	assert_that(Adv.rainpunk_bonus(s, b)).is_equal(0.0)
	b["data"]["rainpunk"] = true
	assert_that(Adv.rainpunk_bonus(s, b)).is_equal(Adv.RAINDRINK_RESOLVE)

func test_small_warehouse_flag() -> void:
	var s: Variant = Settlement.new()
	assert_bool(not Adv.has_small_warehouse(s, Vector2i(2, 2)))
	s.add_building("small_warehouse", Vector2i(2, 2))
	assert_bool(Adv.has_small_warehouse(s, Vector2i(2, 2)))
