class_name BattleUI
extends CanvasLayer

const THEME_PATH := "res://assets/theme/game_theme.tres"
const HERO_PORTRAIT_PATH := "res://assets/ui/hero/portrait.png"

signal retreat_requested
signal rescue_requested
signal auto_battle_requested
signal cancel_requested
signal wait_requested
signal attack_mode_requested
signal skip_requested
signal defend_requested
signal spellbook_requested
signal spell_chosen(spell_id: StringName)
signal spellbook_opened
signal spellbook_closed
signal settings_requested
signal settings_closed
signal result_accepted

static var _hero_portrait: Texture2D = null

# Макет 11: нижний ряд — два кластера медальонов без плиты. Слева — отступление
# и спасение, справа — боевые команды. Путь узла меняется вместе с составом
# кластеров, поэтому он здесь и обязан совпадать со сценой.
@onready var _bottom_bar: Control = $bottom_bar
## T-220: полосы, чья геометрия отъедает вертикаль поля боя (носитель числа — сцена).
@onready var _hero_cards_band: Control = $hero_cards
# D-294: Опции и Спасение — некоманды ряда (оверлей настроек и пункт диалога
# выхода), их кнопок в полосе нет; ссылки сняты вместе с узлами в `_ready`.
@onready var _retreat_btn: Button = $"bottom_bar/bar_box/left_box/retreat_btn"
var _rescue_text: String = "Спасение"
@onready var _auto_btn: Button = $"bottom_bar/bar_box/left_box/auto_btn"
@onready var _wait_btn: Button = $"bottom_bar/bar_box/right_box/wait_btn"
@onready var _attack_button: Button = $"bottom_bar/bar_box/right_box/attack_btn"
@onready var _log_line: Label = $"bottom_bar/info_box/log_row/log_line"
# ☰ — вход в историю боя (вторая — клавиша H), видна с первой записи лога.
@onready var _history_btn: Button = $"bottom_bar/info_box/log_row/history_btn"
@onready var _defend_btn: Button = $"bottom_bar/bar_box/right_box/defend_btn"
@onready var _skip_btn: Button = $"bottom_bar/bar_box/right_box/skip_btn"
@onready var _spellbook_btn: Button = $"bottom_bar/bar_box/right_box/spellbook_btn"
@onready var _cancel_btn: Button = $"bottom_bar/bar_box/right_box/cancel_btn"
# ▲▼ окна сообщений (4.2): макет 11 их снимал в пользу клавиш ↑/↓, описание
# владельца вернуло стрелки в центр панели.
@onready var _log_up_btn: Button = $"bottom_bar/info_box/log_row/log_up_btn"
@onready var _log_down_btn: Button = $"bottom_bar/info_box/log_row/log_down_btn"
@onready var _history_panel: PanelContainer = $history_panel
@onready var _history_list: ItemList = $"history_panel/history_list"
@onready var _hero_left: Control = $hero_cards/hero_left
@onready var _hero_right: Control = $hero_cards/hero_right
@onready var _target_card: PanelContainer = $target_card
@onready var _tc_name: Label = $"target_card/tc_box/tc_name"
@onready var _tc_caption: Label = $"target_card/tc_box/tc_caption"
@onready var _tc_count: Label = $"target_card/tc_box/tc_count_row/tc_count"
@onready var _tc_count_row: HBoxContainer = $"target_card/tc_box/tc_count_row"
@onready var _tc_hp: Label = $"target_card/tc_box/tc_hp_row/tc_hp"
@onready var _tc_def: Label = $"target_card/tc_box/tc_def_row/tc_def"
@onready var _tc_luck_row: HBoxContainer = $"target_card/tc_box/tc_luck_row"
@onready var _tc_luck: Label = $"target_card/tc_box/tc_luck_row/tc_luck"
@onready var _tc_atk_row: HBoxContainer = $"target_card/tc_box/tc_atk_row"
@onready var _tc_atk: Label = $"target_card/tc_box/tc_atk_row/tc_atk"
@onready var _tc_preview: Label = $"target_card/tc_box/tc_preview"
@onready var _tc_abilities: Label = $"target_card/tc_box/tc_abilities"
@onready var _end_overlay: PanelContainer = $end_overlay
@onready var _end_title: Label = $"end_overlay/end_center/end_box/end_title"
@onready var _end_numbers: Label = $"end_overlay/end_center/end_box/end_info_row/end_numbers"
@onready var _continue_btn: Button = $"end_overlay/end_center/end_box/continue_btn"
var _action_buttons: Array[Button] = []
@onready var _settings_screen: SettingsScreen = $SettingsScreen
@onready var _spellbook_panel: BattleSpellbookPanel = $BattleSpellbookPanel

