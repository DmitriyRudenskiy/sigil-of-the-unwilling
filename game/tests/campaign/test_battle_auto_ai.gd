extends BaseTest

## dnd-battle-ladder 2.1: авто-режим — детерминированный AI (min HP в
## досягаемости, тай-брейк меньший id) + отступление при «frightened».
## Тот же движок (CampaignBattle._strike/_death_saves), без координат (C-3:
## «в радиусе» = все живые). Не трогает существующий 1v1-путь (resolve).

const CampaignBattleScript := preload("res://scripts/campaign/campaign_battle.gd")


func _c(spec: Dictionary) -> Dictionary:
	var base := {
		"id": "p1", "character_uid": 1, "hp": 50, "ac": 12, "attack": 15,
		"damage": 8, "luck": 0, "dex": 12, "con": 2, "proficiency": 2,
	}
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


func _e(spec: Dictionary) -> Dictionary:
	var base := {
		"id": "e1", "character_uid": -1, "hp": 20, "ac": 10, "attack": 10,
		"damage": 5, "luck": 0, "dex": 10, "con": 1, "proficiency": 1,
	}
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


## — Выбор цели (авто-режим, 2.1): min HP, тай-брейк меньший id —

func test_select_target_min_hp() -> void:
	var foes := [
		_e({"id": "e1", "hp": 50}),
		_e({"id": "e2", "hp": 30}),
		_e({"id": "e3", "hp": 40}),
	]
	var target := CampaignBattleScript.select_target(foes)
	assert_str(str(target["id"])).is_equal("e2")  # min HP = 30


func test_select_target_tiebreak_smaller_id() -> void:
	var foes := [
		_e({"id": "e3", "hp": 30}),
		_e({"id": "e1", "hp": 30}),
		_e({"id": "e2", "hp": 40}),
	]
	var target := CampaignBattleScript.select_target(foes)
	assert_str(str(target["id"])).is_equal("e1")  # тай-брейк: меньший id


func test_select_target_skips_dead() -> void:
	var foes := [
		_e({"id": "e1", "hp": 0}),
		_e({"id": "e2", "hp": 30}),
	]
	var target := CampaignBattleScript.select_target(foes)
	assert_str(str(target["id"])).is_equal("e2")


func test_select_target_empty_when_no_alive() -> void:
	var foes := [
		_e({"id": "e1", "hp": 0}),
		_e({"id": "e2", "hp": 0}),
	]
	var target := CampaignBattleScript.select_target(foes)
	assert_bool(target.is_empty()).is_true()


## — Разрешение N vs M (авто-режим) —

func test_resolve_multi_party_wins() -> void:
	var party := [_c({"id": "p1", "hp": 100, "attack": 20, "damage": 15})]
	var enemies := [
		_e({"id": "e1", "hp": 10, "attack": 5, "damage": 1}),
		_e({"id": "e2", "hp": 10, "attack": 5, "damage": 1}),
	]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	assert_str(str(report["outcome"])).is_equal("win")


func test_resolve_multi_targets_min_hp_first() -> void:
	var party := [_c({"id": "p1", "hp": 100, "attack": 15, "damage": 5})]
	var enemies := [
		_e({"id": "e1", "hp": 40, "attack": 5, "damage": 1}),
		_e({"id": "e2", "hp": 10, "attack": 5, "damage": 1}),
	]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	var first_attack: Dictionary = (report["trace"] as Array)[0]
	assert_str(str(first_attack["target"])).is_equal("e2")  # min HP первым


