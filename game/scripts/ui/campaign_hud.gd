class_name CampaignHud
extends Control
## Слой кампейн-HUD на `main.tscn` — носитель экрана города в игровом пути.
##
## ui-mockup-parity §7.1: носитель выбран владельцем (Q-M87 → (б), D-204) —
## новый слой HUD на `main.tscn`, архивный `scenes/archive/world.tscn` не
## реанимируется. До этого слоя `CityScreen` существовал только как сцена без
## вызывающего: из «Новой игры» в него было попасть нечем.
##
## Полоса ресурсов, миникарта, панель отряда и кнопка хода (§7.3) здесь же —
## они не заведены: их носители данных ещё не решены в задачах 7.2 (реестр
## счётчиков). Экран города заведён первым, потому что его данные (город)
## существуют.
##
## Дерево строится кодом, как в `city_screen.gd`: сцена-оболочка без единого
## узла — конвенция экранов игры (T-147/T-148: тема через роли, не через
## `theme_override_*`; новых обходов здесь нет — у кнопки только размер).

signal city_screen_opened
signal city_screen_closed

const CityScreenScene := preload("res://scenes/ui/city_screen.tscn")

const CITY_BUTTON_NAME := "CityButton"
const CITY_SCREEN_NAME := "CityScreen"

var city: City = null
var city_screen: CityScreen = null
var _top_row: HBoxContainer = null
var _city_button: Button = null


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
	_top_row.offset_left = -172.0
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
	# Герой кампейн-слоя — не `HeroController` (партия — словари ростера),
	# а карта кампейна — не `MapGenerator`: экран принимает город и без них
	# (подпись переносимого груза и рельеф клеток тогда просто не рисуются).
	city_screen.setup(city, null, city.center, rng, Vector2i.ZERO, Callable())
	_city_button.disabled = false


func open_city_screen() -> void:
	if city_screen == null:
		return
	city_screen.open()
	city_screen_opened.emit()


func close_city_screen() -> void:
	if city_screen == null or not city_screen.is_open():
		return
	city_screen.close()
	city_screen_closed.emit()


func is_city_screen_open() -> bool:
	return city_screen != null and city_screen.is_open()


func refresh_city_screen() -> void:
	if city_screen != null and city_screen.is_open():
		city_screen.refresh()


func _on_city_pressed() -> void:
	if is_city_screen_open():
		close_city_screen()
	else:
		open_city_screen()


func _on_city_screen_close_requested() -> void:
	close_city_screen()
