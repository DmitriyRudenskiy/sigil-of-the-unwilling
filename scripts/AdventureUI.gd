extends CanvasLayer
class_name AdventureUI

signal end_turn_pressed
signal date_changed(month: int, week: int, day: int)

const RIGHT_W := 252
const C_BG := Color(0.16, 0.11, 0.06, 0.95)
const C_BORDER := Color(0.62, 0.47, 0.22)
const C_TEXT := Color(0.95, 0.89, 0.72)
const C_GOLD := Color(1.0, 0.85, 0.4)
const C_SLOT_BG := Color(0.35, 0.24, 0.15)
const MINIMAP_COLORS := [
    Color(0.15, 0.35, 0.75), Color(0.2, 0.45, 0.4), Color(0.85, 0.75, 0.45),
    Color(0.35, 0.6, 0.3), Color(0.15, 0.35, 0.15), Color(0.45, 0.4, 0.35),
    Color(0.9, 0.93, 0.98),
]

var day := 1
var week := 1
var month := 1

var _date_label: Label
var _status_label: Label
var _army_slots: Array[Panel] = []
var _resource_labels: Dictionary = {}
var _hero_slots: Array[Panel] = []
var _town_slots: Array[Panel] = []
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
            minimap_clicked.emit(Vector2i(int(ev.position.x / s.x), int(ev.position.y / s.y)))


func _ready() -> void:
    layer = 10
    _build_right_column()


func setup(hero: HeroController) -> void:
    _hero_controller = hero
    hero.movement_points_changed.connect(func(c, m): _set_status("👣 %d/%d" % [c, m]))
    hero.resources_changed.connect(func(_r): _update_resources())
    hero.path_previewed.connect(func(t): _set_status(t))
    _minimap_overlay.map_ref = hero._map_gen
    _minimap_overlay.hero_ref = hero
    var world := get_parent()
    if world and world.has_method("get_camera"):
        _minimap_overlay.cam_ref = world.get_camera()
    _minimap_overlay.minimap_clicked.connect(_on_minimap_clicked)
    _build_minimap_image(hero._map_gen)
    _fill_hero_slot(0, hero)
    refresh_all()


func _panel_style() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = C_BG
    s.set_border_width_all(2)
    s.border_color = C_BORDER
    return s


func _empty_slot(h: float) -> Panel:
    var p := Panel.new()
    p.custom_minimum_size = Vector2(0, h)
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # FIX: слоты растягиваются поровну
    var s := StyleBoxFlat.new()
    s.bg_color = C_SLOT_BG
    s.set_corner_radius_all(3)
    s.set_border_width_all(1)
    s.border_color = Color(0.2, 0.13, 0.08)
    p.add_theme_stylebox_override("panel", s)
    return p


func _arrow(up: bool) -> Button:
    var b := Button.new()
    b.text = "▲" if up else "▼"
    b.custom_minimum_size = Vector2(24, 18)
    b.add_theme_font_size_override("font_size", 10)
    b.tooltip_text = "Прокрутка (в прототипе не реализовано)"
    return b


func _apply_icon(btn: Button, icon_path: String, fallback: String) -> void:
    if FileAccess.file_exists(icon_path):
        btn.icon = load(icon_path)
        btn.text = ""
        btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        btn.expand_icon = true
    else:
        btn.text = fallback
