class_name McpCanvasDrawNode
extends Node2D
## MCP canvas-draw: обычный класс вместо генерации GDScript из строки (TASK_19_1 S3).

var draw_commands: Array = []


func _draw() -> void:
	for cmd in draw_commands:
		var p: Dictionary = cmd.params
		var c: Color = cmd.color
		match cmd.action:
			"line":
				var f: Dictionary = p.get("from", {})
				var t: Dictionary = p.get("to", {})
				draw_line(
					Vector2(float(f.get("x", 0)), float(f.get("y", 0))),
					Vector2(float(t.get("x", 0)), float(t.get("y", 0))),
					c, float(p.get("width", 2))
				)
			"rect":
				var r: Dictionary = p.get("rect", {})
				draw_rect(
					Rect2(float(r.get("x", 0)), float(r.get("y", 0)), float(r.get("w", 10)), float(r.get("h", 10))),
					c, bool(p.get("filled", true))
				)
			"circle":
				var ct: Dictionary = p.get("center", {})
				draw_circle(Vector2(float(ct.get("x", 0)), float(ct.get("y", 0))), float(p.get("radius", 10)), c)
			"polygon":
				var pts: Array = p.get("points", [])
				var pv := PackedVector2Array()
				for pt in pts:
					pv.append(Vector2(float(pt.get("x", 0)), float(pt.get("y", 0))))
				if pv.size() >= 3:
					draw_colored_polygon(pv, c)
			"text":
				var pos: Dictionary = p.get("position", p.get("pos", {}))
				draw_string(
					ThemeDB.fallback_font,
					Vector2(float(pos.get("x", 0)), float(pos.get("y", 0))),
					str(p.get("text", "")),
					HORIZONTAL_ALIGNMENT_LEFT, -1,
					int(p.get("font_size", 16)), c
				)
