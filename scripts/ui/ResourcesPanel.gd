extends PanelContainer
class_name ResourcesPanel
## Displays strategic resources with icons and amounts.

const ResourceDef = preload("res://scripts/data/ResourceDef.gd")

var _labels: Dictionary = {}  # resource_id -> Label


func _ready() -> void:
	custom_minimum_size = Vector2(160, 0)
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "📦 Ресурсы"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var all := ResourceRegistry.get_all()
	for def in all:
		var hbox := HBoxContainer.new()
		vbox.add_child(hbox)

		var label := Label.new()
		label.text = "%s %d/%d" % [def.icon, 0, GameSettings.RESOURCE_CAPACITY]
		label.tooltip_text = def.display_name
		label.add_theme_font_size_override("font_size", 12)
		hbox.add_child(label)

		_labels[def.id] = label


func update_resources(resources: Dictionary) -> void:
	for id in _labels:
		var label: Label = _labels[id]
		var amount: int = int(resources.get(id, 0))
		var def: ResourceDef = ResourceRegistry.get_resource(id)
		if def:
			label.text = "%s %d/%d" % [def.icon, amount, GameSettings.RESOURCE_CAPACITY]
		else:
			label.text = "⛏️ %d/%d" % [amount, GameSettings.RESOURCE_CAPACITY]
