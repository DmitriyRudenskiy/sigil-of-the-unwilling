class_name CityArenaView
extends Node2D

const HEX_SIZE := 26.0
const SQRT3: float = 1.7320508
const ArenaHexCellScene = preload("res://scenes/ui/ArenaHexCell.tscn")

const PALETTE: Array = [
    [&"farm", "🌾"],
    [&"mill", "🌀"],
    [&"bakery", "🍞"],
    [&"mine", "⛏"],
    [&"smithy", "⚒"],
    [&"tavern", "🍺"],
    [&"school", "📚"],
    [&"trade_post", "⚖"],
    [&"market", "🏪"],
    [&"shack", "🛖"],
    [&"walls", "🧱"],
    [&"district", "🏘"],
]

const PALETTE_BUTTON_NAMES: Array[String] = [
    "FarmButton", "MillButton", "BakeryButton", "MineButton",
    "SmithyButton", "TavernButton", "SchoolButton", "TradePostButton",
    "MarketButton", "ShackButton", "WallsButton", "DistrictButton",
]

var _city: City = null
var _turn := 0
var _starve_days := 0
var _selected: StringName = &""
var _auto := false
var _hex_layer: Node2D = null
var _camera: Camera2D = null
var _ui: CanvasLayer = null
var _top_hud: Label = null
var _score_hud: Label = null
var _log_hud: Label = null
var _tooltip: Label = null
var _auto_btn: Button = null
var _timer: Timer = null
var _cell_nodes: Dictionary = {}
var _palette_buttons: Array[Button] = []

func _ready() -> void:
    _camera = $Camera as Camera2D
    _hex_layer = $HexLayer as Node2D
    _ui = $UI as CanvasLayer
    _top_hud = _ui.get_node("Top/TopHud") as Label
    _score_hud = _ui.get_node("ScoreHud") as Label
    _log_hud = _ui.get_node("LogHud") as Label
    _tooltip = _ui.get_node("Tooltip") as Label
    _timer = $Timer as Timer
    _wire_palette()
    _wire_ui()
    get_viewport().size_changed.connect(_fit_camera)
    _new_game()
    _fit_camera()

func _new_game() -> void:
    _city = CityArenaModel.make_city()
    _turn = 0
    _starve_days = 0
    _selected = &""
    _stop_auto()
    _log(GameText.arena_founded())
    _build_cells()
    _refresh()

func _wire_palette() -> void:
    var palette := _ui.get_node("Palette") as VBoxContainer
    (palette.get_node("Title") as Label).text = GameText.arena_palette_hint()
    _palette_buttons.clear()
    for btn_name in PALETTE_BUTTON_NAMES:
        var btn := palette.get_node(btn_name) as Button
        if btn == null:
            continue
        _palette_buttons.append(btn)
    for i in _palette_buttons.size():
        if i < PALETTE.size():
            var id: StringName = PALETTE[i][0]
            var emoji: String = PALETTE[i][1]
            var bname: String = GameText.building_name(id)
            var cost: String = _cost_label(id)
            _palette_buttons[i].text = GameText.arena_palette_item(emoji, bname, cost)
            _palette_buttons[i].pressed.connect(_on_palette_pressed.bind(id))

func _wire_ui() -> void:
    var bar := _ui.get_node("Bar") as HBoxContainer
    _wire_button(bar, "TurnButton", GameText.arena_turn_button(), _on_turn_pressed)
    _auto_btn = _wire_button(bar, "AutoButton", GameText.arena_auto_button(), _on_auto_pressed)
    _wire_button(bar, "HireButton", GameText.arena_hire_button(), _on_hire_pressed)
    _wire_button(bar, "LevelButton", GameText.arena_level_button(), _on_level_pressed)
    _wire_button(bar, "ResetButton", GameText.arena_reset_button(), _on_reset_pressed)
    _wire_button(bar, "MenuButton", GameText.arena_menu_button(), _on_menu_pressed)
    _timer.timeout.connect(_on_auto_tick)


func _wire_button(parent: Control, name: String, text: String, cb: Callable) -> Button:
    var btn := parent.get_node(name) as Button
    btn.text = text
    btn.pressed.connect(cb)
    return btn

func _cost_label(id: StringName) -> String:
    if id == &"district":
        return GameText.arena_borough_cost()
    var def: UniqueBuilding.Def = BuildingDefs.def_by_id(id)
    if def == null or def.levels.is_empty():
        return ""
    var req: UniqueBuilding.LevelReq = def.levels[0]
    return GameText.arena_cost(int(req.industry))

