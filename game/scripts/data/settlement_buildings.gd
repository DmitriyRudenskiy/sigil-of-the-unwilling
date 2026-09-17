extends RefCounted
## Здания поселения (2.x прототипа, D8: const-таблицы 1:1).

# cost: {ресурс: кол-во}; capacity — жильё; small — малые узлы
const BUILDINGS: Dictionary = {
	# стартовые (2.1)
	"hearth": {"capacity": 0, "cost": {}},
	"warehouse": {"capacity": 0, "cost": {}},
	# лагеря (2.2)
	"woodcutters_camp": {"capacity": 0, "cost": {"wood": 2}, "small": false},
	"stonecutters_camp": {"capacity": 0, "cost": {"wood": 2}, "small": false},
	"harvesters_camp": {"capacity": 0, "cost": {"wood": 2}, "small": false},
	"small_foragers_camp": {"capacity": 0, "cost": {"wood": 1}, "small": true},
	"small_herbalists_camp": {"capacity": 0, "cost": {"wood": 1}, "small": true, "unlock_level": 2},
	# производство (2.3): 1 рецепт за раз
	"lumber_mill": {"capacity": 0, "cost": {"wood": 4}, "recipes": ["planks"]},
	"bakery": {"capacity": 0, "cost": {"wood": 4}, "recipes": ["complex_food"]},
	"granary": {"capacity": 0, "cost": {"wood": 4}, "recipes": ["complex_food"]},
	"crude_workstation": {"capacity": 0, "cost": {"wood": 2}, "recipes": ["planks", "bricks", "cloth"]},
	"cooperage": {"capacity": 0, "cost": {"wood": 4}, "recipes": ["coats", "ale"], "species": "harpy"},
	"tinctury": {"capacity": 0, "cost": {"wood": 4}, "recipes": ["ale", "complex_food"], "species": "beaver"},
	# жильё (2.4)
	"shelter": {"capacity": 3, "cost": {"wood": 3}},
	"big_shelter": {"capacity": 3, "cost": {"wood": 5}, "unlock": "ancient_knowledge"},
	"human_house": {"capacity": 2, "cost": {"planks": 4, "bricks": 2}, "species": "human", "unlock": "vs1"},
	"beaver_house": {"capacity": 2, "cost": {"planks": 8}, "species": "beaver", "unlock": "vs2"},
	"lizard_house": {"capacity": 2, "cost": {"cloth": 2, "bricks": 2}, "species": "lizard", "unlock": "vs3"},
	"harpy_house": {"capacity": 2, "cost": {"cloth": 4}, "species": "harpy", "unlock": "vs4"},
	"fox_house": {"capacity": 2, "cost": {"planks": 4, "cloth": 2}, "species": "fox", "unlock": "vs6"},
	"frog_house": {"capacity": 2, "cost": {"planks": 6}, "species": "frog", "unlock": "sc9"},
	"bat_house": {"capacity": 2, "cost": {"planks": 6}, "species": "bat", "unlock": "sc11"},
	# сервис
	"tavern": {"capacity": 0, "cost": {"planks": 4}},
	# фаза 6
	"unified": {"capacity": 0, "cost": {"planks": 8}, "unlock": "sc6"},
	"small_warehouse": {"capacity": 0, "cost": {"wood": 3}},
	"trading_post": {"capacity": 0, "cost": {"planks": 6}},
}

# рецепты производства: {ресурс: кол-во} -> {ресурс: кол-во}
const RECIPES: Dictionary = {
	"planks": {"input": {"wood": 2}, "output": {"planks": 2}},
	"bricks": {"input": {"stone": 2}, "output": {"bricks": 2}},
	"cloth": {"input": {"fiber": 2}, "output": {"cloth": 1}},
	"complex_food": {"input": {"food": 2}, "output": {"complex_food": 1}},
	"coats": {"input": {"cloth": 2}, "output": {"coats": 1}},
	"ale": {"input": {"food": 2}, "output": {"ale": 2}},
}

# hearth: уровень за дома/декор в радиусе (4.2)
const HEARTH_LEVEL2_HOUSES: int = 2
const HEARTH_LEVEL3_HOUSES: int = 4
const HEARTH_RADIUS: int = 3

static func by_id(id: String) -> Dictionary:
	return BUILDINGS.get(id, {})

static func is_housing(id: String) -> bool:
	var b: Dictionary = by_id(id)
	return int(b.get("capacity", 0)) > 0

static func is_production(id: String) -> bool:
	return by_id(id).get("recipes", []).size() > 0
