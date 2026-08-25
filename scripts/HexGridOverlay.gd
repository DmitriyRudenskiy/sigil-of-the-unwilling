extends Node2D
class_name HexGridOverlay
## Опциональная рамка гексов (по умолчанию выключена)

const HexDraw = preload("res://scripts/util/HexDraw.gd")

var map_ref: MapGenerator
var cam_ref: Camera2D
var enabled := false
var _last_cam_pos := Vector2.ZERO
var _last_zoom := Vector2.ONE


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
  var R := 40.0
  for y in range(c0.y - 1, c1.y + 2):
    for x in range(c0.x - 1, c1.x + 2):
      var center: Vector2 = map_ref.map_to_local(Vector2i(x, y))
      var pts := HexDraw.points_at(center, R)
      draw_polyline(pts, Color(0, 0, 0, 0.4), 2.0)
