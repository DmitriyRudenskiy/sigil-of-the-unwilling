extends BaseTest

## dnd-battle-ladder 4.2 (02d §4): Удача — 7-я характеристика.
## Пул ОУ = 1 + modLuck; Fate Shift (1 ОУ) — результат на ступень вверх;
## Save (2 ОУ) — критпровал → провал; Долг судьбы (K-R1) — на исчерпании
## пула (явный отказ). Авто-политика (auto_luck) — детерминистичная (K2):
## Save при fumble, Fate Shift при partial/failure (консервативно: success
## не «жжёт» на triumph), только при достаточном пуле (долг — ручной слой).

const CampaignBattleScript := preload("res://scripts/campaign/campaign_battle.gd")


func _w(spec: Dictionary) -> Dictionary:
	var base := {
		"id": "hero", "character_uid": 1, "hp": 11, "ac": 12, "attack": 13,
		"damage": 5, "luck": 0, "dex": 12, "con": 1, "proficiency": 2,
	}
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


## Бесшумный противник (урон 0) — бой не заканчивается его ударами.
func _dummy(spec: Dictionary) -> Dictionary:
	var base := {
		"id": "dummy", "character_uid": 77, "hp": 10, "ac": 11, "attack": 0,
		"damage": 0, "luck": 0, "dex": 12, "con": 1, "proficiency": 1,
	}
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


## Первый удар героя (инициатива не гарантирована: "dummy" < "hero").
func _first_strike(report: Dictionary) -> Dictionary:
	for t in report["trace"]:
		var e: Dictionary = t
		if str(e.get("actor", "")) == "hero" and e.has("zone"):
			return e
	fail("нет удара героя в trace")
	return {}


## — Пул ОУ = 1 + modLuck —

func test_luck_pool_init() -> void:
	assert_int(int(CampaignBattleScript.make_combatant({"luck": 0})["luck_ou"])).is_equal(1)
	assert_int(int(CampaignBattleScript.make_combatant({"luck": 2})["luck_ou"])).is_equal(3)
	assert_int(int(CampaignBattleScript.make_combatant({"luck": -2})["luck_ou"])) \
		.override_failure_message("пул не отрицательный").is_equal(0)


## — Fate Shift / Save: учёт пула и Долг судьбы (K-R1) —

func test_fate_shift_spends_one_ou() -> void:
	var c := _w({"luck_ou": 3})
	assert_bool(CampaignBattleScript.fate_shift(c)).is_true()
	assert_int(int(c["luck_ou"])).is_equal(2)


func test_fate_shift_denied_records_debt() -> void:
	var c := _w({"luck_ou": 0})
	assert_bool(CampaignBattleScript.fate_shift(c)).is_false()
	assert_int(int(c["fate_debt"])).override_failure_message("отказ → Долг судьбы (K-R1)").is_equal(1)


func test_save_action_spends_two_ou() -> void:
	var c := _w({"luck_ou": 3})
	assert_bool(CampaignBattleScript.save_action(c)).is_true()
	assert_int(int(c["luck_ou"])).is_equal(1)


func test_save_action_denied_records_debt() -> void:
	var c := _w({"luck_ou": 1})
	assert_bool(CampaignBattleScript.save_action(c)).is_false()
	assert_int(int(c["fate_debt"])).is_equal(1)


func test_step_up_ladder() -> void:
	var z: StringName = CampaignBattleScript.step_up(&"fumble")
	assert_str(str(z)).is_equal("failure")
	z = CampaignBattleScript.step_up(&"failure")
	assert_str(str(z)).is_equal("partial")
	z = CampaignBattleScript.step_up(&"partial")
	assert_str(str(z)).is_equal("success")
	z = CampaignBattleScript.step_up(&"success")
	assert_str(str(z)).is_equal("triumph")
	z = CampaignBattleScript.step_up(&"triumph")
	assert_str(str(z)).override_failure_message("триумф — верх").is_equal("triumph")


## — Авто-политика (auto_luck) в бою —

## partial (−1) + 1 ОУ → Fate Shift → success (урон 2 → 5), пул → 0.
func test_auto_luck_fate_shift_partial_to_success() -> void:
	var hero := _w({"attack": 10, "auto_luck": true})
	var report := CampaignBattleScript.resolve(hero, _dummy({}))
	var hit: Dictionary = _first_strike(report)
	assert_int(int(hit["margin"])).is_equal(-1)
	assert_str(str(hit["zone"])).override_failure_message("Fate Shift: partial → success").is_equal("success")
	assert_int(int(hit["damage"])).is_equal(5)
	assert_str(str(hit["luck_used"])).is_equal("fate_shift")
	assert_int(int(hero["luck_ou"])).override_failure_message("пул 1 → 0").is_equal(0)


## fumble (−9 при luck 1: порог ≤ −(8+1)) + 2 ОУ → Save → failure.
func test_auto_luck_save_fumble_to_failure() -> void:
	var report := CampaignBattleScript.resolve(
		_w({"attack": 2, "auto_luck": true, "luck": 1}), _dummy({}))
	var hit: Dictionary = _first_strike(report)
	assert_int(int(hit["margin"])).override_failure_message("2 − 11 = −9").is_equal(-9)
	assert_str(str(hit["zone"])).override_failure_message("Save: fumble → failure").is_equal("failure")
	assert_str(str(hit["luck_used"])).is_equal("save")


## Консервативность: success не «жжёт» на triumph — пул не тратится.
func test_auto_luck_no_spend_on_success() -> void:
	var hero := _w({"attack": 12, "auto_luck": true})
	var report := CampaignBattleScript.resolve(hero, _dummy({}))
	var hit: Dictionary = _first_strike(report)
	assert_str(str(hit["zone"])).is_equal("success")
	assert_str(str(hit["luck_used"])).is_equal("")
	assert_int(int(hero["luck_ou"])).override_failure_message("пул не тронут").is_equal(1)


## Исчерпанный пул: авто-политика не просит → ни сдвига, ни Долга.
func test_auto_luck_empty_pool_no_debt() -> void:
	var hero := _w({"attack": 10, "auto_luck": true, "luck_ou": 0})
	var report := CampaignBattleScript.resolve(hero, _dummy({}))
	var hit: Dictionary = _first_strike(report)
	assert_str(str(hit["zone"])).is_equal("partial")
	assert_str(str(hit["luck_used"])).is_equal("")
	assert_int(int(hero["fate_debt"])).override_failure_message("долга нет (авто не просит)").is_equal(0)


## Back-compat: без auto_luck Удача не тратится (существующие бои не меняются).
func test_luck_inert_without_auto_flag() -> void:
	var hero := _w({"attack": 10})
	var report := CampaignBattleScript.resolve(hero, _dummy({}))
	var hit: Dictionary = _first_strike(report)
	assert_str(str(hit["zone"])).is_equal("partial")
	assert_str(str(hit["luck_used"])).is_equal("")
	assert_int(int(hero["luck_ou"])).is_equal(1)
