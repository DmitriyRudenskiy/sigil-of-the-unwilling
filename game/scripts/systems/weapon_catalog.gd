class_name WeaponCatalog
extends RefCounted
## social-systems-delta D1: 5 этапов оружия — дерево/камень/железо/сталь/редкое-магия.
## (было: 1 Дерево/камень, 2 Железо, 3 Сталь, 4 Редкое, 5 Легенда; легенда слита в 5)

const MATERIALS := {
	1: {"name": "Дерево", "material": "wood", "weight": 1.0, "durability": 1, "damage": 4},
	2: {"name": "Камень", "material": "stone", "weight": 1.5, "durability": 1, "damage": 5},
	3: {"name": "Железо", "material": "bog_iron", "weight": 2.0, "durability": 2, "damage": 6},
	4: {"name": "Сталь", "material": "steel", "weight": 1.8, "durability": 3, "damage": 8},
	5: {"name": "Редкое/магия", "material": "rare", "weight": 2.5, "durability": 5, "damage": 13},
}

# item_id -> {tier, display_name, type, purpose, two_handed, gold, description}
# weight/damage берутся из MATERIALS[tier] (единый источник)
# social-systems-delta D2: ~30 изделий, 6 на этап, типы по ТЗ
const ITEMS := {
	# --- Этап 1: дерево ---
	"club": {"tier": 1, "display_name": "Дубина", "type": "bludgeoning", "purpose": "Самооборона",
		"two_handed": false, "gold": 5, "description": "Простая палка. Верная, как смерть."},
	"pointed_stick": {"tier": 1, "display_name": "Заострённая палка", "type": "piercing", "purpose": "Охота, рыбалка",
		"two_handed": false, "gold": 3, "description": "Первое колющее."},
	"wooden_spear": {"tier": 1, "display_name": "Деревянное копьё", "type": "piercing", "purpose": "Ближний бой",
		"two_handed": true, "gold": 6, "description": "Длина — аргумент."},
	"throwing_stick": {"tier": 1, "display_name": "Метательная палка", "type": "throwing", "purpose": "Охота на мелкую дичь",
		"two_handed": false, "gold": 4, "description": "Летит туда, где был зверь."},
	"simple_bow": {"tier": 1, "display_name": "Простой лук", "type": "ranged", "purpose": "Охота",
		"two_handed": false, "gold": 8, "description": "Изогнутая ветка с натяжением."},
	"wooden_shield": {"tier": 1, "display_name": "Деревянный щит", "type": "defense", "purpose": "Слабая защита",
		"two_handed": false, "gold": 5, "description": "Лучше, чем ничего."},
	# --- Этап 2: дерево + камень ---
	"stone_axe": {"tier": 2, "display_name": "Каменный топор", "type": "slashing", "purpose": "Охота, бой, рубка",
		"two_handed": true, "gold": 8, "description": "Окаменевшее терпение."},
	"stone_hammer": {"tier": 2, "display_name": "Каменный молот", "type": "bludgeoning", "purpose": "Бой, работа",
		"two_handed": true, "gold": 9, "description": "Два в одном: молот и отговорка."},
	"stone_spear": {"tier": 2, "display_name": "Копьё с каменным наконечником", "type": "piercing", "purpose": "Охота и бой",
		"two_handed": true, "gold": 10, "description": "Наконечник требует ремонта."},
	"flint_arrows": {"tier": 2, "display_name": "Стрелы с кремнёвым наконечником", "type": "ranged", "purpose": "Охота и бой",
		"two_handed": false, "gold": 7, "description": "Ломкие, но колют."},
	"sling": {"tier": 2, "display_name": "Праща", "type": "throwing", "purpose": "Лёгкий дальнобойный бой",
		"two_handed": false, "gold": 4, "description": "Наука о параболах."},
	"stone_knife": {"tier": 2, "display_name": "Каменный нож", "type": "slashing", "purpose": "Разделка, самооборона",
		"two_handed": false, "gold": 6, "description": "Острее, чем кажется."},
	# --- Этап 3: железо ---
	"iron_sword": {"tier": 3, "display_name": "Железный меч", "type": "slashing", "purpose": "Основной ближний бой",
		"two_handed": false, "gold": 20, "description": "Первый настоящий клинок."},
	"iron_axe": {"tier": 3, "display_name": "Железный топор", "type": "slashing", "purpose": "Бой и работа",
		"two_handed": true, "gold": 22, "description": "Рубит и дерево, и всё остальное."},
	"iron_spear": {"tier": 3, "display_name": "Железное копьё", "type": "piercing", "purpose": "Строй, охота",
		"two_handed": true, "gold": 18, "description": "Основа строя."},
	"iron_dagger": {"tier": 3, "display_name": "Железный кинжал", "type": "slashing", "purpose": "Ближний бой, засады",
		"two_handed": false, "gold": 15, "description": "Тихий аргумент."},
	"iron_hammer": {"tier": 3, "display_name": "Железный молот", "type": "bludgeoning", "purpose": "Бой против брони",
		"two_handed": true, "gold": 25, "description": "Броня не любит молчание."},
	"iron_arrows": {"tier": 3, "display_name": "Железные стрелы", "type": "ranged", "purpose": "Война",
		"two_handed": false, "gold": 12, "description": "Война на расстоянии."},
	# --- Этап 4: сталь ---
	"steel_longsword": {"tier": 4, "display_name": "Стальной длинный меч", "type": "slashing", "purpose": "Элитный ближний бой",
		"two_handed": true, "gold": 45, "description": "Тяжёлая сталь тяжёлых решений."},
	"halberd": {"tier": 4, "display_name": "Алебарда", "type": "piercing", "purpose": "Бой против кавалерии и брони",
		"two_handed": true, "gold": 50, "description": "Длинная, острая, окончательная."},
	"steel_axe": {"tier": 4, "display_name": "Стальной топор", "type": "slashing", "purpose": "Тяжёлый бой",
		"two_handed": true, "gold": 42, "description": "Сталь, которая не прощает."},
	"crossbow": {"tier": 4, "display_name": "Арбалет", "type": "ranged", "purpose": "Пробитие брони",
		"two_handed": false, "gold": 55, "description": "Механический аргумент."},
	"plate_armor": {"tier": 4, "display_name": "Латы", "type": "defense", "purpose": "Тяжёлая защита",
		"two_handed": false, "gold": 80, "description": "Ходячая крепость."},
	"reinforced_shield": {"tier": 4, "display_name": "Щит с металлической окантовкой", "type": "defense", "purpose": "Защита",
		"two_handed": false, "gold": 40, "description": "Щит, который держит."},
	# --- Этап 5: редкое/магия ---
	"runic_blade": {"tier": 5, "display_name": "Рунный клинок", "type": "slashing", "purpose": "Оружие с особыми эффектами",
		"two_handed": false, "gold": 90, "description": "Руны шепчут о будущем враге."},
	"enchanted_bow": {"tier": 5, "display_name": "Зачарованный лук", "type": "ranged", "purpose": "Магический дальнобойный бой",
		"two_handed": false, "gold": 110, "description": "Стрелы летят туда, куда должны."},
	"magic_staff": {"tier": 5, "display_name": "Магический посох", "type": "slashing", "purpose": "Магия",
		"two_handed": false, "gold": 130, "description": "Дерево, которое отвечает."},
	"unique_artifact": {"tier": 5, "display_name": "Уникальный артефакт", "type": "slashing", "purpose": "Уникальные эффекты",
		"two_handed": false, "gold": 200, "description": "Единственный в своём роде."},
	"rune_sword": {"tier": 5, "display_name": "Рун. меч", "type": "slashing", "purpose": "Легендарный ближний бой",
		"two_handed": false, "gold": 160, "description": "Легенда, которую можно воткнуть в кого-нибудь."},
	"crystal_amulet": {"tier": 5, "display_name": "Кристальный амулет", "type": "defense", "purpose": "Магическая защита",
		"two_handed": false, "gold": 140, "description": "Свет, который не гаснет."},
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
