extends BaseTest

# alpha-battle-field 4.4: окно сообщений боя прокручивается по журналу.
# Проверка от кнопок ▲▼, а не от клавиш ↑/↓: клавишам свой тест
# (`test_battle_ui_hotkeys`), а кнопки панели — носитель команды из описания
# владельца, и живут они в другой ветке (`_on_history_up`/`_down` общие).

const _BATTLE_UI_SCENE := preload("res://scenes/ui/battle_ui.tscn")

var _ui: Node = null

func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
	_ui = null

func _mk_ui(lines: int = 3) -> BattleUI:
	var ui: BattleUI = _BATTLE_UI_SCENE.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)
	for i in range(lines):
		ui.set_status("запись %d" % (i + 1))
	return ui

func test_arrows_scroll_the_message_window() -> void:
	var ui := _mk_ui()
	assert_str(ui._log_line.text).is_equal("запись 3").override_failure_message(
		"свежий журнал открыт последней записью")
	ui._log_up_btn.emit_signal("pressed")
	assert_str(ui._log_line.text).is_equal("запись 2")
	ui._log_up_btn.emit_signal("pressed")
	assert_str(ui._log_line.text).is_equal("запись 1")
	ui._log_down_btn.emit_signal("pressed")
	assert_str(ui._log_line.text).is_equal("запись 2")

func test_scroll_bounds_do_not_run_off_the_journal() -> void:
	var ui := _mk_ui(2)
	for i in range(5):
		ui._log_up_btn.emit_signal("pressed")
	assert_str(ui._log_line.text).is_equal("запись 1").override_failure_message(
		"за первой записью ▲ стоит на месте")
	for i in range(5):
		ui._log_down_btn.emit_signal("pressed")
	assert_str(ui._log_line.text).is_equal("запись 2").override_failure_message(
		"за последней записью ▼ стоит на месте")

func test_empty_journal_silent() -> void:
	# Пустой журнал: стрелки молчат, панель не падает.
	var empty: BattleUI = _mk_ui(0)
	empty._log_up_btn.emit_signal("pressed")
	empty._log_down_btn.emit_signal("pressed")
	assert_str(empty._log_line.text).is_equal("")

# Отмотанное окно — положение чтения, а не замок: новая запись боя обязана
# показать себя, иначе журнал молча врёт о текущем состоянии.
func test_new_record_returns_window_to_the_last_line() -> void:
	var ui := _mk_ui(3)
	ui._log_up_btn.emit_signal("pressed")
	ui._log_up_btn.emit_signal("pressed")
	assert_str(ui._log_line.text).is_equal("запись 1")
	ui.set_status("новая")
	assert_str(ui._log_line.text).is_equal("новая")
	# ...и прокрутка от новой записи идёт в прошлое, а не в конец старого хвоста.
	ui._log_up_btn.emit_signal("pressed")
	assert_str(ui._log_line.text).is_equal("запись 3")

# Журнал кольцевой с потолком в 50 записей: старые выпадают спереди, и прокрутка
# не должна показывать то, чего уже нет.
func test_journal_keeps_its_ceiling() -> void:
	var ui := _mk_ui(1)
	for i in range(2, 61):
		ui.set_status("запись %d" % i)
	assert_int(ui._history.size()).is_equal(50)
	for i in range(60):
		ui._log_up_btn.emit_signal("pressed")
	assert_str(ui._log_line.text).is_equal("запись 11").override_failure_message(
		"верх прокрутки — самая старая из оставшихся, а не выпавшая запись")
