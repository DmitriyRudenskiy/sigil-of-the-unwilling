extends "res://tests/gut_base.gd"
## Tests for BattleEmulator (extracted from SocketController in the world-
## controller-decoupling refactor): pure helpers + auto-battle emulation.
## emulate_battle builds armies and runs the auto-battle loop; it does not
## depend on the spell registry autoload, so no ServiceLocator setup needed.

const _Emulator = preload("res://scripts/autoload/BattleEmulator.gd")

# Army spec builders — mirror BattleEmulator.army_stack field names.
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
	var em = _Emulator.new()
	var specs := [
		{"id": "a", "count": 5},
		{"id": "b", "count": 7},
		{"id": "c", "count": 0},
	]
	assert_eq(em.total_count(specs), 12, "total_count should sum counts")
	assert_eq(em.total_count([]), 0, "empty specs → 0")
	assert_eq(em.total_count([{"id": "x"}]), 0, "missing count → 0")

func test_total_count_ignores_non_dicts() -> void:
	var em = _Emulator.new()
	assert_eq(em.total_count([{"id": "a", "count": 3}, "junk", 42]), 3, "non-dicts ignored")

func test_side_name_attacker_and_defender() -> void:
	var em = _Emulator.new()
	assert_eq(em.side_name(BattleState.Side.ATTACKER), "attacker", "attacker side name")
	assert_eq(em.side_name(BattleState.Side.DEFENDER), "defender", "defender side name")

func test_emulate_battle_requires_both_armies() -> void:
	var em = _Emulator.new()
	var r1 = em.emulate_battle({"attacker_army": [stronger()], "defender_army": []})
	assert_true(r1.has("error"), "empty defender army should error")
	var r2 = em.emulate_battle({"attacker_army": [], "defender_army": [weaker()]})
	assert_true(r2.has("error"), "empty attacker army should error")

func test_emulate_battle_report_structure() -> void:
	var em = _Emulator.new()
	var r = em.emulate_battle({"attacker_army": [stronger()], "defender_army": [weaker()]})
	assert_false(r.has("error"), "battle should run: %s" % str(r.get("error")))
	assert_true(r.get("battle_over", false), "battle should reach battle_over")
	assert_true(r.get("winner") in ["attacker", "defender"], "winner must be a side name")
	assert_true(r.get("turns", 0) > 0, "at least one turn played")
	assert_true(r.has("atk_survivors"), "atk_survivors present")
	assert_true(r.has("def_survivors"), "def_survivors present")
	assert_true(r.get("atk_loss", -1) >= 0, "atk_loss non-negative")
	assert_true(r.get("def_loss", -1) >= 0, "def_loss non-negative")

func test_emulate_battle_loss_accounting_is_sane() -> void:
	var em = _Emulator.new()
	var r = em.emulate_battle({"attacker_army": [stronger()], "defender_army": [weaker()]})
	# Losses are bounded by each army's initial count (probabilistic sim, so we
	# assert the accounting is valid rather than a strict ordering).
	var atk_loss: int = r.get("atk_loss", -1)
	var def_loss: int = r.get("def_loss", -1)
	assert_true(0 <= atk_loss and atk_loss <= 20, "atk_loss in [0,20]: %d" % atk_loss)
	assert_true(0 <= def_loss and def_loss <= 10, "def_loss in [0,10]: %d" % def_loss)

func test_emulate_battle_invalid_army_type() -> void:
	var em = _Emulator.new()
	var r = em.emulate_battle({"attacker_army": "nope", "defender_army": [weaker()]})
	assert_true(r.has("error"), "non-array army should error")


# ==================== SEQUENCE_BATTLE (ротация heal) ====================

## sequence_battle последовательно прогоняет шаги: cast (heal) → enemy →
## attack; каждый шаг попадает в steps с правильной командой.
func test_sequence_battle_rotates_heal_and_actions() -> void:
	var em = _Emulator.new()
	var r = em.sequence_battle({
		"sequence": [
			{"cmd": "cast", "spell": "cure", "self": true},
			{"cmd": "enemy"},
			{"cmd": "attack"},
		],
	})
	assert_false(r.has("error"), "sequence should run: %s" % str(r.get("error")))
	var steps: Array = r.get("steps", [])
	assert_eq(steps.size(), 3, "all three steps processed (rotation)")
	assert_eq(steps[0]["cmd"], "cast", "step 0: cast (heal)")
	assert_eq(steps[0]["spell"], "cure", "step 0 casts cure")
	assert_eq(steps[1]["cmd"], "enemy", "step 1: enemy")
	assert_eq(steps[2]["cmd"], "attack", "step 2: attack")
	assert_true(steps[0].has("result"), "cast step returns a spell result")

## sequence_battle на пустой последовательности: steps пуст, без ошибок.
func test_sequence_battle_empty_sequence() -> void:
	var em = _Emulator.new()
	var r = em.sequence_battle({"sequence": []})
	assert_false(r.has("error"), "empty sequence should not error")
	var steps: Array = r.get("steps", [])
	assert_eq(steps.size(), 0, "empty sequence → no steps")


# ==================== CAST (воскрешение мёртвой цели) ====================

## cast_in_battle: воскрешение мёртвой цели (target_count = 0). resurrect
## устанавливает цель мёртвой, затем revive_count > 0 возрождает её.
func test_cast_in_battle_resurrects_dead_target() -> void:
	var em = _Emulator.new()
	var r = em.cast_in_battle({
		"spell_id": "resurrection",
		"caster_hp": 60,
		"caster_count": 10,
		"target_hp": 100,
		"target_count": 0,  # мёртвый
	})
	assert_false(r.has("error"), "cast should run: %s" % str(r.get("error")))
	assert_eq(r.get("result"), "success", "resurrection applied: %s" % str(r))
	assert_true(r.get("revived", false) == true, "target revived: %s" % str(r))
	assert_true(int(r.get("revive_count", 0)) >= 1, "revived stack has units: %s" % str(r))
