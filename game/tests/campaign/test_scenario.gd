extends BaseTest

## T-117: campaign-сценарий 21 дня (остаток T-112). Покрывает AC тикета и
## состав 14-й итерации (раунд 3 §2.3): сверка с бит-таблицей 04-narrative
## (каркас K-M9 1/7/14/17/21; слух хода 3 — Post-MVP-строка; смерть 10 —
## условный), биты-угрозы — ссылки на директивы raids.json (сверить ссылки,
## не дублировать числа), стартовое состояние R2 из конфига, победные условия
## MVP-среза (якорь «ход 21 = финальный рейд отражён/нет» + Престиж-якорь),
## seed-политика (CAMPAIGN_SEED — I1), состав населения — первый эшелон 7.

const CAMPAIGN_PATH := "res://data/config/balance/campaign.json"
const RAIDS_PATH := "res://data/config/balance/raids.json"
const PRESTIGE_PATH := "res://data/config/balance/prestige.json"
const CATALOG_PATH := "res://assets/data/mvp_catalog.json"


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_bool(f != null).is_true()
	var data: Variant = JSON.parse_string(f.get_as_text())
	assert_bool(typeof(data) == TYPE_DICTIONARY).is_true()
	return data


func _has_num(arr: Array, v: float) -> bool:
	# JSON-числа приходят float-ами — сравнение по значению, не по типу.
	for e in arr:
		if float(e) == v:
			return true

	return false


## — Бит-таблица 04-narrative —

func test_beat_skeleton_mvp() -> void:
	# Каркас K-M9: 1/7/14/17/21 — MVP; слух (3) — Post-MVP-строка той же схемы.
	var beats: Dictionary = _json(CAMPAIGN_PATH).get("beats", {})
	for turn in ["1", "7", "14", "17", "21"]:
		assert_bool(beats.has(turn)).is_true()
	assert_bool(beats.has("3")).is_true()
	assert_str(str((beats["3"] as Dictionary).get("status", ""))).contains("Post-MVP")
	# Смерть персонажа (10) — условный бит, вне MVP-каркаса.
	assert_str(str((beats["10"] as Dictionary).get("status", ""))).contains("условный")


func test_threat_beats_are_links_not_copies() -> void:
	# Биты-угрозы — ссылки на директивы raids.json; числа (turn/tier/cr)
	# в beats отсутствуют — иначе три источника истины (T-121).
	var beats: Dictionary = _json(CAMPAIGN_PATH).get("beats", {})
	var links := {
		"7": "raids.json#directives.first_raid",
		"14": "raids.json#directives.district",
		"17": "raids.json#directives.strong_raid",
		"21": "raids.json#directives.final_raid",
	}
	for turn in links.keys():
		var beat: Dictionary = beats[turn]
		assert_str(str(beat.get("directive", ""))).is_equal(str(links[turn]))
		for forbidden in ["turn", "tier", "cr", "enemies"]:
			assert_bool(not beat.has(forbidden)).is_true()


func test_beat_directive_links_resolve() -> void:
	# Ссылки битов разрешаются в raids.json; ходы директив = ходы битов
	# (сверка с бит-таблицей: ≈7/14/≈17/≤21).
	var raids: Dictionary = _json(RAIDS_PATH)
	var directives: Dictionary = raids.get("directives", {})
	var expected := {"first_raid": 7, "district": 14, "strong_raid": 17, "final_raid": 21}
	for key in expected.keys():
		var d: Dictionary = directives.get(key, {})
		assert_bool(not d.is_empty()).is_true()
		assert_int(int(d.get("turn", 0))).is_equal(int(expected[key]))
	# Финал — босс (K-R3: wave.composition = босс).
	assert_bool(bool(directives.get("final_raid", {}).get("boss", false))).is_true()


## — Стартовое состояние (R2) и состав населения —

