extends BaseTest

## T-050: бой K-канона кампании (состав акта 12-й итерации §3.4).
## Покрывает: инициатива «Удача+Ловкость» (тай-брейки), лестница 02d с
## трассировкой, детерминизм (без RNG — T-050 AC), маска K-M7 (prone +
## высотный статус сосуществуют), Долг судьбы Б.4 (Расплата + штраф 1,25),
## death saves 3/3 (mod ТЕЛ), лимит 20 раундов (D-128), шов §2.2
## (losses: [character_uid] + эмит в хук населения), A5-шов character_uid.

const CampaignBattleScript := preload("res://scripts/campaign/campaign_battle.gd")

var _warrior := {
	"id": "hero", "character_uid": 1, "hp": 11, "ac": 12, "attack": 13,
	"damage": 5, "luck": 0, "dex": 12, "con": 1, "proficiency": 2,
}
var _raider := {
	"id": "raider", "character_uid": 77, "hp": 7, "ac": 11, "attack": 12,
	"damage": 5, "luck": 0, "dex": 12, "con": 1, "proficiency": 1,
}


func _c(spec: Dictionary) -> Dictionary:
	var base := _warrior.duplicate(true)
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


func _r(spec: Dictionary) -> Dictionary:
	var base := _raider.duplicate(true)
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


## — Инициатива «Удача + Ловкость», один раз на бой —

func test_initiative_luck_plus_dex_sum() -> void:
	var a := _c({"luck": 1, "dex": 12})  # 13
	var b := _r({"luck": 2, "dex": 12})  # 14
	assert_str(CampaignBattleScript.initiative_first(a, b)).is_equal("raider")


func test_initiative_tie_breaks_on_dex() -> void:
	var a := _c({"luck": 0, "dex": 14})  # 14
	var b := _r({"luck": 2, "dex": 12})  # 14
	assert_str(CampaignBattleScript.initiative_first(a, b)).is_equal("hero")


func test_initiative_tie_breaks_on_id() -> void:
	var a := _c({"id": "aa", "luck": 0, "dex": 12})
	var b := _r({"id": "ab", "luck": 0, "dex": 12})
	assert_str(CampaignBattleScript.initiative_first(a, b)).is_equal("aa")


## — Лестница 02d + трассировка + детерминизм (T-050 AC: без RNG) —

func test_ladder_trace_present() -> void:
	var report := CampaignBattleScript.resolve(_c({}), _r({}))
	var trace: Array = report["trace"]
	assert_int(trace.size()).is_greater(0)
	var first: Dictionary = trace[0]
	assert_str(str(first["zone"])).is_equal("success")  # margin 13−11=+2, luck 0
	assert_int(int(first["margin"])).is_equal(2)
	assert_bool(bool(report["battle_over"])).is_true()


func test_determinism_same_inputs_same_report() -> void:
	var spec_a := JSON.stringify(_c({}))
	var spec_b := JSON.stringify(_r({}))
	var r1 := CampaignBattleScript.resolve(
		JSON.parse_string(spec_a), JSON.parse_string(spec_b))
	var r2 := CampaignBattleScript.resolve(
		JSON.parse_string(spec_a), JSON.parse_string(spec_b))
	assert_str(JSON.stringify(r1)).is_equal(JSON.stringify(r2))


## — Маска K-M7: prone + высотный статус сосуществуют —

func test_prone_and_elevated_mask_coexist() -> void:
	var atk := _c({"prone": true, "elevated": true})
	var def_ := _r({"prone": true, "elevated": false})
	# prone-атакующий −2, prone-цель +2, высота +2 (по наземному) → +2.
	assert_int(CampaignBattleScript._state_margin(atk, def_))\
		.is_equal(GameNumbers.ADVANTAGE_MARGIN)


func test_elevated_defender_penalizes_attacker() -> void:
	var atk := _c({})
	var def_ := _r({"elevated": true})
	assert_int(CampaignBattleScript._state_margin(atk, def_))\
		.is_equal(-GameNumbers.ADVANTAGE_MARGIN)


