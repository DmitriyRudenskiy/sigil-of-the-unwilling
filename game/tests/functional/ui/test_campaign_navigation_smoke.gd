extends BaseTest

## mvp-ui-flow 5.4 — сквозной UI-smoke навигации кампании: «закрыть в никуда»
## отсутствует (K-M8).
##
## До этого среза каждый экран был покрыт своим носителем поодиночке
## (`test_campaign_city_carrier` — 15 кейсов, `test_campaign_party_carrier` — 12,
## `test_campaign_hud_entries` — 7, `test_campaign_chronicle_carrier` — 6), и в
## каждом из этих файлов проверялся один-два перехода. Инвариант K-M8 сформулирован не
## про один экран, а про множество: «у каждого состояния есть выход», и он мог
## сломаться на одном экране, которого не назвали ни в одном из четырёх файлов.
## Здесь обход весь: каждый экран полосы открывается из карты, оставляет ровно
## один видимый слой, имеет выход на карту (машину *и* реальную кнопку) и
## переключается с любым соседним без стопки.
##
## Знаменатель честный: из восьми экранов K-M8 достижимы шесть — карта плюс
## четыре экрана полосы. Бой в кампании не зарегистрирован (носитель — зона
## `battle-demo-two-rosters`), преигра и меню живут до кампании. Первый тест
## сторожит именно этот список: когда чужая сессия зарегистрирует боевой экран,
## он станет красным и заставит пересчитать 5.4, а не оставит дымку «шесть из
## восьми навсегда».

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const HUD_PATH := "CampaignHUD/CampaignHud"
const TOP_BUTTONS_PATH := HUD_PATH + "/TopButtons"
const TURN_BUTTON_PATH := TOP_BUTTONS_PATH + "/TurnButton"

## Экраны полосы в канонном порядке K-M8 (город, партия, хроника, настройки):
## id машины навигации → имя кнопки слоя.
const SCREEN_BUTTONS := {
	"city": "CityButton",
	"party": "PartyButton",
	"chronicle": "ChronicleButton",
	"settings": "SettingsButton",
}

var _main: Node = null
var _window_size := Vector2i.ZERO
var _window_saved := false


func _root() -> Node:
	return Engine.get_main_loop().root


func _mount() -> Node:
	# Размер окна — как у макета: ряд кнопок прижат к правому краю, и в узком
	# окне его прямоугольник ничего общего с кадром игрока не имел бы.
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


func _manager() -> CampaignUIManager:
	return _main.campaign_ui_manager as CampaignUIManager


func _button_path(id: String) -> String:
	return "%s/%s" % [TOP_BUTTONS_PATH, SCREEN_BUTTONS[id]]


func _press(path: String) -> void:
	var button: Button = _main.get_node(path) as Button
	assert_object(button).is_not_null().override_failure_message("нет кнопки по пути %s" % path)
	assert_bool(not button.disabled) \
		.override_failure_message("кнопка %s выключена — нажатие ничего не значит" % path) \
		.is_true()
	button.emit_signal("pressed")
	await get_tree().process_frame


## Открытость экрана — только через предикат слоя: у города это `is_open()`
## (у него свой оверлей), у хроники — флаг слоя, а не `visible` (машина может
## погасить слой сама, и по `visible` закрытие не отличить).
func _is_open(id: String) -> bool:
	var hud: CampaignHud = _hud()
	match id:
		"city":
			return hud.is_city_screen_open()
		"party":
			return hud.is_party_screen_open()
		"chronicle":
			return hud.is_chronicle_screen_open()
		"settings":
			return hud.is_settings_screen_open()
	return false


## Знаменатель обхода. Сломается в двух честных случаях: экран полосы пропал
## (регрессия) или бой пришёл в кампанию (чужой срез) — в обоих нужно править
## либо код, либо формулировку 5.4, а не молча мерить четыре экрана вместо восьми.
func test_reachable_set_is_the_documented_half_of_k_m8() -> void:
	await _mount()
	var mgr: CampaignUIManager = _manager()
	assert_object(mgr).is_not_null().override_failure_message("хост обязан создать машину экранов")
	for id: String in SCREEN_BUTTONS:
		assert_bool(mgr.has_screen(StringName(id))) \
			.override_failure_message("экран %s не зарегистрирован в машине — smoke его не видит" % id) \
			.is_true()
		assert_bool(_main.get_node_or_null(_button_path(id)) is Button) \
			.override_failure_message("у экрана %s нет кнопки полосы" % id).is_true()
	# Боевой экран в кампании не зарегистрирован: его носитель — другой срез.
	assert_bool(not mgr.has_screen(&"battle")) \
		.override_failure_message(
			"боевой экран появился в кампании — знаменатель 5.4 пересчитать (было 6 из 8)"
		).is_true()
	assert_bool(mgr.current_screen() == &"map") \
		.override_failure_message("кампания стартует на карте").is_true()


