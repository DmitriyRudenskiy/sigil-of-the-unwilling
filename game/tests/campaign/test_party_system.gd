extends BaseTest
## T-060 (R1/R4, K-M13, K3, K-M11): чистые функции PartySystem.
## Канон: 02-mechanics §3.2, 07-balance §3, DECISIONS K-M13/K-M11/K3.


func _member(xp: int = 0, extra: Dictionary = {}) -> Dictionary:
	var m := {
		"id": "m1", "class": "fighter", "race": "humans", "level": 1,
		"xp": xp, "luck": 0,
		"stats": {"str": 14, "dex": 10, "con": 12, "int": 10, "wis": 10, "cha": 10},
	}
	for k in extra:
		m[k] = extra[k]
	return m


func test_config_wiring_xp_json() -> void:
	# Канон-значения — из data/config/balance/xp.json (07-balance §3), не хардкод.
	var t: Array = PartySystem.thresholds()
	assert_bool(t == [0, 2700, 6500, 15000, 38000]).override_failure_message("level_thresholds (SRD, K-M13)").is_true()
	assert_bool(PartySystem.max_level() == 5).is_true()
	assert_bool(PartySystem.raid_survived_xp() == 300).is_true()
	assert_bool(PartySystem.node_xp_range() == [200, 800]).is_true()


func test_level_thresholds_srd_canon() -> void:
	# K-M13: пороги SRD — канон (уровни 2–5), правятся источники, не пороги.
	assert_bool(PartySystem.level_for_xp(0) == 1).is_true()
	assert_bool(PartySystem.level_for_xp(2699) == 1).is_true()
	assert_bool(PartySystem.level_for_xp(2700) == 2).is_true()
	assert_bool(PartySystem.level_for_xp(6500) == 3).is_true()
	assert_bool(PartySystem.level_for_xp(15000) == 4).is_true()
	assert_bool(PartySystem.level_for_xp(38000) == 5).is_true()
	assert_bool(PartySystem.level_for_xp(999999) == 5).override_failure_message("кап 5 (K-M13)").is_true()


func test_grant_xp_level_up() -> void:
	var m := _member(2600)
	var r: Dictionary = PartySystem.grant_xp(m, 100)
	assert_bool(bool(r.ok)).is_true()
	assert_bool(int(m.xp) == 2700).is_true()
	assert_bool(int(m.level) == 2).is_true()
	assert_bool(int(r.level_ups) == 1).is_true()
	assert_bool(int(r.from_level) == 1 and int(r.to_level) == 2).is_true()


func test_grant_xp_multi_level_and_cap() -> void:
	var m := _member(0)
	var r: Dictionary = PartySystem.grant_xp(m, 38000)
	assert_bool(int(m.level) == 5).is_true()
	assert_bool(int(r.level_ups) == 4).is_true()
	# Кап 5: XP копится, уровень не растёт (K-M13).
	var r2: Dictionary = PartySystem.grant_xp(m, 10000)
	assert_bool(int(m.level) == 5).is_true()
	assert_bool(int(r2.level_ups) == 0).is_true()


func test_grant_xp_negative_rejected() -> void:
	var m := _member(100)
	var r: Dictionary = PartySystem.grant_xp(m, -5)
	assert_bool(bool(not r.ok)).is_true()
	assert_bool(int(m.xp) == 100).is_true()


func test_xp_from_battle_formula() -> void:
	# 07-balance §3: 100 × CR × (1+0.1n).
	assert_bool(PartySystem.xp_from_battle(1.0, 1) == 110).is_true()
	assert_bool(PartySystem.xp_from_battle(2.0, 3) == 260).is_true()
	assert_bool(PartySystem.xp_from_battle(7.0, 1) == 770).is_true()
	assert_bool(PartySystem.xp_from_battle(0.0, 1) == 0).is_true()
	assert_bool(PartySystem.xp_from_battle(1.0, 0) == 0).is_true()


