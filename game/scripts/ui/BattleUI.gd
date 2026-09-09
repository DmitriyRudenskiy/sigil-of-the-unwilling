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

@onready var _top_panel: PanelContainer = $top_panel
@onready var _status: Label = $"top_panel/top_vbox/status"
@onready var _active_info: Label = $"top_panel/top_vbox/active_info"
@onready var _preview: Label = $"top_panel/top_vbox/preview"
@onready var _bottom_bar: HBoxContainer = $bottom_bar
@onready var _retreat_btn: Button = $"bottom_bar/retreat_btn"
@onready var _wait_btn: Button = $"bottom_bar/wait_btn"
@onready var _attack_button: Button = $"bottom_bar/attack_btn"
@onready var _defend_btn: Button = $"bottom_bar/defend_btn"
@onready var _skip_btn: Button = $"bottom_bar/skip_btn"
@onready var _spellbook_btn: Button = $"bottom_bar/spellbook_btn"
@onready var _settings_btn: Button = $"bottom_bar/settings_btn"
@onready var _collapse_btn: Button = $collapse_btn
@onready var _initiative_panel: PanelContainer = $initiative_panel
@onready var _initiative_list: ItemList = $"initiative_panel/initiative_list"
var _action_buttons: Array[Button] = []
@onready var _settings_screen: SettingsScreen = $SettingsScreen
@onready var _spellbook_panel: BattleSpellbookPanel = $BattleSpellbookPanel

var _theme: Theme = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_theme = load(THEME_PATH)
	_apply_theme()
	_connect_skeleton()
	if _status != null:
		_status.text = GameText.battle_select_unit()
	if not _spellbook_panel.spell_chosen.is_connected(_on_spellbook_chosen):
		_spellbook_panel.spell_chosen.connect(_on_spellbook_chosen)

func _apply_theme() -> void:
	if _theme == null:
		return
	var sb := _theme.get_stylebox("panel", "Panel")
	if sb == null:
		return
	_top_panel.add_theme_stylebox_override("panel", sb)
	_initiative_panel.add_theme_stylebox_override("panel", sb)

func _connect_skeleton() -> void:

	_status.add_theme_color_override("font_color", ThemeConfig.C_TEXT_PRIMARY)
	_active_info.add_theme_color_override("font_color", ThemeConfig.C_ACTIVE_INFO)
	_preview.add_theme_color_override("font_color", ThemeConfig.C_TEXT_GOLD)

	_action_buttons = [_retreat_btn, _wait_btn, _attack_button, _defend_btn, _skip_btn]
	_retreat_btn.pressed.connect(_on_retreat)
	_wait_btn.pressed.connect(_on_wait)
	_attack_button.pressed.connect(_on_attack_mode)
	_defend_btn.pressed.connect(_on_defend)
	_skip_btn.pressed.connect(_on_skip)
	_spellbook_btn.pressed.connect(_on_spellbook)
	_settings_btn.pressed.connect(_on_settings)
	if not _collapse_btn.pressed.is_connected(_on_collapse):
		_collapse_btn.pressed.connect(_on_collapse)
	_attack_button.disabled = true

func set_status(text: String) -> void:
	_status.text = text

func set_attack_preview(text: String) -> void:
	_preview.text = text

func update_active_unit(unit: BattleState.BattleUnit) -> void:
	if unit == null or unit.stack == null or unit.stack.stats == null:
		_active_info.text = ""
		return

	var stats: UnitStats = unit.stack.stats

	_active_info.text = GameText.battle_unit_info(
		stats.display_name,
		unit.get_count(),
		stats.hp,
		stats.attack,
		stats.defense,
		stats.speed,
		", ".join(stats.tags)
	)

func update_initiative(units: Array[BattleState.BattleUnit], active_unit: BattleState.BattleUnit) -> void:
	if _initiative_list == null:
		return
	_initiative_list.clear()
	for unit in units:
		if unit == null:
			continue
		var text = GameText.battle_unit_short(unit.get_display_name().left(8), unit.get_count())
		var idx = _initiative_list.add_item(text)
		if unit == active_unit:
			_initiative_list.set_item_custom_fg_color(idx, Color.GOLD)
		elif unit.side == BattleState.Side.ATTACKER:
			_initiative_list.set_item_custom_fg_color(idx, ThemeConfig.C_INITIATIVE_YOUR)
		else:
			_initiative_list.set_item_custom_fg_color(idx, ThemeConfig.C_INITIATIVE_ENEMY)

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

func _on_collapse() -> void:
	_bottom_bar.visible = not _bottom_bar.visible

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
