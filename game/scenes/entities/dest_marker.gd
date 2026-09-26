extends Node2D
class_name DestMarker

const _HexDraw = preload("res://scripts/core/hex_draw.gd")

var active := false
var _t := 0.0


func _process(d: float) -> void:
	if active:
		_t += d
		queue_redraw()


func show_at(pos: Vector2) -> void:
	position = pos
	active = true
	queue_redraw()


func hide_marker() -> void:
	active = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var r := 36.0 + sin(_t * 6.0) * 4.0
	var pts := _HexDraw.points(r)
	draw_polyline(pts, ThemeConfig.C_BATTLE_HIGHLIGHT_ATK, 3.0)
