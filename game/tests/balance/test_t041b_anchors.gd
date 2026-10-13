extends BaseTest

## T-041b (акт раунда 16 §3): интеграционный калибровочный перегон —
## T-030 + T-124 в одном дереве. Якоря 2–6; якорь 1 (food-chain) — в
## test_t041_anchors.gd, не меняется. Сценарии 3/4 — конфигами (scenarios).
## Числа — с атрибуцией прогона (ансамбль сидов, main после b7719c15).
## Красный якорь = калибровка числа с атрибуцией, не правка канона (D-180).

const SEEDS: Array = [12345, 777, 4242, 900001, 55]

## Сценарии-конфиги: basic — автопилот без стройки; farms — базовая стройка
## (ферма каждые 4 хода); losses — гибель трёх защитников в бою хода 6
## (тот же шов battle_report.losses, что эмитирует CampaignBattle).
const SCENARIOS := {
	"basic": {"farms": false, "losses": false},
	"farms": {"farms": true, "losses": false},
	"losses": {"farms": false, "losses": true},
}


func _run(seed_v: int, scenario: Dictionary) -> Dictionary:
	var c := CampaignComposition.from_campaign_config(seed_v)
	c.set_sign("spark")
	var mood10 := 0.0
	while not c.campaign.is_done():
		var t := c.campaign.current_turn
		c.advance_turn()
		if scenario.get("farms", false) and c.campaign.current_turn % 4 == 0:
			c.settlement.buildings.append({"id": "farm", "group": "Земледельцы и Пивовары",
				"output_day": {"food": 1.0}, "efficiency": 1.0})
		if scenario.get("losses", false) and t == 6:
			var uids: Array = []
			for r in c.population_system.residents.slice(0, 3):
				uids.append(int(r["uid"]))
			c._on_battle_losses(uids, {})
		if t == 10:
			var s := 0.0
			for k in c.districts.mood.keys():
				s += float(c.districts.mood[k])
			mood10 = s / maxf(1.0, float(c.districts.mood.size()))
	return {"rep": c.ethics.reputation, "mood10": mood10,
		"prestige": float(c.victory_assessment().get("prestige_balance", 0.0))}


## — Якорь 2 (D-179-обещание): настроение районов к ходу 10 не на полу —
##   при базовой стройке. Замер ансамбля: 100.0 (пол = 0; без стройки — 0,
##   голод-петля D-179, это известный сценарий, не якорь). —

func test_t041b_mood_not_at_floor_with_basic_build() -> void:
	for seed_v in SEEDS:
		var r := _run(seed_v, SCENARIOS["farms"])
		assert_float(r["mood10"]).override_failure_message(
			"настроение районов на полу при базовой стройке (seed %d)" % seed_v).is_greater(0.0)


## — Якорь 3 (D-180): согласованная игра — Репутация ∈ [+2,+6] на ансамбле. —

func test_t041b_reputation_aligned_ensemble_in_corridor() -> void:
	for seed_v in SEEDS:
		var rep: int = _run(seed_v, SCENARIOS["basic"])["rep"]
		assert_bool(rep >= 2 and rep <= 6).override_failure_message(
			"Репутация %d вне [+2,+6] (seed %d, согласованная игра)" % [rep, seed_v]).is_true()


## — Якорь 4 (D-180): сценарий с потерями — Репутация ∈ [−3,+3] на ансамбле. —

func test_t041b_reputation_losses_ensemble_in_window() -> void:
	for seed_v in SEEDS:
		var rep: int = _run(seed_v, SCENARIOS["losses"])["rep"]
		assert_bool(rep >= -3 and rep <= 3).override_failure_message(
			"Репутация %d вне [−3,+3] (seed %d, сценарий с потерями)" % [rep, seed_v]).is_true()


## — Якорь 5 (T-041): Престиж 500–999 к ходу 21 — на ансамбле. —

func test_t041b_prestige_ensemble_in_band() -> void:
	for seed_v in SEEDS:
		var p: float = _run(seed_v, SCENARIOS["basic"])["prestige"]
		assert_bool(p >= 500.0 and p <= 999.0).override_failure_message(
			"Престиж %.0f вне [500,999] (seed %d)" % [p, seed_v]).is_true()


## — Якорь 6 (T-030-недосдача): «3-в-1» достижим к ходу 21 при специализации.
##   Спец-стройка campaign_farm×2 + terrascape_fruit_farm в цикл-такт (4 хода)
##   → 3 постройки к ходу 9; слияние по реальному каталогу. —

func test_t041b_merge_three_reachable_by_turn21() -> void:
	var c := CampaignComposition.from_campaign_config(12345)
	c.set_sign("spark")
	var spec: Array = ["campaign_farm", "campaign_farm", "terrascape_fruit_farm"]
	var built := 0
	while not c.campaign.is_done():
		c.advance_turn()
		if built < spec.size() and c.campaign.current_turn % 4 == 0:
			c.settlement.buildings.append({"id": spec[built],
				"group": "Земледельцы и Пивовары", "output_day": {}, "efficiency": 1.0})
			built += 1
	assert_int(c.campaign.current_turn).is_less_equal(21)
	var res := DistrictSystem.merge_three(c.settlement.buildings,
		CampaignBuildingCatalog.load_catalog(), "terrascape_fruit_farm")
	assert_bool(bool(res.get("ok", false))).override_failure_message(
		"3-в-1 недостижим при спец-стройке: %s" % str(res.get("reason", ""))).is_true()
