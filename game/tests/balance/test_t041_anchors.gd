extends BaseTest

## T-041 (раунд 8 §4): якоря баланс-прогона. Каждый тест — один якорь приказа;
## числа калиброваны прогоном (balance_metrics.gd → CI-2 artifact), тесты
## держат якоря как регрессию. Сид один (12345, MVP — точечная проверка;
## ансамблевые метрики [0.4,0.6] перенесены на 1.0/автобалансировщика —
## зафиксировано в TICKETS T-041).

const SEED := 12345


func _run_to_done(farms: bool = false) -> Dictionary:
	var comp := CampaignComposition.from_campaign_config(SEED)
	var deficit_turns: Array = []
	while not comp.campaign.is_done():
		comp.advance_turn()
		if str(comp.settlement.sm.get("food", {}).get("state", "OK")) == "DEFICIT":
			deficit_turns.append(comp.campaign.current_turn)
		if farms and (comp.campaign.current_turn - 1) % 4 == 0 \
				and comp.campaign.current_turn >= 1:
			comp.settlement.buildings.append({"id": "farm",
				"group": "Земледельцы и Пивовары",
				"output_day": {"food": 1.0}, "efficiency": 1.0})
	return {"comp": comp, "deficit_turns": deficit_turns}


func _statblocks() -> Dictionary:
	var f := FileAccess.open("res://data/config/balance/campaign.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text()).get("unit_statblocks", {})


## — Якорь 3a: food-chain без стройки — не DEFICIT до хода 7 (cutover-акт §2) —

func test_food_chain_no_build_deficit_not_before_turn7() -> void:
	var r := _run_to_done(false)
	var first: int = 22
	for t in (r["deficit_turns"] as Array):
		first = mini(first, int(t))
	assert_int(first).is_greater_equal(7)


## — Якорь 3b: food-chain с базовой стройкой ферм — не DEFICIT до хода 21 —

func test_food_chain_basic_farms_no_deficit() -> void:
	var r := _run_to_done(true)
	assert_array(r["deficit_turns"]).is_empty()


## — Якорь 4: k_mig 0.25 × 8 = 2 ≈ рождаемость за ход (F-3, K-M12) —

func test_k_mig_anchor_matches_births() -> void:
	var pop := PopulationSystem.new()
	pop.seed_population(20)
	var rep: Dictionary = pop.process_turn(WorldSeasons.DAYS_PER_SEASON, 8.0)
	assert_int(int(rep["immigrants"])).is_equal(2)
	assert_int(int(rep["births"])).is_equal(2)


## — Якорь 1: K-M15 — трое взаимно сбалансированы против босса (одинаковый
## исход у всех классов; босс = якорь ур.5, E4/Q-M13) и отражаются —

func test_mutual_balance_vs_boss_all_win() -> void:
	var sb := _statblocks()
	var outcomes := {}
	for cls in ["warrior", "ranger", "mage"]:
		var hero := CampaignBattle.make_recruit(sb[cls], -1)
		hero["id"] = "hero"
		var raider := CampaignBattle.make_combatant(sb["raider_tier_3"])
		raider["id"] = "raider"
		var rep: Dictionary = CampaignBattle.resolve(hero, raider)
		outcomes[str(rep["outcome"])] = true
		assert_str(str(rep["outcome"])).is_equal("win")
		assert_array(rep["losses"]).is_empty()
	assert_int(outcomes.size()).is_equal(1)  # взаимная сбалансированность


## — Тот же инвариант на каждом рейдере (лестница кампании) —

func test_mutual_balance_all_raiders_single_outcome() -> void:
	var sb := _statblocks()
	for key in ["raider_tier_1", "raider_tier_2", "raider_tier_3", "raider_final"]:
		var outcomes := {}
		for cls in ["warrior", "ranger", "mage"]:
			var hero := CampaignBattle.make_recruit(sb[cls], -1)
			hero["id"] = "hero"
			var raider := CampaignBattle.make_combatant(sb[key])
			raider["id"] = "raider"
			outcomes[str(CampaignBattle.resolve(hero, raider)["outcome"])] = true
		assert_int(outcomes.size()).is_equal(1)


## — Якорь 5: Престиж-коридор хода 21 = «Почитаемый» 500–999 (точечная
## проверка, один сид; красная метка: корректируются числа источников) —

func test_prestige_corridor_turn21() -> void:
	var comp: CampaignComposition = _run_to_done(false)["comp"]
	var v: Dictionary = comp.victory_assessment()
	var bal := float(v["prestige_balance"])
	assert_bool(bal >= 500.0 and bal < 1000.0).is_true()
	assert_bool(bool(v["prestige_anchor_met"])).is_true()


## — Якорь 2: parity_le_0.8 разморожен — начисляется против превосходящих
## (босс cr 7 ≥ героя cr 5 / 0.8) и НЕ начисляется против равных/слабых —

func test_parity_accrued_only_vs_superior() -> void:
	var comp: CampaignComposition = _run_to_done(false)["comp"]
	var parity_ids: Array = []
	for e in comp.prestige_ledger:
		if str(e["id"]).begins_with("parity_"):
			parity_ids.append(str(e["id"]))
	assert_array(parity_ids).contains("parity_t3")
	assert_bool("parity_t1" in parity_ids).is_false()
	assert_bool("parity_t2" in parity_ids).is_false()


## — Победная оценка: финальный рейд отражён (победа достижима на baseline) —

func test_final_raid_repelled() -> void:
	var comp: CampaignComposition = _run_to_done(false)["comp"]
	assert_bool(comp.final_raid_repelled).is_true()
	assert_bool(bool(comp.victory_assessment()["victory"])).is_true()
