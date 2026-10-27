extends BaseTest

## Поэлементная карта макета экрана кампании (`CampaignScreenMap`) — инварианты
## реестра, а не пикселей.
##
## Карта объявлена **знаменателем приёмки** (D-281): «COVERAGE n/m» считается по
## её строкам, поэтому дефект реестра дороже дефекта кода. Строка без носителя
## данных и без задачи — «немой писатель» (D-200): экран покажет число или иконку,
## взятые неоткуда, и глаз по кадру этого не увидит. Адрес ячейки обязан
## совпадать с координатой, иначе тред говорит «кнопка в D5», а гард мерит другую
## клетку. Порядок верхней полосы обязан совпадать с `CampaignCounters.ROWS`,
## иначе макет и полоса расходятся молча (мешок стоял после руды ровно так).

const ScreenMap := preload("res://scripts/ui/campaign_screen_map.gd")
const Counters := preload("res://scripts/ui/campaign_counters.gd")

## Разбор макета 2026-10-28: 37 элементов в шести блоках. Число — знаменатель
## `COVERAGE n/m`; правка числа = правка разбора макета, а не «ещё узел добавили».
const EXPECTED_ELEMENTS := 37


func test_registry_size_is_the_mockup_inventory() -> void:
	assert_int(ScreenMap.ROWS.size()).is_equal(EXPECTED_ELEMENTS)


func test_ids_unique_and_blocks_known() -> void:
	var seen: Dictionary = {}
	for row in ScreenMap.ROWS:
		var id: StringName = row.get("id", &"")
		assert_bool(id != &"").is_true()
		assert_bool(not seen.has(id)).is_true()
		assert_bool(ScreenMap.BLOCKS.has(row.get("block", &""))).is_true()
		seen[id] = true
	for block in ScreenMap.BLOCKS:
		assert_int(ScreenMap.rows_in_block(block).size()).is_greater(0)


## Главный инвариант D-200: у элемента либо носитель значения, либо задача о том,
## что носителя нет. То же к рисунку — либо готовый носитель, либо партия T-247.
func test_every_element_has_carrier_or_ticket() -> void:
	for row in ScreenMap.ROWS:
		var ticket := String(row.get("ticket", ""))
		if row.get("data", &"") == &"":
			assert_str(ticket).is_not_empty()  # значение неоткуда
		if row.get("art", &"") == &"":
			assert_str(ticket).is_not_empty()  # рисунок неоткуда


## Координаты — доли кадра макета, элемент лежит внутри кадра.
func test_rects_are_normalized_and_inside_frame() -> void:
	for row in ScreenMap.ROWS:
		var rect: Rect2 = row.get("rect", Rect2())
		assert_bool(rect.size.x > 0.0 and rect.size.y > 0.0).is_true()  # пустой rect
		assert_bool(rect.position.x >= 0.0 and rect.position.y >= 0.0).is_true()
		assert_bool(rect.end.x <= 1.0 and rect.end.y <= 1.0).is_true()  # вылез за кадр


## Адрес ячейки (`scripts/ui_grid.py`, сетка 10×10) вычислен из центра `rect`.
func test_cell_matches_rect_center() -> void:
	for row in ScreenMap.ROWS:
		assert_str(String(row.get("cell", ""))) \
			.is_equal(ScreenMap.cell_of(row.get("rect", Rect2())))


## Порядок строк = порядок элементов макета: горизонтальные блоки — по X,
## левая колонка — по Y.
func test_rows_follow_the_mockup_order() -> void:
	for block in [&"top_counters", &"top_right", &"bottom_band"]:
		var last := -1.0
		for row in ScreenMap.rows_in_block(StringName(block)):
			var rect: Rect2 = row.get("rect", Rect2())
			assert_bool(rect.position.x >= last - 0.001).is_true()  # строка не по X
			last = rect.position.x
	var last_y := -1.0
	for row in ScreenMap.rows_in_block(&"left_column"):
		var rect: Rect2 = row.get("rect", Rect2())
		assert_bool(rect.position.y >= last_y - 0.001).is_true()  # строка не по Y
		last_y = rect.position.y


## Верхняя полоса: карта элементов и реестр счётчиков — один и тот же порядок
## слева направо (`counter_<id>` строки карты ↔ строка `CampaignCounters.ROWS`).
func test_counter_order_matches_counters_registry() -> void:
	var from_map: Array[String] = []
	for row in ScreenMap.rows_in_block(&"top_counters"):
		var id := String(row.get("id", &""))
		if id == "counter_frame":
			continue
		from_map.append(id)
	var from_counters: Array[String] = []
	for row in Counters.ROWS:
		from_counters.append("counter_%s" % String(row.get("id", &"")))
	assert_str(",".join(from_map)).is_equal(",".join(from_counters))


## Элементы без носителя значения обязаны быть заглушками с задачей, а не
## исчезать: список скрытых — часть приёмки (`COVERAGE n/m`).
func test_missing_data_elements_are_ticketed_stubs() -> void:
	var missing := ScreenMap.data_missing_rows()
	assert_int(missing.size()).is_greater(0)  # разбор 2026-10-28: элементы без значения
	for row in missing:
		assert_str(String(row.get("ticket", ""))).is_not_empty()
	for row in ScreenMap.art_missing_rows():
		assert_str(String(row.get("ticket", ""))).is_not_empty()
