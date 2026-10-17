extends BaseTest
# Функциональные тесты кнопки «Хроника» (UI-3 шаг 3, AC3).
#
# Нажатие проверяется по сигналу `pressed` — тому самому, который BaseButton
# испускает при завершённом клике. Собственный обработчик нажатия кнопки из
# скрипта недостижим: путь «отпустил → pressed» требует мышиного фокуса, который
# ставит только viewport (gui_set_mouse_focus в API нет), а пик по координате
# через Viewport.push_input до кнопок меню не доходит. Hit-testing остаётся за
# ручным smoke (TICKET: кликабельность меню не покрыта автотестами).


func _activate(btn: Button) -> void:
	btn.emit_signal("pressed")


func test_credits_button_disabled() -> void:
	var runner := scene_runner("res://scenes/main_menu.tscn")
	var menu: Node = runner.scene()
	assert_bool((menu.get_node("RightColumn/CreditsButton") as Button).disabled).is_true()


func test_neighbour_buttons_stay_enabled() -> void:
	var runner := scene_runner("res://scenes/main_menu.tscn")
	var menu: Node = runner.scene()
	assert_bool((menu.get_node("RightColumn/NewGameButton") as Button).disabled).is_false()
	assert_bool((menu.get_node("RightColumn/SettingsButton") as Button).disabled).is_false()


func test_credits_press_changes_nothing() -> void:
	var runner := scene_runner("res://scenes/main_menu.tscn")
	var menu: Node = runner.scene()
	var settings: Control = menu.get_node("SettingsScreen")
	var chronicle: Control = menu.get_node("ChronicleScreen")
	settings.hide()
	chronicle.hide()
	_activate(menu.get_node("RightColumn/CreditsButton") as Button)
	await get_tree().process_frame
	assert_bool(settings.visible).is_false()
	assert_bool(chronicle.visible).is_false()
	assert_object(menu.get_tree().get_current_scene()).is_same(menu)


func test_credits_button_has_no_handler() -> void:
	# Заглушка до шага 5: у «Хроники» нет ни одного подключения к screen-логике.
	var runner := scene_runner("res://scenes/main_menu.tscn")
	var menu: Node = runner.scene()
	var btn: Button = menu.get_node("RightColumn/CreditsButton")
	assert_int(btn.pressed.get_connections().size()).is_equal(0)


func test_settings_button_press_opens_settings() -> void:
	var runner := scene_runner("res://scenes/main_menu.tscn")
	var menu: Node = runner.scene()
	var settings: Control = menu.get_node("SettingsScreen")
	settings.hide()
	_activate(menu.get_node("RightColumn/SettingsButton") as Button)
	await get_tree().process_frame
	assert_bool(settings.visible).is_true()


func test_continue_and_exit_disabled_state() -> void:
	# Continue — по наличию сейва в слоте 1 (main_menu.gd:_refresh_continue),
	# Exit — всегда выключена (AC6).
	var runner := scene_runner("res://scenes/main_menu.tscn")
	var menu: Node = runner.scene()
	var cont: Button = menu.get_node("RightColumn/ContinueButton")
	var exit_btn: Button = menu.get_node("RightColumn/ExitButton")
	assert_bool(cont.disabled).is_equal(not MvpSaveManager.has_save_in_slot(1))
	assert_bool(exit_btn.disabled).is_true()
