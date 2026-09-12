extends BaseTest

# Ранняя игра: кольцевые тиры, враждебность, сезоны (early-game-foundation).


func before_test() -> void:
	WorldSeasons.reset()


func test_threat_pool_rings() -> void:
	var near: Array = MapSpawner._threat_pool(0)
	assert_bool(near.has("wolves")).is_true()
	assert_bool(near.has("red_dragon")).is_false()
	var mid: Array = MapSpawner._threat_pool(MapSpawner.THREAT_RING2_RADIUS)
	assert_bool(mid.has("orc")).is_true()
	assert_bool(mid.has("wolves")).is_false()
	assert_bool(mid.has("red_dragon")).is_false()
	var far: Array = MapSpawner._threat_pool(MapSpawner.THREAT_RING3_RADIUS)
	assert_bool(far.has("red_dragon")).is_true()
	assert_bool(far.has("orc")).is_false()


func test_spawned_enemies_respect_rings() -> void:
	var model := MapModel.new()
	model.map_width = 90
	model.map_height = 70
	model.seed_value = 42
	for y in model.map_height:
		for x in model.map_width:
			model.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
	var spawner := MapSpawner.new(model)
	# Весь мир — трава: первая ходимая клетка (старт героя) — (0,0)
	var start := Vector2i(0, 0)
	var reachable: Dictionary = {}
	for y in range(4, 40):
		for x in range(4, 40):
			var cell := Vector2i(x, y)
			if HexUtils.hex_distance(cell, start) < 30:
				reachable[cell] = true
	spawner.place_enemies(reachable)
	assert_bool(model.enemy_stacks.size() > 0).is_true()
	for cell in model.enemy_stacks:
		var army: Array = model.enemy_stacks[cell]
		var dist: int = HexUtils.hex_distance(cell, start)
		var expected: Array = MapSpawner._threat_pool(dist)
		for stack in army:
			assert_bool(expected.has(stack.get_key())).is_true()


func test_season_cycle_and_mults() -> void:
	assert_that(WorldSeasons.season_name()).is_equal("Ясный сезон")
	assert_float(WorldSeasons.production_mult()).is_equal(1.0)
	for i in WorldSeasons.TURN_LENGTH:
		WorldSeasons.advance_turn()
	assert_that(WorldSeasons.season_name()).is_equal("Морось")
	assert_float(WorldSeasons.production_mult()).is_equal(1.2)
	for i in WorldSeasons.TURN_LENGTH:
		WorldSeasons.advance_turn()
	assert_that(WorldSeasons.season_name()).is_equal("Буря")
	assert_float(WorldSeasons.production_mult()).is_equal(0.4)
	assert_float(WorldSeasons.enemy_mult()).is_greater(1.0)


func test_hostility_grows_over_time() -> void:
	var base: float = WorldSeasons.hostility_mult()
	for i in 20:
		WorldSeasons.advance_turn()
	assert_float(WorldSeasons.hostility_mult()).is_greater(base)
	for i in 500:
		WorldSeasons.advance_turn()
	assert_float(WorldSeasons.hostility_mult()).is_equal(WorldSeasons.HOSTILITY_CAP)


func test_make_stack_size_mult() -> void:
	var reg: Node = Services.resolve(&"units")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var small: UnitStack = reg.make_stack("wolves", rng, 1.0)
	var big: UnitStack = reg.make_stack("wolves", rng, 2.0)
	assert_int(big.count).is_greater(small.count)


func test_storm_boosts_spawns() -> void:
	WorldSeasons.reset()
	for i in WorldSeasons.TURN_LENGTH * 2:
		WorldSeasons.advance_turn()
	assert_that(WorldSeasons.season_name()).is_equal("Буря")
	var reg: Node = Services.resolve(&"units")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var calm: UnitStack = null
	var stormy: UnitStack = null
	WorldSeasons.reset()
	calm = reg.make_stack("wolves", rng, WorldSeasons.hostility_mult() * WorldSeasons.enemy_mult())
	for i in WorldSeasons.TURN_LENGTH * 2:
		WorldSeasons.advance_turn()
	stormy = reg.make_stack("wolves", rng, WorldSeasons.hostility_mult() * WorldSeasons.enemy_mult())
	assert_bool(stormy.count >= calm.count).is_true()
