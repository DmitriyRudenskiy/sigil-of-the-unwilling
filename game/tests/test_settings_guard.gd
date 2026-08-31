extends "res://tests/test_base.gd"
## Regression tests for РФ7-1 / РФ7-2 / РФ7-5: settings guard, headless safety, backpack source.

const _Settings = preload("res://scripts/autoload/Settings.gd")

# РФ7-5: SettingsScreen без setup() закрывается, closed эмитится, _build пропускается
func test_settings_screen_closed_without_settings() -> void:
	var screen = SettingsScreen.new()
	var flags: Array = [false]
	screen.closed.connect(func(): flags[0] = true)
	var main_root: Window = Engine.get_main_loop().root
	main_root.add_child(screen)
	assert_true(flags[0], "closed should emit when /root/Settings is missing")
	# _build() был пропущен: у экрана нет дочерних нод (закроется queue_free в конце кадра)
	assert_eq(screen.get_child_count(), 0, "screen should have no children when _build skipped")

# РФ7-1: apply_display_mode безопасен в headless
func test_apply_display_mode_headless_safe() -> void:
	var settings = _Settings.new()
	# Не должно бросить ошибку/криш в headless-режиме
	settings.apply_display_mode()
	assert_true(true, "apply_display_mode should not crash in headless")
	settings.free()

# РФ7-2: единый источник истины для размера бэкпака
func test_backpack_single_source() -> void:
	assert_eq(HeroInventory.MAX_BACKPACK, GameSettings.MAX_BACKPACK_SIZE,
		"HeroInventory.MAX_BACKPACK must match GameSettings.MAX_BACKPACK_SIZE")
	assert_eq(GameSettings.MAX_BACKPACK_SIZE, 16, "MAX_BACKPACK_SIZE should be 16 (UI builds 16 slots)")
