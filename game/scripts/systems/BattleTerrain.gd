class_name HexTerrain
extends RefCounted
## Боевая местность (tactical-battle-system, фаза 5).
## NOTE: переименовано с BattleTerrain -> HexTerrain при merge двух боевых
## систем (local String-terrain battle_terrain.gd сохранил имя BattleTerrain).
##
## Каждый гекс боевой доски имеет тип местности. Тип влияет на:
##   * защиту юнита на этом гексе (лес/холм/укрепление),
##   * атаку, если юнит бьёт «вниз» (высота атакующего выше высоты цели),
##   * прохождение (вода блокирует),
##   * скорость (лес/холм/укрепление замедляют).
##
## Значения — из specs/tactical-combat/spec.md (требование «Местность»).
## Местность детерминированно генерируется из seed боя (см. generate),
## не затрагивая стратегический слой карты (proposal: «Не трогается»).

enum TerrainType { PLAIN, FOREST, HILL, FORT, WATER }

## +20% атака, когда атакующий выше цели (требование «Холм»).
const DOWNHILL_ATTACK_MULT := 1.2

const _DEFENSE_MULT := {
	TerrainType.PLAIN: 1.0,
	TerrainType.FOREST: 1.3,
	TerrainType.HILL: 1.5,
	TerrainType.FORT: 1.75,
	TerrainType.WATER: 1.0,
}

const _ELEVATION := {
	TerrainType.PLAIN: 0,
	TerrainType.FOREST: 0,
	TerrainType.HILL: 1,
	TerrainType.FORT: 1,
	TerrainType.WATER: 0,
}

const _SPEED_MULT := {
	TerrainType.PLAIN: 1.0,
	TerrainType.FOREST: 0.8,
	TerrainType.HILL: 0.7,
	TerrainType.FORT: 0.5,
	TerrainType.WATER: 0.0,
}

## Множитель защиты юнита, стоящего на местности t (требование «Местность»).
static func defense_multiplier(t: int) -> float:
	return float(_DEFENSE_MULT.get(t, 1.0))

## Высота местности (для проверки атаки «вниз»).
static func elevation(t: int) -> int:
	return int(_ELEVATION.get(t, 0))

## Блокирует ли местность движение (вода).
static func is_blocking(t: int) -> bool:
	return t == TerrainType.WATER

## Множитель скорости по местности (для pathfinding).
static func speed_multiplier(t: int) -> float:
	return float(_SPEED_MULT.get(t, 1.0))

## Детерминированная генерация местности из rng.
##
## Возвращает {Vector2i: TerrainType} только для «природных» гексов;
## остальная доска считается PLAIN. Колонки развёртки (x=0 и x=bw-1)
## оставляются чистыми, чтобы стартовые гексы юнитов были проходимыми.
## `density` — доля внутренних гексов, получающих тип (0..1).
static func generate(rng: RandomNumberGenerator, bw: int, bh: int, density: float = 0.1) -> Dictionary:
	var cells: Array = []
	for y in bh:
		for x in bw:
			if x <= 0 or x >= bw - 1:
				continue
			cells.append(Vector2i(x, y))

	# Fisher–Yates с переданным rng — детерминированная перестановка.
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp

	var n: int = int(float(cells.size()) * clampf(density, 0.0, 1.0))
	var grid: Dictionary = {}
	for i in n:
		grid[cells[i]] = _random_type(rng)
	return grid

## Взвешенный выбор типа: лес чаще всего, затем холм, укрепление, вода.
static func _random_type(rng: RandomNumberGenerator) -> int:
	var r: float = rng.randf()
	if r < 0.45:
		return TerrainType.FOREST
	if r < 0.70:
		return TerrainType.HILL
	if r < 0.85:
		return TerrainType.FORT
	return TerrainType.WATER
