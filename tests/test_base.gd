extends SceneTree
## Base class for headless unit tests.

var _passed := 0
var _failed := 0
var _errors: Array[String] = []

func _init() -> void:
	pass  # Runner handles test execution


func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		_fail("assert_eq failed: %s (got %s, expected %s)" % [msg, str(a), str(b)])
	else:
		_pass(msg)


func assert_true(val: bool, msg: String = "") -> void:
	if not val:
		_fail("assert_true failed: %s" % msg)
	else:
		_pass(msg)


func assert_false(val: bool, msg: String = "") -> void:
	if val:
		_fail("assert_false failed: %s" % msg)
	else:
		_pass(msg)


func assert_not_null(val: Variant, msg: String = "") -> void:
	if val == null:
		_fail("assert_not_null failed: %s" % msg)
	else:
		_pass(msg)


func assert_null(val: Variant, msg: String = "") -> void:
	if val != null:
		_fail("assert_null failed: %s (got %s)" % [msg, str(val)])
	else:
		_pass(msg)


func assert_not_empty(val: Variant, msg: String = "") -> void:
	if val == null or val.is_empty():
		_fail("assert_not_empty failed: %s" % msg)
	else:
		_pass(msg)


func assert_gt(a: Variant, b: Variant, msg: String = "") -> void:
	if not (float(a) > float(b)):
		_fail("assert_gt failed: %s (got %s, expected > %s)" % [msg, str(a), str(b)])
	else:
		_pass(msg)


func assert_lt(a: Variant, b: Variant, msg: String = "") -> void:
	if not (float(a) < float(b)):
		_fail("assert_lt failed: %s (got %s, expected < %s)" % [msg, str(a), str(b)])
	else:
		_pass(msg)


func _pass(msg: String) -> void:
	_passed += 1


func _fail(msg: String) -> void:
	_failed += 1
	_errors.append(msg)
	printerr("[FAIL] %s" % msg)


func get_results() -> String:
	var lines := _errors.duplicate()
	lines.append("")
	lines.append("Results: %d passed, %d failed" % [_passed, _failed])
	if _failed == 0:
		lines.append("ALL TESTS PASSED")
	else:
		lines.append("SOME TESTS FAILED")
	return "\n".join(lines)
