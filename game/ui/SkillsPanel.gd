extends PanelContainer
class_name SkillsPanel
## Displays hero skills with levels.

var _labels: Dictionary = {}
var _skill_order := [&"nature_sense", &"keen_eye", &"navigation", &"geology", &"alchemy"]
var _skill_names := {
	&"nature_sense": "Чувство Природы",
	&"keen_eye": "Зоркий Взор",
	&"navigation": "Навигация",
	&"geology": "Геология",
	&"alchemy": "Алхимия",
}


func _ready() -> void:
	custom_minimum_size = Vector2(160, 0)
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "🔮 Навыки"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	for skill in _skill_order:
		var hbox := HBoxContainer.new()
		vbox.add_child(hbox)

		var name_label := Label.new()
		name_label.text = _skill_names.get(skill, skill)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.custom_minimum_size = Vector2(100, 0)
		hbox.add_child(name_label)

		var level_label := Label.new()
		level_label.text = "0/3"
		level_label.add_theme_font_size_override("font_size", 12)
		hbox.add_child(level_label)

		_labels[skill] = level_label


func update_skills(skills: Dictionary) -> void:
	for skill in _skill_order:
		var level: int = int(skills.get(skill, 0))
		if _labels.has(skill):
			_labels[skill].text = "%d/3" % level
