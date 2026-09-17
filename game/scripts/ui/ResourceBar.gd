class_name ResourceBar
extends HBoxContainer

const IR = preload("res://scripts/theme/IconRegistry.gd")

var _labels: Dictionary = {}
var _icons: Dictionary = {}

func _ready() -> void:
	for id in ResourceType.classic_ids():
		var l := get_node(ResourceType.to_key(id).capitalize()) as Label
		if l == null:
			continue
		l.add_theme_font_size_override("font_size", ThemeConfig.FONT_SIZE_SMALL)
		l.add_theme_color_override("font_color", ThemeConfig.C_TEXT_PRIMARY)
		_labels[id] = l
		var t := get_node_or_null("%sIcon" % ResourceType.to_key(id).capitalize()) as TextureRect
		if t != null:
			t.texture = IR.resource_texture(ResourceType.to_name(id))
			_icons[id] = t

func update_resources(resources: Dictionary) -> void:
	for id in _labels:
		_labels[id].text = "%d" % int(resources.get(id, 0))
		if _icons.has(id):
			_icons[id].tooltip_text = ResourceType.to_name(id)
