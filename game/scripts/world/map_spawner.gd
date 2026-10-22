class_name MapSpawner
extends RefCounted

const _MapModel = preload("res://scripts/world/map_model.gd")

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

## world-map-art-variety 9.1/9.2: таблица «биом → группа ресурсов» — данные,
## не код: правка таблицы не требует правки спавнера. Наследственная генерация
## (generator_version = 1) таблицы не читает — раскладка старых сейвов
## воспроизводится старым правилом (9.3).
const BIOME_RESOURCES_PATH := "res://data/config/biome_resources.json"

static var _table_cache: Dictionary = {}
static var _table_cached := false

## Разрешённая таблица: {biome_ids: {биом: [id]}, id_biomes: {id: [биом]}}.
## Структура файла: {"biomes": {имя биома: [имена типов]}} — тип выбирается
## равномерно из списка биома. Кеш на процесс — файл статичен; тесты читают
## `_load_biome_table()` напрямую (мимо кеша).
static func biome_table() -> Dictionary:
	if not _table_cached:
		_table_cached = true
		_table_cache = _load_biome_table()
	return _table_cache

static func _load_biome_table() -> Dictionary:
	var out := {"biome_ids": {}, "id_biomes": {}}
	var f := FileAccess.open(BIOME_RESOURCES_PATH, FileAccess.READ)
	if f == null:
		push_error("MapSpawner: нет таблицы биомов %s" % BIOME_RESOURCES_PATH)
		return out
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		push_error("MapSpawner: таблица биомов %s не читается как JSON" % BIOME_RESOURCES_PATH)
		return out
	var biomes_raw: Dictionary = data.get("biomes", {})
	var biome_ids: Dictionary = {}
	for biome in biomes_raw:
		var ids: Array[int] = []
		for name in biomes_raw[biome]:
			var id := ResourceType.from_name(str(name))
			if id < 0:
				push_error("MapSpawner: неизвестный ресурс '%s' в биоме '%s'" % [str(name), str(biome)])
				continue
			ids.append(id)
		biome_ids[str(biome)] = ids
	var id_biomes: Dictionary = {}
	for biome in biome_ids:
		for id in biome_ids[biome]:
			if not id_biomes.has(id):
				id_biomes[id] = []
			(id_biomes[id] as Array).append(str(biome))
	out["biome_ids"] = biome_ids
	out["id_biomes"] = id_biomes
	return out

## Группа ресурсов террейна (пусто — на этом биоме ресурсов нет).
static func biome_ids_for_terrain(terrain_id: int) -> Array[int]:
	if terrain_id < 0 or terrain_id >= HexUtils.TERRAIN_NAMES.size():
		return []
	var table := biome_table()
	return (table["biome_ids"] as Dictionary).get(
		HexUtils.TERRAIN_NAMES[terrain_id], [] as Array[int]) as Array[int]

func place_resources(reachable = null, spacing := -1,
		generator_version: int = SaveData.CURRENT_GENERATOR_VERSION) -> void:
	model.resource_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 700
	if spacing < 0:
		spacing = clampi(
			int(float(model.map_width) / GameNumbers.MAP_RESOURCE_SPACING_DIVISOR),
			GameNumbers.MAP_RESOURCE_SPACING_MIN, GameNumbers.MAP_RESOURCE_SPACING_MAX)

	if reachable == null:
		reachable = _get_reachable_cells()

	## world-map-art-variety 9.2: новая генерация (generator_version >= 2) —
	## выбор из группы биома (таблица biome_resources.json); наследственная
	## (== 1) — прежний равномерный бросок 0..6 без изменений, чтобы старые
	## сейвы воспроизводили раскладку клетка-в-клетку (9.3).
	var by_biome: bool = generator_version >= SaveData.CURRENT_GENERATOR_VERSION

	var candidates: Array[Vector2i] = []
	for cell in model.terrain_grid:
		if not reachable.has(cell):
			continue
		var t: int = model.terrain_grid[cell]
		if t == HexUtils.Terrain.WATER or t == HexUtils.Terrain.MOUNTAIN:
			continue
		if model.village_cells.has(cell):
			continue
		if by_biome and biome_ids_for_terrain(t).is_empty():
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
		if by_biome:
			var group: Array[int] = biome_ids_for_terrain(int(model.terrain_grid[cell]))
			model.resource_cells[cell] = group[rng.randi_range(0, group.size() - 1)]
		else:
			model.resource_cells[cell] = rng.randi_range(0, 6)
		for y in range(cell.y - spacing, cell.y + spacing + 1):
			for x in range(cell.x - spacing, cell.x + spacing + 1):
				var nb := Vector2i(x, y)
				if HexUtils.hex_distance(cell, nb) <= spacing:
					blocked[nb] = true
	print_resource_report()

