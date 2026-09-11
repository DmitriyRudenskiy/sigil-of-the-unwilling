extends GdUnitTestSuite
## WorldShortcuts: hotkey handling, city-overlay priority, visibility guards.

class _StubUI extends WorldUIManager:
	var overlay_open_ := false
	var closed_count := 0
	var toggled_count := 0

	func city_overlay_open() -> bool:
		return overlay_open_

	func close_city_screen() -> void:
		closed_count += 1

	func toggle_inventory() -> void:
		toggled_count += 1


class _StubCtrl extends Node:
	var visible_ := true
	var terminal_ := false
	var death_open_ := false
	var saves := 0

	func is_world_visible() -> bool:
		return visible_

	func is_terminal() -> bool:
		return terminal_

	func is_death_sequence_open() -> bool:
		return death_open_

	func save_game() -> bool:
		saves += 1
		return true


var _shortcuts: WorldShortcuts
var _ui: _StubUI
var _ctrl: _StubCtrl
var _hero: HeroController

func before_test() -> void:
	_ui = _StubUI.new()
	_ui.inventory_screen = ArtifactInventoryScreen.new()
	_ctrl = _StubCtrl.new()
	_hero = HeroController.new()
	_shortcuts = WorldShortcuts.new()
	_shortcuts.setup(null, _ui, _hero, _ctrl)
	add_child(_shortcuts)


func after_test() -> void:
	if _ui != null and is_instance_valid(_ui.inventory_screen):
		_ui.inventory_screen.free()
	for n in [_shortcuts, _ui, _ctrl, _hero]:
		if n != null and is_instance_valid(n):
			n.free()
	_shortcuts = null
	_ui = null
	_ctrl = null
	_hero = null


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	e.echo = false
	return e


func test_f5_saves_via_world_ctrl() -> void:
	_shortcuts._unhandled_input(_key(KEY_F5))
	assert_that(_ctrl.saves).is_equal(1)


func test_i_toggles_inventory() -> void:
	_shortcuts._unhandled_input(_key(KEY_I))
	assert_that(_ui.toggled_count).is_equal(1)


func test_escape_closes_city_overlay() -> void:
	_ui.overlay_open_ = true
	_shortcuts._unhandled_input(_key(KEY_ESCAPE))
	assert_that(_ui.closed_count).is_equal(1)


func test_other_keys_blocked_while_overlay_open() -> void:
	_ui.overlay_open_ = true
	_shortcuts._unhandled_input(_key(KEY_I))
	_shortcuts._unhandled_input(_key(KEY_F5))
	assert_that(_ui.toggled_count).is_equal(0)
	assert_that(_ctrl.saves).is_equal(0)


func test_escape_without_overlay_ignored() -> void:
	_shortcuts._unhandled_input(_key(KEY_ESCAPE))
	assert_that(_ui.closed_count).is_equal(0)


func test_input_blocked_when_world_hidden() -> void:
	_ctrl.visible_ = false
	_shortcuts._unhandled_input(_key(KEY_F5))
	assert_that(_ctrl.saves).is_equal(0)


func test_input_blocked_when_terminal() -> void:
	_ctrl.terminal_ = true
	_shortcuts._unhandled_input(_key(KEY_F5))
	assert_that(_ctrl.saves).is_equal(0)


func test_key_release_ignored() -> void:
	var e := _key(KEY_I)
	e.pressed = false
	_shortcuts._unhandled_input(e)
	assert_that(_ui.toggled_count).is_equal(0)
