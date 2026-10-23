extends BaseTest

## 7.13 (ui-mockup-parity) — кнопка хода в живом кампейне (`scenes/main/main.tscn`).
##
## Указание владельца 2026-10-23: ход — по нажатию кнопки, авто-таймера дня нет.
## до этого раунда ход делал `_process` по таймеру (`day_duration` = 3 с), а
## кнопки не было вовсе: игрок не мог закончить ход, когда захочет, и не мог
## остановить время, чтобы спокойно разобраться с городом.
##
## Что гейтится:
## 1. кнопка есть, она подписана на носитель и включена, когда ход доступен
##    (проверка идёт от нажатия кнопки, а не от прямого вызова системного
##    метода — спека `campaign-hud`);
## 2. нажатие двигает ровно один ход: дата пересчитывается, `advance_turn`
##    вызван один раз;
## 3. повторное нажатие во время обработки хода не даёт второй ход (7.13);
## 4. авто-таймера нет: без нажатий время стоит сколько бы кадров ни прошло
##    (`_process` у драйвера отсутствует — иначе таймер вернётся молча);
## 5. открытые экраны кампании и кризис выключают кнопку, закрытые — включают;
## 6. «есть в модели» ≠ «видно на экране»: у кнопки ненулевой прямоугольник
##    внутри кадра (тот же урок, что у даты).

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const TURN_BUTTON_PATH := "CampaignHUD/CampaignHud/TopButtons/TurnButton"
const Calendar := preload("res://scripts/campaign/campaign_calendar.gd")

var _main: Node = null
var _window_size := Vector2i.ZERO
var _window_saved := false


func _root() -> Node:
	return Engine.get_main_loop().root


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


## Кампейн поднимается так же, как его поднимает игра: сцена `main.tscn`,
## `_ready` → `_init_campaign` → `_mount_campaign_hud` (там же проводка кнопки).
func _boot_campaign() -> Node:
	var window := _root() as Window
	_window_size = window.size
	_window_saved = true
	window.size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


func _hud() -> CampaignHud:
	return _main.get_node("CampaignHUD/CampaignHud") as CampaignHud


func _turn_button() -> Button:
	return _main.get_node_or_null(TURN_BUTTON_PATH) as Button


func _day() -> int:
	return _main.game_manager.get_current_day()


func test_turn_button_is_built_and_enabled() -> void:
	await _boot_campaign()
	var button := _turn_button()
	assert_object(button).is_not_null()
	assert_str(button.text).is_not_equal("")
	# Включена: драйвер подключён в `_mount_campaign_hud`, ход доступен.
	assert_bool(button.disabled).is_false()
	assert_bool(_hud().is_turn_enabled()).is_true()


## Проверка от нажатия, а не от вызова системы (спека): эмит `pressed` — тот же
## путь, что клик, а `_advance_day()` из теста был бы проверкой драйвера, а не
## носителя.
func test_pressing_turn_button_advances_one_turn() -> void:
	await _boot_campaign()
	var day := _day()
	var date_before := _hud().get_date_text()
	var turns := [0]
	_hud().turn_requested.connect(func() -> void: turns[0] += 1)

	_turn_button().pressed.emit()

	await get_tree().process_frame
	assert_int(turns[0]).is_equal(1)
	assert_int(_day()).is_equal(day + 1)
	assert_str(_hud().get_date_text()).is_equal(Calendar.date_label(day + 1))
	assert_str(_hud().get_date_text()).is_not_equal(date_before)


## Защита от повторного нажатия во время обработки (7.13): обработчик хода
## нажимает кнопку ещё раз — второго хода нет.
func test_press_during_handling_does_not_double_the_turn() -> void:
	await _boot_campaign()
	var day := _day()
	var button := _turn_button()
	var reentries := [0]
	# Вложенное нажатие — не «ещё один клик игрока», а ровно тот же дефект:
	# двойной клик или скриптовый эмит, пока ход обрабатывается.
	_hud().turn_requested.connect(func() -> void:
		reentries[0] += 1
		button.pressed.emit())

	button.pressed.emit()

	await get_tree().process_frame
	assert_int(reentries[0]).is_equal(1)
	assert_int(_day()).is_equal(day + 1)


## Авто-таймера нет (указание владельца): без нажатий кампейн-время стоит.
## Проверяется не только «день не сдвинулся» (это прошло бы и с таймером в
## 10 минут), но и отсутствием самого драйвера-таймера у сцены.
func test_time_does_not_advance_itself() -> void:
	await _boot_campaign()
	var day := _day()
	assert_bool(_main.has_method("_process")).is_false()
	for _frame in 120:
		await get_tree().process_frame
	assert_int(_day()).is_equal(day)
	assert_str(_hud().get_date_text()).is_equal(Calendar.date_label(day))


## открытые экраны кампании останавливает время (тот же приём, что пауза на
## кризисе) — кнопка хода не должна давать ход за спиной у открытого экрана.
func test_open_campaign_screen_disables_turn_button() -> void:
	await _boot_campaign()
	var day := _day()

	_hud().open_city_screen()
	await get_tree().process_frame
	assert_bool(_turn_button().disabled).is_true()
	assert_bool(_hud().is_turn_enabled()).is_false()
	# Нажатие выключенной кнопки — не ход (защита на двух уровнях: `disabled`
	# и замок слоя).
	_turn_button().pressed.emit()
	assert_int(_day()).is_equal(day)

	_hud().close_city_screen()
	await get_tree().process_frame
	assert_bool(_turn_button().disabled).is_false()
	assert_bool(_hud().is_turn_enabled()).is_true()


## Кризис модален: ход во время кризиса двигал бы триггеры событий под панелью.
## Панель не поднимается (`start_crisis` кладёт в root модалку, которая пережила
## бы тест): проверяется ровно то состояние, которое читает драйвер — флаг
## кризиса и сигнал `crisis_started`, тем же путём, каким их ставит игра.
func test_crisis_disables_turn_button() -> void:
	await _boot_campaign()
	var gm: GameManager = _main.game_manager
	gm.is_crisis_active = true
	gm.crisis_started.emit("test_crisis")
	await get_tree().process_frame
	assert_bool(_turn_button().disabled).is_true()
	var day := _day()
	_turn_button().pressed.emit()
	assert_int(_day()).is_equal(day)

	gm.is_crisis_active = false
	gm.crisis_ended.emit("test_crisis", true)
	await get_tree().process_frame
	assert_bool(_turn_button().disabled).is_false()


## Кнопка в строке с «Город»/«Партия» обязана помещаться в кадр: ряд кнопок
## растёт вместе с составом, и уехавшая за правый край кнопка хода — это
## «элемента управления нет» на глаз (урок нулевой высоты даты).
func test_turn_button_has_a_rect_on_screen() -> void:
	await _boot_campaign()
	await get_tree().process_frame
	var frame_size := (_root() as Window).size
	var rect: Rect2 = _turn_button().get_global_rect()
	assert_bool(rect.size.x > 0.0).is_true()
	assert_bool(rect.size.y > 0.0).is_true()
	assert_bool(rect.position.x >= 0.0).is_true()
	assert_bool(rect.end.x <= float(frame_size.x)).is_true()
	assert_bool(rect.end.y <= float(frame_size.y)).is_true()
