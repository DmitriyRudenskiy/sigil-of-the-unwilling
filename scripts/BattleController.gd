extends Node2D
class_name BattleController
## Боевой режим по prototype_var.html:
## клик по своему существу -> подсветка гексов хода -> клик -> перемещение (tween по пути)
## атака по соседу без реталиации; очередь ходов по скорости

signal battle_finished(winner: String, surviving_atk: Array, surviving_def: Array)

const BW := 17
const BH := 11

var attacker_units: Array[Dictionary] = []
var defender_units: Array[Dictionary] = []
var active_unit: Dictionary = {}
var highlight_move: Dictionary = {}
var highlight_attack: Dictionary = {}
var obstacles: Dictionary = {}
var is_player_turn := true
var battle_over := false
var turn_queue: Array[Dictionary] = []
var turn_idx := 0

var _tile_map: TileMapLayer
var _hl_move: TileMapLayer
var _hl_atk: TileMapLayer
var _sprites: Array[Node2D] = []
var _status: Label
var _canvas: CanvasLayer
var _bottom_bar: HBoxContainer
var _camera: Camera2D
var _uid := 0


func _ready() -> void:
    print("[Battle] Initializing combat scene...")
    _setup_background()
    
    _tile_map = TileMapLayer.new()
    _tile_map.name = "BattleTerrain"
    _tile_map.tile_set = load("res://tilesets/hex_tileset.tres")
    add_child(_tile_map)
    HexUtils.calibrate(_tile_map)

    _hl_move = TileMapLayer.new()
    _hl_move.modulate = Color(0.3, 0.8, 1.0, 0.35)
    add_child(_hl_move)
    _hl_atk = TileMapLayer.new()
    _hl_atk.modulate = Color(1.0, 0.2, 0.2, 0.45)
    add_child(_hl_atk)

    _paint_field()
    _place_obstacles()

    _camera = Camera2D.new()
    add_child(_camera)
    if _tile_map.tile_set != null:
        _camera.position = _tile_map.map_to_local(Vector2i(BW / 2, BH / 2))

    _build_ui()
    _fade_in()


func _paint_field() -> void:
    var grass: Vector2i = TerrainAtlasMap.CENTER_COORDS[HexUtils.Terrain.GRASS]
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    for y in BH:
        for x in BW:
            var coords := grass
            var vars: Array = TerrainAtlasMap.VARIANTS.get(HexUtils.Terrain.GRASS, [])
            if vars.size() > 0 and rng.randf() < 0.5:
                coords = vars[rng.randi_range(0, vars.size() - 1)]
            _tile_map.set_cell(Vector2i(x, y), TerrainAtlasMap.SOURCE_ID, coords)


func _place_obstacles() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 777
    var n := 0
    while n < 8:
        var cell := Vector2i(rng.randi_range(3, BW - 4), rng.randi_range(1, BH - 2))
        if obstacles.has(cell):
            continue
        obstacles[cell] = true
        var lbl := Label.new()
        lbl.text = "🪨" if rng.randf() > 0.5 else "🌳"
        lbl.add_theme_font_size_override("font_size", 28)
        lbl.position = _tile_map.map_to_local(cell) + Vector2(-14, -16)
        lbl.z_index = 4
        add_child(lbl)
        n += 1


func _build_ui() -> void:
    _canvas = CanvasLayer.new()
    _canvas.layer = 10
    add_child(_canvas)

    var tb := PanelContainer.new()
    tb.set_anchors_preset(Control.PRESET_TOP_WIDE)
    tb.offset_bottom = 48
    var ts := StyleBoxFlat.new()
    ts.bg_color = Color(0.1, 0.08, 0.05, 0.92)
    tb.add_theme_stylebox_override("panel", ts)
    _canvas.add_child(tb)
    _status = Label.new()
    _status.text = "Выберите существо…"
    _status.add_theme_font_size_override("font_size", 18)
    _status.add_theme_color_override("font_color", Color(0.95, 0.89, 0.72))
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tb.add_child(_status)

    _bottom_bar = HBoxContainer.new()
    _bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _bottom_bar.offset_top = -58
    _bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
    _bottom_bar.add_theme_constant_override("separation", 10)
    _canvas.add_child(_bottom_bar)

    # Золотые иконки по ДОПОЛНЕНИЮ №3
    var btns := [
        ["res://assets/ui/icons/expand.png", "Настройки/пауза", "_on_settings", "⚙️"],
        ["res://assets/ui/icons/flag.png", "Отступление", "_on_retreat", "🏕️"],
        ["res://assets/ui/icons/horse4.png", "Ждать", "_on_wait", "🏃"],
        ["res://assets/ui/icons/atk_sword.png", "Атака", "_on_attack_mode", "⚔️"],
        ["res://assets/ui/icons/point.png", "Свернуть панель", "_on_collapse", "▲"],
        ["res://assets/ui/icons/spell.png", "Книга заклинаний", "_on_spellbook", "📖"],
        ["res://assets/ui/icons/hourglass2.png", "Пропуск хода", "_on_skip", "⏳"],
        ["res://assets/ui/icons/helm.png", "Защита", "_on_defend", "🛡️"],
    ]
    for b in btns:
        var btn := Button.new()
        btn.tooltip_text = b[1]
        btn.custom_minimum_size = Vector2(56, 48)
        btn.pressed.connect(Callable(self, b[2]))
        _apply_icon(btn, b[0], b[3])
        _bottom_bar.add_child(btn)