## Состояние медальона — модуляцией всей кнопки: под непрозрачной пластиной
## медальона стейтбокс не виден, а неактивный медальон обязан читаться, а не
## исчезать без следа.
##
## Альфа 2.9 — не опечатка: отключённую кнопку движок рисует иконкой с гашением
## (~0.35), и на светлом поле медуальон становился призраком — «команды нет», а
## не «команда недоступна» (кадр 4.6, α 0.4 и α 1 давали один и тот же кадр:
## `font_disabled_color` варианта на это гашение не влияет). Множитель возвращает
## пластине непрозрачность, а признаком неактивности служит затемнение цвета.
const _MEDALLION_DIM := Color(0.45, 0.42, 0.38, 2.9)
const _MEDALLION_HOVER := Color(1.18, 1.12, 0.96, 1)
var _theme: Theme = null
var _history: Array[String] = []
var _history_pos := 0

## Команда ↔ клавиша. Единственный носитель соответствия: из той же таблицы
## печатаются подсказки у медальонов (4.5 — «подпись и горячая клавиша»), поэтому
## подпись не может разойтись с реальной клавишей. H/↑/↓ не здесь: у истории нет
## медальона, вход в неё — ☰ и клавиша.
var _hotkeys: Dictionary = {}
var _hero_refs: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_theme = load(THEME_PATH)
	_apply_theme()
	_connect_skeleton()
	if not _history_btn.pressed.is_connected(_on_history_toggle):
		_history_btn.pressed.connect(_on_history_toggle)
	if not _spellbook_panel.spell_chosen.is_connected(_on_spellbook_chosen):
		_spellbook_panel.spell_chosen.connect(_on_spellbook_chosen)
	_continue_btn.pressed.connect(func() -> void: result_accepted.emit())

func _unhandled_input(event: InputEvent) -> void:
	# F: единственный выход — «Продолжить»; Enter/Space/F подтверждают его же
	if _end_overlay.visible:
		if event.is_action_pressed("ui_accept") or _key(event, KEY_F):
			_continue_btn.emit_signal("pressed")
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# §5: Esc — приоритет: открытая панель → закрыть, иначе «Отмена» (4.3: Esc
	# перешёл с настроек на отмену, настройки — на `O`).
	if event.keycode == KEY_ESCAPE:
		if _spellbook_panel.visible:
			_spellbook_panel.visible = false
		elif _history_panel.visible:
			_history_panel.visible = false
		elif _settings_screen.visible:
			_settings_screen.visible = false
		else:
			_press(_cancel_btn)
		get_viewport().set_input_as_handled()
		return
	if _settings_screen.visible:
		return
	# Хоткеи панели (4.3, описание владельца): `O` опции, `C` отступить, `A`
	# автобой, `W` ждать, `D` защищаться, `Esc` отмена. Клавиши, которых в списке
	# нет, оставлены: `S` пропуск, `K` книга, `H` история, ↑/↓ журнал. «Атака»
	# уступила `A` автобою и переехала на `T` — прежний палец на `A` не должен
	# отдавать бой эмулятору.
	if _hotkeys.has(event.keycode):
		_press(_hotkeys[event.keycode])
	elif event.keycode == KEY_J:
		_on_history_toggle()
	elif event.keycode == KEY_UP:
		_on_history_up()
	elif event.keycode == KEY_DOWN:
		_on_history_down()
	else:
		return
	get_viewport().set_input_as_handled()


