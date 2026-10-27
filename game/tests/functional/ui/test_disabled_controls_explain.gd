extends BaseTest
## mvp-ui-flow 3.3, столп 1 («≤2 клика до причины»): выключенный контрол обязан
## называть причину на месте.
##
## Долгие годы «причина» означала только активные действия: `map_screen_model` и
## `city_screen` возвращают `{available, reason}` и печатают `reason` в инспекторе,
## но на экранах, где действие не недоступное, а **отсутствующее**, игрок видел серую
## плиту без ответа. Замер 2026-10-25: в `main_menu.gd` и `character_creation_ui.gd`
## не было ни одной подсказки-причины — ни у «Продолжить» без сохранения (T-110), ни у
## «Титров» без экрана-носителя (Т-133, Q-M90), ни у подрасы, которой в каноне нет
## (Q-M100 → (а), D-239). Обесцвечивание — не объяснение: игрок без сейва не отличает
## «нет сохранения» от «меню сломалось».
##
## Что гейтится:
## 1. инвентарь: в дереве стартового меню выключен (кнопка/список) — только тот, что
##    объяснён, и объяснён именно он (список сверяется целиком: новый молча
##    выключенный контрол обязан покраснеть, а не протихнуть в реестре);
## 2. у доступных пунктов подсказки-причины нет (иначе «причина» превращается в
##    пояснение ко всему подряд и перестаёт быть признаком недоступности);
## 3. конструктор: строка подрасы выключена и называет причину; владелец причины —
##    обработчик `_on_race_changed` (перед проверкой подсказка стирается, чтобы
##    тест не ехал на надписи из `_ready`).
##
## Города и кампейн-HUD здесь не проверяются: там причина печатается в инспекторе и в
## строке сообщения (`city_screen._placement_reasons`) — другой носитель того же
## столпа. Бой — остаток 3.4 (зона battle-demo).

## Скрытые выключенные контролы последнего обхода: в инвентарь D-252 не входят
## (невидимой кнопке нечего объяснять), но печатаются в отчёте — «спрятал и
## выключил» должно оставаться видимым, а не исчезать из поля зрения.
var _hidden_disabled: Array[String] = []

const MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const CREATION_SCENE_PATH := "res://scenes/ui/character_creation.tscn"
const SAVE_LOAD_SCENE_PATH := "res://scenes/ui/save_load_screen.tscn"

const CONTINUE_PATH := "RightColumn/ContinueButton"
const CREDITS_PATH := "RightColumn/CreditsButton"
const EXIT_PATH := "RightColumn/ExitButton"
const AVAILABLE_PATHS := [
	"RightColumn/NewGameButton", "RightColumn/SettingsButton",
]
const SUBRACE_PATH := "Overlay/Scroll/Root/SubraceRow/SubraceOption"
const RACE_PATH := "Overlay/Scroll/Root/RaceRow/RaceOption"

var _screen: Node = null


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.free()
	_screen = null
	await get_tree().process_frame


func _spawn(path: String) -> Node:
	var packed: PackedScene = load(path)
	assert_object(packed).is_not_null()
	_screen = packed.instantiate()
	get_tree().root.add_child(_screen)
	await get_tree().process_frame
	return _screen


## Инвентарь выключенных контролов: пути (относительно корня экрана) всех кнопок и
## списков, у которых `disabled == true` и которые **видно**. Собирается обходом
## дерева, а не списком путей: смысл проверки в том, чтобы заметить нового молча
## выключенного кандидата.
##
## Из инвентаря снят только тот контрол, который **сам себя** скрыл
## (2026-10-27, полоса hero-screen, T-252/D-280). Правило D-252 про то, что игрок,
## ткнувший в неактивную кнопку, обязан понять причину; у невидимой кнопки нет ни
## аффорданса, ни нажатия, ни наведённого курсора — `tooltip_text` на
## `visible == false` писатель без читателя, ровно тот класс, который проект
## вычищает в других местах. Снимается именно `button.visible`, а не
## `is_visible_in_tree()`: экран, спрятанный до вызова (SaveLoadScreen в меню),
## свои кнопки покажет вместе с собой, и они в инвентаре остаются. Проверка не
## превращается в «выключил и спрятал от гейта»: снятый контрол печатается в
## отчёте.
func _disabled_paths(root: Node) -> Array[String]:
	var out: Array[String] = []
	_hidden_disabled = []
	var prefix: String = str(root.get_path()) + "/"
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			var button := child as BaseButton
			if button != null and button.disabled:
				var path := str((child as Node).get_path()).trim_prefix(prefix)
				if button.visible:
					out.append(path)
				else:
					_hidden_disabled.append(path)
	out.sort()
	_hidden_disabled.sort()
	return out


