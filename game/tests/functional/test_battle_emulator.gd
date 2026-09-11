extends BaseTest


func weaker() -> Dictionary:
	return {
		"id": "goblins", "name": "Goblins",
		"attack": 3, "base_damage": 3, "hp": 40, "speed": 5, "defense": 2, "count": 10,
	}

func stronger() -> Dictionary:
	return {
		"id": "swordsmen", "name": "Swordsmen",
		"attack": 6, "base_damage": 5, "hp": 60, "speed": 5, "defense": 4, "count": 20,
	}

func test_total_count_sums_specs() -> void:
	var em = BattleEmulator.new()
	var specs := [
		{"id": "a", "count": 5},
		{"id": "b", "count": 7},
		{"id": "c", "count": 0},
	]
	assert_that(em.total_count(specs)).is_equal(12)
	assert_that(em.total_count([])).is_equal(0)
	assert_that(em.total_count([{"id": "x"}])).is_equal(0)

func test_total_count_ignores_non_dicts() -> void:
	var em = BattleEmulator.new()
	assert_that(em.total_count([{"id": "a", "count": 3}, "junk", 42])).is_equal(3)

func test_side_name_attacker_and_defender() -> void:
	var em = BattleEmulator.new()
	assert_that(em.side_name(BattleState.Side.ATTACKER)).is_equal("attacker")
	assert_that(em.side_name(BattleState.Side.DEFENDER)).is_equal("defender")

func test_emulate_battle_requires_both_armies() -> void:
	var em = BattleEmulator.new()
	var r1 = em.emulate_battle({"attacker_army": [stronger()], "defender_army": []})
	assert_bool(r1.has("error")).is_true()
	var r2 = em.emulate_battle({"attacker_army": [], "defender_army": [weaker()]})
	assert_bool(r2.has("error")).is_true()

func test_emulate_battle_report_structure() -> void:
	var em = BattleEmulator.new()
	var r = em.emulate_battle({"attacker_army": [stronger()], "defender_army": [weaker()]})
	assert_bool(r.has("error")).is_false()
	assert_bool(r.get("battle_over", false)).is_true()
	assert_bool(r.get("winner") in ["attacker", "defender"]).is_true()
	assert_bool(r.get("turns", 0) > 0).is_true()
	assert_bool(r.has("atk_survivors")).is_true()
	assert_bool(r.has("def_survivors")).is_true()
	assert_bool(r.get("atk_loss", -1) >= 0).is_true()
	assert_bool(r.get("def_loss", -1) >= 0).is_true()

func test_emulate_battle_loss_accounting_is_sane() -> void:
	var em = BattleEmulator.new()
	var r = em.emulate_battle({"attacker_army": [stronger()], "defender_army": [weaker()]})
	var atk_loss: int = r.get("atk_loss", -1)
	var def_loss: int = r.get("def_loss", -1)
	assert_bool(0 <= atk_loss and atk_loss <= 20).is_true()
	assert_bool(0 <= def_loss and def_loss <= 10).is_true()

func test_emulate_battle_invalid_army_type() -> void:
	var em = BattleEmulator.new()
	var r = em.emulate_battle({"attacker_army": "nope", "defender_army": [weaker()]})
	assert_bool(r.has("error")).is_true()

func test_sequence_battle_rotates_heal_and_actions() -> void:
	var em = BattleEmulator.new()
	var r = em.sequence_battle({
		"sequence": [
			{"cmd": "cast", "spell": "cure", "self": true},
			{"cmd": "enemy"},
			{"cmd": "attack"},
		],
	})
	assert_bool(r.has("error")).is_false()
	var steps: Array = r.get("steps", [])
	assert_that(steps.size()).is_equal(3)
	assert_that(steps[0]["cmd"]).is_equal("cast")
	assert_that(steps[0]["spell"]).is_equal("cure")
	assert_that(steps[1]["cmd"]).is_equal("enemy")
	assert_that(steps[2]["cmd"]).is_equal("attack")
	assert_bool(steps[0].has("result")).is_true()

func test_sequence_battle_empty_sequence() -> void:
	var em = BattleEmulator.new()
	var r = em.sequence_battle({"sequence": []})
	assert_bool(r.has("error")).is_false()
	var steps: Array = r.get("steps", [])
	assert_that(steps.size()).is_equal(0)

func test_cast_in_battle_resurrects_dead_target() -> void:
	var em = BattleEmulator.new()
	var r = em.cast_in_battle({
		"spell_id": "resurrection",
		"caster_hp": 60,
		"caster_count": 10,
		"target_hp": 100,
		"target_count": 0,
	})
	assert_bool(r.has("error")).is_false()
	assert_that(r.get("result")).is_equal("success")
	assert_bool(r.get("revived", false) == true).is_true()
	assert_bool(int(r.get("revive_count", 0)) >= 1).is_true()
