class_name MinimapPanel
extends VBoxContainer
## Миникарта + NSWE-навигация.

signal minimap_clicked(cell: Vector2i)
signal camera_jump_requested(direction: String)

const MINIMAP_COLORS := [
	Color(0.15, 0.35, 0.75), Color(0.2, 0.45, 0.4), Color(0.85, 0.75, 0.45),
	Color(0.35, 0.6, 0.3), Color(0.15, 0.35, 0.15), Color(0.45, 0.4, 0.35),
	Color(0.9, 0.93, 0.98),
]

var map_ref: MapGenerator = null
var hero_ref: HeroController = null
var cam_ref: Camera2D = null

var _tex_rect: TextureRect
var _overlay: MinimapOverlay


class MinimapOverlay extends Control:
	signal minimap_clicked(cell: Vector2i)

	var map_ref: MapGenerator = null
	var hero_ref: HeroController = null
	var cam_ref: Camera2D = null
	var _last_cam_pos := Vector2.ZERO
	var _last_zoom := Vector2.ONE
	var _last_hero_cell := Vector2i(-1, -1)


	func _process(_delta: float) -> void:
		if map_ref == null:
			return
		var dirty := false
		if cam_ref != null:
			if cam_ref.position != _last_cam_pos or cam_ref.zoom != _last_zoom:
				dirty = true
		if hero_ref != null and hero_ref.current_cell != _last_hero_cell:
			dirty = true
		if dirty:
			if cam_ref != null:
				_last_cam_pos = cam_ref.position
				_last_zoom = cam_ref.zoom
			if hero_ref != null:
				_last_hero_cell = hero_ref.current_cell
			queue_redraw()


	func _draw() -> void:
		if map_ref == null or not map_ref.has_valid_tilemap():
			return
		var s := size / Vector2(map_ref.map_width, map_ref.map_height)
		if cam_ref != null:
			var view_sz := get_viewport().get_visible_rect().size / cam_ref.zoom
			var top_left := cam_ref.position - view_sz / 2.0
			var c0 := map_ref.local_to_map(top_left)
			var c1 := map_ref.local_to_map(top_left + view_sz)
			draw_rect(Rect2(c0.x * s.x, c0.y * s.y, (c1.x - c0.x) * s.x, (c1.y - c0.y) * s.y),
				Color(1, 1, 1, 0.8), false, 1.0)
		if hero_ref != null:
			var cell := hero_ref.current_cell
			draw_rect(Rect2(cell.x * s.x - 2, cell.y * s.y - 2, 4, 4), Color(1.0, 0.85, 0.4))


	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if map_ref == null:
				return
			var s := size / Vector2(map_ref.map_width, map_ref.map_height)
			minimap_clicked.emit(Vector2i(int(ev.position.x / s.x), int(ev.position.y / s.y)))


func _ready() -> void:
	_build()


func _build() -> void:
	var box := Control.new()
	box.custom_minimum_size = Vector2(228, 228)
	add_child(box)

	_tex_rect = TextureRect.new()
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(_tex_rect)

	_overlay = MinimapOverlay.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.minimap_clicked.connect(func(cell): minimap_clicked.emit(cell))
	box.add_child(_overlay)

	var nswe := HBoxContainer.new()
	nswe.alignment = BoxContainer.ALIGNMENT_CENTER
	nswe.add_theme_constant_override("separation", 8)
	add_child(nswe)

	for d in ["N", "S", "W", "E"]:
		var b := Button.new()
		b.text = d
		b.custom_minimum_size = Vector2(36, 24)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): camera_jump_requested.emit(d))
		nswe.add_child(b)


func setup(map: MapGenerator, hero: HeroController, camera: Camera2D) -> void:
	map_ref = map
	hero_ref = hero
	cam_ref = camera

	_overlay.map_ref = map
	_overlay.hero_ref = hero
	_overlay.cam_ref = camera

	_build_minimap_image(map)


func _build_minimap_image(map: MapGenerator) -> void:
	if map == null:
		return
	var img := Image.create(map.map_width, map.map_height, false, Image.FORMAT_RGBA8)
	for y in map.map_height:
		for x in map.map_width:
			var t: int = map.terrain_grid.get(Vector2i(x, y), 0)
			img.set_pixel(x, y, MINIMAP_COLORS[t])
	_tex_rect.texture = ImageTexture.create_from_image(img)
