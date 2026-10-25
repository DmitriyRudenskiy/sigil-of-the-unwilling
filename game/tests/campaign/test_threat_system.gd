extends BaseTest
## T-070 — система угроз: функция давления (K-T5: Base × Wealth × Anomalies ×
## Region_History × Global_Phase), аккумулятор, волны тиров 1–3, динамические
## лагеря (D-130: k_p = 2, лексикографический ID, I1), SM рейда (02e4 §13.1),
## директивы K-R3 (floor: первый рейд ≈ ход 7; window: финальный тир к ход 21),
## разрешение рейда (R6: power 15/30/60, loss = power × (1 − defense), cap 30%/день),
## I1-детерминизм, сериализация.

const START_STOCKS: Dictionary = {"food": 30.0, "wood": 20.0, "iron": 10.0}  # T-001


func _new_ts(seed: int = 12345) -> ThreatSystem:
	return ThreatSystem.new(seed)


func _run(turns: int, ts: ThreatSystem, stocks: Dictionary = {}) -> Array:
	var reports: Array = []
	for turn in range(1, turns + 1):
		reports.append(ts.process_turn(turn, {"stocks": stocks.duplicate()}))
	return reports


func test_pressure_formula() -> void:
	# K-T5: pressure = Base × Wealth × Anomalies × Region_History × Global_Phase.
	# Стопки 60 → Wealth = 1 + 0.005×60 = 1.3; ход 1 (фаза 1, ×1.0);
	# рейдов не было → Region_History 1.0; Anomalies 1.0 (MVP).
	var ts := _new_ts()
	assert_float(ts.compute_pressure(1, START_STOCKS)).is_equal_approx(4.0 * 1.3, 1e-6)
	# Фаза 2 (ходы 7–13): ×1.25.
	assert_float(ts.compute_pressure(7, START_STOCKS)).is_equal_approx(4.0 * 1.3 * 1.25, 1e-6)
	# Фаза 3 (ходы 14–20): ×1.5; ход 21: ×2.0 (CR-фазовые якоря, 07-balance §5).
	assert_float(ts.compute_pressure(14, START_STOCKS)).is_equal_approx(4.0 * 1.3 * 1.5, 1e-6)
	assert_float(ts.compute_pressure(21, START_STOCKS)).is_equal_approx(4.0 * 1.3 * 2.0, 1e-6)


func test_accumulator_crossing_tier1() -> void:
	# pressure = 5.2/ход (фаза 1); ход 6: 31.2 ≥ 30 (T1) → волна тира 1.
	var ts := _new_ts()
	var reports: Array = _run(6, ts, START_STOCKS)
	assert_that(reports[4]["wave"].is_empty()).is_equal(true)  # ход 5: 26.0 < 30
	assert_that(reports[5]["wave"].is_empty()).is_equal(false)  # ход 6: 31.2 ≥ 30
	assert_int(int(ts.wave["tier"])).is_equal(1)
	assert_that(ts.camps.size()).is_equal(1)  # D-130: лагерь при пересечении порога


func test_floor_first_raid_turn7() -> void:
	# Пустые стопки: pressure 4.0/ход; ход 6: 24 < 30 — естественного пересечения нет.
	# floor (K-R3): первый рейд ≈ ход 7 (tutorial-тир, гарантирован).
	var ts := _new_ts()
	var reports: Array = _run(7, ts)
	assert_that(reports[5]["wave"].is_empty()).is_equal(true)
	assert_that(reports[6]["wave"].is_empty()).is_equal(false)
	assert_int(int(reports[6]["wave"]["tier"])).is_equal(1)
	assert_that(bool(reports[6]["wave"]["forced"])).is_equal(true)


func test_final_tier_by_turn21() -> void:
	# window (K-R3): финальный тир гарантирован к ход 21 (финальный рейд — floor, тир 3).
	var ts := _new_ts()
	var reports: Array = _run(21, ts)
	var raid: Dictionary = reports[20]["raid"]
	assert_that(raid.is_empty()).is_equal(false)
	assert_int(int(raid["tier"])).is_equal(3)
	assert_float(raid["power"]).is_equal_approx(60.0, 1e-6)
	assert_int(ts.max_tier_raided).is_equal(3)
	# Финал переопределяет cooldown: рейд на 20-м ходу не блокирует финал.
	var ts2 := _new_ts()
	for turn in range(1, 21):
		ts2.process_turn(turn, {"stocks": {}})
	# Волна тира 1 (floor, ход 7) → рейд ход 8; cooldown 8–10; далее давление.
	# На ход 21 может быть активная волна или cooldown — финал всё равно тир 3.
	var r21: Dictionary = ts2.process_turn(21, {"stocks": {}})
	assert_int(int(r21["raid"]["tier"])).is_equal(3)


