extends Node2D
class_name HeroController

signal hero_moved(cell: Vector2i)
signal hero_entered_village(cell: Vector2i)
signal movement_points_changed(current: int, max_val: int)
signal resources_changed(resources: Dictionary)
signal path_previewed(text: String)

const HERO_SHEET_PATH := "res://assets/raw/hero_knight.jpg"

@export var max_move_points: int = 20
@export var move_cost_per_cell: int = 1

var current_cell: Vector2i = Vector2i(5, 5)
var move_points: int = 20
var path: Array[Vector2i] = []
var pending_cell: Vector2i = Vector2i(-1, -1)
var pending_path: Array[Vector2i] = []
var is_moving: bool = false
var hero_name: String = "Darkstorn"

var stats := {"attack": 0, "defense": 0, "spell_power": 4, "knowledge": 2}

var army: Array[Dictionary] = [
    {"icon": "🗡️", "name": "Swordsmen", "count": 103, "base_damage": 4, "speed": 5, "hp": 10},
    {"icon": "🏹", "name": "Archers", "count": 36, "base_damage": 3, "speed": 4, "hp": 8},
    {"icon": "🐴", "name": "Cavalry", "count": 34, "base_damage": 5, "speed": 7, "hp": 15},
    {"icon": "📜", "name": "Mages", "count": 10, "base_damage": 7, "speed": 5, "hp": 12},
    {"icon": "🛡️", "name": "Guardians", "count": 20, "base_damage": 6, "speed": 3, "hp": 25},
    {"icon": "🧙", "name": "Archmages", "count": 12, "base_damage": 9, "speed": 6, "hp": 14},
    {"icon": "⚔️", "name": "Champions", "count": 6, "base_damage": 12, "speed": 8, "hp": 30},
    {"icon": "🐎", "name": "Knights", "count": 12, "base_damage": 8, "speed": 9, "hp": 20},
]

var resources := {
    "wood": 10, "mercury": 2, "ore": 10, "sulfur": 2,
    "crystal": 2, "gems": 2, "gold": 500,
}

var _map_gen: MapGenerator
var _anim: AnimatedSprite2D
var _fallback: Sprite2D
var _avatar_tex: Texture2D
var _tween: Tween
var _path_line: Line2D
var _marker: DestMarker


# ======== Маркер кликнутой клетки (отладка пути) ========
class DestMarker extends Node2D:
    var active := false
    var _t := 0.0

    func _process(d: float) -> void:
        if active:
            _t += d
            queue_redraw()

    func show_at(pos: Vector2) -> void:
        position = pos
        active = true
        queue_redraw()

    func hide_marker() -> void:
        active = false
        queue_redraw()

    func _draw() -> void:
        if not active:
            return
        var r := 36.0 + sin(_t * 6.0) * 4.0
        var pts := PackedVector2Array()
        for i in 7:
            var ang := deg_to_rad(60.0 * i - 90.0)
            pts.append(Vector2(cos(ang), sin(ang)) * r)
        draw_polyline(pts, Color(1.0, 0.25, 0.2, 0.95), 3.0)


func _ready() -> void:
    _build_visual()


func _build_visual() -> void:
    # Пытаемся собрать анимацию из спрайт-листа рыцаря
    if FileAccess.file_exists(HERO_SHEET_PATH):
        var sheet := Image.load_from_file(HERO_SHEET_PATH)
        if sheet != null:
            _build_anim_from_sheet(sheet)
    if _anim == null:
        # Фолбэк: золотой круг
        _fallback = Sprite2D.new()
        var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
        var center := Vector2(24, 24)
        for y in 48:
            for x in 48:
                var dist := Vector2(x, y).distance_to(center)
                if dist <= 20:
                    img.set_pixel(x, y, Color(0.9, 0.7, 0.1))
                elif dist <= 22:
                    img.set_pixel(x, y, Color(0.3, 0.2, 0.0))
        _fallback.texture = ImageTexture.create_from_image(img)
        _fallback.z_index = 10
        add_child(_fallback)


