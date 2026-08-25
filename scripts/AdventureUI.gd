extends CanvasLayer
class_name AdventureUI

signal end_turn_pressed
signal date_changed(month: int, week: int, day: int)

const RIGHT_W := 244
const BOTTOM_H := 252
const C_BG := Color(0.16, 0.11, 0.06, 0.95)
const C_BORDER := Color(0.62, 0.47, 0.22)
const C_TEXT := Color(0.95, 0.89, 0.72)
const C_GOLD := Color(1.0, 0.85, 0.4)
const C_SLOT_BG := Color(0.22, 0.16, 0.10)
const MINIMAP_COLORS := [
    Color(0.15, 0.35, 0.75), Color(0.85, 0.75, 0.45), Color(0.35, 0.6, 0.3),
    Color(0.15, 0.35, 0.15), Color(0.45, 0.4, 0.35), Color(0.9, 0.93, 0.98),
]

var day := 1
var week := 1
var month := 1

var _date_label: Label
var _status_label: Label
var _stats_label: Label
var _mp_label: Label
var _army_slots: Array[Panel] = []
var _resource_labels: Dictionary = {}
var _city_list: VBoxContainer
var _city_placeholder: Label
var _hero_list: VBoxContainer
var _hero_controller: HeroController
var _minimap_tex_rect: TextureRect
var _minimap_overlay: MinimapOverlay


class MinimapOverlay extends Control:
    signal minimap_clicked(cell: Vector2i)
    var map_ref: MapGenerator
    var hero_ref: HeroController
    var cam_ref: Camera2D

    func _process(_d: float) -> void:
        queue_redraw()

    func _draw() -> void:
        if map_ref == null:
            return
        var s := size / Vector2(map_ref.map_width, map_ref.map_height)
        if cam_ref != null and map_ref._tile_map != null and map_ref._tile_map.tile_set != null:
            var view_sz := get_viewport().get_visible_rect().size / cam_ref.zoom
            var top_left := cam_ref.position - view_sz / 2.0
            var c0 := map_ref._tile_map.local_to_map(top_left)
            var c1 := map_ref._tile_map.local_to_map(top_left + view_sz)
            draw_rect(Rect2(c0.x * s.x, c0.y * s.y, (c1.x - c0.x) * s.x, (c1.y - c0.y) * s.y),
                Color(1, 1, 1, 0.8), false, 1.0)
        if hero_ref != null:
            var cell := hero_ref.current_cell
            draw_rect(Rect2(cell.x * s.x - 2, cell.y * s.y - 2, 4, 4), Color(1.0, 0.85, 0.4))

    func _gui_input(ev: InputEvent) -> void:
        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
            if map_ref == null:
                return
            var s := size / Vector2(map_ref.map_width, map_ref.map_height)
            var cell := Vector2i(int(ev.position.x / s.x), int(ev.position.y / s.y))
            minimap_clicked.emit(cell)


func _ready() -> void:
    layer = 10
    _build_right_column()
    _build_bottom_panel()


func setup(hero: HeroController) -> void:
    _hero_controller = hero
    hero.movement_points_changed.connect(_on_mp_changed)
    hero.resources_changed.connect(_on_resources_changed)
    hero.path_previewed.connect(_on_path_preview)
    _minimap_overlay.map_ref = hero._map_gen
    _minimap_overlay.hero_ref = hero
    var world := get_parent()
    if world and world.has_method("get_camera"):
        _minimap_overlay.cam_ref = world.get_camera()
    _minimap_overlay.minimap_clicked.connect(_on_minimap_clicked)
    _build_minimap_image(hero._map_gen)
    _fill_hero_list(hero)
    refresh_all()


func _panel_style() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = C_BG
    s.set_border_width_all(2)
    s.border_color = C_BORDER
    return s


func _btn(icon: String, tip: String, h: float) -> Button:
    var btn := Button.new()
    btn.text = icon
    btn.tooltip_text = tip
    btn.custom_minimum_size = Vector2(0, h)
    btn.add_theme_font_size_override("font_size", 16)
    if tip == "Конец хода":
        btn.pressed.connect(_on_end_turn)
        btn.modulate = C_GOLD
    return btn


