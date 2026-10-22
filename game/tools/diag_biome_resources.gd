extends SceneTree
## world-map-art-variety 9.5: баланс-проба таблицы «биом → ресурс».
##
## Для N run-сидов генерирует полную карту тем же конвейером, что и
## MapGenerator.generate (шум → сглаживание → горы → реки → леса → деревни →
## достижимость; сид карты = первый randi после посева, как в
## world_bootstrap._create_map), и ставит ресурсы двумя способами:
## наследственный (v1, равномерный бросок 0..6 — базовая линия) и новый
## (v2, таблица biome_resources.json). Печатает средние/минимальные
## количества по типам, home_share и распределение по биомам.
##
## Headless, без сцены:
##   godot --headless --path game -s tools/diag_biome_resources.gd [N]

const DEFAULT_SEEDS := 50
const BASE_RUN_SEED := 20260001
## MapSpawner грузится в рантайме, а не через class_name: скрипт с class_name-
## зависимостью компилируется на старте (до autoload), а map_spawner.gd
## ссылается на autoload Services и в этот момент не компилируется.
const MAP_SPAWNER_PATH := "res://scripts/world/map_spawner.gd"


## ВАЖНО: логика в `_initialize()`, не `_init()` — в `-s`-режиме autoload-
## идентификаторы (Services в map_spawner.gd) резолвятся только после
## SceneTree::initialize(), когда autoloadы зарегистрированы.
func _initialize() -> void:
	var spawner_script: GDScript = load(MAP_SPAWNER_PATH)
	var n := DEFAULT_SEEDS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = maxi(1, int(args[0]))

	var sum_v1: Dictionary = {}
	var sum_v2: Dictionary = {}
	var min_v1: Dictionary = {}
	var min_v2: Dictionary = {}
	var home_v1: Array[float] = []
	var home_v2: Array[float] = []
	var total_v1: Array[int] = []
	var total_v2: Array[int] = []
	var biome_v1: Dictionary = {}
	var biome_v2: Dictionary = {}
	var maps := 0

	for i in n:
		var model := _generate_world(BASE_RUN_SEED + i)
		if model == null:
			continue
		maps += 1
		var reachable := _reachable(model)
		var spawner = spawner_script.new(model)
		spawner.place_resources(reachable, -1, 1)
		_accumulate(model, spawner, sum_v1, min_v1, home_v1, total_v1, biome_v1)
		model.resource_cells.clear()
		spawner.place_resources(reachable, -1, 2)
		_accumulate(model, spawner, sum_v2, min_v2, home_v2, total_v2, biome_v2)

	print("[biome-res] maps=%d" % maps)
	_print_version("v1 legacy (uniform 0..6)", maps, sum_v1, min_v1, home_v1, total_v1, biome_v1)
	_print_version("v2 biome table", maps, sum_v2, min_v2, home_v2, total_v2, biome_v2)
	quit()


func _print_version(
		label: String, maps: int,
		sums: Dictionary, mins: Dictionary, homes: Array, totals: Array,
		biomes: Dictionary
) -> void:
	if maps <= 0:
		print("[biome-res] %s: no maps" % label)
		return
	var total_avg := 0.0
	for t in totals:
		total_avg += float(t)
	total_avg /= float(maps)
	var home_avg := 0.0
	for h in homes:
		home_avg += h
	home_avg /= float(maps)
	var type_parts: PackedStringArray = []
	for id in ResourceType.classic_ids():
		type_parts.append("%s avg=%.1f min=%d" % [
			ResourceType.to_key(id), float(sums.get(id, 0)) / float(maps),
			int(mins.get(id, 0))])
	var biome_parts: PackedStringArray = []
	for b in biomes:
		biome_parts.append("%s:%d" % [str(b), int(biomes[b])])
	print("[biome-res] %s: total avg=%.1f home_share avg=%.3f" % [label, total_avg, home_avg])
	print("[biome-res]   types: %s" % " | ".join(type_parts))
	print("[biome-res]   biomes: %s" % " | ".join(biome_parts))


func _accumulate(
		model: MapModel, spawner, sums: Dictionary, mins: Dictionary,
		homes: Array, totals: Array, biomes: Dictionary
) -> void:
	var rep: Dictionary = spawner.resource_report()
	totals.append(int(rep["total"]))
	homes.append(float(rep["home_share"]))
	var by_type: Dictionary = rep["by_type"]
	for id in ResourceType.classic_ids():
		var c := int(by_type.get(id, 0))
		sums[id] = int(sums.get(id, 0)) + c
		if not mins.has(id) or c < int(mins[id]):
			mins[id] = c
	for cell in model.resource_cells:
		var name: String = str(HexUtils.TERRAIN_NAMES[int(model.terrain_grid[cell])])
		biomes[name] = int(biomes.get(name, 0)) + 1


## Та же цепочка, что в MapGenerator.generate, без сцены/тайлсетов.
func _generate_world(run_seed: int) -> MapModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var model := MapModel.new()
	model.map_width = 60
	model.map_height = 60
	model.seed_value = rng.randi() % 999999
	model.village_count = GameNumbers.MAP_VILLAGE_COUNT
	model.generate_noise()
	model.smooth_invalid_adjacencies()
	MapMountainGenerator.new(model).generate()
	MapRiverGenerator.new(model).generate()
	MapForestGenerator.new(model).generate()
	load(MAP_SPAWNER_PATH).new(model).place_villages()
	return model


func _reachable(model: MapModel) -> Dictionary:
	var start_cell: Vector2i = model.find_spawn_cell(true)
	if start_cell.x < 0:
		return {}
	return HexPathfinding.bfs_reachable(
		start_cell,
		model.map_width + model.map_height,
		model.get_blocked_cells(),
		model.map_width,
		model.map_height,
		true
	)
