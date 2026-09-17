extends RefCounted
## Продвинутые механики + Prestige (фаза 6). Д2/Д6.

const B = preload("res://scripts/data/settlement_buildings.gd")
const Num = preload("res://scripts/constants/GameNumbersSettlement.gd")

# 6.4 Prestige 1–10: const-таблица модификаторов
const PRESTIGE: Dictionary = {
	1: {"reputation_goal_bonus": 4},
	2: {"storm_season_extra_turns": 2},
	5: {"low_resolve_leave_multiplier": 2},
	6: {"building_cost_multiplier": 1.5},
	7: {"double_food_chance": 0.5},
	8: {"double_luxury_chance": 0.5},
	9: {"glade_work_slowdown": 0.33},
	10: {"trade_goods_discount": 0.5},
}

static func prestige_modifiers(level: int) -> Dictionary:
	return PRESTIGE.get(level, {})

static func reputation_goal(prestige: int) -> int:
	var m: Dictionary = prestige_modifiers(prestige)
	return Num.REPUTATION_GOAL + int(m.get("reputation_goal_bonus", 0))

# 6.1 Улучшения домов: 2 уровня, выбор 1 из 2 бонусов
const HOUSE_UPGRADES: Dictionary = {
	1: [
		{"id": "speed", "desc": "+15% скорость"},
		{"id": "resolve", "desc": "+1 Resolve за резидента"},
	],
	2: [
		{"id": "capacity", "desc": "+1 место"},
		{"id": "resolve2", "desc": "+2 Resolve за резидента"},
	],
}

static func house_capacity(b: Dictionary, upgrades: Dictionary) -> int:
	var cap := int(B.by_id(b["type"]).get("capacity", 0))
	for lvl in upgrades:
		if upgrades[lvl] == "capacity":
			cap += 1
	return cap

# 6.2 Unified (SC L6): меньше бонус, чем специализированный сервис
const UNIFIED_SERVICE_BONUS: float = 2.0  # против BONUS_SERVICE 4

# 6.3 Trading Post: товары -> Amber
const TRADE_RATES: Dictionary = {
	"planks": 2, "bricks": 2, "cloth": 3, "coats": 5, "ale": 2,
}

static func trade(settle, goods: Dictionary, prestige: int = 0) -> int:
	# goods: {ресурс: кол-во} -> Amber. Prestige 10: товары на 50% дешевле
	# (продавец даёт меньше) — для игрока это минус.
	var post: Array = settle.buildings_of("trading_post")
	if post.is_empty():
		return 0
	var amber := 0
	for g in goods:
		var amount := int(goods[g])
		if amount <= 0:
			continue
		if not settle.take_resource(g, float(amount)):
			continue
		amber += amount * int(TRADE_RATES.get(g, 1))
	var m: Dictionary = prestige_modifiers(prestige)
	if float(m.get("trade_goods_discount", 0.0)) > 0.0:
		amber = int(float(amber) * (1.0 - float(m["trade_goods_discount"])))
	settle.add_resource("amber", float(amber))
	return amber

# 6.3 Small Warehouse: локальный склад у производства (ускоряет перенос)
# ponytail: эффект = флаг в data, без модели пути — упрощение
static func has_small_warehouse(settle, cell: Vector2i) -> bool:
	for b in settle.buildings_of("small_warehouse"):
		if b["cell"] == cell:
			return true
	return false

# 6.3 Rainpunk: двигатель в здании бустит Resolve работников
const RAINDRINK_RESOLVE: float = 2.0
static func rainpunk_bonus(settle, b: Dictionary) -> float:
	if bool(b["data"].get("rainpunk", false)):
		return RAINDRINK_RESOLVE
	return 0.0
