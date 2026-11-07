extends BaseTest
class_name TestMarkerLabelBox

## Норма `world-marker-containment` (T-344, пункт 2.7): бокс `draw_string`
## центрируется **центром клетки**, а не начинается в нём.
##
## Пиксельный арбитр этого же требования — e2e (`tests/mcp/test_marker_fog_visual.py`,
## `leaks == 0`), но он слеп к причине: он заметит вылет, только когда камера уже
## встала так, что клетка в кадре. Здесь — чистая геометрия бокса, та, на которой
## норму можно поймать до съёмки. Дефект жил именно тут: в вызове стоял
## `HORIZONTAL_ALIGNMENT_CENTER`, что выглядело как центровка, пока бокс шириной
## 95 px тянулся от центра клетки на восток (замер зонда: Δcenter +46.5 px).

## Ширина бокса, как её считают call site: подпись города `2.0·hex`, глиф `1.6·hex`
## при `hex = 47.5` (радиус pointy-top = h/2 при `tile_size = (82, 95)`).
const W_LABEL := 95
const W_GLYPH := 76


## Бокс симметричен центру клетки: расстояние от центра до каждого из его краёв
## равно половине ширины — при любом `box_width`.
func test_box_span_is_symmetric_about_cell() -> void:
	var center := Vector2(41.0, 47.5)
	for width in [W_GLYPH, W_LABEL]:
		var origin: Vector2 = MarkerLayer.label_origin(center, width)
		assert_float(center.x - origin.x).is_equal_approx(width / 2.0, 0.001)
		assert_float(origin.x + width - center.x).is_equal_approx(width / 2.0, 0.001)


## Если бокс и выступает за соту (его ширина 95 px больше плоской ширины гекса
## `√3·R ≈ 82.3`), то вылет обязан быть симметричным: текст внутри бокса центрован,
## значит симметричен относительно клетки и его собственный силуэт. Регрессия
## «отсчёт от центра» даёт весь вылет в одну сторону — ровно тот дефект, который
## e2e мерил как 41 px.
func test_spill_is_symmetric_and_defect_is_not() -> void:
	var center_x := 41.0
	var origin := MarkerLayer.label_origin(Vector2(center_x, 47.5), W_LABEL)
	assert_float((center_x - origin.x) - (origin.x + W_LABEL - center_x)).is_equal_approx(0.0, 0.001)
	# Прежний код: точка отсчёта = центр клетки, без поправки.
	var defect_left := center_x - center_x
	var defect_right := center_x + W_LABEL - center_x
	assert_float(defect_left - defect_right).is_equal_approx(-float(W_LABEL), 0.001)


## Вертикаль — только переданный сдвиг базовой линии (`−0.30·hex` у подписи города,
## 0 у глифа); поправка по X не имеет права сдвинуть строку по Y.
func test_vertical_offset_is_passed_through() -> void:
	var center := Vector2(41.0, 47.5)
	assert_float(MarkerLayer.label_origin(center, W_GLYPH).y).is_equal_approx(center.y, 0.001)
	assert_float(MarkerLayer.label_origin(center, W_LABEL, -14.25).y).is_equal_approx(center.y - 14.25, 0.001)
