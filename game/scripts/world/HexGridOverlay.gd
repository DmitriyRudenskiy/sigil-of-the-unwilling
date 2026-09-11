extends Node2D
class_name HexGridOverlay

const HexDraw = preload("res://scripts/core/HexDraw.gd")

var map_ref: MapGenerator
var cam_ref: Camera2D
var enabled := false
var _last_cam_pos := Vector2.ZERO
var _last_zoom := Vector2.ONE

const R := 40.0
# TASK_21: переиспользуемый буфер контура — _draw не аллоцирует PackedVector2Array
# на каждый видимый гекс (packed-массивы — value-типы, кэш в HexDraw только экономит
# вычисление вершин, копию при возврате не отменяет).
var _hex_base := PackedVector2Array()
var _hex_outline := PackedVector2Array()

func _ready() -> void:
  _hex_base = HexDraw.points(R)
  _hex_outline.resize(_hex_base.size())

func _process(_d: float) -> void:
  if not enabled:
    return
  if cam_ref != null:
    if cam_ref.position != _last_cam_pos or cam_ref.zoom != _last_zoom:
      _last_cam_pos = cam_ref.position
      _last_zoom = cam_ref.zoom
      queue_redraw()

func _draw() -> void:
  if not enabled or map_ref == null or not map_ref.has_valid_tilemap() or cam_ref == null:
    return
  var view_sz := get_viewport().get_visible_rect().size / cam_ref.zoom
  var c0: Vector2i = map_ref.local_to_map(cam_ref.position - view_sz / 2.0)
  var c1: Vector2i = map_ref.local_to_map(cam_ref.position + view_sz / 2.0)
  for y in range(c0.y - 1, c1.y + 2):
    for x in range(c0.x - 1, c1.x + 2):
      var center: Vector2 = map_ref.map_to_local(Vector2i(x, y))
      for i in _hex_base.size():
        _hex_outline[i] = center + _hex_base[i]
      draw_polyline(_hex_outline, ThemeConfig.C_GRID_LINE, 2.0)
