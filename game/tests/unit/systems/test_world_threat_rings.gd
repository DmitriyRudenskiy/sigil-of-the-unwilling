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
	# Q-M27 (закрыто, 11-я итерация §1.1): сезон = ход, цикл 4 (Весна/Лето/Осень/Зима),
	# ход 1 = Весна; множители — 07-balance §6 (сезонная таблица).
	assert_that(WorldSeasons.season_name()).is_equal("Весна")  # ход 0 = Весна
	assert_float(WorldSeasons.production_mult()).is_equal(1.0)
	WorldSeasons.advance_turn()  # ход 1 = Весна
	assert_that(WorldSeasons.season_name()).is_equal("Весна")
	WorldSeasons.advance_turn()  # ход 2 = Лето
	assert_that(WorldSeasons.season_name()).is_equal("Лето")
	assert_float(WorldSeasons.production_mult()).is_equal(1.2)
	WorldSeasons.advance_turn()  # ход 3 = Осень
	assert_that(WorldSeasons.season_name()).is_equal("Осень")
	assert_float(WorldSeasons.production_mult()).is_equal(1.0)
	WorldSeasons.advance_turn()  # ход 4 = Зима
	assert_that(WorldSeasons.season_name()).is_equal("Зима")
	assert_float(WorldSeasons.production_mult()).is_equal(0.4)
	assert_float(WorldSeasons.enemy_mult()).is_greater(1.0)
	# Ход 21 = Весна по формуле (20 % 4 = 0) — Q-M29 (решение Q-M27: «зима» —
	# противоречие, вердикт владельцу).
	WorldSeasons.set_turns(21)
	assert_that(WorldSeasons.season_name()).is_equal("Весна")


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


func test_winter_boosts_spawns() -> void:
	WorldSeasons.reset()
	for i in 4:  # ход 4 = Зима (Q-M27: цикл 4, 1 ход = 1 сезон)
		WorldSeasons.advance_turn()
	assert_that(WorldSeasons.season_name()).is_equal("Зима")
	var reg: Node = Services.resolve(&"units")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var calm: UnitStack = null
	var wintery: UnitStack = null
	WorldSeasons.reset()
	calm = reg.make_stack("wolves", rng, WorldSeasons.hostility_mult() * WorldSeasons.enemy_mult())
	for i in 4:  # ход 4 = Зима
		WorldSeasons.advance_turn()
	wintery = reg.make_stack("wolves", rng, WorldSeasons.hostility_mult() * WorldSeasons.enemy_mult())
	assert_bool(wintery.count >= calm.count).is_true()


func test_no_enemy_spawn_near_cities() -> void:
	# Города (capital + вилладж) спавнятся после generate(): место для
	# врагов вокруг городов должно быть заблокировано (ENEMY_CITY_SPAWN_GAP).
	var model := MapModel.new()
	model.map_width = 40
	model.map_height = 40
	model.seed_value = 42
	for y in model.map_height:
		for x in model.map_width:
			model.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
	var spawner := MapSpawner.new(model)
	var reachable: Dictionary = {}
	for y in range(2, 38):
		for x in range(2, 38):
			reachable[Vector2i(x, y)] = true
	var city := City.new()
	city.center = Vector2i(20, 20)
	spawner.set_known_cities([city])
	spawner.place_enemies(reachable)
	assert_bool(model.enemy_stacks.size() > 0).is_true()
	for cell in model.enemy_stacks:
		assert_bool(
			HexUtils.hex_distance(cell, city.center) >= MapSpawner.ENEMY_CITY_SPAWN_GAP
		).is_true()
