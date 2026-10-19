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


## — 5.2: death saves margin_N = mod(CON) + supply(N=1) − (N−1) (Q-M57→(а)) —

func test_death_saves_margin_n_con1_two_success_one_fail() -> void:
	# con=1: N=1 (1≥0 успех), N=2 (0≥0 успех), N=3 (−1<0 провал) → 2/1 → не погиб.
	var a := _c({"attack": 25, "damage": 5})
	var b := _r({"con": 1})
	var report := CampaignBattleScript.resolve(a, b)
	assert_bool(bool(b["dead"])).is_false()
	assert_int((report["losses"] as Array).size()).is_equal(0)


func test_death_saves_margin_n_con2_three_success_wounded() -> void:
	# con=2: N=1 (2≥0), N=2 (1≥0), N=3 (0≥0) → 3 успеха = WOUNDED (не погиб).
	var a := _c({"attack": 25, "damage": 5})
	var b := _r({"con": 2})
	var report := CampaignBattleScript.resolve(a, b)
	assert_bool(bool(b["dead"])).is_false()
	assert_int((report["losses"] as Array).size()).is_equal(0)


func test_death_saves_supply_bonus_rescues_first_save() -> void:
	# con=−1, supply_bonus=2: N=1 (−1+2=1≥0 успех), N=2 (−2<0), N=3 (−3<0) →
	# 1/2 → не погиб (снабжение спасает 1-й спас, Q-M57→(а)).
	var a := _c({"attack": 25, "damage": 5})
	var b := _r({"con": -1, "supply_bonus": 2})
	var report := CampaignBattleScript.resolve(a, b)
	assert_bool(bool(b["dead"])).is_false()
	assert_int((report["losses"] as Array).size()).is_equal(0)


func test_death_saves_supply_bonus_not_enough() -> void:
	# con=−2, supply_bonus=2: N=1 (−2+2=0≥0 успех), N=2 (−3<0), N=3 (−4<0) →
	# 1/2 → не погиб. con=−3, supply_bonus=2: N=1 (−3+2=−1<0), N=2 (−4<0), N=3 (−5<0)
	# → 3 провала → смерть.
	var a := _c({"attack": 25, "damage": 5})
	var b := _r({"con": -3, "supply_bonus": 2})
	var report := CampaignBattleScript.resolve(a, b)
	assert_bool(bool(b["dead"])).is_true()
	assert_array(report["losses"]).contains_exactly([77])


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


## — Голод (party-characters 3.2 / campaign-core-loop 3.2, P-4) —

func test_hunger_penalty_default_zero() -> void:
	var c := CampaignBattleScript.make_combatant({})
	assert_int(int(c.get("hunger_penalty", 0))).is_equal(0)


func test_hunger_penalty_lowers_margin_and_zone() -> void:
	# attack 13 vs ac 12, luck 0: margin 1 → success (урон 5);
	# с голодом (−2): margin −1 → partial (урон 2, половина).
	var d1 := CampaignBattleScript.resolve(
		_c({"hp": 100}), _r({"hp": 100, "ac": 12}))
	var d2 := CampaignBattleScript.resolve(
		_c({"hp": 100, "hunger_penalty": -2}), _r({"hp": 100, "ac": 12}))
	var h1: Dictionary = d1["trace"][0]
	var h2: Dictionary = d2["trace"][0]
	assert_str(str(h1["actor"])) \
		.override_failure_message("герой ходит первым (тай-брейк ID)").is_equal("hero")
	assert_int(int(h1["margin"])).is_equal(1)
	assert_str(str(h1["zone"])).is_equal("success")
	assert_int(int(h1["damage"])).is_equal(5)
	assert_int(int(h2["margin"])) \
		.override_failure_message("голод: margin −2 (P-4)").is_equal(-1)
	assert_str(str(h2["zone"])).is_equal("partial")
	assert_int(int(h2["damage"])).is_equal(2)


## ═══════════ T-116 SM: WOUNDED/UNSTABLE (party-characters 2.1) ═══════════
## SM (02-mechanics §3.2): READY → WOUNDED (hit_dice ≤ 0) → UNSTABLE (спасы)
## → DEAD (3 провала) / WOUNDED (стабилизирован). Внутрибоевые состояния,
## не персистятся между боями (MVP-срез: потери = DEAD, раненые — не потери).

func test_state_default_ready() -> void:
	var c := CampaignBattleScript.make_combatant({})
	assert_str(str(c["state"])) \
		.override_failure_message("дефолт — READY").is_equal(CampaignBattleScript.STATE_READY)


func test_is_wounded_threshold() -> void:
	assert_bool(CampaignBattleScript.is_wounded_threshold(0)).is_true()
	assert_bool(CampaignBattleScript.is_wounded_threshold(-3)).is_true()
	assert_bool(CampaignBattleScript.is_wounded_threshold(1)).is_false()


