extends Node2D
class_name HexGridOverlay
## Опциональная рамка гексов (по умолчанию выключена)

var map_ref: MapGenerator
var cam_ref: Camera2D
var enabled := false


func _process(_d: float) -> void:
  if enabled:
    queue_redraw()


func _draw() -> void:
  if not enabled or map_ref == null or map_ref._tile_map == null or cam_ref == null:
    return
  var tm := map_ref._tile_map
  if tm.tile_set == null:
    return
  var view_sz := get_viewport().get_visible_rect().size / cam_ref.zoom
  var c0 := tm.local_to_map(cam_ref.position - view_sz / 2.0)
  var c1 := tm.local_to_map(cam_ref.position + view_sz / 2.0)
  var R := 40.0
  for y in range(c0.y - 1, c1.y + 2):
    for x in range(c0.x - 1, c1.x + 2):
      var center := tm.map_to_local(Vector2i(x, y))
      var pts := PackedVector2Array()
      for i in 7:
        var ang := deg_to_rad(60.0 * i - 90.0)
        pts.append(center + Vector2(cos(ang), sin(ang)) * R)
      draw_polyline(pts, Color(0, 0, 0, 0.4), 2.0)
