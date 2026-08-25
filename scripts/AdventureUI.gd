extends CanvasLayer
class_name AdventureUI

signal end_turn_pressed
signal date_changed(month: int, week: int, day: int)

var day: int = 1
var week: int = 1
var month: int = 1

var _date_label: Label
var _hero_panel: PanelContainer
var _army_slots: Array[Panel] = []
var _resource_labels: Dictionary = {}
var _stat_labels: Dictionary = {}
var _mp_label: Label
var _hero_controller: HeroController


func _ready() -> void:
    layer = 10
    _build_top_panel()
    _build_hero_panel()
    _build_army_panel()
    _build_resource_panel()


func setup(hero: HeroController) -> void:
    _hero_controller = hero
    hero.movement_points_changed.connect(_on_mp_changed)
    hero.resources_changed.connect(_on_resources_changed)
    refresh_all()


# ===================== TOP PANEL =====================
func _build_top_panel() -> void:
    var p := PanelContainer.new()
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.15, 0.12, 0.25, 0.9)
    s.set_corner_radius_all(4)
    p.add_theme_stylebox_override("panel", s)
    p.set_anchors_preset(Control.PRESET_TOP_WIDE)
    p.offset_bottom = 60
    add_child(p)
    
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 10)
    p.add_child(hb)
    
    # Дата
    _date_label = Label.new()
    _date_label.text = _fmt_date()
    _date_label.add_theme_font_size_override("font_size", 20)
    _date_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
    hb.add_child(_date_label)
    
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(sp)
    
    # Кнопки действий
    var btns := [
        ["🏰", "Castle"], ["🚩", "Flag"], ["⛺", "Camp"],
        ["🐎", "Stable"], ["🚢", "Ship"], ["⚒️", "Forge"],
        ["🔍", "Scout"], ["🪖", "Army"], ["📜", "Journal"],
        ["⏳", "End Turn"],
    ]
    for b in btns:
        var btn := Button.new()
        btn.text = b[0]
        btn.tooltip_text = b[1]
        btn.custom_minimum_size = Vector2(50, 44)
        btn.add_theme_font_size_override("font_size", 22)
        if b[1] == "End Turn":
            btn.pressed.connect(_on_end_turn)
            btn.modulate = Color(1.0, 0.85, 0.4)
        hb.add_child(btn)
    
    # Камера: N S W E
    for dir_name in ["N", "S", "W", "E"]:
        var btn := Button.new()
        btn.text = dir_name
        btn.custom_minimum_size = Vector2(36, 36)
        btn.add_theme_font_size_override("font_size", 16)
        btn.pressed.connect(_on_camera_jump.bind(dir_name))
        hb.add_child(btn)


# ===================== HERO PANEL =====================
func _build_hero_panel() -> void:
    _hero_panel = PanelContainer.new()
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.1, 0.1, 0.2, 0.85)
    s.set_corner_radius_all(6)
    s.set_border_width_all(2)
    s.border_color = Color(0.4, 0.35, 0.6)
    _hero_panel.add_theme_stylebox_override("panel", s)
    _hero_panel.offset_left = 10
    _hero_panel.offset_top = 70
    _hero_panel.offset_right = 250
    _hero_panel.offset_bottom = 350
    add_child(_hero_panel)
    
    var vb := VBoxContainer.new()
    vb.name = "VBox"
    vb.add_theme_constant_override("separation", 8)
    _hero_panel.add_child(vb)
    
    var nl := Label.new()
    nl.text = "Darkstorn"
    nl.add_theme_font_size_override("font_size", 22)
    nl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
    vb.add_child(nl)
    
    vb.add_child(HSeparator.new())
    
    var stats_data := [
        ["⚔️", "attack", "Attack"],
        ["🛡️", "defense", "Defense"],
        ["🔮", "spell_power", "Spell"],
        ["📖", "knowledge", "Know"],
    ]
    for sd in stats_data:
        var l := Label.new()
        l.name = sd[1]
        l.text = "%s %s: 0" % [sd[0], sd[2]]
        l.add_theme_font_size_override("font_size", 18)
        vb.add_child(l)
        _stat_labels[sd[1]] = l
    
    _mp_label = Label.new()
    _mp_label.name = "MP"
    _mp_label.text = "Move: 20/20"
    _mp_label.add_theme_font_size_override("font_size", 16)
    _mp_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
    vb.add_child(_mp_label)


