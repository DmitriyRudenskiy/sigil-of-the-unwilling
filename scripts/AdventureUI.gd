extends CanvasLayer
class_name AdventureUI

signal end_turn_pressed
signal date_changed(month: int, week: int, day: int)

# ==== КАЛИБРОВКА ПО prototype_map.html ====
const RIGHT_W := 244
const C_BG := Color(0.16, 0.11, 0.06, 0.95)
const C_BORDER := Color(0.62, 0.47, 0.22)
const C_TEXT := Color(0.95, 0.89, 0.72)
const C_GOLD := Color(1.0, 0.85, 0.4)
const C_SLOT_BG := Color(0.22, 0.16, 0.10)
const MINIMAP_COLORS := [
    Color(0.15, 0.35, 0.75), Color(0.85, 0.75, 0.45), Color(0.35, 0.6, 0.3),
    Color(0.15, 0.35, 0.15), Color(0.45, 0.4, 0.35), Color(0.9, 0.93, 0.98),
]
# ==========================================

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
    refresh_all()


func _panel_style() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = C_BG
    s.set_border_width_all(2)
    s.border_color = C_BORDER
    return s


# ===================== ЕДИНАЯ ПРАВАЯ КОЛОНКА =====================
func _build_right_column() -> void:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _panel_style())
    p.anchor_left = 1.0
    p.anchor_right = 1.0
    p.anchor_top = 0.0
    p.anchor_bottom = 1.0
    p.offset_left = -RIGHT_W
    p.offset_right = 0
    p.offset_top = 0
    p.offset_bottom = 0
    add_child(p)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 6)
    p.add_child(vb)

    # 1) Дата (верх колонки)
    _date_label = Label.new()
    _date_label.text = _fmt_date()
    _date_label.add_theme_font_size_override("font_size", 17)
    _date_label.add_theme_color_override("font_color", C_TEXT)
    _date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(_date_label)

    # 2) Ресурсы (сетка 2 колонки)
    var rg := GridContainer.new()
    rg.columns = 2
    rg.add_theme_constant_override("h_separation", 10)
    vb.add_child(rg)
    var res_icons := [
        ["wood", "🪵"], ["mercury", "🧪"], ["ore", "🪨"], ["sulfur", "🟡"],
        ["crystal", "🔷"], ["gems", "💎"], ["gold", "🪙"],
    ]
    for ri in res_icons:
        var l := Label.new()
        l.text = "%s 0" % ri[1]
        l.add_theme_font_size_override("font_size", 14)
        l.add_theme_color_override("font_color", C_TEXT)
        rg.add_child(l)
        _resource_labels[ri[0]] = l

    # 3) Миникарта
    var box := Control.new()
    box.custom_minimum_size = Vector2(RIGHT_W - 24, RIGHT_W - 24)
    vb.add_child(box)
    _minimap_tex_rect = TextureRect.new()
    _minimap_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _minimap_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
    box.add_child(_minimap_tex_rect)
    _minimap_overlay = MinimapOverlay.new()
    _minimap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    box.add_child(_minimap_overlay)

    # 4) NSWE
    var nswe := HBoxContainer.new()
    nswe.alignment = BoxContainer.ALIGNMENT_CENTER
    nswe.add_theme_constant_override("separation", 6)
    vb.add_child(nswe)
    for d in ["N", "S", "W", "E"]:
        var b := Button.new()
        b.text = d
        b.custom_minimum_size = Vector2(44, 30)
        b.add_theme_font_size_override("font_size", 14)
        b.pressed.connect(_on_camera_jump.bind(d))
        nswe.add_child(b)

    vb.add_child(HSeparator.new())

    # 5) Кнопки управления (вертикально, порядок прототипа)
    var btns := [
        ["🏰", "Замок"], ["🚩", "Флаг"], ["⛺", "Лагерь"], ["🐎", "Конюшня"],
        ["🚢", "Корабль"], ["⚒️", "Кузница"], ["🔍", "Разведка"], ["🪖", "Армия"],
        ["📜", "Журнал"], ["⏳", "Конец хода"], ["🏰", "Королевство"],
    ]
    for b in btns:
        var btn := Button.new()
        btn.text = b[0]
        btn.tooltip_text = b[1]
        btn.custom_minimum_size = Vector2(RIGHT_W - 24, 32)
        btn.add_theme_font_size_override("font_size", 16)
        if b[1] == "Конец хода":
            btn.pressed.connect(_on_end_turn)
            btn.modulate = C_GOLD
        vb.add_child(btn)

    # 6) Статус-строка (предпросмотр пути)
    _status_label = Label.new()
    _status_label.text = ""
    _status_label.add_theme_font_size_override("font_size", 13)
    _status_label.add_theme_color_override("font_color", C_TEXT)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(_status_label)

    vb.add_child(_vspacer())

    # 7) Герой
    var hv := VBoxContainer.new()
    hv.add_theme_constant_override("separation", 2)
    vb.add_child(hv)
    var nl := Label.new()
    nl.text = "Darkstorn"
    nl.add_theme_font_size_override("font_size", 19)
    nl.add_theme_color_override("font_color", C_GOLD)
    hv.add_child(nl)
    _stats_label = Label.new()
    _stats_label.text = "⚔️ 0 🛡️ 0 🔮 4 📖 2"
    _stats_label.add_theme_font_size_override("font_size", 15)
    _stats_label.add_theme_color_override("font_color", C_TEXT)
    hv.add_child(_stats_label)
    _mp_label = Label.new()
    _mp_label.text = "👣 20/20"
    _mp_label.add_theme_font_size_override("font_size", 13)
    _mp_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
    hv.add_child(_mp_label)
    var tg := HBoxContainer.new()
    hv.add_child(tg)
    for t in ["🛡️", "⚔️"]:
        var b := Button.new()
        b.text = t
        b.custom_minimum_size = Vector2(34, 30)
        b.tooltip_text = "Панель героя"
        tg.add_child(b)

    # 8) Армия: сетка 2x4 в самом низу колонки
    var ag := GridContainer.new()
    ag.columns = 2
    ag.add_theme_constant_override("h_separation", 6)
    ag.add_theme_constant_override("v_separation", 6)
    vb.add_child(ag)
    for i in 8:
        var slot := Panel.new()
        slot.name = "Slot%d" % i
        slot.custom_minimum_size = Vector2(104, 44)
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
        ic.add_theme_font_size_override("font_size", 18)
        sh.add_child(ic)

        var ct := Label.new()
        ct.name = "Count"
        ct.text = "0"
        ct.add_theme_font_size_override("font_size", 15)
        ct.add_theme_color_override("font_color", C_TEXT)
        sh.add_child(ct)

        ag.add_child(slot)
        _army_slots.append(slot)


# ===================== MINIMAP =====================
func _build_minimap_image(map: MapGenerator) -> void:
    if map == null:
        return
    var img := Image.create(map.map_width, map.map_height, false, Image.FORMAT_RGBA8)
    for y in map.map_height:
        for x in map.map_width:
            var cell := Vector2i(x, y)
            var t: int = map.terrain_grid.get(cell, 0)
            if t < MINIMAP_COLORS.size():
                img.set_pixel(x, y, MINIMAP_COLORS[t])
            else:
                img.set_pixel(x, y, Color.BLACK)
    _minimap_tex_rect.texture = ImageTexture.create_from_image(img)


func _on_minimap_clicked(cell: Vector2i) -> void:
    var world := get_parent()
    if world and world.has_method("center_camera_on"):
        world.center_camera_on(cell)


# ===================== REFRESH / SIGNALS =====================
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
