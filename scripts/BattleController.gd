extends Node2D
class_name BattleController

signal battle_finished(winner: String, surviving_atk: Array, surviving_def: Array)

const BW := 17
const BH := 11

var attacker_units: Array[Dictionary] = []
var defender_units: Array[Dictionary] = []
var active_unit: Dictionary = {}
var highlighted_cells: Dictionary = {}
var is_player_turn: bool = true
var battle_over: bool = false
var turn_queue: Array[Dictionary] = []
var turn_idx: int = 0

var _tile_map: TileMapLayer
var _hl_layer: TileMapLayer
var _sprites: Array[Node2D] = []
var _status: Label
var _canvas: CanvasLayer

func _ready() -> void:
    _tile_map = TileMapLayer.new(); _tile_map.name = "BattleTerrain"; add_child(_tile_map)
    _hl_layer = TileMapLayer.new(); _hl_layer.name = "HL"; _hl_layer.modulate = Color(0.3,0.8,1,0.4); add_child(_hl_layer)
    for y in BH:
        for x in BW: _tile_map.set_cell(Vector2i(x,y), 0, Vector2i(0, 2))
    _build_ui()

func _build_ui() -> void:
    _canvas = CanvasLayer.new(); _canvas.layer = 10; add_child(_canvas)
    var tb := PanelContainer.new(); tb.set_anchors_preset(Control.PRESET_TOP_WIDE); tb.offset_bottom = 50
    var ts := StyleBoxFlat.new(); ts.bg_color = Color(0.1,0.1,0.15,0.9)
    tb.add_theme_stylebox_override("panel", ts); _canvas.add_child(tb)
    _status = Label.new(); _status.text = "Select a creature..."
    _status.add_theme_font_size_override("font_size", 20); _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tb.add_child(_status)
    var bb := HBoxContainer.new(); bb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); bb.offset_top = -60
    bb.alignment = BoxContainer.ALIGNMENT_CENTER; bb.add_theme_constant_override("separation", 10); _canvas.add_child(bb)
    for bd in [["⚙️","Settings"],["🏕️","Retreat"],["🏃","Wait"],["⚔️","Attack"],["▲","Collapse"],["📖","Spells"],["⏳","Skip"],["🛡️","Defend"]]:
        var btn := Button.new(); btn.text = bd[0]; btn.tooltip_text = bd[1]
        btn.custom_minimum_size = Vector2(56,48); btn.add_theme_font_size_override("font_size", 22)
        if bd[1]=="Retreat": btn.pressed.connect(_on_retreat)
        elif bd[1]=="Wait": btn.pressed.connect(_on_wait)
        elif bd[1]=="Skip": btn.pressed.connect(_on_skip)
        elif bd[1]=="Defend": btn.pressed.connect(_on_defend)
        elif bd[1]=="Spells": btn.pressed.connect(func(): _status.text = "Spellbook: not in prototype")
        bb.add_child(btn)

func start_battle(atk: Array[Dictionary], def: Array[Dictionary]) -> void:
    attacker_units = _place(atk, true)
    defender_units = _place(def, false)
    _build_queue()
    _next_turn()

func _place(army: Array[Dictionary], is_atk: bool) -> Array[Dictionary]:
    var units: Array[Dictionary] = []
    var sx := 1 if is_atk else BW - 2
    for i in army.size():
        var s := army[i].duplicate()
        if s.get("count",0) <= 0: continue
        s["cell"] = Vector2i(sx, clampi(1 + i*2, 0, BH-1))
        s["side"] = "attacker" if is_atk else "defender"
        s["alive"] = true; s["has_moved"] = false
        units.append(s); _make_sprite(s)
    return units

