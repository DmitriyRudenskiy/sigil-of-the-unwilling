extends Node2D
class_name BoardOutline

## Рамка поля боя. Нужна только когда под гексами кадр местности: тайлы поля
## тогда прозрачны, и без рамки игрок не видит, где поле кончается — армия
## «стоит в пейзаже».
##
## Рисуются только внешние рёбра поля: общее ребро двух пограничных гексов
## приходит с обеих сторон, а тёмная подложка на двойной толщине даёт удвоенную
## линию. Кадр бывает и снежным, и болотным, поэтому поверх тёмной подложки
## идёт светлая линия.

var tm: TileMapLayer
var cells: Array[Vector2i] = []

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if tm == null or cells.is_empty():
		return
	var dark := Color(0.0, 0.0, 0.0, 0.55)
	var light: Color = ThemeConfig.C_BATTLE_BOARD_EDGE
	var edges := _outer_edges()
	for i in range(0, edges.size(), 2):
		draw_line(edges[i], edges[i + 1], dark, 4.0)
		draw_line(edges[i], edges[i + 1], light, 1.5)

## Рёбра пограничных гексов без повторов, парами (начало, конец).
func _outer_edges() -> PackedVector2Array:
	var seen := {}
	var out := PackedVector2Array()
	for c in cells:
		var pts := HexDraw.points_at(tm.map_to_local(c), BattleView.HEX_OUTLINE_RADIUS)
		for i in 6:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var key := _edge_key(a, b)
			if seen.has(key):
				continue
			seen[key] = true
			out.append(a)
			out.append(b)
	return out

## Ключ ребра не зависит от порядка концов: общее ребро двух гексов встречается
## у обоих, повторный рисунок удваивает толщину.
func _edge_key(a: Vector2, b: Vector2) -> String:
	var first := a if a.x < b.x or (a.x == b.x and a.y <= b.y) else b
	var second := b if first == a else a
	return str(first) + "|" + str(second)