func test_camp_placement_lexicographic() -> void:
	# D-130: сухие узлы в радиусе k_p = 2, обходя занятые; тай-брейк — лекс. ID (I1).
	var ts := _new_ts()
	ts.adjacency = {"city": ["b", "a"], "a": ["z"], "b": ["m"]}
	_run(7, ts)  # floor → волна + лагерь
	assert_that(str(ts.camps[0]["node"])).is_equal("a")  # глубина 1: a < b
	# Занятый узел (донжон) обходится.
	var ts2 := _new_ts()
	ts2.adjacency = {"city": ["b", "a"], "a": ["z"], "b": ["m"]}
	ts2.occupied_nodes = ["a"]
	_run(7, ts2)
	assert_that(str(ts2.camps[0]["node"])).is_equal("b")
	# k_p = 2: узел на глубине 2, если глубина 1 занята.
	var ts3 := _new_ts()
	ts3.adjacency = {"city": ["a"], "a": ["z", "y"]}
	ts3.occupied_nodes = ["a"]
	_run(7, ts3)
	assert_that(str(ts3.camps[0]["node"])).is_equal("y")  # глубина 2: y < z
	# Лагерь не ставится на узел существующего лагеря.
	var ts4 := _new_ts()
	ts4.adjacency = {"city": ["a", "b"], "a": [], "b": []}
	_run(7, ts4)
	assert_that(str(ts4.camps[0]["node"])).is_equal("a")
	ts4.wave = {}
	var rep4: Dictionary = {"events": [] as Array}
	ts4._place_camp(2, rep4)
	assert_that(str(ts4.camps.back()["node"])).is_equal("b")  # a занят лагерем


func test_raid_resolution_power_defense_cap() -> void:
	# R6: power 15/30/60; loss = power × (1 − defense); defense = 0.2 при казарме.
	var ts := _new_ts()
	ts.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks: Dictionary = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	var r: Dictionary = ts.process_turn(8,
		{"stocks": stocks, "has_barracks": false, "hero_in_city": false})
	assert_float(r["raid"]["loss"]).is_equal_approx(15.0, 1e-6)
	assert_float(stocks["food"]).is_equal_approx(85.0, 1e-6)
	# Казарма: loss = 15 × 0.8 = 12.
	var ts2 := _new_ts()
	ts2.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks2: Dictionary = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	var r2: Dictionary = ts2.process_turn(8,
		{"stocks": stocks2, "has_barracks": true, "hero_in_city": false})
	assert_float(r2["raid"]["loss"]).is_equal_approx(12.0, 1e-6)
	# Per-ресурсный кап (Q-M58→(в), T-127): food ≤40%. stock 10 → loss = min(15, 4) = 4.
	var ts3 := _new_ts()
	ts3.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks3: Dictionary = {"food": 10.0, "wood": 0.0, "iron": 0.0}
	var r3: Dictionary = ts3.process_turn(8,
		{"stocks": stocks3, "has_barracks": false, "hero_in_city": false})
	assert_float(r3["raid"]["loss"]).is_equal_approx(4.0, 1e-6)
	assert_that(bool(r3["raid"]["cap_applied"])).is_equal(true)
	# Power тиров: 15/30/60 (R6; raids.json — источник чисел, T-115).
	assert_float(ts.tier_power[1]).is_equal_approx(15.0, 1e-6)
	assert_float(ts.tier_power[2]).is_equal_approx(30.0, 1e-6)
	assert_float(ts.tier_power[3]).is_equal_approx(60.0, 1e-6)


