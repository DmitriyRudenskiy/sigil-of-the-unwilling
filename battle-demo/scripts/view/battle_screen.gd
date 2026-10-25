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
## Гибель: полоса остаётся пустой (спека), но дорожка не багрянеет — багряная
## полоса на тёмном фоне читалась как залитый HP (read-агент 2026-10-25: «у
## юнита красная полоса при живой позе — мёртвый/раненый/враг неразличимо»,
## «погибший волк несёт над собой красную полосу как живой»). Погибшего метит
## крест поверх пустой полосы: он не похож ни на заполненную полосу, ни на волю.
const DEATH_MARK := "✕"
const DEATH_MARK_COLOR := Color(0.95, 0.32, 0.22)
const DEATH_MARK_FONT := 26
## Полоса противника — кирпичная: зелёная у обеих сторон читалась как «свои»
## (read-агент: «враг-волк справа с зелёной полосой как свои»). Сторона видна
## и по углу поля, но полосу игрок читает быстрее, чем силуэт.
const BAR_FILL_ENEMY := Color(0.74, 0.27, 0.2)
## Подъём полосы над опорами юнита — в масштабе самого юнита (`BAR_LIFT ×
## view.scale.y`), чтобы полоса оставалась над головой при любом `UNIT_SCALE`.
## 120 × 1.1 = 132 px: 123 px фигуры + 8 px зазора спеки (задача 10.10; раньше
## было 100 × 2.2 = 220 px при 246 px фигуры — полоса лежала на корпусе).
const BAR_LIFT := 120.0

var combat: CombatState

var _bars := {}

var _marks := {}

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
		_bars[unit.uid()] = _make_bar(view, unit)
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
	_marks = {}
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
			fill.size.x = maxf(0.0, (BAR_SIZE.x - 2.0) * float(unit.hp) / unit.stats.max_hp)
			(_marks[unit.uid()] as Label).visible = dead
			if dead:
				# Обесцвечивание идёт тем же сигналом, что и полоса: `_process`
				# вьюера догоняет гибель кадром позже, и съёмка кадров ловила
				# цветного погибшего (read-агент 2026-10-25, `b_mid`: «юнит с
				# красным X нарисован тем же непрозрачным спрайтом, что живые»).
				var view: BattleUnitView = field.view_of(unit)
				if view != null:
					view.die()


func _make_bar(view: BattleUnitView, unit: BattleUnit) -> ColorRect:
	var track := ColorRect.new()
	track.color = BAR_TRACK
	track.size = BAR_SIZE
	track.position = view.position + Vector2(
		-BAR_SIZE.x / 2.0, -BAR_LIFT * view.scale.y
	)
	track.z_index = view.z_index
	add_child(track)
	var fill := ColorRect.new()
	fill.color = BAR_FILL if unit.side == BattleUnit.SIDE_PLAYER else BAR_FILL_ENEMY
	fill.position = Vector2(1, 1)
	fill.size = Vector2(BAR_SIZE.x - 2.0, BAR_SIZE.y - 2.0)
	track.add_child(fill)
	var mark := Label.new()
	mark.text = DEATH_MARK
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.position = Vector2(0.0, -11.0)
	mark.size = Vector2(BAR_SIZE.x, BAR_SIZE.y + 22.0)
	mark.add_theme_font_size_override("font_size", DEATH_MARK_FONT)
	mark.add_theme_color_override("font_color", DEATH_MARK_COLOR)
	mark.visible = false
	track.add_child(mark)
	_marks[unit.uid()] = mark
	return fill