## Хоткеи идут через кнопку, а не через `_on_*`: `disabled` — единственное место,
## где команда считается доступной для текущего юнита и фазы, и прямой вызов
## обработчика его обходил (4.3: «недоступная команда не изменяет состояние
## боя»). Побочный эффект тот, что требует спека: путь клавиши и путь мыши —
## один путь.
func _press(btn: Button) -> void:
	if btn == null or btn.disabled:
		return
	btn.emit_signal("pressed")


static func _key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode

func _apply_theme() -> void:
	if _theme == null:
		return
	theme_root_theme(_theme)

## CanvasLayer не Control — тему вешаем на корневые контролы слоя.
func theme_root_theme(t: Theme) -> void:
	for c in ["bottom_bar", "target_card", "end_overlay", "history_panel"]:
		get_node(NodePath(c)).theme = t
	# Носитель плит — тема, а не код. В game_theme.tres нет носителя для
	# PanelContainer, поэтому раньше сюда клался `Panel/styles/panel`
	# через add_theme_stylebox_override — а переопределение узла сильнее темы,
	# так что кит шага 4 на этих двух панелях не мог проявиться ни при каком
	# изменении темы (T-147). Приём тот же, что у ячеек инициативы
	# (PanelCard/PanelActive/PanelDead): узел переводится на вариант темы, и
	# StyleBoxTexture_panel (9-slice panel_bg.png) резолвится сам.
	# Вариант — именно PanelPlate, а не «Panel»: незарегистрированный тип движок
	# не резолвит (замер — test_battle_theme_carrier.gd), а «Panel» в теме —
	# мешок стилей, к которому код обращается по имени, а не тип виджета.
	# Плита нижней панели макетом снята: медальоны лежат на поле. Носитель
	# остаётся только у панели истории (она по-прежнему плита).
	_history_panel.theme_type_variation = &"PanelPlate"

func _connect_skeleton() -> void:
	_action_buttons = [
		_retreat_btn, _auto_btn, _wait_btn, _attack_button,
		_defend_btn, _skip_btn, _cancel_btn,
	]
	_retreat_btn.pressed.connect(_on_retreat)
	# Раскладка ряда применяется отложенно: в `_ready` узел ещё настраивает
	# детей, и перенос ребёнка в этот момент движок отклоняет.
	call_deferred("_apply_command_row")
	_auto_btn.pressed.connect(_on_auto_battle)
	_cancel_btn.pressed.connect(_on_cancel)
	_log_up_btn.pressed.connect(_on_history_up)
	_log_down_btn.pressed.connect(_on_history_down)
	_wait_btn.pressed.connect(_on_wait)
	_attack_button.pressed.connect(_on_attack_mode)
	_defend_btn.pressed.connect(_on_defend)
	_skip_btn.pressed.connect(_on_skip)
	_spellbook_btn.pressed.connect(_on_spellbook)
	_retreat_btn.pressed.disconnect(_on_retreat)
	_retreat_btn.pressed.connect(_on_exit_dialog)
	_attack_button.disabled = true
	# Клавиши и подписи медальонов — из одной таблицы (см. `_hotkeys`).
	_hotkeys = {
		# D-294: хоткеи дублируют кнопки ряда; у Атаки хоткея нет (цель — клик).
		KEY_A: _auto_btn, KEY_W: _wait_btn, KEY_S: _skip_btn,
		KEY_D: _defend_btn, KEY_B: _spellbook_btn,
		KEY_C: get_node_or_null("bottom_bar/bar_box/right_box/cancel_btn"),
	}
	for key: int in _hotkeys:
		var btn: Button = _hotkeys[key]
		var caption: Label = btn.get_node_or_null("caption")
		# D-293 (7.1): медальон несёт только знак. Подпись остаётся в сцене
		# носителем имени команды — его же читает подсказка, — но на кадр больше не
		# выводится: имя и клавиша живут во всплывающей подсказке.
		if caption != null:
			btn.tooltip_text = "%s (%s)" % [caption.text, OS.get_keycode_string(key)]
			caption.visible = false
		btn.mouse_entered.connect(_on_medallion_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_medallion_hover.bind(btn, false))


