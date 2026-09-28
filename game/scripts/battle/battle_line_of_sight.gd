class_name BattleLineOfSight
extends RefCounted

## Линия видимости для тактического боя (tactical-combat-implementation,
## фаза 4). Переиспользует DNDLineOfSight через адаптер местность→высота:
## холм = 1 уровень, укрепление = 2. Лес НЕ блокирует LOS, но листва
## скрывает цель от дальнобойной атаки на дистанции > 1.

## Местность → уровень высоты для DNDLineOfSight.
const _ELEVATION: Dictionary = {
	BattleTerrain.HILL: 1,
	BattleTerrain.FORT: 2,
}


## Адаптер: строит DNDElevationSystem из боевой карты местности.
static func terrain_elevation(state: BattleState) -> DNDElevationSystem:
	var elev := DNDElevationSystem.new()
	for c in state.battle_terrain:
		var level: int = int(_ELEVATION.get(str(state.battle_terrain[c]), 0))
		if level > 0:
			elev.set_elevation(c, level)
	return elev


## Может ли юнит в `atk_cell` видеть цель в `target_cell` (LOS по высотам).
static func has_line_of_sight(state: BattleState, atk_cell: Vector2i, target_cell: Vector2i) -> bool:
	if state.battle_terrain.is_empty():
		return true
	return DNDLineOfSight.has_line_of_sight(terrain_elevation(state), atk_cell, target_cell)


## Полная проверка дальнего выстрела: дистанция, LOS и листва.
## Лес на позиции цели скрывает её от выстрела на дистанции > 1
## (каноповое укрытие) — вплотную стрелять можно.
static func can_target_ranged(state: BattleState, atk_cell: Vector2i, target: BattleState.BattleUnit) -> bool:
	if target == null or not target.is_alive():
		return false
	var dist := HexUtils.hex_distance(atk_cell, target.cell, state.hex_shift_right)
	if dist <= 1:
		return false
	if dist > GameNumbersBattle.RANGED_MAX_RANGE:
		return false
	if not has_line_of_sight(state, atk_cell, target.cell):
		return false
	# Листва: цель в лесу не видна для выстрела на дистанции > 1.
	if state.get_terrain_at(target.cell) == BattleTerrain.FOREST and dist > 1:
		return false
	return true
