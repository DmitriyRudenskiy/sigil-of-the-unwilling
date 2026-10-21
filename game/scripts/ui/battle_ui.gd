class_name BattleUI
extends CanvasLayer

const THEME_PATH := "res://assets/theme/game_theme.tres"
const HERO_PORTRAIT_PATH := "res://assets/ui/hero/portrait.png"
# Ячейка очереди хода (макет 11) — квадратный портрет 72 с бейджем уровня.
const _TILE_PX := 94.0  # макет 11: плитка очереди ~94 px, щель 5 px
# Варианты темы ячейки: обычный / активный (золотая рама) / мёртвый.
const TILE_VARIANT := "PanelQueueTile"
const TILE_VARIANT_ACTIVE := "PanelQueueTileActive"
const TILE_VARIANT_DEAD := "PanelQueueTileDead"

signal retreat_requested
signal rescue_requested
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

static var _portrait_tex: Dictionary = {}
static var _hero_portrait: Texture2D = null

# Макет 11: нижний ряд — два кластера медальонов без плиты. Слева — отступление
# и спасение, справа — боевые команды. Путь узла меняется вместе с составом
# кластеров, поэтому он здесь и обязан совпадать со сценой.
@onready var _bottom_bar: Control = $bottom_bar
@onready var _settings_btn: Button = $"bottom_bar/bar_box/left_box/settings_btn"
@onready var _retreat_btn: Button = $"bottom_bar/bar_box/left_box/retreat_btn"
@onready var _rescue_btn: Button = $"bottom_bar/bar_box/left_box/rescue_btn"
@onready var _wait_btn: Button = $"bottom_bar/bar_box/right_box/wait_btn"
@onready var _attack_button: Button = $"bottom_bar/bar_box/right_box/attack_btn"
@onready var _turn_line: Label = $"bottom_bar/info_box/turn_line"
@onready var _log_line: Label = $"bottom_bar/info_box/log_row/log_line"
@onready var _history_up: Button = $"bottom_bar/info_box/log_row/history_nav/history_up"
@onready var _history_down: Button = $"bottom_bar/info_box/log_row/history_nav/history_down"
@onready var _history_btn: Button = $"bottom_bar/info_box/log_row/history_btn"
@onready var _defend_btn: Button = $"bottom_bar/bar_box/right_box/defend_btn"
@onready var _skip_btn: Button = $"bottom_bar/bar_box/right_box/skip_btn"
@onready var _spellbook_btn: Button = $"bottom_bar/bar_box/right_box/spellbook_btn"
@onready var _history_panel: PanelContainer = $history_panel
@onready var _history_list: ItemList = $"history_panel/history_list"
@onready var _init_box: HBoxContainer = $initiative_bar/init_col/init_box
@onready var _hero_left: Control = $hero_cards/hero_left
@onready var _hero_right: Control = $hero_cards/hero_right
@onready var _turn_timer: TurnTimer = $turn_timer
@onready var _target_card: PanelContainer = $target_card
@onready var _tc_name: Label = $"target_card/tc_box/tc_name"
@onready var _tc_count: Label = $"target_card/tc_box/tc_count_row/tc_count"
@onready var _tc_count_row: HBoxContainer = $"target_card/tc_box/tc_count_row"
@onready var _tc_hp: Label = $"target_card/tc_box/tc_hp_row/tc_hp"
@onready var _tc_def: Label = $"target_card/tc_box/tc_def_row/tc_def"
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

var _theme: Theme = null
var _history: Array[String] = []
var _history_pos := 0
var _initiative_units: Array[BattleState.BattleUnit] = []
var _hero_refs: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_theme = load(THEME_PATH)
	_apply_theme()
	_connect_skeleton()
	if not _history_up.pressed.is_connected(_on_history_up):
		_history_up.pressed.connect(_on_history_up)
	if not _history_down.pressed.is_connected(_on_history_down):
		_history_down.pressed.connect(_on_history_down)
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
	# §5: Esc — приоритет: открытая панель → закрыть, иначе настройки
	if event.keycode == KEY_ESCAPE:
		if _spellbook_panel.visible:
			_spellbook_panel.visible = false
		elif _history_panel.visible:
			_history_panel.visible = false
		elif _settings_screen.visible:
			_settings_screen.visible = false
		else:
			_on_settings()
		get_viewport().set_input_as_handled()
		return
	if _settings_screen.visible:
		return
	# §5: хоткеи — спека, не опция. Q (Авто) — absent: кнопки авто нет,
	# AI-автобой вне скоупа (docs/14 §7) — тикет в TICKETS.md, не изобретаем.
	match event.keycode:
		KEY_A:
			_on_attack_mode()
		KEY_D:
			_on_defend()
		KEY_W:
			_on_wait()
		KEY_S:
			_on_skip()
		KEY_K:
			_on_spellbook()
		KEY_H:
			_on_history_toggle()
		KEY_UP:
			_on_history_up()
		KEY_DOWN:
			_on_history_down()
		_:
			return
	get_viewport().set_input_as_handled()


static func _key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode

func _apply_theme() -> void:
	if _theme == null:
		return
	theme_root_theme(_theme)

## CanvasLayer не Control — тему вешаем на корневые контролы слоя.
func theme_root_theme(t: Theme) -> void:
	for c in ["bottom_bar", "initiative_bar", "target_card", "end_overlay", "history_panel"]:
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
	_action_buttons = [_retreat_btn, _rescue_btn, _wait_btn, _attack_button, _defend_btn, _skip_btn]
	_retreat_btn.pressed.connect(_on_retreat)
	_rescue_btn.pressed.connect(_on_rescue)
	_wait_btn.pressed.connect(_on_wait)
	_attack_button.pressed.connect(_on_attack_mode)
	_defend_btn.pressed.connect(_on_defend)
	_skip_btn.pressed.connect(_on_skip)
	_spellbook_btn.pressed.connect(_on_spellbook)
	_settings_btn.pressed.connect(_on_settings)
	_attack_button.disabled = true

