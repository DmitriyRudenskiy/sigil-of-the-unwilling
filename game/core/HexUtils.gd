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
static var _config: HexGridConfig = null

static func get_config() -> HexGridConfig:
	if _config == null:
		_config = HexGridConfig.new()
	return _config

enum Terrain { WATER=0, SWAMP=1, SAND=2, GRASS=3, FOREST=4, MOUNTAIN=5, SNOW=6 }
const TERRAIN_NAMES := ["water", "swamp", "sand", "grass", "forest", "mountain", "snow"]


static func calibrate(tm: TileMapLayer) -> void:
	## Определяет, в какую сторону смещены НЕЧЁТНЫЕ строки в реальном рендере
	if tm == null or tm.tile_set == null:
		return
	var a := tm.map_to_local(Vector2i(0, 0))
	var b := tm.map_to_local(Vector2i(0, 1))
	get_config().odd_row_shift_right = b.x > a.x
	print("[HexUtils] calibrated: odd_row_shift_right = ", get_config().odd_row_shift_right)


static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
	var odd := (cell.y & 1) == 1
	var table: Array
	if get_config().odd_row_shift_right:
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
	if get_config().odd_row_shift_right:
		x = cell.x - (r - (r & 1)) / 2
	else:
		x = cell.x - (r + (r & 1)) / 2
	var z := r
	return Vector3i(x, -x - z, z)


@warning_ignore("integer_division")
static func cube_to_offset(c: Vector3i) -> Vector2i:
	var r := c.z
	var x: int
	if get_config().odd_row_shift_right:
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


## A* with hex_distance admissible heuristic. Faster than BFS for long paths.
static func astar_path(start: Vector2i, goal: Vector2i, blocked: Dictionary, w: int, h: int) -> Array[Vector2i]:
	if start == goal:
		return [start]
	var h_fn := func(c: Vector2i) -> int: return hex_distance(c, goal)

	var open := MinHeap.new()
	var start_f: int = h_fn.call(start)
	open.push([start_f, 0, start])  # [f, g, cell]

	var g_score: Dictionary = {start: 0}
	var came_from: Dictionary = {}

	while not open.is_empty():
		var cur: Array = open.pop()
		var cur_g: float = cur[1]
		var cur_cell: Vector2i = cur[2]

		# Stale entry (улучшенная копия уже в open) — skip
		var best_g: float = g_score.get(cur_cell, INF)
		if cur_g > best_g + 0.001:
			continue

		if cur_cell == goal:
			# Reconstruct path
			var path: Array[Vector2i] = []
			var c := goal
			while c != start:
				path.append(c)
				c = came_from[c]
			path.append(start)
			path.reverse()
			return path

		for bit in 6:
			var nxt := get_neighbor(cur_cell, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt):
				continue
			var tentative_g: float = cur_g + 1.0
			var existing_g: float = g_score.get(nxt, INF)
			if tentative_g >= existing_g:
				continue
			g_score[nxt] = tentative_g
			came_from[nxt] = cur_cell
			var f_score = tentative_g + GameSettings.ASTAR_HEURISTIC_WEIGHT * h_fn.call(nxt)
			open.push([f_score, tentative_g, nxt])

	return []


static func pos_to_idx(cell: Vector2i, w: int) -> int:
	return cell.y * w + cell.x


static func idx_to_pos(idx: int, w: int) -> Vector2i:
	return Vector2i(idx % w, idx / w)


## Dijkstra with float terrain costs.
## Dijkstra on hex grid using MinHeap for O((V+E) log V) pathfinding.
## and far simpler than a hand-rolled binary heap in GDScript.
## `cost_fn` — Callable(cell: Vector2i) -> float; returns cost to ENTER that cell (INF = blocked).
## Returns PackedFloat32Array of cheapest cost from start to each cell. Indices: y * w + x.
static func dijkstra(start: Vector2i, max_cost: float, cost_fn: Callable, w: int, h: int) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(INF)

	var start_idx := pos_to_idx(start, w)
	dist[start_idx] = 0.0

	# Min-heap priority queue for O(log n) extraction
	var open := MinHeap.new()
	open.push([0.0, start])
	var visited := {}

	while not open.is_empty():
		var cur: Array = open.pop()
		var cur_d: float = cur[0]
		var cur_cell: Vector2i = cur[1]
		var cur_idx := pos_to_idx(cur_cell, w)

		if visited.has(cur_idx):
			continue
		visited[cur_idx] = true

		if cur_d > dist[cur_idx]:
			continue
		if cur_d > max_cost:
			continue

		for bit in 6:
			var nxt := get_neighbor(cur_cell, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			var enter_cost: float = cost_fn.call(nxt)
			if enter_cost >= INF:
				continue
			var new_d: float = cur_d + enter_cost
			var nxt_idx := pos_to_idx(nxt, w)
			if new_d < dist[nxt_idx] and new_d <= max_cost:
				dist[nxt_idx] = new_d
				open.push([new_d, nxt])

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


# ==================== MinHeap ====================
class MinHeap:
	var _data: Array = []
	func push(item: Array) -> void:
		_data.append(item)
		var idx := _data.size() - 1
		while idx > 0:
			var parent := (idx - 1) / 2
			if _data[idx][0] < _data[parent][0]:
				var tmp: Array = _data[idx]
				_data[idx] = _data[parent]
				_data[parent] = tmp
				idx = parent
			else:
				break
	func pop() -> Array:
		var res = _data[0]
		var last: Array = _data.pop_back()
		if _data.size() > 0:
			_data[0] = last
			var idx := 0
			var size := _data.size()
			while true:
				var left := idx * 2 + 1
				var right := idx * 2 + 2
				var smallest := idx
				if left < size and _data[left][0] < _data[smallest][0]: smallest = left
				if right < size and _data[right][0] < _data[smallest][0]: smallest = right
				if smallest != idx:
					var tmp = _data[idx]
					_data[idx] = _data[smallest]
					_data[smallest] = tmp
					idx = smallest
				else:
					break
		return res
	func is_empty() -> bool:
		return _data.is_empty()
