extends SceneTree
## Курсор боя: режимы (меч/палочка/стрела/прицел) и видимость.

const _BattleView = preload("res://systems/BattleView.gd")
const _BattleInput = preload("res://systems/BattleInput.gd")

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	var failed := 0
	failed += _test_cursor_modes_enum()
	failed += _test_cursor_overlay_mode()
	failed += _test_cursor_overlay_visibility()
	failed += _test_view_cursor_methods()
	failed += _test_input_setter_propagates()
	failed += _test_walk_cursor_mode()
	failed += _test_walk_cursor_distinct_from_ranged()

	if failed == 0:
		print("Battle cursor tests passed")
	else:
		printerr("Battle cursor tests failed: ", failed)
	_failed = failed
	_passed = 1 if failed == 0 else 0

	await process_frame
	quit(1 if failed > 0 else 0)


func _test_cursor_modes_enum() -> int:
	var errors := 0
	# DEFAULT=0, ATTACK=1, SPELL=2, RANGED=3
	if _BattleView.CursorMode.ATTACK != 1:
		printerr("CursorMode.ATTACK should be 1")
		errors += 1
	if _BattleView.CursorMode.SPELL != 2:
		printerr("CursorMode.SPELL should be 2")
		errors += 1
	if _BattleView.CursorMode.RANGED != 3:
		printerr("CursorMode.RANGED should be 3")
		errors += 1
	return errors


func _test_cursor_overlay_mode() -> int:
	var errors := 0
	var c := _BattleView.CursorOverlay.new()
	c.set_mode(_BattleView.CursorMode.ATTACK)
	if c.mode != _BattleView.CursorMode.ATTACK:
		printerr("cursor overlay mode should be ATTACK after set_cursor_mode")
		errors += 1

	c.set_mode(_BattleView.CursorMode.SPELL)
	if c.mode != _BattleView.CursorMode.SPELL:
		printerr("cursor overlay mode should be SPELL after set_cursor_mode")
		errors += 1

	c.set_mode(_BattleView.CursorMode.RANGED)
	if c.mode != _BattleView.CursorMode.RANGED:
		printerr("cursor overlay mode should be RANGED after set_cursor_mode")
		errors += 1

	c.set_mode(_BattleView.CursorMode.DEFAULT)
	if c.mode != _BattleView.CursorMode.DEFAULT:
		printerr("cursor overlay mode should be DEFAULT after set_cursor_mode")
		errors += 1

	c.queue_free()
	return errors


func _test_cursor_overlay_visibility() -> int:
	var errors := 0
	var c := _BattleView.CursorOverlay.new()
	c.visible_flag = true
	if not c.visible_flag:
		printerr("cursor should be visible when visible_flag = true")
		errors += 1

	c.visible_flag = false
	if c.visible_flag:
		printerr("cursor should be hidden when visible_flag = false")
		errors += 1

	c.queue_free()
	return errors


## BattleView.set_cursor_mode / set_cursor_visible / clear_cursor делегируют оверлею.
func _test_view_cursor_methods() -> int:
	var errors := 0
	var view := _BattleView.new()
	# Без setup() курсор null — методы должны корректно игнорировать это.
	view.set_cursor_mode(_BattleView.CursorMode.ATTACK)
	view.set_cursor_visible(true)

	# Имитация настроенного курсора.
	view._cursor = _BattleView.CursorOverlay.new()
	view.set_cursor_mode(_BattleView.CursorMode.SPELL)
	if view._cursor.mode != _BattleView.CursorMode.SPELL:
		printerr("view.set_cursor_mode should propagate to overlay")
		errors += 1

	view.set_cursor_visible(true)
	if not view._cursor.visible_flag:
		printerr("view.set_cursor_visible should set overlay visible_flag")
		errors += 1

	view.clear_cursor()
	if view._cursor.mode != _BattleView.CursorMode.DEFAULT:
		printerr("view.clear_cursor should reset mode to DEFAULT")
		errors += 1

	view._cursor.queue_free()
	view.queue_free()
	return errors


func _test_input_setter_propagates() -> int:
	var errors := 0
	var input := _BattleInput.new()
	# Без setup — дефолтный режим, сеттер работает.
	if input._cursor_mode != _BattleView.CursorMode.DEFAULT:
		printerr("input cursor mode should default to DEFAULT")
		errors += 1

	input.set_cursor_mode(_BattleView.CursorMode.ATTACK)
	if input._cursor_mode != _BattleView.CursorMode.ATTACK:
		printerr("input cursor mode should be ATTACK after set_cursor_mode")
		errors += 1

	input.set_cursor_mode(_BattleView.CursorMode.SPELL)
	if input._cursor_mode != _BattleView.CursorMode.SPELL:
		printerr("input cursor mode should be SPELL after set_cursor_mode")
		errors += 1

	input.set_cursor_mode(_BattleView.CursorMode.RANGED)
	if input._cursor_mode != _BattleView.CursorMode.RANGED:
		printerr("input cursor mode should be RANGED after set_cursor_mode")
		errors += 1

	input.queue_free()
	return errors


## Режим ходьбы (MOVE) — отдельный курсор, не путается с атакой/стрелой.
func _test_walk_cursor_mode() -> int:
	var errors := 0
	if _BattleView.CursorMode.MOVE != 4:
		printerr("CursorMode.MOVE should be 4 (added after RANGED=3)")
		errors += 1
	# Значения старых режимов не должны сдвинуться.
	if _BattleView.CursorMode.DEFAULT != 0 or _BattleView.CursorMode.ATTACK != 1:
		printerr("existing cursor mode values must not change")
		errors += 1

	var c := _BattleView.CursorOverlay.new()
	c.set_mode(_BattleView.CursorMode.MOVE)
	if c.mode != _BattleView.CursorMode.MOVE:
		printerr("cursor overlay should be MOVE after set_mode(MOVE)")
		errors += 1
	c.queue_free()
	return errors


## Курсор ходьбы должен отличаться от стрелого (RANGED) и дефолтного (DEFAULT).
func _test_walk_cursor_distinct_from_ranged() -> int:
	var errors := 0
	if _BattleView.CursorMode.MOVE == _BattleView.CursorMode.RANGED:
		printerr("MOVE cursor mode must be distinct from RANGED")
		errors += 1
	if _BattleView.CursorMode.MOVE == _BattleView.CursorMode.DEFAULT:
		printerr("MOVE cursor mode must be distinct from DEFAULT")
		errors += 1
	return errors
