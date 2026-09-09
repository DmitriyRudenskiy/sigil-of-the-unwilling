extends GdUnitTestSuite

const _STACK_PATH := "res://scripts/entities/UnitStack.gd"

func _reg():
	return Units

func _stack():
	return load(_STACK_PATH)


func test_make_stack_swordsmen() -> void:
	var rng := TestFactories.seeded(7915)
	rng.seed = 123
	var stack = _reg().make_stack("swordsmen", rng)
	assert_that(stack).is_not_null()
	assert_bool(stack.is_alive()).is_true()
	assert_that(stack.stats.base_damage).is_equal(4)
	assert_that(stack.stats.hp).is_equal(10)


func test_make_stack_invalid_key() -> void:
	var rng := TestFactories.seeded(7915)
	assert_that(_reg().make_stack("nonexistent_unit", rng)).is_null()


func test_make_fixed_stack() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	assert_that(fixed).is_not_null()
	assert_that(fixed.count).is_equal(36)


func test_stack_to_dict() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	var d = fixed.to_dict() if fixed else {}
	assert_that(d.get("key")).is_equal("archers")
	assert_that(d.get("count")).is_equal(36)


func test_stack_from_dict() -> void:
	var def_cav = _reg().get_definition("cavalry")
	var restored = _stack().from_dict({"key": "cavalry", "count": 50}, def_cav)
	assert_that(restored).is_not_null()
	assert_that(restored.count).is_equal(50)
	assert_that(restored.stats.base_damage).is_equal(5)


func test_duplicate_stack() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	var dup = fixed.duplicate_stack() if fixed else null
	assert_that(dup).is_not_null()
	assert_that(dup.count).is_equal(fixed.count)


func test_is_alive() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	assert_bool(fixed.is_alive()).is_true()
	var dead = _reg().make_fixed_stack("mages", 0)
	assert_bool(dead == null or not dead.is_alive()).is_true()


func test_get_display_name() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	assert_that(fixed.get_display_name()).is_equal("Archer")


func test_get_definition() -> void:
	var def_s = _reg().get_definition("guardians")
	assert_that(def_s).is_not_null()
	assert_that(def_s.base_damage).is_equal(6)
	assert_that(def_s.hp).is_equal(25)


func test_unit_report_invariants() -> void:
	Units.ensure_definitions()
	var keys := Units.get_all_keys()
	assert_bool(keys.size() > 50).is_true()
	var checked := 0
	for key in keys:
		var stack := Units.make_fixed_stack(key, 10)
		var s: UnitStats = stack.stats
		assert_bool(s.hp > 0).is_true()
		assert_bool(s.speed >= 1).is_true()
		assert_bool(s.attack >= 0).is_true()
		assert_bool(s.base_damage >= 0).is_true()
		for tag in s.tags:
			assert_bool((tag as String).is_empty()).is_false()
		checked += 1
	assert_that(checked).is_equal(keys.size())