# ===================== ARMY PANEL =====================
func _build_army_panel() -> void:
    var bp := PanelContainer.new()
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.12, 0.1, 0.18, 0.9)
    s.set_corner_radius_all(4)
    bp.add_theme_stylebox_override("panel", s)
    bp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bp.offset_top = -90
    add_child(bp)
    
    var hb := HBoxContainer.new()
    hb.name = "HBox"
    hb.alignment = BoxContainer.ALIGNMENT_CENTER
    hb.add_theme_constant_override("separation", 8)
    bp.add_child(hb)
    
    for i in 8:
        var slot := Panel.new()
        slot.name = "Slot%d" % i
        slot.custom_minimum_size = Vector2(90, 70)
        var ss := StyleBoxFlat.new()
        ss.bg_color = Color(0.2, 0.18, 0.28)
        ss.set_corner_radius_all(4)
        slot.add_theme_stylebox_override("panel", ss)
        
        var svb := VBoxContainer.new()
        svb.name = "VBox"
        svb.alignment = BoxContainer.ALIGNMENT_CENTER
        slot.add_child(svb)
        
        var ic := Label.new()
        ic.name = "Icon"
        ic.text = "-"
        ic.add_theme_font_size_override("font_size", 24)
        ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        svb.add_child(ic)
        
        var ct := Label.new()
        ct.name = "Count"
        ct.text = "0"
        ct.add_theme_font_size_override("font_size", 16)
        ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        ct.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
        svb.add_child(ct)
        
        hb.add_child(slot)
        _army_slots.append(slot)


# ===================== RESOURCE PANEL =====================
func _build_resource_panel() -> void:
    var rp := HBoxContainer.new()
    rp.name = "ResourcePanel"
    rp.set_anchors_preset(Control.PRESET_TOP_WIDE)
    rp.offset_top = 62
    rp.offset_bottom = 92
    rp.alignment = BoxContainer.ALIGNMENT_CENTER
    rp.add_theme_constant_override("separation", 20)
    add_child(rp)
    
    var res_icons := [
        ["wood", "🪵"], ["mercury", "🧪"], ["ore", "🪨"],
        ["sulfur", "🟡"], ["crystal", "🔷"], ["gems", "💎"], ["gold", "🪙"],
    ]
    for ri in res_icons:
        var l := Label.new()
        l.text = "%s 0" % ri[1]
        l.add_theme_font_size_override("font_size", 16)
        l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.7))
        rp.add_child(l)
        _resource_labels[ri[0]] = l


# ===================== REFRESH =====================
func refresh_all() -> void:
    if not _hero_controller:
        return
    
    # Статы
    for k in _stat_labels:
        _stat_labels[k].text = "%s: %d" % [k, _hero_controller.stats.get(k, 0)]
    
    # Армия
    for i in range(8):
        var slot: Panel = _army_slots[i]
        var vbox := slot.get_node("VBox")
        var ic: Label = vbox.get_node("Icon")
        var ct: Label = vbox.get_node("Count")
        if i < _hero_controller.army.size():
            ic.text = _hero_controller.army[i]["icon"]
            ct.text = str(_hero_controller.army[i]["count"])
        else:
            ic.text = "-"
            ct.text = "0"
    
    # Ресурсы
    _update_resources()


func _update_resources() -> void:
    if not _hero_controller:
        return
    var icons := {
        "wood": "🪵", "mercury": "🧪", "ore": "🪨",
        "sulfur": "🟡", "crystal": "🔷", "gems": "💎", "gold": "🪙",
    }
    for k in _resource_labels:
        _resource_labels[k].text = "%s %d" % [icons[k], _hero_controller.resources.get(k, 0)]


# ===================== SIGNALS =====================
func _on_mp_changed(cur: int, mx: int) -> void:
    if _mp_label:
        _mp_label.text = "Move: %d/%d" % [cur, mx]


func _on_resources_changed(res: Dictionary) -> void:
    _update_resources()


# ===================== DATE =====================
func advance_day() -> void:
    day += 1
    if day > 7:
        day = 1
        week += 1
        if week > 4:
            week = 1
            month += 1
    _date_label.text = _fmt_date()
    date_changed.emit(month, week, day)


func _fmt_date() -> String:
    return "Month: %d, Week: %d, Day: %d" % [month, week, day]


# ===================== BUTTON HANDLERS =====================
func _on_end_turn() -> void:
    advance_day()
    end_turn_pressed.emit()


func _on_camera_jump(direction: String) -> void:
    var world := get_parent()
    if world and world.has_method("jump_camera"):
        world.jump_camera(direction)
