class_name BattleHud extends CanvasLayer

## Интерфейс боя по макету (`_task_interface`): панели полководцев по углам,
## полоса состава сверху, счётчик хода в кольце, команды снизу.
##
## Как и остальной слой, HUD — только подписчик: значения берутся из
## `CombatState` в момент сигнала, а нажатие команды уходит тем же путём, что и
## любой ход, — `CombatState.perform` с действием из `legal_actions`. Отдельного
## списка «что можно сделать» здесь нет: панель показывает те действия, которые
## разрешило ядро, и гасит те, для которых ядро дало причину.
##
## Чего в макете нет в демо: уровни юнитов, мана, книга заклинаний, «сдаться» и
## «спасти». Их полос и бейджей здесь нет — элемент без значения за спиной
## врал бы о состоянии.

const PORTRAIT_DIR := "res://assets/portraits"
const PANEL := Color(0.09, 0.08, 0.07, 0.92)
const PANEL_EDGE := Color(0.62, 0.48, 0.24, 1.0)
const HP_FILL := Color(0.36, 0.78, 0.31)
## Полоса врага обязана читаться чужой: зелёная полоса в правом блоке
## (read-отчёт 2026-10-26) рисовала «свой» там, где противник. Тон тот же,
## что у `BattleScreen.BAR_FILL_ENEMY` на поле — глаз читает одну идею в двух
## местах.
const HP_FILL_ENEMY := Color(0.74, 0.27, 0.2)
const HP_TRACK := Color(0.1, 0.11, 0.13, 1.0)
const FOCUS_FILL := Color(0.31, 0.55, 0.86)
const FOCUS_TRACK := Color(0.12, 0.14, 0.18, 1.0)
const GOLD := Color(0.85, 0.68, 0.32)
const TEXT := Color(0.93, 0.9, 0.84)
## Кегль подписей — нижняя граница метрик `docs/ui-spec.md` (≥ 24 px).
const FONT := 24
const FONT_SMALL := 18
const STRIP_CELL := 84.0
## Верх полосы порядка — тёмная полоса над полем; счётчик раунда и подпись
## активного юнита стоят под ней и проверяют зазор этим числом.
const STRIP_TOP := 24.0
const PANEL_SIZE := Vector2(392, 132)
## 264 px — чтобы самое длинное имя способности («Танец кинжалов», кегль 24)
## влезало в пилюлю с полями: на 216 px текст залезал на рамку кнопки
## (read-агент 2026-10-25, `a_start`).
const BUTTON_SIZE := Vector2(264, 64)
const HP_WIDTH := 242.0
const VIEWPORT_WIDTH := 1920.0
## Команды — колонкой в правом поле. Правый край сетки — x 1380 (клетка col 7),
## но фигура в масштабе 1.1 шире клетки и доходит до ~1590, поэтому колонка
## стоит у правого края вьюпорта: строкой внизу и ближе к полю кнопки ложились
## на шестиугольники и на волков (задача 10.13).
## Колонка команд прижата к правому краю: правый край кнопки — 24 px от края
## кадра, поэтому ширина кнопки входит в координату, а не догоняется числом.
const COMMAND_X := VIEWPORT_WIDTH - 24.0 - BUTTON_SIZE.x
const COMMAND_TOP := 300.0
const COMMAND_STEP := 80.0

var combat: CombatState
var commands := Control.new()
var reason := Label.new()
var _counter: Control
var _left := {}
var _right := {}
var _strip := {}
var _ring := Label.new()
## Кнопки команд по id: пересборка панели идёт из сигнала кнопки, поэтому старые
## узлы снимаются `queue_free` (free() внутри собственного `pressed` — locked
## object), а поиск идёт по словарю, а не по дереву.
var _buttons := {}


func _ready() -> void:
	layer = 10
	add_child(_hero_panel(Vector2(24, 24), _left))
	add_child(_hero_panel(Vector2(VIEWPORT_WIDTH - 24.0 - PANEL_SIZE.x, 24), _right, true))
	add_child(_round_counter())
	commands.name = "Commands"
	add_child(commands)
	reason.add_theme_font_size_override("font_size", FONT_SMALL)
	reason.add_theme_color_override("font_color", GOLD)
	reason.position = Vector2(1596.0, COMMAND_TOP + 6.0 * COMMAND_STEP)
	reason.size = Vector2(300.0, 26.0)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(reason)


## Связка с ядром: однократная подписка на все сигналы состояния.
func attach(built: CombatState) -> void:
	combat = built
	combat.turn_started.connect(refresh)
	combat.action_performed.connect(refresh)
	combat.unit_died.connect(refresh)
	combat.battle_ended.connect(refresh)
	refresh()


