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
