class_name AdjacencySystem
extends RefCounted
## Спринт 8: Матрица adjacency-бонусов города.
##
## Два вида эффектов:
##  1. Производственный (building_output_mult) — множитель выходов
##     цепочки здания по соседним зданиям:
##       мельница у 2+ полей  -> x1.5
##       кузница у рудника    -> x3.0  (концепт: "+2 к выходу" при базе 1)
##  2. Репутационный (reputation_bonus) — суммарная дельта репутации
##     за ход:
##       храм/таверна у жилья -> +2 за здание
##       особняк у рудника    -> -2 за здание
##
## Соседство — 6 hex-клеток (HexUtils.get_all_neighbors).
## Статика, без нод Godot.

## "def_id" -> {сосед-предикат: {count, output_mult}}.
## Предикаты: StringName def_id соседа либо &"housing" (любой
## жилой объект, Спринт 7).
const OUTPUT_MATRIX: Dictionary = {
	&"mill": {
		&"farm": {"count": 2, "output_mult": 1.5},
	},
	&"smithy": {
		&"mine": {"count": 1, "output_mult": 3.0},
	},
}

## "def_id" -> {сосед-предикат: {count, rep}}.
const REPUTATION_MATRIX: Dictionary = {
	&"great_temple": {
		&"housing": {"count": 1, "rep": 2},
	},
	&"tavern": {
		&"housing": {"count": 1, "rep": 2},
	},
	&"manor": {
		&"mine": {"count": 1, "rep": -2},
	},
}


## Жилой ли объект (имеет хотя бы один слот жилья).
static func is_housing(def: UniqueBuilding.Def) -> bool:
	if def == null:
		return false
	for k in def.housing:
		if int(def.housing[k]) > 0:
			return true
	return false


## Число соседей на клетках, удовлетворяющих предикату (def_id или
## &"housing").
static func _neighbor_count(city: City, cell: Vector2i, predicate: StringName) -> int:
	var n := 0
	for nb in HexUtils.get_all_neighbors(cell):
		var b := city.get_building_at(nb)
		if b == null or b.def == null:
			continue
		if predicate == &"housing":
			if is_housing(b.def):
				n += 1
		elif b.def.id == predicate:
			n += 1
	return n


## Множитель выходов цепочки здания (1.0 = без бонусов).
static func building_output_mult(city: City, building: UniqueBuilding) -> float:
	if city == null or building == null or building.def == null:
		return 1.0
	var row: Dictionary = OUTPUT_MATRIX.get(building.def.id, {})
	if row.is_empty():
		return 1.0
	var mult := 1.0
	for predicate in row:
		var rule: Dictionary = row[predicate]
		if _neighbor_count(city, building.cell, StringName(predicate)) >= int(rule.count):
			mult *= float(rule.output_mult)
	return mult


## Суммарный репутационный бонус города за ход.
static func reputation_bonus(city: City) -> int:
	if city == null:
		return 0
	var total := 0
	for building in city.buildings:
		if building == null or building.def == null:
			continue
		var row: Dictionary = REPUTATION_MATRIX.get(building.def.id, {})
		if row.is_empty():
			continue
		for predicate in row:
			var rule: Dictionary = row[predicate]
			if _neighbor_count(city, building.cell, StringName(predicate)) >= int(rule.count):
				total += int(rule.rep)
	return total
