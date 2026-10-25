class_name BattleScreen extends Node2D

## Экран боя (задача 9.3) с полосами HP (задача 9.4).
##
## Экран — только подписчик: `CombatState` не знает про картинку, а UI не меняет
## модель (спека `battle-demo-ui`, «Синхронность»). Единственный путь — сигналы
## ядра, поэтому рассинхрон ловится тестом, а не кадром: после любого
## `action_performed` полосы перерисовываются в том же кадре.
##
## Очередь ходов, панель способностей и экран результата — следующие задачи
## (9.5–9.7); здесь то, без чего бой не виден: две линии, метка активного юнита
## и его имя.

## Метрики читаемости зафиксированы в `docs/ui-spec.md` (96×10 px, кегль ≥ 24).
const BAR_SIZE := Vector2(96, 10)
const BAR_FILL := Color(0.55, 0.78, 0.42)
const BAR_TRACK := Color(0.12, 0.12, 0.14)
## Дорожка мёртвого юнита (задача 10.11): пустая полоса того же цвета, что и
## у живого на малом hp, отличалась только шириной заполнения — на кадре
## гибель не читалась. Пустая полоса становится багряной.
const BAR_DEAD := Color(0.45, 0.11, 0.11)
## Подъём полосы над опорами юнита — в масштабе самого юнита (`BAR_LIFT ×
## view.scale.y`), чтобы полоса оставалась над головой при любом `UNIT_SCALE`.
## 120 × 1.1 = 132 px: 123 px фигуры + 8 px зазора спеки (задача 10.10; раньше
## было 100 × 2.2 = 220 px при 246 px фигуры — полоса лежала на корпусе).
const BAR_LIFT := 120.0

var combat: CombatState

var _bars := {}

@onready var field: BattleField = $Field
@onready var active_label: Label = $ActiveLabel
@onready var hud: BattleHud = $HUD
@onready var result_view: BattleResult = $Result


func _enter_tree() -> void:
	# Витрина выключается до `_ready` поля, иначе линия из данных ростеров
	# разъедется с юнитами боя.
	$Field.auto_cycle = false


func _ready() -> void:
	# HUD выше слоя результата: затемнение модалки снимало контраст всему
	# интерфейсу (кадр `a_result`), а геометрически модалка с HUD не пересекается.
	hud.layer = result_view.layer + 1
	result_view.replay.connect(
		func() -> void: get_tree().reload_current_scene()
	)
	result_view.change_roster.connect(
		func() -> void:
			get_tree().change_scene_to_file("res://scenes/roster_select.tscn")
	)
	# Экран запускается сам: игрок пришёл сюда с выбора набора, а не из теста.
	if combat == null:
		start_roster(DemoFlow.roster_id)


## Состав из данных — то, что приносит выбор набора (9.2).
func start_roster(id: String, seed_value: int = 1) -> void:
	var units := DataLibrary.load_units()
	var built := CombatState.new()
	built.setup(DataLibrary.load_roster(id), [units[DataLibrary.ENEMY_ID]], seed_value)
	built.start()
	run(built)


## Экземпляр боя до `start()` или после: очередь на момент подписки уже стоит на
## активном юните, поэтому его метка ставится сразу.
func run(built: CombatState) -> void:
	_reset_view()
	combat = built
	field.attach(combat)
	hud.attach(combat)
	combat.turn_started.connect(_on_turn)
	combat.action_performed.connect(_on_action)
	combat.unit_died.connect(_on_action)
	combat.battle_ended.connect(_on_battle_ended)
	for unit in combat.units:
		var view := field.spawn(unit)
		_bars[unit.uid()] = _make_bar(view)
	_refresh_all()
	_on_turn(combat.current)


## Заполнение полосы HP — то, что видит игрок. Тест синхронности (9.8) сверяет с
## моделью именно это значение, а не внутреннее состояние боя.
func bar_of(unit: BattleUnit) -> ColorRect:
	var fill: ColorRect = _bars.get(unit.uid())
	return fill


func _on_action(_action) -> void:
	_refresh_all()


## Исход — только надпись и выходы (задача 9.7). Бой к этому моменту окончен в
## модели, и экран результата ничего не решает: он показывает `combat.result`.
func _on_battle_ended(outcome: int) -> void:
	# Активного юнита после конца боя нет: жёлтая метка и подпись под полем
	# остались бы висящей подсказкой про последнего ходившего (read-агент:
	# «сирота-подпись» на кадре результата).
	field.active_cell = Vector2i(-1, -1)
	field.queue_redraw()
	active_label.text = ""
	result_view.show_outcome(outcome, combat.turn_index)


## Повтор боя на том же экране: старые картинки и полосы снимаются, иначе
## второй `run` оставил бы два набора полос над одними юнитами.
func _reset_view() -> void:
	if combat == null:
		return
	for fill: ColorRect in _bars.values():
		fill.get_parent().free()
	_bars = {}
	field.clear_views()
	field.active_cell = Vector2i(-1, -1)
	field.queue_redraw()
	active_label.text = ""
	result_view.visible = false


func _on_turn(unit: BattleUnit) -> void:
	if unit == null:
		return
	var view: BattleUnitView = field.view_of(unit)
	if view != null:
		# Признак хода — обведённая клетка (задача 10.12). Полоска под ногами,
		# которая была здесь раньше, ушла: на кадре она читалась то ли чужим
		# HP-баром, то ли обрезком грани шестиугольника.
		field.active_cell = field.cell_of(unit)
		field.queue_redraw()
	active_label.text = unit.stats.display_name


func _refresh_all() -> void:
	for unit in combat.units:
		var fill: ColorRect = _bars.get(unit.uid())
		if fill != null:
			# Мёртвый юнит остаётся с пустой полосой: hp 0 → ширина 0.
			var dead := unit.hp <= 0
			fill.get_parent().color = BAR_DEAD if dead else BAR_TRACK
			fill.size.x = maxf(0.0, (BAR_SIZE.x - 2.0) * float(unit.hp) / unit.stats.max_hp)


func _make_bar(view: BattleUnitView) -> ColorRect:
	var track := ColorRect.new()
	track.color = BAR_TRACK
	track.size = BAR_SIZE
	track.position = view.position + Vector2(
		-BAR_SIZE.x / 2.0, -BAR_LIFT * view.scale.y
	)
	track.z_index = view.z_index
	add_child(track)
	var fill := ColorRect.new()
	fill.color = BAR_FILL
	fill.position = Vector2(1, 1)
	fill.size = Vector2(BAR_SIZE.x - 2.0, BAR_SIZE.y - 2.0)
	track.add_child(fill)
	return fill
