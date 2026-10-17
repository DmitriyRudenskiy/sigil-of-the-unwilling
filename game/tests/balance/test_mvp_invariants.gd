extends BaseTest

# T-112: баланс-конфиги MVP (зеркало docs/07-balance.md) + инварианты K-M4/K-M9/K-M13.
# T-041 (раунд 8): assert_that(<bool>) без метода-проверки ничего не проверял
# (полупустой паттерн — TICKETS T-123); конвертирован в реальные asserts.
# Попутно исправлена устаревшая строка: «Ранги Престижа [0,500,1500,3500,
# 7000,12000] (02c)» — 6-ранговая шкала аннулирована Ф4 (проверяется ниже).

const Invariants = preload("res://scripts/balance/mvp_invariants.gd")

const CONFIGS := ["campaign", "movement", "xp", "population", "raids", "prestige", "races"]

## Все 6 конфигов загружаются и имеют version
func test_configs_load() -> void:
	for name in CONFIGS:
		var cfg: Dictionary = Invariants.load_config(name)
		assert_bool(not cfg.is_empty()).override_failure_message(name + ".json не загрузился").is_true()
		assert_bool(cfg.has("version")).override_failure_message(name + ".json: нет version").is_true()

## Канон 07-balance: ключевые значения не потеряны при переносе в конфиги
func test_canon_values_07_balance() -> void:
	var campaign: Dictionary = Invariants.load_config("campaign")
	assert_int(int(campaign.campaign.turns)).override_failure_message("Кампания = 21 ход").is_equal(21)
	assert_int(int(campaign.campaign.party_max)).override_failure_message("Партия <= 5 (R1)").is_equal(5)
	# Еда 600 — T-041 food-chain якорь (30→130, T-041; 130→600 — T-003 стартовая
	# партия R2: +2/день, нетто −3/день): калибровка ансамбля (5 сидов, farms
	# t1/5/9.. и t4/8/12..) — 600 минимум без DEFICIT (якоря 3a/3b + mood T-041b).
	# Атрибуция — TICKETS T-041/T-003; Q-M91.
	assert_int(int(campaign.start_state.resources.food)).override_failure_message("Старт: еда 600 (R2→T-041→T-003)").is_equal(600)
	assert_int(int(campaign.start_state.resources.wood)).override_failure_message("Старт: дерево 20 (R2)").is_equal(20)
	assert_int(int(campaign.start_state.resources.iron)).override_failure_message("Старт: железо 10 (R2)").is_equal(10)
	assert_int(int(campaign.supply.hero_capacity_food)).override_failure_message("Ёмкость героя 10 еды (R7)").is_equal(10)

	var xp: Dictionary = Invariants.load_config("xp")
	var th: Dictionary = xp.level_thresholds
	assert_int(int(th["2"])).override_failure_message("SRD ур.2 = 2700 (R4)").is_equal(2700)
	assert_int(int(th["3"])).override_failure_message("SRD ур.3 = 6500 (R4)").is_equal(6500)
	assert_int(int(th["4"])).override_failure_message("SRD ур.4 = 15000 (R4)").is_equal(15000)
	assert_int(int(th["5"])).override_failure_message("SRD ур.5 = 38000 (R4)").is_equal(38000)
	assert_int(int(xp.level_cap)).override_failure_message("Кап уровней 1-5 (K-M13)").is_equal(5)

	var pop: Dictionary = Invariants.load_config("population")
	assert_float(float(pop.k_pop_per_day)).override_failure_message("k_pop = 0.1/день (K-M12)").is_equal_approx(0.1, 0.001)

	var raids: Dictionary = Invariants.load_config("raids")
	assert_int(int(raids.raid_power.light)).override_failure_message("Тир лёгкий 15 (R6)").is_equal(15)
	assert_int(int(raids.raid_power.medium)).override_failure_message("Тир средний 30 (R6)").is_equal(30)
	assert_int(int(raids.raid_power.large)).override_failure_message("Тир крупный 60 (R6)").is_equal(60)
	assert_float(float(raids.defense.barracks)).override_failure_message("Defense 0.2 при барраках (R6)").is_equal_approx(0.2, 0.001)
	assert_float(float(raids.loss_cap_per_day)).override_failure_message("Кап урона 30%/день").is_equal_approx(0.30, 0.001)

	var prestige: Dictionary = Invariants.load_config("prestige")
	# Шкала Ф4 [0,200,500,1000,2000] — ниже в test_prestige_ranks_f4; старая
	# 6-ранговая строка (02c) аннулирована Ф4 (K-M16), здесь не дублируется.
	assert_int(int(prestige.faction_actions_max)).override_failure_message("Действия <= 12").is_equal(12)

