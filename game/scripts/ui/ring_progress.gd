class_name RingProgress
extends Control

## Кольцо прогресса (D-281, задача 3.3): доля месяца на медальоне нижней полосы.
##
## Лёгкий контрол: одно `_draw` и одно число. Своего состояния нет — долю
## считает вызывающий из `CampaignCalendar`, потому что календарь и есть носитель
## длины месяца (`days_per_month()`, 28), а не экран.
##
## Резного ободка макета нет: носитель рисунка не произведён (T-259), поэтому
## кольцо — линия, а не спрайт. Спрайт встанет сюда же, когда партия выйдет.


const COLOR_TRACK := Color(0.13, 0.11, 0.09, 0.9)
const COLOR_FILL := Color(0.78, 0.62, 0.4)

## Доля (0…1) — сколько месяца занято. Наружу только `set_fraction`.
var fraction := 0.0


func set_fraction(value: float) -> void:
	fraction = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.45
	if radius <= 0.0:
		return
	# Ободок толще трёх пикселей иначе не читается как кольцо, а на маленьком
	# медальоне минимальная ширина важнее доли пикселя.
	var width := maxf(3.0, radius * 0.16)
	var center := size * 0.5
	draw_arc(center, radius, 0.0, TAU, 96, COLOR_TRACK, width)
	if fraction > 0.0:
		# Отсчёт от «12 часов» — как часовая стрелка, а не от «3 часов».
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * fraction, 96, COLOR_FILL, width)