# ===================== ПРАВАЯ КОЛОНКА =====================
func _build_right_column() -> void:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _panel_style())
    p.anchor_left = 1.0
    p.anchor_right = 1.0
    p.anchor_top = 0.0
    p.anchor_bottom = 1.0
    p.offset_left = -RIGHT_W
    p.offset_right = 0
    add_child(p)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 6)
    p.add_child(vb)

    _date_label = Label.new()
    _date_label.text = _fmt_date()
    _date_label.add_theme_font_size_override("font_size", 16)
    _date_label.add_theme_color_override("font_color", C_TEXT)
    _date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(_date_label)

    # Миникарта с NSWE крестом
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 4)
    vb.add_child(grid)

    var mm_size := RIGHT_W - 100
    grid.add_child(_cell_spacer())
    grid.add_child(_nswe("N"))
    grid.add_child(_cell_spacer())
    grid.add_child(_nswe("W"))

    var box := Control.new()
    box.custom_minimum_size = Vector2(mm_size, mm_size)
    grid.add_child(box)
    _minimap_tex_rect = TextureRect.new()
    _minimap_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _minimap_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
    box.add_child(_minimap_tex_rect)
    _minimap_overlay = MinimapOverlay.new()
    _minimap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    box.add_child(_minimap_overlay)

    grid.add_child(_nswe("E"))
    grid.add_child(_cell_spacer())
    grid.add_child(_nswe("S"))
    grid.add_child(_cell_spacer())

    _status_label = Label.new()
    _status_label.text = ""
    _status_label.add_theme_font_size_override("font_size", 13)
    _status_label.add_theme_color_override("font_color", C_TEXT)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(_status_label)

    vb.add_child(_vspacer())

    # Герой
    var hv := VBoxContainer.new()
    hv.add_theme_constant_override("separation", 2)
    vb.add_child(hv)
    var nl := Label.new()
    nl.text = "Darkstorn"
    nl.add_theme_font_size_override("font_size", 19)
    nl.add_theme_color_override("font_color", C_GOLD)
    hv.add_child(nl)
    _stats_label = Label.new()
    _stats_label.text = "⚔️ 0 🛡️ 0 🔮 4  2"
    _stats_label.add_theme_font_size_override("font_size", 15)
    _stats_label.add_theme_color_override("font_color", C_TEXT)
    hv.add_child(_stats_label)
    _mp_label = Label.new()
    _mp_label.text = "👣 20/20"
    _mp_label.add_theme_font_size_override("font_size", 13)
    _mp_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
    hv.add_child(_mp_label)

    # Армия 2x4
    var ag := GridContainer.new()
    ag.columns = 2
    ag.add_theme_constant_override("h_separation", 6)
    ag.add_theme_constant_override("v_separation", 6)
    vb.add_child(ag)
    for i in 8:
        var slot := Panel.new()
        slot.name = "Slot%d" % i
        slot.custom_minimum_size = Vector2(104, 40)
        var ss := StyleBoxFlat.new()
        ss.bg_color = C_SLOT_BG
        ss.set_corner_radius_all(4)
        ss.set_border_width_all(1)
        ss.border_color = C_BORDER
        slot.add_theme_stylebox_override("panel", ss)
        var sh := HBoxContainer.new()
        sh.name = "HBox"
        sh.alignment = BoxContainer.ALIGNMENT_CENTER
        sh.add_theme_constant_override("separation", 6)
        slot.add_child(sh)
        var ic := Label.new()
        ic.name = "Icon"
        ic.text = "-"
        ic.add_theme_font_size_override("font_size", 17)
        sh.add_child(ic)
        var ct := Label.new()
        ct.name = "Count"
        ct.text = "0"
        ct.add_theme_font_size_override("font_size", 14)
        ct.add_theme_color_override("font_color", C_TEXT)
        sh.add_child(ct)
        ag.add_child(slot)
        _army_slots.append(slot)


func _nswe(d: String) -> Button:
    var b := Button.new()
    b.text = d
    b.custom_minimum_size = Vector2(40, 26)
    b.add_theme_font_size_override("font_size", 13)
    b.pressed.connect(_on_camera_jump.bind(d))
    return b


func _cell_spacer() -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(40, 26)
    return c


