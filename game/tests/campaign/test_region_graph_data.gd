extends GdUnitTestSuite
## T-020 (1.1): валидация данных MAP-1 (region_graph.json, канон 02e1-base-map).
## 46 узлов, связность, степень ≥ 2, MVP-маска {E3,E4,N4,N5,N6}, босс внутри, вода вне.

const DATA_PATH := "res://data/campaign/region_graph.json"


func _load_data() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	assert_bool(file != null).is_true().override_failure_message("region_graph.json не найден: " + DATA_PATH)
	if file == null:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	assert_bool(err == OK).is_true().override_failure_message("JSON parse error: %s" % json.get_error_message())
	return json.data if json.data is Dictionary else {}


func test_region_count_in_canon_range() -> void:
	# 40–48 регионов (K-T7).
	var data := _load_data()
	var regions: Dictionary = data.get("regions", {})
	assert_bool(regions.size() >= 40 and regions.size() <= 48).is_true() \
		.override_failure_message("Регионов %d (канон 40–48)" % regions.size())


func test_graph_connected() -> void:
	# Связность: все узлы достижимы из E1 (BFS по рёбрам).
	var data := _load_data()
	var regions: Dictionary = data.get("regions", {})
	var edges: Array = data.get("edges", [])
	var adj := {}
	for e in edges:
		var a: String = e[0]
		var b: String = e[1]
		if not adj.has(a): adj[a] = []
		if not adj.has(b): adj[b] = []
		adj[a].append(b)
		adj[b].append(a)
	var visited := {"E1": true}
	var stack := ["E1"]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for nb in adj.get(cur, []):
			if not visited.has(nb):
				visited[nb] = true
				stack.append(nb)
	assert_bool(visited.size() == regions.size()).is_true() \
		.override_failure_message("Связность: %d/%d" % [visited.size(), regions.size()])


func test_min_degree_two() -> void:
	# ≥ 2 соседей у каждого узла (замыкание «краёв нет»).
	var data := _load_data()
	var regions: Dictionary = data.get("regions", {})
	var edges: Array = data.get("edges", [])
	var adj := {}
	for e in edges:
		var a: String = e[0]
		var b: String = e[1]
		if not adj.has(a): adj[a] = []
		if not adj.has(b): adj[b] = []
		adj[a].append(b)
		adj[b].append(a)
	for rid in regions.keys():
		var deg: int = adj.get(rid, []).size()
		assert_bool(deg >= 2).is_true().override_failure_message("%s: степень %d < 2" % [rid, deg])


func test_ring_closure_edges() -> void:
	# Замыкание: E16–E1, N14–N1, S14–S1.
	var data := _load_data()
	var edges: Array = data.get("edges", [])
	var edge_set := {}
	for e in edges:
		var key := [e[0], e[1]]
		key.sort()
		edge_set["|".join(key)] = true
	assert_bool(edge_set.has("E1|E16")).is_true().override_failure_message("нет ребра E16–E1")
	assert_bool(edge_set.has("N1|N14")).is_true().override_failure_message("нет ребра N14–N1")
	assert_bool(edge_set.has("S1|S14")).is_true().override_failure_message("нет ребра S14–S1")


func test_mvp_mask_connected() -> void:
	# MVP-маска {E3,E4,N4,N5,N6}: связность.
	var data := _load_data()
	var mask: Array = (data.get("mvp_mask", {}) as Dictionary).get("regions", [])
	assert_bool(mask.size() == 5).is_true().override_failure_message("MVP-маска: %d регионов" % mask.size())
	var start: String = (data.get("mvp_mask", {}) as Dictionary).get("start", "E3")
	var edges: Array = data.get("edges", [])
	var adj := {}
	for e in edges:
		var a: String = e[0]
		var b: String = e[1]
		if mask.has(a) and mask.has(b):
			if not adj.has(a): adj[a] = []
			if not adj.has(b): adj[b] = []
			adj[a].append(b)
			adj[b].append(a)
	var visited := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for nb in adj.get(cur, []):
			if not visited.has(nb):
				visited[nb] = true
				stack.append(nb)
	assert_bool(visited.size() == mask.size()).is_true() \
		.override_failure_message("MVP-связность: %d/%d" % [visited.size(), mask.size()])


func test_boss_inside_mvp_mask() -> void:
	# Босс E4 внутри MVP-маски (K-M2).
	var data := _load_data()
	var mask: Array = (data.get("mvp_mask", {}) as Dictionary).get("regions", [])
	assert_bool(mask.has("E4")).is_true().override_failure_message("босс E4 вне MVP-маски")
	var e4: Dictionary = data.get("regions", {}).get("E4", {})
	assert_bool(bool(e4.get("boss", false))).is_true().override_failure_message("E4.boss != true")
	assert_bool(int(e4.get("difficulty_anchor", 0)) == 5).is_true() \
		.override_failure_message("E4.difficulty_anchor != 5")


func test_water_outside_mvp_mask() -> void:
	# Вода (N7,N8,S7,S8) вне MVP-маски.
	var data := _load_data()
	var mask: Array = (data.get("mvp_mask", {}) as Dictionary).get("regions", [])
	var regions: Dictionary = data.get("regions", {})
	for rid in mask:
		var reg: Dictionary = regions.get(rid, {})
		assert_bool(not bool(reg.get("water", false))).is_true() \
			.override_failure_message("вода %s внутри MVP-маски" % rid)


func test_k_a_is_two() -> void:
	# k_a = 2 (радиус аномалии).
	var data := _load_data()
	assert_bool(int(data.get("k_a", 0)) == 2).is_true().override_failure_message("k_a != 2")
