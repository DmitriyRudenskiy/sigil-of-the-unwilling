class_name CharacterCreationUI
extends Control
## Конструктор героя (RU). Порт GAMES_TROLES CharacterCreationUI под
## систему характеристик проекта. Всё поле — обобщённо по ключам реестров
## hero_races / hero_classes / hero_cultures: замена содержания не ломает UI.
##
## «Создать» → HeroBuildProfile → WorldPersistence.pending_new_game → World.tscn.
## «Назад» → MainMenu.tscn. Звук на этом экране не играем (headless-safe).

const _Races = preload("res://scripts/data/hero_races.gd")
const _Classes = preload("res://scripts/data/hero_classes.gd")
const _Cultures = preload("res://scripts/data/hero_cultures.gd")
const _Profile = preload("res://scripts/data/HeroBuildProfile.gd")

const _WORLD_SCENE := "res://scenes/World.tscn"
const _MENU_SCENE := "res://scenes/MainMenu.tscn"
const _SEXES := [{"id": "male", "name": "Мужской"}, {"id": "female", "name": "Женский"}]

@onready var _root: VBoxContainer = $Overlay/Scroll/Root
var _profile: _Profile = _Profile.new()

var _name_edit: LineEdit
var _sex_option: OptionButton
var _race_option: OptionButton
var _subrace_option: OptionButton
var _class_option: OptionButton
var _culture_option: OptionButton
var _background_option: OptionButton
var _summary_label: Label
var _row_spacing := 8
# Ключи реестров по индексам в соответствующих OptionButton (профиль хранит
# ключи «dwarf», а не названия «Дварф»: get_stats ищет по ключу).
var _sex_keys: Array = []
var _race_keys: Array = []
var _class_keys: Array = []
var _culture_keys: Array = []
var _background_keys: Array = []
var _subrace_keys: Array = []

func _ready() -> void:
	_build()

# ==================== BUILD (data-driven) ====================

func _build() -> void:
	_add_styled(_root, "Label", "Создание героя", 20, HORIZONTAL_ALIGNMENT_CENTER)
	_add_styled(_root, "Label", "Выберите облик героя для новой игры", 12, HORIZONTAL_ALIGNMENT_CENTER)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Имя героя"
	_name_edit.text = "Darkstorn"
	_name_edit.max_length = 32
	_add_field("Имя:", _name_edit)
	_name_edit.text_changed.connect(_on_change)

	_sex_option = _make_option(_SEXES, "Мужской", _sex_keys)
	_add_field("Пол:", _sex_option)

	_race_option = _make_option(_keys_labels(_Races.RACES), _Races.RACES.keys()[0], _race_keys)
	_race_option.item_selected.connect(_on_race_changed)
	_add_field("Расa:", _race_option)

	_subrace_option = _make_option([], "", _subrace_keys)
	_subrace_option.item_selected.connect(_on_change)
	_add_field("Подраса:", _subrace_option)

	_class_option = _make_option(_keys_labels(_Classes.CLASSES), _Classes.CLASSES.keys()[0], _class_keys)
	_class_option.item_selected.connect(_on_change)
	_add_field("Класс:", _class_option)

	_culture_option = _make_option(_keys_labels(_Cultures.CULTURES), _Cultures.CULTURES.keys()[0], _culture_keys)
	_culture_option.item_selected.connect(_on_change)
	_add_field("Культура:", _culture_option)

	_background_option = _make_option(_keys_labels(_Cultures.BACKGROUNDS), _Cultures.BACKGROUNDS.keys()[0], _background_keys)
	_background_option.item_selected.connect(_on_change)
	_add_field("Прошлое:", _background_option)

	_root.add_spacer(8)
	_summary_label = _add_styled(_root, "Label", "", 12, HORIZONTAL_ALIGNMENT_LEFT)
	_summary_label.custom_minimum_size = Vector2(640, 96)
	_root.add_spacer(8)

	var buttons_row := HBoxContainer.new()
	_root.add_child(buttons_row)
	buttons_row.add_spacer(1)

	var create_btn := _instantiate("Button")
	create_btn.text = "Создать"
	create_btn.pressed.connect(_on_create)
	buttons_row.add_child(create_btn)

	var back_btn := _instantiate("Button")
	back_btn.text = "Назад"
	back_btn.pressed.connect(_on_back)
	buttons_row.add_child(back_btn)

	buttons_row.add_spacer(1)
	_update_summary()