## Каждый экран: открывается из карты нажатием, выключает ход, закрывается тем же
## нажатием, возвращает машину на карту и включает ход обратно.
func test_every_screen_opens_from_map_and_closes_back_to_map() -> void:
	await _mount()
	var mgr: CampaignUIManager = _manager()
	var turn: Button = _main.get_node(TURN_BUTTON_PATH) as Button
	for id: String in SCREEN_BUTTONS:
		assert_bool(not _is_open(id)) \
			.override_failure_message("экран %s открыт до нажатия" % id).is_true()
		await _press(_button_path(id))
		assert_bool(_is_open(id)) \
			.override_failure_message("экран %s не открылся нажатием кнопки" % id).is_true()
		assert_bool(mgr.current_screen() == StringName(id)) \
			.override_failure_message("машина не перешла на %s" % id).is_true()
		assert_bool(turn.disabled) \
			.override_failure_message("открытый %s обязан выключать ход — время стоит" % id) \
			.is_true()
		await _press(_button_path(id))
		assert_bool(not _is_open(id)) \
			.override_failure_message("экран %s не закрылся повторным нажатием" % id).is_true()
		assert_bool(mgr.current_screen() == &"map") \
			.override_failure_message("после закрытия %s машина обязана вернуться на карту" % id) \
			.is_true()
		assert_bool(not turn.disabled) \
			.override_failure_message("на карте ход снова доступен (закрытие — не в никуда)") \
			.is_true()


## Инвариант одного активного экрана: под открытым экраном не остаётся второго
## живого слоя (`visible_screens` смотрит зарегистрированные экраны машины).
func test_open_screen_leaves_exactly_one_visible_layer() -> void:
	await _mount()
	var mgr: CampaignUIManager = _manager()
	for id: String in SCREEN_BUTTONS:
		await _press(_button_path(id))
		var visible: Array = mgr.visible_screens()
		assert_int(visible.size()).is_equal(1)
		assert_str(String(visible[0])).is_equal(id)
		await _press(_button_path(id))
		# Карта в машине экраном не зарегистрирована (её носит хост), поэтому
		# «на карте» для `visible_screens` — ноль видимых слоёв.
		assert_int(mgr.visible_screens().size()).is_equal(0)


## «Закрыть в никуда» отсутствует на двух уровнях: машина обязана разрешать
## переход на карту из каждого состояния, а кнопка полосы — реализовывать это
## разрешение одним нажатием.
func test_every_open_screen_offers_a_way_back_to_map() -> void:
	await _mount()
	var mgr: CampaignUIManager = _manager()
	for id: String in SCREEN_BUTTONS:
		await _press(_button_path(id))
		var way: Dictionary = mgr.can_show(&"map")
		assert_bool(bool(way.get("available", false))) \
			.override_failure_message("из %s нет хода на карту: %s" % [id, way.get("reason", "")]) \
			.is_true()
		var back: Button = _main.get_node(_button_path(id)) as Button
		assert_bool(not back.disabled and back.is_visible_in_tree()) \
			.override_failure_message("кнопка возврата из %s не видна или выключена" % id) \
			.is_true()
		await _press(_button_path(id))
		assert_bool(mgr.current_screen() == &"map") \
			.override_failure_message("кнопка не реализовала разрешённый машиной ход в карту").is_true()


## Переключение соседей: 12 упорядоченных пар. Между двумя экранами полосы
## перехода нет (K-M8), поэтому смена идёт через карту — и обязана оставлять
## открытым именно целевой экран, а не стопку из двух.
func test_switching_between_neighbours_never_stacks() -> void:
	await _mount()
	var mgr: CampaignUIManager = _manager()
	for from_id: String in SCREEN_BUTTONS:
		var last_opened := ""
		for to_id: String in SCREEN_BUTTONS:
			if from_id == to_id:
				continue
			await _press(_button_path(from_id))
			assert_bool(_is_open(from_id)) \
				.override_failure_message("исходный %s не открылся" % from_id).is_true()
			await _press(_button_path(to_id))
			assert_bool(_is_open(to_id)) \
				.override_failure_message("%s не открылся поверх %s" % [to_id, from_id]).is_true()
			assert_bool(not _is_open(from_id)) \
				.override_failure_message("под %s остался открытый %s (стопка экранов)" % [to_id, from_id]) \
				.is_true()
			assert_bool(mgr.current_screen() == StringName(to_id)) \
				.override_failure_message("машина осталась на %s после перехода в %s" % [from_id, to_id]) \
				.is_true()
			assert_int(mgr.visible_screens().size()).is_equal(1)
			last_opened = to_id
		# Снять открытый экран последней пары: следующий внешний цикл начинается
		# с карты, и «открыт сосед» не должно быть его стартовым состоянием.
		if last_opened != "":
			await _press(_button_path(last_opened))
			assert_bool(mgr.current_screen() == &"map") \
				.override_failure_message("обход оставил открытый экран после пары").is_true()


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
