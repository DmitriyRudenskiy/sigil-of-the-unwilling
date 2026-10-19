class_name BattleUI
extends CanvasLayer

const THEME_PATH := "res://assets/theme/game_theme.tres"

signal retreat_requested
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

@onready var _bottom_bar: PanelContainer = $bottom_bar
@onready var _settings_btn: Button = $"bottom_bar/bar_box/left_box/settings_btn"
@onready var _retreat_btn: Button = $"bottom_bar/bar_box/left_box/retreat_btn"
@onready var _wait_btn: Button = $"bottom_bar/bar_box/left_box/wait_btn"
@onready var _attack_button: Button = $"bottom_bar/bar_box/left_box/attack_btn"
@onready var _turn_line: Label = $"bottom_bar/bar_box/center_box/turn_line"
@onready var _log_line: Label = $"bottom_bar/bar_box/center_box/log_row/log_line"
@onready var _history_up: Button = $"bottom_bar/bar_box/center_box/log_row/history_nav/history_up"
@onready var _history_down: Button = $"bottom_bar/bar_box/center_box/log_row/history_nav/history_down"
@onready var _history_btn: Button = $"bottom_bar/bar_box/center_box/log_row/history_btn"
@onready var _defend_btn: Button = $"bottom_bar/bar_box/right_box/defend_btn"
@onready var _skip_btn: Button = $"bottom_bar/bar_box/right_box/skip_btn"
@onready var _spellbook_btn: Button = $"bottom_bar/bar_box/right_box/spellbook_btn"
@onready var _history_panel: PanelContainer = $history_panel
@onready var _history_list: ItemList = $"history_panel/history_list"
@onready var _init_box: HBoxContainer = $initiative_bar/init_col/init_box
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
	var sb := _theme.get_stylebox("panel", "Panel")
	if sb == null:
		return
	_bottom_bar.add_theme_stylebox_override("panel", sb)
	_history_panel.add_theme_stylebox_override("panel", sb)

func _connect_skeleton() -> void:
	_action_buttons = [_retreat_btn, _wait_btn, _attack_button, _defend_btn, _skip_btn]
	_retreat_btn.pressed.connect(_on_retreat)
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
	cell.theme_type_variation = "PanelDead" if dead else "PanelCard"
	cell.name = "cell_%d" % unit.uid
	if dead:
		var hatch := TextureRect.new()
		hatch.texture = _hatch_texture()
		hatch.texture_repeat = 1  # TextureRect.RepeatMode.REPEAT_ENABLED (Godot 4.7)
		hatch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(hatch)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.theme_type_variation = "LabelDead" if dead else "LabelCell"
	name_label.text = unit.get_display_name()
	var hp_label := Label.new()
	hp_label.theme_type_variation = "LabelNumber"
	hp_label.text = str(unit.get_hp())
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	box.add_child(hp_label)
	cell.add_child(box)
	return cell

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
			if child.theme_type_variation == "PanelDead":
				continue
			var is_active: bool = active_unit != null and uid == active_unit.uid
			child.theme_type_variation = "PanelActive" if is_active else "PanelCard"

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
