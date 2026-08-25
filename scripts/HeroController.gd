extends Node2D
class_name HeroController

signal hero_moved(cell: Vector2i)
signal hero_entered_village(cell: Vector2i)
signal movement_points_changed(current: int, max_val: int)

@export var max_move_points: int = 20
@export var move_cost_per_cell: int = 1

var current_cell: Vector2i = Vector2i(5, 5)
var move_points: int = 20
var path: Array[Vector2i] = []
var is_moving: bool = false
var hero_name: String = "Darkstorn"
var stats := {"attack": 0, "defense": 0, "spell_power": 4, "knowledge": 2}
var army: Array[Dictionary] = [
    {"icon":"🗡️","name":"Swordsmen","count":103,"base_damage":4,"speed":5,"hp":10},
    {"icon":"🏹","name":"Archers","count":36,"base_damage":3,"speed":4,"hp":8},
    {"icon":"🐴","name":"Cavalry","count":34,"base_damage":5,"speed":7,"hp":15},
    {"icon":"📜","name":"Mages","count":10,"base_damage":7,"speed":5,"hp":12},
    {"icon":"🛡️","name":"Guardians","count":20,"base_damage":6,"speed":3,"hp":25},
    {"icon":"🧙","name":"Archmages","count":12,"base_damage":9,"speed":6,"hp":14},
    {"icon":"⚔️","name":"Champions","count":6,"base_damage":12,"speed":8,"hp":30},
    {"icon":"🐎","name":"Knights","count":12,"base_damage":8,"speed":9,"hp":20},
]
var resources := {"wood":10,"mercury":2,"ore":10,"sulfur":2,"crystal":2,"gems":2,"gold":500}

var _map_gen: MapGenerator
var _sprite: Sprite2D
var _tween: Tween

func _ready() -> void:
    _create_visual()
    movement_points_changed.emit(move_points, max_move_points)

func _create_visual() -> void:
    _sprite = Sprite2D.new()
    var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
    for y in 48:
        for x in 48:
            var d := Vector2(x,y).distance_to(Vector2(24,24))
            if d <= 20: img.set_pixel(x, y, Color(0.9, 0.7, 0.1))
            elif d <= 22: img.set_pixel(x, y, Color(0.3, 0.2, 0.0))
    _sprite.texture = ImageTexture.create_from_image(img)
    _sprite.z_index = 10
    add_child(_sprite)

func setup(map: MapGenerator) -> void:
    _map_gen = map
    for y in map.map_height:
        for x in map.map_width:
            var cell := Vector2i(x, y)
            if map.is_walkable(cell):
                current_cell = cell
                _update_position()
                return

func _update_position() -> void:
    if _map_gen and _map_gen._tile_map:
        position = _map_gen._tile_map.map_to_local(current_cell)

func on_map_clicked(cell: Vector2i) -> void:
    if is_moving or cell == current_cell: return
    if _map_gen:
        var blocked := _map_gen.get_blocked_cells()
        var p := HexUtils.bfs_path(current_cell, cell, blocked, _map_gen.map_width, _map_gen.map_height)
        if p.size() > 1:
            var max_cells := move_points / move_cost_per_cell
            path = p.slice(0, mini(p.size(), max_cells + 1))
            _start_moving()

func _start_moving() -> void:
    if path.size() < 2: return
    is_moving = true
    _move_next_step()

func _move_next_step() -> void:
    if path.size() < 2:
        is_moving = false; path.clear(); return
    var next := path[1]; path.remove_at(0)
    move_points -= move_cost_per_cell
    movement_points_changed.emit(move_points, max_move_points)
    var target := _map_gen._tile_map.map_to_local(next) if _map_gen._tile_map else Vector2.ZERO
    if _tween and _tween.is_valid(): _tween.kill()
    _tween = create_tween()
    _tween.tween_property(_sprite, "position", target, 0.25)
    _tween.tween_callback(_on_step_complete.bind(next))

func _on_step_complete(cell: Vector2i) -> void:
    current_cell = cell
    position = _sprite.position
    hero_moved.emit(cell)
    if _map_gen and _map_gen.resource_cells.has(cell):
        var names := ["wood","mercury","ore","sulfur","crystal","gems","gold"]
        var t: int = _map_gen.resource_cells[cell]
        resources[names[t]] += 5 if t < 6 else 50
        _map_gen.resource_cells.erase(cell)
    if _map_gen and cell in _map_gen.village_cells:
        hero_entered_village.emit(cell)
    if move_points <= 0: is_moving = false; path.clear(); return
    _move_next_step()

func end_turn() -> void:
    move_points = max_move_points
    movement_points_changed.emit(move_points, max_move_points)
    is_moving = false; path.clear()

func get_army_for_battle() -> Array[Dictionary]:
    var a: Array[Dictionary] = []
    for s in army:
        if s["count"] > 0: a.append(s.duplicate())
    return a

func apply_battle_results(surviving: Array[Dictionary]) -> void:
    army = surviving
