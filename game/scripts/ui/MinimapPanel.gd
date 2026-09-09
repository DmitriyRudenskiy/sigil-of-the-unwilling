class_name MinimapPanel
extends VBoxContainer

signal minimap_clicked(cell: Vector2i)
signal camera_jump_requested(direction: String)

const MINIMAP_COLORS := [
	ThemeConfig.C_MINIMAP_TERRAIN_WATER, ThemeConfig.C_MINIMAP_TERRAIN_2, ThemeConfig.C_MINIMAP_TERRAIN_3,
	ThemeConfig.C_MINIMAP_TERRAIN_GRASS, ThemeConfig.C_MINIMAP_TERRAIN_FOREST, ThemeConfig.C_MINIMAP_TERRAIN_6,
	ThemeConfig.C_MINIMAP_TERRAIN_7,
]

var map_ref: MapGenerator = null
var hero_ref: HeroController = null
var cam_ref: Camera2D = null

var _tex_rect: TextureRect
@onready var _overlay: MinimapOverlay = $MapBox/Overlay

var _minimap_image: Image = null
var _minimap_texture: ImageTexture = null

func _ready() -> void:
	var box := get_node("MapBox") as Control
	_tex_rect = box.get_node("TextureRect") as TextureRect

	_overlay.minimap_clicked.connect(func(cell): minimap_clicked.emit(cell))
	var nswe := get_node("NSWE") as HBoxContainer
	for d in ["N", "S", "W", "E"]:
		(nswe.get_node(d) as Button).pressed.connect(func(): camera_jump_requested.emit(d))

func setup(map: MapGenerator, hero: HeroController, camera: Camera2D) -> void:
	map_ref = map
	hero_ref = hero
	cam_ref = camera

	_overlay.map_ref = map
	_overlay.hero_ref = hero
	_overlay.cam_ref = camera

	_build_minimap_image(map)

func _build_minimap_image(map: MapGenerator, visibility = null) -> void:
	if map == null:
		return
	if _minimap_image == null or _minimap_image.get_width() != map.map_width or _minimap_image.get_height() != map.map_height:
		_minimap_image = Image.create(map.map_width, map.map_height, false, Image.FORMAT_RGBA8)
		_minimap_texture = ImageTexture.create_from_image(_minimap_image)
		_tex_rect.texture = _minimap_texture
	for y in map.map_height:
		for x in map.map_width:
			var cell := Vector2i(x, y)
			var t: int = map.terrain_grid.get(cell, 0)
			var color: Color = MINIMAP_COLORS[t] if t < MINIMAP_COLORS.size() else Color.BLACK
			if visibility != null:
				if not visibility.is_explored(cell):
					color = Color.BLACK
				elif not visibility.is_visible(cell):
					color = color.lerp(ThemeConfig.C_FOG_GRAY, 0.55)
			_minimap_image.set_pixel(x, y, color)
	_minimap_texture.update(_minimap_image)

func refresh() -> void:
	if map_ref != null:
		_build_minimap_image(map_ref, map_ref.visibility)
	_overlay.queue_redraw()
