"""T-124 Ф4-MVP «этический минимум»: вектор знака, журнал, сверка, Репутация,
миграция. Формула — приказ раунда 15 §3 (w_r=1, w_d=2, якорь дельты [−3,+3],
калибровочный якорь Репутации [+2,+6]); векторы — signs.json (ратифицировано,
Гармония 0/+1/−1). Четыре стража: I1-сейв, Э1-3 (миграция — только Репутация),
Репутация вне ресурсных транзакций, миграция старого сейва.
"""
extends BaseTest

const SIGNS_JSON := "res://data/signs.json"


func _config() -> Dictionary:
	return MvpInvariants.load_config("ethics")


func _sign_vectors() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SIGNS_JSON))
	return EthicsSystem.load_sign_vectors(parsed)


func _ethics(sign: String = "spark") -> EthicsSystem:
	return EthicsSystem.new_for_sign(sign, _config())


func test_vector_table_ratified() -> void:
	var v := _sign_vectors()
	var expected := {
		"spark": [2, 1, 0], "time": [-1, -1, -1], "balance": [0, 0, 0],
		"primal": [1, 1, -1], "shadow": [1, -1, 2], "harmony": [0, 1, -1],
		"cycle": [1, -1, -1], "basis": [-2, 0, 1],
	}
	assert_int(v.size()).is_equal(8)
	for id in expected:
		var vec: Array = [
			int(v[id]["order_freedom"]), int(v[id]["ascetic_luxury"]),
			int(v[id]["openness_isolation"]),
		]
		assert_str(str(vec)).override_failure_message(
			"этический вектор не ратифицирован: " + str(id)).is_equal(str(expected[id]))


func test_reconcile_direction_math_and_clamp() -> void:
	var e := _ethics("spark")  # референс +2/+1/0
	# Согласованно: Долг судьбы (+Свобода) + победа в обороне → Резонанс.
	e.record_fate_debt_win(3)
	e.record_defense_win(4)
	var rep: Dictionary = e.reconcile(10, _sign_vectors())
	# r = 1 (событие) + 1 (ось Свобода совпала; Роскошь/Изоляция — ноль, нейтраль).
	assert_int(int(rep.get("r", 0))).is_equal(2)
	assert_int(int(rep.get("delta", 0))).override_failure_message(
		"дельта ≠ w_r·R − w_d·D").is_equal(2)
	assert_int(e.reputation).is_equal(2)
	# Противоречие: 3 потери → d=3 → raw = −6 → кламп якоря [−3,+3].
	var e2 := _ethics("spark")
	e2.record_losses(1)
	e2.record_losses(2)
	e2.record_losses(3)
	var rep2: Dictionary = e2.reconcile(10, _sign_vectors())
	assert_int(int(rep2.get("d", 0))).is_equal(3)
	assert_int(e2.reputation).override_failure_message(
		"дельта вне якоря [−3,+3]").is_equal(-3)
	# Нулевая ось (Изоляция у Искры) — нейтраль, вклад 0; аккумулятор сброшен.
	assert_int(int(e.axes["openness_isolation"])).is_equal(0)
	assert_int(e.resonance + e.dissonance).override_failure_message(
		"аккумуляторы не сброшены на сверке").is_equal(0)


func test_reputation_anchor_corridor() -> void:
	# Знаково-согласованная игра (Искра): оборона + Долг судьбы, без потерь.
	var e := _ethics("spark")
	var vectors := _sign_vectors()
	for turn in [10, 20]:
		e.record_fate_debt_win(turn - 1)
		e.record_defense_win(turn - 1)
		e.reconcile(turn, vectors)
	var anchor: Array = _config().get("reputation_anchor", [])
	assert_bool(e.reputation >= int(anchor[0]) and e.reputation <= int(anchor[1])) \
		.override_failure_message(
			"Репутация согласованной игры вне якоря [+2,+6]: " + str(e.reputation)).is_true()


func test_guard_i1_journal_not_recomputed_on_load() -> void:
	# Страж 1 (I1): журнал/Репутация — состояние; загрузка не пересчитывает.
	var e := _ethics("spark")
	e.record_losses(2)
	e.record_defense_win(3)
	e.reconcile(10, _sign_vectors())
	var e2 := EthicsSystem.from_dict(e.to_dict(), _config())
	assert_int(e2.reputation).is_equal(e.reputation)
	assert_int(e2.journal.size()).is_equal(e.journal.size())
	assert_int(e2.last_reconcile_turn).override_failure_message(
		"сверка повторится после загрузки").is_equal(10)
	assert_bool(e2.needs_reconcile(10)).is_false()


