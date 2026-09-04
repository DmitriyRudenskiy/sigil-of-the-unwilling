extends "res://tests/gut_base.gd"
## Headless tests for UnitRegistry, UnitStats, UnitStack (GUT-конвертация).

const _STACK_PATH := "res://scripts/entities/UnitStack.gd"

func _reg():
	return Units

func _stack():
	return load(_STACK_PATH)


func test_make_stack_swordsmen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var stack = _reg().make_stack("swordsmen", rng)
	assert_not_null(stack, "make_stack swordsmen")
	assert_true(stack.is_alive(), "stack alive")
	assert_eq(stack.stats.base_damage, 4, "swordsmen base_damage")
	assert_eq(stack.stats.hp, 10, "swordsmen hp")


func test_make_stack_invalid_key() -> void:
	var rng := RandomNumberGenerator.new()
	assert_null(_reg().make_stack("nonexistent_unit", rng), "invalid key returns null")


func test_make_fixed_stack() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	assert_not_null(fixed, "make_fixed_stack archers")
	assert_eq(fixed.count, 36, "count=36")


func test_stack_to_dict() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	var d = fixed.to_dict() if fixed else {}
	assert_eq(d.get("key"), "archers", "to_dict key")
	assert_eq(d.get("count"), 36, "to_dict count")


func test_stack_from_dict() -> void:
	var def_cav = _reg().get_definition("cavalry")
	var restored = _stack().from_dict({"key": "cavalry", "count": 50}, def_cav)
	assert_not_null(restored, "from_dict cavalry")
	assert_eq(restored.count, 50, "count preserved")
	assert_eq(restored.stats.base_damage, 5, "cavalry base_damage")


func test_duplicate_stack() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	var dup = fixed.duplicate_stack() if fixed else null
	assert_not_null(dup, "duplicate_stack")
	assert_eq(dup.count, fixed.count, "count preserved in duplicate")


func test_is_alive() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	assert_true(fixed.is_alive(), "alive stack is alive")
	var dead = _reg().make_fixed_stack("mages", 0)
	assert_true(dead == null or not dead.is_alive(), "zero count stack not alive")


func test_get_display_name() -> void:
	var fixed = _reg().make_fixed_stack("archers", 36)
	assert_eq(fixed.get_display_name(), "Archer", "display name")


func test_get_definition() -> void:
	var def_s = _reg().get_definition("guardians")
	assert_not_null(def_s, "get_definition guardians")
	assert_eq(def_s.base_damage, 6, "guardians base_damage")
	assert_eq(def_s.hp, 25, "guardians hp")

# ==================== 1.7 dump_unit_report.gd инварианты ====================

## Порт tools/dump_unit_report.gd: сводка по всем юнитам должна быть
## непротиворечивой. Никаких side-эффектов (UNIT_REPORT.txt не пишем).
func test_unit_report_invariants() -> void:
	Units.ensure_definitions()
	var keys := Units.get_all_keys()
	assert_true(keys.size() > 50, "registry has > 50 units (actual: %d)" % keys.size())
	var checked := 0
	for key in keys:
		var stack := Units.make_fixed_stack(key, 10)
		var s: UnitStats = stack.stats
		assert_true(s.hp > 0, "unit %s hp > 0" % key)
		assert_true(s.speed >= 1, "unit %s spd >= 1" % key)
		assert_true(s.attack >= 0, "unit %s atk >= 0" % key)
		assert_true(s.base_damage >= 0, "unit %s dmg >= 0" % key)
		for tag in s.tags:
			assert_false((tag as String).is_empty(), "unit %s tag non-empty (%s)" % [key, tag])
		checked += 1
	assert_eq(checked, keys.size(), "every unit validated")