func _on_medallion_hover(btn: Button, hovered: bool) -> void:
	if hovered:
		btn.set_meta("hover", true)
	else:
		btn.remove_meta("hover")
	_medallion_state(btn)


## Состояние медальона видно без стейтбокса: неактивный гаснет, наведённый чуть
## светится. Прежняя обратная связь шла стейтбоксом темы, но пластина медальона
## лежит поверх неё и скрывает и наведение, и отключение.
func _medallion_state(btn: Button) -> void:
	if btn.disabled:
		btn.self_modulate = _MEDALLION_DIM
	elif btn.has_meta("hover"):
		btn.self_modulate = _MEDALLION_HOVER
	else:
		btn.self_modulate = Color(1, 1, 1, 1)

func set_status(text: String) -> void:
	_history.append(text)
	if _history.size() > 50:
		_history.pop_front()
	_history_pos = _history.size() - 1
	_log_line.text = text
	# ☰ макет 11 не несёт отдельной кнопки истории: она просыпается вместе с
	# первой записью лога, а до первой записи в полосе нечего смотреть.
	_history_btn.visible = true

func set_attack_preview(text: String) -> void:
	# B: предпросмотр урона — error-chip (лёгальная подложка #281c0f, docs/14 §2)
	_tc_preview.text = text
	_tc_preview.visible = text != ""

func show_target_card(unit: BattleState.BattleUnit, caption: String = "Цель") -> void:
	# B (M1): только live-поля; строка без источника — скрыта, фейковых чисел нет
	if unit == null:
		hide_target_card()
		return
	_tc_caption.text = caption
	_tc_name.text = unit.get_display_name()
	var count: int = unit.get_count()
	_tc_count_row.visible = count > 1
	_tc_count.text = str(count)
	if unit.is_dnd_character() and unit.dnd_profile != null:
		_tc_hp.text = "%d / %d" % [unit.get_hp(), unit.dnd_profile.max_hp]
	else:
		_tc_hp.text = str(unit.get_hp())
	var defense: int = unit.get_defense()
	_tc_def.text = str(defense)
	_tc_def.visible = defense > 0
	## T-221 (D-268): Удача — только при наличии носителя; «0 без источника» было бы
	## выдуманным числом, M1 это прямо запрещает.
	_tc_luck_row.visible = unit.has_luck()
	if unit.has_luck():
		_tc_luck.text = "%+d" % unit.luck
	var atk: int = unit.dnd_profile.get_attack_bonus() if unit.dnd_profile != null else 0
	_tc_atk_row.visible = unit.dnd_profile != null
	_tc_atk.text = "+%d" % atk
	# способности — строго по data-source: dnd-профиль (live) → шесть очков
	# способностей; иконок 32 px нет (absent) → моно-строка, тикет на иконки.
	var ab: DNDAbilityScores = unit.dnd_profile.abilities if unit.dnd_profile != null else null
	_tc_abilities.visible = ab != null
	if ab != null:
		var A := DNDAbilityScores.Ability
		_tc_abilities.text = "СИЛ %d · ЛОВ %d · ТЕЛ %d ·\nИНТ %d · МДР %d · ХАР %d" % [
			ab.get_score(A.STR), ab.get_score(A.DEX), ab.get_score(A.CON),
			ab.get_score(A.INT), ab.get_score(A.WIS), ab.get_score(A.CHA),
		]
	_target_card.visible = true

func hide_target_card() -> void:
	_target_card.visible = false