func _build_anim_from_sheet(sheet: Image) -> void:
    if sheet.get_format() != Image.FORMAT_RGBA8:
        sheet.convert(Image.FORMAT_RGBA8)
    sheet.resize(512, 512, Image.INTERPOLATE_LANCZOS)
    # Убрать чёрный фон
    for y in 512:
        for x in 512:
            var px := sheet.get_pixel(x, y)
            if px.r < 0.12 and px.g < 0.12 and px.b < 0.12:
                sheet.set_pixel(x, y, Color(0, 0, 0, 0))
    var fs := 128
    var sf := SpriteFrames.new()
    if sf.has_animation("default"):
        sf.remove_animation("default")
    sf.add_animation("side")
    sf.add_animation("away")
    for an in ["side", "away"]:
        sf.set_animation_loop(an, true)
        sf.set_animation_speed(an, 8.0)
    for c in 4:
        var f_side := Image.create(fs, fs, false, Image.FORMAT_RGBA8)
        f_side.blit_rect(sheet, Rect2i(c * fs, 0, fs, fs), Vector2i(0, 0))
        sf.add_frame("side", ImageTexture.create_from_image(f_side))
        var f_away := Image.create(fs, fs, false, Image.FORMAT_RGBA8)
        f_away.blit_rect(sheet, Rect2i(c * fs, 3 * fs, fs, fs), Vector2i(0, 0))
        sf.add_frame("away", ImageTexture.create_from_image(f_away))
    _avatar_tex = sf.get_frame_texture("side", 0)
    _anim = AnimatedSprite2D.new()
    _anim.sprite_frames = sf
    _anim.scale = Vector2(0.62, 0.62)
    _anim.z_index = 10
    add_child(_anim)
    _anim.play("side")
    print("[Hero] Knight animation built from ", HERO_SHEET_PATH)


func get_avatar_texture() -> Texture2D:
    return _avatar_tex


func setup(map: MapGenerator) -> void:
    _map_gen = map
    if _path_line == null:
        _path_line = Line2D.new()
        _path_line.width = 3.0
        _path_line.default_color = Color(1, 1, 0, 0.6)
        _path_line.z_index = 5
        get_parent().add_child(_path_line)
    if _marker == null:
        _marker = DestMarker.new()
        get_parent().add_child(_marker)
    for y in map.map_height:
        for x in map.map_width:
            var cell := Vector2i(x, y)
            if map.is_walkable(cell):
                current_cell = cell
                _update_position()
                return


func _update_position() -> void:
    if _map_gen and _map_gen._tile_map and _map_gen._tile_map.tile_set != null:
        position = _map_gen._tile_map.map_to_local(current_cell)
    else:
        position = Vector2(current_cell.x * 64 + 32, current_cell.y * 56 + 28)


# ===================== TWO-CLICK MOVEMENT =====================
func on_map_clicked(cell: Vector2i) -> void:
    if is_moving or _map_gen == null or _map_gen._tile_map == null:
        return
    if cell == current_cell:
        cancel_pending()
        return

    if cell == pending_cell and pending_path.size() > 1:
        path = pending_path
        pending_cell = Vector2i(-1, -1)
        pending_path = []
        path_previewed.emit("")
        _marker.hide_marker()
        _start_moving()
        return

    if move_points <= 0:
        path_previewed.emit("Нет очков движения — нажмите ⏳")
        return

    var blocked := _map_gen.get_blocked_cells()
    var found := HexUtils.bfs_path(current_cell, cell, blocked, _map_gen.map_width, _map_gen.map_height)
    if found.size() < 2:
        cancel_pending()
        path_previewed.emit("Путь недоступен")
        return

    var max_cells := move_points / move_cost_per_cell
    var affordable: Array[Vector2i] = found.slice(0, mini(found.size(), max_cells + 1))
    pending_cell = cell
    pending_path = affordable
    _set_line_points(affordable)

    # Маркер кликнутой клетки
    if _map_gen._tile_map.tile_set != null:
        _marker.show_at(_map_gen._tile_map.map_to_local(cell))

    var cost := (affordable.size() - 1) * move_cost_per_cell
    var suffix := ""
    if affordable.size() < found.size():
        suffix = " (очков хватит на %d кл.)" % (affordable.size() - 1)
    path_previewed.emit("Путь: %d кл., очков: %d%s. Клик ещё раз — идти. ПКМ — отмена." % [
        affordable.size() - 1, cost, suffix])


