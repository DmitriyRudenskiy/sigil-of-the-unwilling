extends BaseTest

## Тесты места (задача 3.1, D-281): блок макета 10 лежит там, где нарисован, а не
## там, где его поставил `HBoxContainer`.
##
## Мера — не «узел существует», а **центр узла внутри прямоугольника элемента**,
## снятого с макета (`CampaignScreenMap.rect`). Прямоугольник масштабируется под
## живой кадр, поэтому проверка не зависит от разрешения, а расхождение в半个
## блока ловится. Знаменатель — строки карты, у которых уже есть узел-носитель:
## гард растёт вместе с покрытием (тот же рэтчет, что у `COVERAGE n/m`), и
## элемент, переехавший со своего места, роняет тест.
##
## Порядок внутри блока — вторая половина той же проверки: в макете полоса
## счётчиков, нижняя полоса и левая колонка упорядочены, а набор «всё на месте,
## но вразноброс» макетом не считается.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const ScreenMap := preload("res://scripts/ui/campaign_screen_map.gd")

## Допуск центра — 3% кадра: блок обязан попасть в свой прямоугольник, но
## внутренние отступы панели (поля `PanelCard`) не считаются переездом.
const TOLERANCE := 0.03

## Порядок нижней полосы макета слева направо (элементы, у которых уже есть
## узел-носитель; остальные придут с задачами группы 3).
const BOTTOM_BAND_ORDER: Array[StringName] = [
	&"party_frame", &"sign_plaque", &"medallion", &"ability_frame", &"cart_button",
]
## Левая нижняя колонка сверху вниз: тайлы полосы.
const LEFT_COLUMN_ORDER: Array[StringName] = [
	&"tile_city", &"tile_party", &"tile_menu", &"tile_reset",
]


var _main: Node = null


func _root() -> Window:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	super.after_test()


func _boot_campaign() -> void:
	var window := _root()
	window.size = Vector2i(1920, 1080)
	await get_tree().process_frame
	_main = load(MAIN_SCENE_PATH).instantiate()
	window.add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame


func _frame() -> Vector2:
	return _root().get_visible_rect().size


## Прямоугольник элемента в пикселях живого кадра.
func _want_rect(id: StringName) -> Rect2:
	var r: Rect2 = ScreenMap.row_by_id(id).get("rect", Rect2())
	var size := _frame()
	return Rect2(r.position.x * size.x, r.position.y * size.y, r.size.x * size.x, r.size.y * size.y)


func _carrier(id: StringName) -> Control:
	var node_name := String(ScreenMap.row_by_id(id).get("node", ""))
	if node_name == "":
		return null
	return _main.find_child(node_name, true, false) as Control


## Центр узла обязан лежать в прямоугольнике макета (с допуском). Для строки без
## узла-носителя проверка пропускается — её принимает гард состава.
func _assert_place(id: StringName) -> void:
	var node := _carrier(id)
	if node == null:
		return
	var want := _want_rect(id)
	var got := node.get_global_rect().get_center()
	var pad := _frame() * TOLERANCE
	var context := "%s: центр %s вне макетного %s (допуск ±%s)" % [
		String(id), str(got.round()), str(want), str(pad.round()),
	]
	assert_bool(got.x >= want.position.x - pad.x and got.x <= want.end.x + pad.x)\
		.is_true().override_failure_message(context + " — по X")
	assert_bool(got.y >= want.position.y - pad.y and got.y <= want.end.y + pad.y)\
		.is_true().override_failure_message(context + " — по Y")


func test_every_carrier_lies_on_its_mockup_rect() -> void:
	await _boot_campaign()
	for row in ScreenMap.ROWS:
		_assert_place(String(row.get("id", &"")))


