extends GdUnitTestSuite

const _ArmyCtrl = preload("res://scripts/entities/HeroArmyController.gd")

var _units: Node

func before_test() -> void:
	_units = Services.resolve(&"units")

func test_artifact_mods_do_not_compound() -> void:
	var ctrl = _ArmyCtrl.new()
	ctrl.setup(_units)
	var base_hp: int = ctrl.army[0].stats.hp
	var base_key: String = ctrl.army[0].get_key()

	var dirty: Array[UnitStack] = []
	var dirty_stack = ctrl.army[0].duplicate_stack()
	dirty_stack.stats.hp = base_hp + 10
	dirty_stack.count = 50
	dirty.append(dirty_stack)

	ctrl.apply_battle_results(dirty)

	assert_that(ctrl.army[0].stats.hp).is_equal(base_hp)
	assert_that(ctrl.army[0].count).is_equal(50)
	ctrl.free()

func test_two_battles_no_compound() -> void:
	var ctrl = _ArmyCtrl.new()
	ctrl.setup(_units)
	var base_hp: int = ctrl.army[0].stats.hp

	var dirty1: Array[UnitStack] = []
	var s1 = ctrl.army[0].duplicate_stack()
	s1.stats.hp = base_hp + 10
	s1.count = 80
	dirty1.append(s1)
	ctrl.apply_battle_results(dirty1)
	assert_that(ctrl.army[0].stats.hp).is_equal(base_hp)

	var dirty2: Array[UnitStack] = []
	var s2 = ctrl.army[0].duplicate_stack()
	s2.stats.hp = base_hp + 10
	s2.count = 60
	dirty2.append(s2)
	ctrl.apply_battle_results(dirty2)
	assert_that(ctrl.army[0].stats.hp).is_equal(base_hp)
	assert_that(ctrl.army[0].count).is_equal(60)
	ctrl.free()

func test_retreat_survivors_clean_stats() -> void:
	var ctrl = _ArmyCtrl.new()
	ctrl.setup(_units)
	var base_hp: int = ctrl.army[0].stats.hp

	var survivors: Array[UnitStack] = []
	var s = ctrl.army[0].duplicate_stack()
	s.stats.hp = base_hp + 5
	s.count = 10
	survivors.append(s)

	ctrl.apply_battle_results(survivors)
	assert_that(ctrl.army[0].stats.hp).is_equal(base_hp)
	ctrl.free()