func test_start_state_r2_from_config() -> void:
	var start: Dictionary = _json(CAMPAIGN_PATH).get("start_state", {})
	assert_int(int(start.get("population", 0))).is_equal(20)
	assert_int(int(start.get("housing", 0))).is_equal(20)
	var res: Dictionary = start.get("resources", {})
	# Еда 130 — T-041 food-chain якорь (было 30, R2): без стройки DEFICIT
	# не ранее хода 7 (нетто −1/день × 120 дней). Атрибуция — TICKETS T-041.
	assert_int(int(res.get("food", 0))).is_equal(130)
	assert_int(int(res.get("wood", 0))).is_equal(20)
	assert_int(int(res.get("iron", 0))).is_equal(10)


func test_population_composition_first_tier_7() -> void:
	# Первый эшелон 7 (K-M5, T-001): каталог и сценарий согласованы (ссылка).
	var scenario: Dictionary = _json(CAMPAIGN_PATH).get("scenario", {})
	var comp: Dictionary = scenario.get("population_composition", {})
	assert_int(int(comp.get("first_tier_races", 0))).is_equal(7)
	var first_tier := 0
	for r in _json(CATALOG_PATH).get("races", []):
		if bool((r as Dictionary).get("first_tier", false)):
			first_tier += 1
	assert_int(first_tier).is_equal(7)


## — Победные условия MVP-среза —

func test_victory_anchor_turn21_final_raid() -> void:
	var victory: Dictionary = _json(CAMPAIGN_PATH).get("scenario", {}).get("victory", {})
	assert_str(str(victory.get("anchor", ""))).contains("ход 21")
	assert_str(str(victory.get("anchor", ""))).contains("final_raid")
	assert_str(str(victory.get("defeat", ""))).contains("не отражён")


func test_prestige_anchor_matches_ranks() -> void:
	# «Почитаемый» 500–999, касание «Славного» 1000 — шкала prestige.json.
	var ranks: Array = _json(PRESTIGE_PATH).get("ranks", [])
	assert_bool(_has_num(ranks, 500.0)).is_true()
	assert_bool(_has_num(ranks, 1000.0)).is_true()
	var victory: Dictionary = _json(CAMPAIGN_PATH).get("scenario", {}).get("victory", {})
	assert_str(str(victory.get("prestige_anchor", ""))).contains("500")
	assert_str(str(victory.get("prestige_anchor", ""))).contains("1000")


## — Seed-политика (I1) —

func test_seed_policy_campaign_seed() -> void:
	var seed_policy: Dictionary = _json(CAMPAIGN_PATH).get("scenario", {}).get("seed_policy", {})
	assert_str(str(seed_policy.get("rule", ""))).contains("CAMPAIGN_SEED")
	assert_str(str(seed_policy.get("rule", ""))).contains("без ГСЧ")
	assert_str(str(seed_policy.get("carrier", ""))).contains("main.gd")


## — CR-якоря фаз покрывают 21 хода (сверка с бит-таблицей) —

func test_cr_phase_anchors_cover_campaign() -> void:
	var anchors: Dictionary = _json(CAMPAIGN_PATH).get("cr_anchors", {})
	var covered := {}
	for phase in anchors.keys():
		var rng: Array = anchors[phase].get("turns", [])
		for t in range(int(rng[0]), int(rng[1]) + 1):
			covered[t] = true
	# Покрытие без дыр и пересечений: ровно ходы 1..21.
	assert_int(covered.size()).is_equal(21)
	for t in range(1, 22):
		assert_bool(covered.has(t)).is_true()
	# Финал — 21, CR 6–8 (raids.json final_raid.cr = [6,8]).
	var final_turns: Array = anchors.get("final", {}).get("turns", [])
	assert_int(final_turns.size()).is_equal(2)
	assert_float(float(final_turns[0])).is_equal(21.0)
	assert_float(float(final_turns[1])).is_equal(21.0)
	var cr: Array = anchors.get("final", {}).get("cr", [])
	assert_float(float(cr[0])).is_equal(6.0)
	assert_float(float(cr[1])).is_equal(8.0)
