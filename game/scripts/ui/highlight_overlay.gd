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
        _hex_fill(BattleView.project(tm, k), ThemeConfig.C_BATTLE_HIGHLIGHT_UNREACH)
    for k in move_cells:
        _hex_fill(BattleView.project(tm, k), ThemeConfig.C_BATTLE_HIGHLIGHT_MOVE)
    for k in move_cells:
        _hex(BattleView.project(tm, k), ThemeConfig.C_BATTLE_HIGHLIGHT_MOVE_B)
    for k in atk_cells:
        _hex(BattleView.project(tm, k), ThemeConfig.C_BATTLE_HIGHLIGHT_ATK)

func _hex(center: Vector2, col: Color) -> void:
    draw_polyline(_pts(center), col, 3.0)

func _hex_fill(center: Vector2, col: Color) -> void:
    draw_colored_polygon(_pts(center), col)

## Соты того же наклона, что и поле: полигон берётся из HexDraw, а не рисуется
## вторым экземпляром формулы.
func _pts(center: Vector2) -> PackedVector2Array:
    return HexDraw.points_at(center, BattleView.HEX_OUTLINE_RADIUS, BattleView.TILT)
