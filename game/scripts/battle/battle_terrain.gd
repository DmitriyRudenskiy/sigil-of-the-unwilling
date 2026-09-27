class_name BattleTerrain
extends RefCounted

## Battle terrain modifiers (tactical-combat spec: "Бонусы местности").
## Hex types: plain / forest / hill / water / fort.
## - Defense bonus: forest +30%, hill +50%, fort +75%.
## - Movement: water blocks, forest/hill raise the move cost (speed proxy).
## - Hill attack bonus: +20% attack when the attacker stands on a hill and
##   the target does not.
##
## Built on top of TerrainCostTable: world terrain names are mapped onto the
## battle types (world_to_battle) and forest/water costs reuse the table.

const PLAIN := "plain"
const FOREST := "forest"
const HILL := "hill"
const WATER := "water"
const FORT := "fort"

const FOREST_DEFENSE_BONUS := 0.30
const HILL_DEFENSE_BONUS := 0.50
const FORT_DEFENSE_BONUS := 0.75
const HILL_ATTACK_BONUS := 0.20

const _DEFENSE_BONUS: Dictionary = {
	FOREST: FOREST_DEFENSE_BONUS,
	HILL: HILL_DEFENSE_BONUS,
	FORT: FORT_DEFENSE_BONUS,
}

## Move cost per hex (plain = 1.0 baseline). Reuses TerrainCostTable values
## where the names match (forest 1.25, water INF).
const _MOVE_COST: Dictionary = {
	PLAIN: 1.0,
	FOREST: TerrainCostTable.FOREST,
	HILL: 1.25,
	FORT: 1.0,
	WATER: INF,
}

## World terrain (TerrainCostTable names) -> battle terrain type.
const _WORLD_MAP: Dictionary = {
	"grass": PLAIN,
	"road": PLAIN,
	"sand": PLAIN,
	"snow": PLAIN,
	"swamp": FOREST,
	"forest": FOREST,
	"dense_forest": FOREST,
	"mountain": HILL,
	"water": WATER,
	"river": WATER,
}


static func defense_bonus(terrain: String) -> float:
	return float(_DEFENSE_BONUS.get(terrain, 0.0))


static func attack_bonus(terrain: String) -> float:
	return HILL_ATTACK_BONUS if terrain == HILL else 0.0


static func move_cost(terrain: String) -> float:
	return float(_MOVE_COST.get(terrain, 1.0))


static func is_blocked(terrain: String) -> bool:
	return move_cost(terrain) >= INF


static func world_to_battle(terrain: String) -> String:
	return str(_WORLD_MAP.get(terrain, PLAIN))


## True when the map contains any non-plain battle terrain (used to switch
## movement from the cheap BFS fast path to costed Dijkstra).
static func map_has_effects(map: Dictionary) -> bool:
	for c in map:
		var t: String = str(map[c])
		if t != PLAIN:
			return true
	return false
