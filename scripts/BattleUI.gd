class_name BattleUI
extends CanvasLayer
## Панель боя: статус, кнопки, инициатива, активный стек, preview.

signal retreat_requested
signal wait_requested
signal attack_mode_requested
signal skip_requested
signal defend_requested
signal spellbook_requested
signal spell_chosen(spell_id: StringName)
signal settings_requested
signal settings_closed

const _SettingsScreen = preload("res://scripts/ui/SettingsScreen.gd")
const _SpellbookPanel = preload("res://scripts/ui/BattleSpellbookPanel.gd")

var _status: Label
var _active_info: Label
var _preview: Label
var _bottom_bar: HBoxContainer
var _initiative_list: VBoxContainer
var _action_buttons: Array[Button] = []
var _attack_button: Button = null
var _settings_screen: Control = null
var _spellbook_panel: _SpellbookPanel = null


func _ready() -> void:
	layer = 10
	_build_ui()


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
		elif unit.side == "attacker":
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


func _build_ui() -> void:
	_build_top_panel()
	_build_bottom_bar()
	_build_initiative_panel()
	_build_spellbook()


func _build_spellbook() -> void:
	_spellbook_panel = _SpellbookPanel.new()
	_spellbook_panel.visible = false
	_spellbook_panel.spell_chosen.connect(func(id): spell_chosen.emit(id))
	add_child(_spellbook_panel)


func _build_top_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 92

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.05, 0.92)
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	_status = Label.new()
	_status.text = "Выберите существо…"
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.95, 0.89, 0.72))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_status)

	_active_info = Label.new()
	_active_info.text = ""
	_active_info.add_theme_font_size_override("font_size", 14)
	_active_info.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_active_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_active_info)

	_preview = Label.new()
	_preview.text = ""
	_preview.add_theme_font_size_override("font_size", 14)
	_preview.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_preview)


func _build_bottom_bar() -> void:
	_bottom_bar = HBoxContainer.new()
	_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.offset_top = -58
	_bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_bar.add_theme_constant_override("separation", 10)

	add_child(_bottom_bar)

	var buttons: Array[Dictionary] = [
		{"text": "🏕️", "tooltip": "Отступление", "callback": _on_retreat, "action": true},
		{"text": "🏃", "tooltip": "Ждать", "callback": _on_wait, "action": true},
		{"text": "⚔️", "tooltip": "Атака", "callback": _on_attack_mode, "action": true, "attack": true},
		{"text": "🛡️", "tooltip": "Защита", "callback": _on_defend, "action": true},
		{"text": "⏳", "tooltip": "Пропуск хода", "callback": _on_skip, "action": true},
		{"text": "▲", "tooltip": "Свернуть панель", "callback": _on_collapse, "action": false},
		{"text": "📖", "tooltip": "Книга заклинаний", "callback": _on_spellbook, "action": false},
		{"text": "⚙️", "tooltip": "Настройки", "callback": _on_settings, "action": true},
	]

	for data in buttons:
		var btn := Button.new()
		btn.text = data["text"]
		btn.tooltip_text = data["tooltip"]
		btn.custom_minimum_size = Vector2(56, 48)
		btn.add_theme_font_size_override("font_size", 22)

		var callback: Callable = data["callback"]
		btn.pressed.connect(callback)

		_bottom_bar.add_child(btn)

		if data.get("action", false):
			_action_buttons.append(btn)

		if data.get("attack", false):
			_attack_button = btn
			btn.disabled = true


func _build_initiative_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -190
	panel.offset_top = 100
	panel.offset_bottom = -80

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.85)
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)

	_initiative_list = VBoxContainer.new()
	_initiative_list.add_theme_constant_override("separation", 4)
	panel.add_child(_initiative_list)


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


func open_spellbook(_state: BattleState) -> void:
	if _spellbook_panel == null: return
	# TODO: pass hero and magic when available
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
