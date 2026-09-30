class_name ExtractRules
extends RefCounted
## attribute-weight-system: правила добычи узлов от характеристик.
## Сила (attack) — скорость/усталость; внимательность (knowledge) —
## улов и скрытые узлы. Один источник, его зовут ResourceNodeManager
## и UI. ponytail: ступенчатые правила (не формулы) — upgrade path:
# плавные шкалы, если баланс захочет тоньше.

## REST-штраф за добычу: базовый 0.05, при высокой силе −50%.
static func rest_cost(attack: int) -> float:
	var base := 0.05
	if attack >= GameNumbersHero.EXTRACT_REST_REDUCE_MIN_ATTACK:
		base *= 0.5
	return base

## Бонус к улову от силы (до 1 единицы).
static func yield_bonus(attack: int) -> int:
	return 1 if attack >= GameNumbersHero.EXTRACT_YIELD_BONUS_ATTACK else 0

## Базовый улов с узла: [yield_min, yield_max] + бонус силы.
static func base_yield(def: ResourceDef, attack: int) -> int:
	if def == null:
		return 0
	return maxi(def.yield_min, def.yield_max) + yield_bonus(attack)

## Шанс обнаружить скрытый узел: база + внимательность (уровень 2+).
static func hidden_chance(knowledge: int) -> float:
	var chance := GameNumbersHero.HIDDEN_NODE_CHANCE_BASE
	if knowledge >= 2:
		chance += GameNumbersHero.HIDDEN_NODE_KNOWLEDGE_BONUS
	return chance
