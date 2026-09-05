extends "res://tests/gut_base.gd"

const _TerrainCostTable = preload("res://scripts/data/TerrainCostTable.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")
const _HexPathfinding = preload("res://scripts/core/HexPathfinding.gd")

# --- Terrain cost table ---

func test_cost_grass() -> void:
	assert_eq(_TerrainCostTable.get_cost("grass"), 1.0, "grass")

func test_cost_forest() -> void:
	assert_eq(_TerrainCostTable.get_cost("forest"), 1.25, "forest")

func test_cost_sand() -> void:
	assert_eq(_TerrainCostTable.get_cost("sand"), 1.5, "sand")

func test_cost_swamp() -> void:
	assert_eq(_TerrainCostTable.get_cost("swamp"), 1.75, "swamp")

func test_cost_water() -> void:
	assert_true(_TerrainCostTable.get_cost("water") >= INF - 1, "water is INF")

func test_cost_levitation_water() -> void:
	assert_eq(_TerrainCostTable.get_cost_with_effects("water", true), 1.0, "water+levitation")

func test_cost_all_terains() -> void:
	assert_true(_TerrainCostTable.get_all_terrains().size() >= 6, "6+ terrains")

# --- Dijkstra ---

func test_dijkstra_flat() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return INF
		return 1.0
	var dist := _HexPathfinding.dijkstra(Vector2i(0, 0), 10.0, cost_fn, 21, 21)
	var goal_idx := _HexUtils.pos_to_idx(Vector2i(5, 0), 21)
	assert_true(dist[goal_idx] < INF, "5 cells reachable")
	assert_eq(dist[goal_idx], 5.0, "cost=5")

func test_dijkstra_swamp_cost() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return INF
		if c.x == 3 and c.y == 0:
			return 1.75
		return 1.0
	var dist := _HexPathfinding.dijkstra(Vector2i(0, 0), 20.0, cost_fn, 21, 21)
	var goal_idx := _HexUtils.pos_to_idx(Vector2i(3, 0), 21)
	assert_true(dist[goal_idx] < INF, "swamp reachable")
	# Path: (0,0)->(1,0)->(2,0)->(3,0), cost = 1.0+1.0+1.75 = 3.75
	assert_eq(dist[goal_idx], 3.75, "swamp adds 1.75")

func test_dijkstra_water_blocked() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return INF
		if c.x == 2 and c.y == 0:
			return INF
		return 1.0
	var dist := _HexPathfinding.dijkstra(Vector2i(0, 0), 5.0, cost_fn, 21, 21)
	var goal_idx := _HexUtils.pos_to_idx(Vector2i(2, 0), 21)
	var past_idx := _HexUtils.pos_to_idx(Vector2i(5, 0), 21)
	assert_false(dist[goal_idx] < INF, "water not reachable")
	assert_false(dist[past_idx] < INF, "past water unreachable")

func test_dijkstra_mp_cap() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return INF
		return 1.0
	var dist := _HexPathfinding.dijkstra(Vector2i(0, 0), 3.0, cost_fn, 21, 21)
	var goal_idx := _HexUtils.pos_to_idx(Vector2i(3, 0), 21)
	var down_idx := _HexUtils.pos_to_idx(Vector2i(0, 3), 21)
	assert_true(dist[goal_idx] < INF, "exactly 3 MP reachable")
	assert_true(dist[down_idx] < INF, "down 3 cells")

# --- Daily MP cap ---

func test_daily_cap_10() -> void:
	assert_eq(GameSettings.HERO_DAILY_MOVEMENT, 10.0, "base MP=10")
