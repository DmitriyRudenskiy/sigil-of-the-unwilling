extends "res://tests/gut_base.gd"
## enemy-world-ai: профили фракций, ход врагов (движение/атака/захват),
## детерминизм, рост (ослабленное возрождение), сериализация growth state.

const _Proc = preload("res://scripts/systems/EnemyTurnProcessor.gd")
const _Growth = preload("res://scripts/systems/EnemyGrowthSystem.gd")
const _Profile = preload("res://scripts/data/EnemyAIProfile.gd")
const _MapGen = preload("res://scripts/world/MapGenerator.gd")
const _MapModel = preload("res://scripts/world/MapModel.gd")
const _Delta = preload("res://scripts/world/WorldStateDelta.gd")
const _CityMgr = preload("res://scripts/world/CityManager.gd")
const _City = preload("res://scripts/world/City.gd")
const _ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")

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


func before_each() -> void:
	rng.seed = SEED
	units_reg = _ServiceLocator.resolve(null, &"units")
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


func after_each() -> void:
	# proc/delta — RefCounted: просто сбрасываем ссылки ниже.
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


# ==================== ПРОФИЛИ ФРАКЦИЙ ====================

func test_profile_faction_by_composition() -> void:
	var sets: Array = units_reg.FACTION_SETS
	var pikeman: Array = _make_stack("pikeman")
	assert_eq(EnemyAIProfile.faction_of_army(pikeman, sets), 0, "pikeman -> faction 0")
	var skeleton: Array = _make_stack("skeleton")
	assert_eq(EnemyAIProfile.faction_of_army(skeleton, sets), 2, "skeleton -> faction 2")

	var p: Dictionary = EnemyAIProfile.for_stack(pikeman, sets)
	assert_true(p.has("weights") and p["weights"].has("village"), "profile has village weight")
	assert_true(p["weights"].has("resource"), "profile has resource weight")
	assert_true(p["weights"].has("hero"), "profile has hero weight")
	assert_eq(int(p.get("aggro_radius", 0)), GameSettings.ENEMY_AGGRO_RADIUS, "aggro from settings")
	assert_eq(int(p.get("mp", 0)), int(GameSettings.ENEMY_MP), "mp from settings")

	# Неизвестная армия -> дефолтный профиль (фракция 0), не падает.
	var unknown: Array = [_make_stack("goblins")[0]]
	var pu: Dictionary = EnemyAIProfile.for_stack(unknown, sets)
	assert_true(pu.has("weights"), "unknown army gets default profile")

# ==================== ХОД ВРАГОВ ====================

func test_enemy_moves_toward_hero_and_attacks() -> void:
	var start := Vector2i(2, 2)
	model.enemy_stacks[start] = _make_stack("pikeman")
	hero.current_cell = Vector2i(5, 2)  # hex-дистанция 3

	var attacks: Array = []
	proc.enemy_attack_requested.connect(func(army: Array, cell: Vector2i): attacks.append(cell))

	var report: Dictionary = proc.process(TurnContext.new())
	assert_true(report["attacks"] >= 1, "enemy attacked hero")
	assert_true(report["moved"] >= 1, "enemy moved")
	assert_eq(model.enemy_stacks.size(), 1, "one stack left")
	var cur: Vector2i = model.enemy_stacks.keys()[0]
	assert_eq(HexUtils.hex_distance(cur, hero.current_cell), 1, "enemy stopped adjacent to hero")
	assert_eq(attacks[0], cur, "attack requested from the contact cell")

func test_enemy_attacks_immediately_on_contact() -> void:
	var start := Vector2i(2, 2)
	model.enemy_stacks[start] = _make_stack("pikeman")
	hero.current_cell = Vector2i(3, 2)  # уже рядом

	var attacks: Array = []
	proc.enemy_attack_requested.connect(func(army: Array, cell: Vector2i): attacks.append(cell))
	var report: Dictionary = proc.process(TurnContext.new())
	assert_eq(report["attacks"], 1, "immediate attack")
	assert_eq(report["moved"], 0, "no movement when already in range")
	assert_eq(attacks[0], start, "attack from the start cell")

