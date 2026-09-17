extends RefCounted
class_name QuestTemplates

const HeroFactions = preload("res://scripts/data/hero_factions.gd")
## quests-reputation-system: шаблоны процедурных квестов.
## Типы: kill, gather, deliver, escort. Сложность по кольцу (1–3).
## Кольцо 1 — простые (животные, базовые ресурсы), кольцо 3 — эпические.

const RING_TARGETS := {
	1: ["wolf", "boar", "bandit"],
	2: ["goblin", "ogre", "raider"],
	3: ["dragon_whelp", "warlord", "abomination"],
}

const RING_RESOURCES := {
	1: ["herb", "wood", "ore"],
	2: ["quartz", "silver", "herb"],
	3: ["turquoise", "ancient_relic", "dragon_scale"],
}

## Награды по кольцу: {xp, gold, reputation}
const RING_REWARDS := {
	1: {"xp": 20, "gold": 15, "reputation": 10},
	2: {"xp": 50, "gold": 40, "reputation": 20},
	3: {"xp": 120, "gold": 100, "reputation": 30},
}

## Целевые значения по кольцу (kill/gather — количество)
const RING_TARGET_COUNT := {1: 3, 2: 5, 3: 8}

## Таймер квеста в днях по кольцу
const RING_DEADLINE := {1: 10, 2: 15, 3: 25}

const QUEST_TYPES := ["kill", "gather", "deliver", "escort"]

## Генерация одного квеста.
## faction_id — фракция-заказчик (из HeroFactions), ring — кольцо 1..3,
## rng — генератор (для детерминизма в тестах).
## Возвращает Dictionary: {id, type, title, faction_id, ring, target, target_count, deadline, reward, next_quest_id}
static func generate(id: String, faction_id: String, ring: int, rng: RandomNumberGenerator) -> Dictionary:
	ring = clampi(ring, 1, 3)
	var qtype: String = QUEST_TYPES[rng.randi_range(0, QUEST_TYPES.size() - 1)]
	var target := ""
	var target_count: int = int(RING_TARGET_COUNT[ring])
	match qtype:
		"kill":
			var targets: Array = RING_TARGETS[ring]
			target = str(targets[rng.randi_range(0, targets.size() - 1)])
		"gather":
			var resources: Array = RING_RESOURCES[ring]
			target = str(resources[rng.randi_range(0, resources.size() - 1)])
		"deliver":
			target = "scroll"
			target_count = 1
		"escort":
			target = "messenger"
			target_count = 1
	var reward: Dictionary = RING_REWARDS[ring].duplicate(true)
	return {
		"id": id,
		"type": qtype,
		"title": _title(qtype, target, target_count, faction_id),
		"faction_id": faction_id,
		"ring": ring,
		"target": target,
		"target_count": target_count,
		"deadline": RING_DEADLINE[ring],
		"reward": reward,
		"next_quest_id": "",
	}

static func _title(qtype: String, target: String, count: int, faction_id: String) -> String:
	match qtype:
		"kill": return "Убить %d: %s" % [count, target]
		"gather": return "Собрать %d: %s" % [count, target]
		"deliver": return "Доставить свиток (%s)" % HeroFactions.faction_name(faction_id)
		"escort": return "Эскорт гонца (%s)" % HeroFactions.faction_name(faction_id)
	return target
