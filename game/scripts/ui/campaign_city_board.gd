class_name CampaignCityBoard
extends Control

signal cell_selected(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")
const BUILDING_ICON_ROLES := [
	["food_production", "farm"], ["agriculture", "farm"],
	["wood_production", "mill"], ["woodworking", "mill"],
	["iron_production", "mine"], ["metalworking", "smithy"],
	["military_training", "barracks"], ["static_defense", "walls"],
	["housing", "shack"], ["education", "school"], ["education_service", "school"],
	["religious_service", "great_temple"], ["administration", "market"],
	["community_service", "market"],
]
const BUILDING_ART_BY_ID := {
	"campaign_farm": "building_farmhouse.webp",
	"campaign_sawmill": "building_sawmill.webp",
	"campaign_housing": "building_longhouse.webp",
	"campaign_barracks": "building_barracks.webp",
	"aoe4_archery_range": "building_archery_range.webp",
	"aoe4_barracks": "building_barracks.webp",
	"aoe4_stable": "building_stable.webp",
	"aoe4_war_stable": "building_stable.webp",
	"terrascape_fruit_farm": "building_farmhouse.webp",
	"terrascape_pond_farm": "building_greenhouse.webp",
	"terrascape_shieling": "building_longhouse.webp",
	"terrascape_kenbet": "building_academy.webp",
	"terrascape_hospital": "building_apothecary.webp",
	"terrascape_herb_garden": "building_greenhouse.webp",
	"terrascape_sanctuary": "building_temple.webp",
	"terrascape_henge": "building_temple.webp",
	"aoe4_buddhist_temple": "building_temple.webp",
	"aoe4_temple_of_equality": "building_temple.webp",
	"aoe4_town_center": "building_town_hall.webp",
	"aoe4_capital_town_center": "building_town_hall.webp",
}
static var _building_art_cache: Dictionary = {}

var city: City
var catalog: Dictionary = {}
var terrain_provider: Callable = Callable()
var selected_cell := Vector2i(-1, -1)
var preview_anchor := Vector2i(-1, -1)
var preview_footprint: Array[Vector2i] = []
var preview_valid := false
var _cells: Array[Vector2i] = []
var _centers: Dictionary = {}
var _terrain_ids: Dictionary = {}
var _hovered_cell := Vector2i(-1, -1)
var _layout_dirty := true
var _radius := 20.0
var _atlas: Texture2D

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_atlas = load("res://assets/textures/hex_sheet_0.png") as Texture2D
	resized.connect(queue_redraw)

func bind_city(value: City, building_catalog: Dictionary, terrain_fn: Callable = Callable()) -> void:
	city = value
	catalog = building_catalog
	terrain_provider = terrain_fn
	_cells = CampaignBuildingPlacement.city_cells(city.center) if city != null else []
	_terrain_ids.clear()
	if city != null and terrain_provider.is_valid():
		for cell in _cells:
			_terrain_ids[cell] = int(terrain_provider.call(cell))
	_layout_dirty = true
	queue_redraw()

func get_rendered_cells() -> Array[Vector2i]:
	return _cells.duplicate()

func get_cell_visual(cell: Vector2i) -> Dictionary:
	if not _cells.has(cell) or city == null:
		return {}
	var legacy := ""
	for building in city.buildings:
		if building != null and building.def != null and building.cell == cell:
			legacy = String(building.def.id)
	var campaign := ""
	var campaign_state := ""
	var remaining := 0
	for building in city.campaign_buildings:
		if not (building is Dictionary):
			continue
		var anchor: Vector2i = building.get("cell", Vector2i.ZERO)
		var footprint := CampaignBuildingPlacement.footprint_cells(
			anchor, building.get("footprint", [[0, 0]]))
		if footprint.is_empty():
			footprint = [anchor]
		if footprint.has(cell):
			campaign = String(building.get("id", ""))
			campaign_state = String(building.get("state", "active"))
			remaining = int(building.get("construction_turns_remaining", 0))
	return {
		"cell": cell,
		"ring": HexUtils.core_distance(city.center, cell),
		"terrain_id": _terrain_ids.get(cell, -1),
		"terrain_name": HexUtils.TERRAIN_NAMES[int(_terrain_ids[cell])] \
			if _terrain_ids.has(cell) and int(_terrain_ids[cell]) >= 0 \
			and int(_terrain_ids[cell]) < HexUtils.TERRAIN_NAMES.size() else "",
		"legacy_building_id": legacy,
		"campaign_building_id": campaign,
		"campaign_state": campaign_state,
		"construction_turns_remaining": remaining,
		"occupied": not legacy.is_empty() or not campaign.is_empty() or city.cell_is_built(cell),
	}

func get_terrain_by_cell() -> Dictionary:
	var terrains := {}
	for cell in _cells:
		if _terrain_ids.has(cell):
			terrains[cell] = HexUtils.TERRAIN_NAMES[int(_terrain_ids[cell])]
	return terrains

func set_selection(cell: Vector2i) -> void:
	if _cells.has(cell):
		selected_cell = cell
		queue_redraw()

func set_placement_preview(building: Dictionary, anchor: Vector2i, valid: bool) -> void:
	preview_anchor = anchor
	preview_footprint = CampaignBuildingPlacement.footprint_cells(
		anchor, building.get("footprint", [[0, 0]]))
	preview_valid = valid
	queue_redraw()

func clear_placement_preview() -> void:
	preview_anchor = Vector2i(-1, -1)
	preview_footprint.clear()
	preview_valid = false
	queue_redraw()

func cell_at_position(local_position: Vector2) -> Vector2i:
	_ensure_layout()
	var closest := Vector2i(-1, -1)
	var closest_distance := INF
	for cell in _cells:
		var distance := local_position.distance_to(_centers[cell])
		if distance < closest_distance:
			closest = cell
			closest_distance = distance
	return closest if closest_distance <= _radius * 1.05 else Vector2i(-1, -1)

func get_cell_center(cell: Vector2i) -> Vector2:
	_ensure_layout()
	return _centers.get(cell, Vector2(-1, -1))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := cell_at_position(event.position)
		if cell != _hovered_cell:
			_hovered_cell = cell
			cell_hovered.emit(cell)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		var cell := cell_at_position(event.position)
		if cell != Vector2i(-1, -1):
			selected_cell = cell
			grab_focus()
			cell_selected.emit(cell)
			queue_redraw()
			accept_event()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		_move_selection(event.keycode)
		accept_event()

func _move_selection(keycode: Key) -> void:
	_ensure_layout()
	if _cells.is_empty():
		return
	if not _cells.has(selected_cell):
		selected_cell = _cells[0]
	else:
		var direction := Vector2.LEFT if keycode == KEY_LEFT else Vector2.RIGHT \
			if keycode == KEY_RIGHT else Vector2.UP if keycode == KEY_UP else Vector2.DOWN
		var origin: Vector2 = _centers[selected_cell]
		var best_score := -INF
		var next := selected_cell
		for cell in _cells:
			if cell == selected_cell:
				continue
			var delta: Vector2 = _centers[cell] - origin
			var alignment := delta.normalized().dot(direction)
			if alignment <= 0.0:
				continue
			var score := alignment * 1000.0 - delta.length()
			if score > best_score:
				best_score = score
				next = cell
		selected_cell = next
	cell_selected.emit(selected_cell)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_dirty = true

func _draw() -> void:
	_ensure_layout()
	if _centers.size() != _cells.size():
		return
	for cell in _cells:
		var visual := get_cell_visual(cell)
		var center: Vector2 = _centers[cell]
		var polygon := _hex_polygon(center, _radius)
		_draw_terrain(cell, visual, center)
		var ring := int(visual.ring)
		if ring == 0:
			draw_colored_polygon(polygon, Color(0.95, 0.73, 0.30, 0.10))
		var edge_color := Color("#d6c28d") if ring == 0 else Color("#4b493c")
		draw_polyline(_closed_polygon(polygon), edge_color, 1.5 if ring == 0 else 1.0, true)
	for cell in _cells:
		var visual := get_cell_visual(cell)
		var center: Vector2 = _centers[cell]
		var polygon := _hex_polygon(center, _radius)
		_draw_building(visual, center)
		if preview_footprint.has(cell):
			var preview_color := Color("#48d2bd") if preview_valid else Color("#ed6d56")
			draw_colored_polygon(polygon, Color(preview_color, 0.30))
			draw_polyline(_closed_polygon(polygon), preview_color, 3.0, true)
		if cell == selected_cell:
			draw_polyline(_closed_polygon(polygon), Color("#77e4da"), 3.0, true)
			_draw_cell_focus(center)

func _ensure_layout() -> void:
	if not _layout_dirty:
		return
	_layout_dirty = false
	_centers.clear()
	if _cells.is_empty() or size.x <= 0.0 or size.y <= 0.0 or city == null:
		return
	var center_cube := HexUtils.offset_to_cube(city.center)
	var normalized := {}
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for cell in _cells:
		var cube := HexUtils.offset_to_cube(cell) - center_cube
		var point := Vector2(sqrt(3.0) * (float(cube.x) + float(cube.z) / 2.0), 1.5 * float(cube.z))
		normalized[cell] = point
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	_radius = maxf(18.0, minf((size.x - 32.0) / (max_x - min_x + sqrt(3.0)),
		(size.y - 32.0) / (max_y - min_y + 2.0)))
	var used := Vector2((min_x + max_x) * _radius / 2.0, (min_y + max_y) * _radius / 2.0)
	var offset := size / 2.0 - used
	for cell in normalized:
		_centers[cell] = offset + normalized[cell] * _radius

static func building_art_path(building_id: String) -> String:
	var filename := String(BUILDING_ART_BY_ID.get(building_id, ""))
	if filename.is_empty() and building_id.begins_with("aoe4_") and building_id.contains("palace"):
		filename = "building_palace.webp"
	return "res://assets/textures/objects/" + filename if not filename.is_empty() else ""

static func building_art_texture(building_id: String) -> Texture2D:
	var path := building_art_path(building_id)
	if path.is_empty():
		return null
	if not _building_art_cache.has(path):
		_building_art_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _building_art_cache[path]

static func icon_id_for_building(building_id: String, building_catalog: Dictionary) -> String:
	var exact_path := ThemeConfig.ICON_DIR_BUILDINGS + building_id + ".png"
	if ResourceLoader.exists(exact_path):
		return building_id
	for definition in building_catalog.get("buildings", []):
		if String(definition.get("id", "")) != building_id:
			continue
		for mapping in BUILDING_ICON_ROLES:
			if definition.get("roles", []).has(mapping[0]):
				return String(mapping[1])
		break
	return "fallback"

func _terrain_atlas_coord(terrain_id: int) -> Vector2i:
	match terrain_id:
		HexUtils.Terrain.WATER, HexUtils.Terrain.RIVER: return Vector2i(4, 0)
		HexUtils.Terrain.SWAMP: return Vector2i(7, 6)
		HexUtils.Terrain.SAND: return Vector2i(1, 0)
		HexUtils.Terrain.GRASS: return Vector2i(0, 0)
		HexUtils.Terrain.FOREST: return Vector2i(0, 0)
		HexUtils.Terrain.MOUNTAIN: return Vector2i(5, 0)
		HexUtils.Terrain.SNOW: return Vector2i(2, 0)
		HexUtils.Terrain.ROAD: return Vector2i(6, 0)
		HexUtils.Terrain.DENSE_FOREST: return Vector2i(3, 0)
	return Vector2i(-1, -1)

func _draw_terrain(_cell: Vector2i, visual: Dictionary, center: Vector2) -> void:
	var source := _terrain_atlas_coord(int(visual.terrain_id))
	var polygon := _hex_polygon(center, _radius)
	if _atlas != null and source.x >= 0:
		var cell_size := Vector2(_atlas.get_size()) / 8.0
		var draw_size := Vector2(sqrt(3.0) * _radius, 2.0 * _radius)
		draw_texture_rect_region(_atlas, Rect2(center - draw_size * 0.5, draw_size),
			Rect2(Vector2(source) * cell_size, cell_size))
	else:
		draw_colored_polygon(polygon, Color("#666150"))
	draw_colored_polygon(polygon, Color(0.07, 0.06, 0.04, 0.12))

func _draw_building(visual: Dictionary, center: Vector2) -> void:
	var building_id := String(visual.campaign_building_id)
	var legacy_id := String(visual.legacy_building_id)
	if building_id.is_empty() and legacy_id.is_empty():
		return
	var id := building_id if not building_id.is_empty() else legacy_id
	var texture := building_art_texture(id) if not building_id.is_empty() else null
	if texture != null:
		var side := _radius * 1.55
		draw_texture_rect(texture, Rect2(center - Vector2.ONE * side / 2.0, Vector2.ONE * side), false)
	else:
		var icon_id := icon_id_for_building(id, catalog) if not building_id.is_empty() else id
		texture = BuildingDefs.get_icon(StringName(icon_id))
		if texture != null:
			var side := minf(_radius * 0.82, 40.0)
			draw_circle(center, side * 0.68, Color("#171915", 0.88))
			draw_arc(center, side * 0.68, 0.0, TAU, 24, Color("#c6a65e", 0.9), 1.5, true)
			draw_texture_rect(texture, Rect2(center - Vector2.ONE * side / 2.0, Vector2.ONE * side), false)
		else:
			draw_string(get_theme_default_font(), center, "⌂", HORIZONTAL_ALIGNMENT_CENTER,
				_radius, 20, Color.WHITE)
	if not building_id.is_empty():
		if int(visual.construction_turns_remaining) > 0:
			draw_string(get_theme_default_font(), center + Vector2(-_radius * 0.55, -_radius * 0.45),
				"⌛%d" % int(visual.construction_turns_remaining), HORIZONTAL_ALIGNMENT_LEFT,
				_radius, 13, Color("#fff0cb"))
		elif String(visual.campaign_state) == "ruined":
			draw_string(get_theme_default_font(), center + Vector2(-_radius * 0.3, _radius * 0.35),
				"×", HORIZONTAL_ALIGNMENT_LEFT, _radius, 20, Color("#ff7562"))

func _draw_cell_focus(center: Vector2) -> void:
	if has_focus():
		draw_arc(center, _radius * 0.84, 0.0, TAU, 6, Color.WHITE, 1.5, true)

func _hex_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := PI / 3.0 * i - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed
