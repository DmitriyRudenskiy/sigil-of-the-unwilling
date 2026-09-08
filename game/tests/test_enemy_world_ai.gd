extends GdUnitTestSuite

const _Proc = preload("res://scripts/systems/EnemyTurnProcessor.gd")
const _Growth = preload("res://scripts/systems/EnemyGrowthSystem.gd")
const _Profile = preload("res://scripts/data/EnemyAIProfile.gd")
const _MapGen = preload("res://scripts/world/MapGenerator.gd")
const _MapModel = preload("res://scripts/world/MapModel.gd")
const _Delta = preload("res://scripts/world/WorldStateDelta.gd")
const _CityMgr = preload("res://scripts/world/CityManager.gd")
const _City = preload("res://scripts/world/City.gd")

const MAP_SIZE := 12
const SEED := 12345

class FakeHero:
	extends Node
	var current_cell: Vector2i = Vector2i(-1, -1)


var map_gen: MapGenerator
var model: MapModel
var hero: FakeHero
var delta: WorldStateDelta
var cities: CityManager
var proc: EnemyTurnProcessor
var rng := RandomNumberGenerator.new()
var units_reg: Node


func before_test() -> void:
	rng.seed = SEED
	units_reg = Services.resolve(&"units")
	map_gen = _MapGen.new()
	model = _MapModel.new()
	model.map_width = MAP_SIZE
	model.map_height = MAP_SIZE
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			model.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
	map_gen.model = model
	hero = FakeHero.new()
	delta = _Delta.new()
	cities = _CityMgr.new()
	proc = _Proc.new()
	proc.setup_world(map_gen, hero, null, cities, delta, SEED)


func after_test() -> void:
	if map_gen != null:
		map_gen.free()
	if hero != null:
		hero.free()
	if cities != null:
		cities.free()
	proc = null
	map_gen = null
	hero = null
	cities = null


func _make_stack(key: String, count: int = 10) -> Array:
	var s = units_reg.make_fixed_stack(key, count)
	return [s]



func test_profile_faction_by_composition() -> void:
	var sets: Array = units_reg.FACTION_SETS
	var pikeman: Array = _make_stack("pikeman")
	assert_that(EnemyAIProfile.faction_of_army(pikeman, sets)).is_equal(0)
	var skeleton: Array = _make_stack("skeleton")
	assert_that(EnemyAIProfile.faction_of_army(skeleton, sets)).is_equal(2)

	var p: Dictionary = EnemyAIProfile.for_stack(pikeman, sets)
	assert_bool(p.has("weights") and p["weights"].has("village")).is_true()
	assert_bool(p["weights"].has("resource")).is_true()
	assert_bool(p["weights"].has("hero")).is_true()
	assert_that(int(p.get("aggro_radius", 0))).is_equal(GameNumbers.ENEMY_AGGRO_RADIUS)
	assert_that(int(p.get("mp", 0))).is_equal(int(GameNumbers.ENEMY_MP))

	var unknown: Array = [_make_stack("goblins")[0]]
	var pu: Dictionary = EnemyAIProfile.for_stack(unknown, sets)
	assert_bool(pu.has("weights")).is_true()


func test_enemy_moves_toward_hero_and_attacks() -> void:
	var start := Vector2i(2, 2)
	model.enemy_stacks[start] = _make_stack("pikeman")
	hero.current_cell = Vector2i(5, 2)  

	var attacks: Array = []
	proc.enemy_attack_requested.connect(func(army: Array, cell: Vector2i): attacks.append(cell))

	var report: Dictionary = proc.process(TurnContext.new())
	assert_bool(report["attacks"] >= 1).is_true()
	assert_bool(report["moved"] >= 1).is_true()
	assert_that(model.enemy_stacks.size()).is_equal(1)
	var cur: Vector2i = model.enemy_stacks.keys()[0]
	assert_that(HexUtils.hex_distance(cur, hero.current_cell)).is_equal(1)
	assert_that(attacks[0]).is_equal(cur)

func test_enemy_attacks_immediately_on_contact() -> void:
	var start := Vector2i(2, 2)
	model.enemy_stacks[start] = _make_stack("pikeman")
	hero.current_cell = Vector2i(3, 2)  

	var attacks: Array = []
	proc.enemy_attack_requested.connect(func(army: Array, cell: Vector2i): attacks.append(cell))
	var report: Dictionary = proc.process(TurnContext.new())
	assert_that(report["attacks"]).is_equal(1)
	assert_that(report["moved"]).is_equal(0)
	assert_that(attacks[0]).is_equal(start)

func test_village_capture_flips_owner_and_garrisons() -> void:
	var center := Vector2i(2, 4)
	var city = _City.new()
	city.display_name = "Тестовая деревня"
	city.center = center
	city.owner = &"player"
	cities.cities.append(city)

	model.enemy_stacks[Vector2i(2, 2)] = _make_stack("pikeman")
	hero.current_cell = Vector2i(11, 11)  

	var captured: Array = []
	proc.enemy_village_captured.connect(func(c: City): captured.append(c))
	var report: Dictionary = proc.process(TurnContext.new())

	assert_that(captured.size()).is_equal(1)
	assert_that(captured[0]).is_equal(city)
	assert_that(city.owner).is_equal(&"enemy")
	assert_that(report["captures"]).is_equal(1)
	assert_bool(model.enemy_stacks.has(center)).is_true()

	var report2: Dictionary = proc.process(TurnContext.new())
	assert_that(report2["moved"]).is_equal(0)
	assert_bool(model.enemy_stacks.has(center)).is_true()
	var garrisoned: Array = delta.enemy_growth_state.get("garrisoned", [])
	assert_that(garrisoned.size()).is_equal(1)
	assert_that(int(garrisoned[0].get("x", -1))).is_equal(center.x)