func test_fall_stabilized_is_wounded_not_loss() -> void:
	# con 1: margin 1/0/−1 → 2 успеха, 1 провал → стабилизирован: WOUNDED,
	# не потеря (character_uid не в losses).
	var hero := _c({"hp": 1, "con": 1})
	var raider := _r({"hp": 100, "ac": 1})
	var d := CampaignBattleScript.resolve(hero, raider)
	assert_str(str(d["states"]["hero"])) \
		.override_failure_message("стабилизированный — WOUNDED").is_equal(CampaignBattleScript.STATE_WOUNDED)
	assert_str(str(d["states"]["raider"])).is_equal(CampaignBattleScript.STATE_READY)
	assert_int(d["losses"].size()).is_equal(0)
	var ds := _find_trace_zone(d, "death_saves")
	assert_str(str(ds["state"])) \
		.override_failure_message("trace: финальное состояние в death_saves").is_equal(CampaignBattleScript.STATE_WOUNDED)
	assert_bool(bool(ds["dead"])).is_false()


func test_fall_three_failures_is_dead_loss() -> void:
	# con −3: margin −3/−4/−5 → 3 провала → DEAD, потеря = character_uid.
	var hero := _c({"hp": 1, "con": -3})
	var raider := _r({"hp": 100, "ac": 1})
	var d := CampaignBattleScript.resolve(hero, raider)
	assert_str(str(d["states"]["hero"])) \
		.override_failure_message("3 провала — DEAD").is_equal(CampaignBattleScript.STATE_DEAD)
	assert_int(d["losses"].size()).is_equal(1)
	assert_int(d["losses"][0]).is_equal(1)


func test_unstable_entry_saves_before_round1() -> void:
	# «Следующий бой при HD = 0» (WOUNDED → UNSTABLE): вход с hp 0, спасброски
	# до раунда 1. con 3 → 3 успеха → WOUNDED (стабилизирован), бой
	# продолжается; 0 HP — не атакует, оппонент бьёт → падение → спасы снова
	# (con 3 → стабилизирован), 1v1-бой кончен.
	var hero := _c({"hp": 0, "con": 3})
	var d := CampaignBattleScript.resolve(hero, _r({}))
	assert_int(d["trace"].size()).is_greater(1)
	var t0: Dictionary = d["trace"][0]
	assert_int(int(t0["round"])) \
		.override_failure_message("входные спасброски — до раунда 1").is_equal(0)
	assert_str(str(t0["actor"])).is_equal("hero")
	assert_str(str(t0["zone"])).is_equal("death_saves")
	assert_str(str(t0["state"])) \
		.override_failure_message("3 успеха — WOUNDED").is_equal(CampaignBattleScript.STATE_WOUNDED)
	assert_str(str(d["states"]["hero"])).is_equal(CampaignBattleScript.STATE_WOUNDED)
	assert_str(str(d["states"]["raider"])).is_equal(CampaignBattleScript.STATE_READY)
	assert_int(d["losses"].size()).is_equal(0)


func test_unstable_entry_dead() -> void:
	# Вход с hp 0 + con −3 → 3 провала до раунда 1 → DEAD, бой кончен.
	var hero := _c({"hp": 0, "con": -3})
	var d := CampaignBattleScript.resolve(hero, _r({}))
	assert_int(int(d["rounds"])).is_equal(0)
	assert_str(str(d["outcome"])).is_equal("lose")
	assert_str(str(d["states"]["hero"])) \
		.override_failure_message("3 провала — DEAD").is_equal(CampaignBattleScript.STATE_DEAD)
	assert_int(d["losses"].size()).is_equal(1)


func test_unstable_entry_both_stabilized_draw() -> void:
	# Оба входят с 0 HP и стабилизируются → никто не атакует (0 HP) →
	# тупик — ничья.
	var hero := _c({"hp": 0, "con": 3})
	var raider := _r({"hp": 0, "con": 3})
	var d := CampaignBattleScript.resolve(hero, raider)
	assert_str(str(d["outcome"])) \
		.override_failure_message("оба 0 HP — ничья").is_equal("draw")
	assert_str(str(d["states"]["hero"])).is_equal(CampaignBattleScript.STATE_WOUNDED)
	assert_str(str(d["states"]["raider"])).is_equal(CampaignBattleScript.STATE_WOUNDED)


func test_states_not_persisted_between_battles() -> void:
	# MVP-срез (T-116): WOUNDED/UNSTABLE не переносятся между боями — каждый
	# бой начинается с READY (новый комбатант из статблока, state не в сейве).
	var hero1 := _c({"hp": 1, "con": 3})
	CampaignBattleScript.resolve(hero1, _r({"hp": 100, "ac": 1}))
	assert_str(str(hero1["state"])) \
		.override_failure_message("бой 1: герой стабилизирован").is_equal(CampaignBattleScript.STATE_WOUNDED)
	# Следующий бой — свежий комбатант (как делает кампания).
	var hero2 := _c({})
	assert_str(str(hero2["state"])) \
		.override_failure_message("бой 2: старт с READY").is_equal(CampaignBattleScript.STATE_READY)
	assert_int(int(hero2["hp"])).is_equal(11)


func _find_trace_zone(report: Dictionary, zone: String) -> Dictionary:
	for e in report.get("trace", []):
		var entry: Dictionary = e
		if str(entry.get("zone", "")) == zone:
			return entry
	return {}
