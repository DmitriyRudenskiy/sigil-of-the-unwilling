extends BaseTest

# Экран города: оболочка не имеет права быть шире экрана (три дефекта съёмки
# «до» ui-mockup-parity, 2026-10-18 — чипы шапки обрезаны по правому краю,
# подпись футера обрезана по нижнему краю, золотая заглушка «План города»
# висит поверх живого плана).
#
# Замеры — на живом экране с привязанным кампейн-городом и экстремальными
# балансами. Без города `refresh()` выходит по early-return, шапка остаётся с
# билдовыми подписями, и «ничего не обрезано» ничего не доказывает: ровно так
# дефект и прожил до первой съёмки с данными.
#
# Почему замер идёт через `window.size`, а не через `size` экрана: адаптация
# смотрит на минимум из двух ширин (см. `_on_screen_resized`), а в headless
# окно — 64×64. Тот же приём в test_sidebar_collapses_at_compact_width.

const _SCREEN := preload("res://scenes/ui/city_screen.tscn")
const HexUtils := preload("res://scripts/core/hex_utils.gd")
const BuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const ConstructionService := preload("res://scripts/city/campaign_building_construction_service.gd")

const _ROW_PATH := "ScreenMargin/ScreenLayout/ScreenHeader/HeaderRow"
const _LAYOUT_PATH := "ScreenMargin/ScreenLayout"
const _CHIP_PATH := _ROW_PATH + "/ResourceHud/%sMetric"
const _CLOSE_PATH := _ROW_PATH + "/Close"
const _MESSAGE_PATH := "ScreenMargin/ScreenLayout/ScreenFooter/CityMessage"
const _TOGGLE_PATH := "ScreenMargin/ScreenLayout/ScreenFooter/LegacyToggle"

## Балансы «самое длинное, что умеет регистр»: шесть целых знаков + дробь.
const _EXTREME := 999999.9

## Причина отказа такой длины, чтобы одной строки не хватило.
const _LONG_MESSAGE := "Строительство не принято: не хватает ресурсов и рабочих " \
	+ "мест, клетка занята, требуется prerequisite и свободный лимит клеток уровня города."

var _screen: CityScreen = null
var _window_size := Vector2i.ZERO


func before_test() -> void:
	_window_size = get_window().size


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null
	# Окно шарится между тестами: чужой размер окна = чужая адаптивная мода.
	get_window().size = _window_size
	await get_tree().process_frame


