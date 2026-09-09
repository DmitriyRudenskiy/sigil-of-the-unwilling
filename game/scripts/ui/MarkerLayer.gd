extends Node2D
class_name MarkerLayer

const _TerrainCostTable = preload("res://scripts/data/TerrainCostTable.gd")

signal marker_hovered(cell: Vector2i, cost: float, remaining: float, is_reachable: bool)
signal marker_clicked(cell: Vector2i, is_reachable: bool)
signal city_marker_clicked(city: City)

enum MarkType { GREEN, YELLOW, RED }

const _COLOR_GREEN := ThemeConfig.C_MARKER_GREEN
const _COLOR_YELLOW := ThemeConfig.C_MARKER_YELLOW
const _COLOR_RED := ThemeConfig.C_MARKER_RED

var _map_gen: MapGenerator
var _hero_cell: Vector2i
var _mp_current: float = 0.0
var _dist: Dictionary = {}
var _reachable: Dictionary = {}
var _red_frontier: Dictionary = {}
var _visible: bool = false
var _green_pos: PackedVector2Array = PackedVector2Array()
var _yellow_pos: PackedVector2Array = PackedVector2Array()
var _red_pos: PackedVector2Array = PackedVector2Array()

var _hex_size: float = 32.0
var _city_marks: Array = []
var _threat_pos: PackedVector2Array = PackedVector2Array()
var _terrain_mgr: Variant = null
var _terrain_pos: Dictionary = {}

func setup(map: MapGenerator) -> void:
	_map_gen = map
	z_index = 5
	if _map_gen and _map_gen.has_valid_tilemap():
		_hex_size = _map_gen.get_tile_size().x * 0.5

func show_markers(hero_cell: Vector2i, mp: float, dist_map: Dictionary) -> void:
	_hero_cell = hero_cell
	_mp_current = mp
	_dist = dist_map
	_reachable.clear()
	_red_frontier.clear()
	_visible = true

	for cell in _dist:
		var cost: float = _dist[cell]
		if cost <= mp + 0.001:
			var remaining: float = mp - cost
			if remaining >= 1.0:
				_reachable[cell] = MarkType.GREEN
			else:
				_reachable[cell] = MarkType.YELLOW

	var red_candidates: Dictionary = {}
	for cell in _reachable:
		for nb in HexUtils.get_all_neighbors(cell):
			if not _map_gen.is_in_bounds(nb) or nb in _reachable:
				continue
			var can_enter_within_budget: bool = _map_gen.is_walkable(nb) and _dist.get(nb, INF) <= mp + 0.001
			if not can_enter_within_budget:
				red_candidates[nb] = true

	_red_frontier = red_candidates

	_green_pos.clear()
	_yellow_pos.clear()
	_red_pos.clear()
	if _map_gen and _map_gen.has_valid_tilemap():
		for cell in _reachable:
			if _reachable[cell] == MarkType.GREEN:
				_green_pos.append(_map_gen.map_to_local(cell))
			else:
				_yellow_pos.append(_map_gen.map_to_local(cell))
		for cell in _red_frontier:
			_red_pos.append(_map_gen.map_to_local(cell))

	queue_redraw()

func hide_markers() -> void:
	_visible = false
	_reachable.clear()
	_red_frontier.clear()
	_green_pos.clear()
	_yellow_pos.clear()
	_red_pos.clear()
	queue_redraw()

func set_city_markers(cities: Array) -> void:
	_city_marks.clear()
	if _map_gen == null or not _map_gen.has_valid_tilemap():
		return
	for city in cities:
		if city == null:
			continue
		_city_marks.append({"cell": city.center, "pos": _map_gen.map_to_local(city.center), "city": city})
	queue_redraw()

func city_at_cell(cell: Vector2i) -> City:
	for m in _city_marks:
		if m.cell == cell:
			return m.city
	return null

func set_threat_markers(cells: Array) -> void:
	_threat_pos.clear()
	if _map_gen == null or not _map_gen.has_valid_tilemap():
		queue_redraw()
		return
	for cell in cells:
		if cell is Vector2i:
			_threat_pos.append(_map_gen.map_to_local(cell))
	queue_redraw()

func set_terrain_resource_markers(terrain_mgr: Variant) -> void:
	_terrain_mgr = terrain_mgr
	_terrain_pos.clear()
	if _map_gen == null or not _map_gen.has_valid_tilemap() or terrain_mgr == null:
		queue_redraw()
		return
	for cell in terrain_mgr.cells:
		if cell is Vector2i:
			_terrain_pos[cell] = {"pos": _map_gen.map_to_local(cell), "exhausted": terrain_mgr.is_exhausted(cell)}
	queue_redraw()

