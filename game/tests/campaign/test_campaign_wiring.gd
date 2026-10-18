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
