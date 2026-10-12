class_name SignChoiceUI
extends Control

## T-002 «Выбор знака»: экран выбора 1 из 8 Знаков на всю игру (Q18, D12;
## каталог — data/signs.json, docs/02c-signs.md). Протагонист = Носитель (R1).
## Выбор кладётся в WorldPersistence.pending_sign_id и уходит в кампанию
## (main.gd → CampaignComposition.sign_id → сейв-секция "sign").

const _CAMPAIGN_SCENE := "res://scenes/main/main.tscn"  # тот же срез, что у CharacterCreationUI (D-157)
const _MENU_SCENE := "res://scenes/main_menu.tscn"

var _selected: String = ""


func _ready() -> void:
	_build()


func selected_id() -> String:
	return _selected


func _build() -> void:
	var root: VBoxContainer = $Overlay/Scroll/Root
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Выбор Знака"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = "Знак выбирается один раз — на всю игру. Ты — Носитель."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	for sign in Signs.all():
		var btn := Button.new()
		btn.name = "Sign_%s" % sign.get("id", "")
		btn.text = "%s %s — «%s»" % [sign.get("glyph", ""), sign.get("name", ""), sign.get("motto", "")]
		btn.pressed.connect(_on_sign_pressed.bind(str(sign.get("id", ""))))
		root.add_child(btn)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Назад"
	back.pressed.connect(_on_back)
	root.add_child(back)


func _on_sign_pressed(id: String) -> void:
	if not Signs.is_valid(id):
		return
	_selected = id
	var persistence: WorldPersistence = Services.resolve(&"persistence")
	persistence.pending_sign_id = id
	get_tree().change_scene_to_file(_CAMPAIGN_SCENE)


func _on_back() -> void:
	get_tree().change_scene_to_file(_MENU_SCENE)