# ===================== START =====================
func start_battle(atk: Array[Dictionary], def: Array[Dictionary]) -> void:
    attacker_units = _place_army(atk, true)
    defender_units = _place_army(def, false)
    _build_queue()
    _next_turn()


func _place_army(army: Array[Dictionary], is_atk: bool) -> Array[Dictionary]:
    var units: Array[Dictionary] = []
    var sx := 1 if is_atk else BW - 2
    for i in army.size():
        var s: Dictionary = army[i].duplicate()
        if s.get("count", 0) <= 0:
            continue
        var row := clampi(1 + i * 2, 0, BH - 1)
        s["cell"] = Vector2i(sx, row)
        s["side"] = "attacker" if is_atk else "defender"
        s["alive"] = true
        s["has_moved"] = false
        s["uid"] = _uid
        _uid += 1
        units.append(s)
        _make_unit_sprite(s)
    return units


func _make_unit_sprite(u: Dictionary) -> void:
    var n := Node2D.new()
    var sp := Sprite2D.new()
    
    # Приоритет: Портрет -> Эмодзи-круг
    var portrait_path := UnitSprites.find_portrait(u.get("name", "").to_lower().replace(" ", "_"))
    if portrait_path == "":
        # Фолбэк: рисование цветного круга с эмодзи
        var col := Color(0.2, 0.5, 0.9) if u["side"] == "attacker" else Color(0.9, 0.3, 0.2)
        var img := Image.create(52, 52, false, Image.FORMAT_RGBA8)
        var c := Vector2(26, 26)
        for y in 52:
            for x in 52:
                var d := Vector2(x, y).distance_to(c)
                if d <= 22:
                    img.set_pixel(x, y, col)
                elif d <= 24:
                    img.set_pixel(x, y, Color(0.1, 0.1, 0.1))
        sp.texture = ImageTexture.create_from_image(img)
    else:
        sp.texture = load(portrait_path)
        if u["side"] == "defender":
            sp.flip_h = true
    
    n.add_child(sp)
    var il := Label.new()
    il.text = u.get("icon", "?")
    il.add_theme_font_size_override("font_size", 20)
    il.position = Vector2(-10, -14)
    n.add_child(il)
    var cl := Label.new()
    cl.name = "CountLabel"
    cl.text = str(u["count"])
    cl.add_theme_font_size_override("font_size", 13)
    cl.add_theme_color_override("font_color", Color.WHITE)
    cl.position = Vector2(-10, 10)
    n.add_child(cl)
    n.position = _tile_map.map_to_local(u["cell"])
    n.z_index = 6
    n.set_meta("uid", u["uid"])
    add_child(n)
    _sprites.append(n)


# ===================== TURNS =====================
func _build_queue() -> void:
    turn_queue.clear()
    turn_queue.append_array(attacker_units)
    turn_queue.append_array(defender_units)
    turn_queue.sort_custom(func(a, b): return a.get("speed", 5) > b.get("speed", 5))


func _next_turn() -> void:
    if battle_over:
        return
    _clear_highlights()
    while turn_idx < turn_queue.size():
        var u: Dictionary = turn_queue[turn_idx]
        if u.get("alive", false) and u.get("count", 0) > 0:
            break
        turn_idx += 1
    if turn_idx >= turn_queue.size():
        turn_idx = 0
        for u in turn_queue:
            u["has_moved"] = false
            u["defending"] = false
        _next_turn()
        return
    active_unit = turn_queue[turn_idx]
    is_player_turn = (active_unit["side"] == "attacker")
    var side_txt := "Ваш ход" if is_player_turn else "Ход противника"
    _status.text = "%s: %s (%d)" % [side_txt, active_unit.get("name", ""), active_unit.get("count", 0)]
    var node := _find_node(active_unit)
    if node != null:
        var tw := create_tween()
        tw.tween_property(node, "scale", Vector2(1.25, 1.25), 0.15)
        tw.tween_property(node, "scale", Vector2(1, 1), 0.15)
    if not is_player_turn:
        await get_tree().create_timer(0.7).timeout
        _ai_turn()