func _make_sprite(stack: Dictionary) -> void:
    var n := Node2D.new()
    var col := Color(0.2,0.5,0.9) if stack["side"]=="attacker" else Color(0.9,0.3,0.2)
    var img := Image.create(48,48,false,Image.FORMAT_RGBA8)
    for y in 48:
        for x in 48:
            var d := Vector2(x,y).distance_to(Vector2(24,24))
            if d<=20: img.set_pixel(x,y,col)
            elif d<=22: img.set_pixel(x,y,Color(0.1,0.1,0.1))
    var sp := Sprite2D.new(); sp.texture = ImageTexture.create_from_image(img); n.add_child(sp)
    var il := Label.new(); il.text = stack.get("icon","?"); il.add_theme_font_size_override("font_size",20)
    il.position = Vector2(-12,-14); n.add_child(il)
    var cl := Label.new(); cl.name = "CountLabel"; cl.text = str(stack["count"])
    cl.add_theme_font_size_override("font_size",14); cl.position = Vector2(-10,8); n.add_child(cl)
    n.position = _tile_map.map_to_local(stack["cell"]); n.set_meta("unit", stack)
    add_child(n); _sprites.append(n)

func _build_queue() -> void:
    turn_queue.clear()
    turn_queue.append_array(attacker_units)
    turn_queue.append_array(defender_units)
    turn_queue.sort_custom(func(a,b): return a.get("speed",5) > b.get("speed",5))

func _next_turn() -> void:
    if battle_over: return
    while turn_idx < turn_queue.size():
        var u: Dictionary = turn_queue[turn_idx]
        if u.get("alive",false) and u.get("count",0)>0: break
        turn_idx += 1
    if turn_idx >= turn_queue.size():
        turn_idx = 0
        for u in turn_queue: u["has_moved"] = false
        _next_turn(); return
    active_unit = turn_queue[turn_idx]
    is_player_turn = (active_unit["side"] == "attacker")
    highlighted_cells.clear(); _hl_layer.clear()
    _status.text = "%s: %s (%d)" % ["Your turn" if is_player_turn else "Enemy turn", active_unit.get("name",""), active_unit.get("count",0)]
    if not is_player_turn:
        await get_tree().create_timer(0.8).timeout
        _ai_turn()

func _unhandled_input(event: InputEvent) -> void:
    if battle_over or not is_player_turn: return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var cell := _tile_map.local_to_map(get_global_mouse_position())
        if cell.x<0 or cell.x>=BW or cell.y<0 or cell.y>=BH: return
        if highlighted_cells.has(cell): _do_move(active_unit, cell); return
        var clicked := _unit_at(cell, "attacker")
        if clicked.size()>0 and not clicked.get("has_moved",false): _select(clicked)

func _select(unit: Dictionary) -> void:
    active_unit = unit; highlighted_cells.clear(); _hl_layer.clear()
    var blocked: Dictionary = {}
    for u in attacker_units: if u!=unit and u.get("alive",false): blocked[u["cell"]]=true
    for u in defender_units: if u.get("alive",false): blocked[u["cell"]]=true
    highlighted_cells = HexUtils.bfs_reachable(unit["cell"], unit.get("speed",5), blocked, BW, BH)
    for c in highlighted_cells: _hl_layer.set_cell(c, 0, Vector2i(0,2))
    for n in HexUtils.get_all_neighbors(unit["cell"]):
        if _unit_at(n,"defender").size()>0: highlighted_cells[n]=0
    _status.text = "Selected: %s. Click hex to move." % unit.get("name","")

func _do_move(unit: Dictionary, target: Vector2i) -> void:
    var enemy := _unit_at(target, "defender")
    if enemy.size()>0: _attack(unit, enemy)
    else:
        var blocked: Dictionary = {}
        for u in attacker_units: if u!=unit and u.get("alive",false): blocked[u["cell"]]=true
        for u in defender_units: if u.get("alive",false): blocked[u["cell"]]=true
        var p := HexUtils.bfs_path(unit["cell"], target, blocked, BW, BH)
        unit["cell"] = target; unit["has_moved"] = true
        _animate(unit, p)
    highlighted_cells.clear(); _hl_layer.clear()
    _status.text = "Select a creature..."
    await get_tree().create_timer(0.5).timeout
    _end_turn()