func test_enemy_turn_is_deterministic() -> void:
	var results: Array = []
	for i in 2:
		var mg := _MapGen.new()
		var md := _MapModel.new()
		md.map_width = MAP_SIZE
		md.map_height = MAP_SIZE
		for x in MAP_SIZE:
			for y in MAP_SIZE:
				md.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
		mg.model = md
		md.enemy_stacks[Vector2i(2, 2)] = _make_stack("pikeman")
		md.enemy_stacks[Vector2i(8, 3)] = _make_stack("skeleton")
		var h := FakeHero.new()
		h.current_cell = Vector2i(6, 6)
		var p2 := _Proc.new()
		var cm := _CityMgr.new()
		p2.setup_world(mg, h, null, cm, _Delta.new(), SEED)
		var rep: Dictionary = p2.process(TurnContext.new())
		results.append([rep["moved"], rep["attacks"], rep["captures"],
			md.enemy_stacks.keys().duplicate()])
		mg.free()
		h.free()
		cm.free()

	var a: Array = results[0]
	var b: Array = results[1]
	assert_that(a[0]).is_equal(b[0])
	assert_that(a[1]).is_equal(b[1])
	assert_that(a[3]).is_equal(b[3])

func test_no_battle_when_hero_far() -> void:
	model.enemy_stacks[Vector2i(2, 2)] = _make_stack("pikeman")
	hero.current_cell = Vector2i(11, 11)  
	var report: Dictionary = proc.process(TurnContext.new())
	assert_that(report["attacks"]).is_equal(0)
	assert_that(report["moved"]).is_equal(0)


func test_weakened_respawn_after_cooldown() -> void:
	var cell := Vector2i(3, 3)
	var growth := _Growth.new()
	growth.setup_growth(map_gen, null, cities, delta, SEED)

	growth.on_stack_defeated(cell, _make_stack("pikeman", 10))
	var q0: Array = delta.enemy_growth_state.get("respawn_queue", [])
	assert_that(q0.size()).is_equal(1)
	assert_that(int(q0[0]["units"][0]["count"])).is_equal(5)

	var spawned_at: Array = []
	for i in GameNumbers.ENEMY_RESPAWN_TURNS + 1:
		growth.process(TurnContext.new())
		if model.enemy_stacks.has(cell):
			spawned_at.append(i)

	assert_bool(spawned_at.size() >= 1).is_true()
	assert_that(spawned_at[0]).is_equal(GameNumbers.ENEMY_RESPAWN_TURNS - 1)
	var army: Array = model.enemy_stacks[cell]
	assert_that(army.size()).is_equal(1)
	assert_that(army[0].count).is_equal(5)
	var q: Array = delta.enemy_growth_state.get("respawn_queue", [])
	assert_that(q.size()).is_equal(0)

func test_respawn_skipped_when_cell_occupied() -> void:
	var cell := Vector2i(3, 3)
	model.enemy_stacks[cell] = _make_stack("skeleton")  
	delta.enemy_growth_state["respawn_queue"] = [
		{"x": cell.x, "y": cell.y, "units": [{"key": "pikeman", "count": 10}], "turns_left": 1},
	]
	var growth := _Growth.new()
	growth.setup_growth(map_gen, null, cities, delta, SEED)
	growth.process(TurnContext.new())
	var army: Array = model.enemy_stacks[cell]
	assert_that(army[0].get_key()).is_equal("skeleton")
	assert_that(delta.enemy_growth_state.get("respawn_queue", []).size()).is_equal(0)


func test_growth_state_roundtrip() -> void:
	delta.enemy_growth_state["respawn_queue"] = [
		{"x": 3, "y": 4, "units": [{"key": "pikeman", "count": 5}], "turns_left": 2},
	]
	delta.enemy_growth_state["garrisoned"] = [{"x": 7, "y": 8}]
	var data: Dictionary = delta.serialize()
	var back = _Delta.new()
	back.deserialize(data)
	assert_that(back.enemy_growth_state.get("respawn_queue", []).size()).is_equal(1)
	assert_that(back.enemy_growth_state.get("garrisoned", []).size()).is_equal(1)
	assert_that(int(back.enemy_growth_state["respawn_queue"][0]["turns_left"])).is_equal(2)


func test_dist_field_from_hero_per_turn() -> void:
	var cost := func(_c: Vector2i) -> float: return 1.0
	# Hero-поле: строится от героя один раз за ход.
	hero.current_cell = Vector2i(2, 2)
	proc._rebuild_hero_dist_field()
	assert_bool(proc._hero_dist_field_valid).is_true()
	assert_that(proc._hero_dist_field[HexUtils.pos_to_idx(hero.current_cell, MAP_SIZE)]).is_equal(0.0)
	# Per-stack поле: кэшируется в пределах хода.
	var cache := {}
	var start := Vector2i(8, 8)
	var d1: PackedFloat32Array = proc._dist_field(start, 5.0, cost, cache)
	var d2: PackedFloat32Array = proc._dist_field(start, 5.0, cost, cache)
	assert_that(cache.size()).is_equal(1)
	assert_that(d1).is_equal(d2)
	var goal := Vector2i(9, 8)
	var path: Array[Vector2i] = HexPathfinding.dijkstra_path(start, goal, d1, cost, MAP_SIZE, MAP_SIZE)
	assert_bool(path.is_empty()).is_false()
	assert_that(path[0]).is_equal(start)
	assert_that(path[path.size() - 1]).is_equal(goal)