## Кампейн-поселение с постройками: чипы тогда считают дельту по журналу, доска
## рендерит 52 клетки, метрики уровня берут настоящие значения.
func _screen_with_city(width: int) -> CityScreen:
	_screen = _SCREEN.instantiate() as CityScreen
	get_tree().root.add_child(_screen)
	var city := City.new()
	city.display_name = "Пепельный Пикет"
	city.center = Vector2i(20, 20)
	city.level = 3
	city.core_cells = HexUtils.core_cells(city.center)
	city.resource_ctx = ResourceContext.new()
	city.resource_ctx.setup(Resources.get_campaign_resource_defs(true), true)
	for resource_id in [&"food", &"wood", &"iron"]:
		city.resource_ctx.add(resource_id, _EXTREME)
	var catalog := BuildingCatalog.load_catalog()
	var cells := HexUtils.cells_in_core_ring(city.center, 1)
	var taken := 0
	for building_id in ["campaign_farm", "campaign_sawmill", "campaign_iron_mine",
			"campaign_housing", "campaign_barracks"]:
		if taken >= cells.size():
			break
		if bool(ConstructionService.request(city, catalog, building_id, cells[taken], {})
				.get("ok", false)):
			taken += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_screen.setup(city, null, city.center, rng, Vector2i(48, 48),
		func(_cell: Vector2i) -> int: return int(HexUtils.Terrain.GRASS))
	_screen.open()
	_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_window().size = Vector2i(width, 720)
	_screen.size = Vector2(width, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	return _screen


func _node(path: String) -> Control:
	var node := _screen.get_node_or_null(path) as Control
	assert_that(node).is_not_null()
	return node


## Правый край оболочки обязан оставаться на экране: как только минимальная
## ширина шапки превышает данную, MarginContainer раздувает весь экран и всё
## правее этой отметки просто не рисуется.
func _assert_shell_inside_screen(where: String) -> void:
	var right := _screen.get_global_position().x + _screen.size.x
	var layout := _node(_LAYOUT_PATH)
	assert_float(layout.get_global_position().x + layout.size.x).is_less_equal(right) \
		.override_failure_message("оболочка шире экрана на %.0f px (%s)" % [
			layout.get_global_position().x + layout.size.x - right, where])
	var bottom := _screen.get_global_position().y + _screen.size.y
	assert_float(layout.get_global_position().y + layout.size.y).is_less_equal(bottom) \
		.override_failure_message("оболочка ниже экрана на %.0f px (%s)" % [
			layout.get_global_position().y + layout.size.y - bottom, where])
	for path in [_CLOSE_PATH, _CHIP_PATH % "Food", _CHIP_PATH % "Wood", _CHIP_PATH % "Iron"]:
		var node := _node(path)
		assert_float(node.get_global_position().x + node.size.x).is_less_equal(right) \
			.override_failure_message("%s вылез за правый край (%s)" % [node.name, where])


func test_shell_fits_full_hd_with_extreme_balances() -> void:
	await _screen_with_city(1920)
	# На широком окне остаётся развёрнутая форма: дельта по журналу видна.
	assert_bool(_screen._header_compact).is_false()
	assert_str((_node(_CHIP_PATH % "Food") as Button).text).contains("Δ")
	_assert_shell_inside_screen("1920×720")


## Узкое окно: адаптивная шапка обязана ужаться, а не обрезать себя.
func test_shell_fits_narrow_window_in_compact_header() -> void:
	await _screen_with_city(1280)
	assert_bool(_screen._header_compact).is_true()
	assert_bool(_screen._header_subtitle.visible).is_false()
	# Короткая форма чипов: без дельты.
	assert_str((_node(_CHIP_PATH % "Food") as Button).text).not_contains("Δ")
	# Вторичные метрики уходят первыми — их место в инспекторе.
	assert_bool(_node(_ROW_PATH + "/HousingMetric").visible).is_false()
	assert_bool(_node(_ROW_PATH + "/CityLevelProgression").visible).is_false()
	# Первичные остаются: ресурсы и жители.
	assert_bool(_node(_ROW_PATH + "/PopulationMetric").visible).is_true()
	assert_bool(_node(_CLOSE_PATH).visible).is_true()
	_assert_shell_inside_screen("1280×720")


## Промежуточные ширины: между компактом и развёрнутой шапкой не должно оставаться
## зазора, где оболочка уже шире экрана.
func test_shell_fits_every_supported_width() -> void:
	for width in [1280, 1440, 1600, 1920]:
		await _screen_with_city(width)
		_assert_shell_inside_screen("%d×720" % width)


## Компактный режим обязан сниматься, когда окно снова широкое: иначе короткая
## форма останется на полном окне после одного случая узкого.
func test_header_leaves_compact_mode_when_window_widens() -> void:
	await _screen_with_city(1280)
	assert_bool(_screen._header_compact).is_true()
	get_window().size = Vector2i(1920, 1080)
	_screen.size = Vector2(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_screen._header_compact).is_false()
	assert_bool(_screen._header_subtitle.visible).is_true()
	assert_bool(_node(_ROW_PATH + "/HousingMetric").visible).is_true()
	assert_bool(_node(_ROW_PATH + "/CityLevelProgression").visible).is_true()
	assert_str((_node(_CHIP_PATH % "Food") as Button).text).contains("Δ")


## Без ресурсного контекста чипы показывают прочерк, а не «0.0» — и в компактном
## режиме тоже: иначе пустой город выглядит как город с нулевыми запасами.
func test_chips_without_resource_context_show_placeholder_in_compact_mode() -> void:
	_screen = _SCREEN.instantiate() as CityScreen
	get_tree().root.add_child(_screen)
	var city := City.new()
	city.display_name = "Пепельный Пикет"
	city.center = Vector2i(20, 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_screen.setup(city, null, city.center, rng, Vector2i(48, 48))
	_screen.open()
	_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_window().size = Vector2i(1280, 720)
	_screen.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_screen._header_compact).is_true()
	assert_str((_node(_CHIP_PATH % "Food") as Button).text).is_equal("Еда  —")


## Заглушка «План города» — только пока доску нечем заполнять. С привязанным
## городом её быть не должно: раньше она гасла лишь по клику по клетке, и на
## открытом экране золотая надпись висела поверх живого плана.
func test_board_placeholder_hides_once_board_has_cells() -> void:
	await _screen_with_city(1920)
	assert_int(_screen._board.get_rendered_cells().size()).is_greater(0)
	assert_bool(_screen._board_placeholder.visible).is_false()


## Кнопка уровня города до привязки города пустая — на кадре она выглядела
## обрезанным синим квадратом.
func test_level_button_invisible_before_city_bound() -> void:
	_screen = _SCREEN.instantiate() as CityScreen
	get_tree().root.add_child(_screen)
	await get_tree().process_frame
	var button := _node(_ROW_PATH + "/CityLevelProgression") as Button
	assert_bool(button.visible).is_false()
	assert_bool(button.text.is_empty()).is_true()


## Длинная причина отказа остаётся одной строкой футера: без переноса она
## раздувает минимальную ширину и выталкивает за экран весь экран города,
## с переносом без фиксации высоты — схлопывается в невидимую полосу.
func test_long_message_stays_single_visible_line() -> void:
	await _screen_with_city(1280)
	var message := _node(_MESSAGE_PATH) as Label
	var toggle := _node(_TOGGLE_PATH) as Button
	message.text = _LONG_MESSAGE
	await get_tree().process_frame
	assert_float(message.size.y).is_greater_equal(20.0) \
		.override_failure_message("подпись футера схлопнулась — текст невидим")
	assert_float(message.get_combined_minimum_size().x).is_less(200.0) \
		.override_failure_message("длинная подпись раздувает минимальную ширину футера")
	assert_float(toggle.get_global_position().x).is_greater_equal(
		_screen.get_global_position().x) \
		.override_failure_message("переключатель вынесен за левый край")
	_assert_shell_inside_screen("длинное сообщение, 1280×720")
