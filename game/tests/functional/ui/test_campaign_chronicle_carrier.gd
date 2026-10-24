extends BaseTest

## D-240 (T-175): лента хроники в кампейне — кнопка, экран, модальность.
##
## До этого среза «Хроника» в кампании не существовала физически: класс
## `ChronicleScreen` показывал строки итога забега (легаси-носитель), а
## кампанийная лента писала в `TelemetryLog` — лог сессии, который по своему
## контракту не попадает ни в сейв, ни игроку на экран. Кнопка `chronicle_requested`
## в `SettingsScreen` была выключена именно потому, что слушать её было некому.
##
## Что гейтится (от нажатия кнопки, как и остальные точки входа кампании):
## 1. кнопка есть, подписана и включена — лента привязана к слою при старте;
## 2. нажатие открывает экран со свежей лентой, повторное — закрывает;
## 3. открытый экран выключает кнопку хода (время стоит, как на городе);
## 4. из ленты по канону один ход — в карту (K-M8), но соседняя кнопка слоя не
##    упирается в отказ навигации: она сама закрывает ленту и идёт к цели;
## 5. экран перечитывает ленту при каждом открытии — новые ходы видны без
##    пересоздания слоя;
## 6. Esc и кнопка «Закрыть» на экране возвращают на карту ровно один сигнал.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const TOP_BUTTONS_PATH := "CampaignHUD/CampaignHud/TopButtons"
const HUD_PATH := "CampaignHUD/CampaignHud"
const CHRONICLE_BUTTON_PATH := TOP_BUTTONS_PATH + "/ChronicleButton"
const CHRONICLE_SCREEN_PATH := HUD_PATH + "/ChronicleScreen"
const LIST_PATH := CHRONICLE_SCREEN_PATH + "/Root/Panel/VBox/Scroll/List"
const CLOSE_BUTTON_PATH := CHRONICLE_SCREEN_PATH + "/Root/Panel/VBox/CloseButton"
const TURN_BUTTON_PATH := TOP_BUTTONS_PATH + "/TurnButton"
const CITY_BUTTON_PATH := TOP_BUTTONS_PATH + "/CityButton"

var _main: Node = null
var _window_size := Vector2i.ZERO
var _window_saved := false


func _root() -> Node:
	return Engine.get_main_loop().root


func _mount() -> Node:
	var window := _root() as Window
	_window_size = window.size
	_window_saved = true
	window.size = Vector2i(1920, 1080)
	var scene: PackedScene = load(MAIN_SCENE_PATH)
	assert_object(scene).is_not_null()
	_main = scene.instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(_main.get_node_or_null(HUD_PATH)) \
		.is_not_null().override_failure_message("main.tscn обязан нести слой CampaignHud")
	return _main


func _hud() -> CampaignHud:
	return _main.get_node(HUD_PATH) as CampaignHud


func _press(path: String) -> void:
	var button: Button = _main.get_node(path) as Button
	assert_object(button).is_not_null().override_failure_message("нет кнопки по пути %s" % path)
	assert_bool(not button.disabled) \
		.override_failure_message("кнопка %s выключена — нажатие ничего не значит" % path) \
		.is_true()
	button.emit_signal("pressed")
	await get_tree().process_frame


func _texts() -> Array[String]:
	# Все подписи ленты: заголовок дня, строки событий, пустая заготовка.
	var out: Array[String] = []
	var list: VBoxContainer = _main.get_node(LIST_PATH) as VBoxContainer
	assert_object(list).is_not_null().override_failure_message("у экрана хроники есть список")
	for child in list.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


func _is_open() -> bool:
	return _hud().is_chronicle_screen_open()


## Кнопка — живой носитель: подпись и подсказка из GameText, включённое состояние
## (лента привязана `_mount_campaign_hud`), ненулевой прямоугольник.
func test_chronicle_button_is_live() -> void:
	await _mount()
	var button: Button = _main.get_node(CHRONICLE_BUTTON_PATH) as Button
	assert_str(button.text).is_equal(GameText.campaign_chronicle())
	assert_str(button.tooltip_text).is_equal(GameText.campaign_chronicle_hint())
	assert_bool(not button.disabled) \
		.override_failure_message("лента привязана к слою — кнопка не декорация").is_true()
	assert_bool(button.get_rect().size.x > 0.0 and button.get_rect().size.y > 0.0) \
		.override_failure_message("у кнопки есть размер").is_true()


## Одно нажатие — экран с лентой, второе — закрытие. Экран скрыт до нажатия.
func test_button_opens_feed_and_closes_it() -> void:
	await _mount()
	var screen: CanvasLayer = _main.get_node(CHRONICLE_SCREEN_PATH) as CanvasLayer
	assert_bool(not screen.visible) \
		.override_failure_message("лента скрыта до нажатия").is_true()
	await _press(CHRONICLE_BUTTON_PATH)
	assert_bool(_is_open()).override_failure_message("лента открылась").is_true()
	assert_bool(screen.visible).is_true()
	await _press(CHRONICLE_BUTTON_PATH)
	assert_bool(not _is_open()) \
		.override_failure_message("повторное нажатие закрывает ленту").is_true()
	assert_bool(not screen.visible) \
		.override_failure_message("слой экрана обязан быть погашен, а не перекрыт").is_true()