## 4.1 (M1): «AC/HP/способность видны всегда». Подпись «Противник» вместо «Цель»,
## пока игрок не нацелился: карточка показывает текущего живого врага, а не пустоту.
## Строка Удача в ней сознательно нет — источника удачи в бою не существует
## (`BattleRules.resolve_ladder(luck_mod)` никто не вызывает с ненулевым значением),
## а M1 запрещает показывать число без носителя.
func show_default_enemy_card(state: BattleState) -> void:
	if state == null:
		hide_target_card()
		return
	for unit in state.defender_units:
		if unit != null and unit.alive:
			show_target_card(unit, "Противник")
			return
	hide_target_card()

# F: финал боя — единственный выход «Продолжить» (docs/14 §4.F); потери — моно
# (числа отделены от подписи: end_info serif + end_numbers LabelNumber).
func show_result(winner: int, surviving_atk: int, surviving_def: int) -> void:
	_end_title.text = "Победа" if winner == BattleState.Side.ATTACKER else "Поражение"
	_end_numbers.text = "%d / %d" % [surviving_atk, surviving_def]
	_end_overlay.visible = true
	_continue_btn.grab_focus()

func set_controls_enabled(enabled: bool) -> void:
	for btn in _action_buttons:
		# инвариант 07-ui-ux:53 — «Пропустить» доступен всегда; request_skip()
		# уже защищён фазой WAITING_INPUT (battle_turn_executor.gd:279)
		if btn == _skip_btn:
			continue
		btn.disabled = not enabled
		_medallion_state(btn)

	if _attack_button != null and not enabled:
		_attack_button.disabled = true

func set_attack_enabled(enabled: bool) -> void:
	if _attack_button != null:
		_attack_button.disabled = not enabled

func _on_spellbook_chosen(id: StringName) -> void:
	close_spellbook()
	spell_chosen.emit(id)

func close_spellbook() -> void:
	if _spellbook_panel != null and _spellbook_panel.visible:
		_spellbook_panel.visible = false
		spellbook_closed.emit()

## Диалог выхода из боя (D-294): «Отступить» открывает выбор вместо мгновенного
## отступа, «Спасение» — пункт диалога, «Сдаться» — до T-282 неактивно.
func _on_exit_dialog() -> void:
	var dlg: AcceptDialog = AcceptDialog.new()
	dlg.title = "Выйти из боя?"
	var row: HBoxContainer = HBoxContainer.new()
	for spec: Array in [["Отступить", _on_retreat, true], [_rescue_text, _on_rescue, true],
			["Сдаться", _on_surrender_placeholder, false]]:
		# ponytail: строка «Сдаться» поедет в locale вместе с T-282.
		var b: Button = Button.new()
		b.text = String(spec[0])
		b.disabled = not bool(spec[2])
		b.pressed.connect(Callable(spec[1]))
		row.add_child(b)
	dlg.add_child(row)
	add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered()


func _on_surrender_placeholder() -> void:
	pass  # механики капитуляции нет; пункт неактивен (T-282).


func _on_retreat() -> void:
	retreat_requested.emit()

func _on_rescue() -> void:
	rescue_requested.emit()


# «Автобой» (4.2): кнопка и сигнал. Передача на эмулятор с подтверждением —
# группа 5 этого же change (`BattleEmulator.run_auto_battle`); носитель механики
# есть уже сейчас, поэтому команда рисуется, а не ждёт своей группы.
func _on_auto_battle() -> void:
	auto_battle_requested.emit()


func _on_cancel() -> void:
	cancel_requested.emit()


# --- Карточки героев (макет, шаг 5.2) ------------------------------------
# Герой — боец стороны (`HeroController.get_hero_battle_stack`, ключ `hero`),
# поэтому имя, портрет и HP читаются из его `BattleUnit`, а текущее HP пишет
# обратно сам бой (`world_battle_coordinator.set_combat_hp`). Мана — `HeroMagic`,
# она есть только у своей стороны: у вражеской карточки полоса маны скрыта.
# Героя в бою может не быть (армия без командира) — карточка скрыта целиком:
# нулей вместо данных нет (docs/14 §3).



func update_hero_cards(state: BattleState, magic: HeroMagic = null) -> void:
	_fill_hero_card(_hero_left, state, BattleState.Side.ATTACKER, magic)
	_fill_hero_card(_hero_right, state, BattleState.Side.DEFENDER, null)


