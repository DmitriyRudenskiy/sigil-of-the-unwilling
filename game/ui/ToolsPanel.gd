extends PanelContainer
class_name ToolsPanel
## Displays tool inventory slots.

var _slot_labels: Array[Label] = []
var _tool_names := {
	&"shovel": "🔧 Лопата",
	&"pickaxe": "⛏️ Кирка",
	&"cart": "🛒 Телега",
	&"skin_protection": "🛡️ Защита кожи",
	&"net": "🥅 Сеть",
}


func _ready() -> void:
	custom_minimum_size = Vector2(160, 0)
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "🧰 Инструменты"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	for i in GameSettings.TOOL_INVENTORY_SLOTS:
		var hbox := HBoxContainer.new()
		vbox.add_child(hbox)

		var label := Label.new()
		label.text = "[%d] Пусто" % (i + 1)
		label.add_theme_font_size_override("font_size", 12)
		hbox.add_child(label)
		_slot_labels.append(label)


func update_tools(tools: Array[Dictionary]) -> void:
	for i in GameSettings.TOOL_INVENTORY_SLOTS:
		if i >= _slot_labels.size():
			break
		var slot: Dictionary = tools[i] if i < tools.size() else {}
		if slot.is_empty():
			_slot_labels[i].text = "[%d] Пусто" % (i + 1)
		else:
			var id: StringName = slot.get("id", "")
			var qty: int = slot.get("quantity", 1)
			var name: String = _tool_names.get(id, str(id))
			_slot_labels[i].text = "[%d] %s x%d" % [i + 1, name, qty]