func _build_right_column() -> void:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _panel_style())
    p.anchor_left = 1.0
    p.anchor_right = 1.0
    p.anchor_top = 0.0
    p.anchor_bottom = 1.0
    p.offset_left = -RIGHT_W
    add_child(p)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 6)
    p.add_child(vb)

    # 1) Миникарта
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

    # NSWE
    var nswe := HBoxContainer.new()
    nswe.alignment = BoxContainer.ALIGNMENT_CENTER
    nswe.add_theme_constant_override("separation", 8)
    vb.add_child(nswe)
    for d in ["N", "S", "W", "E"]:
        var b := Button.new()
        b.text = d
        b.custom_minimum_size = Vector2(36, 24)
        b.add_theme_font_size_override("font_size", 12)
        b.pressed.connect(_on_camera_jump.bind(d))
        nswe.add_child(b)

    # Дата
    _date_label = Label.new()
    _date_label.text = _fmt_date()
    _date_label.add_theme_font_size_override("font_size", 14)
    _date_label.add_theme_color_override("font_color", C_TEXT)
    _date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(_date_label)

    # 2) Панель «герои | города»
    var lists := HBoxContainer.new()
    lists.add_theme_constant_override("separation", 6)
    vb.add_child(lists)

    var hv := VBoxContainer.new()
    hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hv.add_theme_constant_override("separation", 3)
    lists.add_child(hv)
    var ha := HBoxContainer.new()
    ha.alignment = BoxContainer.ALIGNMENT_CENTER
    ha.add_child(_arrow(true))
    hv.add_child(ha)
    for i in 4:
        var s := _empty_slot(44)
        hv.add_child(s)
        _hero_slots.append(s)
    var ha2 := HBoxContainer.new()
    ha2.alignment = BoxContainer.ALIGNMENT_CENTER
    ha2.add_child(_arrow(false))
    hv.add_child(ha2)

    var tv := VBoxContainer.new()
    tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tv.add_theme_constant_override("separation", 3)
    lists.add_child(tv)
    var ta := HBoxContainer.new()
    ta.alignment = BoxContainer.ALIGNMENT_CENTER
    ta.add_child(_arrow(true))
    tv.add_child(ta)
    for i in 4:
        var s := _empty_slot(44)
        tv.add_child(s)
        _town_slots.append(s)
    var ta2 := HBoxContainer.new()
    ta2.alignment = BoxContainer.ALIGNMENT_CENTER
    ta2.add_child(_arrow(false))
    tv.add_child(ta2)

    # 3) Сетка кнопок 4x3 — СРАЗУ после панели героев/городов (как в оригинале)
    var bg := GridContainer.new()
    bg.columns = 4
    bg.add_theme_constant_override("h_separation", 4)
    bg.add_theme_constant_override("v_separation", 4)
    vb.add_child(bg)
    var btns := [
        ["res://assets/ui/icons/treasure.png", "Замок", "🏰"],
        ["res://assets/ui/icons/flag.png", "Флаг", "🚩"],
        ["res://assets/ui/icons/battle_flag.png", "Лагерь", "⛺"],
        ["res://assets/ui/icons/horse.png", "Конюшня", "🐎"],
        ["res://assets/ui/icons/ship.png", "Корабль", "🚢"],
        ["res://assets/ui/icons/swords.png", "Кузница", "⚒️"],
        ["res://assets/ui/icons/scout.png", "Разведка", "🔍"],
        ["res://assets/ui/icons/army.png", "Армия", "🪖"],
        ["res://assets/ui/icons/scroll.png", "Журнал", "📜"],
        ["res://assets/ui/icons/hourglass.png", "Конец хода", "⏳"],
        ["res://assets/ui/icons/gold.png", "Королевство", "🏰"],
        ["res://assets/ui/icons/expand.png", "Опции", "⚙️"],
    ]
    for b in btns:
        var btn := Button.new()
        btn.tooltip_text = b[1]
        btn.custom_minimum_size = Vector2(52, 42)
        if b[1] == "Конец хода":
            btn.pressed.connect(_on_end_turn)
            btn.modulate = C_GOLD
        elif b[1] == "Опции":
            btn.pressed.connect(_on_options)
        _apply_icon(btn, b[0], b[2])
        bg.add_child(btn)

    # 4) Панель армии (внизу, как в оригинале)
    var ap := PanelContainer.new()
    var aps := StyleBoxFlat.new()
    aps.bg_color = Color(0.3, 0.2, 0.12)
    aps.set_corner_radius_all(4)
    aps.set_border_width_all(2)
    aps.border_color = C_BORDER
    ap.add_theme_stylebox_override("panel", aps)
    vb.add_child(ap)
    var ag := GridContainer.new()
    ag.columns = 2
    ag.add_theme_constant_override("h_separation", 6)
    ag.add_theme_constant_override("v_separation", 6)
    ap.add_child(ag)
    for i in 8:
        var slot := Panel.new()
        slot.name = "Slot%d" % i
        slot.custom_minimum_size = Vector2(0, 40)
        slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var ss := StyleBoxFlat.new()
        ss.bg_color = C_SLOT_BG
        ss.set_corner_radius_all(3)
        slot.add_theme_stylebox_override("panel", ss)
        var sh := HBoxContainer.new()
        sh.name = "HBox"
        sh.alignment = BoxContainer.ALIGNMENT_CENTER
        sh.add_theme_constant_override("separation", 6)
        slot.add_child(sh)
        var ic := TextureRect.new()
        ic.name = "Icon"
        ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        ic.custom_minimum_size = Vector2(24, 24)
        sh.add_child(ic)
        var ct := Label.new()
        ct.name = "Count"
        ct.text = "0"
        ct.add_theme_font_size_override("font_size", 14)
        ct.add_theme_color_override("font_color", C_TEXT)
        sh.add_child(ct)
        ag.add_child(slot)
        _army_slots.append(slot)

    # 5) Ресурсы
    var rh := HBoxContainer.new()
    rh.alignment = BoxContainer.ALIGNMENT_CENTER
    rh.add_theme_constant_override("separation", 8)
    vb.add_child(rh)
    for ri in [["wood", "🪵"], ["mercury", "🧪"], ["ore", "🪨"], ["sulfur", "🟡"],
            ["crystal", "🔷"], ["gems", "💎"], ["gold", "🪙"]]:
        var l := Label.new()
        l.text = "%s0" % ri[1]
        l.add_theme_font_size_override("font_size", 12)
        l.add_theme_color_override("font_color", C_TEXT)
        rh.add_child(l)
        _resource_labels[ri[0]] = l

    vb.add_child(_vspacer())

    # 6) Статус — в самом низу
    _status_label = Label.new()
    _status_label.text = ""
    _status_label.add_theme_font_size_override("font_size", 12)
    _status_label.add_theme_color_override("font_color", C_TEXT)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(_status_label)


