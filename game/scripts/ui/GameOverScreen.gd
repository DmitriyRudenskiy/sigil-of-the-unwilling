## scripts/ui/GameOverScreen.gd
class_name GameOverScreen
extends CanvasLayer
## endgame-conditions: полноэкранный оверлей терминального состояния
## (код-билд, не .tscn — конвенция репо: CityScreen/AdventureUI строятся
## кодом). Заголовок результата, строка причины, сетка итогов забега,
## кнопка «В главное меню». Пока открыт — глотает весь unhandled-ввод
## (гарды терминального состояния в WorldInput/WorldShortcuts/сокет
## — основная блокировка, экран — страховка).

signal return_to_menu

const _REASONS: Dictionary = {
	&"unsuccessored_death": "Герой пал, и некому принять легенду.",
	&"total_collapse": "Все города пали.",
	&"path_completed": "Путь завершён — слава накоплена.",
	&"domination": "Все вражеские силы уничтожены.",
}

var _root: Control = null
var _summary_rows: Array = []


func _init() -> void:
	layer = 100
	visible = false


func show_result(result: String, reason: StringName, summary: Dictionary) -> void:
	_build()
	var title: Label = _root.get_node("Panel/VBox/Title")
	var reason_label: Label = _root.get_node("Panel/VBox/Reason")
	title.text = "Путь завершён" if result == "VICTORY" else "Знак угас"
	title.add_theme_color_override(
		"font_color", Color(0.92, 0.84, 0.55) if result == "VICTORY" else Color(0.75, 0.3, 0.28))
	reason_label.text = str(_REASONS.get(reason, String(reason)))

	var d: Dictionary = summary.get("date", {})
	var values: Dictionary = {
		"TurnsLabel": "Ходы: %d" % int(summary.get("turns", 0)),
		"DateLabel": "Дата: %d/%d/%d" % [
			int(d.get("month", 1)), int(d.get("week", 1)), int(d.get("day", 1))],
		"CitiesLabel": "Города: %d" % int(summary.get("cities_owned", 0)),
		"GloryLabel": "Слава: %d" % int(summary.get("glory", 0)),
		"BattlesLabel": "Боёв: %d побед / %d поражений" % [
			int(summary.get("battles_won", 0)), int(summary.get("battles_lost", 0))],
		"GenerationsLabel": "Поколений: %d" % int(summary.get("generations", 1)),
	}
	var grid: VBoxContainer = _root.get_node("Panel/VBox/Grid")
	for row in _summary_rows:
		grid.get_node(row[0]).text = str(values.get(row[0], row[1]))
	visible = true


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var panel: Panel = Panel.new()
	# ponytail: имя ставим явно — в Godot 4.7 auto-name для unnamed-нод
	# получается «@Panel@N» и get_node("Panel") не находит.
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	panel.position = Vector2(-230, -220)
	_root.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(16, 16)
	vbox.size = Vector2(panel.custom_minimum_size.x - 32, 400)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	var reason := Label.new()
	reason.name = "Reason"
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.add_theme_font_size_override("font_size", 16)
	vbox.add_child(reason)

	var grid := VBoxContainer.new()
	grid.name = "Grid"
	grid.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(grid)

	var rows: Array = [
		["TurnsLabel", "Ходы: —"],
		["DateLabel", "Дата: —"],
		["CitiesLabel", "Города: —"],
		["GloryLabel", "Слава: —"],
		["BattlesLabel", "Боёв: —"],
		["GenerationsLabel", "Поколений: —"],
	]
	for row in rows:
		var l := Label.new()
		l.name = row[0]
		grid.add_child(l)
		_summary_rows.append(row)

	var btn := Button.new()
	btn.name = "MenuButton"
	btn.text = "В главное меню"
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(func() -> void: return_to_menu.emit())
	vbox.add_child(btn)


func _unhandled_input(_event: InputEvent) -> void:
	# Страховка: пока открыт экран, ввод мира не проходит.
	if visible:
		get_viewport().set_input_as_handled()