## world-map-art-variety 9.2: отчёт генерации — доля ресурсов «на своём
## биоме» (тип в группе биома клетки) и количество по типам. Доля считается
## по итоговой раскладке, а не по правилу: наследственная карта (v1) печатает
## фактический дрейф, новая (v2) — 1.0.
func resource_report() -> Dictionary:
	var table := biome_table()
	var total: int = int(model.resource_cells.size())
	var home := 0
	var by_type: Dictionary = {}
	for cell in model.resource_cells:
		var id: int = int(model.resource_cells[cell])
		by_type[id] = int(by_type.get(id, 0)) + 1
		var t: int = int(model.terrain_grid.get(cell, -1))
		if t >= 0 and t < HexUtils.TERRAIN_NAMES.size():
			var ids: Array[int] = (table["biome_ids"] as Dictionary).get(
				HexUtils.TERRAIN_NAMES[t], [] as Array[int]) as Array[int]
			if ids.has(id):
				home += 1
	var share: float = float(home) / float(total) if total > 0 else 1.0
	return {"total": total, "home_share": share, "by_type": by_type}

func print_resource_report() -> void:
	var r := resource_report()
	var parts: PackedStringArray = []
	var by_type: Dictionary = r["by_type"]
	for id in by_type:
		parts.append("%s:%d" % [ResourceType.to_key(int(id)), int(by_type[id])])
	print("[MapSpawner] resources: total=%d home_share=%.3f by_type=%s" % [
		int(r["total"]), float(r["home_share"]), ", ".join(parts) if parts.size() > 0 else "—"])

## Растительность (7.2): объект по биомам, id — из манифеста листа объектов
## (`MapObjects.ids()`). Только отрисовка: ни проходимость, ни стоимость
## движения decor_cells не читают (спека «Слои не влияют на логику»), поэтому
## куст на клетке — не препятствие. Прежние «palm»/«cactus» были id, которых в
## листе объектов нет ни одного, а рисовать их было нечем: слой молча оставался
## пустым (носитель растительности появился только с партией объектов).
## Подлесок (7.1, кадр `review-11-3/undergrowth-*.png`) — напольный ярус того же
## леса: он не отдельный биом, а доля клеток леса наряду с деревьями, поэтому он
## в тех же пулах, а не вторым проходом (один объект на клетку — меньше кода и
## не надо решать, кто кого перекрывает в пределах клетки).
const DECOR_FOREST := ["obj_tree_deciduous", "obj_tree_deciduous_large", "obj_conifer",
	"obj_undergrowth"]
const DECOR_DENSE := ["obj_conifer_large", "obj_tree_deciduous_large", "obj_undergrowth"]
const DECOR_SHRUB := ["obj_bush"]
## Рельеф (7.1): гора и мерзлота были биомами без носителя вообще — валуны, склон,
## вершина и снежный валун лежали в листе неиспользованными. Пул на биом, как в
## лесу: один объект на клетку, тип читается по силуэту, а не по данным.
# obj_rock_small из пула снят: мох на «тонком основании» читается как топиарий
# на ножке, а не как валун (глазной прогон кадра relief-t71).
const DECOR_MOUNTAIN := ["obj_slope", "obj_rock_large", "obj_summit", "obj_peak"]
const DECOR_SNOW := ["obj_boulder_snow", "obj_peak"]
const DECOR_FOREST_CHANCE := 0.6
const DECOR_DENSE_CHANCE := 0.85
const DECOR_MOUNTAIN_CHANCE := 0.25
const DECOR_SNOW_CHANCE := 0.4
## У кромки леса кусты читаются как край леса, в глубине лугов — реже, иначе
## луга зарастают в сплошной лес.
const DECOR_EDGE_CHANCE := 0.25
const DECOR_GRASS_CHANCE := 0.06


