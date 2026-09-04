extends "res://tests/gut_base.gd"
## Smoke-тест CityArenaView: инстанс, палитра, клики по клеткам, ходы.
## Асинхронный (await на кадры и таймер) — GUT поддерживает await в тестах.

var _view: CityArenaView = null


func after_each() -> void:
	if _view != null and is_instance_valid(_view):
		_view.free()
		_view = null


func test_arena_smoke() -> void:
	var view: CityArenaView = CityArenaView.new()
	_view = view
	add_child(view)
	# _ready() отработает на первом кадре — ждём.
	await get_tree().process_frame

	check("city создан (после _ready)", view._city != null)

	# 3 хода для промышленности.
	for i in 3:
		view._on_turn_pressed()
	check("ходов: %d" % view._turn, view._turn == 3)

	# Ферма на свободной клетке кольца 1.
	var farm_cell: Vector2i = _first_free_r1(view)
	view._on_palette_pressed(&"farm")
	view._handle_cell_click(farm_cell)
	check("ферма построена на %s" % str(farm_cell), view._city.cell_is_built(farm_cell))

	# Район на другой клетке кольца 1.
	var d_cell: Vector2i = _first_free_r1(view)
	view._on_palette_pressed(&"district")
	view._handle_cell_click(d_cell)
	check("район построен (boroughs=%d)" % view._city.boroughs.size(), view._city.boroughs.size() == 1)

	# Клик по построенному — попытка апгрейда (должна пройти без ошибок).
	view._on_palette_pressed(&"")
	view._handle_cell_click(farm_cell)

	# Нанять + уровень.
	view._on_hire_pressed()
	view._on_level_pressed()

	# Ещё 10 ходов.
	for i in 10:
		view._on_turn_pressed()
	check("ходов: %d" % view._turn, view._turn == 13)

	# Авто-режим: включить, дождаться тиков, выключить.
	view._on_auto_pressed()
	check("авто включено", view._auto)
	await view._timer.timeout
	await view._timer.timeout
	view._on_auto_pressed()
	check("авто выключено", not view._auto)
	check("авто крутит ходы (turn=%d)" % view._turn, view._turn > 13)

	var score: float = CityArenaModel.score(view._city, view._starve_days)
	check("score вменяемый: %.1f" % score, score > -100.0)


## Клик по клетке через реальный путь сигнала Area2D.input_event (а не через
## _handle_cell_click напрямую): левая кнопка должна дойти до обработчика
## и построить здание / сменить состояние выбора.
func test_cell_click_signal_path() -> void:
	var view: CityArenaView = CityArenaView.new()
	_view = view
	add_child(view)
	await get_tree().process_frame
	check("city создан", view._city != null)

	var cell: Vector2i = _first_free_r1(view)

	# 1) Выбор здания кликом по палитре — состояние меняется.
	view._on_palette_pressed(&"farm")
	check("выбрана ферма (до клика)", view._selected == &"farm")

	# 2) Стреляем левой кнопкой прямо в _on_cell_input (сигнальный путь).
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	view._on_cell_input(view, mb, 0, Vector2.ZERO, Vector2.ZERO, cell)

	check("клик дошёл: ферма построена на %s" % str(cell), view._city.cell_is_built(cell))

	# 3) Повторный клик по построенной клетке — апгрейд без ошибки.
	view._on_cell_input(view, mb, 0, Vector2.ZERO, Vector2.ZERO, cell)
	check("апгрейд прошёл без падения", view._city.cell_is_built(cell))

	# 4) Клик по центру кольца 0 — «это центр города», без построения.
	var center: Vector2i = Vector2i.ZERO
	view._on_palette_pressed(&"farm")
	view._on_cell_input(view, mb, 0, Vector2.ZERO, Vector2.ZERO, center)
	check("центр не строится", not view._city.cell_is_built(center))

	# 5) Пустое событие (не кнопка) — никуда не доходит, ошибок нет.
	var me := InputEventMouseMotion.new()
	view._on_cell_input(view, me, 0, Vector2.ZERO, Vector2.ZERO, cell)
	check("mouse-движение игнорируется", view._city.cell_is_built(cell))


func _first_free_r1(view: CityArenaView) -> Vector2i:
	for cell in CityArenaModel.cells_in_arena():
		var cv: Vector2i = cell
		# Аудит #3: «свободная» = не построена и без рабочего (иначе стройка отклоняется).
		if CityArenaModel.ring_of(cv) == 1 and not view._city.cell_is_built(cv) \
				and not _worker_on(view._city, cv):
			return cv
	return Vector2i.ZERO


func _worker_on(city: City, cv: Vector2i) -> bool:
	for u in city.pop:
		if u.state == PopUnit.State.WORKER and u.tile == cv:
			return true
	return false
