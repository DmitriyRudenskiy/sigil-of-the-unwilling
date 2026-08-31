class_name ArenaBalance
extends RefCounted
## Баланс строительной арены: приросты ресурсов по кольцам и
## бонусы зданий по кольцам.
##
## АВТО-ГЕНЕРАЦИЯ: численные константы RING_YIELD / RING_BONUS
## подбираются итеративно (hill climbing) инструментом:
##     /Applications/Godot.app/Contents/MacOS/Godot --headless \
##         -s tools/tune_city_arena.gd -- --evals 8000
## Не редактировать числа вручную — пересоберите файл тюнером.

const ARENA_RADIUS := 5

## Ресурсы прироста по кольцам: порядок [food, industry, dust, science,
## influence]. Строка 0 — центр (не используется).
const RING_YIELD: Array = [
	[0.00, 0.00, 0.00, 0.00, 0.00],
	[3.00, 6.00, 0.00, 0.00, 0.00],
	[3.50, 6.00, 0.00, 0.00, 0.50],
	[4.00, 6.00, 0.50, 1.00, 1.00],
	[6.00, 6.00, 1.00, 0.50, 1.00],
	[2.00, 1.00, 1.50, 1.00, 1.50],
]

## Доп. множитель здания на кольце: building_id -> {кольцо: бонус}.
## Общий множитель здания = 1.0 + ring_bonus(def_id, ring).
const RING_BONUS: Dictionary = {
	&"farm": { 1: 0.00, 2: 0.00, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"mill": { 1: 0.15, 2: 0.00, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"bakery": { 1: 0.00, 2: 0.10, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"mine": { 1: 0.00, 2: 0.15, 3: 0.20, 4: 0.00, 5: 0.00 },
	&"smithy": { 1: 0.00, 2: 0.20, 3: 0.25, 4: 0.00, 5: 0.00 },
	&"tavern": { 1: 0.00, 2: 0.10, 3: 0.15, 4: 0.00, 5: 0.00 },
	&"trade_post": { 1: 0.00, 2: 0.15, 3: 0.20, 4: 0.00, 5: 0.00 },
	&"school": { 1: 0.10, 2: 0.00, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"market": { 1: 0.00, 2: 0.20, 3: 0.10, 4: 0.00, 5: 0.00 },
	&"shack": { 1: 0.00, 2: 0.10, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"walls": { 1: 0.00, 2: 0.00, 3: 0.10, 4: 0.25, 5: 0.00 },
}

## --- Механики: кластер ×4 (авто-слияние TerraScape) -----------------
## Мин. размер связной группы зданий одного типа.
const CLUSTER_MIN := 4
## Множитель производства каждого здания в кластере.
const CLUSTER_MULT := 1.5
## Бонусных слотов рабочих на каждый кластер.
const CLUSTER_HOUSING := 2

## --- Механики: особенности клеток (детерминированный хэш) -----------
## Вероятность особенности на клетке колец 2..4 (0..1).
const FEATURE_CHANCE := 0.13
## Карьер: рудник ×N.
const FEATURE_QUARRY_MULT := 1.5
## Родник: ферма ×N.
const FEATURE_SPRING_MULT := 1.5
## Река: любое здание ×N.
const FEATURE_RIVER_MULT := 1.25
## Руины: разовый бонус золота за постройку на клетке.
const FEATURE_RUINS_GOLD := 15.0

## --- Механики: шторм -----------------------------------------------
## Шторм на каждом N-м ходе (turn % N == 0).
const STORM_PERIOD := 6
## Множитель производства в шторм (без стен ур. 2).
const STORM_PRODUCTION_MULT := 0.75
## Множитель производства в шторм со стенами ур. 2+.
const STORM_MITIGATED_PRODUCTION_MULT := 0.875
## Потери еды в шторме (без стен / со стенами ур. 2+).
const STORM_FOOD := 2.0
const STORM_MITIGATED_FOOD := 1.0


## Прирост ресурсов на клетке кольца `ring`: {food, industry, dust,
## science, influence} (пусто для центра/вне арены).
static func ring_yield(ring: int, table: Array = RING_YIELD) -> Dictionary:
	if ring < 1 or ring > ARENA_RADIUS:
		return {}
	var row: Array = table[ring]
	return {
		&"food": float(row[0]),
		&"industry": float(row[1]),
		&"dust": float(row[2]),
		&"science": float(row[3]),
		&"influence": float(row[4]),
	}


## Бонус здания на кольце (0.0 = без бонуса; общий = 1.0 + bonus).
static func ring_bonus(def_id: StringName, ring: int, table: Dictionary = RING_BONUS) -> float:
	if not table.has(def_id):
		return 0.0
	var row: Dictionary = table[def_id]
	return float(row.get(ring, 0.0))