func place_decor() -> void:
	model.decor_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 900
	for cell in model.terrain_grid:
		if model.village_cells.has(cell) or model.resource_cells.has(cell):
			continue
		var pool: Array = []
		var chance := 0.0
		match int(model.terrain_grid[cell]):
			HexUtils.Terrain.FOREST:
				pool = DECOR_FOREST
				chance = DECOR_FOREST_CHANCE
			HexUtils.Terrain.DENSE_FOREST:
				pool = DECOR_DENSE
				chance = DECOR_DENSE_CHANCE
			HexUtils.Terrain.GRASS:
				pool = DECOR_SHRUB
				chance = DECOR_EDGE_CHANCE if _near_forest(cell) else DECOR_GRASS_CHANCE
			HexUtils.Terrain.MOUNTAIN:
				pool = DECOR_MOUNTAIN
				chance = DECOR_MOUNTAIN_CHANCE
			HexUtils.Terrain.SNOW:
				pool = DECOR_SNOW
				chance = DECOR_SNOW_CHANCE
			_:
				continue
		if rng.randf() >= chance:
			continue
		model.decor_cells[cell] = String(pool[rng.randi() % pool.size()])


## Кромка леса — у клетки есть сосед-лес или плотный лес.
func _near_forest(cell: Vector2i) -> bool:
	for nb in HexUtils.get_all_neighbors(cell):
		var t: int = int(model.terrain_grid.get(nb, -1))
		if t == HexUtils.Terrain.FOREST or t == HexUtils.Terrain.DENSE_FOREST:
			return true
	return false

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

# Минимальная дистанция спавна врага от клеток города. >= ENEMY_AGGRO_RADIUS (8),
# иначе стая сразу в aggro радиусе города захватывает его за 1–2 хода —
# DEFEAT на ходу 2, ранняя игра непроходима (найдено balance-core прогонкой).
const ENEMY_CITY_SPAWN_GAP := GameNumbers.ENEMY_AGGRO_RADIUS

var known_cities: Array = []  # заполняется после generate(): см. WorldBootstrap._create_cities

# ponytail: known_cities — сеттер-защита: из-за раннего кэша класса спавнер
# может иметь старую схему полей, и прямое присваивание падает runtime-error.
func set_known_cities(cities: Array) -> void:
	known_cities.assign(cities)

func place_enemies(reachable = null) -> void:
	model.enemy_stacks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 777

	if reachable == null:
		reachable = _get_reachable_cells()
	var threat_origin := _threat_origin()

	var candidates: Array[Vector2i] = []
	for cell in reachable:
		if cell in model.village_cells or model.resource_cells.has(cell):
			continue

		if cell.x < 3 or cell.x >= model.map_width - 4 or cell.y < 3 or cell.y >= model.map_height - 4:
			continue

		# Не спавнить у ворот городов: см. ENEMY_CITY_SPAWN_GAP.
		if _near_city(cell):
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
		var dist: int = HexUtils.hex_distance(cell, threat_origin) if threat_origin.x >= 0 else THREAT_RING3_RADIUS
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

func _threat_origin() -> Vector2i:
	for city in known_cities:
		if city != null and city.owner == &"player" and city.center is Vector2i:
			return city.center
	return model.find_spawn_cell()

func _city_cells() -> Dictionary:
	# Клетки городов: столицы/вилладжи (known_cities, появляются после
	# generate()) + вилладжи из model.village_cells (есть ещё во время
	# place_enemies — их клетки уже известны).
	var out: Dictionary = {}
	for vc in model.village_cells:
		out[vc] = true
	for city in known_cities:
		if city == null:
			continue
		out[city.center] = true
		for b in city.buildings:
			if b != null and b.cell is Vector2i:
				out[b.cell] = true
	return out

# Без кэша: place_enemies вызывается дважды (generate + после городов),
# города — ≤2, клетки — единицы; пересчёт дёшев.
func _near_city(cell: Vector2i) -> bool:
	var city_cells := _city_cells()
	if city_cells.is_empty():
		return false
	for c in city_cells:
		if HexUtils.hex_distance(cell, c) <= ENEMY_CITY_SPAWN_GAP:
			return true
	return false

static func _threat_pool(dist: int) -> Array:
	if dist < THREAT_RING2_RADIUS:
		return THREAT_RING1
	if dist < THREAT_RING3_RADIUS:
		return THREAT_RING2
	return THREAT_RING3

func _get_reachable_cells() -> Dictionary:
	var start_cell: Vector2i = model.find_spawn_cell()
	if start_cell.x < 0:
		return {}
	return HexPathfinding.bfs_reachable(start_cell, model.map_width + model.map_height,
		model.get_blocked_cells(), model.map_width, model.map_height)
