extends Node2D
class_name WorldController

var _map_gen: MapGenerator
var _hero: HeroController
var _ui: AdventureUI
var _camera: Camera2D
var _zoom: float = 1.0

const CAM_SPEED := 600.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.0
const EDGE := 20


func _ready() -> void:
    _map_gen = MapGenerator.new()
    _map_gen.name = "MapGenerator"
    _map_gen.seed_value = randi() % 999999
    add_child(_map_gen)

    _hero = HeroController.new()
    _hero.name = "Hero"
    add_child(_hero)

    await get_tree().process_frame
    _hero.setup(_map_gen)
    _hero.hero_moved.connect(_on_hero_moved)
    _hero.hero_entered_village.connect(_on_village)

    _ui = AdventureUI.new()
    add_child(_ui)
    _ui.setup(_hero)
    _ui.end_turn_pressed.connect(_on_end_turn)

    _camera = Camera2D.new()
    _camera.position_smoothing_enabled = true
    add_child(_camera)
    if _hero != null:
        _camera.position = _hero.position

    _spawn_villages()
    _spawn_resources()
    print("[World] Scene ready.")
    
    # Для headless режима: выход после генерации
    if OS.has_feature("headless") or "--autoquit" in OS.get_cmdline_args():
        await get_tree().create_timer(1.0).timeout
        get_tree().quit()


func _process(delta: float) -> void:
    if _camera == null or _hero == null:
        return

    var mv := Vector2.ZERO
    if Input.is_action_pressed("camera_left"): mv.x -= 1
    if Input.is_action_pressed("camera_right"): mv.x += 1
    if Input.is_action_pressed("camera_up"): mv.y -= 1
    if Input.is_action_pressed("camera_down"): mv.y += 1

    # Edge scroll: ТОЛЬКО если мышь не над UI и у самого края окна
    var vp := get_viewport()
    var over_ui := false
    if vp.has_method("gui_get_hovered_control"):
        over_ui = vp.gui_get_hovered_control() != null
    if not over_ui:
        var mp := vp.get_mouse_position()
        var vs := vp.get_visible_rect().size
        if mp.x < EDGE: mv.x -= 1
        elif mp.x > vs.x - EDGE: mv.x += 1
        if mp.y < EDGE: mv.y -= 1
        elif mp.y > vs.y - EDGE: mv.y += 1

    if mv != Vector2.ZERO:
        _camera.position += mv.normalized() * CAM_SPEED * delta / _zoom


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom = minf(_zoom + 0.1, ZOOM_MAX)
            _camera.zoom = Vector2(_zoom, _zoom)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom = maxf(_zoom - 0.1, ZOOM_MIN)
            _camera.zoom = Vector2(_zoom, _zoom)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _hero.cancel_pending()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if _map_gen and _map_gen._tile_map and _map_gen._tile_map.tile_set != null:
                var cell := _map_gen._tile_map.local_to_map(get_global_mouse_position())
                if cell.x >= 0 and cell.x < _map_gen.map_width and cell.y >= 0 and cell.y < _map_gen.map_height:
                    _hero.on_map_clicked(cell)


func _spawn_villages() -> void:
    if _map_gen._tile_map == null or _map_gen._tile_map.tile_set == null:
        return
    for cell in _map_gen.village_cells:
        var v := Node2D.new()
        v.set_meta("cell", cell)
        var sp := Sprite2D.new()
        var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
        for y in 48:
            for x in 48:
                if y < 20 and abs(x - 24) < (24 - y) * 0.8:
                    img.set_pixel(x, y, Color(0.7, 0.2, 0.1))
                elif y >= 20 and y < 42 and x >= 10 and x <= 38:
                    img.set_pixel(x, y, Color(0.6, 0.5, 0.3))
        sp.texture = ImageTexture.create_from_image(img)
        sp.z_index = 5
        v.add_child(sp)
        var flag := Label.new()
        flag.name = "Flag"
        flag.text = "🚩"
        flag.add_theme_font_size_override("font_size", 16)
        flag.position = Vector2(18, -20)
        v.add_child(flag)
        v.position = _map_gen._tile_map.map_to_local(cell)
        add_child(v)


func _spawn_resources() -> void:
    if _map_gen._tile_map == null or _map_gen._tile_map.tile_set == null:
        return
    var icons := ["🪵", "🧪", "🪨", "", "", "💎", ""]
    for cell in _map_gen.resource_cells:
        var res_type: int = _map_gen.resource_cells[cell]
        var r := Node2D.new()
        r.set_meta("cell", cell)
        r.set_meta("res_type", res_type)
        var lbl := Label.new()
        lbl.text = icons[res_type] if res_type < icons.size() else "?"
        lbl.add_theme_font_size_override("font_size", 24)
        lbl.position = Vector2(-12, -12)
        r.add_child(lbl)
        r.position = _map_gen._tile_map.map_to_local(cell)
        r.z_index = 6
        add_child(r)


func _on_hero_moved(cell: Vector2i) -> void:
    _camera.position = _hero.position
    for child in get_children():
        if child.has_meta("cell") and child.get_meta("cell") == cell and child.has_meta("res_type"):
            child.queue_free()
            break


func _on_village(cell: Vector2i) -> void:
    print("[World] Village captured at ", cell)
    for child in get_children():
        if child.has_meta("cell") and child.get_meta("cell") == cell:
            var flag := child.get_node_or_null("Flag")
            if flag:
                flag.text = "🏳️"
            break


func _on_end_turn() -> void:
    _hero.end_turn()
    _ui.refresh_all()


func get_camera() -> Camera2D:
    return _camera

func center_camera_on(cell: Vector2i) -> void:
    if _map_gen and _map_gen._tile_map and _map_gen._tile_map.tile_set != null:
        _camera.position = _map_gen._tile_map.map_to_local(cell)


func jump_camera(direction: String) -> void:
    if not _map_gen:
        return
    var center := Vector2i(_map_gen.map_width / 2, _map_gen.map_height / 2)
    match direction:
        "N": center_camera_on(Vector2i(center.x, 2))
        "S": center_camera_on(Vector2i(center.x, _map_gen.map_height - 3))
        "W": center_camera_on(Vector2i(2, center.y))
        "E": center_camera_on(Vector2i(_map_gen.map_width - 3, center.y))