func test_village_capture_flips_owner_and_garrisons() -> void:
	var center := Vector2i(2, 4)
	var city = _City.new()
	city.display_name = "Тестовая деревня"
	city.center = center
	city.owner = &"player"
	cities.cities.append(city)

	model.enemy_stacks[Vector2i(2, 2)] = _make_stack("pikeman")
	hero.current_cell = Vector2i(11, 11)  # вне радиуса агрессии

	var captured: Array = []
	proc.enemy_village_captured.connect(func(c: City): captured.append(c))
	var report: Dictionary = proc.process(TurnContext.new())

	assert_eq(captured.size(), 1, "village captured")
	assert_eq(captured[0], city, "captured the right city")
	assert_eq(city.owner, &"enemy", "owner flipped to enemy")
	assert_eq(report["captures"], 1, "report captures = 1")
	assert_true(model.enemy_stacks.has(center), "garrison stays at the village")

	# Гарнизон не двигается на следующих ходах.
	var report2: Dictionary = proc.process(TurnContext.new())
	assert_eq(report2["moved"], 0, "garrison does not move")
	assert_true(model.enemy_stacks.has(center), "garrison still there")
	var garrisoned: Array = delta.enemy_growth_state.get("garrisoned", [])
	assert_eq(garrisoned.size(), 1, "one garrisoned cell in delta")
	assert_eq(int(garrisoned[0].get("x", -1)), center.x, "garrison x persisted")

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
		p2.setup_world(mg, h, null, _CityMgr.new(), _Delta.new(), SEED)
		var rep: Dictionary = p2.process(TurnContext.new())
		results.append([rep["moved"], rep["attacks"], rep["captures"],
			md.enemy_stacks.keys().duplicate()])
		# p2 — RefCounted: ссылка сброшится
		mg.free()
		h.free()

	var a: Array = results[0]
	var b: Array = results[1]
	assert_eq(a[0], b[0], "deterministic moves")
	assert_eq(a[1], b[1], "deterministic attacks")
	assert_eq(a[3], b[3], "deterministic final positions")

func test_no_battle_when_hero_far() -> void:
	model.enemy_stacks[Vector2i(2, 2)] = _make_stack("pikeman")
	hero.current_cell = Vector2i(11, 11)  # дистанция 14 > радиуса 8
	var report: Dictionary = proc.process(TurnContext.new())
	assert_eq(report["attacks"], 0, "no attack out of aggro")
	assert_eq(report["moved"], 0, "no goals in range -> no movement")

# ==================== РОСТ: ВОЗРОЖДЕНИЕ ====================

func test_weakened_respawn_after_cooldown() -> void:
	var cell := Vector2i(3, 3)
	var growth := _Growth.new()
	growth.setup_growth(map_gen, null, cities, delta, SEED)

	# Уничтожен стек из 10 — в очередь уходит ослабленный на 1 ярус (5).
	growth.on_stack_defeated(cell, _make_stack("pikeman", 10))
	var q0: Array = delta.enemy_growth_state.get("respawn_queue", [])
	assert_eq(q0.size(), 1, "queue entry created")
	assert_eq(int(q0[0]["units"][0]["count"]), 5, "halved: 10 -> 5")

	var spawned_at: Array = []
	for i in GameSettings.ENEMY_RESPAWN_TURNS + 1:
		growth.process(TurnContext.new())
		if model.enemy_stacks.has(cell):
			spawned_at.append(i)

	assert_true(spawned_at.size() >= 1, "stack respawned")
	assert_eq(spawned_at[0], GameSettings.ENEMY_RESPAWN_TURNS - 1, "respawned after full cooldown (0-based)")
	var army: Array = model.enemy_stacks[cell]
	assert_eq(army.size(), 1, "one stack unit type")
	assert_eq(army[0].count, 5, "respawned weakened: 10 -> 5")
	var q: Array = delta.enemy_growth_state.get("respawn_queue", [])
	assert_eq(q.size(), 0, "queue entry consumed")

func test_respawn_skipped_when_cell_occupied() -> void:
	var cell := Vector2i(3, 3)
	model.enemy_stacks[cell] = _make_stack("skeleton")  # клетка занята
	delta.enemy_growth_state["respawn_queue"] = [
		{"x": cell.x, "y": cell.y, "units": [{"key": "pikeman", "count": 10}], "turns_left": 1},
	]
	var growth := _Growth.new()
	growth.setup_growth(map_gen, null, cities, delta, SEED)
	growth.process(TurnContext.new())
	var army: Array = model.enemy_stacks[cell]
	assert_eq(army[0].get_key(), "skeleton", "existing stack untouched")
	assert_eq(delta.enemy_growth_state.get("respawn_queue", []).size(), 0, "entry dropped (no infinite retry)")

# ==================== СЕРИАЛИЗАЦИЯ GROWTH STATE ====================

func test_growth_state_roundtrip() -> void:
	delta.enemy_growth_state["respawn_queue"] = [
		{"x": 3, "y": 4, "units": [{"key": "pikeman", "count": 5}], "turns_left": 2},
	]
	delta.enemy_growth_state["garrisoned"] = [{"x": 7, "y": 8}]
	var data: Dictionary = delta.serialize()
	var back = _Delta.new()
	back.deserialize(data)
	assert_eq(back.enemy_growth_state.get("respawn_queue", []).size(), 1, "queue roundtrip")
	assert_eq(back.enemy_growth_state.get("garrisoned", []).size(), 1, "garrisoned roundtrip")
	assert_eq(int(back.enemy_growth_state["respawn_queue"][0]["turns_left"]), 2, "turns_left roundtrip")