func set_status(text: String) -> void:
	_history.append(text)
	if _history.size() > 50:
		_history.pop_front()
	_history_pos = _history.size() - 1
	_log_line.text = text

func set_attack_preview(text: String) -> void:
	# B: предпросмотр урона — error-chip (лёгальная подложка #281c0f, docs/14 §2)
	_tc_preview.text = text
	_tc_preview.visible = text != ""

func show_target_card(unit: BattleState.BattleUnit) -> void:
	# B (M1): только live-поля; строка без источника — скрыта, фейковых чисел нет
	if unit == null:
		hide_target_card()
		return
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

func update_active_unit(unit: BattleState.BattleUnit) -> void:
	# A: переподсветка активного в очереди инициативы
	_refresh_initiative_highlight(unit)

# A: очередь инициативы — live из BattleState.turn_queue; активный — PanelActive
# (золотая рамка, docs/14 §4.A), мёртвый — PanelDead + десат + штриховка
# (различимы формой, не тоном — M3-1).
func update_initiative(
	units: Array[BattleState.BattleUnit],
	active_unit: BattleState.BattleUnit
) -> void:
	_initiative_units = units
	for child in _init_box.get_children():
		_init_box.remove_child(child)
		child.queue_free()
	for unit in units:
		_init_box.add_child(_make_initiative_cell(unit))
	_refresh_initiative_highlight(active_unit)

func _make_initiative_cell(unit: BattleState.BattleUnit) -> PanelContainer:
	var cell := PanelContainer.new()
	var dead: bool = not unit.is_alive()
	cell.theme_type_variation = TILE_VARIANT_DEAD if dead else TILE_VARIANT
	cell.name = "cell_%d" % unit.uid
	cell.custom_minimum_size = Vector2(_TILE_PX, _TILE_PX)
	if dead:
		var hatch := TextureRect.new()
		hatch.texture = _hatch_texture()
		hatch.texture_repeat = 1  # TextureRect.RepeatMode.REPEAT_ENABLED (Godot 4.7)
		hatch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(hatch)
	# Макет 11: ячейка — квадратный портрет с бейджем уровня в углу. Имени и
	# чисел в ней нет: имя и здоровье даёт карточка цели, количество — на поле
	# (композиция — макет, поведение — спека docs/14 §4.A).
	var row := HBoxContainer.new()
	row.name = "row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_make_initiative_portrait(unit))
	cell.add_child(row)
	return cell




func _make_initiative_portrait(unit: BattleState.BattleUnit) -> Control:
	var box := Control.new()
	box.name = "portrait_box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(_TILE_PX - 4.0, _TILE_PX - 4.0)
	var portrait := TextureRect.new()
	portrait.name = "portrait"
	portrait.texture = _unit_portrait(unit.get_key())
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not unit.is_alive():
		portrait.modulate = Color(0.4, 0.4, 0.4, 0.8)  # десат мёртвого (docs/14 §4.A)
	box.add_child(portrait)
	var level: int = unit.get_level()
	if level > 0:
		# Бейдж уровня — в нижнем левом углу плитки (макет 11).
		var badge := Label.new()
		badge.name = "level_badge"
		badge.theme_type_variation = "LabelQueueBadge"
		badge.text = str(level)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		badge.position = Vector2(4, -24)
		box.add_child(badge)
	return box




static func _unit_portrait(key: String) -> Texture2D:
	if _portrait_tex.has(key):
		return _portrait_tex[key]
	var tex: Texture2D = null
	var path := UnitSprites.find_portrait(key)
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_portrait_tex[key] = tex
	return tex

static var _hatch_tex: ImageTexture = null


## М3-1: диагональная штриховка мёртвой ячейки — различимость формой.
static func _hatch_texture() -> ImageTexture:
	if _hatch_tex == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var c := Color(0.02, 0.01, 0.01, 0.55)
		for i in 8:
			img.set_pixel(i, i, c)
			img.set_pixel((i + 1) % 8, i, c)
		_hatch_tex = ImageTexture.create_from_image(img)
	return _hatch_tex


func _refresh_initiative_highlight(active_unit: BattleState.BattleUnit) -> void:
	for child in _init_box.get_children():
		if child is PanelContainer and child.name.begins_with("cell_"):
			var uid: int = int(child.name.get_slice("_", 1))
			if child.theme_type_variation == TILE_VARIANT_DEAD:
				continue
			var is_active: bool = active_unit != null and uid == active_unit.uid
			child.theme_type_variation = TILE_VARIANT_ACTIVE if is_active else TILE_VARIANT

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

func _on_retreat() -> void:
	retreat_requested.emit()

func _on_rescue() -> void:
	rescue_requested.emit()


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


# --- Таймер хода (макет, шаг 5.3) -----------------------------------------
# Значения несёт BattleState (turn_time_left / turn_time_limit / turn_timer_running);
# режим без ограничения — неактивное состояние элемента, а не исчезание.
func set_turn_timer(seconds_left: float, limit: int, running: bool) -> void:
	if _turn_timer != null:
		_turn_timer.set_state(seconds_left, limit, running)


# «Спасение» (макет, шаг 5.2): кнопка активна, только когда есть кого поднимать.
func set_rescue_enabled(enabled: bool) -> void:
	if _rescue_btn != null:
		_rescue_btn.disabled = not enabled

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
