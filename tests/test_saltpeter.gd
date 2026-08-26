extends "res://tests/test_base.gd"
## Saltpeter explosion tests: double damage to adjacent units.

const _BattleState = preload("res://scripts/BattleState.gd")
const _BattleRules = preload("res://scripts/util/BattleRules.gd")
const _UnitRegistry = preload("res://scripts/UnitRegistry.gd")
const _UnitStack = preload("res://scripts/unit_stack.gd")
const _UnitStats = preload("res://scripts/unit_stats.gd")
const _HexUtils = preload("res://scripts/HexUtils.gd")
const _ResourceRegistry = preload("res://scripts/data/ResourceRegistry.gd")

var state: BattleState
var rng: RandomNumberGenerator


func before_each() -> void:
	state = BattleState.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 42


func test_saltpeter_tag_exists() -> void:
	var def := _ResourceRegistry.get(&"saltpeter")
	assert_not_null(def, "saltpeter exists")


func test_saltpeter_explosion_dmg_mult() -> void:
	assert_eq(GameSettings.SALTPETER_EXPLOSION_DMG_MULT, 2.0, "double damage")


func test_saltpeter_adjacent_kills() -> void:
	# Create attacker with saltpeter tag
	var atk_stats := UnitStats.new(&"saltpeter_unit", "Saltpeter", 5, 5, 10, 3, 2)
	atk_stats._tags = ["melee", "saltpeter"]
	var atk_stack := UnitStack.new(atk_stats, 5)
	atk_stack.count = 5

	# Create defender
	var def_stats := UnitStats.new(&"goblin", "Goblin", 2, 2, 8, 4, 1)
	def_stats._tags = ["melee"]
	var def_stack := UnitStack.new(def_stats, 5)
	def_stack.count = 5

	# Create adjacent defender (should take explosion damage)
	var adj_stats := UnitStats.new(&"wolf", "Wolf", 2, 4, 10, 6, 1)
	adj_stats._tags = ["melee"]
	var adj_stack := UnitStack.new(adj_stats, 5)
	adj_stack.count = 5

	state.place_army([atk_stack], [def_stack, adj_stack])

	var atk_unit := state.attacker_units[0]
	var def_unit := state.defender_units[0]
	var adj_unit := state.defender_units[1]

	# Place adjacent unit next to defender
	adj_unit.cell = Vector2i(def_unit.cell.x + 1, def_unit.cell.y)

	var result := state.apply_attack(atk_unit, def_unit, true, rng)
	assert_true(result.has("saltpeter_kills"), "saltpeter triggered")


func test_saltpeter_no_adjacent() -> void:
	var atk_stats := UnitStats.new(&"saltpeter_unit", "Saltpeter", 5, 5, 10, 3, 2)
	atk_stats._tags = ["melee", "saltpeter"]
	var atk_stack := UnitStack.new(atk_stats, 3)

	var def_stats := UnitStats.new(&"goblin", "Goblin", 2, 2, 8, 4, 1)
	def_stats._tags = ["melee"]
	var def_stack := UnitStack.new(def_stats, 3)

	state.place_army([atk_stack], [def_stack])

	var atk_unit := state.attacker_units[0]
	var def_unit := state.defender_units[0]

	var result := state.apply_attack(atk_unit, def_unit, true, rng)
	assert_true(result.has("saltpeter_kills"), "saltpeter triggered")
	assert_eq(result["saltpeter_kills"], 0, "no adjacent victims")
