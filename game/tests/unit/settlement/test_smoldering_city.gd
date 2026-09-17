extends BaseTest

# Фаза 5 settlement-system: Smoldering City, апгрейды, meta-сейв

const SC = preload("res://scripts/settlement/SmolderingCity.gd")
const Settlement = preload("res://scripts/settlement/Settlement.gd")
const Upgrades = preload("res://scripts/data/smoldering_upgrades.gd")

func _meta(tablets := 100, level := 1) -> Dictionary:
	var m: Dictionary = SC.fresh_state()
	m["tablets"] = tablets
	m["level"] = level
	return m

func test_settle_share_defeat_half() -> void:
	var s: Variant = Settlement.new()
	s.add_resource("ancient_tablets", 10.0)
	assert_that(SC.settle_share(s)).is_equal(5.0)

func test_settle_share_victory_full() -> void:
	var s: Variant = Settlement.new()
	s.add_resource("ancient_tablets", 10.0)
	s.state["victory"] = true
	assert_that(SC.settle_share(s)).is_equal(10.0)

func test_on_settlement_ended_victory_raises_level() -> void:
	var m := _meta(0, 3)
	var s: Variant = Settlement.new()
	s.state["victory"] = true
	s.add_resource("ancient_tablets", 4.0)
	SC.on_settlement_ended(m, s)
	assert_that(int(m["tablets"])).is_equal(4)
	assert_that(int(m["level"])).is_equal(4)
	assert_that(int(m["victories"])).is_equal(1)

func test_frog_unlock_at_level_9() -> void:
	var m := _meta(0, 8)
	assert_bool(not bool(m["purchased"].get("frog_species", false)))
	m["level"] = 9
	SC.on_settlement_ended(m, _settle_won())
	assert_bool(bool(m["purchased"].get("frog_species", false)))

func test_buy_requires_level_and_dlc() -> void:
	var m := _meta(100, 5)
	# bat: level 11 + DLC
	assert_bool(not SC.can_buy(m, "bat_species"))
	m["level"] = 11
	assert_bool(not SC.can_buy(m, "bat_species"))  # нет DLC
	m["dlc"]["nightwatchers"] = true
	assert_bool(SC.can_buy(m, "bat_species"))
	assert_bool(SC.buy(m, "bat_species"))
	assert_that(int(m["tablets"])).is_equal(80)
	assert_bool(not SC.can_buy(m, "bat_species"))  # уже куплено

func test_buy_insufficient_tablets() -> void:
	var m := _meta(3, 1)
	assert_bool(not SC.can_buy(m, "vanguard_spire"))  # стоит 5
	assert_bool(not SC.buy(m, "vanguard_spire"))
	assert_that(int(m["tablets"])).is_equal(3)

func test_meta_for_buildings_vanguard() -> void:
	var m := _meta(100, 4)
	m["purchased"]["vanguard_spire"] = true
	var mb: Dictionary = SC.meta_for_buildings(m)
	assert_that(int(mb["vanguard_level"])).is_equal(4)
	assert_that(int(mb["smoldering_level"])).is_equal(4)

func test_meta_save_load_roundtrip() -> void:
	var m := _meta(42, 7)
	m["purchased"]["vanguard_spire"] = true
	SC.save(m)
	var loaded: Dictionary = SC.load()
	assert_that(int(loaded["tablets"])).is_equal(42)
	assert_that(int(loaded["level"])).is_equal(7)
	assert_bool(bool(loaded["purchased"].get("vanguard_spire", false)))
	# очистка после теста
	DirAccess.remove_absolute(SC.SAVE_PATH)

func test_load_missing_returns_fresh() -> void:
	DirAccess.remove_absolute(SC.SAVE_PATH)
	var m: Dictionary = SC.load()
	assert_that(int(m["tablets"])).is_equal(0)
	assert_that(int(m["level"])).is_equal(1)

func _settle_won() -> Variant:
	var s: Variant = Settlement.new()
	s.state["victory"] = true
	return s