func test_target_argmin() -> void:
	# Цель (Q-M30 (б), K-R3): слабейший запас = argmin(stocks); равенство
	# минимумов → лексикографика (I1); финальный рейд — то же правило.
	var ts := ThreatSystem.new(42)
	assert_that(ts._pick_target({"food": 50.0, "wood": 10.0, "iron": 40.0})) \
		.is_equal("wood")
	# Равенство минимумов food = iron (5 < 50) → "food" (food < iron, лексикографика).
	assert_that(ts._pick_target({"food": 5.0, "wood": 50.0, "iron": 5.0})) \
		.is_equal("food")
	# Ресурс отсутствует в стопках = 0 → слабейший.
	assert_that(ts._pick_target({"food": 5.0, "wood": 50.0})).is_equal("iron")
	# Сквозной: рейд бьёт по слабейшему запасу (стопки 50/10/40 → Wealth 1.5,
	# пересечение тира 1 на ход 5, удар на ход 6 — цель wood).
	var ts2 := ThreatSystem.new(42)
	var stocks: Dictionary = {"food": 50.0, "wood": 10.0, "iron": 40.0}
	var reports: Array = _run(6, ts2, stocks)
	assert_that(str(reports[5]["raid"]["target"])).is_equal("wood")
	# Финальный рейд (ход 21) — то же правило, без исключений.
	var ts3 := ThreatSystem.new(42)
	var stocks3: Dictionary = {"food": 100.0, "wood": 200.0, "iron": 50.0}
	var reports3: Array = _run(21, ts3, stocks3)
	assert_that(str(reports3[20]["raid"]["target"])).is_equal("iron")


func test_sm_states_sequence() -> void:
	# SM рейда (02e4 §13.1): IDLE → CHARGING → INBOUND → STRIKE → RESOLVED
	# → COOLDOWN → IDLE. STRIKE/RESOLVED — внутри одного хода (события в логе).
	var ts := _new_ts()
	var states: Array = [ts.raid_state]
	for turn in range(1, 13):
		ts.process_turn(turn, {"stocks": {}})
		states.append(ts.raid_state)
	assert_that(str(states[0])).is_equal("IDLE")
	assert_that(str(states[1])).is_equal("CHARGING")  # давление копится
	assert_that(str(states[7])).is_equal("INBOUND")   # floor: волна на ход 7
	assert_that(str(states[8])).is_equal("COOLDOWN")  # рейд на ход 8
	assert_that(str(states[10])).is_equal("COOLDOWN")  # cooldown 3 хода (8–10)
	assert_that(str(states[11])).is_equal("CHARGING")  # cooldown кончился (IDLE — транзит в том же ходе) → давление
	assert_that(str(states[12])).is_equal("CHARGING")
	var has_strike: bool = false
	var has_resolved: bool = false
	var has_idle: bool = false
	for e in ts.event_log():
		if e.contains("→ STRIKE"):
			has_strike = true
		if e.contains("→ RESOLVED"):
			has_resolved = true
		if e.contains("→ IDLE"):
			has_idle = true
	assert_that(has_strike and has_resolved and has_idle).is_equal(true)


func test_cooldown_after_raid() -> void:
	# K-T5: после рейда аккумулятор → 0 + региональный cooldown (3 хода).
	var ts := _new_ts()
	_run(8, ts)  # floor (ход 7) → волна; ход 8 → рейд
	assert_float(ts.accumulator).is_equal_approx(0.0, 1e-6)
	assert_int(ts.region_cooldown).is_equal(3)
	# Во время cooldown (ходы 9–10) давление не копится, волна не генерируется.
	for turn in [9, 10]:
		ts.process_turn(turn, {"stocks": {}})
	assert_float(ts.accumulator).is_equal_approx(0.0, 1e-6)
	assert_that(ts.wave.is_empty()).is_equal(true)
	# Уничтожение лагеря — региональный cooldown («лагеря помнят», D-130).
	var camp_id: String = str(ts.camps[0]["id"])
	var rep: Dictionary = {"events": [] as Array}
	assert_that(ts.destroy_camp(camp_id, rep)).is_equal(true)
	assert_that(ts.camps.is_empty()).is_equal(true)
	assert_int(ts.region_cooldown).is_equal(ts.cooldown_turns)
	assert_that(ts.destroy_camp("camp_nonexistent", rep)).is_equal(false)


