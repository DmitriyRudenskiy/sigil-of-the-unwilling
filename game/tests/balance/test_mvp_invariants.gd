extends BaseTest

# T-112: баланс-конфиги MVP (зеркало docs/07-balance.md) + инварианты K-M4/K-M9/K-M13.

const Invariants = preload("res://scripts/balance/mvp_invariants.gd")

const CONFIGS := ["campaign", "movement", "xp", "population", "raids", "prestige"]

## Все 6 конфигов загружаются и имеют version
func test_configs_load() -> void:
	for name in CONFIGS:
		var cfg: Dictionary = Invariants.load_config(name)
		assert_that(cfg.size() > 0).override_failure_message(name + ".json не загрузился")
		assert_that(cfg.has("version")).override_failure_message(name + ".json: нет version")

## Канон 07-balance: ключевые значения не потеряны при переносе в конфиги
func test_canon_values_07_balance() -> void:
	var campaign: Dictionary = Invariants.load_config("campaign")
	assert_that(int(campaign.campaign.turns) == 21).override_failure_message("Кампания = 21 ход")
	assert_that(int(campaign.campaign.party_max) == 5).override_failure_message("Партия <= 5 (R1)")
	assert_that(int(campaign.start_state.resources.food) == 30).override_failure_message("Старт: еда 30 (R2)")
	assert_that(int(campaign.start_state.resources.wood) == 20).override_failure_message("Старт: дерево 20 (R2)")
	assert_that(int(campaign.start_state.resources.iron) == 10).override_failure_message("Старт: железо 10 (R2)")
	assert_that(int(campaign.supply.hero_capacity_food) == 10).override_failure_message("Ёмкость героя 10 еды (R7)")

	var xp: Dictionary = Invariants.load_config("xp")
	var th: Dictionary = xp.level_thresholds
	assert_that(int(th["2"]) == 2700).override_failure_message("SRD ур.2 = 2700 (R4)")
	assert_that(int(th["3"]) == 6500).override_failure_message("SRD ур.3 = 6500 (R4)")
	assert_that(int(th["4"]) == 15000).override_failure_message("SRD ур.4 = 15000 (R4)")
	assert_that(int(th["5"]) == 38000).override_failure_message("SRD ур.5 = 38000 (R4)")
	assert_that(int(xp.level_cap) == 5).override_failure_message("Кап уровней 1-5 (K-M13)")

	var pop: Dictionary = Invariants.load_config("population")
	assert_that(absf(pop.k_pop_per_day - 0.1) < 0.001).override_failure_message("k_pop = 0.1/день (K-M12)")

	var raids: Dictionary = Invariants.load_config("raids")
	assert_that(int(raids.raid_power.light) == 15).override_failure_message("Тир лёгкий 15 (R6)")
	assert_that(int(raids.raid_power.medium) == 30).override_failure_message("Тир средний 30 (R6)")
	assert_that(int(raids.raid_power.large) == 60).override_failure_message("Тир крупный 60 (R6)")
	assert_that(absf(raids.defense.barracks - 0.2) < 0.001).override_failure_message("Defense 0.2 при барраках (R6)")
	assert_that(absf(raids.loss_cap_per_day - 0.30) < 0.001).override_failure_message("Кап урона 30%/день")

	var prestige: Dictionary = Invariants.load_config("prestige")
	assert_that(prestige.ranks == [0, 500, 1500, 3500, 7000, 12000]).override_failure_message("Ранги Престижа (02c)")
	assert_that(int(prestige.faction_actions_max) == 12).override_failure_message("Действия <= 12")

## K-M13: пейсинг — «ход 21 = 5×ур.5», ур.5 не раньше (±1 ход)
func test_pacing_invariant() -> void:
	var xp: Dictionary = Invariants.load_config("xp")
	var raids: Dictionary = Invariants.load_config("raids")
	var movement: Dictionary = Invariants.load_config("movement")
	var violations: Array = Invariants.check_pacing(xp, raids, movement.mvp_mask)
	assert_that(violations.is_empty()).override_failure_message(str(violations))

## K-M4: доходимость — руины к туториал-дню 3, весь S1 в пределах кампании
func test_reachability_invariant() -> void:
	var movement: Dictionary = Invariants.load_config("movement")
	var campaign: Dictionary = Invariants.load_config("campaign")
	var violations: Array = Invariants.check_reachability(movement, campaign)
	assert_that(violations.is_empty()).override_failure_message(str(violations))

## K-M9: биты внутри кампании, floor-директивы совпадают с битами
func test_beat_anchor_invariant() -> void:
	var campaign: Dictionary = Invariants.load_config("campaign")
	var raids: Dictionary = Invariants.load_config("raids")
	var violations: Array = Invariants.check_beats(campaign, raids)
	assert_that(violations.is_empty()).override_failure_message(str(violations))

## Сводная проверка: все инварианты держатся
func test_check_all_clean() -> void:
	assert_that(Invariants.check_all().is_empty()).override_failure_message(str(Invariants.check_all()))
