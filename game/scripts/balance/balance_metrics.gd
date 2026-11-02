extends SceneTree
## T-041 (раунд 8): метрик-харнесс баланс-прогона. Прогон composition root
## кампании (тот же CampaignComposition, что и main.gd — анти-дубль) и пишет
## трассы: кривые запасов, ход первого WARN/DEFICIT, Престиж-сальдо по ходам,
## потери населения — в res://balance_report.json (CI-2 artifact).
## Якоря (вердикты в отчёте, приказ раунда 8 §4): food-chain (без стройки /
## с базовой стройкой ферм), k_mig (0.25 × 8 = 2 ≈ рождаемость), взаимная
## сбалансированность троих против босса (K-M15), Престиж-коридор хода 21
## (500–999), parity-начисление. Харнесс — только метрики; гейт — тесты
## tests/balance/test_t041_anchors.gd. Запуск: godot --headless --path game
## --script res://scripts/balance/balance_metrics.gd

const SEED := 12345
const OUT_PATH := "res://balance_report.json"
const CLASSES: Array = ["warrior", "ranger", "mage"]
const RAIDERS: Array = ["raider_tier_1", "raider_tier_2", "raider_tier_3", "raider_final"]
## «Базовая стройка ферм» (детерминированный скрипт сценария B): +1 ферма
## после ходов 1/5/9/13/17 (активна с ходов 2/6/10/14/18).
const FARM_EVERY_TURNS := 4
const FARM_FIRST_AFTER := 1


func _initialize() -> void:
	var report := {
		"seed": SEED,
		"runs": {
			"no_build": _run_campaign(false),
			"basic_farms": _run_campaign(true),
		},
		"k_mig": _k_mig_check(),
		"mutual_balance": _mutual_balance(),
	}
	report["anchors"] = _verdicts(report)
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	for key in (report["anchors"] as Dictionary).keys():
		print("ANCHOR %s: %s" % [key, JSON.stringify((report["anchors"] as Dictionary)[key])])
	print("REPORT: %s" % ProjectSettings.globalize_path(OUT_PATH))
	quit(0)


## Один прогон кампании 21 хода; farms=true — базовая стройка ферм.
func _run_campaign(farms: bool) -> Dictionary:
	var comp := CampaignComposition.from_campaign_config(SEED)
	var trace: Array = []
	while not comp.campaign.is_done() and trace.size() < 30:
		comp.advance_turn()
		var t := comp.campaign.current_turn
		var bal := 0.0
		var ids: Array = []
		for e in comp.prestige_ledger:
			bal += float(e["amount"])
			ids.append(str(e["id"]))
		trace.append({
			"turn": t,
			"stocks": {
				"food": comp.settlement.stocks["food"],
				"wood": comp.settlement.stocks["wood"],
				"iron": comp.settlement.stocks["iron"],
			},
			"sm_food": str(comp.settlement.sm.get("food", {}).get("state", "OK")),
			"prestige_balance": bal,
			"ledger_ids": ids,
			"population": comp.population_system.size(),
			"raids_count": comp.threats.raids_count,
		})
		if farms and t >= FARM_FIRST_AFTER \
				and (t - FARM_FIRST_AFTER) % FARM_EVERY_TURNS == 0:
			comp.settlement.buildings.append({"id": "farm",
				"group": "Земледельцы и Пивовары",
				"output_day": {"food": 1.0}, "efficiency": 1.0})
	var v: Dictionary = comp.victory_assessment()
	return {
		"trace": trace,
		"first_warn_turn": _first_state_turn(trace, "WARN"),
		"first_deficit_turn": _first_state_turn(trace, "DEFICIT"),
		"final": v,
		"ledger": comp.prestige_ledger,
	}


func _first_state_turn(trace: Array, state: String) -> int:
	for row in trace:
		if str((row as Dictionary)["sm_food"]) == state:
			return int((row as Dictionary)["turn"])
	return -1


## k_mig-якорь: net_за_ход = k_mig × (Репутация − нейтрал) = 0.25 × 8 = 2 ≈
## рождаемость за ход (k_pop 0.1 × 20 дней). Число канонизировано — прогон
## подтверждает (приказ раунда 8 §4.4).
func _k_mig_check() -> Dictionary:
	var pop := PopulationSystem.new()
	pop.seed_population(20)
	var r: Dictionary = pop.process_turn(WorldSeasons.DAYS_PER_SEASON, 8.0)
	return {
		"reputation": 8.0,
		"immigrants": int(r["immigrants"]),
		"births": int(r["births"]),
		"k_mig_per_turn": pop.k_mig_per_turn,
	}


## K-M15-инвариант: трое взаимно сбалансированы против босс-биома — одинаковый
## исход у всех классов на каждом рейдере (детерминированный резолвер, T-050).
func _mutual_balance() -> Dictionary:
	var f := FileAccess.open("res://data/config/balance/campaign.json", FileAccess.READ)
	var scenario: Dictionary = JSON.parse_string(f.get_as_text())
	var sb: Dictionary = scenario.get("unit_statblocks", {})
	var out := {}
	for raider_key in RAIDERS:
		var results := {}
		for cls in CLASSES:
			var hero := CampaignBattle.make_recruit(sb[cls], -1)
			hero["id"] = "hero"
			var raider := CampaignBattle.make_combatant(sb[raider_key])
			raider["id"] = "raider"
			var rep: Dictionary = CampaignBattle.resolve(hero, raider)
			results[cls] = {
				"outcome": str(rep["outcome"]),
				"rounds": int(rep["rounds"]),
				"losses": (rep["losses"] as Array).size(),
			}
		var outcomes := {}
		for cls in results.keys():
			outcomes[str((results[cls] as Dictionary)["outcome"])] = true
		out[raider_key] = {"per_class": results, "single_outcome": outcomes.size() == 1}
	return out


func _verdicts(report: Dictionary) -> Dictionary:
	var runs: Dictionary = report["runs"]
	var a: Dictionary = runs["no_build"]
	var b: Dictionary = runs["basic_farms"]
	var mb: Dictionary = report["mutual_balance"]
	var boss: Dictionary = mb.get("raider_tier_3", {})
	var final_a: Dictionary = a.get("final", {})
	var bal := float(final_a.get("prestige_balance", 0.0))
	var parity_fired := false
	for e in (a["ledger"] as Array):
		if str((e as Dictionary)["id"]).begins_with("parity_"):
			parity_fired = true
	var km: Dictionary = report["k_mig"]
	return {
		"food_chain_no_build": {
			"met": int(a["first_deficit_turn"]) >= 7 or int(a["first_deficit_turn"]) < 0,
			"first_deficit_turn": a["first_deficit_turn"],
		},
		"food_chain_basic_farms": {
			"met": int(b["first_deficit_turn"]) < 0,
			"first_deficit_turn": b["first_deficit_turn"],
		},
		"k_mig": {
			"met": int(km["immigrants"]) == 2 and int(km["births"]) == 2,
			"immigrants": km["immigrants"], "births": km["births"],
		},
		"mutual_balance_vs_boss": {
			"met": bool(boss.get("single_outcome", false)) \
				and str((boss.get("per_class", {}) as Dictionary)
					.get("warrior", {}).get("outcome", "")) == "win",
			"per_class": boss.get("per_class", {}),
		},
		"prestige_corridor_turn21": {
			"met": bool(final_a.get("prestige_anchor_met", false)),
			"balance": bal, "corridor": "500..999",
		},
		"parity_fired": {"met": parity_fired},
		"final_raid_repelled": {"met": bool(final_a.get("final_raid_repelled", false))},
	}