## — Долг судьбы (02d §4.2, таблица Б.4) —

func test_fate_debt_reckoning_steps_down_and_resets() -> void:
	var a := _c({"attack": 12, "damage": 1, "fate_debt": 2})  # порог = проф 2
	var b := _r({"hp": 100, "ac": 10, "attack": 0, "damage": 0, "id": "tank"})
	var report := CampaignBattleScript.resolve(a, b)
	var first: Dictionary = report["trace"][0]
	assert_bool(bool(first["reckoning"])).is_true()
	assert_str(str(first["zone"])).is_equal("partial")  # success → ступень ниже
	assert_int(int(a["fate_debt"])).is_equal(0)  # долг сброшен Расплатой


func test_fate_debt_penalty_divisor() -> void:
	var a := _c({"attack": 12, "damage": 1, "fate_debt": 1})  # 1 < порога 2
	var b := _r({"hp": 100, "ac": 10, "attack": 0, "damage": 0, "id": "tank"})
	var report := CampaignBattleScript.resolve(a, b)
	var first: Dictionary = report["trace"][0]
	assert_bool(bool(first["reckoning"])).is_false()
	# «Судьба следит»: margin floor(2 / 1,25) = 1.
	assert_int(int(first["margin"])).is_equal(1)


## — Death saves 3/3 (mod ТЕЛ); потери — только погибшие —

func test_death_saves_death_below_zero_con() -> void:
	var a := _c({"attack": 25, "damage": 5})  # margin 14 → Триумф, ×2
	var report := CampaignBattleScript.resolve(a, _r({"con": -1}))
	assert_str(str(report["outcome"])).is_equal("win")
	assert_array(report["losses"]).contains_exactly([77])


func test_death_saves_stabilize_at_or_above_zero() -> void:
	var a := _c({"attack": 25, "damage": 5})
	var b := _r({"con": 0})
	var report := CampaignBattleScript.resolve(a, b)
	assert_str(str(report["outcome"])).is_equal("win")  # выбыл — бой кончен
	assert_int((report["losses"] as Array).size()).is_equal(0)  # не потеря
	assert_bool(bool(b["dead"])).is_false()


## — Лимит 20 раундов — ничья (D-128) —

func test_20_round_limit_is_draw() -> void:
	var a := _c({"hp": 100, "attack": 5, "damage": 0})
	var b := _r({"hp": 100, "attack": 5, "damage": 0})
	var report := CampaignBattleScript.resolve(a, b)
	assert_str(str(report["outcome"])).is_equal("draw")
	assert_int(int(report["rounds"])).is_equal(20)


## — Шов §2.2: losses + эмит в хук населения; A5: character_uid —

func test_losses_are_character_uids_and_hook_emits() -> void:
	var captured: Array = []
	var hook := func(losses: Array, _report: Dictionary) -> void:
		captured.append(losses)
	var a := _c({"attack": 25})
	var report := CampaignBattleScript.resolve(a, _r({"con": -2}), hook)
	assert_array(report["losses"]).contains_exactly([77])
	assert_int(captured.size()).is_equal(1)  # эмит с дня первого боя
	assert_array(captured[0]).contains_exactly([77])


func test_hook_emits_even_with_empty_losses() -> void:
	var captured: Array = []
	var hook := func(losses: Array, _report: Dictionary) -> void:
		captured.append(losses)
	# Ничья 20 раундов — потерь нет, эмит обязан быть (§2.2).
	var a := _c({"hp": 100, "attack": 5, "damage": 0})
	var b := _r({"hp": 100, "attack": 5, "damage": 0})
	CampaignBattleScript.resolve(a, b, hook)
	assert_int(captured.size()).is_equal(1)
	assert_array(captured[0]).is_empty()


func test_make_recruit_carries_character_uid() -> void:
	var recruit := CampaignBattleScript.make_recruit(_warrior, 42)
	assert_int(int(recruit["character_uid"])).is_equal(42)
