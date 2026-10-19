"""Проводка T-110 (cutover, раунд 6 §3.2): pending_new_game → кампания.

Юнит-уровень: hero_name собирается в сейв и восстанавливается из него
(roundtrip секции campaign). E2E-потребление профиля навигацией —
test_full_cycle (smoke-контракт).
"""
extends BaseTest


func _composition() -> CampaignComposition:
	var c: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	c.hero_name = "WiredHero"
	return c


func test_hero_name_reaches_save_and_back() -> void:
	var c := _composition()
	var state := c.build_save_state()
	assert_str(str(state.get("campaign", {}).get("hero_name", ""))) \
		.override_failure_message("hero_name не собран в секцию campaign").is_equal("WiredHero")
	c.load_save_state(state)
	assert_str(c.hero_name) \
		.override_failure_message("hero_name не восстановлен из сейва").is_equal("WiredHero")


func test_empty_hero_name_roundtrip() -> void:
	# Без создания (прямой запуск кампании) — пустое имя, roundtrip не ломается.
	var c: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	c.load_save_state(c.build_save_state())
	assert_str(c.hero_name).is_equal("")


## raid-pressure 2.2 (K-R3): «все районы разрушены» — проводка флага в threat-context
## и cooldown ×2.
func test_all_districts_destroyed_flag_and_cooldown() -> void:
	var c := _composition()
	# Старт: есть здания (5 стартовых) → не все разрушены.
	assert_bool(c._all_districts_destroyed()) \
		.override_failure_message("старт с зданиями помечен как все разрушены").is_false()
	assert_bool((c._threat_context() as Dictionary).get("all_districts_destroyed", true)) \
		.override_failure_message("флаг не в threat-context").is_false()

	# Убираем все здания → все 7 групп пусты → все разрушены.
	c.settlement.buildings = []
	assert_bool(c._all_districts_destroyed()) \
		.override_failure_message("пустое поселение не помечено как все разрушены").is_true()
	assert_bool((c._threat_context() as Dictionary).get("all_districts_destroyed", false)) \
		.override_failure_message("флаг не передался в threat-context").is_true()

	# Cooldown ×2 при всех разрушенных (K-R3): 3 → 6.
	assert_int(c.threats.effective_cooldown(true)).is_equal(6)
	assert_int(c.threats.effective_cooldown(false)).is_equal(3)

	# Одно здание любой группы → не все разрушены.
	c.settlement.buildings = [{"id": "farm", "group": "Земледельцы и Пивовары",
		"output_day": {"food": 1.0}, "efficiency": 1.0}]
	assert_bool(c._all_districts_destroyed()) \
		.override_failure_message("один район жив → не все разрушены").is_false()


# --- T-020: регион-граф в составе кампании (сборка, сейв, контекст угроз) ---

func test_region_map_initialized_in_composition() -> void:
	# T-020: регион-граф в составе — герой в городе (R01), туман радиус 1.
	var c := _composition()
	assert_bool(c.region_map != null).is_true()
	assert_str(c.region_map.hero_region).is_equal("R01")
	assert_bool(c.region_map.open_regions.has("R02")).is_true()
	assert_bool(not c.region_map.open_regions.has("R03")).is_true()


func test_region_map_in_save_and_back() -> void:
	# T-020: регион-граф в секции "map".region — roundtrip (позиция + туман).
	var c := _composition()
	c.region_map.food = 10.0  # запас на переход (в кампании старт 0 — до UI-пополнения)
	c.region_map.travel("R02")
	var state := c.build_save_state()
	assert_bool((state.get("map", {}) as Dictionary).has("region")).is_true()
	c.load_save_state(state)
	assert_str(c.region_map.hero_region).is_equal("R02")
	assert_bool(c.region_map.open_regions.has("R03")).is_true()  # туман раскрыт


func test_threat_context_hero_position_from_region_map() -> void:
	# T-020: hero_in_city — из позиции героя (город → бой CR 1/2/6; поход → авто-рейд R5).
	var c := _composition()
	var ctx := c._threat_context()
	assert_bool(ctx.get("hero_in_city", false)).is_true()  # герой в R01 (городе)
	c.region_map.food = 10.0
	c.region_map.travel("R02")
	ctx = c._threat_context()
	assert_bool(ctx.get("hero_in_city", true)).is_false()  # герой в R02 (поход)


func test_old_save_without_region_starts_in_city() -> void:
	# T-020: старый сейв без секции "region" — герой в городе (R01), не fail-fast.
	var c := _composition()
	var state := c.build_save_state()
	(state.get("map", {}) as Dictionary).erase("region")
	c.load_save_state(state)
	assert_str(c.region_map.hero_region).is_equal("R01")
	assert_bool(c.region_map.open_regions.has("R02")).is_true()


## party-characters 3.2 / campaign-core-loop 3.2 (P-4): голод (0 еды) → −2
## к атакам — проводка в бой: у голодного героя margin первого удара ниже
## на |штраф|, чем у сытого (тот же seed, тот же рейд).
func test_hunger_penalty_wired_into_battle() -> void:
	var c1: CampaignComposition = CampaignComposition.from_campaign_config(777)
	var c2: CampaignComposition = CampaignComposition.from_campaign_config(777)
	assert_int(c2.supply_system.food()).is_equal(10)
	c2.supply_system.consume_for_travel(10)  # еда 10 → 0: голод
	assert_bool(c2.supply_system.is_hungry()).is_true()
	var turn := 0
	while c1.last_battle_report.is_empty() and turn < 21:
		turn += 1
		c1.advance_turn()
		c2.advance_turn()
	assert_bool(not c1.last_battle_report.is_empty()) \
		.override_failure_message("до хода 21 боя не было").is_true()
	var m1 := _hero_first_margin(c1.last_battle_report)
	var m2 := _hero_first_margin(c2.last_battle_report)
	assert_int(m2) \
		.override_failure_message("голод: margin героя −2 (P-4)").is_equal(m1 - 2)


func _hero_first_margin(report: Dictionary) -> int:
	for entry in report.get("trace", []):
		var e: Dictionary = entry
		if e.has("margin") and str(e.get("actor", "")) != "raider_t1":
			return int(e["margin"])
	return -999
