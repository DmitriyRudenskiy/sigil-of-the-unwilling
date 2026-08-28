class_name ResourceBar
extends HBoxContainer
## Панель ресурсов: иконка + число.

const C_TEXT := Color(0.95, 0.89, 0.72)
const ICONS := {
	"wood": "🪵", "mercury": "🧪", "ore": "🪨", "sulfur": "🟡",
	"crystal": "🔷", "gems": "💎", "gold": "🪙",
}

var _labels: Dictionary = {}


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)

	for key in ICONS:
		var l := Label.new()
		l.text = "%s0" % ICONS[key]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", C_TEXT)
		add_child(l)
		_labels[key] = l


func update_resources(resources: Dictionary) -> void:
	for k in _labels:
		_labels[k].text = "%s%d" % [ICONS[k], resources.get(k, 0)]
