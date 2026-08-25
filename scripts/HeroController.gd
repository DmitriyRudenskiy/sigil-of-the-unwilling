extends Node2D
class_name HeroController

signal hero_moved(cell: Vector2i)
signal hero_entered_village(cell: Vector2i)
signal movement_points_changed(current: int, max_val: int)
signal resources_changed(resources: Dictionary)

@export var max_move_points: int = 20
@export var move_cost_per_cell: int = 1

var current_cell: Vector2i = Vector2i(5, 5)
var move_points: int = 20
var path: Array[Vector2i] = []
var is_moving: bool = false
var hero_name: String = "Darkstorn"

var stats := {
    "attack": 0,
    "defense": 0,
    "spell_power": 4,
    "knowledge": 2,
}

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
    "wood": 10,
    "mercury": 2,
    "ore": 10,
    "sulfur": 2,
    "crystal": 2,
    "gems": 2,
    "gold": 500,
}

var _map_gen: MapGenerator
var _sprite: Sprite2D
var _tween: Tween
var _path_line: Line2D


func _ready() -> void:
    _create_visual()
    movement_points_changed.emit(move_points, max_move_points)
    resources_changed.emit(resources)


func _create_visual() -> void:
    _sprite = Sprite2D.new()
    var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
    var center := Vector2(24, 24)
    for y in 48:
        for x in 48:
            var dist := Vector2(x, y).distance_to(center)
            if dist <= 20:
                img.set_pixel(x, y, Color(0.9, 0.7, 0.1))
            elif dist <= 22:
                img.set_pixel(x, y, Color(0.3, 0.2, 0.0))
    _sprite.texture = ImageTexture.create_from_image(img)
    _sprite.z_index = 10
    add_child(_sprite)
    
    _path_line = Line2D.new()
    _path_line.width = 3.0
    _path_line.default_color = Color(1, 1, 0, 0.6)
    _path_line.z_index = 5
    add_child(_path_line)


func setup(map: MapGenerator) -> void:
    _map_gen = map
    # Найти стартовую позицию на суше
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


func on_map_clicked(cell: Vector2i) -> void:
    if is_moving or cell == current_cell:
        return
    if _map_gen == null or _map_gen._tile_map == null:
        return
    
    # Проверить, можно ли дойти
    var blocked := _map_gen.get_blocked_cells()
    var found_path := HexUtils.bfs_path(current_cell, cell, blocked, _map_gen.map_width, _map_gen.map_height)
    
    if found_path.size() > 1:
        var cost := (found_path.size() - 1) * move_cost_per_cell
        if cost <= move_points:
            path = found_path
            _start_moving()
        else:
            # Двигаться насколько хватит очков
            var max_cells := move_points / move_cost_per_cell
            if max_cells > 0:
                path = found_path.slice(0, max_cells + 1)
                _start_moving()


func _start_moving() -> void:
    if path.size() < 2:
        return
    is_moving = true
    _draw_path()
    _move_next_step()


func _draw_path() -> void:
    _path_line.clear_points()
    for p in path:
        var local_pos: Vector2
        if _map_gen and _map_gen._tile_map:
            local_pos = _map_gen._tile_map.map_to_local(p)
        else:
            local_pos = Vector2(p.x * 64 + 32, p.y * 56 + 28)
        _path_line.add_point(local_pos)


func _move_next_step() -> void:
    if path.size() < 2:
        is_moving = false
        path.clear()
        _path_line.clear_points()
        return
    
    var next_cell := path[1]
    path.remove_at(0)
    
    # Списать очки движения
    move_points -= move_cost_per_cell
    movement_points_changed.emit(move_points, max_move_points)
    
    # Tween к следующей клетке
    var target_pos: Vector2
    if _map_gen and _map_gen._tile_map:
        target_pos = _map_gen._tile_map.map_to_local(next_cell)
    else:
        target_pos = Vector2(next_cell.x * 64 + 32, next_cell.y * 56 + 28)
    
    if _tween and _tween.is_valid():
        _tween.kill()
    _tween = create_tween()
    _tween.tween_property(_sprite, "position", target_pos, 0.25)
    _tween.tween_callback(_on_step_complete.bind(next_cell))


func _on_step_complete(cell: Vector2i) -> void:
    current_cell = cell
    position = _sprite.position if _sprite else position
    hero_moved.emit(cell)
    
    # Проверить подбор ресурса
    if _map_gen and _map_gen.resource_cells.has(cell):
        var res_type: int = _map_gen.resource_cells[cell]
        _pickup_resource(res_type)
        _map_gen.resource_cells.erase(cell)
        resources_changed.emit(resources)
    
    # Проверить вход в деревню
    if _map_gen and cell in _map_gen.village_cells:
        hero_entered_village.emit(cell)
    
    # Если очков не осталось — остановить
    if move_points <= 0:
        is_moving = false
        path.clear()
        _path_line.clear_points()
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
    _path_line.clear_points()
    print("[Hero] End turn: move points restored to %d" % move_points)


func get_army_for_battle() -> Array[Dictionary]:
    var alive: Array[Dictionary] = []
    for stack in army:
        if stack["count"] > 0:
            alive.append(stack.duplicate())
    return alive


func apply_battle_results(surviving_army: Array[Dictionary]) -> void:
    army = surviving_army
