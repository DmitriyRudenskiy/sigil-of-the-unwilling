extends BaseTest

## Носитель экрана партии в игровом пути кампании (ui-mockup-parity §7.3,
## продолжение раунда «экран города»; регистрация — D-226/D-227).
##
## До этого раунда `PartyScreen` был техническим экраном без вызывающего:
## grep по игровому пути не давал ни одного `refresh`/создания узла вне тестов —
## данные партии (`composition.party`) существовали, попасть в экран из «Новой
## игры» было нечем.
##
## Что здесь гейтится:
## 1. кнопка «Партия» поднимается вместе с `main.tscn` и активна только после
##    привязки ростера (несвязанная кнопка обещала бы нажатие, которого нет);
## 2. экран зарегистрирован в машине навигации и становится активным экраном
##    (инвариант одного видимого экрана), а не просто виден поверх кампании;
## 3. отказ машины не открывает экран — из боя партия недоступна, причина
##    остаётся в `can_show` (гарантия «≤2 клика до причины», mvp-ui-flow 3.3);
## 4. переключение между экранами слоя идёт через карту: `CITY→PARTY` машина
##    запрещает, поэтому город обязан закрыться, а не остаться под партией;
## 5. кампейн-время стоит, пока экран открыт (тот же приём, что пауза на
##    кризисе и на экране города);
## 6. у экрана есть выход: технического Esc носителя закрывает его (у самого
##    `PartyScreen` кнопки выхода нет, а ложится он поверх кнопок);
## 7. экран перечитывается при каждом открытии — ростер меняется между
##    открытиями (бой, смерть, тренировка).
##
## Числа старта не изобретаются: партия строится тем же путём, что и кампания
## (`CampaignComposition.from_campaign_config`), поэтому тест сверяет заголовок
## экрана с живым ростером, а не с константой.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const PARTY_BUTTON_PATH := "CampaignHUD/CampaignHud/TopButtons/PartyButton"
const PARTY_SCREEN_PATH := "CampaignHUD/CampaignHud/PartyScreen"

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
## `_ready` → `_init_campaign` → привязка слоя. Окно — явным размером:
## headless-окно 64×64 легально включает компактный режим шапки HUD.
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


## Esc — вызовом обработчика, как в существующих тестах клавиш (`
## test_city_screen.gd`, `test_battle_ui_hotkeys.gd`): headless-`push_input`
## до `_unhandled_key_input` носителя не доходит (проверено на живом прогоне).
func _press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	(_main.get_node("CampaignHUD/CampaignHud") as CampaignHud)._unhandled_key_input(event)
	await get_tree().process_frame


func test_carrier_mounts_party_button_on_campaign_scene() -> void:
	var main := await _boot_campaign()
	assert_that(_hud()).is_not_null()
	var button := main.get_node_or_null(PARTY_BUTTON_PATH) as Button
	assert_that(button).is_not_null()
	assert_bool(button.disabled).is_false()
	# Подпись из локали, а не хардкод; «отряд» запрещён глоссарием (отряд —
	# военная единица города, партия — персонажи игрока).
	assert_str(button.text).is_equal(GameText.campaign_party())
	assert_str(button.text).is_not_equal("Отряд")


func test_party_screen_registered_in_campaign_ui_manager() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	assert_that(manager).is_not_null()
	assert_bool(manager.has_screen(&"party")).is_true()
	# До открытия не видно ни одного экрана кампании.
	assert_int(manager.visible_screens().size()).is_equal(0)


func test_open_party_screen_moves_machine_to_party() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	_hud().open_party_screen()
	assert_str(String(manager.current_screen())).is_equal("party")
	var visible: Array = manager.visible_screens()
	assert_int(visible.size()).is_equal(1)
	assert_str(String(visible[0])).is_equal("party")


## Экран показывает живой ростер, а не заглушку: заголовок = живые/ёмкость,
## слотов — ёмкость, занятых — столько, сколько персонажей в композиции.
func test_party_screen_shows_live_roster() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	hud.open_party_screen()
	var screen := main.get_node(PARTY_SCREEN_PATH) as PartyScreen
	assert_that(screen).is_not_null()
	assert_bool(screen.visible).is_true()
	var alive := PartySystem.alive_members(main.composition.party).size()
	assert_str(screen.get_header_text()).is_equal("Партия: %d/5" % alive)
	assert_int(screen.get_slot_count()).is_equal(5)
	var filled := 0
	for child in screen.get_node("Root").get_children():
		# Панели слотов — `Slot0..`, `EmptySlot0..`; `SlotHint` — подпись,
		# она тоже начинается на «Slot», поэтому фильтр по типу панели.
		if child is PanelContainer and String(child.name).begins_with("Slot"):
			filled += 1
	assert_int(filled).is_equal(alive)


