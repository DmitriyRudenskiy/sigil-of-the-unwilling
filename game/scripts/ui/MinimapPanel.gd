class_name MinimapPanel
extends Control
## Панель миникарты. Геометрия 1:1 с prototype_map.html:
## рамка 3px, поля 24/32, карта 4:3 во всю ширину контент-бокса,
## компас N/S/W/E в полях панели (n/s ±2px, w/e ±9px, центр по второй оси).
##
## ВАЖНО (найдено бисекцией под godot-mcp, 2026-07): custom_minimum_size
## нельзя менять ПОСЛЕ первого layout-прохода (в NOTIFICATION_RESIZED и т.п.) —
## поздний рост min-высоты тянет RightColumn за низ окна и macOS-окно
## закрывается/зависает (в headless — молча). Поэтому cmin.y вычисляется
## один раз в _ready (ширина колонки известна из viewport), а RESIZED
## пере-раскладывает только карту и компас.

signal minimap_clicked(cell: Vector2i)
signal camera_jump_requested(direction: String)

const MINIMAP_COLORS := [
	ThemeConfig.C_MINIMAP_TERRAIN_WATER, ThemeConfig.C_MINIMAP_TERRAIN_2, ThemeConfig.C_MINIMAP_TERRAIN_3,
	ThemeConfig.C_MINIMAP_TERRAIN_GRASS, ThemeConfig.C_MINIMAP_TERRAIN_FOREST, ThemeConfig.C_MINIMAP_TERRAIN_6,
	ThemeConfig.C_MINIMAP_TERRAIN_7,
]
# Inset RightColumn: border 2px (StyleBox в AdventureUI._ready) + Margin 10px.
const COLUMN_INSET := 24

var map_ref: MapGenerator = null
var hero_ref: HeroController = null
var cam_ref: Camera2D = null
var _tex_rect: TextureRect
var _minimap_image: Image = null
var _minimap_texture: ImageTexture = null
var _last_pw := 0.0

@onready var _overlay: MinimapOverlay = $MapBox/Overlay
@onready var _map_box: Control = $MapBox
@onready var _compass: Dictionary = {
	"N": $N as Button,
	"S": $S as Button,
	"W": $W as Button,
	"E": $E as Button,
}

func _ready() -> void:
	_tex_rect = $MapBox/TextureRect as TextureRect
	_overlay.minimap_clicked.connect(func(cell): minimap_clicked.emit(cell))
	for d in _compass:
		(_compass[d] as Button).pressed.connect(func(): camera_jump_requested.emit(d))
	# cmin ДО первого layout: ширина панели известна из viewport (col = clamp(25vw,300,430)).
	var vp_w := get_viewport().get_visible_rect().size.x
	custom_minimum_size = Vector2(0, UILayout.minimap_panel_height(UILayout.sidebar_width(vp_w) - COLUMN_INSET))
	_apply_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()

## Раскладывает карту и компас по текущей ширине панели (прототип: width:100% + aspect 4/3).
## НЕТРОГАЕТ custom_minimum_size — см. комментарий в шапке.
func _apply_layout() -> void:
	# Settings.apply_display_mode флешит layout синхронно из _ready autoload —
	# RESIZED может прийти раньше инициализации @onready.
	if _map_box == null:
		return
	var pw := size.x
	if pw <= 1.0 or is_equal_approx(pw, _last_pw):
		return
	_last_pw = pw
	var map_w := pw - 2.0 * (UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_H)
	if map_w <= 8.0:
		return
	var map_h := map_w / UILayout.MINIMAP_ASPECT
	var panel_h := UILayout.minimap_panel_height(pw)

	_map_box.position = Vector2(
		UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_H,
		UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_V)
	_map_box.size = Vector2(map_w, map_h)

	# Кнопки ставим по ЦЕНТРУ номинальной CSS-коробки (cb): Godot Button с шрифтом 17
	# имеет мин. высоту ~32px, size=22 будет клэмпом — центрирование стабильнее краёв.
	var cb := UILayout.COMPASS_BTN
	_center_compass(_compass["N"], pw * 0.5, UILayout.MINIMAP_BORDER + UILayout.COMPASS_NS_INSET + cb.y * 0.5)
	_center_compass(_compass["S"], pw * 0.5, panel_h - UILayout.MINIMAP_BORDER - UILayout.COMPASS_NS_INSET - cb.y * 0.5)
	_center_compass(_compass["W"], UILayout.MINIMAP_BORDER + UILayout.COMPASS_WE_INSET + cb.x * 0.5, panel_h * 0.5)
	_center_compass(_compass["E"], pw - UILayout.MINIMAP_BORDER - UILayout.COMPASS_WE_INSET - cb.x * 0.5, panel_h * 0.5)

static func _center_compass(c: Control, cx: float, cy: float) -> void:
	c.position = Vector2(cx - c.size.x * 0.5, cy - c.size.y * 0.5)

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
	var w: int = map.map_width
	var h: int = map.map_height
	if _minimap_image == null or _minimap_image.get_width() != w or _minimap_image.get_height() != h:
		_minimap_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
		_minimap_texture = ImageTexture.create_from_image(_minimap_image)
		_tex_rect.texture = _minimap_texture
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var color: Color = MINIMAP_COLORS[clampi(map.get_terrain_id(cell), 0, MINIMAP_COLORS.size() - 1)]
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