func test_hero_in_city_battle_request() -> void:
	# Герой в городе → бой (CR по фазам, шов T-050); герой вне → авто-рейд (R5).
	var battles: Array = []
	var ts := _new_ts()
	ts.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks: Dictionary = {"food": 100.0, "wood": 50.0, "iron": 50.0}
	var r: Dictionary = ts.process_turn(9, {
		"stocks": stocks, "hero_in_city": true,
		"battle_handler": func(ctx: Dictionary) -> void: battles.append(ctx)})
	assert_that(bool(r["raid"]["battle_requested"])).is_equal(true)
	assert_int(battles.size()).is_equal(1)
	# Ход 9 → фаза 2 (7–13): CR 1–2 (07-balance §5).
	assert_that(battles[0]["cr_range"]).is_equal([1, 2])
	assert_int(int(battles[0]["turn"])).is_equal(9)
	# Герой вне города → авто-рейд (R5), без вызова боя.
	var ts2 := _new_ts()
	ts2.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var r2: Dictionary = ts2.process_turn(9,
		{"stocks": stocks.duplicate(), "hero_in_city": false})
	assert_that(bool(r2["raid"]["battle_requested"])).is_equal(false)
	# CR-якоря: фаза 1 (1–6): ¼–1; фаза 3 (14–20): 2–4; ход 21: 6–8.
	assert_that(ts.cr_range(3)).is_equal([0.25, 1])
	assert_that(ts.cr_range(15)).is_equal([2, 4])
	assert_that(ts.cr_range(21)).is_equal([6, 8])


func test_i1_determinism_full_campaign() -> void:
	# I1: один seed кампании → одна кампания (лог событий, стопки, состояния).
	var ts_a := ThreatSystem.new(777)
	var ts_b := ThreatSystem.new(777)
	var stocks_a: Dictionary = START_STOCKS.duplicate()
	var stocks_b: Dictionary = START_STOCKS.duplicate()
	for turn in range(1, 22):
		ts_a.process_turn(turn, {"stocks": stocks_a, "hero_in_city": true})
		ts_b.process_turn(turn, {"stocks": stocks_b, "hero_in_city": true})
	assert_that(JSON.stringify(ts_a.event_log())).is_equal(JSON.stringify(ts_b.event_log()))
	assert_that(JSON.stringify(stocks_a)).is_equal(JSON.stringify(stocks_b))
	assert_that(JSON.stringify(ts_a.to_dict())).is_equal(JSON.stringify(ts_b.to_dict()))


func test_serialization_roundtrip() -> void:
	# Сериализация (схема T-110): состояние mid-campaign восстанавливается;
	# campaign_seed — I1 (продолжение детерминировано; v2: rng выведен, Q-M30 (б)).
	var ts := _new_ts(999)
	_run(10, ts, START_STOCKS)
	var data: Dictionary = ts.to_dict()
	var ts2 := ThreatSystem.from_dict(data)
	assert_float(ts2.accumulator).is_equal_approx(ts.accumulator, 1e-6)
	assert_int(ts2.raids_count).is_equal(ts.raids_count)
	assert_int(ts2.max_tier_raided).is_equal(ts.max_tier_raided)
	assert_that(ts2.raid_state).is_equal(ts.raid_state)
	assert_that(JSON.stringify(ts2.camps)).is_equal(JSON.stringify(ts.camps))
	assert_int(ts2.campaign_seed).is_equal(ts.campaign_seed)
	# Продолжение: два восстановленных экземпляра сходятся.
	var ts3 := ThreatSystem.from_dict(data)
	var r2: Dictionary = ts2.process_turn(11, {"stocks": START_STOCKS.duplicate()})
	var r3: Dictionary = ts3.process_turn(11, {"stocks": START_STOCKS.duplicate()})
	assert_that(JSON.stringify(r2)).is_equal(JSON.stringify(r3))


func test_serialization_v1_migration() -> void:
	# Миграция v1→v2 (райдер T-110): v1 payload (rng_state, без campaign_seed)
	# загружается; rng_state игнорируется (в v2 нет ГСЧ), campaign_seed → 1.
	var v1: Dictionary = {
		"schema_version": 1,
		"accumulator": 12.5,
		"region_cooldown": 2,
		"turns_since_last_raid": 6,
		"wave": {},
		"camps": [{"id": "camp_0", "node": "city", "tier": 1}],
		"raids_count": 1,
		"max_tier_raided": 1,
		"raid_state": ThreatSystem.SM_COOLDOWN,
		"city_node": "city",
		"rng_state": 987654321,
	}
	var ts := ThreatSystem.from_dict(v1)
	assert_float(ts.accumulator).is_equal_approx(12.5, 1e-6)
	assert_int(ts.raids_count).is_equal(1)
	assert_int(ts.max_tier_raided).is_equal(1)
	assert_that(ts.raid_state).is_equal(ThreatSystem.SM_COOLDOWN)
	assert_int(ts.campaign_seed).is_equal(1)
	# Детерминированное продолжение после миграции (I1).
	var a := ThreatSystem.from_dict(v1)
	var b := ThreatSystem.from_dict(v1)
	assert_that(JSON.stringify(a.process_turn(7, {"stocks": START_STOCKS.duplicate()}))) \
		.is_equal(JSON.stringify(b.process_turn(7, {"stocks": START_STOCKS.duplicate()})))


