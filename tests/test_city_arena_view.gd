extends SceneTree
## Smoke-тест CityArenaView: инстанс, палитра, клики по клеткам, ходы.

var _view: CityArenaView = null
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var view: CityArenaView = CityArenaView.new()
	_view = view
	root.add_child(view)
	# _ready() отработает на первом кадре — ждём.
	await process_frame

	check(view._city != null, "city создан (после _ready)")

	# 3 хода для промышленности.
	for i in 3:
		view._on_turn_pressed()
	check(view._turn == 3, "ходов: %d" % view._turn)

	# Ферма на свободной клетке кольца 1.
	var farm_cell: Vector2i = _first_free_r1(view)
	view._on_palette_pressed(&"farm")
	view._handle_cell_click(farm_cell)
	check(view._city.cell_is_built(farm_cell), "ферма построена на %s" % str(farm_cell))

	# Район на другой клетке кольца 1.
	var d_cell: Vector2i = _first_free_r1(view)
	view._on_palette_pressed(&"district")
	view._handle_cell_click(d_cell)
	check(view._city.boroughs.size() == 1, "район построен (boroughs=%d)" % view._city.boroughs.size())

	# Клик по построенному — попытка апгрейда (должна пройти без ошибок).
	view._on_palette_pressed(&"")
	view._handle_cell_click(farm_cell)

	# Нанять + уровень.
	view._on_hire_pressed()
	view._on_level_pressed()

	# Ещё 10 ходов.
	for i in 10:
		view._on_turn_pressed()
	check(view._turn == 13, "ходов: %d" % view._turn)

	# Авто-режим: включить, дождаться тиков, выключить.
	view._on_auto_pressed()
	check(view._auto, "авто включено")
	await view._timer.timeout
	await view._timer.timeout
	view._on_auto_pressed()
	check(not view._auto, "авто выключено")
	check(view._turn > 13, "авто крутит ходы (turn=%d)" % view._turn)

	var score: float = CityArenaModel.score(view._city, view._starve_days)
	print("[arena-view-test] turn=%d buildings=%d boroughs=%d pop=%d score=%.1f" % [
		view._turn, view._city.buildings.size(), view._city.boroughs.size(),
		view._city.pop_total(), score])
	check(score > -100.0, "score вменяемый: %.1f" % score)

	if _failures.is_empty():
		print("[arena-view-test] OK")
		quit(0)
	else:
		for f in _failures:
			printerr("[arena-view-test] FAIL: ", f)
		quit(1)


func _first_free_r1(view: CityArenaView) -> Vector2i:
	for cell in CityArenaModel.cells_in_arena():
		var cv: Vector2i = cell
		if CityArenaModel.ring_of(cv) == 1 and not view._city.cell_is_built(cv):
			return cv
	return Vector2i.ZERO


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
