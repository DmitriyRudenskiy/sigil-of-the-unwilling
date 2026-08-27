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
	return max(max(absi(ac.x - bc.x), absi(ac.y - bc.y)), absi(ac.z - bc.z))


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


static func pos_to_idx(cell: Vector2i, w: int) -> int:
	return cell.y * w + cell.x


static func idx_to_pos(idx: int, w: int) -> Vector2i:
	return Vector2i(idx % w, idx / w)


## Dijkstra with float terrain costs (binary heap O(log n)).
## `cost_fn` — Callable(cell: Vector2i) -> float; returns cost to ENTER that cell (INF = blocked).
## Returns PackedFloat32Array of cheapest cost from start to each cell. Indices: y * w + x.
static func dijkstra(start: Vector2i, max_cost: float, cost_fn: Callable, w: int, h: int) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(INF)
	
	var start_idx := pos_to_idx(start, w)
	dist[start_idx] = 0.0
	# Min-heap: index 1 = root, [d, cell] pairs
	var heap: Array = [0.0, [0.0, start]]

	while heap.size() > 1:
		# heap pop
		var entry: Array = heap[1]
		if heap.size() > 2:
			heap[1] = heap.pop_back()
		else:
			heap.pop_back()
		if heap.size() > 1:
			var hi := 1
			while hi * 2 < heap.size():
				var smallest := hi
				var left := hi * 2
				var right := left + 1
				if left < heap.size() and heap[left][0] < heap[smallest][0]: smallest = left
				if right < heap.size() and heap[right][0] < heap[smallest][0]: smallest = right
				if smallest == hi: break
				var tmp = heap[smallest]; heap[smallest] = heap[hi]; heap[hi] = tmp
				hi = smallest
		var cur: Vector2i = entry[1]
		var cur_d: float = entry[0]
		
		var cur_idx := pos_to_idx(cur, w)
		if cur_d > dist[cur_idx]: continue
		if cur_d > max_cost: continue
		for bit in 6:
			var nxt := get_neighbor(cur, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			var enter_cost: float = cost_fn.call(nxt)
			if enter_cost == INF: continue
			var new_d: float = cur_d + enter_cost
			var nxt_idx := pos_to_idx(nxt, w)
			if new_d < dist[nxt_idx]:
				dist[nxt_idx] = new_d
				heap.append([new_d, nxt])
				var i := heap.size() - 1
				while i > 1:
					var parent := i / 2
					if heap[parent][0] <= heap[i][0]: break
					var tmp2 = heap[parent]; heap[parent] = heap[i]; heap[i] = tmp2
					i = parent
	for i in range(dist.size()):
		if dist[i] > max_cost + 0.001:
			dist[i] = INF
	return dist


## Dijkstra path reconstruction: trace back from goal to start using dist map.
static func dijkstra_path(start: Vector2i, goal: Vector2i, dist: PackedFloat32Array, cost_fn: Callable, w: int, h: int) -> Array[Vector2i]:
	var goal_idx := pos_to_idx(goal, w)
	if dist[goal_idx] == INF:
		return []
	if start == goal:
		return [start]
	var path: Array[Vector2i] = []
	var c: Vector2i = goal

	while c != start:
		path.append(c)

		var best: Vector2i = c
		var c_idx := pos_to_idx(c, w)
		var best_d: float = dist[c_idx]
		var enter_current: float = cost_fn.call(c)

		if enter_current >= INF:
			push_warning("dijkstra_path: cell %s has INF enter cost" % c)
			break

		for bit in 6:
			var nb: Vector2i = get_neighbor(c, bit)
			if nb.x < 0 or nb.x >= w or nb.y < 0 or nb.y >= h:
				continue
			var nb_idx := pos_to_idx(nb, w)
			var candidate: float = INF

			if nb == start:
				candidate = enter_current
			elif dist[nb_idx] != INF:
				candidate = dist[nb_idx] + enter_current

			if candidate != INF and candidate <= best_d + 0.0001:
				best_d = candidate
				best = nb

		if best == c:
			break

		c = best

	path.append(c)
	path.reverse()
	return path


static func bfs_reachable(start: Vector2i, steps: int, blocked: Dictionary, w: int, h: int) -> Dictionary:
	var result: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var dist: int = result[cur]
		if dist >= steps:
			continue
		for bit in 6:
			var nxt: Vector2i = get_neighbor(cur, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt) or result.has(nxt):
				continue
			result[nxt] = dist + 1
			queue.append(nxt)
	result.erase(start)
	return result
