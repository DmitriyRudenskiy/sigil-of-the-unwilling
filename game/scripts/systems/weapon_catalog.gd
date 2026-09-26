class_name WeaponCatalog
extends RefCounted
## social-stats-weapon-tech D4: 5 тиров оружия — материалы (вес/прочность/урон) и изделия.
## Материалы: дерево 1.0, камень/железо 2.0, сталь 1.8, редкое/легенда 2.5.

const MATERIALS := {
	1: {"name": "Дерево/камень", "material": "wood", "weight": 1.0, "durability": 1, "damage": 4},
	2: {"name": "Железо", "material": "bog_iron", "weight": 2.0, "durability": 2, "damage": 6},
	3: {"name": "Сталь", "material": "steel", "weight": 1.8, "durability": 3, "damage": 8},
	4: {"name": "Редкое", "material": "rare", "weight": 2.5, "durability": 4, "damage": 10},
	5: {"name": "Легенда", "material": "legendary", "weight": 2.5, "durability": 5, "damage": 13},
}

# item_id -> {tier, display_name, two_handed, gold, description}
# weight/damage берутся из MATERIALS[tier] (единый источник)
const ITEMS := {
	"club": {"tier": 1, "display_name": "Дубина", "two_handed": false, "gold": 5,
		"description": "Простая палка. Верная, как смерть."},
	"stone_axe": {"tier": 1, "display_name": "Каменный топор", "two_handed": true, "gold": 8,
		"description": "Окаменевшее терпение."},
	"iron_sword": {"tier": 2, "display_name": "Железный меч", "two_handed": false, "gold": 20,
		"description": "Первый настоящий клинок."},
	"steel_longsword": {"tier": 3, "display_name": "Стальной длинный меч", "two_handed": true, "gold": 45,
		"description": "Тяжёлая сталь тяжёлых решений."},
	"runic_blade": {"tier": 4, "display_name": "Рунный клинок", "two_handed": false, "gold": 90,
		"description": "Руны шепчут о будущем враге."},
	"rune_sword": {"tier": 5, "display_name": "Рун. меч", "two_handed": false, "gold": 160,
		"description": "Легенда, которую можно воткнуть в кого-нибудь."},
}

static func best_item(tier: int) -> String:
	var best := ""
	var best_tier := 0
	for id in ITEMS:
		var t: int = int(ITEMS[id]["tier"])
		if t == tier and t > best_tier:
			best = str(id)
			best_tier = t
	return best

static func item_weight(item_id: String) -> float:
	var item: Dictionary = ITEMS.get(item_id, {})
	if item.is_empty():
		return 0.0
	return float(MATERIALS[int(item["tier"])]["weight"])

static func item_damage(item_id: String) -> int:
	var item: Dictionary = ITEMS.get(item_id, {})
	if item.is_empty():
		return 0
	return int(MATERIALS[int(item["tier"])]["damage"])

static func item_durability(item_id: String) -> int:
	var item: Dictionary = ITEMS.get(item_id, {})
	if item.is_empty():
		return 1
	return int(MATERIALS[int(item["tier"])]["durability"])
