extends RefCounted
class_name HexUtils
## Гекс-утилиты с АВТОКАЛИБРОВКОЙ чётности строк под реальный layout TileMapLayer.
## Порядок doc-битов: [E, NE, NW, W, SW, SE] = 0..5

# Таблицы соседей (Red Blob Games), odd-r и even-r
const T_ODD_RIGHT := [  # нечётная строка смещена ВПРАВО
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]
const T_EVEN_RIGHT := [  # чётная строка (при odd-r)
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

# Калибруется по реальному TileMapLayer (см. calibrate)
static var odd_row_shift_right := true

enum Terrain { WATER=0, SWAMP=1, SAND=2, GRASS=3, FOREST=4, MOUNTAIN=5, SNOW=6 }
const TERRAIN_NAMES := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]


static func calibrate(tm: TileMapLayer) -> void:
	## Определяет, в какую сторону смещены НЕЧЁТНЫЕ строки в реальном рендере
	if tm == null or tm.tile_set == null:
		return
	var a := tm.map_to_local(Vector2i(0, 0))
	var b := tm.map_to_local(Vector2i(0, 1))
	odd_row_shift_right = b.x > a.x
	print("[HexUtils] calibrated: odd_row_shift_right = ", odd_row_shift_right)


static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
	var odd := (cell.y & 1) == 1
	var table: Array
	if odd_row_shift_right:
		table = T_ODD_RIGHT if odd else T_EVEN_RIGHT
	else:
		table = T_EVEN_RIGHT if odd else T_ODD_RIGHT
	return cell + table[bit]


static func get_all_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for i in 6:
		r.append(get_neighbor(cell, i))
	return r


@warning_ignore("integer_division")
static func offset_to_cube(cell: Vector2i) -> Vector3i:
	var r := cell.y
	var x: int
	if odd_row_shift_right:
		x = cell.x - (r - (r & 1)) / 2
	else:
		x = cell.x - (r + (r & 1)) / 2
	var z := r
	return Vector3i(x, -x - z, z)


@warning_ignore("integer_division")
static func cube_to_offset(c: Vector3i) -> Vector2i:
	var r := c.z
	var x: int
	if odd_row_shift_right:
		x = c.x + (r - (r & 1)) / 2
	else:
		x = c.x + (r + (r & 1)) / 2
	return Vector2i(x, r)


static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := offset_to_cube(a)
	var bc := offset_to_cube(b)
	return maxi(maxi(absi(ac.x - bc.x), absi(ac.y - bc.y)), absi(ac.z - bc.z))


static func bfs_path(start: Vector2i, goal: Vector2i, blocked: Dictionary, w: int, h: int) -> Array[Vector2i]:
	if start == goal:
		return [start]
	var queue: Array[Vector2i] = [start]
	var head := 0
	var from: Dictionary = {start: start}
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == goal:
			break
		for bit in 6:
			var nxt := get_neighbor(cur, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt) or from.has(nxt):
				continue
			from[nxt] = cur
			queue.append(nxt)
	if not from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var c := goal
	while c != start:
		path.append(c)
		c = from[c]
	path.append(start)
	path.reverse()
	return path


## Dijkstra with float terrain costs.
## `cost_fn` — Callable(cell: Vector2i) -> float; returns cost to ENTER that cell (INF = blocked).
## Returns Dictionary[cell: float] of cheapest cost from start to each reachable cell.
static func dijkstra(start: Vector2i, max_cost: float, cost_fn: Callable) -> Dictionary:
	var dist: Dictionary = {start: 0.0}
	var pq: Array[Dictionary] = [{"cell": start, "d": 0.0}]  # simple priority list
	var head := 0
	while head < pq.size():
		# Find minimum in remaining queue
		var best_idx: int = head
		for i in range(head + 1, pq.size()):
			if pq[i].d < pq[best_idx].d:
				best_idx = i
		var entry: Dictionary = pq[best_idx]
		var tmp = pq[head]
		pq[head] = pq[best_idx]
		pq[best_idx] = tmp
		var cur: Vector2i = entry.cell
		var cur_d: float = entry.d
		head += 1
		if cur_d > dist[cur]:
			continue
		if cur_d > max_cost:
			continue
		for bit in 6:
			var nxt := get_neighbor(cur, bit)
			var enter_cost: float = cost_fn.call(nxt)
			if enter_cost >= INF:
				continue
			var new_d: float = cur_d + enter_cost
			if not dist.has(nxt) or new_d < dist[nxt]:
				dist[nxt] = new_d
				pq.append({"cell": nxt, "d": new_d})
	dist.erase(start)
	# Filter: only keep cells within max_cost
	var result: Dictionary = {}
	for cell in dist:
		if dist[cell] <= max_cost + 0.001:
			result[cell] = dist[cell]
	return result


## Dijkstra path reconstruction: trace back from goal to start using dist map.
static func dijkstra_path(start: Vector2i, goal: Vector2i, dist: Dictionary, cost_fn: Callable) -> Array[Vector2i]:
	if not dist.has(goal):
		return []
	if start == goal:
		return [start]
	var path: Array[Vector2i] = []
	var c := goal
	while c != start:
		path.append(c)
		var best: Vector2i = c
		var best_d: float = dist[c]
		for bit in 6:
			var nb := get_neighbor(c, bit)
			if dist.has(nb):
				var nb_cost: float = cost_fn.call(nb)
				if nb_cost < INF:
					var prev_d: float = dist[nb]
					if prev_d + nb_cost <= best_d - 0.0001:
						best_d = prev_d + nb_cost
						best = nb
			if best == c:
				break  # can't find predecessor, stuck
		if best == c:
			break
		c = best
	path.append(c)
	path.reverse()
	return path


static func bfs_reachable(start: Vector2i, steps: int, blocked: Dictionary, w: int, h: int) -> Dictionary:
	var result := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var dist: int = result[cur]
		if dist >= steps:
			continue
		for bit in 6:
			var nxt := get_neighbor(cur, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt) or result.has(nxt):
				continue
			result[nxt] = dist + 1
			queue.append(nxt)
	result.erase(start)
	return result
