## scripts/ui/ChronicleScreen.gd
class_name ChronicleScreen
extends CanvasLayer
## legend-chronicle: чтение летописи поколений — newest-first список
## записей + «Закрыть». Код-билд (конвенция репо). Доступна из
## MainMenu («Летопись») и после смерти героя (DeathSequence).

signal closed

var _root: Control = null


func _init() -> void:
	layer = 120
	visible = false


## entries — Array[Dictionary] в том же формате, что Chronicle.entries
## (отображается newest-first).
func show_entries(entries: Array) -> void:
	_build()
	var list: VBoxContainer = _root.get_node("Panel/VBox/Scroll/List")
	var count := entries.size()
	for i in range(count - 1, -1, -1):
		var e: Dictionary = entries[i]
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 14)
		l.text = _entry_line(e)
		list.add_child(l)
	if count == 0:
		var empty := Label.new()
		empty.text = "Летопись пуста — легенда только начинается."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		list.add_child(empty)
	visible = true
	# Твин требует ноду в дереве — в headless-тестах показываем без анимации.
	if _root.get_node("Panel").is_inside_tree():
		UIAnimator.animate_in(_root.get_node("Panel"))


func _entry_line(e: Dictionary) -> String:
	var outcome := str(e.get("outcome", "?"))
	var icon := "👑" if outcome == "VICTORY" else "💀" if outcome == "DEFEAT" else "🔁"
	return "%s %d. %s (%s) — %s | ходы %s, слава %s, боёв %s/%s" % [
		icon,
		int(e.get("generation", 0)),
		str(e.get("hero_name", "?")),
		str(e.get("path", "")),
		outcome,
		str(e.get("end_turn", 0)),
		str(e.get("glory", 0)),
		str(e.get("battles_won", 0)),
		str(e.get("battles_lost", 0)),
	]


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	# ponytail: имя явное — Godot 4.7 auto-name (@Control@N) ломает get_node.
	_root.name = "Root"
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
	panel.custom_minimum_size = Vector2(520, 0)
	panel.position = Vector2(-260, -240)
	_root.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(16, 16)
	vbox.size = Vector2(panel.custom_minimum_size.x - 32, 440)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "📜 Летопись поколений"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Закрыть"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	vbox.add_child(close_btn)


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