func _animate(unit: Dictionary, path: Array[Vector2i]) -> void:
    var node := _find_node(unit)
    if node == null or path.size()<2: return
    var tw := create_tween()
    for i in range(1, path.size()):
        tw.tween_property(node, "position", _tile_map.map_to_local(path[i]), 0.12)

func _attack(atk: Dictionary, def: Dictionary) -> void:
    var dmg := maxi(1, int(float(atk.get("count",1)*atk.get("base_damage",3)) * (1.0 - clampf(float(def.get("defense",0))*0.03, 0.0, 0.7))))
    var kills := maxi(1, dmg / maxi(1, def.get("hp",10)))
    def["count"] = maxi(0, def.get("count",0) - kills)
    var dn := _find_node(def)
    if dn:
        var cl := dn.get_node_or_null("CountLabel")
        if cl: cl.text = str(def["count"])
    atk["has_moved"] = true
    if def["count"]<=0:
        def["alive"] = false
        if dn: dn.queue_free(); _sprites.erase(dn)
    _check_end()

func _ai_turn() -> void:
    if battle_over: return
    var cell: Vector2i = active_unit["cell"]
    var nearest: Dictionary = {}; var nd := 999
    for au in attacker_units:
        if au.get("alive",false):
            var d := HexUtils.hex_distance(cell, au["cell"])
            if d < nd: nd = d; nearest = au
    if nearest.size()==0: _end_turn(); return
    if nd == 1: _attack(active_unit, nearest); await get_tree().create_timer(0.5).timeout; _end_turn(); return
    var blocked: Dictionary = {}
    for u in defender_units: if u!=active_unit and u.get("alive",false): blocked[u["cell"]]=true
    for u in attacker_units: if u.get("alive",false): blocked[u["cell"]]=true
    var p := HexUtils.bfs_path(cell, nearest["cell"], blocked, BW, BH)
    if p.size()>1:
        var steps := mini(active_unit.get("speed",5), p.size()-1)
        active_unit["cell"] = p[steps]; active_unit["has_moved"] = true
        _animate(active_unit, p.slice(0, steps+1))
    await get_tree().create_timer(0.5).timeout
    _end_turn()

func _unit_at(cell: Vector2i, side: String) -> Dictionary:
    var units := attacker_units if side=="attacker" else defender_units
    for u in units:
        if u.get("alive",false) and u.get("cell",Vector2i(-1,-1))==cell: return u
    return {}

func _find_node(unit: Dictionary) -> Node2D:
    for n in _sprites:
        if n.get_meta("unit",{})==unit: return n
    return null

func _end_turn() -> void: turn_idx += 1; _next_turn()

func _check_end() -> void:
    var aa := false; var da := false
    for u in attacker_units: if u.get("alive",false) and u.get("count",0)>0: aa=true; break
    for u in defender_units: if u.get("alive",false) and u.get("count",0)>0: da=true; break
    if not aa: battle_over=true; _status.text="Defeat!"; battle_finished.emit("defender",_surv(attacker_units),_surv(defender_units))
    elif not da: battle_over=true; _status.text="Victory!"; battle_finished.emit("attacker",_surv(attacker_units),_surv(defender_units))

func _surv(units: Array[Dictionary]) -> Array[Dictionary]:
    var r: Array[Dictionary] = []
    for u in units: if u.get("alive",false) and u.get("count",0)>0: r.append(u)
    return r

func _on_retreat() -> void: battle_over=true; battle_finished.emit("defender",[],_surv(defender_units))
func _on_wait() -> void: turn_queue.erase(active_unit); turn_queue.append(active_unit); _end_turn()
func _on_skip() -> void: active_unit["has_moved"]=true; _end_turn()
func _on_defend() -> void: active_unit["has_moved"]=true; active_unit["defending"]=true; _end_turn()
