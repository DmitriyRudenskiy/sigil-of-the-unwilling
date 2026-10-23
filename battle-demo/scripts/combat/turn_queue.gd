class_name TurnQueue extends RefCounted

## Порядок ходов: инициатива по убыванию. При равенстве — сначала сторона
## игрока, затем по позиции в линии. Сортировка полна, поэтому результат
## определён одним составом бою и не зависит от порядка входа в массив.


static func order(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var sorted := units.duplicate()
	sorted.sort_custom(_compare)
	return sorted


static func _compare(a: BattleUnit, b: BattleUnit) -> bool:
	if a.stats.initiative != b.stats.initiative:
		return a.stats.initiative > b.stats.initiative
	if a.side != b.side:
		return a.side == BattleUnit.SIDE_PLAYER
	return a.slot < b.slot
