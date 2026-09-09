
class_name ResourceBar
extends HBoxContainer

const ResourceType = preload("res://scripts/data/ResourceType.gd")

var _labels: Dictionary = {}

func _ready() -> void:
	for id in ResourceType.classic_ids():
		var l := get_node(ResourceType.to_key(id).capitalize()) as Label
		if l == null:
			continue
		l.add_theme_font_size_override("font_size", ThemeConfig.FONT_SIZE_SMALL)
		l.add_theme_color_override("font_color", ThemeConfig.C_TEXT_PRIMARY)
		_labels[id] = l

func update_resources(resources: Dictionary) -> void:
	for id in _labels:
		var icon := ThemeConfig.resource_icon(ResourceType.to_name(id))
		_labels[id].text = "%s%d" % [icon, int(resources.get(id, 0))]