func _fill_hero_slot(idx: int, hero: HeroController) -> void:
    if idx >= _hero_slots.size():
        return
    var slot := _hero_slots[idx]
    for c in slot.get_children():
        c.queue_free()
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 4)
    slot.add_child(hb)
    var av := hero.get_avatar_texture()
    if av != null:
        var tr := TextureRect.new()
        tr.texture = av
        tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # FIX: держим 40x40
        tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tr.custom_minimum_size = Vector2(40, 40)
        hb.add_child(tr)
    else:
        var em := Label.new()
        em.text = "🧙"
        em.add_theme_font_size_override("font_size", 22)
        hb.add_child(em)
    var nm := Label.new()
    nm.text = hero.hero_name
    nm.add_theme_font_size_override("font_size", 13)
    nm.add_theme_color_override("font_color", C_GOLD)
    nm.clip_text = true
    hb.add_child(nm)


func add_city(city_name: String) -> void:
    for i in _town_slots.size():
        var slot := _town_slots[i]
        if slot.get_child_count() == 0:
            var hb := HBoxContainer.new()
            hb.add_theme_constant_override("separation", 4)
            slot.add_child(hb)
            var ic := Label.new()
            ic.text = "🏰"
            ic.add_theme_font_size_override("font_size", 18)
            hb.add_child(ic)
            var nm := Label.new()
            nm.text = city_name
            nm.add_theme_font_size_override("font_size", 12)
            nm.add_theme_color_override("font_color", C_TEXT)
            nm.clip_text = true
            hb.add_child(nm)
            return


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
    for i in range(8):
        var hbox: HBoxContainer = _army_slots[i].get_node("HBox")
        var ic: TextureRect = hbox.get_node("Icon")
        var ct: Label = hbox.get_node("Count")
        if i < _hero_controller.army.size():
            var key: String = _hero_controller.army[i].get("name", "").to_lower().replace(" ", "_")
            var portrait := UnitSprites.find_portrait_small(key)
            if portrait != "":
                ic.texture = load(portrait)
            else:
                ic.texture = null
                # fallback to emoji if we had a label, but now it's TextureRect.
                # We can't put emoji in TextureRect. We'll just leave it blank or use a default.
            ct.text = str(_hero_controller.army[i]["count"])
        else:
            ic.texture = null
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
        _resource_labels[k].text = "%s%d" % [icons[k], _hero_controller.resources.get(k, 0)]


func _set_status(text: String) -> void:
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

var _options_popup: PopupPanel
var _border_check: CheckBox

func _on_options() -> void:
    if _options_popup == null:
        _options_popup = PopupPanel.new()
        var vb := VBoxContainer.new()
        _options_popup.add_child(vb)
        _border_check = CheckBox.new()
        _border_check.text = "Рамка гексов"
        _border_check.toggled.connect(_on_border_toggled)
        vb.add_child(_border_check)
        add_child(_options_popup)
    _options_popup.popup_centered(Vector2i(260, 80))

func _on_border_toggled(on: bool) -> void:
    var world := get_parent()
    if world and world.has_method("set_hex_borders"):
        world.set_hex_borders(on)