## K-M13: пейсинг — «ход 21 = 5×ур.5», ур.5 не раньше (±1 ход)
func test_pacing_invariant() -> void:
	var xp: Dictionary = Invariants.load_config("xp")
	var raids: Dictionary = Invariants.load_config("raids")
	var movement: Dictionary = Invariants.load_config("movement")
	var violations: Array = Invariants.check_pacing(xp, raids, movement.mvp_mask)
	assert_array(violations).override_failure_message(str(violations)).is_empty()

## K-M4: доходимость — руины к туториал-дню 3, весь S1 в пределах кампании
func test_reachability_invariant() -> void:
	var movement: Dictionary = Invariants.load_config("movement")
	var campaign: Dictionary = Invariants.load_config("campaign")
	var violations: Array = Invariants.check_reachability(movement, campaign)
	assert_array(violations).override_failure_message(str(violations)).is_empty()

## K-M9: биты внутри кампании, floor-директивы совпадают с битами
func test_beat_anchor_invariant() -> void:
	var campaign: Dictionary = Invariants.load_config("campaign")
	var raids: Dictionary = Invariants.load_config("raids")
	var violations: Array = Invariants.check_beats(campaign, raids)
	assert_array(violations).override_failure_message(str(violations)).is_empty()

## Ф4: источники Престижа — закрытый список; «район» отклоняется (K-M16)
func test_prestige_sources_closed_list() -> void:
	var prestige: Dictionary = Invariants.load_config("prestige")
	var clean: Array = Invariants.check_prestige(prestige)
	assert_array(clean).override_failure_message(str(clean)).is_empty()
	var bad: Dictionary = JSON.parse_string(JSON.stringify(prestige))
	(bad["sources"] as Dictionary)["district_created"] = 500
	var violations: Array = Invariants.check_prestige(bad)
	assert_bool(violations.size() == 1 and str(violations[0]).contains("district_created")) \
		.override_failure_message("район должен отклоняться закрытым списком Ф4: %s" % str(violations)).is_true()

## Ф4: шкала рангов 0/200/500/1000/2000 (волна 1); якорь «Почитаемый» (500–999); титулы — канонизация 2026-10-04
func test_prestige_ranks_f4() -> void:
	var prestige: Dictionary = Invariants.load_config("prestige")
	var ranks: Array = prestige["ranks"]
	var ranks_ok := ranks.size() == 5
	if ranks_ok:
		for i in 5:
			ranks_ok = ranks_ok and absf(float(ranks[i]) - float([0, 200, 500, 1000, 2000][i])) < 0.0001
	assert_bool(ranks_ok) \
		.override_failure_message("Ф4-шкала рангов: %s" % str(ranks)).is_true()
	assert_str(str(prestige["anchor_turn_21"]["title"])) \
		.override_failure_message("якорь хода 21: %s" % str(prestige["anchor_turn_21"])).is_equal("Почитаемый")
	assert_str(str(prestige["rank_names"]["0"])).is_equal("Безымянный")
	assert_str(str(prestige["rank_names"]["200"])).is_equal("Знаемый")
	assert_str(str(prestige["rank_names"]["500"])).is_equal("Почитаемый")
	assert_str(str(prestige["rank_names"]["1000"])).is_equal("Славный")
	assert_str(str(prestige["rank_names"]["2000"])).is_equal("Легендарный")

## Сводная проверка: все инварианты держатся
func test_check_all_clean() -> void:
	var violations: Array = Invariants.check_all()
	assert_array(violations).override_failure_message(str(violations)).is_empty()