func test_config_driven_numbers_t115() -> void:
	# T-115: числа угрозы читаются из raids.json (07-balance §5/§6 зеркало),
	# не хардкод (K-M15).
	var ts := _new_ts()
	assert_float(ts.pressure_base).is_equal_approx(4.0, 1e-6)
	assert_float(ts.tier_thresholds[1]).is_equal_approx(30.0, 1e-6)
	assert_float(ts.tier_thresholds[2]).is_equal_approx(100.0, 1e-6)
	assert_float(ts.tier_thresholds[3]).is_equal_approx(250.0, 1e-6)
	assert_float(ts.defense_barracks).is_equal_approx(0.2, 1e-6)
	assert_float(ts.loss_cap_fraction).is_equal_approx(0.3, 1e-6)
	assert_int(ts.cooldown_turns).is_equal(3)
	assert_int(ts.camp_k_p).is_equal(2)
	assert_float(ts.enemy_mult_winter).is_equal_approx(1.25, 1e-6)
	# Директивы битов 1:1 (бит-таблица 07-balance §6): 7/14/17/21.
	var turns: Array = []
	for k in ts.directives:
		turns.append(int(ts.directives[k]["turn"]))
	turns.sort()
	assert_array(turns).is_equal([7, 14, 17, 21])


## raid-pressure-system 2.1 (Q-M58→(в), D-189, T-127): per-ресурсные капы за рейд.
## еда ≤40%, железо/дерево ≤30%; ресурс не в loss_caps → дефолт loss_cap_fraction.
func test_per_resource_caps() -> void:
	var ts := _new_ts()
	# Значения капов из raids.json (loss_caps).
	assert_float(ts.loss_cap_for("food")).is_equal_approx(0.4, 1e-6)
	assert_float(ts.loss_cap_for("wood")).is_equal_approx(0.3, 1e-6)
	assert_float(ts.loss_cap_for("iron")).is_equal_approx(0.3, 1e-6)
	# Ресурс не в loss_caps → дефолт loss_cap_fraction (0.3).
	assert_float(ts.loss_cap_for("unknown_res")).is_equal_approx(0.3, 1e-6)