## Правый верхний угол макета — круглые книга и шестерня; город/партия/меню/ход
## в макете живут не там, и прежний ряд из шести текстовых кнопок в правом
## верху был расхождением с макетом, а не его копией.
func test_top_right_holds_only_book_and_gear() -> void:
	await _boot_campaign()
	var size := _frame()
	for id in [&"button_book", &"button_gear"]:
		var node := _carrier(id)
		if node == null:
			continue
		var center := node.get_global_rect().get_center()
		assert_bool(center.y < size.y * 0.15).is_true()
		assert_bool(center.x > size.x * 0.8).is_true()
	for id in [&"tile_city", &"tile_party", &"tile_menu", &"turn_button"]:
		var node := _carrier(id)
		if node == null:
			continue
		assert_bool(node.get_global_rect().get_center().y > size.y * 0.5).is_true()


## Нижняя полоса: порядок блоков слева направо = порядок макета.
##
## Сравнение только для пар, которые не перекрываются, — то же правило, что у
## `test_rows_follow_the_mockup_order`: медальон нарисован поверх панели отряда,
## плита центрирована под медальоном, и строгая монотонность требовала бы от
## элементов макета не перекрывать друг друга. Отношение «плита под медальоном»
## проверяется отдельно, по совпадению центров.
func test_bottom_band_order_matches_mockup() -> void:
	await _boot_campaign()
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	for id in BOTTOM_BAND_ORDER:
		var node := _carrier(id)
		if node == null:
			continue
		rects.append(node.get_global_rect())
		names.append(String(id))
	for i in rects.size() - 1:
		if rects[i + 1].position.x < rects[i].end.x - 1.0:
			continue  # перекрываются — порядок по X не определён
		assert_bool(rects[i + 1].position.x >= rects[i].position.x - 1.0).is_true() \
			.override_failure_message(
				"%s левее %s — порядок нижней полосы не макетный" % [names[i + 1], names[i]])
	var plaque := _carrier(&"sign_plaque")
	var medallion := _carrier(&"medallion")
	if plaque == null or medallion == null:
		return
	var offset := absf(plaque.get_global_rect().get_center().x
			- medallion.get_global_rect().get_center().x)
	assert_bool(offset < _frame().x * TOLERANCE).is_true() \
			.override_failure_message("табличка не под медальоном: %f px" % offset)


## Левая нижняя колонка: тайлы полосы сложены вертикально сверху вниз. Тайлы
## макета — деления одной вертикальной плиты и стоят впритык (0.795+0.06 =
## 0.855), поэтому порядок — «не выше предыдущего», а не «строго под ним».
func test_left_column_tiles_stack_top_down() -> void:
	await _boot_campaign()
	var last_bottom := -INF
	for id in LEFT_COLUMN_ORDER:
		var node := _carrier(id)
		if node == null:
			continue
		var rect := node.get_global_rect()
		assert_bool(rect.position.y >= last_bottom - 1.0).is_true().override_failure_message(
			"тайл %s налез на предыдущий" % String(id))
		last_bottom = rect.end.y


## Силуэт панели отряда из макета — два блока (2×2 + 1), а не ряд из пяти.
## Ёмкость (`PartyScreenModel.DEFAULT_CAPACITY`) не меняется: слотов пять,
## просто три ячейки правого блока не рисуются.
func test_party_slots_split_into_two_blocks() -> void:
	await _boot_campaign()
	var left := _carrier(&"party_block_left")
	if left == null:
		return
	var right := _carrier(&"party_block_right")
	var blocks := _slot_count(left) + (0 if right == null else _slot_count(right))
	assert_int(blocks).is_equal(5)
	if right == null:
		return
	assert_int(_slot_count(left)).is_equal(4)
	assert_int(_slot_count(right)).is_equal(1)
	assert_bool(right.get_global_rect().position.x > left.get_global_rect().end.x - 1).is_true()


func _slot_count(block: Node) -> int:
	var count := 0
	for child in block.get_children():
		if String(child.name).begins_with("PartySlot"):
			count += 1
	return count