func _tooltip(root: Node, path: String) -> String:
	var control := root.get_node(path) as Control
	assert_object(control).override_failure_message("контрола %s нет на экране" % path).is_not_null()
	return control.tooltip_text


func _assert_equal(actual: String, expected: String, what: String) -> void:
	assert_bool(actual == expected).override_failure_message(
		"%s: ожидалось «%s», получено «%s»" % [what, expected, actual]).is_true()


## Ожидаемый инвентарь выключенных контролов стартового меню в момент монтирования.
## Экран настроек/хроника скрыты и своих выключенных контролов не имеют; панель
## сохранений — имеет: её слоты выключены самим `.tscn` (данные ещё не читаны), и
## именно поэтому причина ставится уже в `_ready`, а не только в `open()`.
func _expected_menu_disabled(has_save: bool) -> Array[String]:
	var out: Array[String] = [CREDITS_PATH, EXIT_PATH]
	# Плитка «?» экрана снаряжения (правый нижний угол макета 12) при монтировании
	# выключается И прячется одним местом кода (`artifact_inventory_screen._build_units`:
	# `visible = false` и `disabled = true`, журнала квестов нет — T-252, D-280).
	# В инвентаре D-252 её быть не может: невидимую кнопку нельзя ни нажать, ни
	# навести, — её подсказка читателя не имеет (D-282). Контрол не исчезает из поля
	# зрения: он печатается в отчёте теста как «отключённый, но скрытый».
	if not has_save:
		out.append(CONTINUE_PATH)
	for i in 5:
		for button_name in ["LoadButton", "DeleteButton"]:
			out.append("SaveLoadScreen/Panel/Box/SlotList/Slot%d/HBox/Buttons/%s"
				% [i, button_name])
	out.sort()
	return out


func test_menu_disabled_items_carry_a_reason() -> void:
	var menu: Node = await _spawn(MENU_SCENE_PATH)
	var has_save: bool = MvpSaveManager.has_save_in_slot(MvpSaveManager.CAMPAIGN_SLOT)
	var expected := _expected_menu_disabled(has_save)
	var disabled := _disabled_paths(menu)
	assert_bool(disabled == expected).override_failure_message(
		"инвентарь выключенных контролов меню разошёлся: ждалось %s, получено %s"
		% [expected, disabled]).is_true()
	for path in disabled:
		assert_str(_tooltip(menu, path)).override_failure_message(
			"выключенный пункт %s не объясняет причину" % path).is_not_empty()
	if not _hidden_disabled.is_empty():
		print("отключённые, но скрытые контролы меню (причина не требуется, D-252): "
			+ str(_hidden_disabled))
	_assert_equal(_tooltip(menu, CREDITS_PATH), GameText.menu_credits_unavailable(),
		"причина «Титров»")
	_assert_equal(_tooltip(menu, EXIT_PATH), GameText.menu_exit_unavailable(),
		"причина «Выхода»")
	_assert_equal(_tooltip(menu, CONTINUE_PATH),
		"" if has_save else GameText.menu_continue_unavailable(), "причина «Продолжить»")


## Причина — признак недоступности, а не подпись: у живых пунктов её быть не должно.
## «Выход» в списке недоступна намеренно (AC6 макета 09), поэтому её здесь нет.
func test_menu_available_items_carry_no_reason() -> void:
	var menu: Node = await _spawn(MENU_SCENE_PATH)
	for path in AVAILABLE_PATHS:
		var button: Button = menu.get_node(path) as Button
		assert_bool(not button.disabled) \
			.override_failure_message("пункт %s должен быть доступен" % path).is_true()
		assert_bool(button.tooltip_text == "") \
			.override_failure_message("у доступного пункта %s появилась причина: «%s»"
				% [path, button.tooltip_text]).is_true()