## Открытая лента останавливает время: кнопка хода выключена, после закрытия —
## снова жива (тот же инвариант, что у города и партии).
func test_open_chronicle_blocks_turn() -> void:
	await _mount()
	var turn_btn: Button = _main.get_node(TURN_BUTTON_PATH) as Button
	assert_bool(not turn_btn.disabled) \
		.override_failure_message("на карте ход доступен").is_true()
	await _press(CHRONICLE_BUTTON_PATH)
	assert_bool(turn_btn.disabled) \
		.override_failure_message("открытая хроника обязана выключать кнопку хода").is_true()
	await _press(CHRONICLE_BUTTON_PATH)
	assert_bool(not turn_btn.disabled) \
		.override_failure_message("после закрытия ход снова доступен").is_true()


## По канону навигации (K-M8) из хроники один ход — в карту. Слой обязан делать
## этот ход за игрока: соседняя кнопка закрывает ленту и открывается сама, а не
## молча отказывает (инвариант «≤2 клика до причины», mvp-ui-flow 3.3).
func test_neighbour_button_closes_feed_and_opens_city() -> void:
	await _mount()
	var hud: CampaignHud = _hud()
	await _press(CHRONICLE_BUTTON_PATH)
	# Канон навигации K-M8: хроника — экран, из которого есть один ход в карту
	# (`CampaignNavigation`: MAP ↔ CHRONICLE). Соседней кнопкой из неё не идут.
	assert_bool(_main.campaign_ui_manager.current_screen() == hud.CHRONICLE_SCREEN_ID) \
		.override_failure_message("машина обязана считать активной ленту").is_true()
	await _press(CHRONICLE_BUTTON_PATH)
	assert_bool(_main.campaign_ui_manager.current_screen() == hud.MAP_SCREEN_ID) \
		.override_failure_message("закрытие ленты возвращает кампанию на карту").is_true()
	await _press(CHRONICLE_BUTTON_PATH)
	await _press(CITY_BUTTON_PATH)
	assert_bool(not hud.is_chronicle_screen_open()) \
		.override_failure_message("под городом остался живой открытый экран хроники").is_true()
	assert_bool(hud.is_city_screen_open()) \
		.override_failure_message("город открыт").is_true()


## Экран перечитывает ленту при каждом открытии: ход, сделанный между
## открытиями, обязан стать виден без пересоздания слоя.
func test_feed_is_reread_on_every_open() -> void:
	await _mount()
	await _press(CHRONICLE_BUTTON_PATH)
	var first := _texts()
	assert_bool(first.has(GameText.chronicle_line("chronicle.bit_sign"))) \
		.override_failure_message("бит 1 («Знак всё равно пришёл») не в ленте экрана").is_true()
	assert_bool(first.has(GameText.chronicle_turn(1))) \
		.override_failure_message("у ленты нет заголовка дня").is_true()
	await _press(CHRONICLE_BUTTON_PATH)
	# Между открытиями в ленте появилась новая запись (ход кампании; событие
	# добавляем носителем, а не симуляцией 21 хода — здесь гейтится перечитывание
	# экрана, а не писатели: им посвящён test_chronicle_writers).
	var turn: int = _main.composition.campaign.current_turn
	_main.composition.chronicle.record_line(turn, "chronicle.wave_warning")
	await _press(CHRONICLE_BUTTON_PATH)
	var second := _texts()
	assert_int(second.size()) \
		.override_failure_message("экран показал те же строки: лента не перечитана") \
		.is_greater(first.size())
	assert_bool(second.has(GameText.chronicle_line("chronicle.wave_warning"))) \
		.override_failure_message("свежая запись не дошла до экрана").is_true()
	assert_bool(second.has(GameText.chronicle_line("chronicle.bit_sign"))) \
		.override_failure_message("ранняя запись не должна исчезать из ленты").is_true()


## Кнопка «Закрыть» на экране и Esc возвращают на карту и зовут хоста ровно
## один раз (иначе `chronicle_screen_closed` снимал бы паузу дважды).
func test_close_button_and_escape_return_to_map() -> void:
	await _mount()
	var hud: CampaignHud = _hud()
	# Счётчик — массив: GDScript-лямбда захватывает локальную переменную по
	# значению, и `closed += 1` внутри колбэка внешнюю переменную не трогал бы.
	var closed: Array[int] = []
	hud.chronicle_screen_closed.connect(func() -> void: closed.append(1))
	await _press(CHRONICLE_BUTTON_PATH)
	await _press(CLOSE_BUTTON_PATH)
	assert_bool(not _is_open()) \
		.override_failure_message("кнопка экрана обязана закрывать ленту").is_true()
	assert_int(closed.size()) \
		.override_failure_message("сигнал закрытия должен прозвучать один раз").is_equal(1)
	assert_bool(_main.campaign_ui_manager.current_screen() == hud.MAP_SCREEN_ID).is_true()

	# Esc: headless-`push_input` не доезжает до обработчиков ввода (известный
	# сдвиг тестовой среды), поэтому цепочка проверяется вызовом обработчика —
	# код тот же, что и в живом нажатии.
	await _press(CHRONICLE_BUTTON_PATH)
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	hud._unhandled_key_input(esc)
	await get_tree().process_frame
	assert_bool(not _is_open()) \
		.override_failure_message("Esc обязан закрывать хронику").is_true()
	assert_int(closed.size()) \
		.override_failure_message("Esc не должен закрывать дважды").is_equal(2)


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	if _window_saved:
		(_root() as Window).size = _window_size
		_window_saved = false
	super.after_test()
