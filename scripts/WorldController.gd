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
const EDGE := 30

func _ready() -> void:
    _map_gen = MapGenerator.new()
    _map_gen.name = "MapGenerator"
    _map_gen.seed_value = randi() % 999999
    add_child(_map_gen)
    
    _hero = HeroController.new()
    _hero.name = "Hero"
    add_child(_hero)
    
    # Дождитесь, пока MapGenerator создаст _tile_map
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
    print("[World] Scene ready.")

func _process(delta: float) -> void:
    if _camera == null or _hero == null:
        return
    
    var mv := Vector2.ZERO
    if Input.is_action_pressed("camera_left"): mv.x -= 1
    if Input.is_action_pressed("camera_right"): mv.x += 1
    if Input.is_action_pressed("camera_up"): mv.y -= 1
    if Input.is_action_pressed("camera_down"): mv.y += 1
    
    var mp := get_viewport().get_mouse_position()
    var vs := get_viewport().get_visible_rect().size
    if mp.x < EDGE: mv.x -= 1
    elif mp.x > vs.x - EDGE: mv.x += 1
    if mp.y < EDGE: mv.y -= 1
    elif mp.y > vs.y - EDGE: mv.y += 1
    
    if mv != Vector2.ZERO:
        _camera.position += mv.normalized() * CAM_SPEED * delta / _zoom

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom = minf(_zoom + 0.1, ZOOM_MAX); _camera.zoom = Vector2(_zoom, _zoom)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom = maxf(_zoom - 0.1, ZOOM_MIN); _camera.zoom = Vector2(_zoom, _zoom)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            var cell := _map_gen._tile_map.local_to_map(get_global_mouse_position())
            if cell.x >= 0 and cell.x < _map_gen.map_width and cell.y >= 0 and cell.y < _map_gen.map_height:
                _hero.on_map_clicked(cell)

func _spawn_villages() -> void:
    if _map_gen._tile_map == null or _map_gen._tile_map.tile_set == null:
        print("WARN: TileMap not ready for villages")
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
        
        v.position = _map_gen._tile_map.map_to_local(cell)
        add_child(v)

func _on_hero_moved(cell: Vector2i) -> void: _camera.position = _hero.position
func _on_village(cell: Vector2i) -> void: print("Village captured: ", cell)
func _on_end_turn() -> void: _hero.end_turn(); _ui.refresh_all()

func start_battle(enemy: Array[Dictionary]) -> void:
    var battle := BattleController.new(); battle.name = "Battle"
    get_tree().root.add_child(battle); visible = false
    set_process(false); set_process_unhandled_input(false)
    battle.start_battle(_hero.get_army_for_battle(), enemy)
    battle.battle_finished.connect(_on_battle_end.bind(battle))

func _on_battle_end(winner: String, surv_atk: Array, surv_def: Array, node: Node) -> void:
    node.queue_free(); visible = true; set_process(true); set_process_unhandled_input(true)
    if winner == "attacker":
        var a: Array[Dictionary] = []
        for s in surv_atk: a.append(s)
        _hero.apply_battle_results(a); _ui.refresh_all()

func spawn_demo_enemy() -> void:
    start_battle([
        {"icon":"👹","name":"Goblins","count":50,"base_damage":3,"speed":4,"hp":6},
        {"icon":"🐺","name":"Wolves","count":30,"base_damage":4,"speed":6,"hp":8},
        {"icon":"🧌","name":"Trolls","count":15,"base_damage":8,"speed":3,"hp":20},
    ])
