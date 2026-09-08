extends Node2D
class_name HighlightOverlay

var move_cells: Dictionary = {}
var atk_cells: Dictionary = {}
var unreachable_cells: Dictionary = {}
var tm: TileMapLayer


func refresh() -> void:
    queue_redraw()


func _draw() -> void:
    if tm == null:
        return
    for k in unreachable_cells:
        _hex_fill(tm.map_to_local(k), ThemeConfig.C_BATTLE_HIGHLIGHT_UNREACH)
    for k in move_cells:
        _hex_fill(tm.map_to_local(k), ThemeConfig.C_BATTLE_HIGHLIGHT_MOVE)
    for k in move_cells:
        _hex(tm.map_to_local(k), ThemeConfig.C_BATTLE_HIGHLIGHT_MOVE_B)
    for k in atk_cells:
        _hex(tm.map_to_local(k), ThemeConfig.C_BATTLE_HIGHLIGHT_ATK)


func _hex(center: Vector2, col: Color) -> void:
    var pts := PackedVector2Array()
    for i in 7:
        var ang := deg_to_rad(60.0 * i - 90.0)
        pts.append(center + Vector2(cos(ang), sin(ang)) * BattleView.HEX_OUTLINE_RADIUS)
    draw_polyline(pts, col, 3.0)


func _hex_fill(center: Vector2, col: Color) -> void:
    var pts := PackedVector2Array()
    for i in 7:
        var ang := deg_to_rad(60.0 * i - 90.0)
        pts.append(center + Vector2(cos(ang), sin(ang)) * BattleView.HEX_OUTLINE_RADIUS)
    draw_colored_polygon(pts, col)
