class_name BattleField extends Node2D

## Поле боя — шестигранная сетка (макет `_task_interface`), а не линия.
##
## Боевой логики здесь нет — только связка «экземпляр боя → дорожки на поле»:
## юнит ставится в центр клетки, сторона задаёт разворот, `show_state` проигрывает
## дорожку у всех сразу. Порядок хода и удары приходят из `CombatState` (фаза 8),
## этот слой вызывается ими, а не наоборот.
##
## Клетки — «острая» ориентация (pointy-top) со сдвигом нечётных рядов, как в
## макете: две стороны смотрят друг на друга через середину поля, строй занимает
## три колонки своего фланга. Координата клетки — единственное, что знает поле о
## тактике; дистанции и зоны поражения ядро не считает (мандат демо).

const UNIT_SCENE := "res://scenes/battle_unit.tscn"
## Масштаб кадра на поле: холст 128 px, персонаж в нём ~96 px. Клетка 173×200,
## фигура перекрывает её по высоте в ~1.2 раза — как в макете, где юнит выше
## своего шестиугольника, но не закрывает соседей.
const UNIT_SCALE := 2.2
const HEX_RADIUS := 100.0
const GRID_COLS := 8
const GRID_ROWS := 5
## Центр клетки (0, 0). Середина поля остаётся пустой: стороны не должны
## перекрывать друг друга силуэтами.
const HEX_ORIGIN := Vector2(230.0, 330.0)
## Клетки строя: слот → клетка своего фланга. Фланг противника — те же клетки,
## отражённые по горизонтали, поэтому состав из семи юнитов не требует второй
## таблицы. Семь разных клеток, ряды 0..4: строй читается строем, а не линией.
const FORMATION := [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 1), Vector2i(0, 3),
	Vector2i(1, 2), Vector2i(2, 3), Vector2i(1, 4),
]
## Сколько своих показывать на поле (в бою их семь, для витрины достаточно строя).
const LINE_SIZE := 4
## Цикл показа дорожек для живого прогона (`auto_cycle`).
const SHOWCASE := [&"idle", &"attack", &"hit", &"turn"]
const SHOWCASE_SECONDS := 1.2
const HEX_LINE := Color(0.62, 0.72, 0.86, 0.3)
const HEX_LINE_MID := Color(0.62, 0.72, 0.86, 0.5)

var auto_cycle := true
var _views := {}
var _cells := {}
var _shown := 0
var _elapsed := 0.0


func _ready() -> void:
	if not auto_cycle:
		# Бой (9.3) рассаживает юнитов сам, из `CombatState`.
		return
	var units := DataLibrary.load_units()
	var roster := DataLibrary.load_roster("a")
	for slot in min(LINE_SIZE, roster.units.size()):
		_spawn(roster.units[slot], BattleUnit.SIDE_PLAYER, slot)
	_spawn(units[DataLibrary.ENEMY_ID], BattleUnit.SIDE_ENEMY, 0)


func _process(delta: float) -> void:
	if not auto_cycle:
		return
	_elapsed += delta
	if _elapsed < SHOWCASE_SECONDS:
		return
	_elapsed = 0.0
	_shown = (_shown + 1) % SHOWCASE.size()
	show_state(SHOWCASE[_shown])


## Проигрывает дорожку у всех юнитов поля.
func show_state(state: StringName) -> void:
	for view in _views.values():
		view.play(state)


## Центр клетки сетки. Нечётные ряды сдвинуты на полшага — как в макете.
static func hex_center(col: int, row: int) -> Vector2:
	var step_x := sqrt(3.0) * HEX_RADIUS
	return HEX_ORIGIN + Vector2(
		step_x * (col + 0.5 * (row % 2)), 1.5 * HEX_RADIUS * row
	)


## Клетка слота: свой фланг слева, фланг противника — то же зеркально. Вне
## строя (слота больше, чем клеток) юнит встаёт за последнюю клетку.
static func cell_of_slot(side: int, slot: int) -> Vector2i:
	var cell: Vector2i = FORMATION[mini(slot, FORMATION.size() - 1)]
	if side == BattleUnit.SIDE_PLAYER:
		return cell
	return Vector2i(GRID_COLS - 1 - cell.x, cell.y)


## Контур поля: сетка целиком, средняя линия чуть заметнее — по ней читается
## раздел сторон (в макете середины нет: там она отдана под таймер хода).
func _draw() -> void:
	var shape := PackedVector2Array()
	for step in 6:
		var angle := deg_to_rad(60.0 * step - 30.0)
		shape.append(HEX_RADIUS * Vector2(cos(angle), sin(angle)))
	shape.append(shape[0])
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var center := hex_center(col, row)
			var line := HEX_LINE_MID if col == GRID_COLS / 2 else HEX_LINE
			var points := PackedVector2Array()
			for corner in shape:
				points.append(corner + center)
			draw_polyline(points, line, 2.0, true)


## Картинка юнита по его экземпляру боя (для `CombatState`, а не для витрины).
func spawn(unit: BattleUnit) -> BattleUnitView:
	var view := load(UNIT_SCENE).instantiate() as BattleUnitView
	view.unit = unit
	view.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
	var cell := cell_of_slot(unit.side, unit.slot)
	view.position = hex_center(cell.x, cell.y) + Vector2(0.0, HEX_RADIUS * 0.8)
	# Порядок слоёв — по ряду: юнит дальнего ряда обязан остаться за ближним,
	# порядок спавна (слоты боя) этому не равен.
	view.z_index = cell.y
	add_child(view)
	_views[unit.uid()] = view
	_cells[unit.uid()] = cell
	queue_redraw()
	return view


## Сброс картинок перед новым боем на том же экране (повтор с экрана результата).
func clear_views() -> void:
	for view: BattleUnitView in _views.values():
		view.free()
	_views = {}
	_cells = {}


## Клетка юнита — для тестов рассадки и для подсветки выбранной клетки.
func cell_of(unit: BattleUnit) -> Vector2i:
	return _cells.get(unit.uid(), Vector2i(-1, -1))


## Картинка юнита боя (экрану нужно ставить метку и полосы по позиции).
func view_of(unit: BattleUnit) -> BattleUnitView:
	return _views.get(unit.uid())


## Связка с боевым ядром (задача 8.4): отклик картинки идёт из сигналов, а не из
## опроса состояния. Витрина (`auto_cycle`) гаснет: иначе она переставляет
## дорожки быстрее, чем доходит контактный кадр.
func attach(combat: CombatState) -> void:
	auto_cycle = false
	if not combat.action_performed.is_connected(on_action):
		combat.action_performed.connect(on_action)


## Отклик на выполненное действие: `hit` цели стартует не в момент, когда ядро
## уже начислило урон, а на контактном кадре атакующего. Мёртвая цель на этом же
## кадре гаснет — дорожки гибели нет (D10).
func on_action(action: BattleAction) -> void:
	if action.kind != BattleAction.Kind.ATTACK or action.damage.is_empty():
		return
	var attacker: BattleUnitView = _views.get(action.actor.uid())
	if attacker == null:
		return
	for target in action.targets:
		var victim: BattleUnitView = _views.get(target.uid())
		if victim != null:
			_later(victim, attacker.contact_delay())


func _later(victim: BattleUnitView, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(victim):
		return
	if victim.is_alive():
		victim.play(&"hit")
	else:
		victim.die()


func _spawn(stats: UnitStats, side: int, slot: int) -> void:
	spawn(BattleUnit.new(stats, side, slot))