# ===================== НИЗ: 4 КОЛОНКИ =====================
func _build_bottom_panel() -> void:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _panel_style())
    p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    p.offset_top = -BOTTOM_H
    p.offset_right = -RIGHT_W
    add_child(p)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 4)
    p.add_child(outer)

    # Ресурсы (перенесены сюда из правой колонки)
    var rh := HBoxContainer.new()
    rh.add_theme_constant_override("separation", 14)
    outer.add_child(rh)
    var res_icons := [
        ["wood", "🪵"], ["mercury", "🧪"], ["ore", "🪨"], ["sulfur", "🟡"],
        ["crystal", "🔷"], ["gems", "💎"], ["gold", "🪙"],
    ]
    for ri in res_icons:
        var l := Label.new()
        l.text = "%s 0" % ri[1]
        l.add_theme_font_size_override("font_size", 14)
        l.add_theme_color_override("font_color", C_TEXT)
        rh.add_child(l)
        _resource_labels[ri[0]] = l

    outer.add_child(HSeparator.new())

    var cols := HBoxContainer.new()
    cols.add_theme_constant_override("separation", 10)
    outer.add_child(cols)

    # Колонка 1: аватарки героев
    var c1 := VBoxContainer.new()
    cols.add_child(c1)
    var t1 := Label.new()
    t1.text = "Герои"
    t1.add_theme_font_size_override("font_size", 14)
    t1.add_theme_color_override("font_color", C_GOLD)
    c1.add_child(t1)
    _hero_list = VBoxContainer.new()
    _hero_list.add_theme_constant_override("separation", 4)
    c1.add_child(_hero_list)

    # Колонка 2: кнопки управления (часть 1)
    var c2 := VBoxContainer.new()
    c2.add_theme_constant_override("separation", 4)
    cols.add_child(c2)
    for b in [["🏰", "Замок"], ["🚩", "Флаг"], ["⛺", "Лагерь"], ["🐎", "Конюшня"], ["🚢", "Корабль"], ["⚒️", "Кузница"]]:
        c2.add_child(_btn(b[0], b[1], 30))

    # Колонка 3: кнопки управления (часть 2)
    var c3 := VBoxContainer.new()
    c3.add_theme_constant_override("separation", 4)
    cols.add_child(c3)
    for b in [["🔍", "Разведка"], ["🪖", "Армия"], ["📜", "Журнал"], ["⏳", "Конец хода"], ["🏰", "Королевство"]]:
        c3.add_child(_btn(b[0], b[1], 30))

    # Колонка 4: города
    var c4 := VBoxContainer.new()
    cols.add_child(c4)
    var t4 := Label.new()
    t4.text = "Города"
    t4.add_theme_font_size_override("font_size", 14)
    t4.add_theme_color_override("font_color", C_GOLD)
    c4.add_child(t4)
    _city_list = VBoxContainer.new()
    _city_list.add_theme_constant_override("separation", 4)
    c4.add_child(_city_list)
    _city_placeholder = Label.new()
    _city_placeholder.text = "— нет городов —"
    _city_placeholder.add_theme_font_size_override("font_size", 13)
    _city_placeholder.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    _city_list.add_child(_city_placeholder)


func _fill_hero_list(hero: HeroController) -> void:
    var entry := HBoxContainer.new()
    entry.add_theme_constant_override("separation", 6)
    _hero_list.add_child(entry)
    var av := hero.get_avatar_texture()
    if av != null:
        var tr := TextureRect.new()
        tr.texture = av
        tr.custom_minimum_size = Vector2(48, 48)
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        entry.add_child(tr)
    else:
        var em := Label.new()
        em.text = "🧙"
        em.add_theme_font_size_override("font_size", 28)
        entry.add_child(em)
    var nm := Label.new()
    nm.text = hero.hero_name
    nm.add_theme_font_size_override("font_size", 14)
    nm.add_theme_color_override("font_color", C_TEXT)
    entry.add_child(nm)


func add_city(city_name: String) -> void:
    if _city_placeholder != null and is_instance_valid(_city_placeholder):
        _city_placeholder.queue_free()
        _city_placeholder = null
    var l := Label.new()
    l.text = "🏰 %s" % city_name
    l.add_theme_font_size_override("font_size", 14)
    l.add_theme_color_override("font_color", C_TEXT)
    _city_list.add_child(l)


# ===================== MINIMAP / REFRESH =====================
func _build_minimap_image(map: MapGenerator) -> void:
    if map == null:
        return
    var img := Image.create(map.map_width, map.map_height, false, Image.FORMAT_RGBA8)
    for y in map.map_height:
        for x in map.map_width:
            var t: int = map.terrain_grid.get(Vector2i(x, y), 0)
            img.set_pixel(x, y, MINIMAP_COLORS[t])
    _minimap_tex_rect.texture = ImageTexture.create_from_image(img)


func _on_minimap_clicked(cell: Vector2i) -> void:
    var world := get_parent()
    if world and world.has_method("center_camera_on"):
        world.center_camera_on(cell)


func refresh_all() -> void:
    if not _hero_controller:
        return
    var st: Dictionary = _hero_controller.stats
    _stats_label.text = "⚔️ %d 🛡️ %d 🔮 %d 📖 %d" % [
        st.get("attack", 0), st.get("defense", 0),
        st.get("spell_power", 0), st.get("knowledge", 0)]
    for i in range(8):
        var hbox: HBoxContainer = _army_slots[i].get_node("HBox")
        var ic: Label = hbox.get_node("Icon")
        var ct: Label = hbox.get_node("Count")
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


func _on_mp_changed(cur: int, mx: int) -> void:
    if _mp_label:
        _mp_label.text = "👣 %d/%d" % [cur, mx]


func _on_resources_changed(_r: Dictionary) -> void:
    _update_resources()


func _on_path_preview(text: String) -> void:
    if _status_label:
        _status_label.text = text


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


func _vspacer() -> Control:
    var sp := Control.new()
    sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
    return sp
