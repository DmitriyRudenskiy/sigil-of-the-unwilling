class_name HexPathfinding
extends RefCounted

static func _reconstruct_path(start: Vector2i, goal: Vector2i, from: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var c: Vector2i = goal
	while c != start:
		path.append(c)
		c = from[c]
	path.append(start)
	path.reverse()
	return path

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
			var nxt := HexUtils.get_neighbor(cur, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt) or from.has(nxt):
				continue
			from[nxt] = cur
			queue.append(nxt)
	if not from.has(goal):
		return []
	return _reconstruct_path(start, goal, from)

static func astar_path(start: Vector2i, goal: Vector2i, blocked: Dictionary, w: int, h: int) -> Array[Vector2i]:
	if start == goal:
		return [start]
	var h_fn := func(c: Vector2i) -> int: return HexUtils.hex_distance(c, goal)

	var n := w * h
	var g_score := PackedFloat32Array()
	g_score.resize(n)
	g_score.fill(INF)
	var came_from := PackedInt32Array()
	came_from.resize(n)
	came_from.fill(-1)

	var open := MinHeap.new()
	var start_idx := HexUtils.pos_to_idx(start, w)
	g_score[start_idx] = 0.0
	var start_f: int = h_fn.call(start)
	open.push([start_f, 0, start])

	while not open.is_empty():
		var cur: Array = open.pop()
		var cur_g: float = cur[1]
		var cur_cell: Vector2i = cur[2]
		var cur_idx := HexUtils.pos_to_idx(cur_cell, w)

		if cur_g > g_score[cur_idx]:
			continue

		if cur_cell == goal:
			var path: Array[Vector2i] = []
			var j := cur_idx
			while j != start_idx:
				path.append(HexUtils.idx_to_pos(j, w))
				j = came_from[j]
			path.append(start)
			path.reverse()
			return path

		for bit in 6:
			var nxt := HexUtils.get_neighbor(cur_cell, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt):
				continue
			var nxt_idx := HexUtils.pos_to_idx(nxt, w)
			var tentative_g: float = cur_g + 1.0
			if tentative_g >= g_score[nxt_idx]:
				continue
			g_score[nxt_idx] = tentative_g
			came_from[nxt_idx] = cur_idx
			var f_score = g_score[nxt_idx] + GameNumbers.ASTAR_HEURISTIC_WEIGHT * h_fn.call(nxt)
			open.push([f_score, g_score[nxt_idx], nxt])

	return []

static func find_path(start: Vector2i, goal: Vector2i, blocked: Dictionary, w: int, h: int, algo: String = "astar") -> Array[Vector2i]:
	if algo == "bfs":
		return bfs_path(start, goal, blocked, w, h)
	return astar_path(start, goal, blocked, w, h)

static func dijkstra(start: Vector2i, max_cost: float, cost_fn: Callable, w: int, h: int) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(INF)

	var start_idx := HexUtils.pos_to_idx(start, w)
	dist[start_idx] = 0.0

	var open := MinHeap.new()
	open.push([0.0, start])
	var visited := {}

	while not open.is_empty():
		var cur: Array = open.pop()
		var cur_d: float = cur[0]
		var cur_cell: Vector2i = cur[1]
		var cur_idx := HexUtils.pos_to_idx(cur_cell, w)

		if visited.has(cur_idx):
			continue
		visited[cur_idx] = true

		if cur_d > dist[cur_idx]:
			continue
		if cur_d > max_cost:
			continue

		for bit in 6:
			var nxt := HexUtils.get_neighbor(cur_cell, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			var enter_cost: float = cost_fn.call(nxt)
			if enter_cost >= INF:
				continue
			var new_d: float = cur_d + enter_cost
			var nxt_idx := HexUtils.pos_to_idx(nxt, w)
			if new_d < dist[nxt_idx] and new_d <= max_cost:
				dist[nxt_idx] = new_d
				open.push([new_d, nxt])

	for i in range(dist.size()):
		if dist[i] > max_cost + 0.001:
			dist[i] = INF
	return dist

static func dijkstra_path(start: Vector2i, goal: Vector2i, dist: PackedFloat32Array, cost_fn: Callable, w: int, h: int) -> Array[Vector2i]:
	var goal_idx := HexUtils.pos_to_idx(goal, w)
	if dist[goal_idx] == INF:
		return []
	if start == goal:
		return [start]
	var path: Array[Vector2i] = []
	var c: Vector2i = goal

	while c != start:
		path.append(c)

		var best: Vector2i = c
		var c_idx := HexUtils.pos_to_idx(c, w)
		var best_d: float = dist[c_idx]
		var enter_current: float = cost_fn.call(c)

		if enter_current >= INF:
			push_warning("dijkstra_path: cell %s has INF enter cost" % c)
			break

		for bit in 6:
			var nb: Vector2i = HexUtils.get_neighbor(c, bit)
			if nb.x < 0 or nb.x >= w or nb.y < 0 or nb.y >= h:
				continue
			var nb_idx := HexUtils.pos_to_idx(nb, w)
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
			var nxt: Vector2i = HexUtils.get_neighbor(cur, bit)
			if nxt.x < 0 or nxt.x >= w or nxt.y < 0 or nxt.y >= h:
				continue
			if blocked.has(nxt) or result.has(nxt):
				continue
			result[nxt] = dist + 1
			queue.append(nxt)
	result.erase(start)
	return result
