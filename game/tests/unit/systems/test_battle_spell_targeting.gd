extends GdUnitTestSuite

const _Input = preload("res://scripts/systems/BattleInput.gd")
const _ActionResolver = preload("res://scripts/systems/BattleActionResolver.gd")
const _Spellbook = preload("res://scripts/ui/BattleSpellbookPanel.gd")
const _SpellCaster = preload("res://scripts/systems/SpellCaster.gd")
const _Registry = preload("res://scripts/autoload/SpellRegistry.gd")

var _units: Node

class _MockView extends BattleView:
	func set_highlights(_move_cells: Dictionary, _attack_cells: Dictionary) -> void:
		pass
	func clear_highlights() -> void:
		pass

func before_test() -> void:
	_units = Services.resolve(&"units")

func test_buff_targets_ally_side() -> void:
	var inp = _Input.new()
	inp.name = "TestInput"
	var bs = BattleState.new()
	var view = _MockView.new()
	inp.setup(view, bs, {})
	inp.start_spell_targeting(&"haste", BattleState.Side.ATTACKER)
	assert_that(inp._pending_target_side).is_equal(BattleState.Side.ATTACKER)
	inp.free()
	view.free()

func test_damage_targets_enemy_side() -> void:
	var inp = _Input.new()
	inp.name = "TestInput2"
	var bs = BattleState.new()
	var view = _MockView.new()
	inp.setup(view, bs, {})
	inp.start_spell_targeting(&"magic_arrow", BattleState.Side.DEFENDER)
	assert_that(inp._pending_target_side).is_equal(BattleState.Side.DEFENDER)
	inp.free()
	view.free()

func test_resurrection_targets_dead_ally() -> void:
	var inp = _Input.new()
	inp.name = "TestInput3"
	var bs = BattleState.new()
	var view = _MockView.new()
	inp.setup(view, bs, {})
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 20)
	bs.place_army([atk_stack], [def_stack])
	var dead_unit = bs.attacker_units[0]
	bs.kill_unit(dead_unit)
	assert_bool(dead_unit.is_alive()).is_false()
	inp.start_spell_targeting(&"resurrection", BattleState.Side.ATTACKER, true)
	assert_bool(inp.highlight_attack.has(dead_unit.cell)).is_true()
	inp.free()
	view.free()

func test_resurrection_restores_state() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stacks: Array[UnitStack] = [_units.make_fixed_stack("goblins", 5), _units.make_fixed_stack("goblins", 5)]
	bs.place_army([atk_stack], def_stacks)
	var dead_unit = bs.defender_units[0]
	var cell = dead_unit.cell
	bs.kill_unit(dead_unit)
	assert_bool(dead_unit.is_alive()).is_false()
	assert_that(bs.get_unit_at(cell, BattleState.Side.DEFENDER)).is_null()
	var alive_before = bs._defender_alive_count
	var result = _ActionResolver.apply_spell(bs, &"resurrection", bs.attacker_units[0], dead_unit, {}, {}, TestFactories.seeded(9464))
	assert_bool(result.get("revived", false)).is_true()
	assert_bool(dead_unit.is_alive()).is_true()
	var found = bs.get_unit_at(cell, BattleState.Side.DEFENDER)
	assert_that(found).is_not_null()
	assert_bool(bs._defender_alive_count > alive_before).is_true()
	assert_bool(bs.battle_over).is_false()

func test_resurrection_rejects_alive() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 5)
	bs.place_army([atk_stack], [def_stack])
	var result = _ActionResolver.apply_spell(bs, &"resurrection", bs.attacker_units[0], bs.defender_units[0], {}, {}, TestFactories.seeded(9464))
	assert_that(result.get("result")).is_equal("invalid_target")

func test_spellcaster_no_mutation() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 5)
	bs.place_army([atk_stack], [def_stack])
	var dead_unit = bs.defender_units[0]
	bs.kill_unit(dead_unit)
	var result = _SpellCaster.cast(&"resurrection", dead_unit, {"spell_power": 10}, {}, TestFactories.seeded(9464))
	assert_bool(result.has("revive_count")).is_true()
	assert_bool(dead_unit.alive).is_false()
	assert_bool(dead_unit.get_count() <= 0).is_true()

func test_revive_unit_restores_counters() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 5)
	bs.place_army([atk_stack], [def_stack])
	var unit = bs.defender_units[0]
	var cell = unit.cell
	bs.kill_unit(unit)
	assert_that(bs._defender_alive_count).is_equal(0)
	bs.revive_unit(unit)
	assert_that(bs._defender_alive_count).is_equal(1)
	assert_that(bs.get_unit_at(cell, BattleState.Side.DEFENDER)).is_not_null()

func test_revive_unit_null_safe() -> void:
	var bs = BattleState.new()
	bs.revive_unit(null)
	assert_bool(true).is_true()