func test_close_party_screen_returns_machine_to_map() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	var hud := _hud()
	hud.open_party_screen()
	hud.close_party_screen()
	assert_str(String(manager.current_screen())).is_equal("map")
	assert_bool(hud.is_party_screen_open()).is_false()
	assert_bool((main.get_node(PARTY_SCREEN_PATH) as PartyScreen).visible).is_false()
	assert_int(manager.visible_screens().size()).is_equal(0)


func test_day_cycle_pauses_while_party_screen_open() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	assert_bool(main._campaign_screen_paused).is_false()
	hud.open_party_screen()
	assert_bool(main._campaign_screen_paused).is_true()
	hud.close_party_screen()
	assert_bool(main._campaign_screen_paused).is_false()


## У технического экрана партии своей кнопки выхода нет, а ложится он поверх
## кнопок — без Esc носителя из него не было бы выхода.
func test_escape_closes_party_screen() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	var hud := _hud()
	hud.open_party_screen()
	await _press_escape()
	assert_bool(hud.is_party_screen_open()).is_false()
	assert_str(String(manager.current_screen())).is_equal("map")
	assert_bool(main._campaign_screen_paused).is_false()


## Переход запрещён — экрана нет: из боя партия не открывается, машина остаётся
## в бою, причина — в `can_show` (тот же контракт, что у экрана города).
func test_party_screen_refused_when_machine_is_in_battle() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	assert_bool(bool(manager.show_screen(&"battle").get("ok", false))).is_true()
	var hud := _hud()
	hud.open_party_screen()
	assert_bool(hud.is_party_screen_open()).is_false()
	assert_str(String(manager.current_screen())).is_equal("battle")
	assert_bool((main.get_node(PARTY_SCREEN_PATH) as PartyScreen).visible).is_false()
	assert_str(String(manager.can_show(&"party").get("reason", ""))) \
		.is_equal("not_allowed_from_battle")


## Машина не пускает `CITY→PARTY`, поэтому смена экрана слоя идёт через карту:
## город обязан закрыться (и снять паузу), а не остаться под партией.
func test_switching_city_to_party_goes_through_map() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	var hud := _hud()
	var closed := [0]
	hud.city_screen_closed.connect(func() -> void: closed[0] += 1)
	hud.open_city_screen()
	assert_str(String(manager.current_screen())).is_equal("city")
	hud.open_party_screen()
	assert_str(String(manager.current_screen())).is_equal("party")
	assert_bool(hud.is_city_screen_open()).is_false()
	assert_bool(hud.is_party_screen_open()).is_true()
	assert_int(closed[0]).is_equal(1)
	# Инвариант одного активного экрана: под партией города не видно.
	var visible: Array = manager.visible_screens()
	assert_int(visible.size()).is_equal(1)
	assert_str(String(visible[0])).is_equal("party")


## Смена активного экрана машиной (не игроком) закрывает партию — иначе под
## следующим экраном остался бы живой открытый ростер.
func test_machine_transition_closes_party_screen() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	var hud := _hud()
	hud.open_party_screen()
	manager.show_screen(&"map")
	assert_bool(hud.is_party_screen_open()).is_false()
	assert_bool(main._campaign_screen_paused).is_false()


## Носитель без машины (чистые тесты слоя, хосты без `main.tscn`) не обязан её
## иметь: прямое открытие работает, как работало до регистрации экрана.
func test_carrier_opens_party_without_ui_manager() -> void:
	var hud := CampaignHud.new()
	_main = hud
	_root().add_child(hud)
	await get_tree().process_frame
	hud.bind_party(CampaignComposition.from_campaign_config(12345).party)
	assert_bool(hud.is_party_screen_open()).is_false()
	hud.open_party_screen()
	assert_bool(hud.is_party_screen_open()).is_true()
	assert_bool((hud.get_node("PartyScreen") as PartyScreen).visible).is_true()
	hud.close_party_screen()
	assert_bool(hud.is_party_screen_open()).is_false()


## Ростер меняется между открытиями (бой, смерть) — экран обязан перечитать
## партию при открытии, а не показывать снимок привязки.
func test_party_screen_refetches_roster_on_open() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var screen := main.get_node(PARTY_SCREEN_PATH) as PartyScreen
	hud.open_party_screen()
	assert_str(screen.get_header_text()).is_equal("Партия: 2/5")
	hud.close_party_screen()
	main.composition.party[1]["state"] = PartySystem.STATE_DEAD
	hud.open_party_screen()
	assert_str(screen.get_header_text()).is_equal("Партия: 1/5")