func test_guard_migration_input_is_reputation_only() -> void:
	# Страж 2 (Э1-3): миграция — только Репутация; Престиж — никогда.
	var c: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	var seen: Array = []
	c.settlement.migration_hook = func(ctx: Dictionary) -> void:
		seen.append(ctx)
	c.set_sign("spark")
	c.ethics.reputation = 4
	c.advance_turn()
	assert_int(seen.size()).override_failure_message("миграционный хук не вызван").is_equal(1)
	var ctx: Dictionary = seen[0]
	assert_int(int(ctx.get("reputation", 99))).is_equal(4)
	assert_bool(not ctx.has("prestige")).override_failure_message(
		"Престиж просочился в миграционный вход (Э1-3)").is_true()
	# Формула population: k_mig × (Репутация − нейтраль) — приток при +4.
	var pop := PopulationSystem.new()
	pop.seed_population(20)
	var before := pop.size()
	pop.process_turn(20, 4.0, 100)
	assert_int(pop.size() - before).override_failure_message(
		"k_mig × 4 = 1/ход не дал притока").is_greater(0)


func test_guard_reputation_outside_resource_transactions() -> void:
	# Страж 3: Репутация не участвует в производстве/транзакциях ресурсов.
	var a := SettlementProcessor.new()
	var b := SettlementProcessor.new()
	for proc in [a, b]:
		proc.stocks = {"food": 30.0, "wood": 20.0, "iron": 10.0}
		proc.population = 20
		proc.buildings = [{"id": "farm", "group": "Земледельцы и Пивовары",
			"output_day": {"food": 1.0}, "efficiency": 1.0, "workers": 2, "jobs": 2}]
	b.reputation = 6
	var ra: Dictionary = a.process_production(1.0)
	var rb: Dictionary = b.process_production(1.0)
	assert_str(str(ra.get("production", {}))).override_failure_message(
		"Репутация изменила производство (вне формулы)").is_equal(
			str(rb.get("production", {})))


func test_composition_ethics_wiring_and_save_migration() -> void:
	# Страж 4 + проводка: секция в сейве; старый сейв без секции → дефолты.
	var c: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	c.set_sign("basis")
	c.ethics.record_defense_win(1)
	c.advance_turn()
	var state := c.build_save_state()
	var ethics_section: Dictionary = (state.get("campaign", {}) as Dictionary).get("ethics", {})
	assert_int(ethics_section.size()).override_failure_message("секция ethics не собрана").is_greater(0)
	var c2: CampaignComposition = CampaignComposition.from_campaign_config(999)
	c2.load_save_state(state)
	assert_str(c2.ethics.sign_id).is_equal("basis")
	assert_int(c2.ethics.journal.size()).is_equal(c.ethics.journal.size())
	assert_int(c2.settlement.reputation).override_failure_message(
		"миграционный вход не восстановлен").is_equal(c.ethics.reputation)
	# Миграция старого сейва: нет секции — Репутация 0, журнал пуст.
	(state["campaign"] as Dictionary).erase("ethics")
	var c3: CampaignComposition = CampaignComposition.from_campaign_config(777)
	c3.load_save_state(state)
	assert_int(c3.ethics.reputation).is_equal(0)
	assert_int(c3.ethics.journal.size()).is_equal(0)


func test_integration_city_loop_full_campaign() -> void:
	# Акт раунда 15 §3.4: первый сквозной прогон петли с городским контуром —
	# бои → журнал → сверки 10/20 → Репутация → миграция (страж 2) → рабочие.
	var c: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	c.set_sign("spark")
	for i in 21:
		c.advance_turn()
	assert_bool(c.campaign.is_done()).override_failure_message("кампания не дошла до хода 21").is_true()
	var reconciles := {}
	var battle_events := 0
	for e in c.ethics.journal:
		var kind := str(e.get("kind", ""))
		if kind == "reconcile":
			reconciles[int(e.get("turn", 0))] = e
		elif kind in ["defense_win", "defender_losses", "fate_debt_win"]:
			battle_events += 1
	assert_bool(reconciles.has(10) and reconciles.has(20)) \
		.override_failure_message("сверки 10/20 не прошли: " + str(reconciles.keys())).is_true()
	assert_bool(c.ethics.reputation >= -6 and c.ethics.reputation <= 6) \
		.override_failure_message("Репутация вне 2×якорь [−3,+3]").is_true()
	assert_bool(battle_events > 0) \
		.override_failure_message("за 21 хода — ни одного этического события боя").is_true()
	# Городской контур жив после всех сверок: рабочие назначены, настроение в шкале.
	for b in c.settlement.buildings:
		assert_bool(b.has("workers")) \
			.override_failure_message("районный слой не проведён: " + str(b.get("id", ""))).is_true()
	assert_bool(c.districts.mood.size() == 8).is_true()
