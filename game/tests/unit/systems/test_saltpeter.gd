extends GdUnitTestSuite

const _BattleState = preload("res://scripts/systems/BattleState.gd")
const _BattleRules = preload("res://scripts/core/BattleRules.gd")
const _UnitStack = preload("res://scripts/entities/UnitStack.gd")
const _UnitStats = preload("res://scripts/entities/UnitStats.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")
var state: BattleState
var rng: RandomNumberGenerator

func before_test() -> void:
	state = BattleState.new()
	rng = TestFactories.seeded(4328)
	rng.seed = 42

func test_saltpeter_tag_exists() -> void:
	var def := Resources.get_resource(&"saltpeter")
	assert_that(def).is_not_null()

func test_saltpeter_explosion_dmg_mult() -> void:
	assert_that(GameNumbers.SALTPETER_EXPLOSION_MULT).is_equal(2.0)

func test_saltpeter_adjacent_kills() -> void:
	var atk_stats := UnitStats.new("saltpeter_unit", "Saltpeter", 5, 5, 10, 3, 2, ["melee", "saltpeter"])
	var atk_stack := UnitStack.new(atk_stats, 5)
	atk_stack.count = 5

	var def_stats := UnitStats.new("goblin", "Goblin", 2, 2, 8, 4, 1, ["melee"])
	var def_stack := UnitStack.new(def_stats, 5)
	def_stack.count = 5

	var adj_stats := UnitStats.new("wolf", "Wolf", 2, 4, 10, 6, 1, ["melee"])
	var adj_stack := UnitStack.new(adj_stats, 5)
	adj_stack.count = 5

	state.place_army([atk_stack], [def_stack, adj_stack])

	var atk_unit := state.attacker_units[0]
	var def_unit := state.defender_units[0]
	var adj_unit := state.defender_units[1]

	state.do_move(adj_unit, HexUtils.get_neighbor(def_unit.cell, 0))

	var result := state.apply_attack(atk_unit, def_unit, true, rng)
	assert_bool(result.has("saltpeter_kills")).is_true()
	assert_bool(int(result.get("saltpeter_kills", 0)) > 0).is_true()

func test_saltpeter_no_adjacent() -> void:
	var atk_stats := UnitStats.new("saltpeter_unit", "Saltpeter", 5, 5, 10, 3, 2, ["melee", "saltpeter"])
	var atk_stack := UnitStack.new(atk_stats, 3)

	var def_stats := UnitStats.new("goblin", "Goblin", 2, 2, 8, 4, 1, ["melee"])
	var def_stack := UnitStack.new(def_stats, 3)

	state.place_army([atk_stack], [def_stack])

	var atk_unit := state.attacker_units[0]
	var def_unit := state.defender_units[0]

	var result := state.apply_attack(atk_unit, def_unit, true, rng)
	assert_bool(result.has("saltpeter_kills")).is_true()
	assert_that(result["saltpeter_kills"]).is_equal(0)
