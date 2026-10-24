extends BaseTest

## mvp-ui-flow 5.4 — точки входа кампании: настройки, выход в меню, автосохранение.
##
## До этого среза из живого кампейна (`scenes/main/main.tscn`) было доступно три
## экрана из восьми: карта, город, партия. Экран настроек жил в главном меню и в
## бою, а из кампании к нему не вело ничего — игрок не мог ни изменить громкость,
## ни переключить автосохранение, не входя в бой. Выхода в меню не было вовсе, а
## кампанийный слот (T-110) в живом прохождении не создавался никогда: писать его
## было некому, поэтому «Продолжить» в меню оставалась выключенной кнопкой, а
## переключатель «Автосохранение» — писателем без читателя.
##
## Что гейтится (от нажатия кнопки, не от прямого вызова метода — спека
## `campaign-hud`):
## 1. кнопки есть, подписаны носителями и включены, действие реально;
## 2. «Настройки» открывают экран через машину навигации и возвращают на карту;
##    открытый город при этом закрывается (экраны не складываются стопкой);
## 3. открытый экран настроек выключает кнопку хода — время стоит;
## 4. «В меню» просит хоста, а не делает сама: слой не знает ни про сцену, ни
##    про сейв;
## 5. автосохранение пишет кампанийный слот только при включённой настройке, и
##    записанное читается обратно с текущим днём кампании;
## 6. запись перед выходом в меню существует независимо от настройки.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const TOP_BUTTONS_PATH := "CampaignHUD/CampaignHud/TopButtons"
const SETTINGS_BUTTON_PATH := TOP_BUTTONS_PATH + "/SettingsButton"
const MENU_BUTTON_PATH := TOP_BUTTONS_PATH + "/MenuButton"
const TURN_BUTTON_PATH := TOP_BUTTONS_PATH + "/TurnButton"
const CITY_BUTTON_PATH := TOP_BUTTONS_PATH + "/CityButton"
const SETTINGS_SCREEN_PATH := "CampaignHUD/CampaignHud/SettingsScreen"

var _main: Node = null
var _window_size := Vector2i.ZERO
var _window_saved := false
var _auto_save_before: bool = false


func _root() -> Node:
	return Engine.get_main_loop().root


func _mount() -> Node:
	# Кампейн поднимается так же, как его поднимает игра, и в том же размере
	# окна, что и макет: ряд кнопок прижат к правому краю, и в узком окне его
	# прямоугольник ничего общего с кадром игрока не имел бы.
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
	assert_object(_main.get_node_or_null("CampaignHUD/CampaignHud")) \
		.is_not_null().override_failure_message("main.tscn обязан нести слой CampaignHud")
	return _main


func _press(path: String) -> void:
	var button: Button = _main.get_node(path) as Button
	assert_object(button).is_not_null().override_failure_message("нет кнопки по пути %s" % path)
	assert_bool(not button.disabled) \
		.override_failure_message("кнопка %s выключена — нажатие ничего не значит" % path) \
		.is_true()
	button.emit_signal("pressed")
	await get_tree().process_frame


func _hud() -> CampaignHud:
	return _main.get_node("CampaignHUD/CampaignHud") as CampaignHud


func _settings() -> Object:
	return Services.resolve(&"settings")


## Точка входа обязана быть живой кнопкой, а не обещанием: подпись носителя,
## включённое состояние (действие существует) и ненулевой прямоугольник.
func test_entry_buttons_are_live() -> void:
	await _mount()
	var settings_btn: Button = _main.get_node(SETTINGS_BUTTON_PATH) as Button
	var menu_btn: Button = _main.get_node(MENU_BUTTON_PATH) as Button
	assert_bool(not settings_btn.disabled) \
		.override_failure_message("настройки привязаны в `_mount_campaign_hud` — кнопка живая") \
		.is_true()
	assert_bool(not menu_btn.disabled) \
		.override_failure_message("выход в меню доступен всегда: действие не зависит от привязок") \
		.is_true()
	assert_str(settings_btn.text).is_equal(GameText.campaign_settings())
	assert_str(menu_btn.text).is_equal(GameText.campaign_menu())
	assert_str(menu_btn.tooltip_text).is_equal(GameText.campaign_menu_hint())
	assert_bool(settings_btn.get_rect().size.x > 0.0 and menu_btn.get_rect().size.y > 0.0) \
		.override_failure_message("у кнопок есть размер — «есть в дереве» ≠ «видно на экране»") \
		.is_true()


## Открытие и возврат идут через машину навигации: активный экран — настройки,
## после закрытия — снова карта; экран не виден, когда его нет.
func test_settings_button_opens_screen_and_returns_to_map() -> void:
	await _mount()
	var hud: CampaignHud = _hud()
	var screen: Control = _main.get_node(SETTINGS_SCREEN_PATH) as Control
	assert_object(screen).is_not_null().override_failure_message("экран настроек не зарегистрирован слоем")
	assert_bool(not screen.visible) \
		.override_failure_message("экран настроек скрыт до нажатия").is_true()
	assert_bool(_main.campaign_ui_manager.current_screen()
		== hud.MAP_SCREEN_ID).override_failure_message("кампания начинается на карте").is_true()

	await _press(SETTINGS_BUTTON_PATH)
	assert_bool(screen.visible).override_failure_message("настройка открылась").is_true()
	assert_bool(_main.campaign_ui_manager.current_screen()
		== hud.SETTINGS_SCREEN_ID) \
		.override_failure_message("машина должна считать активным экраном настройки") \
		.is_true()

	await _press(SETTINGS_BUTTON_PATH)
	assert_bool(not screen.visible).override_failure_message("настройки закрылись").is_true()
	assert_bool(_main.campaign_ui_manager.current_screen()
		== hud.MAP_SCREEN_ID).override_failure_message("возврат на карту").is_true()


