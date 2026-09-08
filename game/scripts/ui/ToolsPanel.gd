extends PanelContainer
class_name ToolsPanel

const ToolType = preload("res://scripts/data/ToolType.gd")

var _slot_labels: Array[Label] = []

func _ready() -> void:
    var title := $VBox/Title as Label
    title.add_theme_font_size_override("font_size", 14)
    title.text = GameText.tools_title()
    var container := $VBox/ToolContainer as VBoxContainer
    for i in GameNumbers.TOOL_INVENTORY_SLOTS:
        var row := container.get_node("Slot%d" % i) as HBoxContainer
        if row == null:
            continue
        var label := row.get_node("SlotLabel") as Label
        if label != null:
            label.add_theme_font_size_override("font_size", 12)
            _slot_labels.append(label)

func update_tools(tools: Array[Dictionary]) -> void:
    for i in GameNumbers.TOOL_INVENTORY_SLOTS:
        if i >= _slot_labels.size():
            break
        var slot: Dictionary = tools[i] if i < tools.size() else {}
        if slot.is_empty():
            _slot_labels[i].text = GameText.tools_slot_empty(i + 1)
        else:
            var id: int = slot.get("id", 0)
            var qty: int = slot.get("quantity", 1)
            var name: String = GameText.tool_name(id)
            _slot_labels[i].text = GameText.tools_slot_filled(i + 1, name, qty)