func _on_palette_pressed(id: StringName) -> void:
    _selected = &"" if _selected == id else id
    _log(GameText.arena_selected(_selection_name()))
    _draw_arena()

func _selection_name() -> String:
    if _selected == &"":
        return GameText.arena_nothing()
    for row in PALETTE:
        if row[0] == _selected:
            return GameText.arena_selection(row[1], GameText.building_name(_selected))
    return str(_selected)



func _hex_to_pixel(cell: Vector2i) -> Vector2:
    var x: float = HEX_SIZE * SQRT3 * (float(cell.x) + 0.5 * (cell.y & 1))
    var y: float = HEX_SIZE * 1.5 * float(cell.y)
    return Vector2(x, y)

func _ring_color(ring: int) -> Color:
    return CityArenaModel.ring_color(ring)

func _building_emoji(id: StringName) -> String:
    match id:
        &"farm": return "🌾"
        &"mill": return "🌀"
        &"bakery": return "🍞"
        &"mine": return "⛏"
        &"smithy": return "⚒"
        &"tavern": return "🍺"
        &"school": return "📚"
        &"trade_post": return "⚖"
        &"market": return "🏪"
        &"shack": return "🛖"
        &"walls": return "🧱"
        &"district": return "🏘"
        _: return "❓"

func _ring_yield_short(ring: int) -> String:
    var y: Dictionary = GameNumbers.ring_yield(ring)
    var food: float = float(y.get(&"food", 0.0))
    var ind: float = float(y.get(&"industry", 0.0))
    var parts: Array[String] = []
    if food > 0.0:
        parts.append("🌾" + ("%.1f" % food))
    if ind > 0.0:
        parts.append("🏭" + ("%.1f" % ind))
    return ", ".join(parts)

func _borough_at(cv: Vector2i) -> Borough:
    if _city == null:
        return null
    for b in _city.boroughs:
        if b.cell == cv:
            return b
    return null

func _cell_mark(cv: Vector2i) -> String:
    var b: UniqueBuilding = _city.get_building_at(cv)
    if b != null and b.def != null:
        var mark: String = _building_emoji(b.def.id)
        if b.level > 1:
            mark += str(b.level)
        return mark
    var bo: Borough = _borough_at(cv)
    if bo != null:
        var mark: String = "🏘"
        if bo.level > 1:
            mark += str(bo.level)
        return mark
    return ""

func _build_cells() -> void:
    for c in _hex_layer.get_children():
        c.queue_free()
    _cell_nodes.clear()
    var cells: Array = CityArenaModel.cells_in_arena()
    for cell in cells:
        var cv: Vector2i = cell
        var ring: int = CityArenaModel.ring_of(cv)
        var pos: Vector2 = _hex_to_pixel(cv)
        var feat_id: StringName = CityArenaModel.cell_feature(_city, cv)
        var arena_cell: ArenaHexCell = ArenaHexCellScene.instantiate()
        arena_cell.cell = cv
        arena_cell.ring = ring
        arena_cell.feature_id = feat_id
        arena_cell.position = pos
        arena_cell.cell_input.connect(_on_cell_input)
        arena_cell.cell_entered.connect(_on_cell_entered)
        arena_cell.cell_exited.connect(_on_cell_exited)
        _hex_layer.add_child(arena_cell)
        _cell_nodes[cv] = arena_cell

func _draw_arena() -> void:
    if _city == null:
        return
    var clu: Dictionary = CityArenaModel.cluster_uids(_city)
    var firsts: Dictionary = {}
    for cl in CityArenaModel.clusters(_city):
        var cells: Array = (cl as Dictionary)["cells"]
        firsts[cells[0]] = GameText.arena_cluster_badge(cells.size())
    for cv in _cell_nodes:
        var arena_cell: ArenaHexCell = _cell_nodes[cv]
        var ring: int = CityArenaModel.ring_of(cv)
        var poly: Polygon2D = arena_cell.get_poly()
        var b: UniqueBuilding = _city.get_building_at(cv)
        var in_cluster: bool = b != null and clu.has(b.uid)
        if _city.cell_is_built(cv):
            poly.color = _ring_color(ring).darkened(0.22 if in_cluster else 0.45)
        else:
            poly.color = _ring_color(ring)
        arena_cell.mark_id = "" if ring == 0 else _cell_mark(cv)
        arena_cell.badge_id = firsts.get(cv, "")
        arena_cell.update()