## Панель сохранений — единственный экран, где причина уже была (строка «Сохранение
## не найдено» в той же строке слота). Проверяется, что к ней добавился и тултип,
## и что инвентарь выключенных кнопок совпадает состоянию данных в обоих режимах:
## пустой слот — обе кнопки; заполненный в режиме записи — только «Загрузить».
func test_save_load_rows_explain_their_disabled_buttons() -> void:
	var screen: Node = await _spawn(SAVE_LOAD_SCENE_PATH)
	var filled: Array[bool] = []
	for i in 5:
		filled.append(_slot_filled(i + 1))
	for mode in ["load", "save"]:
		(screen as SaveLoadScreen).open(mode)
		await get_tree().process_frame
		var expected: Array[String] = []
		for i in 5:
			var row: String = "Panel/Box/SlotList/Slot%d/HBox/Buttons/" % i
			if not filled[i]:
				expected.append(row + "LoadButton")
				expected.append(row + "DeleteButton")
			elif mode == "save":
				# Заполненный слот в режиме записи: загружать нечего, удалять — можно.
				expected.append(row + "LoadButton")
		expected.sort()
		var disabled := _disabled_paths(screen)
		assert_bool(disabled == expected).override_failure_message(
			"режим «%s»: инвентарь выключенных кнопок разошёлся: ждалось %s, получено %s"
			% [mode, expected, disabled]).is_true()
		for path in disabled:
			assert_str(_tooltip(screen, path)).override_failure_message(
				"режим «%s»: выключенная кнопка %s без причины" % [mode, path]).is_not_empty()


func _slot_filled(slot: int) -> bool:
	# То же чтение слота, что и у экрана (SaveManager.load_slot + код ошибки):
	# инвентарь сверяется с данными, а не с догадкой о них.
	var result: Dictionary = SaveManager.load_slot(slot)
	return int(result.get("error", -1)) == SaveManager.SaveError.OK


func test_creation_subrace_explains_itself() -> void:
	var creation: Node = await _spawn(CREATION_SCENE_PATH)
	var option: OptionButton = creation.get_node(SUBRACE_PATH) as OptionButton
	assert_bool(option.disabled) \
		.override_failure_message("подрас в канон-каталоге нет — список обязан быть выключен").is_true()
	assert_str(option.tooltip_text) \
		.override_failure_message("строка подрасы не объясняет, почему она пуста").is_not_empty()
	_assert_equal(option.tooltip_text, GameText.creation_subrace_unavailable(),
		"причина строки подрасы")


## Перезаполнение списка по смене расы: `_on_race_changed` вызывает `clear()` и
## пересобирает строку заново — значит причина принадлежит обработчику, а не
## надписи из `_ready`. Перед эмитом подсказка стирается вручную: без этого проверка
## проходила бы за счёт раннего `tooltip_text` (мутант M4 это и показал — `clear()`
## тултип не снимает). Ветка «у расы есть подрасы» с канон-расами недостижима: она
## остаётся для легаси-рас `hero_races.gd` и этим тестом не покрывается.
func test_race_change_keeps_the_reason() -> void:
	var creation: Node = await _spawn(CREATION_SCENE_PATH)
	var race: OptionButton = creation.get_node(RACE_PATH) as OptionButton
	var option: OptionButton = creation.get_node(SUBRACE_PATH) as OptionButton
	assert_int(race.item_count).is_equal(3)
	for idx in range(race.item_count):
		option.tooltip_text = ""
		race.select(idx)
		race.emit_signal("item_selected", idx)
		await get_tree().process_frame
		assert_bool(option.disabled) \
			.override_failure_message(
				"на расе «%s» список подрас включился без носителя" % race.get_item_text(idx)) \
			.is_true()
		assert_str(option.tooltip_text) \
			.override_failure_message(
				"смена расы не восстановила причину строки подрасы (владелец причины — _on_race_changed)") \
			.is_not_empty()
