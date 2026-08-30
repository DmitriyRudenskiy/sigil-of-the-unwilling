extends RefCounted
class_name TerrainCostTable
## Единый источник стоимостей передвижения по террейнам (ОД за вход).

# Активные биомы проекта
const GRASS := 1.0
const FOREST := 1.25
const MOUNTAIN := 1.25
const SAND := 1.5
const SNOW := 1.5
const SWAMP := 1.75
const WATER := INF

# Зарезервированные террейны (будущие расширения, не генерируются сейчас)
# Грязь (Dirt), Лава (Lava), Подземелье (Underground) → 1.0
# Пустоши (Wasteland), Высокогорье (Highlands) → 1.25

static var _costs: Dictionary = {}
# int-таблицы (индекс = HexUtils.Terrain id) — для hot path (Dijkstra):
# без String-аллокаций и dict-lookup'ов.
static var _costs_by_id: PackedFloat32Array = PackedFloat32Array()
static var _levitation_costs_by_id: PackedFloat32Array = PackedFloat32Array()


static func ensure() -> void:
	if not _costs.is_empty():
		return
	_costs = {
		"grass": GRASS,
		"forest": FOREST,
		"mountain": MOUNTAIN,
		"sand": SAND,
		"snow": SNOW,
		"swamp": SWAMP,
		"water": WATER,
	}
	_costs_by_id = PackedFloat32Array()
	_levitation_costs_by_id = PackedFloat32Array()
	for i in HexUtils.TERRAIN_NAMES.size():
		var name: String = HexUtils.TERRAIN_NAMES[i]
		_costs_by_id.append(get_cost(name))
		_levitation_costs_by_id.append(get_cost_with_effects(name, true))


static func get_cost(terrain: String) -> float:
	ensure()
	if terrain == "water":
		return WATER
	return _costs.get(terrain, GRASS)


## Стоимость с учётом артефактов: полёт над водой (boots_levitation → water = 1.0)
static func get_cost_with_effects(terrain: String, has_levitation: bool) -> float:
	ensure()
	if terrain == "water":
		return GRASS if has_levitation else WATER
	return _costs.get(terrain, GRASS)


## Стоимость по ID террейна (int) — быстрый путь для Dijkstra.
## Эквивалент get_cost_with_effects(), но без String-аллокаций.
static func get_cost_with_effects_by_id(terrain_id: int, has_levitation: bool) -> float:
	ensure()
	if terrain_id < 0 or terrain_id >= _costs_by_id.size():
		return GRASS
	return _levitation_costs_by_id[terrain_id] if has_levitation else _costs_by_id[terrain_id]


## Все известные террейны (для итерации)
static func get_all_terrains() -> Array[String]:
	ensure()
	var r: Array[String] = []
	for k in _costs:
		r.append(k)
	return r
