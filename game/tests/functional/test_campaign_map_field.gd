extends BaseTest

## T-194 / D-281 — поле карты кампании в игровом пути.
##
## До этого шага `MapScreenModel` (карточка региона, опции движения, причины
## недоступности) не вызывался из прод-кода никем: модель карты жила в тестах и
## в сейве, а игрок видел пустой фон. Гард построен не на чтении исходников, а
## на живом экране: поднимается `main.tscn`, и поле обязано показать тот же
## туман и того же героя, что носит `RegionMap`.
##
## Что гейтится:
## 1. поле есть в живом кампейне и его состав = туман носителя (не «красивая
##    картинка», а те же открытые регионы);
## 2. клик по открытому региону выбирает его и присылает карточку из модели
##    экрана (с причинами движения), клик по туману не выбирает ничего;
## 3. переход героя меняет состав поля после `refresh()` — поле не хранит
##    снимок тумана;
## 4. поле лежит под слоем HUD: кнопка поверх карты получает клик первой,
##    второй носитель экрана не заводится;
## 5. раскладка детерминирована: один и тот же граф даёт одни и те же центры
##    (I1), кадр не «прыгает» между ходами.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"

var _main: Node = null


func _root() -> Node:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	super.after_test()


func _boot_campaign() -> Node:
	var window := _root() as Window
	window.size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


func _field() -> CampaignMapField:
	return _main.get_node("CampaignMap/CampaignMapField") as CampaignMapField


## Клик — через viewport, а не вызовом метода поля: проверяется маршрутизация
## ввода (кто из двух контролов под курсором получает нажатие), а не то, что
## обработчик умеет вызываться руками.
func _click(at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	ev.global_position = at
	_root().push_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame


## Слой CanvasLayer, на котором живёт узел (0 — вне слоя).
func _layer_of(node: Node) -> int:
	var here: Node = node
	while here != null and not (here is CanvasLayer):
		here = here.get_parent()
	return (here as CanvasLayer).layer if here != null else 0


func test_field_shows_the_carrier_fog() -> void:
	await _boot_campaign()
	var field := _field()
	assert_object(field).is_not_null()
	var map: RegionMap = _main.composition.region_map
	# Состав поля = носитель: ни больше (туман не показан открытым), ни меньше.
	assert_that(field.visible_regions()).is_equal(map.open_regions.duplicate())
	assert_that(field.visible_regions()).is_not_empty()


func test_click_selects_open_region_with_model_card() -> void:
	await _boot_campaign()
	var field := _field()
	var map: RegionMap = _main.composition.region_map
	var target := String(map.open_regions[1])  # [0] — город, берём соседний
	var cards: Array = []
	field.region_selected.connect(func(card: Dictionary) -> void: cards.append(card))
	await _click(field.center_of(target))
	assert_int(cards.size()).is_equal(1)
	var card: Dictionary = cards[0]
	assert_str(String(card.get("region", ""))).is_equal(target)
	# Карточка пришла из модели экрана: у неё есть поле видимости, которого нет
	# у сырого `RegionMap`.
	assert_bool(bool(card.get("visible", false))).is_true()
	assert_str(field.selected_region()).is_equal(target)


func test_click_on_fog_selects_nothing() -> void:
	await _boot_campaign()
	var field := _field()
	var map: RegionMap = _main.composition.region_map
	# MVP-маска S1 (5 регионов, туман радиуса 1) обязана оставлять что-то
	# закрытым: если маска изменится, тест обязанеть, а не молча проходить.
	var fog := MapScreenModel.fog_regions(map)
	assert_int(fog.size()).is_greater(0)
	var cards: Array = []
	field.region_selected.connect(func(card: Dictionary) -> void: cards.append(card))
	await _click(field.center_of(String(fog[0])))
	assert_int(cards.size()).is_equal(0)
	assert_str(field.selected_region()).is_empty()


func test_field_follows_the_carrier_after_travel() -> void:
	await _boot_campaign()
	var field := _field()
	var map: RegionMap = _main.composition.region_map
	var before := field.visible_regions()
	# Провизия — из носителя, но до запроса опций: `travel_options` считает
	# доступность по еде, а не по факту перехода.
	map.food = 999.0
	map.party_size = 1
	var moved := false
	for opt in MapScreenModel.travel_options(map):
		if bool(opt.get("available", false)):
			moved = bool(map.travel(String(opt.get("region", ""))).get("ok", false))
			break
	assert_bool(moved).is_true()
	field.refresh()
	var after := field.visible_regions()
	assert_that(after).is_equal(map.open_regions.duplicate())
	assert_int(after.size()).is_greater_equal(before.size())


## Кнопка хода лежит поверх поля. Поле обязано быть на слое ниже, иначе клик по
## кнопке гаснет в карте, а «ход» невозможно сделать.
func test_hud_button_is_above_the_field() -> void:
	await _boot_campaign()
	var field := _field()
	var button := _main.find_child("TurnButton", true, false) as Control
	assert_object(button).is_not_null()
	assert_int(_layer_of(field)).is_less(_layer_of(button))
	assert_int(button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


## Детерминизм раскладки (I1): тот же граф — те же центры. Поле пересобирается
## при `bind_map`, и «прыгающая» карта была бы видна как расхождение кадра.
func test_layout_is_deterministic() -> void:
	await _boot_campaign()
	var field := _field()
	var map: RegionMap = _main.composition.region_map
	var first := field.center_of(String(map.regions[0]))
	field.bind_map(map)
	assert_that(field.center_of(String(map.regions[0]))).is_equal(first)
	# Все гексы целиком внутри кадра — камеры у поля нет, оно вписывается.
	var size := field.size
	for region in map.regions:
		var center := field.center_of(String(region))
		assert_that(center.x >= 0.0 and center.x <= size.x).is_true()
		assert_that(center.y >= 0.0 and center.y <= size.y).is_true()