func _hero_of_side(state: BattleState, side: BattleState.Side) -> BattleState.BattleUnit:
	if state == null:
		return null
	for u in state.get_units_by_side(side):
		if u.get_key() == GameNumbersHero.HERO_BATTLE_KEY:
			return u
	return null


func _hero_card_refs(panel: Control) -> Dictionary:
	if not _hero_refs.has(panel.name):
		_hero_refs[panel.name] = {
			"portrait": panel.get_node("row/portrait"),
			"name": panel.get_node("row/info/name"),
			"level_row": panel.get_node("row/info/level_row"),
			"level_num": panel.get_node("row/info/level_row/level_num"),
			"hp_row": panel.get_node("row/info/hp_row"),
			"hp_bar": panel.get_node("row/info/hp_row/hp_bar"),
			"hp_num": panel.get_node("row/info/hp_row/hp_num"),
			"mana_row": panel.get_node("row/info/mana_row"),
			"mana_bar": panel.get_node("row/info/mana_row/mana_bar"),
			"mana_num": panel.get_node("row/info/mana_row/mana_num"),
		}
	return _hero_refs[panel.name]


func _fill_hero_card(
	panel: Control,
	state: BattleState,
	side: BattleState.Side,
	magic: HeroMagic
) -> void:
	var hero := _hero_of_side(state, side)
	panel.visible = hero != null
	if hero == null:
		return
	var c := _hero_card_refs(panel)
	c["portrait"].texture = _hero_portrait_texture()
	c["name"].text = hero.get_display_name()
	var level: int = hero.get_level()
	c["level_row"].visible = level > 0
	c["level_num"].text = str(level)
	# Полоса здоровья — только там, где текущее HP действительно меняется
	# (dnd-персонаж). У стекового юнита get_hp() равен максимуму, и полоса
	# всегда была бы полной — то есть врала бы о неизменности.
	var tracked: bool = hero.is_dnd_character()
	c["hp_row"].visible = tracked
	if tracked:
		var mx: int = maxi(1, int(hero.dnd_profile.max_hp))
		var cur: int = clampi(hero.get_hp(), 0, mx)
		c["hp_bar"].max_value = float(mx)
		c["hp_bar"].value = float(cur)
		c["hp_num"].text = "%d/%d" % [cur, mx]
	var has_mana: bool = magic != null and magic.mana_max > 0
	c["mana_row"].visible = has_mana
	if has_mana:
		c["mana_bar"].max_value = float(magic.mana_max)
		c["mana_bar"].value = float(clampi(magic.mana_current, 0, magic.mana_max))
		c["mana_num"].text = "%d/%d" % [magic.mana_current, magic.mana_max]




static func _hero_portrait_texture() -> Texture2D:
	if _hero_portrait == null and ResourceLoader.exists(HERO_PORTRAIT_PATH):
		_hero_portrait = load(HERO_PORTRAIT_PATH) as Texture2D
	return _hero_portrait


# «Спасение» (макет, шаг 5.2): кнопка активна, только когда есть кого поднимать.
func set_rescue_enabled(enabled: bool) -> void:
	if _retreat_btn != null:
		_retreat_btn.disabled = not enabled

func _on_wait() -> void:
	wait_requested.emit()

func _on_attack_mode() -> void:
	attack_mode_requested.emit()

func _on_defend() -> void:
	defend_requested.emit()

func _on_skip() -> void:
	skip_requested.emit()

func _on_history_up() -> void:
	if _history_pos > 0:
		_history_pos -= 1
		_log_line.text = _history[_history_pos]

func _on_history_down() -> void:
	if _history_pos < _history.size() - 1:
		_history_pos += 1
		_log_line.text = _history[_history_pos]

func _on_history_toggle() -> void:
	if _history_panel.visible:
		_history_panel.visible = false
		return
	# Пустая история по клавише H открывается как раньше (test_battle_ui_hotkeys):
	# кнопка ☰ до первой записи не видна, а клавиша — задокументированный вход.
	_history_list.clear()
	for line in _history:
		_history_list.add_item(line)
	_history_panel.visible = true