## --- значения для проверок ------------------------------------------------

## Число карточек в полосе состава — по одной на юнита боя.
func strip_count() -> int:
	return _strip.size()


## Сколько ячеек воли закрашено в левой панели (полоса «маны» в макете).
func active_focus_pips() -> int:
	var filled := 0
	for pip in _left["pips"].get_children():
		if pip.color == FOCUS_FILL:
			filled += 1
	return filled


## Номер хода в кольце.
func round_number() -> int:
	return int(_ring.text)


## Подпись панели полководца стороны. После конца боя на ней остаётся поверженный
## противник, а не прочерк: панель без имени — это потерянное значение.
func commander_name(side: int) -> String:
	return String(_store(side)["title"].text)


## Строка HP панели полководца стороны ("0 / 400 · почин 60").
func commander_note(side: int) -> String:
	return String(_store(side)["note"].text)


## Цвет заполнения полосы HP стороны: своим — зелёный, чужим — ржавый.
func commander_hp_color(side: int) -> Color:
	return (_store(side)["hp"] as ColorRect).color


## Сколько ячеек воли закрашено в панели полководца стороны.
func commander_focus_pips(side: int) -> int:
	var filled := 0
	for pip in _store(side)["pips"].get_children():
		if pip.color == FOCUS_FILL:
			filled += 1
	return filled


func _store(side: int) -> Dictionary:
	return _left if side == BattleUnit.SIDE_PLAYER else _right


## Команда в панели активна? (кулдаун и нехватка воли гасят кнопку).
func command_enabled(ability_id: StringName) -> bool:
	var button := command(ability_id)
	return button != null and not button.disabled


## Сколько команд в панели (после конца боя — ноль, см. `_clear_commands`).
func command_count() -> int:
	return _buttons.size()


## Причина, по которой команда погашена (метрика спеки: «подпись причины»).
func command_reason(ability_id: StringName) -> String:
	var button := command(ability_id)
	return String(button.get_meta("reason", "")) if button != null else "нет команды"


## --- сборка ---------------------------------------------------------------

func _hero_panel(at: Vector2, store: Dictionary, mirrored := false) -> Control:
	var panel := Panel.new()
	panel.position = at
	panel.size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _style(PANEL, 12.0, PANEL_EDGE))
	var portrait := _portrait(&"", 108.0)
	portrait.position = Vector2(12, 12) if not mirrored else Vector2(PANEL_SIZE.x - 120, 12)
	panel.add_child(portrait)
	var title := _label(FONT, TEXT)
	title.position = Vector2(132, 12) if not mirrored else Vector2(12, 12)
	title.size = Vector2(PANEL_SIZE.x - 144, 32)
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if not mirrored else HORIZONTAL_ALIGNMENT_RIGHT
	)
	panel.add_child(title)
	var track := _rect(Vector2(HP_WIDTH + 2, 14), HP_TRACK)
	track.position = Vector2(132, 54) if not mirrored else Vector2(15, 54)
	panel.add_child(track)
	var fill := _rect(Vector2(HP_WIDTH, 12), HP_FILL if not mirrored else HP_FILL_ENEMY)
	fill.position = Vector2(133, 55) if not mirrored else Vector2(16, 55)
	panel.add_child(fill)
	var pips := Control.new()
	pips.position = Vector2(132, 78) if not mirrored else Vector2(16, 78)
	panel.add_child(pips)
	var note := _label(FONT_SMALL, GOLD)
	note.position = Vector2(132, 100) if not mirrored else Vector2(16, 100)
	note.size = Vector2(HP_WIDTH + 2, 24)
	note.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if not mirrored else HORIZONTAL_ALIGNMENT_RIGHT
	)
	panel.add_child(note)
	store.merge({
		"portrait": portrait, "title": title, "hp": fill, "pips": pips, "note": note,
		"unit": null,
	})
	return panel


## Круг счётчика раунда. Полоса порядка занимает y 24..108, верхняя вершина
## верхнего ряда гексов — y 230: круг в 96 px встаёт в зазор между ними
## (122..218). Раньше он стоял на 150 и налезал на сетку (read-агент 2026-10-25:
## «круг счётчика перекрывает верхний ряд гексов»). Круг держим в коде, а не
## в макете: его размер — часть проверки «не лезет на поле».
func _round_counter() -> Control:
	var holder := Panel.new()
	holder.position = Vector2(VIEWPORT_WIDTH / 2.0 - 48.0, 122.0)
	holder.size = Vector2(96, 96)
	var style := _style(Color(0.12, 0.1, 0.06, 0.95), 48.0, GOLD)
	style.set_border_width_all(3)
	holder.add_theme_stylebox_override("panel", style)
	_ring.position = Vector2.ZERO
	_ring.size = holder.size
	_ring.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ring.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ring.add_theme_font_size_override("font_size", 44)
	_ring.add_theme_color_override("font_color", GOLD)
	holder.add_child(_ring)
	_counter = holder
	return holder


