class_name WorkerAssignment
extends RefCounted
## Спринт 7: Назначение рабочих на здания с цепочками производства.
##
## Рабочий = PopUnit.State.WORKER. Назначение — PopUnit.assigned_to
## (uid здания) + UniqueBuilding.assigned_workers (счётчик). Назначение
## не требует клетки (рабочий здания != рабочий тайла legacy-контура).
##
## rebalance() вызывается CityTurnProcessor каждый ход:
##  1. рабочих со сломанными ссылками (здание удалено) освобождаем;
##  2. заполняем недостачу зданий (required_workers - assigned_workers).
## Переназначение существующих рабочих не делается (стабильность):
## если рабочее место высвободилось, его займёт свободный рабочий.

## Назначить свободных рабочих на все здания с цепочками.
## Возвращает число новых назначений.
static func assign_all(city: City) -> int:
	if city == null:
		return 0
	var assigned := 0
	for bld in city.buildings:
		if bld == null or bld.def == null:
			continue
		var chain: ProductionChain = bld.get_production_chain()
		if chain == null or chain.required_workers <= 0:
			continue
		var need: int = chain.required_workers - bld.assigned_workers
		if need <= 0:
			continue
		for u in city.pop:
			if need <= 0:
				break
			if u.state != PopUnit.State.WORKER:
				continue
			if u.assigned_to != -1:
				continue
			if u.pending_state != -1:
				continue  # уже переключается — ждём применения
			u.assigned_to = bld.uid
			bld.assigned_workers += 1
			need -= 1
			assigned += 1
	if assigned > 0:
		city.population_changed.emit()
	return assigned


## Освободить рабочих со сломанными ссылками. Возвращает число.
static func release_orphans(city: City) -> int:
	if city == null:
		return 0
	var valid: Dictionary = {}
	for bld in city.buildings:
		if bld != null:
			valid[bld.uid] = true
	var freed := 0
	for u in city.pop:
		if u.assigned_to != -1 and not valid.has(u.assigned_to):
			u.assigned_to = -1
			freed += 1
	if freed > 0:
		city.population_changed.emit()
	return freed


## Освободить всех рабочих конкретного здания (разрушение/снос).
static func release_building(city: City, building_uid: int) -> int:
	if city == null:
		return 0
	var freed := 0
	for u in city.pop:
		if u.assigned_to == building_uid:
			u.assigned_to = -1
			freed += 1
	for bld in city.buildings:
		if bld != null and bld.uid == building_uid:
			bld.assigned_workers = 0
	if freed > 0:
		city.population_changed.emit()
	return freed


## Полный ребаланс: osphans -> assign_all. Возвращает новых назначений.
static func rebalance(city: City) -> int:
	if city == null:
		return 0
	release_orphans(city)
	return assign_all(city)
