class_name CampaignHud
extends Control
## Слой кампейн-HUD на `main.tscn` — носитель экранов кампании в игровом пути.
##
## ui-mockup-parity §7.1: носитель выбран владельцем (Q-M87 → (б), D-204) —
## новый слой HUD на `main.tscn`, архивный `scenes/archive/world.tscn` не
## реанимируется. До этого слоя `CityScreen` существовал только как сцена без
## вызывающего: из «Новой игры» в него было попасть нечем. Тем же слоем
## поднят и экран партии (`PartyScreen` был техническим экраном без
## вызывающего — его данные, `composition.party`, существуют).
##
## Полоса ресурсов, миникарта и кнопка хода (§7.3) здесь же — они не заведены:
## их носители данных ещё не решены в задачах 7.2 (реестр счётчиков).
##
## Дерево строится кодом, как в `city_screen.gd`: сцена-оболочка без единого
## узла — конвенция экранов игры (T-147/T-148: тема через роли, не через
## `theme_override_*`; новых обходов здесь нет — у кнопки только размер).

signal city_screen_opened
signal city_screen_closed
signal party_screen_opened
signal party_screen_closed

const CityScreenScene := preload("res://scenes/ui/city_screen.tscn")
const PartyScreenModelScript := preload("res://scripts/ui/party_screen_model.gd")

const CITY_BUTTON_NAME := "CityButton"
const CITY_SCREEN_NAME := "CityScreen"
const PARTY_BUTTON_NAME := "PartyButton"
const PARTY_SCREEN_NAME := "PartyScreen"
## Экраны в машине навигации кампании: id перехода и куда возвращаться.
const CITY_SCREEN_ID := &"city"
const PARTY_SCREEN_ID := &"party"
const MAP_SCREEN_ID := &"map"
## Экраны, которыми владеет этот слой: переключение между ними идёт через
## карту (см. `_show_campaign_screen`), чужие экраны (бой, хроника) слой не
## имеет права покидать сам.
const HUD_SCREEN_IDS: Array[StringName] = [CITY_SCREEN_ID, PARTY_SCREEN_ID]

var city: City = null
var city_screen: CityScreen = null
var party_screen: PartyScreen = null
var _top_row: HBoxContainer = null
var _city_button: Button = null
var _party_button: Button = null
var _ui_manager: CampaignUIManager = null
var _party: Array = []
var _party_capacity: int = PartyScreenModelScript.DEFAULT_CAPACITY


func _ready() -> void:
	_build()


func _build() -> void:
	name = "CampaignHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Слой не имеет права перехватывать ввод кампании: клики проходят сквозь
	# HUD, а кнопки (дети) берут своё как обычно.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_top_row = HBoxContainer.new()
	_top_row.name = "TopButtons"
	_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_row)
	_top_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Ширина ряда под две кнопки: 16 + 140 + 16 + 140 от правого края.
	_top_row.add_theme_constant_override("separation", 16)
	_top_row.offset_left = -312.0
	_top_row.offset_right = -16.0
	_top_row.offset_top = 16.0
	_top_row.offset_bottom = 56.0

	_city_button = Button.new()
	_city_button.name = CITY_BUTTON_NAME
	_city_button.text = GameText.campaign_city()
	_city_button.custom_minimum_size = Vector2(140, 40)
	# До привязки города кнопки нет: несвязанная кнопка обещала бы нажатие,
	# которого нет (тот же приём, что у пустых медальонов нижней панели боя).
	_city_button.disabled = true
	_city_button.pressed.connect(_on_city_pressed)
	_top_row.add_child(_city_button)

	_party_button = Button.new()
	_party_button.name = PARTY_BUTTON_NAME
	# «Партия», а не «отряд»: по глоссарию партия — персонажи игрока, отряд —
	# военная единица города (02e 12), их путать нельзя.
	_party_button.text = GameText.campaign_party()
	_party_button.custom_minimum_size = Vector2(140, 40)
	_party_button.disabled = true
	_party_button.pressed.connect(_on_party_pressed)
	_top_row.add_child(_party_button)


## Проводка до машины навигации кампании (`CampaignUIManager`). Порядок важен:
## менеджер привязывается до `bind_city`, иначе экран не будет в нём зарегистрирован.
## Без менеджера носитель работает по-старому — открывает экран напрямую.
func bind_ui_manager(manager: CampaignUIManager) -> void:
	if manager == null or manager == _ui_manager:
		return
	_ui_manager = manager
	_ui_manager.screen_changed.connect(_on_screen_changed)


## Привязка кампейн-города: экран создаётся здесь, а не в `_ready` — слой HUD
## переживает отсутствие города (сейв без города, тест без данных), а экран
## без города показывать нечего.
func bind_city(value: City, rng: RandomNumberGenerator = null) -> void:
	city = value
	if city == null:
		if _city_button != null:
			_city_button.disabled = true
		return
	if city_screen == null:
		city_screen = CityScreenScene.instantiate() as CityScreen
		city_screen.name = CITY_SCREEN_NAME
		# Экран закрыт до `open()`: корневой Control сцены видим по умолчанию,
		# и без этого шага он лег бы поверх кампании сразу после загрузки.
		city_screen.visible = false
		city_screen.close_requested.connect(_on_city_screen_close_requested)
		add_child(city_screen)
		# Экран живёт в носителе, но активным экраном он становится только через
		# машину навигации: иначе `visible_screens()` врёт, а чужой переход
		# (бой, партия) не гасит город.
		if _ui_manager != null:
			_ui_manager.register_screen(CITY_SCREEN_ID, city_screen)
	# Герой кампейн-слоя — не `HeroController` (партия — словари ростера),
	# а карта кампейна — не `MapGenerator`: экран принимает город и без них
	# (подпись переносимого груза и рельеф клеток тогда просто не рисуются).
	city_screen.setup(city, null, city.center, rng, Vector2i.ZERO, Callable())
	_city_button.disabled = false


