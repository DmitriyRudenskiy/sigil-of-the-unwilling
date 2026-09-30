extends Node2D
class_name StatusOrb

var _ratio: float = 1.0
var _t := 0.0


func _ready() -> void:
	position = Vector2(0, -40)
	z_index = 11


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)


func _draw() -> void:
	var color: Color
	if _ratio >= 0.4:
		color = ThemeConfig.C_ORB_HIGH
	elif _ratio >= 0.1:
		color = ThemeConfig.C_ORB_MID
	else:
		color = ThemeConfig.C_ORB_LOW
	var r := 6.0 + sin(_t * 3.0) * 1.5
	draw_circle(Vector2.ZERO, r, color)
