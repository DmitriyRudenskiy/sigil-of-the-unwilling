extends BaseTest

## dnd-battle-ladder 3.4 (02b A.4): бином «Фланг» — fighter + ranger,
## единственный бином MVP. После успешной атаки одного — следующая атака
## другого по той же цели в этом раунде +2 к Итогу (K-M6). 1/раунд на пару;
## BROKEN_DEAD — один умер → добивка не применяется; авто-политика —
## приоритет цели, по которой уже били в раунде. +2 живёт до конца раунда
## или до первой атаки второго (что раньше).

const CampaignBattleScript := preload("res://scripts/campaign/campaign_battle.gd")


func _p(id: String, cls: String, spec: Dictionary) -> Dictionary:
	var base := {
		"id": id, "character_uid": 0, "hp": 30, "ac": 15, "attack": 12,
		"damage": 5, "luck": 0, "dex": 12, "con": 2, "proficiency": 2,
		"class": cls,
	}
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


func _e(id: String, spec: Dictionary) -> Dictionary:
	var base := {
		"id": id, "character_uid": -1, "hp": 100, "ac": 11, "attack": 0,
		"damage": 0, "luck": 0, "dex": 12, "con": 1, "proficiency": 1,
	}
	base.merge(spec, true)
	return CampaignBattleScript.make_combatant(base)


## Удары комбатанта из trace (по порядку).
func _strikes(report: Dictionary, actor: String) -> Array:
	var out: Array = []
	for t in report["trace"]:
		var e: Dictionary = t
		if str(e.get("actor", "")) == actor and e.has("target"):
			out.append(e)
	return out


## Основной сценарий: F бьёт (margin 1, success, 5), R — по той же цели
## +2 (margin 3, success, 5, flank). 1/раунд на пару.
func test_flank_bonus_second_attack_same_target() -> void:
	var party := [_p("F", "fighter", {}), _p("R", "ranger", {})]
	var enemies := [_e("E", {})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	var f1: Dictionary = _strikes(report, "F")[0]
	var r1: Dictionary = _strikes(report, "R")[0]
	assert_int(int(f1["margin"])).override_failure_message("12 − 11 = 1").is_equal(1)
	assert_bool(bool(f1["flank"])).is_false()
	assert_int(int(r1["margin"])).override_failure_message("12 − 11 + 2 = 3").is_equal(3)
	assert_bool(bool(r1["flank"])).override_failure_message("Фланг сработал").is_true()
	assert_str(str(r1["target"])).is_equal("E")
	# 1/раунд на пару: ровно один flank-удар в каждом раунде.
	var rounds: Dictionary = {}
	for t in report["trace"]:
		var e: Dictionary = t
		if bool(e.get("flank", false)):
			rounds[int(e["round"])] = int(rounds.get(int(e["round"]), 0)) + 1
	for r in rounds:
		assert_int(int(rounds[r])).override_failure_message("раунд %d: 1/раунд" % r).is_equal(1)
	assert_str(str(report["outcome"])).is_equal("win")


## BROKEN_DEAD: fighter умер → добивка ranger не применяется (даже если
## атака первого была в раунде).
func test_flank_broken_dead() -> void:
	var party := [_p("F", "fighter", {"con": -1}), _p("R", "ranger", {"damage": 6})]
	var enemies := [
		_e("E1", {"hp": 5, "attack": 20, "damage": 40}),
		_e("E2", {}),
	]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	for t in report["trace"]:
		var e: Dictionary = t
		assert_bool(bool(e.get("flank", false))) \
			.override_failure_message("BROKEN_DEAD: добивки нет").is_false()
	assert_str(str(report["outcome"])).is_equal("win")


## Pending-цель умерла от первого удара: бонуса нет, второй бьёт min HP.
func test_flank_pending_target_died() -> void:
	var party := [_p("F", "fighter", {"damage": 10}), _p("R", "ranger", {})]
	var enemies := [
		_e("E1", {"hp": 5, "con": -3}),  # умирает от 10 урона (3 провала спасов)
		_e("E2", {}),
	]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	var r1: Dictionary = _strikes(report, "R")[0]
	assert_str(str(r1["target"])).override_failure_message("min HP: E2").is_equal("E2")
	assert_bool(bool(r1["flank"])).is_false()
	assert_int(int(r1["margin"])).is_equal(1)
	# Во 2-м раунде пара цела — Фланг работает снова (по E2).
	var r2: Dictionary = _strikes(report, "R")[1]
	assert_bool(bool(r2["flank"])).override_failure_message("R2: Фланг снова").is_true()


## Без пары (fighter + fighter) бинама нет.
func test_flank_requires_fighter_and_ranger() -> void:
	var party := [_p("F1", "fighter", {}), _p("F2", "fighter", {})]
	var enemies := [_e("E", {})]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	for t in report["trace"]:
		var e: Dictionary = t
		assert_bool(bool(e.get("flank", false))).is_false()


## Бином — механика партии: у вражеских fighter/ranger бонуса нет.
func test_flank_party_only() -> void:
	var party := [_p("P", "cleric", {"hp": 200})]
	var enemies := [
		_e("E1", {"class": "fighter", "attack": 12, "damage": 5, "con": 2}),
		_e("E2", {"class": "ranger", "attack": 12, "damage": 5, "con": 2}),
	]
	var report := CampaignBattleScript.resolve_multi(party, enemies)
	for t in report["trace"]:
		var e: Dictionary = t
		assert_bool(bool(e.get("flank", false))).is_false()
