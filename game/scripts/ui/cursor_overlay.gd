extends Node2D
class_name CursorOverlay

var mode := BattleView.CursorMode.DEFAULT
var visible_flag := false
var mouse_pos := Vector2.ZERO

func set_mode(m: int) -> void:
    mode = m as BattleView.CursorMode
    if is_inside_tree():
        queue_redraw()

func _draw() -> void:
    if not visible_flag:
        return
    match mode:
        BattleView.CursorMode.DEFAULT:
            _reticle()
        BattleView.CursorMode.ATTACK:
            _sword(ThemeConfig.C_CURSOR_SWORD)
        BattleView.CursorMode.RANGED:
            _arrow(ThemeConfig.C_CURSOR_ARROW)
        BattleView.CursorMode.SPELL:
            _wand(ThemeConfig.C_CURSOR_WAND)
        BattleView.CursorMode.MOVE:
            _boot(ThemeConfig.C_CURSOR_BOOT)

func _reticle() -> void:
    var col := ThemeConfig.C_CURSOR_DEFAULT
    var pts := PackedVector2Array()
    for i in 20:
        var ang := deg_to_rad(18.0 * i)
        pts.append(mouse_pos + Vector2(cos(ang), sin(ang)) * 13.0)
    draw_polyline(pts, col, 2.0)
    draw_circle(mouse_pos, 2.5, col)

func _sword(col: Color) -> void:
    var blade := PackedVector2Array([
        mouse_pos + Vector2(0, -17),
        mouse_pos + Vector2(7, 0),
        mouse_pos + Vector2(0, -5),
        mouse_pos + Vector2(-7, 0),
    ])
    draw_colored_polygon(blade, col)
    draw_line(mouse_pos + Vector2(-10, 2), mouse_pos + Vector2(10, 2), col, 3.0)
    draw_line(mouse_pos + Vector2(0, -2), mouse_pos + Vector2(0, 12), col, 4.0)

func _arrow(col: Color) -> void:
    draw_line(mouse_pos + Vector2(0, 12), mouse_pos + Vector2(0, -4), col, 3.5)
    var head := PackedVector2Array([
        mouse_pos + Vector2(0, -16),
        mouse_pos + Vector2(7, -4),
        mouse_pos + Vector2(-7, -4),
    ])
    draw_colored_polygon(head, col)
    draw_line(mouse_pos + Vector2(0, -16), mouse_pos + Vector2(0, -4), col, 3.5)

func _wand(col: Color) -> void:
    draw_line(mouse_pos + Vector2(-8, 12), mouse_pos + Vector2(6, -6), col, 4.0)
    var spark := PackedVector2Array([
        mouse_pos + Vector2(0, -20),
        mouse_pos + Vector2(3, -13),
        mouse_pos + Vector2(10, -13),
        mouse_pos + Vector2(4, -9),
        mouse_pos + Vector2(6, -2),
        mouse_pos + Vector2(0, -6),
        mouse_pos + Vector2(-6, -2),
        mouse_pos + Vector2(-4, -9),
        mouse_pos + Vector2(-10, -13),
        mouse_pos + Vector2(-3, -13),
    ])
    draw_colored_polygon(spark, col)

func _boot(col: Color) -> void:
    var head := PackedVector2Array([
        mouse_pos + Vector2(0, 18),
        mouse_pos + Vector2(-7, 5),
        mouse_pos + Vector2(-3, 5),
        mouse_pos + Vector2(-3, -12),
        mouse_pos + Vector2(3, -12),
        mouse_pos + Vector2(3, 5),
        mouse_pos + Vector2(7, 5),
    ])
    draw_colored_polygon(head, col)
    draw_line(mouse_pos + Vector2(0, -18), mouse_pos + Vector2(0, -12), col, 3.0)

func _process(_delta: float) -> void:
    if not visible_flag or not is_inside_tree():
        return
    var p := to_local(get_global_mouse_position())
    if p != mouse_pos:
        mouse_pos = p
        queue_redraw()
