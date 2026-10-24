class_name BattleField extends Node2D

## Поле боя для привязки анимации (задача 8.2): линия набора A против шторм-мага.
##
## Боевой логики здесь нет — только связка «экземпляр боя → дорожки на поле»:
## юнит ставится в точку пола, сторона задаёт разворот, `show_state` проигрывает
## дорожку у всех сразу. Порядок хода и удары приходят из `CombatState` (фаза 8),
## этот слой вызывается ими, а не наоборот.

const UNIT_SCENE := "res://scenes/battle_unit.tscn"
## Масштаб кадра на поле: холст 128 px, персонаж в нём ~96 px, в бою он должен
## читаться, поэтому линия стоит в ~2×.
const UNIT_SCALE := 3.0
const ROW_Y := 700.0
const PLAYER_X := 320.0
const ENEMY_X := 1560.0
const STEP_X := 230.0
## Сколько своих показывать на поле (в бою их семь, для приёмки достаточно линии).
const LINE_SIZE := 4
## Цикл показа дорожек для живого прогона (`auto_cycle`).
const SHOWCASE := [&"idle", &"attack", &"hit", &"turn"]
const SHOWCASE_SECONDS := 1.2

var auto_cycle := true
var _views: Array[BattleUnitView] = []
var _shown := 0
var _elapsed := 0.0


func _ready() -> void:
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
	for view in _views:
		view.play(state)


func _spawn(stats: UnitStats, side: int, slot: int) -> void:
	var view := load(UNIT_SCENE).instantiate() as BattleUnitView
	view.unit = BattleUnit.new(stats, side, slot)
	view.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
	var offset := slot * STEP_X
	view.position = (
		Vector2(PLAYER_X + offset, ROW_Y)
		if side == BattleUnit.SIDE_PLAYER
		else Vector2(ENEMY_X - offset, ROW_Y)
	)
	add_child(view)
	_views.append(view)
