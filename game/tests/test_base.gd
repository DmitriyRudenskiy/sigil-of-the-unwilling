extends SceneTree
## Base class for headless unit tests.

var _passed := 0
var _failed := 0
var _errors: Array[String] = []

## Теги файла (см. `tag(...)`). Используются ранжером для `--tag <name>`.
var _tags: Array[String] = []

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

## Сравнение float с допуском (избегает флейки на float-арифметике).
func assert_approx(a: Variant, b: Variant, eps: float = 0.0001, msg: String = "") -> void:
	if abs(float(a) - float(b)) > eps:
		_fail("assert_approx failed: %s (got %s, expected ~%s ±%s)" % [
			msg, str(a), str(b), str(eps)])
	else:
		_pass(msg)

## Пометить текущий файл/тест тегами для `--tag <name>`.
## Принимает строку или массив строк: `tag("battle")` или `tag(["battle", "slow"])`.
func tag(names: Variant) -> void:
	var list: Array = names if names is Array else [names]
	for n in list:
		if not _tags.has(n):
			_tags.append(n)


func _pass(msg: String) -> void:
	_passed += 1


func _fail(msg: String) -> void:
	_failed += 1
	_errors.append(msg)
	printerr("[FAIL] %s" % msg)


## Хук очистки после каждого метода (если определён — вызывает ранжер).
## По умолчанию пустой. Нужен, когда тесты оставляют глобальное состояние.
func after_each() -> void:
	pass

func get_results() -> String:
	var lines := _errors.duplicate()
	lines.append("")
	lines.append("Results: %d passed, %d failed" % [_passed, _failed])
	if _failed == 0:
		lines.append("ALL TESTS PASSED")
	else:
		lines.append("SOME TESTS FAILED")
	return "\n".join(lines)
