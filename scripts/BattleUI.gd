class_name BattleUI
extends CanvasLayer
## Панель боя: статус, кнопки, намерения игрока через сигналы.
## Не меняет BattleState и не управляет боем.

signal retreat_requested
signal wait_requested
signal attack_mode_requested
signal skip_requested
signal defend_requested

var _status: Label
var _bottom_bar: HBoxContainer


func _ready() -> void:
	layer = 10
	_build_ui()


func set_status(text: String) -> void:
	_status.text = text


func _build_ui() -> void:
	var tb := PanelContainer.new()
	tb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tb.offset_bottom = 48
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.1, 0.08, 0.05, 0.92)
	tb.add_theme_stylebox_override("panel", ts)
	add_child(tb)

	_status = Label.new()
	_status.text = "Выберите существо…"
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.95, 0.89, 0.72))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(_status)

	_bottom_bar = HBoxContainer.new()
	_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.offset_top = -58
	_bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_bar.add_theme_constant_override("separation", 10)
	add_child(_bottom_bar)

	var btns := [
		["⚙️", "Настройки/пауза", "_on_settings"],
		["🏕️", "Отступление", "_on_retreat"],
		["🏃", "Ждать", "_on_wait"],
		["⚔️", "Атака", "_on_attack_mode"],
		["▲", "Свернуть панель", "_on_collapse"],
		["📖", "Книга заклинаний", "_on_spellbook"],
		["⏳", "Пропуск хода", "_on_skip"],
		["🛡️", "Защита", "_on_defend"],
	]
	for b in btns:
		var btn := Button.new()
		btn.text = b[0]
		btn.tooltip_text = b[1]
		btn.custom_minimum_size = Vector2(56, 48)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(Callable(self, b[2]))
		_bottom_bar.add_child(btn)


func _on_settings() -> void:
	_status.text = "⚙️ Пауза (в прототипе не реализовано)"


func _on_retreat() -> void:
	retreat_requested.emit()


func _on_wait() -> void:
	wait_requested.emit()


func _on_attack_mode() -> void:
	attack_mode_requested.emit()


func _on_collapse() -> void:
	_bottom_bar.visible = not _bottom_bar.visible


func _on_spellbook() -> void:
	_status.text = "📖 Книга заклинаний: в прототипе не реализовано"


func _on_skip() -> void:
	skip_requested.emit()


func _on_defend() -> void:
	defend_requested.emit()