## Прямоугольник счётчика — тесту сверять его с верхом поля, а не пиксели.
func counter_rect() -> Rect2:
	return _counter.get_rect()


## Команды активного юнита: базовая атака, его способности и «Ждать». Состав и
## доступность — из `legal_actions`/`ability_state`, чтобы панель не могла
## разойтись с ядром.
func _commands_for(unit: BattleUnit) -> void:
	for child in commands.get_children():
		child.queue_free()
	_buttons = {}
	var legal: Array[BattleAction] = combat.legal_actions(unit)
	var at := Vector2(COMMAND_X, COMMAND_TOP)
	if not legal.is_empty():
		_command_button("Атака", &"", at, _attack_action(legal), "")
		at.y += COMMAND_STEP
		for ability in unit.stats.abilities:
			var state := combat.ability_state(unit, ability)
			var action := _ability_action(legal, ability.id)
			_command_button(
				ability.display_name, ability.id, at, action,
				"" if state == &"ready" else _reason_of(state)
			)
			at.y += COMMAND_STEP
	_command_button("Ждать", &"__wait", at, _skip_action(legal), "")
	at.y += COMMAND_STEP
	var menu := _button("Меню", &"__menu", at)
	menu.pressed.connect(
		func() -> void: get_tree().change_scene_to_file(DemoFlow.ROSTER_SCENE)
	)
	commands.add_child(menu)


func _command_button(label: String, id: StringName, at: Vector2, action, reason: String) -> void:
	var button := _button(label, id, at)
	button.disabled = action == null
	button.set_meta("reason", reason)
	if action != null:
		button.pressed.connect(func() -> void: combat.perform(action))
	commands.add_child(button)


func _button(label: String, id: StringName, at: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.position = at
	button.size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", FONT)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(PANEL, 30.0, PANEL_EDGE))
	button.add_theme_stylebox_override("hover", _style(PANEL, 30.0, GOLD))
	button.add_theme_stylebox_override(
		"pressed", _style(Color(0.16, 0.13, 0.09, 1.0), 30.0, GOLD)
	)
	button.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.07, 0.07, 0.9), 30.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.5))
	if id != &"":
		_buttons[String(id)] = button
	return button


## --- обновление -----------------------------------------------------------

func refresh(_x = null) -> void:
	if combat == null:
		return
	var actor := combat.current
	var foes: Array[BattleUnit] = combat.foes_of(actor) if actor != null else []
	if foes.is_empty():
		# На победе живых противников нет, а панель полководца обязана остаться
		# с именем и нулём HP: `foes_of` считает живых, поверженного берём из
		# полного списка стороны.
		for unit in combat.units:
			if unit.side == BattleUnit.SIDE_ENEMY:
				foes.append(unit)
	_fill_panel(_left, actor)
	_fill_panel(_right, foes[0] if not foes.is_empty() else null)
	# Номер играемого хода, а не следующего: кольцо обновляется на `turn_started`
	# уже после `turn_index += 1`, и `+ 1` рисовал «22» над результатом
	# «Ходов: 21» (read-отчёт 2026-10-26). До первого хода — единица.
	_ring.text = str(maxi(combat.turn_index, 1))
	_refresh_strip()
	if actor != null and not combat.finished:
		_commands_for(actor)
		reason.text = ""
		reason.visible = true
	else:
		# После конца боя команд нет: `CombatState.perform` на финише
		# утверждает, поэтому висящая кнопка была бы падением, а не ходом.
		# Подпись «бой окончен» — тоже сирота: исход объявляет экран
		# результата, а одинокая надпись у правого края без своих кнопок
		# читается как обрезок панели (read-агент 2026-10-25, `b_result`).
		_clear_commands()
		reason.text = ""
		reason.visible = false


func _clear_commands() -> void:
	for child in commands.get_children():
		child.queue_free()
	_buttons = {}


func _fill_panel(store: Dictionary, unit: BattleUnit) -> void:
	store["unit"] = unit
	store["title"].text = unit.stats.display_name if unit != null else "—"
	store["portrait"].texture = _texture(unit.stats.id) if unit != null else null
	(store["hp"] as ColorRect).size.x = (
		HP_WIDTH * clampf(float(unit.hp) / unit.max_hp(), 0.0, 1.0) if unit != null else 0.0
	)
	_set_pips(store["pips"], unit)
	store["note"].text = (
		"%d / %d · почин %d" % [unit.hp, unit.max_hp(), unit.stats.initiative]
		if unit != null
		else ""
	)