func _on_cell_input(viewport: Node, event: InputEvent, shape_idx: int, pos: Vector2, normal: Vector2,
    cv: Vector2i) -> void:
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
            _handle_cell_click(cv)

func _on_cell_entered(cv: Vector2i) -> void:
    _show_tooltip(cv)

func _on_cell_exited() -> void:
    if _tooltip != null:
        _tooltip.visible = false

func _handle_cell_click(cv: Vector2i) -> void:
    if _city == null:
        return
    if CityArenaModel.ring_of(cv) == 0:
        _log(GameText.arena_center_msg())
        return
    if _city.cell_is_built(cv):
        _try_upgrade(cv)
        return
    if _selected == &"":
        _log(GameText.arena_select_msg())
        return
    if _selected == &"district":
        var can: Dictionary = _city.can_build_borough(cv)
        if bool(can.get("ok", false)):
            var ok: bool = _city.build_borough(cv)
            _log(GameText.arena_borough_built() if ok else GameText.arena_borough_not_built())
        else:
            _log(GameText.arena_borough_reason(str(can.get("reason", ""))))
        _refresh()
        return
    var def: UniqueBuilding.Def = BuildingDefs.def_by_id(_selected)
    if def == null:
        return
    var res: Dictionary = CityArenaModel.place_building(_city, def, cv)
    if bool(res.get("ok", false)):
        var ruins: String = ""
        if res.has("ruins_gold"):
            ruins = GameText.arena_ruins("%.0f" % float(res.get("ruins_gold", 0.0)))
        _log(GameText.arena_built(def.display_name, int(res.get("cost", 0.0)), ruins))
    else:
        _log(GameText.arena_not_built(str(res.get("reason", ""))))
    _refresh()

func _try_upgrade(cv: Vector2i) -> void:
    var b: UniqueBuilding = _city.get_building_at(cv)
    if b == null:
        var bo: Borough = _borough_at(cv)
        if bo != null:
            _log(GameText.arena_borough_info(bo.level))
        return
    var can: Dictionary = _city.can_upgrade_building(b)
    if bool(can.get("ok", false)) and _city.perform_upgrade(b):
        _log(GameText.arena_upgraded(b.def.display_name, b.level))
    else:
        _log(GameText.arena_upgrade_failed(str(can.get("reason", ""))))
    _refresh()

func _show_tooltip(cv: Vector2i) -> void:
    if _tooltip == null or _city == null:
        return
    var ring: int = CityArenaModel.ring_of(cv)
    var lines: Array[String] = [GameText.arena_cell_info(cv.x, cv.y, ring)]
    if ring > 0:
        var y: Dictionary = GameNumbers.ring_yield(ring)
        var parts: Array[String] = []
        for k in [&"food", &"industry", &"dust", &"science", &"influence"]:
            var v: float = float(y.get(k, 0.0))
            if v > 0.0:
                parts.append(str(k) + " " + ("%.1f" % v))
        lines.append(GameText.arena_ring_outputs(", ".join(parts) if not parts.is_empty() else "—"))
    var f: StringName = CityArenaModel.cell_feature(_city, cv)
    if f != &"":
        lines.append(CityArenaModel.feature_name(f))
    var b: UniqueBuilding = _city.get_building_at(cv)
    if b != null and b.def != null:
        var ring_bonus: float = 1.0 + GameNumbers.ring_bonus(b.def.id, ring)
        var total: float = CityArenaModel.building_mult(_city, b)
        var in_cluster: bool = CityArenaModel.cluster_uids(_city).has(b.uid)
        var cluster_note: String = GameText.arena_cluster_note() if in_cluster else ""
        lines.append(GameText.arena_building_tip(
            b.def.display_name, b.level, "%.2f" % ring_bonus, "%.2f" % total,
            cluster_note, b.assigned_workers))
    var bo: Borough = _borough_at(cv)
    if bo != null:
        lines.append(GameText.arena_borough_tip(bo.level, bo.net_approval()))
    _tooltip.text = "   |   ".join(lines)
    _tooltip.visible = true

func _on_turn_pressed() -> void:
    _advance_turn()

func _on_auto_tick() -> void:
    _advance_turn()

