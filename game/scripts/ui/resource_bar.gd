class_name ResourceBar
extends HBoxContainer



var _labels: Dictionary = {}

func _ready() -> void:
	for id in ResourceType.classic_ids():
		var box := get_node_or_null(ResourceType.to_key(id).capitalize()) as HBoxContainer
		if box == null:
			continue
		var l := box.get_node("Value") as Label
		l.add_theme_font_size_override("font_size", ThemeConfig.FONT_SIZE_SMALL)
		l.add_theme_color_override("font_color", ThemeConfig.C_TEXT_PRIMARY)
		_labels[id] = l

func update_resources(resources: Dictionary) -> void:
	for id in _labels:
		_labels[id].text = str(int(resources.get(id, 0)))
