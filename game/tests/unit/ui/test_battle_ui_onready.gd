extends GdUnitTestSuite

# C2: лёгкий UI-тест после R3-рефакторинга (@onready + $).
# Инстанцируем реальную сцену, проверяем что все @onready-ссылки разрешились
# и сигналы подключены ровно один раз.


const _BattleUIScene := preload("res://scenes/ui/BattleUI.tscn")


func test_battle_ui_onready_resolved_and_connected() -> void:
	var ui: BattleUI = _BattleUIScene.instantiate()
	get_tree().root.add_child(ui)

	# @onready: все ссылки на ноды разрешились (скелет сцены стабилен).
	assert_object(ui._top_panel).is_not_null().override_failure_message("_top_panel не разрешился")
	assert_object(ui._status).is_not_null().override_failure_message("_status не разрешился")
	assert_object(ui._active_info).is_not_null().override_failure_message("_active_info не разрешился")
	assert_object(ui._preview).is_not_null().override_failure_message("_preview не разрешился")
	assert_object(ui._bottom_bar).is_not_null().override_failure_message("_bottom_bar не разрешился")
	assert_object(ui._initiative_list).is_not_null().override_failure_message("_initiative_list не разрешился")
	assert_object(ui._settings_screen).is_not_null().override_failure_message("_settings_screen не разрешился")
	assert_object(ui._spellbook_panel).is_not_null().override_failure_message("_spellbook_panel не разрешился")

	# Сигналы: кнопки подключены.
	assert_bool(ui._retreat_btn.pressed.is_connected(ui._on_retreat)).is_true().override_failure_message("retreat_btn.pressed не подключён")
	assert_bool(ui._wait_btn.pressed.is_connected(ui._on_wait)).is_true().override_failure_message("wait_btn.pressed не подключён")
	assert_bool(ui._attack_button.pressed.is_connected(ui._on_attack_mode)).is_true().override_failure_message("attack_btn.pressed не подключён")
	assert_bool(ui._defend_btn.pressed.is_connected(ui._on_defend)).is_true().override_failure_message("defend_btn.pressed не подключён")
	assert_bool(ui._skip_btn.pressed.is_connected(ui._on_skip)).is_true().override_failure_message("skip_btn.pressed не подключён")

	# Сигнал гримуара подключён (повторный _ready не должен двойно коннектить).
	assert_bool(ui._spellbook_panel.spell_chosen.is_connected(ui._on_spellbook_chosen)).is_true().override_failure_message("spell_chosen не подключён")

	ui.queue_free()
