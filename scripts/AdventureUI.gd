extends CanvasLayer
class_name AdventureUI
## Adventure UI по prototype_map.html:
## верх: дата (рус) + NSWE + ресурсы + кнопки действий
## низ: герой (имя + статы inline + 👣) + тумблеры 🛡️⚔️ + 8 слотов армии + статус-строка

signal end_turn_pressed
signal date_changed(month: int, week: int, day: int)

var day := 1
var week := 1
var month := 1

var _date_label: Label
var _status_label: Label
var _stats_label: Label
var _mp_label: Label
var _army_slots: Array[Panel] = []
var _resource_labels: Dictionary = {}
var _hero_controller: HeroController


func _ready() -> void:
    layer = 10
    _build_top_panel()
    _build_bottom_panel()


func setup(hero: HeroController) -> void:
    _hero_controller = hero
    hero.movement_points_changed.connect(_on_mp_changed)
    hero.resources_changed.connect(_on_resources_changed)
    hero.path_previewed.connect(_on_path_preview)
    refresh_all()


# ===================== TOP =====================
func _build_top_panel() -> void:
    var p := PanelContainer.new()
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.09, 0.08, 0.16, 0.95)
    p.add_theme_stylebox_override("panel", s)
    p.set_anchors_preset(Control.PRESET_TOP_WIDE)
    p.offset_bottom = 56
    add_child(p)

    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 8)
    p.add_child(hb)

    # Дата (как в прототипе, по-русски)
    _date_label = Label.new()
    _date_label.text = _fmt_date()
    _date_label.add_theme_font_size_override("font_size", 20)
    _date_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
    hb.add_child(_date_label)

    hb.add_child(_spacer())

    # NSWE
    for d in ["N", "S", "W", "E"]:
        var b := Button.new()
        b.text = d
        b.custom_minimum_size = Vector2(32, 32)
        b.add_theme_font_size_override("font_size", 14)
        b.pressed.connect(_on_camera_jump.bind(d))
        hb.add_child(b)

    hb.add_child(_spacer())

    # Ресурсы (7 иконок со счётчиками)
    var res_icons := [
        ["wood", "🪵"], ["mercury", "🧪"], ["ore", "🪨"], ["sulfur", "🟡"],
        ["crystal", "🔷"], ["gems", "💎"], ["gold", "🪙"],
    ]
    for ri in res_icons:
        var l := Label.new()
        l.text = "%s 0" % ri[1]
        l.add_theme_font_size_override("font_size", 16)
        l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.7))
        hb.add_child(l)
        _resource_labels[ri[0]] = l

    hb.add_child(_spacer())

    # Кнопки действий (порядок как в прототипе)
    var btns := [
        ["🏰", "Замок"], ["🚩", "Флаг"], ["⛺", "Лагерь"], ["🐎", "Конюшня"],
        ["🚢", "Корабль"], ["⚒️", "Кузница"], ["🔍", "Разведка"], ["🪖", "Армия"],
        ["📜", "Журнал"], ["⏳", "Конец хода"], ["🏰", "Королевство"],
    ]
    for b in btns:
        var btn := Button.new()
        btn.text = b[0]
        btn.tooltip_text = b[1]
        btn.custom_minimum_size = Vector2(44, 40)
        btn.add_theme_font_size_override("font_size", 20)
        if b[1] == "Конец хода":
            btn.pressed.connect(_on_end_turn)
            btn.modulate = Color(1.0, 0.85, 0.4)
        hb.add_child(btn)


# ===================== BOTTOM =====================
func _build_bottom_panel() -> void:
    var p := PanelContainer.new()
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.09, 0.08, 0.16, 0.95)
    p.add_theme_stylebox_override("panel", s)
    p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    p.offset_top = -96
    add_child(p)

    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 10)
    p.add_child(hb)

    # Герой: имя + статы inline + очки движения
    var hv := VBoxContainer.new()
    hv.add_theme_constant_override("separation", 2)
    hb.add_child(hv)

    var nl := Label.new()
    nl.text = "Darkstorn"
    nl.add_theme_font_size_override("font_size", 20)
    nl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
    hv.add_child(nl)

    _stats_label = Label.new()
    _stats_label.text = "⚔️ 0 🛡️ 0 🔮 4 📖 2"
    _stats_label.add_theme_font_size_override("font_size", 16)
    hv.add_child(_stats_label)

    _mp_label = Label.new()
    _mp_label.text = "👣 20/20"
    _mp_label.add_theme_font_size_override("font_size", 14)
    _mp_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
    hv.add_child(_mp_label)

    # Тумблеры как в прототипе
    for t in ["🛡️", "⚔️"]:
        var b := Button.new()
        b.text = t
        b.custom_minimum_size = Vector2(36, 36)
        b.tooltip_text = "Панель героя"
        hb.add_child(b)

    hb.add_child(VSeparator.new())

    # 8 слотов армии
    for i in 8:
        var slot := Panel.new()
        slot.name = "Slot%d" % i
        slot.custom_minimum_size = Vector2(84, 76)
        var ss := StyleBoxFlat.new()
        ss.bg_color = Color(0.16, 0.14, 0.24)
        ss.set_corner_radius_all(4)
        ss.set_border_width_all(1)
        ss.border_color = Color(0.35, 0.3, 0.5)
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

    hb.add_child(_spacer())

    # Статус-строка (предпросмотр пути и т.п.)
    _status_label = Label.new()
    _status_label.text = ""
    _status_label.add_theme_font_size_override("font_size", 14)
    _status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
    hb.add_child(_status_label)


# ===================== REFRESH =====================
func refresh_all() -> void:
    if not _hero_controller:
        return
    var st: Dictionary = _hero_controller.stats
    _stats_label.text = "⚔️ %d 🛡️ %d 🔮 %d  %d" % [
        st.get("attack", 0), st.get("defense", 0),
        st.get("spell_power", 0), st.get("knowledge", 0)]
    for i in range(8):
        var vbox: VBoxContainer = _army_slots[i].get_node("VBox")
        var ic: Label = vbox.get_node("Icon")
        var ct: Label = vbox.get_node("Count")
        if i < _hero_controller.army.size():
            ic.text = _hero_controller.army[i]["icon"]
            ct.text = str(_hero_controller.army[i]["count"])
        else:
            ic.text = "-"
            ct.text = "0"
    _update_resources()


func _update_resources() -> void:
    if not _hero_controller:
        return
    var icons := {
        "wood": "🪵", "mercury": "🧪", "ore": "🪨", "sulfur": "🟡",
        "crystal": "🔷", "gems": "💎", "gold": "🪙",
    }
    for k in _resource_labels:
        _resource_labels[k].text = "%s %d" % [icons[k], _hero_controller.resources.get(k, 0)]


# ===================== SIGNALS =====================
func _on_mp_changed(cur: int, mx: int) -> void:
    if _mp_label:
        _mp_label.text = "👣 %d/%d" % [cur, mx]


func _on_resources_changed(_r: Dictionary) -> void:
    _update_resources()


func _on_path_preview(text: String) -> void:
    if _status_label:
        _status_label.text = text


# ===================== DATE / BUTTONS =====================
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
    return "Месяц: %d, Неделя: %d, День: %d" % [month, week, day]


func _on_end_turn() -> void:
    advance_day()
    end_turn_pressed.emit()


func _on_camera_jump(direction: String) -> void:
    var world := get_parent()
    if world and world.has_method("jump_camera"):
        world.jump_camera(direction)


func _spacer() -> Control:
    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return sp
