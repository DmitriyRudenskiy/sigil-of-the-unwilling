class_name CharacterCreationUI
extends Control

const _Races = preload("res://scripts/data/hero_races.gd")
const _Classes = preload("res://scripts/data/hero_classes.gd")
const _Cultures = preload("res://scripts/data/hero_cultures.gd")
const _Profile = preload("res://scripts/data/HeroBuildProfile.gd")
const _WORLD_SCENE := "res://scenes/World.tscn"
const _MENU_SCENE := "res://scenes/MainMenu.tscn"
static func _sexes() -> Array:
    return [{"id": "male", "name": GameText.creation_sex_male()},
            {"id": "female", "name": GameText.creation_sex_female()}]

@onready var _root: VBoxContainer = $Overlay/Scroll/Root
@onready var _name_edit: LineEdit = $Overlay/Scroll/Root/NameRow/NameEdit
@onready var _sex_option: OptionButton = $Overlay/Scroll/Root/SexRow/SexOption
@onready var _race_option: OptionButton = $Overlay/Scroll/Root/RaceRow/RaceOption
@onready var _subrace_option: OptionButton = $Overlay/Scroll/Root/SubraceRow/SubraceOption
@onready var _class_option: OptionButton = $Overlay/Scroll/Root/ClassRow/ClassOption
@onready var _culture_option: OptionButton = $Overlay/Scroll/Root/CultureRow/CultureOption
@onready var _background_option: OptionButton = $Overlay/Scroll/Root/BackgroundRow/BackgroundOption
@onready var _summary_label: Label = $Overlay/Scroll/Root/SummaryLabel
@onready var _create_btn: Button = $Overlay/Scroll/Root/ButtonsRow/CreateButton
@onready var _back_btn: Button = $Overlay/Scroll/Root/ButtonsRow/BackButton

var _profile: _Profile = _Profile.new()
var _sex_keys: Array = []
var _race_keys: Array = []
var _class_keys: Array = []
var _culture_keys: Array = []
var _background_keys: Array = []
var _subrace_keys: Array = []

func _ready() -> void:
    _localize()
    _populate_options()
    _connect_signals()
    _update_summary()

func _localize() -> void:
    _root.get_node("TitleLabel").text = GameText.creation_title()
    _root.get_node("SubtitleLabel").text = GameText.creation_subtitle()
    _root.get_node("NameRow/NameLabelNode").text = GameText.creation_name_label()
    _name_edit.placeholder_text = GameText.creation_name_placeholder()
    _root.get_node("SexRow/SexLabelNode").text = GameText.creation_sex_label()
    _root.get_node("RaceRow/RaceLabelNode").text = GameText.creation_race_label()
    _root.get_node("SubraceRow/SubraceLabelNode").text = GameText.creation_subrace_label()
    _root.get_node("ClassRow/ClassLabelNode").text = GameText.creation_class_label()
    _root.get_node("CultureRow/CultureLabelNode").text = GameText.creation_culture_label()
    _root.get_node("BackgroundRow/BackgroundLabelNode").text = GameText.creation_background_label()
    _create_btn.text = GameText.creation_create()
    _back_btn.text = GameText.creation_back()

func _populate_options() -> void:

    for item in _sexes():
        _sex_option.add_item(item["name"])
        _sex_keys.append(item["id"])

    var race_data := _keys_labels(_Races.RACES)
    for item in race_data:
        _race_option.add_item(item["name"])
        _race_keys.append(item["id"])

    _subrace_option.add_item("—")
    _subrace_option.disabled = true

    var class_data := _keys_labels(_Classes.CLASSES)
    for item in class_data:
        _class_option.add_item(item["name"])
        _class_keys.append(item["id"])

    var culture_data := _keys_labels(_Cultures.CULTURES)
    for item in culture_data:
        _culture_option.add_item(item["name"])
        _culture_keys.append(item["id"])

    var bg_data := _keys_labels(_Cultures.BACKGROUNDS)
    for item in bg_data:
        _background_option.add_item(item["name"])
        _background_keys.append(item["id"])

func _connect_signals() -> void:
    _name_edit.text_changed.connect(func(_v): _on_change())
    _sex_option.item_selected.connect(func(_i): _on_change())
    _race_option.item_selected.connect(_on_race_changed)
    _subrace_option.item_selected.connect(func(_i): _on_change())
    _class_option.item_selected.connect(func(_i): _on_change())
    _culture_option.item_selected.connect(func(_i): _on_change())
    _background_option.item_selected.connect(func(_i): _on_change())
    _create_btn.pressed.connect(_on_create)
    _back_btn.pressed.connect(_on_back)

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
            _subrace_keys.append(sub.get("id", ""))
    _profile.subrace = subraces[0].get("id", "") if not subraces.is_empty() else ""
    _on_change()

func _on_change(_value: Variant = 0) -> void:
    _profile.name = _name_edit.text
    _profile.sex = _sex_keys[_sex_option.selected] if _sex_option.selected >= 0 else ""
    _profile.race = _race_keys[_race_option.selected] if _race_option.selected >= 0 else ""
    _profile.character_class = _class_keys[_class_option.selected] if _class_option.selected >= 0 else ""
    _profile.culture = _culture_keys[_culture_option.selected] if _culture_option.selected >= 0 else ""
    _profile.background = _background_keys[_background_option.selected] if _background_option.selected >= 0 else ""
    if _subrace_option.selected >= 0 and _subrace_option.get_item_text(_subrace_option.selected) != "—":
        _profile.subrace = _subrace_option.get_item_text(_subrace_option.selected)
    else:
        _profile.subrace = ""
    _update_summary()

func _on_create() -> void:
    if not _profile.is_valid():
        return
    var persistence: WorldPersistence = Services.resolve(&"persistence")
    persistence.pending_new_game = _profile
    get_tree().change_scene_to_file(_WORLD_SCENE)

func _on_back() -> void:
    get_tree().change_scene_to_file(_MENU_SCENE)

func _update_summary() -> void:
    var s: Dictionary = _profile.summary()
    var stats: Dictionary = s["stats"]
    var lines := [
        "%s  ·  %s" % [s["name"], s["sex"]],
        "%s · %s · %s · %s" % [s["name"], s["subrace"] if s["subrace"] != "" else "—", s["class"], s["culture"]],
        GameText.creation_background_value(str(s["background"])),
        GameText.creation_stats(
            int(stats.get("attack", 0)), int(stats.get("defense", 0)),
            int(stats.get("spell_power", 0)), int(stats.get("knowledge", 0))),
    ]
    _summary_label.text = "\n".join(lines)

func _keys_labels(table: Dictionary) -> Array:
    var out: Array = []
    for k in table:
        out.append({"id": k, "name": table[k].get("name", k)})
    return out
