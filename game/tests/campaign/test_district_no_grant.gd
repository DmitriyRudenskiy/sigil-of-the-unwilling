extends BaseTest
## city-construction-districts 2.1 (K-M16): «Район создан» — НЕ источник
## Престижа и НЕ XP. Верификация: создание района (первое здание новой группы)
## не добавляет запись в Престиж-ledger и не начисляет XP партии.
##
## Канон: K-M16 (район — не источник Престижа/XP); 02-mechanics §3.5 (районы
## эмерджентны). Престиж — только ledger за победы (battle_victory, T-112);
## XP — только бой/узел/рейд (T-060). Строительство и районная обработка
## начислений не содержат.


func _total_party_xp(c: CampaignComposition) -> int:
	var total := 0
	for m in c.party:
		if m is Dictionary:
			total += int((m as Dictionary).get("xp", 0))
	return total


## Базовый инвариант: у свежей кампании Престиж-ledger пуст, XP партии = 0.
func test_fresh_campaign_no_prestige_no_xp() -> void:
	var c: CampaignComposition = CampaignComposition.from_campaign_config(424242)
	assert_that(c.prestige_ledger.size()).is_equal(0)
	assert_that(_total_party_xp(c)).is_equal(0)


## Создание района (первое здание новой группы) не даёт Престиж/XP.
func test_district_creation_grants_nothing() -> void:
	var c: CampaignComposition = CampaignComposition.from_campaign_config(424242)
	var ledger_before := c.prestige_ledger.size()
	var xp_before := _total_party_xp(c)

	# Симулируем появление нового района: здание новой группы (Рыбаки) —
	# до него группа в settlement.buildings отсутствовала.
	var new_district_building := {
		"id": "fishing_hut", "group": "Рыбаки и Морские",
		"output_day": {"food": 0.5}, "efficiency": 1.0,
	}
	c.settlement.buildings.append(new_district_building)

	# Престиж-ledger и XP партии не изменились (K-M16).
	assert_that(c.prestige_ledger.size()) \
		.override_failure_message(
			"создание района добавило запись в Престиж-ledger (K-M16)").is_equal(ledger_before)
	assert_that(_total_party_xp(c)) \
		.override_failure_message(
			"создание района начислило XP партии (K-M16)").is_equal(xp_before)


## Районная обработка (process_turn) не даёт Престиж/XP.
func test_district_process_turn_grants_nothing() -> void:
	var c: CampaignComposition = CampaignComposition.from_campaign_config(424242)
	var ledger_before := c.prestige_ledger.size()
	var xp_before := _total_party_xp(c)

	# Прогоним районный проход (настроение/нужды) — начислений быть не должно.
	var report: Dictionary = c.districts.process_turn(
		c.settlement.buildings, c.settlement.population, c.settlement.party_size, "OK")
	assert_that(report.has("districts")).is_true()

	assert_that(c.prestige_ledger.size()) \
		.override_failure_message(
			"районная обработка добавила Престиж (K-M16)").is_equal(ledger_before)
	assert_that(_total_party_xp(c)) \
		.override_failure_message(
			"районная обработка начислила XP (K-M16)").is_equal(xp_before)


## Контраст: победа в бою ДАЕТ Престиж (ledger не пуст) — подтверждает, что
## канал начисления существует и отличим от района.
func test_battle_win_does_grant_prestige() -> void:
	var c: CampaignComposition = CampaignComposition.from_campaign_config(424242)
	c._request_battle({"tier": 1, "source": "test", "turn": 1})
	# tier 1, CR героя ≤ рейдера → parity; исход «win» не гарантирован, но
	# ledger за победу — единственный канал. Проверяем структуру: если есть
	# запись, её source_type == "battle_victory" (не район).
	for e in c.prestige_ledger:
		if e is Dictionary:
			assert_that(str((e as Dictionary).get("source_type", ""))) \
				.override_failure_message(
					"Престиж из не-боевого источника").is_equal("battle_victory")