## Привязка партии: экран создаётся здесь, как и город — слой переживает
## тест без данных и ростер, которого ещё нет. Ёмкость — из модели экрана
## (там же, откуда её берёт ростер), хост может передать свою.
## Граница: опции тренировки не прокинуты — `CampaignTrainingService
## .available_training_actions` читает сейв-стейт со схемой T-110, а не поля
## композиции; экран без опций рисует ростер и подсказку слота.
func bind_party(party: Array, capacity: int = PartyScreenModelScript.DEFAULT_CAPACITY) -> void:
	_party = party
	_party_capacity = capacity
	if _party_button == null:
		return
	if party_screen == null:
		party_screen = PartyScreen.new()
		party_screen.name = PARTY_SCREEN_NAME
		# Экран закрыт до открытия: корневой Control видим по умолчанию, и без
		# этого шага он лёг бы поверх кампании сразу после загрузки.
		party_screen.visible = false
		add_child(party_screen)
		if _ui_manager != null:
			_ui_manager.register_screen(PARTY_SCREEN_ID, party_screen)
	refresh_party_screen()
	_party_button.disabled = false


func open_city_screen() -> void:
	if city_screen == null:
		return
	# Открытие идёт через SM: отказ машины (переход запрещён из боя, партии,
	# хроники) оставляет кампанию в её экране, а не кладёт город поверх.
	if not _show_campaign_screen(CITY_SCREEN_ID):
		return
	_open_city_screen()


func open_party_screen() -> void:
	if party_screen == null:
		return
	if not _show_campaign_screen(PARTY_SCREEN_ID):
		return
	# Данные партии меняются между открытиями (бой, тренировка, ход) — экран
	# перечитывается при каждом открытии, а не один раз при привязке.
	refresh_party_screen()
	_open_party_screen()


func close_city_screen() -> void:
	if city_screen == null or not city_screen.is_open():
		return
	if _ui_manager != null:
		_ui_manager.show_screen(MAP_SCREEN_ID)
	_close_city_screen()


func close_party_screen() -> void:
	if party_screen == null or not party_screen.visible:
		return
	if _ui_manager != null:
		_ui_manager.show_screen(MAP_SCREEN_ID)
	_close_party_screen()


func is_city_screen_open() -> bool:
	return city_screen != null and city_screen.is_open()


func is_party_screen_open() -> bool:
	return party_screen != null and party_screen.visible


func refresh_city_screen() -> void:
	if city_screen != null and city_screen.is_open():
		city_screen.refresh()


func refresh_party_screen() -> void:
	if party_screen != null:
		party_screen.refresh(_party, _party_capacity, [])


func _on_city_pressed() -> void:
	if is_city_screen_open():
		close_city_screen()
	else:
		open_city_screen()


func _on_city_screen_close_requested() -> void:
	close_city_screen()


func _on_party_pressed() -> void:
	if is_party_screen_open():
		close_party_screen()
	else:
		open_party_screen()


## Esc закрывает экран, у которого своего выхода нет: у `CityScreen` есть и
## кнопка, и свой обработчик Esc; технический экран партии выхода не имеет,
## а ложится поверх кнопок — без этого шага из него не было бы выхода.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if is_party_screen_open():
			close_party_screen()
			get_viewport().set_input_as_handled()


## Смена активного экрана машиной, а не игроком: уход в бой/партию/хронику
## закрывает город, иначе под следующим экраном остался бы живой открытый город.
## То же для партии — экраны переключаются, а не складываются стопкой.
func _on_screen_changed(screen: StringName) -> void:
	if screen != CITY_SCREEN_ID:
		_close_city_screen()
	if screen != PARTY_SCREEN_ID:
		_close_party_screen()


func _open_city_screen() -> void:
	city_screen.open()
	city_screen_opened.emit()


func _close_city_screen() -> void:
	if city_screen == null or not city_screen.is_open():
		return
	city_screen.close()
	city_screen_closed.emit()


func _open_party_screen() -> void:
	party_screen.visible = true
	party_screen_opened.emit()


func _close_party_screen() -> void:
	if party_screen == null or not party_screen.visible:
		return
	party_screen.visible = false
	party_screen_closed.emit()


## Открыть экран кампании через машину. Между двумя экранами слоя машина
## перехода не даёт (`CITY→PARTY` запрещён), поэтому смена идёт через карту:
## тот же легальный путь, что и закрытие. С чужого экрана (бой, хроника) слой
## сам не сходит — отказ машины остаётся отказом.
func _show_campaign_screen(id: StringName) -> bool:
	if _ui_manager == null:
		return true
	var current := _ui_manager.current_screen()
	if current != MAP_SCREEN_ID and current != id and HUD_SCREEN_IDS.has(current):
		_ui_manager.show_screen(MAP_SCREEN_ID)
	return bool(_ui_manager.show_screen(id).get("ok", false))