## Per-ресурсный кап: food 40% vs iron 30% на одинаковом stock.
func test_per_resource_cap_food_vs_iron() -> void:
	# food: stock 10, power 15 → loss = min(15, 0.4×10) = 4.
	var ts_f := _new_ts()
	ts_f.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks_f: Dictionary = {"food": 10.0, "wood": 0.0, "iron": 0.0}
	var r_f: Dictionary = ts_f.process_turn(8,
		{"stocks": stocks_f, "has_barracks": false, "hero_in_city": false})
	assert_float(r_f["raid"]["loss"]).is_equal_approx(4.0, 1e-6)
	assert_that(bool(r_f["raid"]["cap_applied"])).is_equal(true)

	# iron: stock 10, power 15 → loss = min(15, 0.3×10) = 3 (строже, чем food).
	var ts_i := _new_ts()
	ts_i.wave = {"tier": 1, "power": 15.0, "target": "iron", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks_i: Dictionary = {"food": 0.0, "wood": 0.0, "iron": 10.0}
	var r_i: Dictionary = ts_i.process_turn(8,
		{"stocks": stocks_i, "has_barracks": false, "hero_in_city": false})
	assert_float(r_i["raid"]["loss"]).is_equal_approx(3.0, 1e-6)
	assert_that(bool(r_i["raid"]["cap_applied"])).is_equal(true)


## Кап — per-рейд, не per-ход: большой запас не трогает кап.
func test_cap_only_when_loss_exceeds() -> void:
	# food: stock 100, power 15 → loss = 15 < 0.4×100 = 40 → кап не применяется.
	var ts := _new_ts()
	ts.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks: Dictionary = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	var r: Dictionary = ts.process_turn(8,
		{"stocks": stocks, "has_barracks": false, "hero_in_city": false})
	assert_float(r["raid"]["loss"]).is_equal_approx(15.0, 1e-6)
	assert_that(bool(r["raid"]["cap_applied"])).is_equal(false)


## raid-pressure 2.3: рейд по клетке героя → бой; победа → −50% последствий.
func test_hero_victory_reduces_consequences_50() -> void:
	# Герой в городе, бой → победа: урон halved.
	# food: stock 100, power 15, defense 0 → loss = 15; победа → 7.5.
	var ts := _new_ts()
	ts.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks: Dictionary = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	var r: Dictionary = ts.process_turn(8, {
		"stocks": stocks, "has_barracks": false, "hero_in_city": true,
		"battle_handler": func(_ctx: Dictionary) -> String: return "win"})
	assert_that(bool(r["raid"]["battle_requested"])).is_equal(true)
	assert_that(bool(r["raid"]["battle_won"])).is_equal(true)
	assert_float(r["raid"]["loss"]).is_equal_approx(7.5, 1e-6)
	assert_float(stocks["food"]).is_equal_approx(92.5, 1e-6)

	# Поражение: урон полный (15), без halving.
	var ts2 := _new_ts()
	ts2.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks2: Dictionary = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	var r2: Dictionary = ts2.process_turn(8, {
		"stocks": stocks2, "has_barracks": false, "hero_in_city": true,
		"battle_handler": func(_ctx: Dictionary) -> String: return "lose"})
	assert_that(bool(r2["raid"]["battle_won"])).is_equal(false)
	assert_float(r2["raid"]["loss"]).is_equal_approx(15.0, 1e-6)
	assert_float(stocks2["food"]).is_equal_approx(85.0, 1e-6)


## raid-pressure 4.5: AFK-каскад — капы per-рейд предотвращают chain collapse.
## Много рейдов подряд: запасы не уходят в минус (кап per-рейд ограничивает урон).
func test_afk_cascade_no_chain_collapse() -> void:
	var ts := _new_ts()
	var stocks: Dictionary = {"food": 50.0, "wood": 50.0, "iron": 50.0}
	# 10 рейдов подряд (tier 3, power 60) — без капа запасы ушли бы в минус.
	for i in range(10):
		ts.wave = {"tier": 3, "power": 60.0, "target": "food", "camp_id": "x",
			"turns_to_arrival": 0, "forced": false}
		ts.process_turn(10 + i, {"stocks": stocks, "has_barracks": false,
			"hero_in_city": false})
		# Инвариант: запасы не уходят в минус (кап per-рейд).
		assert_float(stocks["food"]).is_greater(-1e-9) \
			.override_failure_message("food ушёл в минус на рейде %d" % i)
	# После серии рейдов food > 0 (кап ограничивает урон, city выживает).
	assert_float(stocks["food"]).is_greater(0.0) \
		.override_failure_message("food = 0 после AFK-каскада (chain collapse)")


## raid-pressure 2.2 (K-R3): «все районы разрушены» → cooldown ×2 (частота −50%).
func test_cooldown_doubled_when_all_districts_ruined() -> void:
	# Базовый cooldown (не все разрушены) = cooldown_turns (3).
	var ts := _new_ts()
	ts.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks: Dictionary = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	ts.process_turn(8, {"stocks": stocks, "has_barracks": false,
		"hero_in_city": false, "all_districts_destroyed": false})
	assert_int(ts.region_cooldown).is_equal(3)
	assert_int(ts.effective_cooldown(false)).is_equal(3)

	# Все районы разрушены → cooldown ×2 = 6.
	var ts2 := _new_ts()
	ts2.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var stocks2: Dictionary = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	ts2.process_turn(8, {"stocks": stocks2, "has_barracks": false,
		"hero_in_city": false, "all_districts_destroyed": true})
	assert_int(ts2.region_cooldown).is_equal(6)
	assert_int(ts2.effective_cooldown(true)).is_equal(6)


func test_winter_enemy_mult_t115() -> void:
	# Q-M29: зима (каждый 4-й ход) — enemy_mult 1.25 к силе волны; финал — без бонуса.
	var ts := _new_ts()
	# Ход 4 — зима ((4−1) mod 4 = 3): тир 1 → 15 × 1.25 = 18.75.
	ts._spawn_wave(4, 1, false, {"events": [] as Array}, 1, {"food": 10.0})
	assert_float(float(ts.wave["power"])).is_equal_approx(18.75, 1e-6)
	# Ход 7 — осень ((7−1) mod 4 = 2): без бонуса.
	ts.wave = {}
	ts._spawn_wave(7, 1, false, {"events": [] as Array}, 1, {"food": 10.0})
	assert_float(float(ts.wave["power"])).is_equal_approx(15.0, 1e-6)
	# Финальный ход 21 — без бонуса (сложность финала — тир волны, K-T5).
	ts.wave = {}
	ts._spawn_wave(21, 3, true, {"events": [] as Array}, 0, {"food": 10.0})
	assert_float(float(ts.wave["power"])).is_equal_approx(60.0, 1e-6)


## raid-pressure 4.1: Wealth clamp — [wealth_min, wealth_max] (дефолты 0.5/2.0;
## конфиг 0.6/1.5 грузится в игре, _new_ts — дефолты).
func test_wealth_clamp_t115() -> void:
	var ts := _new_ts()
	# Высокие запасы: 1 + 0.005×400 = 3.0 → clamp к wealth_max (2.0).
	var high: Dictionary = {"food": 400.0, "wood": 0.0, "iron": 0.0}
	assert_float(ts.compute_pressure(1, high)).is_equal_approx(4.0 * 2.0, 1e-6)
	# Средние запасы: 1 + 0.005×120 = 1.6 → в пределах, clamp не срабатывает.
	var mid: Dictionary = {"food": 120.0, "wood": 0.0, "iron": 0.0}
	assert_float(ts.compute_pressure(1, mid)).is_equal_approx(4.0 * 1.6, 1e-6)
	# Пусто: 1.0 (в пределах, clamp не срабатывает).
	var zero: Dictionary = {"food": 0.0, "wood": 0.0, "iron": 0.0}
	assert_float(ts.compute_pressure(1, zero)).is_equal_approx(4.0 * 1.0, 1e-6)


## raid-pressure 4.1: рост Region_History после cooldown.
func test_region_history_growth_t115() -> void:
	# history = 1 + 0.05×(turns_since_raid − cooldown); 0 в cooldown.
	var ts := _new_ts()
	ts.turns_since_last_raid = -1  # рейдов не было
	assert_float(ts._region_history()).is_equal_approx(1.0, 1e-6)
	ts.turns_since_last_raid = 3  # ровно cooldown → after = 0 → 1.0
	assert_float(ts._region_history()).is_equal_approx(1.0, 1e-6)
	ts.turns_since_last_raid = 8  # after = 5 → 1.25
	assert_float(ts._region_history()).is_equal_approx(1.0 + 0.05 * 5, 1e-6)
	# В cooldown — 0 (регион «помнит», D-130).
	ts.region_cooldown = 2
	assert_float(ts._region_history()).is_equal_approx(0.0, 1e-6)


## raid-pressure 4.2: tiers — пороги 30/100/250, сила 15/30/60, оборона 0.2.
func test_tier_thresholds_power_t115() -> void:
	var ts := _new_ts()
	assert_int(int(ts.tier_thresholds[1])).is_equal(30)
	assert_float(float(ts.tier_power[1])).is_equal_approx(15.0, 1e-6)
	assert_int(int(ts.tier_thresholds[2])).is_equal(100)
	assert_float(float(ts.tier_power[2])).is_equal_approx(30.0, 1e-6)
	assert_int(int(ts.tier_thresholds[3])).is_equal(250)
	assert_float(float(ts.tier_power[3])).is_equal_approx(60.0, 1e-6)
	assert_float(ts.defense_barracks).is_equal_approx(0.2, 1e-6)
	# Оборона: с казармой loss = power×(1−0.2); без — power.
	var stocks: Dictionary = {"food": 100.0, "wood": 0.0, "iron": 0.0}
	ts.wave = {"tier": 1, "power": 15.0, "target": "food", "camp_id": "x",
		"turns_to_arrival": 0, "forced": false}
	var r: Dictionary = ts.process_turn(8, {"stocks": stocks, "has_barracks": true})
	assert_float(r["raid"]["loss"]).is_equal_approx(15.0 * 0.8, 1e-6)


func test_window_strong_raid_turn17_t115() -> void:
	# K-R3 window (бит 17): сильный рейд (тир ≥ 2) гарантирован в окне бита
	# [14..20] — сильнее cooldown и повышает естественную волну в пути.
	var ts := _new_ts()
	var reports: Array = _run(20, ts)  # пустые стопки: худший для гарантии вход
	var strong_in_window := false
	for i in range(13, 20):  # ходы 14..20
		var raid: Dictionary = reports[i]["raid"]
		if not raid.is_empty() and int(raid["tier"]) >= 2:
			strong_in_window = true
			assert_that(bool(raid["battle_requested"])).is_equal(true)  # шов T-050
	assert_that(strong_in_window).is_equal(true)
	assert_int(ts.max_tier_raided).is_equal(2)


func test_wave_composition_t115() -> void:
	# K-R3 директива composition (словарь): естественная волна — weakest_stock;
	# директивы несут composition бита (tutorial/strong_raid/boss).
	var ts := _new_ts()
	var rep: Dictionary = {"events": [] as Array}
	ts._spawn_wave(5, 1, false, rep, 1, {"food": 10.0})
	assert_that(str(ts.wave["composition"])).is_equal("weakest_stock")
	ts.wave = {}
	ts._spawn_wave(7, 1, true, rep, 1, {"food": 10.0}, "tutorial")
	assert_that(str(ts.wave["composition"])).is_equal("tutorial")


func test_anchor_reachability_t115() -> void:
	# Инвариант достижимости якорей 7/14/21 (бит-таблица, 07-balance §6):
	# floor-рейд к ходу 8 (7+прибытие), window тир 2 к ходу 18 (17+прибытие),
	# финал тир 3 на ходу 21 — при худшем для гарантий входе (пустые стопки).
	var ts := _new_ts()
	var reports: Array = _run(21, ts)
	var first_raid_turn := -1
	for r in reports:
		if not (r as Dictionary)["raid"].is_empty():
			first_raid_turn = int((r as Dictionary)["turn"])
			break
	assert_that(first_raid_turn > 0 and first_raid_turn <= 8).is_equal(true)
	var strong_in_window := false
	for i in range(13, 20):  # окно бита 17: ходы 14..20
		var raid: Dictionary = reports[i]["raid"]
		if not raid.is_empty() and int(raid["tier"]) >= 2:
			strong_in_window = true
	assert_that(strong_in_window).is_equal(true)
	assert_int(int(reports[20]["raid"]["tier"])).is_equal(3)


## D-240: волна несёт ход генерации, а рейд — состав. Хроника обязана
## предупреждать «в ход генерации» (07-balance §5) и различать финальный рейд по
## директиве composition = босс (K-R3), а не по тиру: тир 3 бывает не только у
## финала, а бит ≤21 — про босса, а не про арифметику давления.
func test_wave_carries_generation_turn_and_raid_carries_composition() -> void:
	var ts := _new_ts()
	var reports: Array = _run(7, ts)
	var wave: Dictionary = reports[6]["wave"]
	assert_str(str(wave.get("composition", ""))) \
		.override_failure_message("floor-волна потеряла состав директивы").is_equal("tutorial")
	assert_int(int(wave.get("turn", -1))) \
		.override_failure_message("у волны нет хода генерации").is_equal(7)
	# Рейд (ход 8 = 7 + прибытие, героя нет → авто-рейд R5): состав долетает до
	# читателя в результате, а не только в состоянии системы.
	var r8: Dictionary = ts.process_turn(8, {
		"stocks": {"food": 30.0, "wood": 20.0, "iron": 10.0}, "hero_in_city": false})
	assert_str(str((r8["raid"] as Dictionary).get("composition", ""))) \
		.override_failure_message("рейд потерял состав волны").is_equal("tutorial")
	# Финал (ход 21, K-R3: boss-состав).
	var ts2 := _new_ts()
	_run(20, ts2)
	var r21: Dictionary = ts2.process_turn(21, {
		"stocks": {"food": 30.0, "wood": 20.0, "iron": 10.0}, "hero_in_city": false})
	assert_str(str((r21["raid"] as Dictionary).get("composition", ""))) \
		.override_failure_message("финальный рейд не помечен босс-составом").is_equal("boss")