func cancel_pending(clear_text := true) -> void:
    pending_cell = Vector2i(-1, -1)
    pending_path = []
    if _path_line:
        _path_line.clear_points()
    if _marker:
        _marker.hide_marker()
    if clear_text:
        path_previewed.emit("")


func _set_line_points(pts: Array[Vector2i]) -> void:
    if _path_line == null:
        return
    _path_line.clear_points()
    for p in pts:
        var local_pos: Vector2
        if _map_gen and _map_gen._tile_map and _map_gen._tile_map.tile_set != null:
            local_pos = _map_gen._tile_map.map_to_local(p)
        else:
            local_pos = Vector2(p.x * 64 + 32, p.y * 56 + 28)
        _path_line.add_point(local_pos)


# ===================== MOVEMENT =====================
func _start_moving() -> void:
    if path.size() < 2:
        return
    is_moving = true
    _move_next_step()


func _move_next_step() -> void:
    if path.size() < 2:
        is_moving = false
        path.clear()
        if _path_line:
            _path_line.clear_points()
        if _marker:
            _marker.hide_marker()
        return

    var next_cell := path[1]
    path.remove_at(0)
    _set_line_points(path)

    _set_facing(next_cell - current_cell)

    move_points -= move_cost_per_cell
    movement_points_changed.emit(move_points, max_move_points)

    var target_pos: Vector2
    if _map_gen and _map_gen._tile_map and _map_gen._tile_map.tile_set != null:
        target_pos = _map_gen._tile_map.map_to_local(next_cell)
    else:
        target_pos = Vector2(next_cell.x * 64 + 32, next_cell.y * 56 + 28)

    if _tween and _tween.is_valid():
        _tween.kill()
    _tween = create_tween()
    _tween.tween_property(self, "position", target_pos, 0.35)
    _tween.tween_callback(_on_step_complete.bind(next_cell))


func _set_facing(delta: Vector2i) -> void:
    if _anim == null:
        return
    if delta.x > 0:
        _anim.animation = "side"
        _anim.flip_h = true
    elif delta.x < 0:
        _anim.animation = "side"
        _anim.flip_h = false
    elif delta.y < 0:
        _anim.animation = "away"
        _anim.flip_h = false
    else:
        _anim.animation = "away"
        _anim.flip_h = true
    _anim.play()


func _on_step_complete(cell: Vector2i) -> void:
    current_cell = cell
    hero_moved.emit(cell)

    if _map_gen and _map_gen.resource_cells.has(cell):
        var res_type: int = _map_gen.resource_cells[cell]
        _pickup_resource(res_type)
        _map_gen.resource_cells.erase(cell)
        resources_changed.emit(resources)

    if _map_gen and cell in _map_gen.village_cells:
        hero_entered_village.emit(cell)

    if move_points <= 0:
        is_moving = false
        path.clear()
        if _path_line:
            _path_line.clear_points()
        if _marker:
            _marker.hide_marker()
        return

    _move_next_step()


func _pickup_resource(res_type: int) -> void:
    var names := ["wood", "mercury", "ore", "sulfur", "crystal", "gems", "gold"]
    if res_type < names.size():
        var amount := 5 if res_type < 6 else 50
        resources[names[res_type]] += amount
        print("[Hero] Picked up +%d %s" % [amount, names[res_type]])


func end_turn() -> void:
    move_points = max_move_points
    movement_points_changed.emit(move_points, max_move_points)
    is_moving = false
    path.clear()
    cancel_pending()


func get_army_for_battle() -> Array[Dictionary]:
    var alive: Array[Dictionary] = []
    for stack in army:
        if stack["count"] > 0:
            alive.append(stack.duplicate())
    return alive


func apply_battle_results(surviving_army: Array[Dictionary]) -> void:
    army = surviving_army
