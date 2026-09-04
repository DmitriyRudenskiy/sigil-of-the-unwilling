extends "res://tests/gut_base.gd"
## Regression tests for round 4 fixes (РФ4-1 through РФ4-4).

const _Input = preload("res://scripts/systems/BattleInput.gd")
const _ActionResolver = preload("res://scripts/systems/BattleActionResolver.gd")
const _Spellbook = preload("res://scripts/ui/BattleSpellbookPanel.gd")
const _SpellCaster = preload("res://scripts/systems/SpellCaster.gd")
const _Registry = preload("res://scripts/autoload/SpellRegistry.gd")

var _units: Node

## Минимальный мок BattleView: BattleInput вызывает set_highlights/clear_highlights,
## визуальная часть (TileMapLayer, overlay) в unit-тестах не нужна.
class _MockView extends BattleView:
	func set_highlights(_move_cells: Dictionary, _attack_cells: Dictionary) -> void:
		pass
	func clear_highlights() -> void:
		pass


func before_each() -> void:
	_units = ServiceLocator.resolve(null, &"units")

# РФ4-1: Бафф на союзника
func test_buff_targets_ally_side() -> void:
	var inp = _Input.new()
	inp.name = "TestInput"
	var bs = BattleState.new()
	var view = _MockView.new()
	inp.setup(view, bs, {})
	inp.start_spell_targeting(&"haste", BattleState.Side.ATTACKER)
	assert_eq(inp._pending_target_side, BattleState.Side.ATTACKER, "buff targets ATTACKER side")
	inp.free()
	view.free()

# РФ4-1: Урон на врага
func test_damage_targets_enemy_side() -> void:
	var inp = _Input.new()
	inp.name = "TestInput2"
	var bs = BattleState.new()
	var view = _MockView.new()
	inp.setup(view, bs, {})
	inp.start_spell_targeting(&"magic_arrow", BattleState.Side.DEFENDER)
	assert_eq(inp._pending_target_side, BattleState.Side.DEFENDER, "damage targets DEFENDER side")
	inp.free()
	view.free()

# РФ4-2: Мёртвый союзник подсвечен
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
	assert_false(dead_unit.is_alive(), "unit is dead")
	inp.start_spell_targeting(&"resurrection", BattleState.Side.ATTACKER, true)
	# Dead unit cell should be in highlights
	assert_true(inp.highlight_attack.has(dead_unit.cell), "dead ally highlighted")
	inp.free()
	view.free()

# РФ4-2: Воскрешение восстанавливает состояние
func test_resurrection_restores_state() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	# Два стака обороняющихся: убийство одного не должно завершать бой
	# (счётчик живых считает юниты/стаки, а не численность внутри стака).
	var def_stacks: Array[UnitStack] = [_units.make_fixed_stack("goblins", 5), _units.make_fixed_stack("goblins", 5)]
	bs.place_army([atk_stack], def_stacks)
	var dead_unit = bs.defender_units[0]
	var cell = dead_unit.cell
	bs.kill_unit(dead_unit)
	assert_false(dead_unit.is_alive(), "unit dead before resurrection")
	assert_null(bs.get_unit_at(cell, BattleState.Side.DEFENDER), "unit not in grid")
	var alive_before = bs._defender_alive_count
	var result = _ActionResolver.apply_spell(bs, &"resurrection", bs.attacker_units[0], dead_unit, {}, {}, RandomNumberGenerator.new())
	assert_true(result.get("revived", false), "resurrection succeeded")
	assert_true(dead_unit.is_alive(), "unit alive after resurrection")
	var found = bs.get_unit_at(cell, BattleState.Side.DEFENDER)
	assert_not_null(found, "unit restored in grid")
	assert_true(bs._defender_alive_count > alive_before, "alive counter incremented")
	assert_false(bs.battle_over, "battle not ended prematurely")

# РФ4-2: Воскрешение отклоняет живых
func test_resurrection_rejects_alive() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 5)
	bs.place_army([atk_stack], [def_stack])
	var result = _ActionResolver.apply_spell(bs, &"resurrection", bs.attacker_units[0], bs.defender_units[0], {}, {}, RandomNumberGenerator.new())
	assert_eq(result.get("result"), "invalid_target", "resurrection rejects alive target")

# РФ4-2: SpellCaster не мутирует состояние
func test_spellcaster_no_mutation() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 5)
	bs.place_army([atk_stack], [def_stack])
	var dead_unit = bs.defender_units[0]
	bs.kill_unit(dead_unit)
	var result = _SpellCaster.cast(&"resurrection", dead_unit, {"spell_power": 10}, {}, RandomNumberGenerator.new())
	assert_true(result.has("revive_count"), "result has revive_count")
	assert_false(dead_unit.alive, "SpellCaster did not mutate alive")
	assert_true(dead_unit.get_count() <= 0, "SpellCaster did not mutate count")

# РФ4-3: revive_unit восстанавливает счётчики
func test_revive_unit_restores_counters() -> void:
	var bs = BattleState.new()
	var atk_stack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack = _units.make_fixed_stack("goblins", 5)
	bs.place_army([atk_stack], [def_stack])
	var unit = bs.defender_units[0]
	var cell = unit.cell
	bs.kill_unit(unit)
	assert_eq(bs._defender_alive_count, 0, "counter is 0 after kill")
	bs.revive_unit(unit)
	assert_eq(bs._defender_alive_count, 1, "counter restored after revive")
	assert_not_null(bs.get_unit_at(cell, BattleState.Side.DEFENDER), "grid restored")

# РФ4-4: revive_unit null-safe
func test_revive_unit_null_safe() -> void:
	var bs = BattleState.new()
	bs.revive_unit(null)
	assert_true(true, "revive_unit(null) does not crash")