func _end_turn() -> void:
    turn_idx += 1
    _next_turn()


# ===================== INPUT =====================
func _unhandled_input(ev: InputEvent) -> void:
    if battle_over or not is_player_turn:
        return
    if ev is InputEventMouseButton and ev.pressed:
        if ev.button_index == MOUSE_BUTTON_LEFT:
            var cell := _tile_map.local_to_map(get_global_mouse_position())
            if cell.x < 0 or cell.x >= BW or cell.y < 0 or cell.y >= BH:
                return
            if highlight_attack.has(cell):
                _do_attack(active_unit, _unit_at(cell, "defender"))
                return
            if highlight_move.has(cell):
                _do_move(active_unit, cell)
                return
            var own := _unit_at(cell, "attacker")
            if own.size() > 0 and not own.get("has_moved", false):
                _select(own)
        elif ev.button_index == MOUSE_BUTTON_RIGHT:
            _clear_highlights()
            _status.text = "Выберите существо…"


func _select(u: Dictionary) -> void:
    active_unit = u
    _clear_highlights()
    var blocked := _all_blocked(u)
    highlight_move = HexUtils.bfs_reachable(u["cell"], u.get("speed", 5), blocked, BW, BH)
    for c in highlight_move:
        _hl_move.set_cell(c, TerrainAtlasMap.SOURCE_ID, _grass_coords())
    for nb in HexUtils.get_all_neighbors(u["cell"]):
        var en := _unit_at(nb, "defender")
        if en.size() > 0:
            highlight_attack[nb] = 1
            _hl_atk.set_cell(nb, TerrainAtlasMap.SOURCE_ID, _grass_coords())
    _status.text = "%s: клик по гексу — ход, по врагу — атака." % u.get("name", "")


func _clear_highlights() -> void:
    highlight_move.clear()
    highlight_attack.clear()
    _hl_move.clear()
    _hl_atk.clear()


func _all_blocked(except: Dictionary) -> Dictionary:
    var b: Dictionary = {}
    for u in attacker_units:
        if u != except and u.get("alive", false):
            b[u["cell"]] = true
    for u in defender_units:
        if u.get("alive", false):
            b[u["cell"]] = true
    for o in obstacles:
        b[o] = true
    return b


func _grass_coords() -> Vector2i:
    return TerrainAtlasMap.CENTER_COORDS[HexUtils.Terrain.GRASS]


# ===================== ACTIONS =====================
func _do_move(u: Dictionary, target: Vector2i) -> void:
    var blocked := _all_blocked(u)
    var path := HexUtils.bfs_path(u["cell"], target, blocked, BW, BH)
    u["cell"] = target
    u["has_moved"] = true
    _clear_highlights()
    _animate(u, path)
    await get_tree().create_timer(0.4).timeout
    _end_turn()


func _animate(u: Dictionary, path: Array[Vector2i]) -> void:
    var node := _find_node(u)
    if node == null or path.size() < 2:
        return
    var tw := create_tween()
    for i in range(1, path.size()):
        tw.tween_property(node, "position", _tile_map.map_to_local(path[i]), 0.12)


func _do_attack(atk: Dictionary, def: Dictionary) -> void:
    if def.size() == 0:
        return
    var count: int = atk.get("count", 1)
    var bd: int = atk.get("base_damage", 3)
    var def_stat: int = def.get("defense", 0)
    var reduction := clampf(float(def_stat) * 0.03, 0.0, 0.7)
    var dmg := maxi(1, int(float(count * bd) * (1.0 - reduction)))
    if def.get("defending", false):
        dmg = maxi(1, dmg / 2)
    var hp := maxi(1, int(def.get("hp", 10)))
    var kills := maxi(1, dmg / hp)
    def["count"] = maxi(0, int(def.get("count", 0)) - kills)
    atk["has_moved"] = true
    _clear_highlights()

    var dn := _find_node(def)
    if dn != null:
        var cl := dn.get_node_or_null("CountLabel")
        if cl != null:
            cl.text = str(def["count"])
        var tw := create_tween()
        tw.tween_property(dn, "modulate", Color(1, 0.3, 0.3), 0.1)
        tw.tween_property(dn, "modulate", Color.WHITE, 0.2)
    print("[Battle] %s -> %s: урон %d, убито %d" % [atk.get("name", "?"), def.get("name", "?"), dmg, kills])
    if def["count"] <= 0:
        def["alive"] = false
        if dn != null:
            dn.queue_free()
            _sprites.erase(dn)
    _check_end()
    if not battle_over:
        await get_tree().create_timer(0.4).timeout
        _end_turn()


