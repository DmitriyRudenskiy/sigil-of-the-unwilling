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
