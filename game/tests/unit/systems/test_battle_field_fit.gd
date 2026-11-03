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

## Ряды последнего столбца, в которые наливается носитель: верх, середина, низ.
const EDGE_ROWS := [0, 4, 8]

var _original_size := Vector2i(1920, 1080)
var _next_uid := 1000


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
	assert_float(shift).is_equal_approx((r.y - r.x) / (2.0 * cam.zoom.y), 0.01) \
		.override_failure_message("сдвиг %.1f != (bottom - top) / 2z" % shift)


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
	assert_float(cam.position.x).is_equal_approx(center.x, 0.01) \
		.override_failure_message("при нулевом запасе поле обязано остаться по центру поля")
	assert_float(cam.position.y).is_equal_approx(center.y, 0.01) \
		.override_failure_message("при нулевом запасе поле обязано остаться по центру поля")


## T-325: «сота в кадре» ≠ «фигура в кадре». Камера вписывает в кадр центры сот с
## запасом 30 px на сторону (`field_size()`), а силуэт рисуется от опорной точки и
## имеет ширину. Задача — чтобы правый край тела никогда не оказывался за кромкой.
##
## Мера — пиксели, а не константа: обходятся все нарисованные силуэты (фигура-стопка
## и ряды кадров), их края пересчитываются в координаты окна тем же трансформом,
## которым реально рисуется кадр. Ширины в лоб здесь нет намеренно: правку ловит
## конкретный спрайт со своим масштабом и опорой, а не угаданное число.
##
## Аспекта два. При 16:9 вписывание ограничивает ВЕРТИКАЛЬ (полосы HUD, T-220), и по
## горизонтали остаётся запас — этот случай держит регрессию «стало уже». При нулевом
## запасе (стенд: панель не разложена) вписывает ШИРИНА, и до кромки доживает ровно
## тот 30 px запаса, который задан в `field_size()`, — здесь тело и лезет за край.
func test_unit_silhouettes_stay_inside_the_frame() -> void:
	for case in [[Vector2i(1920, 1080), false], [Vector2i(1280, 720), false], [Vector2i(1920, 1080), true]]:
		var edge := await _worst_right_edge_at(case[0], case[1])
		assert_bool(edge["fits"]).is_true().override_failure_message(
			"%s%dx%d: правый край силуэта %s = %.1f при кадре %d — тело подрезано кромкой (T-325)"
			% ["без полос (ширина вписывает) " if case[1] else "", case[0].x, case[0].y,
				edge["who"], edge["right"], case[0].x]
		)


## Правый край самого правого силуэта при заданном размере окна. В последнем
## столбце заранее наливаются настоящие носители: на пустом поле стоит только
## демонстрационная фигура, и проверка была бы зелёной без носителя.
func _worst_right_edge_at(res: Vector2i, no_bands: bool = false) -> Dictionary:
	var battle: Node = await _battle_at(res)
	var view := _view_of(battle)
	if no_bands:
		# Состояние съёмочного стенда: панель не разложена ⇒ запас нулевой ⇒
		# вписывание считает ширина, и поле занимает кадр целиком.
		view.set_hud_reserve(0.0, 0.0)
		view.fit_camera()
	for y in EDGE_ROWS:
		view.create_unit_sprite(_unit_at("knights", Vector2i(BattleState.BW - 1, y)))
	var drawn := _silhouettes(view)
	assert_int(drawn.size()).is_greater_equal(EDGE_ROWS.size()).override_failure_message(
		"рисованных силуэтов %d, размещённых юнитов %d — проверка кромки была бы пустой"
		% [drawn.size(), EDGE_ROWS.size()]
	)
	var vp: Viewport = view.get_viewport()
	var vt: Transform2D = vp.get_canvas_transform()
	var win: Vector2i = vp.get_window().size
	var k := float(win.x) / vp.get_visible_rect().size.x
	var worst := 0.0
	var who := "—"
	for sp in drawn:
		# Край идёт через to_global + canvas-трансформ, а не «центр + ширина»: зум
		# входит в тот же трансформ, и без него замер расходится ровно на столько,
		# во сколько силуэт шире запаса (первая версия теста была зелёной при
		# подрезанном теле).
		var right: float = (vt * (sp as Node2D).to_global(Vector2(_silhouette_span(sp).x, 0.0))).x * k
		if right > worst:
			worst = right
			who = str((sp as Node2D).get_path()).get_file()
	return {"right": worst, "who": who, "fits": worst <= float(win.x)}


## Всё, что рисует **тело** под BattleView: статичная фигура (`Figure`) и ряды кадров
## (`Anim`) — два имени, которыми `create_unit_sprite` держит носитель юнита. Задник
## не проверяется намеренно: он по построению обязан перекрывать кадр целиком.
## Пустые и невидимые узлы не считаются — их кромка кадра не касается.
func _silhouettes(view: Node) -> Array:
	var out: Array = []
	var stack: Array[Node] = [view]
	while not stack.is_empty():
		for c in stack.pop_back().get_children():
			if _draws_body(c):
				out.append(c)
			stack.append(c)
	return out


func _draws_body(n: Node) -> bool:
	if not (n is Node2D) or not (n as CanvasItem).visible:
		return false
	if str(n.name) != "Figure" and str(n.name) != "Anim":
		return false
	if n is AnimatedSprite2D:
		var a := n as AnimatedSprite2D
		return a.sprite_frames != null and a.sprite_frames.has_animation(a.animation)
	return n is Sprite2D and (n as Sprite2D).texture != null


## Вынос нарисованного силуэта вправо от его опорной точки, world px: масштаб ряда
## кадров и масштаб статичной фигуры различаются, опора (у стопки — центр нижнего
## края) решает, сколько тела остаётся по эту сторону от центра клетки.
func _silhouette_span(sp: Node) -> Vector2:
	var size := Vector2.ZERO
	var centered := true
	var offset := Vector2.ZERO
	if sp is AnimatedSprite2D:
		var a := sp as AnimatedSprite2D
		size = a.sprite_frames.get_frame_texture(a.animation, a.frame).get_size()
	else:
		size = (sp as Sprite2D).texture.get_size()
		centered = (sp as Sprite2D).centered
		offset = (sp as Sprite2D).offset
	var drawn_x := size.x * absf((sp as Node2D).scale.x)
	var left := offset.x + (-drawn_x / 2.0 if centered else 0.0)
	return Vector2(left + drawn_x, -left)


func _unit_at(key: String, cell: Vector2i) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(
		UnitStack.new(UnitStats.new(key, key.left(0).to_upper(), 5, 3, 5, 3, 2), 5))
	_next_uid += 1
	u.uid = _next_uid
	u.cell = cell
	u.side = BattleState.Side.DEFENDER
	return u
