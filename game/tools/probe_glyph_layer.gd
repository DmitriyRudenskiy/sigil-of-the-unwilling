class_name ProbeGlyphLayer
extends Node2D
## Зонд T-344: куда ложатся чернила marker_layer при продакшн-параметрах.
## Протокол. Кадр = shot_scene (настоящий рендер, CanvasItem.draw_string).
## Параметры 1:1 с marker_layer.gd:178–191: ThemeDB.fallback_font,
## HORIZONTAL_ALIGNMENT_CENTER, size 14, W = int(_hex·1.6)/int(_hex·2.0),
## _hex = tile_set.tile_size.y·0.5 (:38), pos = TileMapLayer.map_to_local(cell)
## без предсдвига (:141/:153), тайлы — HexCellArt.build_hex_tileset().
## Варианты в кадре: [0] «✗» W=1.6, [1] «⛏️» W=1.6, [2] «Камень» W=2.0,
## [3] «✗» W=-1 (бокс выключен) — контроль центрирования.
## Чернила рисуются магентой (1,0,1) — по ней и считаются; фон чисто-синий.
## Развилка (предзарегистрирована): пересекают ли чернила альфа-маску СВОЕЙ
## ячейки (силуэт тайла, дилатация 2 px = допуск AA). Пересекли = ПОДТВЕРЖДЁН.

const BIOME := 0
const STRIDE := 3
const INK := Color(1.0, 0.0, 1.0, 1.0)
const PLAN := [["✗", 1.6], ["⛏️", 1.6], ["Камень", 2.0], ["✗", -1.0]]

var _layer: TileMapLayer
@export var with_glyphs: bool = true


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 1.0))
	_layer = TileMapLayer.new()
	_layer.tile_set = HexCellArt.build_hex_tileset()
	add_child(_layer)
	var variants: Array = HexCellArt.base_coords(BIOME)
	for i in PLAN.size():
		_layer.set_cell(Vector2i(i * STRIDE, 0), HexCellArt.SOURCE_ID,
			variants[i % variants.size()])
	queue_redraw()


func _draw() -> void:
	if _layer == null or not with_glyphs:
		return
	var ts: Vector2i = _layer.tile_set.tile_size
	var hex: float = ts.y * 0.5
	print("[probe] tile_size=%s _hex=%.1f" % [str(ts), hex])
	for i in PLAN.size():
		var cell := Vector2i(i * STRIDE, 0)
		var pos: Vector2 = _layer.map_to_local(cell)
		var w: int = -1 if float(PLAN[i][1]) < 0.0 else int(hex * PLAN[i][1])
		print("[probe] %d глиф=%s pos=(%.1f,%.1f) W=%d box_center=%.1f" % [
			i, PLAN[i][0], pos.x, pos.y, w, pos.x + w / 2.0])
		draw_string(ThemeDB.fallback_font, pos, PLAN[i][0],
			HORIZONTAL_ALIGNMENT_CENTER, w, 14, INK)