func _set_pips(holder: Control, unit: BattleUnit) -> void:
	for child in holder.get_children():
		child.free()
	if unit == null:
		return
	for pip in BattleUnit.FOCUS_MAX:
		# Воля есть только у живого: залитые пипсы поверженного полководца
		# читались как «у него ещё есть ресурс» (кадр `a_result`).
		var lit := pip < unit.focus and unit.is_alive()
		var rect := _rect(Vector2(26, 14), FOCUS_FILL if lit else FOCUS_TRACK)
		rect.position = Vector2(pip * 32.0, 0.0)
		holder.add_child(rect)


func _refresh_strip() -> void:
	for cell in _strip.values():
		cell["root"].free()
	_strip = {}
	var units: Array = []
	for unit in combat.order:
		# Погибшие из очереди уходят (спека 9.5): карточка мёртвого юнита
		# в полосе порядка врала бы о том, кто ещё ходит.
		if unit.is_alive():
			units.append(unit)
	var at := Vector2(VIEWPORT_WIDTH / 2.0 - units.size() * STRIP_CELL / 2.0, STRIP_TOP)
	for index in units.size():
		var unit: BattleUnit = units[index]
		var root := Panel.new()
		root.position = at + Vector2(index * STRIP_CELL, 0.0)
		root.size = Vector2(STRIP_CELL - 8, STRIP_CELL)
		root.add_theme_stylebox_override(
			"panel",
			_style(PANEL, 8.0, GOLD if unit == combat.current else PANEL_EDGE)
		)
		var portrait := _portrait(unit.stats.id, STRIP_CELL - 20.0)
		portrait.position = Vector2(6, 6)
		root.add_child(portrait)
		var track := _rect(Vector2(STRIP_CELL - 20, 5), HP_TRACK)
		track.position = Vector2(6, STRIP_CELL - 12)
		root.add_child(track)
		var fill := _rect(
			Vector2((STRIP_CELL - 22) * clampf(unit.hp_fraction(), 0.0, 1.0), 3),
			HP_FILL if unit.side == BattleUnit.SIDE_PLAYER else HP_FILL_ENEMY
		)
		fill.position = Vector2(7, STRIP_CELL - 11)
		root.add_child(fill)
		add_child(root)
		_strip[unit.uid()] = {"root": root, "hp": fill, "unit": unit}


## Карточка текущего юнита обведена золотым (`GOLD`), у остальных — `PANEL_EDGE`.
## Возвращает uid помеченной карточки: отметка сверяется с `combat.current`,
## а не с порядком отрисовки (спека «очередь с отметкой текущего»; в отчёте
## `ui-review-2026-10-25.md` этот тест заявлен, но написан не был).
func marked_card_uid() -> String:
	for uid: String in _strip:
		var style := (_strip[uid]["root"] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		if style != null and style.border_color.is_equal_approx(GOLD):
			return uid
	return ""


## --- мелочь ---------------------------------------------------------------

## Кнопка команды по id способности (`&""` — базовая атака).
func command(id: StringName) -> Button:
	return _buttons.get(String(id))


func _attack_action(legal: Array[BattleAction]) -> BattleAction:
	var best: BattleAction = null
	for action in legal:
		if action.kind == BattleAction.Kind.ATTACK and (
			best == null or action.targets[0].hp < best.targets[0].hp
		):
			best = action
	return best


func _ability_action(legal: Array[BattleAction], id: StringName) -> BattleAction:
	for action in legal:
		if action.kind == BattleAction.Kind.ABILITY and action.ability.id == id:
			return action
	return null


func _skip_action(legal: Array[BattleAction]) -> BattleAction:
	for action in legal:
		if action.kind == BattleAction.Kind.PASS:
			return action
	return null


func _reason_of(state: StringName) -> String:
	return {
		&"cost": "мало воли",
		&"cooldown": "перезарядка",
		&"no_target": "нет целей",
		&"stun": "оглушён",
	}.get(state, String(state))


func _texture(id: StringName) -> Texture2D:
	var path := "%s/%s.png" % [PORTRAIT_DIR, id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _portrait(id: StringName, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.texture = _texture(id)
	return rect


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _rect(size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.color = color
	return rect


func _style(color: Color, radius: float, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.set_border_width_all(2 if border.a > 0.0 else 0)
	style.border_color = border
	return style
