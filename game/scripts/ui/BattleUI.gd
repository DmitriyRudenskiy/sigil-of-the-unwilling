class_name BattleUI
extends CanvasLayer
## Панель боя: статус, кнопки, инициатива, активный стек, preview.
## Скелет (top-панель, нижняя полоса кнопок, инициатива) вертается в сцене
## `BattleUI.tscn`; динамические элементы (лейблы инициативы, книга заклинаний,
## настройки) строятся/управляются в рантайме. Стили — из общей темы (D3).

const THEME_PATH := "res://assets/theme/game_theme.tres"
const _SettingsScreen = preload("res://scripts/ui/SettingsScreen.gd")
const _SpellbookPath = "res://scenes/ui/BattleSpellbookPanel.tscn"
const _SpellbookPanel = preload("res://scripts/ui/BattleSpellbookPanel.gd")

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
var _initiative_list: VBoxContainer
var _action_buttons: Array[Button] = []
var _attack_button: Button = null
var _settings_screen: Control = null
var _spellbook_panel: _SpellbookPanel = null

var _theme: Theme = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # SettingsScreen inherits this
	layer = 10
	_theme = load(THEME_PATH)
	_apply_theme()
	_connect_skeleton()
	_build_spellbook()


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
	_initiative_list = get_node_or_null("initiative_panel/initiative_list") as VBoxContainer

	if _status != null:
		_status.add_theme_color_override("font_color", Color(0.95, 0.89, 0.72))
	if _active_info != null:
		_active_info.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	if _preview != null:
		_preview.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))

	_action_buttons = []
	_connect_btn("retreat_btn", _on_retreat, true)
	_connect_btn("wait_btn", _on_wait, true)
	_connect_btn("attack_btn", _on_attack_mode, true)
	_connect_btn("defend_btn", _on_defend, true)
	_connect_btn("skip_btn", _on_skip, true)
	# R2: collapse_btn lives at the root (not inside bottom_bar) so toggling
	# _bottom_bar.visible does not hide the button that expands it again.
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

	_active_info.text = "%s | Count: %d | HP: %d | ATK: %d | DEF: %d | SPD: %d | %s" % [
		stats.display_name,
		unit.get_count(),
		stats.hp,
		stats.attack,
		stats.defense,
		stats.speed,
		", ".join(stats.tags)
	]


func update_initiative(units: Array[BattleState.BattleUnit], active_unit: BattleState.BattleUnit) -> void:
	for child in _initiative_list.get_children():
		# Godot 4.7: Node.remove_from_parent() удалён — remove_child у родителя.
		_initiative_list.remove_child(child)
		child.queue_free()

	for unit in units:
		if unit == null:
			continue

		var label := Label.new()
		label.text = "%s x%d" % [
			unit.get_display_name().left(8),
			unit.get_count()
		]
		label.add_theme_font_size_override("font_size", 12)

		if unit == active_unit:
			label.add_theme_color_override("font_color", Color.GOLD)
		elif unit.side == BattleState.Side.ATTACKER:
			label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		else:
			label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.7))

		_initiative_list.add_child(label)


func set_controls_enabled(enabled: bool) -> void:
	for btn in _action_buttons:
		btn.disabled = not enabled

	if _attack_button != null and not enabled:
		_attack_button.disabled = true


func set_attack_enabled(enabled: bool) -> void:
	if _attack_button != null:
		_attack_button.disabled = not enabled


func _build_spellbook() -> void:
	_spellbook_panel = load(_SpellbookPath).instantiate() as _SpellbookPanel
	_spellbook_panel.visible = false
	_spellbook_panel.spell_chosen.connect(func(id):
		_spellbook_panel.visible = false
		spell_chosen.emit(id))
	add_child(_spellbook_panel)


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
	# Opened by BattleController when pause is set
	_settings_screen = _SettingsScreen.new()
	_settings_screen.setup(get_node_or_null("/root/Settings"))
	_settings_screen.applied.connect(_on_settings_applied)
	_settings_screen.closed.connect(_on_settings_closed)
	add_child(_settings_screen)


func _on_settings_applied() -> void:
	# Applied only applies settings.
	# Resume is handled by the closed signal.
	pass


func _on_settings_closed() -> void:
	_settings_screen = null
	settings_closed.emit()
