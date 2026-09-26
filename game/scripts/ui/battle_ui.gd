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
var _action_buttons: Array[Button] = []
@onready var _settings_screen: SettingsScreen = $SettingsScreen
@onready var _spellbook_panel: BattleSpellbookPanel = $BattleSpellbookPanel

var _theme: Theme = null
var _history: Array[String] = []
var _history_pos := 0

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

func _apply_theme() -> void:
	if _theme == null:
		return
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

# ponytail: top_panel (status/active_info/preview) удалён из сцены — методы оставлены
# no-op, чтобы не трогать подключения в BattleController. Вернуть UI — добавить узлы обратно.
func set_attack_preview(_text: String) -> void:
	pass

func update_active_unit(_unit: BattleState.BattleUnit) -> void:
	pass

# ponytail: initiative_panel удалён из сцены — метод оставлен no-op
# (BattleController:298), turn_line больше не получает счётчик ходов.
func update_initiative(_units: Array[BattleState.BattleUnit], _active_unit: BattleState.BattleUnit) -> void:
	pass

func set_controls_enabled(enabled: bool) -> void:
	for btn in _action_buttons:
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
