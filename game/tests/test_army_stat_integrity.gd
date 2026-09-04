extends "res://tests/gut_base.gd"
## Regression tests for РФ6-1: army stat integrity after battle.

const _ArmyCtrl = preload("res://scripts/entities/HeroArmyController.gd")
const _ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")

var _units: Node

func before_each() -> void:
	_units = ServiceLocator.resolve(null, &"units")

# РФ6-1: apply_battle_results rebuilds stacks from registry (clean stats)
func test_artifact_mods_do_not_compound() -> void:
	var ctrl = _ArmyCtrl.new()
	ctrl.setup(_units)
	# After setup army has 8 stacks. Grab first.
	var base_hp: int = ctrl.army[0].stats.hp
	var base_key: String = ctrl.army[0].get_key()

	# Simulate a battle: surviving army has modified stats (HP bumped)
	var dirty: Array[UnitStack] = []
	var dirty_stack = ctrl.army[0].duplicate_stack()
	dirty_stack.stats.hp = base_hp + 10  # "baked in" artifact bonus
	dirty_stack.count = 50
	dirty.append(dirty_stack)

	ctrl.apply_battle_results(dirty)

	# After apply: stats should be canonical (rebuilt from registry)
	assert_eq(ctrl.army[0].stats.hp, base_hp, "HP should be canonical after apply_battle_results")
	assert_eq(ctrl.army[0].count, 50, "Count should be preserved")
	ctrl.free()

# РФ6-1: Two consecutive battles don't compound
func test_two_battles_no_compound() -> void:
	var ctrl = _ArmyCtrl.new()
	ctrl.setup(_units)
	var base_hp: int = ctrl.army[0].stats.hp

	# First battle
	var dirty1: Array[UnitStack] = []
	var s1 = ctrl.army[0].duplicate_stack()
	s1.stats.hp = base_hp + 10
	s1.count = 80
	dirty1.append(s1)
	ctrl.apply_battle_results(dirty1)
	assert_eq(ctrl.army[0].stats.hp, base_hp, "HP canonical after battle 1")

	# Second battle
	var dirty2: Array[UnitStack] = []
	var s2 = ctrl.army[0].duplicate_stack()
	s2.stats.hp = base_hp + 10
	s2.count = 60
	dirty2.append(s2)
	ctrl.apply_battle_results(dirty2)
	assert_eq(ctrl.army[0].stats.hp, base_hp, "HP canonical after battle 2 (no compound)")
	assert_eq(ctrl.army[0].count, 60, "Count preserved after battle 2")
	ctrl.free()

func test_retreat_survivors_clean_stats() -> void:
	var ctrl = _ArmyCtrl.new()
	ctrl.setup(_units)
	var base_hp: int = ctrl.army[0].stats.hp

	# Simulate retreat survivors with modified stats
	var survivors: Array[UnitStack] = []
	var s = ctrl.army[0].duplicate_stack()
	s.stats.hp = base_hp + 5
	s.count = 10
	survivors.append(s)

	ctrl.apply_battle_results(survivors)
	assert_eq(ctrl.army[0].stats.hp, base_hp, "Retreat survivor HP is canonical")
	ctrl.free()
