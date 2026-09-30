class_name LoadCalculator
extends RefCounted
## attribute-weight-system: единый источник правил веса/переноски.
## Все системы (рюкзак, добыча, движение, отдых, UI) спрашивают его,
## чтобы не дублировать формулы. ponytail: чистые статик-функции, без
## состояния; upgrade: сюда же таблица по defense, если калибровка
# покажет непропорциональность.

## Допустимый вес рюкзака от выносливости (defense).
static func carry_cap(defense: float) -> float:
	return GameNumbersHero.WEIGHT_BASE_CAP + defense * GameNumbersHero.WEIGHT_PER_DEFENSE

## Занятый вес ресурсного рюкзака: сумма units * weight_per_unit.
static func resources_weight(resources: Dictionary, resource_registry: Node) -> float:
	var w := 0.0
	for id in resources:
		var def: ResourceDef = resource_registry.get_resource(StringName(id))
		if def == null:
			continue
		w += float(int(resources[id])) * def.weight_per_unit
	return w

## Свободное место в единицах ресурса при текущем занятом весе.
static func fit_units(def: ResourceDef, current_weight: float, cap: float) -> int:
	if def == null or def.weight_per_unit <= 0.0:
		return 0
	return int(floorf(maxf(0.0, cap - current_weight) / def.weight_per_unit))

## Занятый вес экипировки (надето + рюкзак артефактов).
static func equipment_weight(inventory: HeroInventory) -> float:
	var w := 0.0
	if inventory == null:
		return w
	for slot in inventory.equipped:
		var art: Artifact = inventory.equipped[slot]
		if art != null:
			w += art.weight
	for art in inventory.backpack:
		w += art.weight
	return w

## Доля перегруза экипировки (0.0 = в норме, 1.0 = +100%).
static func overload_fraction(inventory: HeroInventory, defense: float) -> float:
	var cap := carry_cap(defense)
	if cap <= 0.0:
		return 0.0
	return maxf(0.0, (equipment_weight(inventory) - cap) / cap)

## Штраф MP за ход при перегрузе (0..OVERLOAD_MP_PENALTY_MAX).
static func overload_mp_penalty(fraction: float) -> float:
	return clampf(fraction, 0.0, 1.0) * GameNumbersHero.OVERLOAD_MP_PENALTY_MAX

## Доп. спад REST за ход при перегрузе (0..OVERLOAD_REST_PENALTY_MAX).
static func overload_rest_penalty(fraction: float) -> float:
	return clampf(fraction, 0.0, 1.0) * GameNumbersHero.OVERLOAD_REST_PENALTY_MAX
