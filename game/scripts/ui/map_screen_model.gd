class_name MapScreenModel
extends RefCounted

## Экран карты: view model поверх RegionMap (headless-логика, без сцены).
##
## Инвариант 3.3 (≤2 клика до причины, mvp-ui-flow): каждое действие/опция
## возвращает {available, reason} — UI просто показывает reason, если
## available=false. Причина всегда на месте (не «закрыть в никуда»).
##
## Данные — из RegionMap (runtime, movement.json mvp_mask). Модель не мутирует
## состояние карты (только читает + предвычисляет причины).

## Видимые регионы (не в тумане).
static func visible_regions(map: RegionMap) -> Array:
	return map.open_regions.duplicate()

## Регионы в тумане (все из графа минус открытые).
static func fog_regions(map: RegionMap) -> Array:
	var fog: Array = []
	for region in map.regions:
		if not map.open_regions.has(region):
			fog.append(region)
	return fog

## Позиция и состояние героя.
static func hero(map: RegionMap) -> Dictionary:
	return {"region": map.hero_region, "state": map.hero_state}

## Карточка региона для UI: {region, biome, node_type, visible, is_hero, is_start, looted}.
static func region_card(map: RegionMap, region: String) -> Dictionary:
	var node_type: String = map.node_type(region)
	var node_key := "%s:%s" % [region, node_type]
	return {
		"region": region,
		"biome": str(map.biomes.get(region, "")),
		"node_type": node_type,
		"visible": map.open_regions.has(region),
		"is_hero": map.hero_region == region,
		"is_start": region == map.start_region,
		"looted": map.visited_nodes.has(node_key),
	}

## Опции движения: для каждого соседа героя {region, available, days, food_cost, reason}.
## Инвариант 3.3: reason — почему нельзя (если available=false).
static func travel_options(map: RegionMap) -> Array:
	var out: Array = []
	for nb in map.neighbors(map.hero_region):
		var opt := {"region": nb, "available": false, "days": 0, "food_cost": 0.0, "reason": ""}
		if map.hero_state != map.STATE_EXPLORE:
			opt["reason"] = "не в EXPLORE (%s)" % map.hero_state
		elif not map.open_regions.has(nb):
			opt["reason"] = "в тумане"
		else:
			var days := map.entry_days(nb)
			var cost := float(map.party_size) * float(days)
			opt["days"] = days
			opt["food_cost"] = cost
			if cost > map.food + 1e-9:
				opt["reason"] = "мало провизии (%d/%d)" % [int(map.food), int(cost)]
			else:
				opt["available"] = true
		out.append(opt)
	return out

## Доступные действия героя: {action, available, reason}.
static func actions(map: RegionMap) -> Array:
	var out: Array = []
	# Движение (хотя бы один доступный сосед).
	var can_move := false
	for opt in travel_options(map):
		if opt["available"]:
			can_move = true
			break
	out.append({"action": "move", "available": can_move,
		"reason": "" if can_move else "нет доступных соседей"})
	# Посетить узел (герой в регионе с узлом, не выграблен).
	var node_type := map.node_type(map.hero_region)
	var node_key := "%s:%s" % [map.hero_region, node_type]
	var has_node := node_type != ""
	var looted := map.visited_nodes.has(node_key)
	var can_visit := has_node and not looted
	out.append({"action": "visit_node", "available": can_visit,
		"reason": "" if can_visit else ("нет узла" if not has_node else "уже выграблен")})
	# Отступить (из ENGAGE/BATTLE).
	var can_retreat := map.hero_state == map.STATE_ENGAGE or map.hero_state == map.STATE_BATTLE
	out.append({"action": "retreat", "available": can_retreat,
		"reason": "" if can_retreat else "не в бою"})
	# Полевой рейд (не в городе, в EXPLORE).
	var in_city := map.hero_region == map.start_region
	var can_raid := not in_city and map.hero_state == map.STATE_EXPLORE
	out.append({"action": "field_raid", "available": can_raid,
		"reason": "" if can_raid else ("рейд по городу — через город" if in_city else "не в EXPLORE")})
	return out

## Найти действие по id (для UI-обработчика).
static func action_by_id(map: RegionMap, action: String) -> Dictionary:
	for a in actions(map):
		if a["action"] == action:
			return a
	return {"action": action, "available": false, "reason": "нет такого действия"}
