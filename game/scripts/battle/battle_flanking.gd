class_name BattleFlanking
extends RefCounted

## Фланговые и тыловые атаки (tactical-combat-implementation, фаза 5).
## Геометрия: у юнита есть направление (facing = передняя клетка).
## FRONT — клетка направления; REAR — противоположная; FLANK — четыре
## боковых соседа. Тыл: +50% крита и игнор 50% защиты цели.
## Фланг: +25% крита.

enum Position { FRONT, FLANK, REAR }


## Классифицирует позицию атакующего относительно направления цели.
static func classify(
	_state: BattleState,
	attacker: BattleState.BattleUnit,
	defender: BattleState.BattleUnit
) -> int:
	if defender == null or attacker == null:
		return Position.FRONT
	var facing: Vector2i = defender.facing
	if facing == Vector2i(-1, -1):
		return Position.FRONT
	var dir: Vector2i = facing - defender.cell
	# Нормализация: facing может быть клеткой на 2+ гекса (старые сейвы/баги).
	if dir != Vector2i.ZERO:
		dir = _normalize_hex_dir(dir, _state.hex_shift_right)
	var front_cell: Vector2i = defender.cell + dir
	var rear_cell: Vector2i = defender.cell - dir
	if attacker.cell == front_cell:
		return Position.FRONT
	if attacker.cell == rear_cell:
		return Position.REAR
	for nb in HexUtils.get_all_neighbors(defender.cell, _state.hex_shift_right):
		if nb != front_cell and nb != rear_cell and nb == attacker.cell:
			return Position.FLANK
	return Position.FRONT


## Бонус к шансу крита (к GameNumbersBattle.LUCK_CHANCE).
static func luck_bonus(position: int) -> float:
	match position:
		Position.REAR:
			return GameNumbersBattle.REAR_CRIT_BONUS
		Position.FLANK:
			return GameNumbersBattle.FLANK_CRIT_BONUS
		_:
			return 0.0


## Доля игнорируемой защиты цели (только тыл).
static func defense_ignore(position: int) -> float:
	return GameNumbersBattle.REAR_DEF_IGNORE if position == Position.REAR else 0.0


## Сжимает вектор до ближайшей гекс-оси (одного из 6 направлений).
static func _normalize_hex_dir(dir: Vector2i, shift_right: bool) -> Vector2i:
	var best_dir := dir
	var best_dist := 999999
	for nb in HexUtils.get_all_neighbors(Vector2i.ZERO, shift_right):
		var d := HexUtils.hex_distance(nb, dir, shift_right)
		if d < best_dist:
			best_dist = d
			best_dir = nb
	return best_dir