func test_resolve_multi_party_loses() -> void:
	var party := [_c({"id": "p1", "hp": 10, "attack": 5, "damage": 1})]
	var enemies := [_e({"id": "e1", "hp": 100, "attack": 20, "damage": 15})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	assert_str(str(report["outcome"])).is_equal("lose")


func test_resolve_multi_retreat_on_frightened() -> void:
	var party := [_c({"id": "p1", "hp": 50, "frightened": true})]
	var enemies := [_e({"id": "e1", "hp": 50, "attack": 5, "damage": 1})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	assert_str(str(report["outcome"])).is_equal("retreat")


func test_resolve_multi_enemy_frightened_is_win() -> void:
	var party := [_c({"id": "p1", "hp": 50, "attack": 15, "damage": 5})]
	var enemies := [_e({"id": "e1", "hp": 50, "frightened": true})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	assert_str(str(report["outcome"])).is_equal("win")


func test_resolve_multi_deterministic() -> void:
	var party := [_c({"id": "p1", "hp": 50, "attack": 15, "damage": 5})]
	var enemies := [
		_e({"id": "e1", "hp": 30, "attack": 8, "damage": 4}),
		_e({"id": "e2", "hp": 25, "attack": 7, "damage": 3}),
	]
	var r1 := CampaignBattleScript.resolve_multi(party.duplicate(true), enemies.duplicate(true))
	var r2 := CampaignBattleScript.resolve_multi(party.duplicate(true), enemies.duplicate(true))
	assert_dict(r1).is_equal(r2)


## — 5.3: детерминизм авто-режима, 100 повторов → byte-identical —

func test_resolve_multi_100_repeats_byte_identical() -> void:
	var party := [_c({"id": "p1", "hp": 50, "attack": 15, "damage": 5})]
	var enemies := [
		_e({"id": "e1", "hp": 30, "attack": 8, "damage": 4}),
		_e({"id": "e2", "hp": 25, "attack": 7, "damage": 3}),
	]
	var first := CampaignBattleScript.resolve_multi(party.duplicate(true), enemies.duplicate(true))
	for i in range(100):
		var r := CampaignBattleScript.resolve_multi(party.duplicate(true), enemies.duplicate(true))
		assert_dict(r).is_equal(first)


## — 2.3: отчёт боя (REPORT) — один для обоих режимов; ничья без XP/Престижа —

func test_resolve_multi_report_structure() -> void:
	var party := [_c({"id": "p1", "hp": 100, "attack": 20, "damage": 15})]
	var enemies := [_e({"id": "e1", "hp": 10, "attack": 5, "damage": 1})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	assert_bool(report.has("outcome")).is_true()
	assert_bool(report.has("rounds")).is_true()
	assert_bool(report.has("trace")).is_true()
	assert_bool(report.has("losses")).is_true()
	assert_bool(bool(report["battle_over"])).is_true()


func test_resolve_multi_draw_20_rounds_no_xp_prestige() -> void:
	var party := [_c({"id": "p1", "hp": 100, "attack": 5, "damage": 0})]
	var enemies := [_e({"id": "e1", "hp": 100, "attack": 5, "damage": 0})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	assert_str(str(report["outcome"])).is_equal("draw")
	assert_int(int(report["rounds"])).is_equal(20)
	# Ничья: никто не пал → потери пустые; отчёт не несёт XP/Престиж.
	assert_int((report["losses"] as Array).size()).is_equal(0)
	assert_bool(not report.has("xp")).is_true()
	assert_bool(not report.has("prestige")).is_true()


## — dnd-battle-ladder 5.5 (K-M11): мораль аннулирована —

## Шкала морали (0–100) не существует: ни у комбатанта, ни в отчёте.
func test_no_morale_scale() -> void:
	var party := [_c({"id": "p1"})]
	var enemies := [_e({"id": "e1"})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	assert_bool(not report.has("morale")).is_true()
	assert_bool(not party[0].has("morale")).is_true()
	assert_bool(not enemies[0].has("morale")).is_true()


## Потеря → −2 ступени к спасам выживших той же стороны до конца боя.
## A (con −1) погибает в R1 (3 провала) → потеря; B (con 1) падает в R4:
## без штрафа стабилизировался бы (2 успеха 1 провал), с −2 — 3 провала →
## смерть. E (hp 12, урон 2/раунд от B) жив до конца (2 HP).
func test_loss_penalty_minus_two_saves() -> void:
	var a := _c({"id": "A", "hp": 1, "con": -1, "ac": 20, "attack": 10, "damage": 1})
	var b := _c({"id": "B", "hp": 25, "con": 1, "ac": 20, "attack": 10, "damage": 1})
	var e := _e({"id": "E", "hp": 12, "con": 1, "ac": 5, "attack": 20, "damage": 10})
	var report := CampaignBattleScript.resolve_multi([a, b], [e])
	assert_bool(bool(a.get("dead", false))) \
		.override_failure_message("A (con −1): 3 провала → смерть").is_true()
	assert_int(int(b.get("save_penalty", 0))) \
		.override_failure_message("потеря → −2 к спасам (K-M11)").is_equal(2)
	assert_bool(bool(b.get("dead", false))) \
		.override_failure_message("B: con 1 − 2 → 3 провала → смерть").is_true()
	assert_str(str(report["outcome"])).is_equal("lose")
	assert_int(int(e["hp"])).is_equal(2)  # E жив (A после R1 не атакует)


## Контроль: без потери штрафа нет. A (con 1) стабилизирован (2 успеха
## 1 провал) → принуд. отступление при 0 HD (не атакует с R2); B (con 1)
## падает без штрафа → стабилизирован → отступил, не потерян.
func test_no_loss_no_penalty_and_forced_retreat_at_0_hd() -> void:
	var a := _c({"id": "A", "hp": 1, "con": 1, "ac": 20, "attack": 10, "damage": 1})
	var b := _c({"id": "B", "hp": 25, "con": 1, "ac": 20, "attack": 10, "damage": 1})
	var e := _e({"id": "E", "hp": 12, "con": 1, "ac": 5, "attack": 20, "damage": 10})
	var report := CampaignBattleScript.resolve_multi([a, b], [e])
	assert_bool(not bool(a.get("dead", false))) \
		.override_failure_message("A (con 1): 2 успеха 1 провал → стабилизирован").is_true()
	assert_bool(bool(a.get("retreated", false))) \
		.override_failure_message("0 HD → принуд. отступление").is_true()
	assert_int(int(b.get("save_penalty", 0))).is_equal(0)
	assert_bool(bool(b.get("retreated", false))) \
		.override_failure_message("B стабилизирован → отступил (не потеря)").is_true()
	assert_bool(not bool(b.get("dead", false))).is_true()
	assert_int(int(e["hp"])).is_equal(2)  # A не атакует с R2 (отступил)
	assert_int((report["losses"] as Array).size()).is_equal(0)
