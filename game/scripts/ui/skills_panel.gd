extends PanelContainer
class_name SkillsPanel

var _skill_order := [&"nature_sense", &"keen_eye", &"navigation", &"geology", &"alchemy"]
var _level_labels: Dictionary = {}

func _ready() -> void:
    var title := $VBox/Title as Label
    title.add_theme_font_size_override("font_size", 14)
    title.text = GameText.skills_title()
    var container := $VBox/SkillContainer as VBoxContainer
    var row_names := {
        &"nature_sense": "NatureSenseRow",
        &"keen_eye": "KeenEyeRow",
        &"navigation": "NavigationRow",
        &"geology": "GeologyRow",
        &"alchemy": "AlchemyRow",
    }
    for skill in _skill_order:
        var row_name: String = row_names.get(skill, "")
        if row_name.is_empty():
            continue
        var row := container.get_node(row_name) as HBoxContainer
        if row == null:
            continue
        var name_label := row.get_node("NameLabel") as Label
        if name_label != null:
            name_label.add_theme_font_size_override("font_size", 12)
            name_label.text = GameText.skill_name(skill)
        var level_label := row.get_node("LevelLabel") as Label
        if level_label != null:
            level_label.add_theme_font_size_override("font_size", 12)
            _level_labels[skill] = level_label

func update_skills(skills: Dictionary) -> void:
    for skill in _skill_order:
        var level: int = int(skills.get(skill, 0))
        if _level_labels.has(skill):
            _level_labels[skill].text = "%d/3" % level
