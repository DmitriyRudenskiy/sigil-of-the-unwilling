extends BaseTest

## T-220: поле боя вписывается в полосу между бендами HUD, а не во весь вьюпорт.
##
## Предыстория. Срез mvp-ui-flow 4.1 (D-266) добавил множитель ×0.8 по порогу
## «высота окна ≤ 720». Множитель по порогу не лечит Full HD по определению: при
## 1920×1080 поле занимало долю кадра 1.000, а нижняя панель HUD (CanvasLayer, рисуется
## поверх мира всегда) лежала на последних рядах — иконки на y≈955..1010, подписи на
## y≈1030..1050 (замер T-220, кадры battle_1080.png).
##
## Теперь запас = геометрия полос HUD (`BattleUI.hud_bands()`), которую хост внедряет в
## `BattleView`. Отсюда два обязательных теста, которых раньше не было:
##   • запас обязан равняться прямоугольнику панели (иначе фикс — это просто другая
##     константа в другом файле, и правка панели её не заметит);
##   • проверяется ДОЛЯ КАДРА и положение нижней границы поля, а не значение зума:
##     множителя больше нет, и «спека удовлетворена» обязана читаться по пикселям.
##
## Ожидаемый зум тест считает сам по публичному `field_size()` и по публичному же
## `hud_reserve()`, а не повторяет формулу из `fit_camera` иначе мутант «запас не вошёл
## в формулу» остался бы зелёным (батарея tools/mut_battle_fit.sh, M1'…M6').

var _original_size := Vector2i(1920, 1080)


func before_test() -> void:
	_original_size = get_tree().root.size


func after_test() -> void:
	super.after_test()
	get_tree().root.size = _original_size
	await get_tree().process_frame


## Бой стартует на выставленном окне: путь обязан быть производственным
## (`BattleController._ready` → `_apply_hud_reserve()` → `fit_camera()`).
func _battle_at(res: Vector2i) -> Node:
	get_tree().root.size = res
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	auto_free(battle)
	add_child(battle)
	await await_millis(300)
	return battle


func _view_of(battle: Node) -> BattleView:
	return battle.get_node("BattleView") as BattleView


func _ui_of(battle: Node) -> BattleUI:
	return battle.get_node("BattleUI") as BattleUI


func _rect_of(battle: Node, path: String) -> Rect2:
	return (battle.get_node(path) as Control).get_global_rect()


## Ожидаемый зум: вписка в (вьюпорт − полосы). Reserve берётся из носителя, а не
## подставляется числом — иначе тест проверял бы сам себя.
func _expected_zoom(view: BattleView, field: Vector2) -> float:
	var vp: Vector2 = view.get_viewport().get_visible_rect().size
	var r: Vector2 = view.hud_reserve()
	return minf(vp.x / field.x, (vp.y - r.x - r.y) / field.y)


## Связка «панель ↔ запас»: то, без чего фикс был бы другой константой в другом файле.
func test_hud_reserve_equals_the_scene_bands() -> void:
	var battle: Node = await _battle_at(Vector2i(1920, 1080))
	var view := _view_of(battle)
	var bands := _ui_of(battle).hud_bands()
	var cards := _rect_of(battle, "BattleUI/hero_cards")
	var bar := _rect_of(battle, "BattleUI/bottom_bar")
	assert_bool(bar.size.y > 0.0 and cards.size.y > 0.0).is_true().override_failure_message(
		"полосы не разложены — проверка запаса была бы пустой"
	)
	# Верхний пояс — только карточки героев: лента очереди и кольцо инициативы
	# сняты со сцены сменой battle-99-hex-clean-hud.
	assert_float(bands.x).is_equal_approx(cards.end.y, 0.01) \
		.override_failure_message("верхний запас %.1f не равен нижней границе верхних полос" % bands.x)
	assert_float(bands.y).is_equal_approx(bar.size.y, 0.01) \
		.override_failure_message("нижний запас %.1f не равен высоте панели %.1f" % [bands.y, bar.size.y])
	# Хост обязан внедрить прочитанное в камеру, а не оставить нулевой запас.
	assert_float(view.hud_reserve().y).is_equal_approx(bands.y, 0.01) \
		.override_failure_message("хост не внедрил запас HUD в BattleView")


## Правка панели обязана править запас (ловит M4' — «запас из константы, не сцены»).
func test_reserve_follows_a_panel_edit() -> void:
	var battle: Node = await _battle_at(Vector2i(1920, 1080))
	var view := _view_of(battle)
	var before: float = view.hud_reserve().y
	var bar := battle.get_node("BattleUI/bottom_bar") as Control
	bar.offset_top -= 40.0
	await get_tree().process_frame
	await get_tree().process_frame
	battle.call("_apply_hud_reserve")
	var after: float = view.hud_reserve().y
	assert_float(after).is_equal_approx(before + 40.0, 0.01) \
		.override_failure_message(
			"панель стала выше на 40 px, а запас изменился с %.1f до %.1f — число живёт не в сцене"
			% [before, after]
		)


