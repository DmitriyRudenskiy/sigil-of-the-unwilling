extends BaseTest

## mvp-ui-flow 4.1 (C-10): поле боя при 1280×720 — масштаб ×0.8.
##
## До среза `BattleView.fit_camera()` вписывал поле «в притык» на любом
## разрешении: зум = min(вьюпорт/поле), то есть при 720 px по высоте нижний ряд
## клеток занимал всю высоту и залезал под нижнюю панель HUD (та — CanvasLayer,
## рисуется поверх мира). Требование спеки («The battle field at 720p SHALL use
## scale x0.8») не выполнялось ни кодом, ни тестом; остаток задачи 4.1 был именно
## этот пункт, а не «нет скролла» (тот закрыт T-173, третьей проверкой
## адаптивного гейта).
##
## Ожидаемый зум тест считает сам по публичному `field_size()`, а не повторяет
## формулу из `fit_camera`: иначе мутант «забыть множитель» остался бы зелёным
## (проверено батареей mut_battle_fit.sh, M1).

var _original_size := Vector2i(1920, 1080)


func before_test() -> void:
	_original_size = get_tree().root.size


func after_test() -> void:
	super.after_test()
	get_tree().root.size = _original_size
	await get_tree().process_frame


## Бой стартует на уже выставленном вьюпорте: путь обязан быть производственным
## (`BattleController._ready` → `_view.fit_camera()`), а не ручным довызовом.
func _battle_at(res: Vector2i) -> Node:
	get_tree().root.size = res
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	auto_free(battle)
	add_child(battle)
	await await_millis(300)
	return battle


func _view_of(battle: Node) -> BattleView:
	return battle.get_node("BattleView") as BattleView


## Ожидаемый зум считается по layout-размеру вьюпорта (в него и вписывается поле),
## множитель — по высоте реального окна; расщепление то же, что у адаптивного гейта.
func _expected_zoom(view: BattleView, field: Vector2, factor: float) -> float:
	var vp: Vector2 = view.get_viewport().get_visible_rect().size
	return minf(vp.x / field.x, vp.y / field.y) * factor


func test_low_resolution_uses_eighty_percent() -> void:
	assert_float(BattleView.field_fit_scale(720.0)).is_equal(0.8)
	# Пород включителен и монотонен: запас нужен всем меньшим высотам, а не ровно 720.
	assert_float(BattleView.field_fit_scale(600.0)).is_equal(0.8)


func test_above_low_resolution_keeps_tight_fit() -> void:
	assert_float(BattleView.field_fit_scale(1080.0)).is_equal(1.0)
	assert_float(BattleView.field_fit_scale(1440.0)).is_equal(1.0)


func test_camera_at_720p_is_scaled_fit() -> void:
	var battle: Node = await _battle_at(Vector2i(1280, 720))
	var view := _view_of(battle)
	var field: Vector2 = view.field_size()
	assert_bool(field.x > 0.0 and field.y > 0.0).is_true().override_failure_message(
		"поле не залито — проверка ожидаемого зума была бы пустой"
	)
	var cam: Camera2D = view.get_node("Camera")
	var expected := _expected_zoom(view, field, 0.8)
	assert_float(cam.zoom.x).is_equal_approx(expected, 0.001)
	assert_float(cam.zoom.y).is_equal_approx(expected, 0.001)


func test_camera_at_1080p_is_not_scaled() -> void:
	## Множитель не имеет права утечь на Full HD: там плотная вписка — прежнее
	## поведение, и её изменение молча сдвинуло бы все прежние кадры-доказательства.
	var battle: Node = await _battle_at(Vector2i(1920, 1080))
	var view := _view_of(battle)
	var field: Vector2 = view.field_size()
	assert_bool(field.x > 0.0 and field.y > 0.0).is_true().override_failure_message("поле не залито")
	var cam: Camera2D = view.get_node("Camera")
	var expected := _expected_zoom(view, field, 1.0)
	assert_float(cam.zoom.x).is_equal_approx(expected, 0.001)


func test_field_at_720p_leaves_margin_over_hud() -> void:
	## Цель множителя, а не только его значение: нарисованное поле обязано оставить
	## запас по высоте, иначе нижняя панель HUD перекрывает нижний ряд клеток.
	var battle: Node = await _battle_at(Vector2i(1280, 720))
	var view := _view_of(battle)
	var field: Vector2 = view.field_size()
	var cam: Camera2D = view.get_node("Camera")
	# Пересчёт в пиксели окна: layout масштабируется целиком, поэтому доля окна,
	# занятая полем, считается с коэффициентом win_y / layout_y.
	var vp: Vector2 = view.get_viewport().get_visible_rect().size
	var win: Vector2i = view.get_viewport().get_window().size
	var drawn_h: float = field.y * cam.zoom.x * (float(win.y) / vp.y)
	assert_bool(drawn_h <= float(win.y) * 0.85).is_true().override_failure_message(
		"поле занимает %.0f px из %d — нижней строке не хватает места под HUD"
		% [drawn_h, win.y]
	)
