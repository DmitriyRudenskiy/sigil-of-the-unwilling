class_name MapSpawner
extends RefCounted

const _MapModel = preload("res://scripts/world/MapModel.gd")

var model
var _units_registry: Node = null

func setup_registry(units_registry: Node) -> void:
	_units_registry = units_registry

func _init(p_model) -> void:
	model = p_model

func place_villages() -> void:
	model.village_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 500

	var candidates: Array[Vector2i] = []
	for cell in model.terrain_grid:
		if model.is_walkable(cell):
			candidates.append(cell)
	for i in candidates.size():
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var spacing: int = 4
	var blocked: Dictionary = {}

	for cell in candidates:
		if model.village_cells.size() >= model.village_count:
			break
		if blocked.has(cell):
			continue
		model.village_cells.append(cell)
		for y in range(cell.y - spacing, cell.y + spacing + 1):
			for x in range(cell.x - spacing, cell.x + spacing + 1):
				var nb := Vector2i(x, y)
				if HexUtils.hex_distance(cell, nb) <= spacing:
					blocked[nb] = true

func place_resources(reachable = null, spacing := -1) -> void:
	model.resource_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 700
	if spacing < 0:
		spacing = clampi(
			int(float(model.map_width) / GameNumbers.MAP_RESOURCE_SPACING_DIVISOR),
			GameNumbers.MAP_RESOURCE_SPACING_MIN, GameNumbers.MAP_RESOURCE_SPACING_MAX)

	if reachable == null:
		reachable = _get_reachable_cells()

	var candidates: Array[Vector2i] = []
	for cell in model.terrain_grid:
		if not reachable.has(cell):
			continue
		var t: int = model.terrain_grid[cell]
		if t == HexUtils.Terrain.WATER or t == HexUtils.Terrain.MOUNTAIN:
			continue
		if model.village_cells.has(cell):
			continue
		candidates.append(cell)

	for i in candidates.size():
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var blocked: Dictionary = {}
	var target := GameNumbers.MAP_RESOURCE_COUNT
	for cell in candidates:
		if model.resource_cells.size() >= target:
			break
		if blocked.has(cell):
			continue
		model.resource_cells[cell] = rng.randi_range(0, 6)
		for y in range(cell.y - spacing, cell.y + spacing + 1):
			for x in range(cell.x - spacing, cell.x + spacing + 1):
				var nb := Vector2i(x, y)
				if HexUtils.hex_distance(cell, nb) <= spacing:
					blocked[nb] = true

func place_decor() -> void:
	model.decor_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 900
	for cell in model.terrain_grid:
		if model.terrain_grid[cell] == HexUtils.Terrain.SAND and rng.randf() < 0.04:
			model.decor_cells[cell] = "palm" if rng.randf() > 0.5 else "cactus"

# Ранняя игра: кольцевые тиры врагов (early-game-foundation, world-threat-rings).
# Кольцо 1 — дикие животные, 2 — гуманоиды, 3 — монстры.
const THREAT_RING1: Array = GameNumbersHero.WILD_ANIMAL_KEYS
const THREAT_RING2 := ["goblins", "gnoll", "lizardman", "orc", "ogre", "hobgoblin",
	"skeleton", "zombie", "harpy", "wraith"]
const THREAT_RING3 := ["trolls", "stone_golem", "iron_golem", "fire_elemental",
	"storm_elemental", "red_dragon", "green_dragon", "gargoyle", "titan",
	"minotaur", "hydra", "medusa", "beholder", "phoenix"]
const THREAT_RING2_RADIUS := 12
const THREAT_RING3_RADIUS := 24

func place_enemies(reachable = null) -> void:
	model.enemy_stacks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 777

	if reachable == null:
		reachable = _get_reachable_cells()
	var start_cell := _start_cell()

	var candidates: Array[Vector2i] = []
	for cell in reachable:
		if cell in model.village_cells or model.resource_cells.has(cell):
			continue

		if cell.x < 3 or cell.x >= model.map_width - 4 or cell.y < 3 or cell.y >= model.map_height - 4:
			continue
		candidates.append(cell)

	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var placed := 0

	var reg: Node = Services.resolve(&"units")
	for cell in candidates:
		if placed >= GameNumbers.MAP_ENEMY_COUNT:
			break

		# Ранняя игра: тир по дистанции от старта, случайный выбор из общего пула запрещён
		var dist: int = HexUtils.hex_distance(cell, start_cell) if start_cell.x >= 0 else THREAT_RING3_RADIUS
		var pool: Array = _threat_pool(dist)
		var army: Array[UnitStack] = []

		# Ранняя игра: размер стай — враждебность партии + сезон (early-game-foundation)
		var size_mult: float = WorldSeasons.hostility_mult() * WorldSeasons.enemy_mult()
		var unit_count := rng.randi_range(1, 3)
		for i in unit_count:
			var unit_key: String = pool[rng.randi_range(0, pool.size() - 1)]
			var stack = reg.make_stack(unit_key, rng, size_mult)
			if stack != null and stack.is_alive():
				army.append(stack)

		if army.size() > 0:
			model.enemy_stacks[cell] = army
			placed += 1

func _start_cell() -> Vector2i:
	# Стартовая клетка героя (та же, что и в _get_reachable_cells)
	for y in model.map_height:
		for x in model.map_width:
			var cell := Vector2i(x, y)
			if model.is_walkable(cell):
				return cell
	return Vector2i(-1, -1)

static func _threat_pool(dist: int) -> Array:
	if dist < THREAT_RING2_RADIUS:
		return THREAT_RING1
	if dist < THREAT_RING3_RADIUS:
		return THREAT_RING2
	return THREAT_RING3

func _get_reachable_cells() -> Dictionary:
	var start_cell := Vector2i(-1, -1)
	for y in model.map_height:
		for x in model.map_width:
			var cell := Vector2i(x, y)
			if model.is_walkable(cell):
				start_cell = cell
				break
		if start_cell.x >= 0: break
	if start_cell.x < 0:
		return {}
	return HexPathfinding.bfs_reachable(start_cell, model.map_width + model.map_height,
		model.get_blocked_cells(), model.map_width, model.map_height)