## Главный пользовательский контракт T-220: нижняя граница поля не залезает под панель.
func test_field_stays_above_the_bottom_band_at_full_hd() -> void:
	var battle: Node = await _battle_at(Vector2i(1920, 1080))
	var view := _view_of(battle)
	var field: Vector2 = view.field_size()
	var cam: Camera2D = view.get_node("Camera")
	assert_bool(field.x > 0.0 and field.y > 0.0).is_true().override_failure_message(
		"поле не залито — проверка запаса была бы пустой"
	)
	var expected := _expected_zoom(view, field)
	assert_float(cam.zoom.x).is_equal_approx(expected, 0.001)
	assert_float(cam.zoom.y).is_equal_approx(expected, 0.001)
	# Пересчёт в пиксели окна: при stretch canvas_items layout масштабируется целиком.
	var vp: Vector2 = view.get_viewport().get_visible_rect().size
	var win: Vector2i = view.get_viewport().get_window().size
	var k := float(win.y) / vp.y
	var r: Vector2 = view.hud_reserve()
	var centre_screen := vp.y / 2.0 + (r.x - r.y) / 2.0
	var bottom_edge := (centre_screen + field.y * cam.zoom.y / 2.0) * k
	var band_top := float(win.y) - r.y * k
	assert_bool(bottom_edge <= band_top + 1.0).is_true().override_failure_message(
		"поле заканчивается на y=%.0f, панель начинается на y=%.0f — нижний ряд под HUD"
		% [bottom_edge, band_top]
	)


## Требование спеки после T-220 читается долей, а не множителем: при 720p поле
## занимает не больше кадра, а меньше — с запасом под панель.
func test_field_at_720p_occupies_at_most_eighty_percent() -> void:
	var battle: Node = await _battle_at(Vector2i(1280, 720))
	var view := _view_of(battle)
	var field: Vector2 = view.field_size()
	var cam: Camera2D = view.get_node("Camera")
	var vp: Vector2 = view.get_viewport().get_visible_rect().size
	var win: Vector2i = view.get_viewport().get_window().size
	var drawn_h := field.y * cam.zoom.y * (float(win.y) / vp.y)
	assert_bool(drawn_h <= float(win.y) * 0.8).is_true().override_failure_message(
		"поле занимает %.0f px из %d (доля %.3f) — при 720p требовано ≤ 0.8"
		% [drawn_h, win.y, drawn_h / float(win.y)]
	)


## Без сдвига поле впишется в полосу, но останется отцентровано по всему кадру и
## нижней половиной ляжет на HUD (M3'). Перепутанные top/bottom уводят его вниз (M6').
func test_field_is_shifted_up_toward_the_band() -> void:
	var battle: Node = await _battle_at(Vector2i(1920, 1080))
	var view := _view_of(battle)
	var cam: Camera2D = view.get_node("Camera")
	var r: Vector2 = view.hud_reserve()
	assert_bool(r.y > r.x).is_true().override_failure_message(
		"запасы равны или нижний меньше верхнего — проверка сдвига была бы пустой"
	)
	var center := view.field_center()
	# bottom > top ⇒ камера уходит вниз по миру (position.y растёт), поле на экране — вверх.
	assert_bool(cam.position.y > center.y).is_true().override_failure_message(
		"поле не сдвинуто вверх относительно центра мира: camera.y = %.1f, center.y = %.1f"
		% [cam.position.y, center.y]
	)
	# Величина сдвига — ровно половина запаса, поделенная на зум (иначе поле либо
	# всё ещё лежит на панели, либо уехала в полосу выше верхней.
	var shift := cam.position.y - center.y
	assert_float(shift).is_equal_approx((r.y - r.x) / (2.0 * cam.zoom.y), 0.01) 		.override_failure_message("сдвиг %.1f != (bottom - top) / 2z" % shift)


## Нулевой запас = прежняя плотная вписка (ловит M1' «запас не применён» и M2'
## «прочитан, но не вошёл в формулу»: при нуле обе формулы обязаны совпасть).
func test_zero_reserve_restores_tight_fit() -> void:
	var battle: Node = await _battle_at(Vector2i(1920, 1080))
	var view := _view_of(battle)
	var field: Vector2 = view.field_size()
	var cam: Camera2D = view.get_node("Camera")
	view.set_hud_reserve(0.0, 0.0)
	view.fit_camera()
	var vp: Vector2 = view.get_viewport().get_visible_rect().size
	var expected := minf(vp.x / field.x, vp.y / field.y)
	assert_float(cam.zoom.x).is_equal_approx(expected, 0.001)
	var center := view.field_center()
	assert_float(cam.position.x).is_equal_approx(center.x, 0.01) 		.override_failure_message("при нулевом запасе поле обязано остаться по центру поля")
	assert_float(cam.position.y).is_equal_approx(center.y, 0.01) 		.override_failure_message("при нулевом запасе поле обязано остаться по центру поля")