## Экраны переключаются, а не складываются: открытый город закрывается, когда
## игрок идёт в настройки (тот же урок, что с городом и партией).
func test_settings_opening_closes_city() -> void:
	await _mount()
	var hud: CampaignHud = _hud()
	await _press(CITY_BUTTON_PATH)
	assert_bool(hud.is_city_screen_open()).override_failure_message("город открыт").is_true()

	await _press(SETTINGS_BUTTON_PATH)
	assert_bool(not hud.is_city_screen_open()) \
		.override_failure_message("под настройками остался живой открытый город") \
		.is_true()
	assert_bool(hud.is_settings_screen_open()).override_failure_message("настройки открыты").is_true()


## Открытый экран выключает кнопку хода: игрок копается в громкости — мир стоит
## (`_on_campaign_screen_opened` вешается и на настройки, как на город с партией).
func test_settings_open_blocks_turn() -> void:
	await _mount()
	var turn_btn: Button = _main.get_node(TURN_BUTTON_PATH) as Button
	assert_bool(not turn_btn.disabled) \
		.override_failure_message("на карте ход доступен").is_true()
	await _press(SETTINGS_BUTTON_PATH)
	assert_bool(turn_btn.disabled) \
		.override_failure_message("открытые настройки должны выключать кнопку хода") \
		.is_true()
	await _press(SETTINGS_BUTTON_PATH)
	assert_bool(not turn_btn.disabled) \
		.override_failure_message("после закрытия ход снова доступен").is_true()


## Слой не знает про сцену меню и про сейв — он просит хоста. Проверка идёт от
## нажатия кнопки и висит на сигнале, а не на обработчике `main.gd`: обработчик
## меняет сцену, и тест на себя это проверять нельзя.
func test_menu_button_asks_host() -> void:
	await _mount()
	var hud: CampaignHud = _hud()
	var fired: Array[int] = []
	# Обработчик хоста.detachается: он меняет сцену (`change_scene_to_file`), а
	# в тесте сигнала нам нужно проверить просьбу слоя, а не исполнение хоста —
	# исполнению посвящены два теста ниже и ux-review живого нажатия.
	for conn in hud.menu_requested.get_connections():
		hud.menu_requested.disconnect(conn.callable)
	hud.menu_requested.connect(func() -> void: fired.append(1))
	await _press(MENU_BUTTON_PATH)
	assert_int(fired.size()) \
		.override_failure_message("нажатие «В меню» обязано звать хоста ровно один раз") \
		.is_equal(1)


func test_autosave_respects_setting_and_roundtrips() -> void:
	await _mount()
	var settings: Object = _settings()
	assert_object(settings).is_not_null()
	_auto_save_before = bool(settings.auto_save)

	# Выключено (дефолт носителя) — хода нет: иначе переключатель снова стал бы
	# декорацией, а тесты писали бы слот молча.
	settings.auto_save = false
	MvpSaveManager.delete_slot(MvpSaveManager.CAMPAIGN_SLOT)
	await _press(TURN_BUTTON_PATH)
	assert_bool(not MvpSaveManager.has_save_in_slot(MvpSaveManager.CAMPAIGN_SLOT)) \
		.override_failure_message("автосохранение выключено — слот писать некому") \
		.is_true()

	settings.auto_save = true
	await _press(TURN_BUTTON_PATH)
	assert_bool(MvpSaveManager.has_save_in_slot(MvpSaveManager.CAMPAIGN_SLOT)) \
		.override_failure_message("включённое автосохранение обязано создать кампанийный слот") \
		.is_true()
	var loaded: Dictionary = MvpSaveManager.load_slot(MvpSaveManager.CAMPAIGN_SLOT)
	assert_bool(bool(loaded.get("ok", false))) \
		.override_failure_message("слот читается: %s" % str(loaded.get("message", ""))) \
		.is_true()
	var state: Dictionary = loaded.get("state", {})
	var campaign_section: Dictionary = state.get("campaign", {})
	assert_int(int(campaign_section.get("turn", -1))) \
		.override_failure_message("в слоте — ход текущей кампании, а не ноль") \
		.is_equal(int(_main.composition.campaign.current_turn))


## Запись перед выходом в меню не зависит от переключателя: другого пути
## сохранить кампанию у игрока нет.
func test_exit_save_works_without_autosave() -> void:
	await _mount()
	var settings: Object = _settings()
	assert_object(settings).is_not_null()
	_auto_save_before = bool(settings.auto_save)
	settings.auto_save = false
	MvpSaveManager.delete_slot(MvpSaveManager.CAMPAIGN_SLOT)

	var result: Dictionary = _main.save_campaign_slot()
	assert_bool(bool(result.get("ok", false))) \
		.override_failure_message("выход в меню сохраняет всегда: %s" % str(result.get("message", ""))) \
		.is_true()
	assert_bool(MvpSaveManager.has_save_in_slot(MvpSaveManager.CAMPAIGN_SLOT)).is_true()


func after_test() -> void:
	# Слот и настройку оставляем как до теста: чужой тест не должен увидеть ни
	# чужого сейва, ни включённого автосохранения.
	MvpSaveManager.delete_slot(MvpSaveManager.CAMPAIGN_SLOT)
	var settings: Object = Services.resolve(&"settings")
	if settings != null:
		settings.auto_save = _auto_save_before
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	if _window_saved:
		(_root() as Window).size = _window_size
		_window_saved = false
	super.after_test()
