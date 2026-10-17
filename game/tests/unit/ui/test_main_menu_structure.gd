extends BaseTest
const _Scene := preload("res://scenes/main_menu.tscn")

## Порядок колонки по макету 09 (ui-mockup-parity, шаг 3) — сверяется построчно.
const MOCKUP_ORDER := [
	"NewGameButton", "ContinueButton", "SettingsButton", "CreditsButton", "ExitButton",
]

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
	var names: Array = []
	for child in col.get_children():
		names.append(child.name)
	assert_array(names).is_equal(MOCKUP_ORDER).override_failure_message(
		"колонка меню обязана совпадать с макетом 09 по составу и порядку: %s" % [names])
	assert_int(col.get_child_count()).is_equal(5).override_failure_message("ровно 5 кнопок, без Spacer")

func test_main_menu_removed_buttons_absent() -> void:
	var ui := await _spawn()
	var col: Node = ui.get_node_or_null("RightColumn")
	for name in ["ArenaButton", "ModelWarriorButton", "ModelMageButton",
			"ChronicleButton", "LoadGameButton", "Spacer"]:
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
	# Cutover-проводка (раунд 6, T-110): Continue — кампанийный MVP-слот 1.
	assert_bool(ui._continue_btn.disabled).is_equal(not MvpSaveManager.has_save_in_slot(1))

func test_game_text_new_keys_localized() -> void:
	assert_str(GameText.menu_continue()).is_not_empty()
	assert_str(GameText.menu_credits()).is_not_empty()
	assert_str(GameText.settings_additional()).is_not_empty()
	assert_str(GameText.settings_button_arena()).is_not_empty()
	assert_str(GameText.settings_button_chronicle()).is_not_empty()
	assert_str(GameText.settings_button_model()).is_not_empty()


## ui-mockup-parity, шаг 3 (треб. «Кнопки стартового экрана»): нажатие доступного
## пункта ведёт в существующую сцену — цели перехода проверяются на существование
## файла сцены; сам переход живьём покрыт MCP e2e (test_full_cycle).
func test_main_menu_navigation_targets_exist() -> void:
	assert_bool(ResourceLoader.exists(MainMenu.SCENE_CONTINUE)).is_true().override_failure_message(
		"«Продолжить» ведёт в несуществующую сцену: %s" % MainMenu.SCENE_CONTINUE)
	var new_game_target: String = MainMenu._CharacterCreation.resource_path
	assert_bool(ResourceLoader.exists(new_game_target)).is_true().override_failure_message(
		"«Новая игра» ведёт в несуществующую сцену: %s" % new_game_target)


## Пункт без носителя: отключён, нажатие не меняет сцену (отличается не только цветом —
## снятые рамка и тень проверяются снимком, см. docs/mockups/after/09).
func test_main_menu_disabled_item_does_not_navigate() -> void:
	var ui := await _spawn()
	assert_bool(ui._credits_btn.disabled).is_true().override_failure_message(
		"«Титры» обязаны быть отключены: экрана-носителя нет (Т-133)")
	var before: Node = get_tree().current_scene
	ui._credits_btn.emit_signal("pressed")
	await get_tree().process_frame
	assert_object(get_tree().current_scene).is_equal(before).override_failure_message(
		"нажатие отключённого пункта не должно менять сцену")