func _on_race_changed(_idx: int) -> void:
	var key: String = _race_keys[_race_option.selected]
	var subraces: Array = _Races.RACES.get(key, {}).get("subraces", [])
	_subrace_option.clear()
	_subrace_keys.clear()
	if subraces.is_empty():
		_subrace_option.set_disabled(true)
		_subrace_option.add_item("—")
	else:
		_subrace_option.set_disabled(false)
		for sub in subraces:
			_subrace_option.add_item(sub.get("name", sub.get("id", "")))
		_profile.subrace = subraces[0].get("id", "")
	_on_change()

func _on_change(_value: Variant = 0) -> void:
	_profile.name = _name_edit.text
	_profile.sex = _sex_keys[_sex_option.selected]
	_profile.race = _race_keys[_race_option.selected]
	_profile.character_class = _class_keys[_class_option.selected]
	_profile.culture = _culture_keys[_culture_option.selected]
	_profile.background = _background_keys[_background_option.selected]
	_profile.subrace = _subrace_option.get_item_text(_subrace_option.selected)
	if _subrace_option.get_item_text(_subrace_option.selected) == "—":
		_profile.subrace = ""
	_update_summary()

func _on_create() -> void:
	if not _profile.is_valid():
		return
	WorldPersistence.pending_new_game = _profile
	get_tree().change_scene_to_file(_WORLD_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(_MENU_SCENE)

func _update_summary() -> void:
	var s: Dictionary = _profile.summary()
	var stats: Dictionary = s["stats"]
	var lines := [
		"%s  ·  %s" % [s["name"], s["sex"]],
		"%s · %s · %s · %s" % [s["name"], s["subrace"] if s["subrace"] != "" else "—", s["class"], s["culture"]],
		"Прошлое: %s" % s["background"],
		"Силы: Ур=%d  Защ=%d  Маг=%d  Муд=%d" % [
			int(stats.get("attack", 0)), int(stats.get("defense", 0)),
			int(stats.get("spell_power", 0)), int(stats.get("knowledge", 0))],
	]
	_summary_label.text = "\n".join(lines)

# ==================== HELPERS ====================

func _keys_labels(table: Dictionary) -> Array:
	var out: Array = []
	for k in table:
		out.append({"id": k, "name": table[k].get("name", k)})
	return out

## ponytail: ключи заполняются в keys_target по индексам; профиль хранит
## ключи («dwarf»), а не названия («Дварф»): get_stats ищет по ключу.
func _make_option(items: Array, default_id: String, keys_target: Array) -> OptionButton:
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(it.get("name", it))
		keys_target.append(it.get("id", it))
	ob.selected = _index_of_id(items, default_id)
	return ob

func _index_of_id(items: Array, default_id: String) -> int:
	for i in items.size():
		if items[i].get("id", "") == default_id:
			return i
	return 0

func _add_field(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(720, 28)
	row.add_theme_constant_override("separation", _row_spacing)
	_add_child(_root, row)
	_add_styled(row, "Label", label_text, 14, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(control)

func _add_styled(parent: Control, type_name: String, text: String, size: int, align: int) -> Control:
	var c := _instantiate(type_name)
	c.add_theme_font_size_override("font_size", size)
	c.horizontal_alignment = align
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_child(parent, c)
	return c

func _instantiate(type_name: String) -> Control:
	match type_name:
		"Label":
			return Label.new()
		"Button":
			return Button.new()
		"HBoxContainer":
			return HBoxContainer.new()
		_:
			return Control.new()

func _add_child(parent: Control, child: Control) -> void:
	parent.add_child(child)