func _on_spellbook() -> void:
	spellbook_requested.emit()

func open_spellbook(_state: BattleState, magic: HeroMagic = null) -> void:
	if _spellbook_panel == null: return
	if magic != null:
		_spellbook_panel.setup(null, magic, null)
	_spellbook_panel.visible = true
	spellbook_opened.emit()

func _on_settings() -> void:
	settings_requested.emit()

func open_settings() -> void:
	if not _settings_screen.applied.is_connected(_on_settings_applied):
		_settings_screen.applied.connect(_on_settings_applied)
	if not _settings_screen.closed.is_connected(_on_settings_closed):
		_settings_screen.closed.connect(_on_settings_closed)

	var settings_node: Object = Services.resolve(&"settings")
	_settings_screen.setup(settings_node)
	_settings_screen.show()

func _on_settings_applied() -> void:
	pass

func _on_settings_closed() -> void:
	settings_closed.emit()

## Сколько вертикали кадра занято полосами HUD (T-220): x — верх, y — низ, в
## layout-пикселях. Число — не константа кода, а геометрия сцены: правка панели в
## `scenes/ui/battle_ui.tscn` автоматически правит и запас поля боя, поэтому «чинить
## хардкод разрешений» не приходится.
##
## Верх = нижняя граница верхней полосы (карточки героя), и только если полоса
## видна: скрытая панель не имеет права отъедать вертикаль поля.
##
## Вызывается после первого кадра (хост читает после `process_frame`): до раскладки
## `get_global_rect()` пуст, и запас молча стал бы нулём.
func hud_bands() -> Vector2:
	var top := 0.0
	if _hero_cards_band != null:
		top = _hero_cards_band.get_global_rect().end.y
	var bottom := 0.0
	if _bottom_bar != null:
		bottom = _bottom_bar.get_global_rect().size.y
	return Vector2(top, bottom)



## Командный ряд боя (D-294): восемь истинных команд, 4+4, центр полосы пуст.
func _apply_command_row() -> void:
	# D-294: ряд = восемь истинных команд. Сцена несёт исторический состав
	# (десять кнопок и два пустых слота), носителем новой раскладки сделан этот
	# блок — править сцену под неё означало бы второй носитель раскладки.
	var _rescue_node: Button = get_node_or_null("bottom_bar/bar_box/left_box/rescue_btn")
	if _rescue_node != null:
		_rescue_text = _rescue_node.get_node("caption").text
	for _dead in ["bottom_bar/bar_box/left_box/settings_btn",
			"bottom_bar/bar_box/left_box/rescue_btn",
			"bottom_bar/bar_box/right_box/slot_empty_1",
			"bottom_bar/bar_box/right_box/slot_empty_2"]:
		var _n: Node = get_node_or_null(_dead)
		if _n != null:
			_n.free()  # подписи-дети уходят вместе с узлом
	var _left: HBoxContainer = $bottom_bar/bar_box/left_box
	for _b: Button in [_attack_button, _defend_btn]:
		if _b.get_parent() != _left:
			_b.get_parent().remove_child(_b)
			_left.add_child(_b)
	_left.move_child(_attack_button, 0)  # Атака, Защита, Отступить, Автобой
	_left.move_child(_defend_btn, 1)
	# Центр полосы пуст: строка журнала и ▲▼ из неё сняты, журнал — вкладка у
	# края кадра (7.5).
	for _c: CanvasItem in [_log_line, _log_up_btn, _log_down_btn]:
		_c.visible = false
	var _hb_parent: Node = _history_btn.get_parent()
	if _hb_parent != self:
		_hb_parent.remove_child(_history_btn)
		add_child(_history_btn)
	_history_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_history_btn.offset_left = -84.0
	_history_btn.offset_top = 470.0
	_history_btn.offset_right = -24.0
	_history_btn.offset_bottom = 570.0
