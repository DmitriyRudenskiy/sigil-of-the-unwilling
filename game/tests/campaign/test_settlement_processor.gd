extends BaseTest
## T-040 — settlement-фаза: stock/flow (K-D5), 3 ресурса (K-R2), SM дефицита,
## R3-кап, рождения (K-M12), clamp эффективности (07-balance §6), I1-детерминизм.
## 1 ход = DAYS_PER_SEASON = 20 дней (Q-M26).

const START_BUILDINGS: Array = [
	{"id": "farm", "output_day": {"food": 2.0}},
	{"id": "sawmill", "output_day": {"wood": 2.0}},
	{"id": "mine", "output_day": {"iron": 1.0}},
]


func _start_state() -> SettlementProcessor:
	# Стартовые числа баланса: T-001 (население 20, еда 30/дерево 20/железо 10, партия 2),
	# T-030 (5 зданий; жильё 20 — Q-M28, закрыто, 11-я итерация §1.2: старт-кап = старт-популяции).
	var p := SettlementProcessor.new()
	p.stocks = {"food": 30.0, "wood": 20.0, "iron": 10.0}
	p.population = 20
	p.housing = 20
	p.party_size = 2
	p.buildings = START_BUILDINGS.duplicate(true)
	return p


func test_start_state_one_turn() -> void:
	var p := _start_state()
	var r: Dictionary = p.process_turn(1.0)
	# Еда: prod 2/день, cons 0.1×20 + 2×1 = 4/день → net −2/день; d15: B=0 → DEFICIT;
	# d16–d20: prod ×0.25 = 0.5 → net −3.5 → B(20) = −17.5.
	assert_float(p.stocks["food"]).is_equal_approx(-17.5, 1e-6)
	# Дерево: 20 + 2×20 = 60. Железо: 10 + 1×20 = 30.
	assert_float(p.stocks["wood"]).is_equal_approx(60.0, 1e-6)
	assert_float(p.stocks["iron"]).is_equal_approx(30.0, 1e-6)
	# SM: еда DEFICIT; дерево/железо OK (потребления нет).
	assert_that(p.sm["food"]["state"]).is_equal("DEFICIT")
	assert_that(p.sm["wood"]["state"]).is_equal("OK")
	assert_that(p.sm["iron"]["state"]).is_equal("OK")
	# R3-кап: min(жильё 20, floor(14/0.7)=20) = 20; рождения int(0.1×20)=2; pop = clamp(22, 0, 20) = 20.
	assert_int(r["population_cap"]).is_equal(20)
	assert_int(p.population).is_equal(20)
	# Отчёт: 20 дней, production еда = 15×2 + 5×0.5 = 32.5.
	assert_int(r["days"]).is_equal(20)
	assert_float(r["production"]["food"]).is_equal_approx(32.5, 1e-6)
	assert_float(r["consumption"]["food"]).is_equal_approx(80.0, 1e-6)


func test_no_consumption_stays_ok() -> void:
	var p := SettlementProcessor.new()
	p.stocks = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	p.population = 0
	p.party_size = 0
	var r: Dictionary = p.process_turn(1.0)
	assert_that(p.sm["food"]["state"]).is_equal("OK")
	assert_float(p.stocks["food"]).is_equal(100.0)
	# Нет производства еды → R3-кап 0 → население 0.
	assert_int(p.population).is_equal(0)


func test_sm_warn_transition() -> void:
	# Еда 26, pop 0, party 1: cons 1/день, supply d1 = 25 ≥ 7 (OK), d2 = 24…
	# WARN: B < 7 дней потребления → d20: B = 26−20 = 6 → WARN на d20.
	var p := SettlementProcessor.new()
	p.stocks = {"food": 26.0, "wood": 0.0, "iron": 0.0}
	p.party_size = 1
	p.process_turn(1.0)
	assert_that(p.sm["food"]["state"]).is_equal("WARN")


