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

var _status: Label
var _active_info: Label
var _preview: Label
var _bottom_bar: HBoxContainer
var _initiative_list: ItemList
var _action_buttons: Array[Button] = []
var _attack_button: Button = null
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
	var tp := get_node_or_null("top_panel") as PanelContainer
	if tp != null:
		tp.add_theme_stylebox_override("panel", sb)
	var ip := get_node_or_null("initiative_panel") as PanelContainer
	if ip != null:
		ip.add_theme_stylebox_override("panel", sb)


func _connect_skeleton() -> void:
	_status = get_node_or_null("top_panel/top_vbox/status") as Label
	_active_info = get_node_or_null("top_panel/top_vbox/active_info") as Label
	_preview = get_node_or_null("top_panel/top_vbox/preview") as Label
	_bottom_bar = get_node_or_null("bottom_bar") as HBoxContainer
	_initiative_list = get_node_or_null("initiative_panel/initiative_list") as ItemList

	if _status != null:
		_status.add_theme_color_override("font_color", ThemeConfig.C_TEXT_PRIMARY)
	if _active_info != null:
		_active_info.add_theme_color_override("font_color", ThemeConfig.C_ACTIVE_INFO)
	if _preview != null:
		_preview.add_theme_color_override("font_color", ThemeConfig.C_TEXT_GOLD)

	_action_buttons = []
	_connect_btn("retreat_btn", _on_retreat, true)
	_connect_btn("wait_btn", _on_wait, true)
	_connect_btn("attack_btn", _on_attack_mode, true)
	_connect_btn("defend_btn", _on_defend, true)
	_connect_btn("skip_btn", _on_skip, true)
	var _collapse_btn := get_node_or_null("collapse_btn") as Button
	if _collapse_btn != null and not _collapse_btn.pressed.is_connected(_on_collapse):
		_collapse_btn.pressed.connect(_on_collapse)
	_connect_btn("spellbook_btn", _on_spellbook, true)
	_connect_btn("settings_btn", _on_settings, true)
	_attack_button = get_node_or_null("bottom_bar/attack_btn") as Button
	if _attack_button != null:
		_attack_button.disabled = true


func _connect_btn(name: String, cb: Callable, is_action: bool) -> void:
	var btn := get_node_or_null("bottom_bar/%s" % name) as Button
	if btn == null:
		return
	btn.pressed.connect(cb)
	if is_action:
		_action_buttons.append(btn)


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
	# ИСПРАВЛЕНИЕ: Services.resolve вместо get_node("/root/Settings")
	var settings_node: Object = Services.resolve(&"settings")
	_settings_screen.setup(settings_node)
	_settings_screen.show()


func _on_settings_applied() -> void:
	pass


func _on_settings_closed() -> void:
	settings_closed.emit()
