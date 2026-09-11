extends BaseTest


func before_test() -> void:
	# TASK_19_1 P3: таблица теперь инициализируется явно.
	TerrainCostTable.ensure()

func test_cost_grass() -> void:
	assert_that(TerrainCostTable.get_cost("grass")).is_equal(1.0)

func test_cost_forest() -> void:
	assert_that(TerrainCostTable.get_cost("forest")).is_equal(1.25)

func test_cost_sand() -> void:
	assert_that(TerrainCostTable.get_cost("sand")).is_equal(1.5)

func test_cost_swamp() -> void:
	assert_that(TerrainCostTable.get_cost("swamp")).is_equal(1.75)

func test_cost_water() -> void:
	assert_bool(TerrainCostTable.get_cost("water") >= INF - 1).is_true()

func test_cost_levitation_water() -> void:
	assert_that(TerrainCostTable.get_cost_with_effects("water", true)).is_equal(1.0)

func test_cost_all_terains() -> void:
	assert_bool(TerrainCostTable.get_all_terrains().size() >= 6).is_true()

func test_dijkstra_flat() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return INF
		return 1.0
	var dist := HexPathfinding.dijkstra(Vector2i(0, 0), 10.0, cost_fn, 21, 21)
	var goal_idx := HexUtils.pos_to_idx(Vector2i(5, 0), 21)
	assert_bool(dist[goal_idx] < INF).is_true()
	assert_that(dist[goal_idx]).is_equal(5.0)

func test_dijkstra_swamp_cost() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return INF
		if c.x == 3 and c.y == 0:
			return 1.75
		return 1.0
	var dist := HexPathfinding.dijkstra(Vector2i(0, 0), 20.0, cost_fn, 21, 21)
	var goal_idx := HexUtils.pos_to_idx(Vector2i(3, 0), 21)
	assert_bool(dist[goal_idx] < INF).is_true()
	assert_that(dist[goal_idx]).is_equal(3.75)

func test_dijkstra_water_blocked() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return INF
		if c.x == 2 and c.y == 0:
			return INF
		return 1.0
	var dist := HexPathfinding.dijkstra(Vector2i(0, 0), 5.0, cost_fn, 21, 21)
	var goal_idx := HexUtils.pos_to_idx(Vector2i(2, 0), 21)
	var past_idx := HexUtils.pos_to_idx(Vector2i(5, 0), 21)
	assert_bool(dist[goal_idx] < INF).is_false()
	assert_bool(dist[past_idx] < INF).is_false()

func test_dijkstra_mp_cap() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return INF
		return 1.0
	var dist := HexPathfinding.dijkstra(Vector2i(0, 0), 3.0, cost_fn, 21, 21)
	var goal_idx := HexUtils.pos_to_idx(Vector2i(3, 0), 21)
	var down_idx := HexUtils.pos_to_idx(Vector2i(0, 3), 21)
	assert_bool(dist[goal_idx] < INF).is_true()
	assert_bool(dist[down_idx] < INF).is_true()

func test_daily_cap_10() -> void:
	assert_that(GameNumbers.HERO_DAILY_MOVEMENT).is_equal(10.0)
