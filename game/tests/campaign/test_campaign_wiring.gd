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