func test_xp_from_node_clamped() -> void:
	# 07-balance §3: узел (one-time) 200–800.
	assert_bool(PartySystem.xp_from_node(100) == 200).is_true()
	assert_bool(PartySystem.xp_from_node(500) == 500).is_true()
	assert_bool(PartySystem.xp_from_node(900) == 800).is_true()


func test_asi_apply_and_cap() -> void:
	# K3: +2 к одной или +1 к двум; практический потолок 16.
	var m := _member()
	assert_bool(bool(PartySystem.apply_asi(m, "str", 2))).is_true()
	assert_bool(int(m.stats.str) == 16).is_true()
	assert_bool(bool(PartySystem.apply_asi(m, "str", 2))).is_true()
	assert_bool(int(m.stats.str) == 16).override_failure_message("потолок 16 (K3)").is_true()
	var m2 := _member()
	assert_bool(bool(PartySystem.apply_asi(m2, "DEX", 1))).is_true()  # регистр не важен
	assert_bool(int(m2.stats.dex) == 11).is_true()


func test_asi_rejects_invalid() -> void:
	var m := _member()
	assert_bool(bool(not PartySystem.apply_asi(m, "luck", 2))).override_failure_message("Удача — не объект ASI (7-я хар-ка, раса)").is_true()
	assert_bool(bool(not PartySystem.apply_asi(m, "str", 3))).is_true()
	assert_bool(bool(not PartySystem.apply_asi(m, "str", 0))).is_true()
	assert_bool(bool(not PartySystem.apply_asi({"id": "x"}, "str", 2))).override_failure_message("нет stats").is_true()


func test_apply_losses_by_uid_and_id() -> void:
	var a := _member(0, {"uid": 7})
	var b := _member(0, {"id": "comp_1"})
	var c := _member(0, {"uid": 9})
	var party: Array = [a, b, c]
	var dead := PartySystem.apply_losses(party, [7, "comp_1"])
	assert_bool(dead == 2).is_true()
	# "state" — входная величина: у живых по умолчанию READY (key может отсутствовать).
	assert_bool(str(a.get("state", PartySystem.STATE_READY)) == PartySystem.STATE_DEAD).is_true()
	assert_bool(str(b.get("state", PartySystem.STATE_READY)) == PartySystem.STATE_DEAD).is_true()
	assert_bool(str(c.get("state", PartySystem.STATE_READY)) == PartySystem.STATE_READY).is_true()


func test_apply_losses_idempotent_for_dead() -> void:
	var a := _member(0, {"uid": 7})
	var party: Array = [a]
	PartySystem.apply_losses(party, [7])
	var dead := PartySystem.apply_losses(party, [7])
	assert_bool(dead == 0).override_failure_message("мёртвый не списывается повторно").is_true()


func test_is_wiped() -> void:
	assert_bool(not PartySystem.is_wiped([])).override_failure_message("пустая партия — не wipe (R1: wipe = вся партия пала)").is_true()
	var a := _member(0, {"uid": 1})
	var b := _member(0, {"uid": 2})
	var party: Array = [a, b]
	assert_bool(not PartySystem.is_wiped(party)).is_true()
	PartySystem.apply_losses(party, [1])
	assert_bool(not PartySystem.is_wiped(party)).is_true()
	PartySystem.apply_losses(party, [2])
	assert_bool(PartySystem.is_wiped(party)).is_true()


func test_loss_stage_k_m11() -> void:
	# K-M11: «утрата» = ступень (модификатор −2 к спасам), не шкала.
	assert_bool(PartySystem.loss_stage(true) == 0).is_true()
	assert_bool(PartySystem.loss_stage(false) == 1).is_true()


func test_alive_members() -> void:
	var a := _member(0, {"uid": 1})
	var b := _member(0, {"uid": 2, "state": PartySystem.STATE_DEAD})
	var alive := PartySystem.alive_members([a, b])
	assert_bool(alive.size() == 1 and int(alive[0].uid) == 1).is_true()
