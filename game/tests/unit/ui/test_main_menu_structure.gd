extends BaseTest
const _Scene := preload("res://scenes/MainMenu.tscn")

var _menu: Node = null

func after_test() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
	_menu = null

func _spawn() -> MainMenu:
	var m: MainMenu = _Scene.instantiate()
	_menu = m
	get_tree().root.add_child(m)
	await get_tree().process_frame
	return m

func test_main_menu_column_has_five_buttons() -> void:
	var ui := await _spawn()
	var col: Node = ui.get_node_or_null("RightColumn")
	assert_object(col).is_not_null()
	for name in ["ContinueButton", "NewGameButton", "LoadGameButton", "SettingsButton", "ExitButton"]:
		assert_object(col.get_node_or_null(name)).is_not_null().override_failure_message("%s отсутствует" % name)
	assert_int(col.get_child_count()).is_equal(6).override_failure_message("5 кнопок + Spacer")

func test_main_menu_removed_buttons_absent() -> void:
	var ui := await _spawn()
	var col: Node = ui.get_node_or_null("RightColumn")
	for name in ["ArenaButton", "ModelWarriorButton", "ModelMageButton", "ChronicleButton"]:
		assert_object(col.get_node_or_null(name)).is_null().override_failure_message("%s должен быть убран из меню" % name)

func test_main_menu_version_and_lock_on_root() -> void:
	var ui := await _spawn()
	assert_object(ui.get_node_or_null("VersionLabel")).is_not_null()
	assert_object(ui.get_node_or_null("LockPanel")).is_not_null()

func test_main_menu_signals_and_locale() -> void:
	var ui := await _spawn()
	assert_str(ui._loc()).is_equal(TranslationServer.get_locale())
	var settings: Node = ui.get_node_or_null("SettingsScreen")
	assert_object(settings).is_not_null()
	assert_bool(settings.has_signal("arena_requested")).is_true()
	assert_bool(settings.has_signal("chronicle_requested")).is_true()
	assert_bool(settings.has_signal("model_requested")).is_true()
	assert_bool(ui._on_arena.is_valid()).is_true()
	assert_bool(ui._on_chronicle.is_valid()).is_true()
	assert_bool(ui._on_model_variant.is_valid()).is_true()

func test_main_menu_continue_button_state() -> void:
	var ui := await _spawn()
	assert_bool(ui._continue_btn != null).is_true()
	# Без сохранения в слоте 1 кнопка заблокирована
	assert_bool(ui._continue_btn.disabled).is_equal(not SaveManager.has_save_in_slot(1))

func test_game_text_new_keys_localized() -> void:
	assert_str(GameText.menu_continue()).is_not_empty()
	assert_str(GameText.settings_additional()).is_not_empty()
	assert_str(GameText.settings_button_arena()).is_not_empty()
	assert_str(GameText.settings_button_chronicle()).is_not_empty()
	assert_str(GameText.settings_button_model()).is_not_empty()
