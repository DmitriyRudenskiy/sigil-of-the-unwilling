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
@onready var _init_box: HBoxContainer = $initiative_bar/init_scroll/init_box
@onready var _target_card: PanelContainer = $target_card
@onready var _tc_name: Label = $"target_card/tc_box/tc_name"
@onready var _tc_count: Label = $"target_card/tc_box/tc_count_row/tc_count"
@onready var _tc_count_row: HBoxContainer = $"target_card/tc_box/tc_count_row"
@onready var _tc_hp: Label = $"target_card/tc_box/tc_hp_row/tc_hp"
@onready var _tc_def: Label = $"target_card/tc_box/tc_def_row/tc_def"
@onready var _tc_atk_row: HBoxContainer = $"target_card/tc_box/tc_atk_row"
@onready var _tc_atk: Label = $"target_card/tc_box/tc_atk_row/tc_atk"
@onready var _tc_preview: Label = $"target_card/tc_box/tc_preview"
@onready var _end_overlay: PanelContainer = $end_overlay
@onready var _end_title: Label = $"end_overlay/end_center/end_box/end_title"
@onready var _end_info: Label = $"end_overlay/end_center/end_box/end_info"
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
	# F: единственный выход — «Продолжить»; Enter/Space подтверждают его же
	if _end_overlay.visible and event.is_action_pressed("ui_accept"):
		_continue_btn.emit_signal("pressed")
		get_viewport().set_input_as_handled()

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
	_target_card.visible = true

func hide_target_card() -> void:
	_target_card.visible = false

func update_active_unit(unit: BattleState.BattleUnit) -> void:
	# A: переподсветка активного в очереди инициативы
	_refresh_initiative_highlight(unit)

# A: очередь инициативы — live из BattleState.turn_queue; активный — PanelActive
# (золотая рамка, docs/14 §4.A), мёртвый — PanelDead + LabelDead (десат формой).
func update_initiative(units: Array[BattleState.BattleUnit], active_unit: BattleState.BattleUnit) -> void:
	_initiative_units = units
	for child in _init_box.get_children():
		_init_box.remove_child(child)
		child.queue_free()
	for unit in units:
		_init_box.add_child(_make_initiative_cell(unit))
	_refresh_initiative_highlight(active_unit)

func _make_initiative_cell(unit: BattleState.BattleUnit) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.theme_type_variation = "PanelDead" if not unit.is_alive() else "PanelCard"
	cell.name = "cell_%d" % unit.uid
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.theme_type_variation = "LabelDead" if not unit.is_alive() else "LabelCell"
	name_label.text = unit.get_display_name()
	var hp_label := Label.new()
	hp_label.theme_type_variation = "LabelNumber"
	hp_label.text = str(unit.get_hp())
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	box.add_child(hp_label)
	cell.add_child(box)
	return cell

func _refresh_initiative_highlight(active_unit: BattleState.BattleUnit) -> void:
	for child in _init_box.get_children():
		if child is PanelContainer and child.name.begins_with("cell_"):
			var uid: int = int(child.name.get_slice("_", 1))
			if child.theme_type_variation == "PanelDead":
				continue
			child.theme_type_variation = "PanelActive" if active_unit != null and uid == active_unit.uid else "PanelCard"

# F: финал боя — единственный выход «Продолжить» (docs/14 §4.F); потери — моно.
func show_result(winner: int, surviving_atk: int, surviving_def: int) -> void:
	_end_title.text = "Победа" if winner == BattleState.Side.ATTACKER else "Поражение"
	_end_info.text = "Остаток: %d / %d" % [surviving_atk, surviving_def]
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
	if _spellbook_panel != null:
		_spellbook_panel.visible = false

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