# ===================== AI =====================
func _ai_turn() -> void:
    if battle_over:
        return
    var u := active_unit
    var nearest: Dictionary = {}
    var nd := 999
    for au in attacker_units:
        if au.get("alive", false) and au.get("count", 0) > 0:
            var d := HexUtils.hex_distance(u["cell"], au["cell"])
            if d < nd:
                nd = d
                nearest = au
    if nearest.size() == 0:
        _end_turn()
        return
    if nd == 1:
        _do_attack(u, nearest)
        return
    var blocked := _all_blocked(u)
    var path := HexUtils.bfs_path(u["cell"], nearest["cell"], blocked, BW, BH)
    if path.size() > 1:
        var steps := mini(u.get("speed", 5), path.size() - 1)
        var target: Vector2i = path[steps]
        # если встали вплотную — атакуем
        var adj := HexUtils.get_all_neighbors(target)
        var victim: Dictionary = {}
        for a in adj:
            var au := _unit_at(a, "attacker")
            if au.size() > 0:
                victim = au
                break
        u["cell"] = target
        u["has_moved"] = true
        _animate(u, path.slice(0, steps + 1))
        await get_tree().create_timer(0.4).timeout
        if victim.size() > 0:
            _do_attack(u, victim)
            return
    _end_turn()


# ===================== BUTTONS =====================
func _on_settings() -> void:
    _status.text = "⚙️ Пауза (в прототипе не реализовано)"


func _on_retreat() -> void:
    battle_over = true
    _status.text = "Отступление!"
    battle_finished.emit("defender", _surv(attacker_units), _surv(defender_units))


func _on_wait() -> void:
    if active_unit.size() > 0 and is_player_turn:
        turn_queue.erase(active_unit)
        turn_queue.append(active_unit)
        _end_turn()


func _on_attack_mode() -> void:
    if active_unit.size() == 0 or not is_player_turn:
        return
    _clear_highlights()
    for nb in HexUtils.get_all_neighbors(active_unit["cell"]):
        var en := _unit_at(nb, "defender")
        if en.size() > 0:
            highlight_attack[nb] = 1
            _hl_atk.set_cell(nb, TerrainAtlasMap.SOURCE_ID, _grass_coords())
    _status.text = "⚔️ Кликните подсвеченного врага."


func _on_collapse() -> void:
    _bottom_bar.visible = not _bottom_bar.visible


func _on_spellbook() -> void:
    _status.text = "📖 Книга заклинаний: в прототипе не реализовано"


func _on_skip() -> void:
    if is_player_turn and active_unit.size() > 0:
        active_unit["has_moved"] = true
        _end_turn()


func _on_defend() -> void:
    if is_player_turn and active_unit.size() > 0:
        active_unit["has_moved"] = true
        active_unit["defending"] = true
        _status.text = "🛡️ Защита: входящий урон вдвое меньше до следующего хода."
        _end_turn()


func _apply_icon(btn: Button, icon_path: String, fallback: String) -> void:
    if FileAccess.file_exists(icon_path):
        btn.icon = load(icon_path)
        btn.text = ""
        btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        btn.expand_icon = true
    else:
        btn.text = fallback
func _setup_background() -> void:
    var bg_layer := CanvasLayer.new()
    bg_layer.layer = -1
    add_child(bg_layer)
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.07, 1.0)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg_layer.add_child(bg)

func _fade_in() -> void:
    var fade_layer := CanvasLayer.new()
    fade_layer.layer = 100
    add_child(fade_layer)
    var fade := ColorRect.new()
    fade.color = Color.BLACK
    fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    fade_layer.add_child(fade)
    var tw := create_tween()
    tw.tween_property(fade, "color:a", 0.0, 0.5)
    tw.tween_callback(fade_layer.queue_free)

func _unit_at(cell: Vector2i, side: String) -> Dictionary:
    var units := attacker_units if side == "attacker" else defender_units
    for u in units:
        if u.get("alive", false) and u.get("cell", Vector2i(-1, -1)) == cell:
            return u
    return {}


func _find_node(u: Dictionary) -> Node2D:
    for n in _sprites:
        if n.get_meta("uid", -1) == u.get("uid", -2):
            return n
    return null


func _check_end() -> void:
    var aa := false
    var da := false
    for u in attacker_units:
        if u.get("alive", false) and u.get("count", 0) > 0:
            aa = true
            break
    for u in defender_units:
        if u.get("alive", false) and u.get("count", 0) > 0:
            da = true
            break
    if not aa:
        battle_over = true
        _status.text = "Поражение!"
        battle_finished.emit("defender", _surv(attacker_units), _surv(defender_units))
    elif not da:
        battle_over = true
        _status.text = "Победа!"
        battle_finished.emit("attacker", _surv(attacker_units), _surv(defender_units))


func _surv(units: Array[Dictionary]) -> Array[Dictionary]:
    var r: Array[Dictionary] = []
    for u in units:
        if u.get("alive", false) and u.get("count", 0) > 0:
            r.append(u)
    return r
