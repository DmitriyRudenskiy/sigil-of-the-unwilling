extends CanvasLayer
class_name MarkerLayer
## Overlays green/yellow/red dots on reachable hexes.

const _TerrainCostTable = preload("res://scripts/data/TerrainCostTable.gd")

signal marker_hovered(cell: Vector2i, cost: float, remaining: float, is_reachable: bool)
signal marker_clicked(cell: Vector2i, is_reachable: bool)

enum MarkType { GREEN, YELLOW, RED }

var _map_gen: MapGenerator
var _hero_cell: Vector2i
var _mp_current: float = 0.0
var _dist: Dictionary = {}  # cell -> cumulative cost from hero
var _reachable: Dictionary = {}  # cell -> MarkType
var _red_frontier: Dictionary = {}  # cell -> true
var _visible: bool = false

var _hex_size: float = 32.0  # default, recalculated on setup


func setup(map: MapGenerator) -> void:
	_map_gen = map
	layer = 5  # between terrain and units
	if _map_gen and _map_gen.has_valid_tilemap():
		var ts = _map_gen.tile_map.tile_set
		if ts:
			_hex_size = ts.tile_size.x * 0.5


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

	# Red frontier: unreachable neighbors of reachable cells
	var red_candidates: Dictionary = {}
	for cell in _reachable:
		for bit in 6:
			var nb = _HexUtils_get_neighbor(cell, bit)
			if not _dist.has(nb) or _dist[nb] > mp + 0.001:
				# Check if actually blocked or just too expensive
				if _map_gen.is_in_bounds(nb) and _map_gen.is_walkable(nb):
					# Too expensive — not red, just unreachable
					pass
				elif _map_gen.is_in_bounds(nb):
					red_candidates[nb] = true

	_red_frontier = red_candidates
	queue_redraw()


func hide_markers() -> void:
	_visible = false
	_reachable.clear()
	_red_frontier.clear()
	queue_redraw()


func _draw() -> void:
	if not _visible or not _map_gen or not _map_gen.has_valid_tilemap():
		return

	var time: float = Time.get_ticks_msec() / 1000.0

	# Green dots (pulse)
	for cell in _reachable:
		if _reachable[cell] != MarkType.GREEN:
			continue
		var pos: Vector2 = _map_gen.map_to_local(cell)
		var pulse: float = 1.0 + sin(time * 3.0) * 0.15
		var r: float = _hex_size * 0.18 * pulse
		draw_circle(pos, r, Color(0.2, 0.85, 0.2, 0.75))

	# Yellow dots (smaller, static)
	for cell in _reachable:
		if _reachable[cell] != MarkType.YELLOW:
			continue
		var pos: Vector2 = _map_gen.map_to_local(cell)
		var r: float = _hex_size * 0.10
		draw_circle(pos, r, Color(1.0, 0.85, 0.1, 0.8))

	# Red frontier dots (tiny, sparse)
	for cell in _red_frontier:
		var pos: Vector2 = _map_gen.map_to_local(cell)
		var r: float = _hex_size * 0.08
		draw_circle(pos, r, Color(0.9, 0.2, 0.2, 0.6))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		var cell := _screen_to_cell(pos)
		if cell == null:
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			var is_green_or_yellow: bool = _reachable.has(cell) and _reachable[cell] != MarkType.RED
			if is_green_or_yellow:
				marker_clicked.emit(cell, true)
			elif _red_frontier.has(cell):
				marker_clicked.emit(cell, false)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			pass  # handled elsewhere

	elif event is InputEventMouseMotion and _visible:
		var cell := _screen_to_cell(event.position)
		if cell != null:
			var is_reachable: bool = _reachable.has(cell) and _reachable[cell] != MarkType.RED
			var cost: float = _dist.get(cell, INF)
			var remaining: float = _mp_current - cost
			if not is_reachable and _red_frontier.has(cell):
				remaining = -remaining  # show deficit
			marker_hovered.emit(cell, cost, remaining, is_reachable)


func _screen_to_cell(pos: Vector2) -> Vector2i:
	if not _map_gen or not _map_gen.has_valid_tilemap():
		return null
	return _map_gen.local_to_map(pos)


# Inline neighbor to avoid circular preload
static func _HexUtils_get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
	# Simplified: use even-r offsets (good enough for frontier detection)
	var neighbors := [
		Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	if (cell.y & 1) == 1:
		neighbors = [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
		]
	return cell + neighbors[bit]
