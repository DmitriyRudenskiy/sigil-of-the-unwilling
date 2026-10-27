class_name CampaignMinimap
extends Control

## Миникарта кампейна (D-281, задача 3.7): второй вид того же носителя, что у
## поля карты, — `RegionMap` с туманом войны.
##
## Своего графа, своей раскладки и своего тумана здесь нет намеренно: точки
## берутся у `CampaignMapField` в его же координатах и пересчитываются в размер
## плашки. Миникарта, у которой свой раскладчик, расходится с полем в первый же
## день, а проверить это нечем. Боевой `MinimapPanel` — другой узел и другие
## данные, он не трогается.


const COLOR_REGION := Color(0.72, 0.58, 0.4, 0.9)
const COLOR_HERO := Color(0.92, 0.88, 0.8)

var _field: CampaignMapField = null


## Поле передаётся как есть: узел читает его раскладку, но не пишет в неё.
func bind_field(field: CampaignMapField) -> void:
	_field = field
	# Раскладка поля считается по кадру поля, а не по размеру миникарты.
	field.resized.connect(refresh)
	refresh()


func refresh() -> void:
	queue_redraw()


## Что миникарта рисует (для теста: id регионов в порядке поля).
func shown_regions() -> Array:
	return [] if _field == null else _field.visible_regions()


func _draw() -> void:
	if _field == null or _field.size.x <= 0.0 or _field.size.y <= 0.0:
		return
	var k := size / _field.size
	var hero := _field.hero_region()
	var dot := maxf(2.0, minf(size.x, size.y) * 0.06)
	for region in _field.visible_regions():
		var at := _field.center_of(String(region)) * k
		draw_circle(at, dot, COLOR_HERO if String(region) == hero else COLOR_REGION)