func refresh_terrain_markers() -> void:
	if _terrain_mgr == null:
		return
	_terrain_pos.clear()
	if _map_gen == null or not _map_gen.has_valid_tilemap():
		queue_redraw()
		return
	for cell in _terrain_mgr.cells:
		if cell is Vector2i:
			_terrain_pos[cell] = {"pos": _map_gen.map_to_local(cell), "exhausted": _terrain_mgr.is_exhausted(cell)}
	queue_redraw()

func _process(_d: float) -> void:
	if (_visible and not _green_pos.is_empty()) or not _threat_pos.is_empty():
		queue_redraw()

func _draw() -> void:
	if not _map_gen or not _map_gen.has_valid_tilemap():
		return

	var pulse_t: float = Time.get_ticks_msec() / 1000.0
	for pos in _threat_pos:
		var ring_r: float = _hex_size * (0.30 + 0.08 * sin(pulse_t * 4.0))
		draw_arc(pos, ring_r, 0.0, TAU, 32, ThemeConfig.C_MARKER_DANGER_ARC, 2.5)

	for m in _city_marks:
		var pos: Vector2 = m.pos
		draw_circle(pos, _hex_size * 0.22, ThemeConfig.C_MARKER_MAGIC_FILL)
		draw_arc(pos, _hex_size * 0.22, 0.0, TAU, 32, ThemeConfig.C_MARKER_MAGIC_RING, 2.0)
		draw_string(
			ThemeDB.fallback_font, pos + Vector2(0.0, -_hex_size * 0.30),
			m.city.display_name, HORIZONTAL_ALIGNMENT_CENTER,
			int(_hex_size * 2.0), 14, ThemeConfig.C_MARKER_LABEL)

	for cell in _terrain_pos:
		var m: Dictionary = _terrain_pos[cell]
		var pos: Vector2 = m["pos"]
		var glyph: String = "✗" if m["exhausted"] else "⛏️"
		var color: Color = ThemeConfig.C_MARKER_EXHAUSTED if m["exhausted"] else ThemeConfig.C_MARKER_ACTIVE
		draw_string(ThemeDB.fallback_font, pos, glyph, HORIZONTAL_ALIGNMENT_CENTER,
			int(_hex_size * 1.6), 14, color)

	if not _visible:
		return

	var pulse: float = 1.0 + sin(Time.get_ticks_msec() / 1000.0 * 3.0) * 0.15
	var r_green: float = _hex_size * 0.18 * pulse
	for pos in _green_pos:
		draw_circle(pos, r_green, _COLOR_GREEN)

	var r_yellow: float = _hex_size * 0.10
	for pos in _yellow_pos:
		draw_circle(pos, r_yellow, _COLOR_YELLOW)

	var r_red: float = _hex_size * 0.08
	for pos in _red_pos:
		draw_circle(pos, r_red, _COLOR_RED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell := _screen_to_cell(get_global_mouse_position())
		if cell == Vector2i(-1, -1):
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(cell)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			pass

	elif event is InputEventMouseMotion and _visible:
		var cell := _screen_to_cell(get_global_mouse_position())
		if cell != Vector2i(-1, -1):
			var is_reachable: bool = _reachable.has(cell) and _reachable[cell] != MarkType.RED
			var cost: float = _dist.get(cell, INF)
			var remaining: float = _mp_current - cost
			if not is_reachable and _red_frontier.has(cell):
				remaining = -remaining
			marker_hovered.emit(cell, cost, remaining, is_reachable)

func _handle_left_click(cell: Vector2i) -> void:
	var c: City = city_at_cell(cell)
	if c != null:
		city_marker_clicked.emit(c)
		get_viewport().set_input_as_handled()
		return
	var is_green_or_yellow: bool = _reachable.has(cell) and _reachable[cell] != MarkType.RED
	if is_green_or_yellow:
		marker_clicked.emit(cell, true)
		get_viewport().set_input_as_handled()
	elif _red_frontier.has(cell):
		marker_clicked.emit(cell, false)
		get_viewport().set_input_as_handled()

func _screen_to_cell(world_pos: Vector2) -> Vector2i:
	if not _map_gen or not _map_gen.has_valid_tilemap():
		return Vector2i(-1, -1)
	return _map_gen.world_to_map(world_pos)
