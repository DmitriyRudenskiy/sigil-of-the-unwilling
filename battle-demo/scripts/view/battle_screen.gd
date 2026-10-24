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
const MARKER_SIZE := Vector2(96, 6)
const MARKER_COLOR := Color(0.95, 0.8, 0.35)
## Полоса — над головой: холст 128 px при масштабе 3 даёт юнита ростом ~336 px.
const BAR_LIFT := 350.0

var combat: CombatState

var _bars := {}

@onready var field: BattleField = $Field
@onready var marker: ColorRect = $Marker
@onready var active_label: Label = $ActiveLabel


func _enter_tree() -> void:
	# Витрина выключается до `_ready` поля, иначе линия из данных ростеров
	# разъедется с юнитами боя.
	$Field.auto_cycle = false


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
	combat = built
	field.attach(combat)
	combat.turn_started.connect(_on_turn)
	combat.action_performed.connect(_on_action)
	combat.unit_died.connect(_on_action)
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


func _on_turn(unit: BattleUnit) -> void:
	if unit == null:
		return
	var view: BattleUnitView = field.view_of(unit)
	if view != null:
		marker.visible = true
		marker.position = view.position + Vector2(-MARKER_SIZE.x / 2.0, 8.0)
	active_label.text = unit.stats.display_name


func _refresh_all() -> void:
	for unit in combat.units:
		var fill: ColorRect = _bars.get(unit.uid())
		if fill != null:
			# Мёртвый юнит остаётся с пустой полосой: hp 0 → ширина 0.
			fill.size.x = maxf(0.0, (BAR_SIZE.x - 2.0) * float(unit.hp) / unit.stats.max_hp)


func _make_bar(view: BattleUnitView) -> ColorRect:
	var track := ColorRect.new()
	track.color = BAR_TRACK
	track.size = BAR_SIZE
	track.position = view.position + Vector2(-BAR_SIZE.x / 2.0, -BAR_LIFT)
	add_child(track)
	var fill := ColorRect.new()
	fill.color = BAR_FILL
	fill.position = Vector2(1, 1)
	fill.size = Vector2(BAR_SIZE.x - 2.0, BAR_SIZE.y - 2.0)
	track.add_child(fill)
	return fill