func test_sm_deficit_recovery_three_days() -> void:
	# DEFICIT → OK: B > 0 три дня подряд. cons = 0, B = 1.0 → d3 → OK.
	var p := SettlementProcessor.new()
	p.stocks = {"food": 1.0, "wood": 0.0, "iron": 0.0}
	p.sm = {"food": {"state": "DEFICIT", "days_positive": 0, "days_negative": 5}}
	p.process_turn(1.0)
	assert_that(p.sm["food"]["state"]).is_equal("OK")
	var recovery_day: int = -1
	for e in p.event_log():
		if e.begins_with("day ") and e.contains("DEFICIT→OK"):
			recovery_day = int(e.split(" ")[1])
	assert_int(recovery_day).is_equal(3)


func test_sm_warn_to_ok_recovery() -> void:
	# WARN → OK: B ≥ 7 дней потребления. cons 0.1/день (pop 1, party 0), B = 5 → supply 50 ≥ 7 → OK на d1.
	var p := SettlementProcessor.new()
	p.stocks = {"food": 5.0, "wood": 0.0, "iron": 0.0}
	p.population = 1
	p.sm = {"food": {"state": "WARN", "days_positive": 0, "days_negative": 0}}
	p.process_turn(1.0)
	assert_that(p.sm["food"]["state"]).is_equal("OK")


func test_efficiency_clamp() -> void:
	# clamp [0.2; 2.5] (07-balance §6): eff 5.0 → 2.5; eff 0.1 → 0.2.
	var p := SettlementProcessor.new()
	p.buildings = [{"id": "farm_hi", "output_day": {"food": 1.0}, "efficiency": 5.0}]
	var r: Dictionary = p.process_turn(1.0)
	assert_float(r["production"]["food"]).is_equal_approx(2.5 * 20.0, 1e-6)
	p = SettlementProcessor.new()
	p.buildings = [{"id": "farm_lo", "output_day": {"food": 1.0}, "efficiency": 0.1}]
	r = p.process_turn(1.0)
	assert_float(r["production"]["food"]).is_equal_approx(0.2 * 20.0, 1e-6)


func test_season_mult_applied() -> void:
	# Зима: production ×0.4 (Q-M27: season = turn, цикл 4; mult — инжкт из WorldSeasons).
	var p := _start_state()
	var r: Dictionary = p.process_turn(0.4)
	assert_float(r["production"]["wood"]).is_equal_approx(2.0 * 0.4 * 20.0, 1e-6)


func test_i1_determinism() -> void:
	var a := _start_state()
	var b := _start_state()
	var ra: Dictionary = a.process_turn(1.0)
	var rb: Dictionary = b.process_turn(1.0)
	assert_that(JSON.stringify(ra)).is_equal(JSON.stringify(rb))
	assert_that(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict()))


func test_serialization_roundtrip() -> void:
	var p := _start_state()
	p.process_turn(1.0)
	var data: Dictionary = p.to_dict()
	var p2 := SettlementProcessor.from_dict(data)
	var r1: Dictionary = p.process_turn(1.0)
	var r2: Dictionary = p2.process_turn(1.0)
	assert_that(JSON.stringify(r1)).is_equal(JSON.stringify(r2))
	assert_that(JSON.stringify(p.to_dict())).is_equal(JSON.stringify(p2.to_dict()))


func test_driver_integration() -> void:
	# Драйвер (T-010) + процессор: settlement_hook = process_turn.bind(season_mult).
	var driver := TurnDriver.new()
	var p := _start_state()
	driver.settlement_hook = p.process_turn.bind(1.0)
	for i in 3:
		driver.advance_auto_phase()  # settlement → player
		driver.end_player_phase()    # player → threats
		driver.advance_auto_phase()  # threats → finish (следующий settlement)
	assert_int(driver.current_turn).is_equal(4)
	assert_int(p.population).is_equal(20)  # R3-кап 20 держится (Q-M28)
	assert_float(p.stocks["food"]).is_less(0.0)  # дефицит еды (якорь «выживание», 06-economy)
	assert_float(p.stocks["wood"]).is_greater(0.0)
	# Сериализация пары driver+processor.
	var d_data: Dictionary = driver.to_dict()
	var p_data: Dictionary = p.to_dict()
	var driver2 := TurnDriver.from_dict(d_data)
	var p2 := SettlementProcessor.from_dict(p_data)
	assert_int(driver2.current_turn).is_equal(4)
	assert_int(p2.population).is_equal(20)
