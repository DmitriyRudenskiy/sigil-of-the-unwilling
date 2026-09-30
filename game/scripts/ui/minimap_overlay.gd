extends Control
class_name MinimapOverlay

signal minimap_clicked(cell: Vector2i)

var map_ref: MapGenerator = null

var hero_ref: Node = null
var cam_ref: Camera2D = null
var city_mgr: Node = null

var _texture: ImageTexture = null
var _last_cam_pos: Vector2 = Vector2.ZERO
var _last_zoom: float = 1.0
var _last_hero_cell: Vector2i = Vector2i.ZERO
var _last_city_count := -1
const MOVE_THRESHOLD := 8.0
const HERO_RADIUS := 4.0
# Прототип: #minimap { border: 2px solid var(--gold-hi) } — рисуем поверх текстуры карты.
const C_MAP_BORDER := Color("#f3d68c")

func _ready() -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	var n: int = city_mgr.cities.size() if city_mgr != null and "cities" in city_mgr else -1
	if n != _last_city_count:
		_last_city_count = n
		queue_redraw()
	if cam_ref == null:
		return
	var pos: Vector2 = cam_ref.position
	var zoom: float = cam_ref.zoom.x
	var changed := (pos - _last_cam_pos).length() > MOVE_THRESHOLD or absf(zoom - _last_zoom) > 0.01
	if changed:
		_last_cam_pos = pos
		_last_zoom = zoom
		queue_redraw()

func _draw() -> void:
	var size_ := get_rect().size
	if map_ref != null and _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size_), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size_), ThemeConfig.C_MINIMAP_BG, true)
		_draw_cross(size_)
	_draw_camera_rect(size_)
	_draw_city_dots(size_)
	_draw_hero_dot(size_)
	_draw_map_border(size_)

func _draw_map_border(size_: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size_), C_MAP_BORDER, false, UILayout.MINIMAP_MAP_BORDER)

func _draw_cross(size_: Vector2) -> void:
	var c := ThemeConfig.C_MINIMAP_CROSS
	draw_line(Vector2(size_.x * 0.5, 0), Vector2(size_.x * 0.5, size_.y), c, 1.0)
	draw_line(Vector2(0, size_.y * 0.5), Vector2(size_.x, size_.y * 0.5), c, 1.0)

func _draw_camera_rect(size_: Vector2) -> void:
	if cam_ref == null or map_ref == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var half_w := vp.x / 2.0 / cam_ref.zoom.x
	var half_h := vp.y / 2.0 / cam_ref.zoom.x
	var rect_pos := _world_to_overlay(cam_ref.position, size_)
	var rect_sz := Vector2(half_w * 2.0, half_h * 2.0)
	draw_rect(Rect2(rect_pos - rect_sz * 0.5, rect_sz), ThemeConfig.C_MINIMAP_VIEWPORT, true)
	draw_rect(Rect2(rect_pos - rect_sz * 0.5, rect_sz), ThemeConfig.C_MINIMAP_BORDER, false, 1.0)

func _draw_hero_dot(size_: Vector2) -> void:
	if hero_ref == null or map_ref == null:
		return

	if not ("current_cell" in hero_ref):
		return
	var cell: Vector2i = hero_ref.current_cell
	_last_hero_cell = cell
	var pos: Vector2 = _world_to_overlay(map_ref.map_to_local(cell), size_)
	draw_circle(pos, HERO_RADIUS, ThemeConfig.C_MINIMAP_HERO)
	draw_arc(pos, HERO_RADIUS + 2.0, 0, TAU, 16, ThemeConfig.C_MINIMAP_HERO_RING, 1.0)

func _draw_city_dots(size_: Vector2) -> void:
	if city_mgr == null or map_ref == null or not ("cities" in city_mgr):
		return
	for city in city_mgr.cities:
		if city == null or not ("center" in city) or city.center.x < 0:
			continue
		var pos: Vector2 = _world_to_overlay(map_ref.map_to_local(city.center), size_)
		if "is_capital" in city and city.is_capital:
			draw_rect(Rect2(pos - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), ThemeConfig.C_MINIMAP_CAPITAL)
		else:
			draw_rect(Rect2(pos - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), ThemeConfig.C_MINIMAP_CITY)

func _world_to_overlay(world_pos: Vector2, size_: Vector2) -> Vector2:
	if map_ref == null or map_ref.map_width <= 0 or map_ref.map_height <= 0:
		return world_pos
	var sx := size_.x / float(map_ref.map_width)
	var sy := size_.y / float(map_ref.map_height)
	return Vector2(world_pos.x * sx, world_pos.y * sy)

func _gui_input(event: InputEvent) -> void:
	var pe := event as InputEventMouseButton
	if pe == null or not pe.pressed:
		return
	if map_ref == null or map_ref.map_width <= 0 or map_ref.map_height <= 0:
		return
	var size_ := get_rect().size
	var sx := size_.x / float(map_ref.map_width)
	var sy := size_.y / float(map_ref.map_height)
	var local_pos: Vector2 = get_global_mouse_position() - global_position
	var cell := Vector2i(int(local_pos.x / sx), int(local_pos.y / sy))
	cell.x = clampi(cell.x, 0, map_ref.map_width - 1)
	cell.y = clampi(cell.y, 0, map_ref.map_height - 1)
	minimap_clicked.emit(cell)

func update_texture(tex: ImageTexture) -> void:
	_texture = tex