func _on_auto_pressed() -> void:
    if _auto:
        _stop_auto()
    else:
        _auto = true
        _auto_btn.text = GameText.arena_stop()
        _timer.start()
        _log(GameText.arena_auto_started())

func _stop_auto() -> void:
    _auto = false
    if _timer != null:
        _timer.stop()
    if _auto_btn != null:
        _auto_btn.text = GameText.arena_auto_button()

func _advance_turn() -> void:
    if _city == null:
        return
    _turn += 1
    var rep: Dictionary = CityArenaModel.run_turn(_city, _turn)
    if _city.starving:
        _starve_days += 1
    var net: float = float(rep.get("net_food", 0.0))
    var food: float = _city.food_stockpile
    var warn: String = ""
    if bool(rep.get("storm", false)):
        var pm: float = CityArenaModel.storm_production_mult(_city, _turn)
        var sm: String = GameText.arena_storm_info("%.2f" % pm, "%.1f" % float(rep.get("storm_food", 0.0)))
        warn = sm + warn
    if _city.starving:
        warn = GameText.arena_starving(_starve_days) + warn
    var clusters: int = int(rep.get("clusters", 0))
    var cl_note: String = GameText.arena_cluster(clusters) if clusters > 0 else ""
    _log(GameText.arena_turn_log(
        _turn, "%.0f" % food, "%+.1f" % net, "%.0f" % _city.prosperity,
        _city.level, warn, cl_note))
    _refresh()

func _on_hire_pressed() -> void:
    var n: int = CityArenaModel.hire_worker(_city)
    if n > 0:
        _log(GameText.arena_worker_hired(_city.pop_total()))
    else:
        _log(GameText.arena_no_worker())
    _refresh()

func _on_level_pressed() -> void:
    var can: Dictionary = ProsperitySystem.can_level_up(_city)
    if bool(can.get("ok", false)):
        if ProsperitySystem.try_level_up(_city):
            _log(GameText.arena_level_up(_city.level, _city.building_max_distance()))
        else:
            var reasons: Array[String] = []
            for r in can.get("reasons", []):
                reasons.append(str(r))
            _log(GameText.arena_level_reasons(", ".join(reasons)))
    _refresh()

func _on_reset_pressed() -> void:
    _new_game()

func _on_menu_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _log(msg: String) -> void:
    if _log_hud != null:
        _log_hud.text = msg

func _refresh() -> void:
    if _city == null:
        return
    _draw_arena()
    var food: float = _city.food_stockpile
    var industry: float = float(_city.storage.get(&"industry", 0.0))
    var gold: float = float(_city.storage.get(&"gold", 0.0))
    var net: float = _city.net_food()
    var storm_mark: String = GameText.arena_storm() if CityArenaModel.is_storm_turn(_turn) else ""
    var clusters: int = (CityArenaModel.clusters(_city) as Array).size()
    var cluster_mark: String = GameText.arena_cluster_mark(clusters) if clusters > 0 else ""
    _top_hud.text = GameText.arena_hud(
        _turn, "%.0f" % food, "%+.1f" % net, "%.0f" % industry, "%.0f" % gold,
        _city.pop_total(), "%.0f" % _city.prosperity, _city.level, storm_mark, cluster_mark)
    var score: float = CityArenaModel.score(_city, _starve_days)
    _score_hud.text = GameText.arena_score("%.0f" % score)

func _fit_camera() -> void:
    if _camera == null:
        return
    var cells: Array = CityArenaModel.cells_in_arena()
    var minv := Vector2(INF, INF)
    var maxv := Vector2(-INF, -INF)
    for cell in cells:
        var p: Vector2 = _hex_to_pixel(cell as Vector2i)
        minv = minv.min(p)
        maxv = maxv.max(p)
    var world_size: Vector2 = (maxv - minv) + Vector2(HEX_SIZE * 3.0, HEX_SIZE * 3.0)
    var vp: Vector2 = get_viewport().get_visible_rect().size
    var avail: Vector2 = Vector2(maxf(300.0, vp.x - 230.0), maxf(300.0, vp.y - 140.0))
    var zoom: float = minf(avail.x / world_size.x, avail.y / world_size.y)
    _camera.zoom = Vector2(zoom, zoom)
    _camera.position = Vector2((minv.x + maxv.x) * 0.5 + 115.0 / maxf(zoom, 0.05),
        (minv.y + maxv.y) * 0.5)
