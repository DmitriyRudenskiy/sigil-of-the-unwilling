class_name InfoPanel
extends VBoxContainer

const THEME_PATH := "res://assets/theme/game_theme.tres"
const C_TEXT := ThemeConfig.C_TEXT_PRIMARY
const C_GOLD := ThemeConfig.C_TEXT_GOLD

@onready var _date_label: Label = $date_label
@onready var _time_label: Label = $time_label
@onready var _status_label: Label = $status_label
@onready var _actions_grid: GridContainer = $actions
@onready var _end_turn_btn: Button = $actions/EndTurnButton
@onready var _options_btn: Button = $actions/OptionsButton

var _hero_slots: Array[Panel] = []
var _town_slots: Array[Panel] = []
var _theme: Theme = null

signal end_turn_pressed
signal options_requested

var day := 1
var week := 1
var month := 1

func _ready() -> void:
    add_theme_constant_override("separation", 6)
    _theme = load(THEME_PATH)
    _apply_theme()
    _collect_slots()
    _connect_buttons()
    (get_node("date_label") as Label).text = _fmt_date()
    for child in (get_node("actions") as Control).get_children():
        if child is Button:
            (child as Button).tooltip_text = GameText.info_tooltip(child.name)

func _apply_theme() -> void:
    if _theme == null:
        return
    var sb := _theme.get_stylebox("slot", "Panel")
    if sb == null:
        return
    for slot in _get_slot_nodes():
        slot.add_theme_stylebox_override("panel", sb)

func _get_slot_nodes() -> Array:
    var out: Array[Panel] = []
    for i in 4:
        var h := get_node_or_null("columns/hero_col/hero_slot_%d" % i)
        if h is Panel:
            out.append(h)
    var t: Array[Panel] = []
    for i in 4:
        var v := get_node_or_null("columns/town_col/town_slot_%d" % i)
        if v is Panel:
            t.append(v)
    return out + t

func _collect_slots() -> void:
    _hero_slots = []
    _town_slots = []
    for i in 4:
        var h := get_node_or_null("columns/hero_col/hero_slot_%d" % i)
        if h is Panel:
            _hero_slots.append(h)
        var t := get_node_or_null("columns/town_col/town_slot_%d" % i)
        if t is Panel:
            _town_slots.append(t)

func _connect_buttons() -> void:
    _end_turn_btn.pressed.connect(func(): end_turn_pressed.emit())
    _end_turn_btn.modulate = C_GOLD
    _options_btn.pressed.connect(func(): options_requested.emit())

func set_time(hour: float) -> void:
    var h := int(floor(hour))
    var m := int(round((hour - floor(hour)) * 60))
    _time_label.text = "🕐 %02d:%02d" % [h, m]
    if hour >= 21.0:
        _time_label.add_theme_color_override("font_color", ThemeConfig.C_TIME_NIGHT)
    elif hour >= 17.0:
        _time_label.add_theme_color_override("font_color", ThemeConfig.C_TIME_EVENING)
    elif hour >= 11.0:
        _time_label.add_theme_color_override("font_color", ThemeConfig.C_TIME_NOON)
    else:
        _time_label.add_theme_color_override("font_color", ThemeConfig.C_TIME_DAY)

func set_status(text: String) -> void:
    _status_label.text = text

func set_status_colored(text: String, color: Color) -> void:
    _status_label.text = text
    _status_label.add_theme_color_override("font_color", color)

func advance_day() -> void:
    day += 1
    if day > 7:
        day = 1
        week += 1
        if week > 4:
            week = 1
            month += 1
    _date_label.text = _fmt_date()

func set_date(m: int, w: int, d: int) -> void:
    month = max(1, m)
    week = max(1, min(4, w))
    day = max(1, min(7, d))
    _date_label.text = _fmt_date()

func add_city(city_name: String) -> void:
    for i in _town_slots.size():
        var slot := get_node_or_null("columns/town_col/town_slot_%d" % i)
        if slot == null:
            continue
        if slot.get_child_count() == 0:
            var icon_node := slot.get_node_or_null("Icon")
            var name_node := slot.get_node_or_null("Name")
            if icon_node != null:
                icon_node.visible = false
            if name_node != null:
                name_node.text = "🏰 " + city_name
                name_node.add_theme_color_override("font_color", C_TEXT)
                name_node.clip_text = true
            return

func fill_hero_slot(idx: int, hero: HeroController) -> void:
    if idx >= _hero_slots.size():
        return
    var slot := get_node_or_null("columns/hero_col/hero_slot_%d" % idx)
    if slot == null:
        return
    var avatar_node := slot.get_node_or_null("Avatar") as TextureRect
    var name_node := slot.get_node_or_null("Name") as Label
    var av: Texture2D = hero.get_avatar_texture()
    if avatar_node != null:
        avatar_node.texture = av
        avatar_node.visible = av != null
    if name_node != null:
        name_node.text = hero.hero_name
        name_node.add_theme_color_override("font_color", C_GOLD)
        name_node.clip_text = true

func _fmt_date() -> String:
    return GameText.info_date(month, week, day)
