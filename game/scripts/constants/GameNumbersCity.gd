class_name GameNumbersCity
extends RefCounted

const HEX_SIZE                   := 26.0  # гекс арены города, px (CityArenaView)
const CITY_CYCLE_TURNS          := 7
const INFLOW_BASE               := 2.0
const INFLOW_PER_TEMPLE         := 2.0
const INFLOW_GLORY_DIVISOR      := 50.0
const INFLOW_SUMMER_MOD         := 1.0
const INFLOW_WINTER_MOD         := 0.5
const INFLOW_SPRING_AUTUMN_MOD  := 1.0
const GROWTH_THRESHOLD_BASE     := 5.0
const GROWTH_THRESHOLD_EXP      := 2.75
const FOOD_PER_WORKER           := 1.0
const FOOD_PER_MILITIA          := 1.0
const FOOD_PER_FOLLOWER         := 0.0
const FOOD_PER_SCHOLAR          := 0.5
const BASE_SETTLEMENT_HOUSING   := 10
const BOROUGH_BASE_COST         := 20.0
const BOROUGH_COST_STEP         := 10.0
const BOROUGH_POP_RATIO_DEFAULT := 2.0
const BOROUGH_POP_RATIO_WIDE    := 1.0
const BOROUGH_LEVELUP_NEIGHBORS := 4
const BOROUGH_MAX_LEVEL         := 3
const BUILDING_MAX_LEVEL        := 3
const BUILDING_MAX_DIST_BASE    := 3
const SAFETY_PER_PATROL         := 5
const STARVING_APPROVAL_PENALTY := 10
const REP_MIN                   := -100
const REP_MAX                   := 100
const REP_BAND_GOLDEN_AGE       := 80
const REP_BAND_PROSPERITY       := 30
const REP_BAND_DISCONTENT       := -30
const REP_BAND_CRISIS           := -70
const REP_FOOD_SURPLUS          := 1
const REP_STARVING              := -5
const REP_OVERPOP_PER           := -2
const REP_VICTORY               := 10
const REP_DISASTER              := -10
const MIGRATE_IN_AT             := 30
const MIGRATE_OUT_AT            := -30
const MIGRATE_CRISIS_AT         := -70
const MIGRATE_IN_PER_TURN       := 1
const MIGRATE_CRISIS_PER_TURN   := 2
const ROYALTY_FRACTION          := 0.25
const POP_CAP_BY_STRONGHOLD     := [10, 20, 35]
const APPROVAL_NET_PER_BOROUGH_LEVEL := [-10, 5, 15]
const PROSPERITY_BASE           := 50.0
const PROSPERITY_MAX            := 100.0
const PROSPERITY_FOOD_BONUS     := 10.0
const PROSPERITY_GOLD_REQ       := 10.0
const PROSPERITY_BLD_PER        := 2.0
const PROSPERITY_BLD_CAP        := 20.0
const PROSPERITY_POP_BONUS      := 10.0
const PROSPERITY_POP_RATIO      := 0.75
const PROSPERITY_GOLD_PER_PT    := 0.05
const PROSPERITY_LEVEL_REQ      := 60.0
const PROSPERITY_LEVEL_POP_BASE := 12
const PROSPERITY_LEVEL_POP_STEP := 8
const PROSPERITY_LEVEL_BLD_PER  := 2
const PROSPERITY_MAX_RADIUS     := 5
const CITY_LEVEL_MAX            := 5
const CITY_LEVEL_MIN            := 1
const PROSPERITY_MIN            := 0.0
const PROSPERITY_GOLD_BONUS     := 10.0
const PROSPERITY_REP_HIGH       := 60.0
const PROSPERITY_REP_LOW        := 20.0
const VILLAGE_START_WORKERS     := 4
const VILLAGE_START_FOLLOWERS   := 2
const VILLAGE_START_INDUSTRY    := 30.0
const VILLAGE_START_GOLD        := 5.0
const VILLAGE_START_FOOD        := 10.0
const RAID_CHANCE_BASE          := 0.10
const RAID_CHANCE_MIN           := 0.02
const RAID_CHANCE_MAX           := 0.30
const RAID_REP_DIVISOR          := 500.0
const RAID_DEF_PER_MILITIA      := 2
const RAID_DEF_PER_WALL         := 5
const RAID_STRENGTH_MIN         := 5
const RAID_STRENGTH_SPAN        := 11
const RAID_REP_RELIEF           := 5
const RAID_REP_LOSS             := -10
const RAID_PILLAGE_FRACTION     := 0.30
const MARKET_DEFAULT_RATE       := 2.0
const MARKET_MIN_AMOUNT         := 1.0
const ZONE_INDUSTRIAL_MIN_DIST  := 2
const ZONE_AGGLOMERATION_COUNT  := 2
const ZONE_AGGLOMERATION_BONUS  := 0.10
const ZONE_COMMERCIAL_MARKET    := 0.10
const ZONE_INDUSTRIAL_ROAD      := 0.10
const ZONE_MAX_MULT             := 1.5
const LOGISTICS_DIST_FALLOFF    := 0.15
const LOGISTICS_MIN_MULT        := 0.25
const LOGISTICS_MAX_MULT        := 1.0
const LOGISTICS_ROAD_BONUS      := 0.15
const LOGISTICS_ROAD_MAX        := 1.5
const SCALE_TIERS               := [4, 14, 29]
const SCALE_STORAGE_MULT        := [1.0, 1.25, 1.5, 2.0]
const SCALE_AUTO_MULT           := [1.0, 1.1, 1.2, 1.4]
const SCALE_UPKEEP_MULT         := [1.0, 0.95, 0.9, 0.85]
const DEMO_CRITICAL_THRESHOLD   := 0.2
const DEMO_DEATH_STREAK         := 3
const DEMO_OUTBREAK_COOLDOWN    := 5
const DEMO_MAX_TRAITS           := 3
const ARENA_RADIUS              := 5
const ARENA_CLUSTER_MIN         := 4
const ARENA_CLUSTER_MULT        := 1.5
const ARENA_CLUSTER_HOUSING     := 2
const ARENA_FEATURE_CHANCE      := 0.13
const ARENA_FEATURE_QUARRY      := 1.5
const ARENA_FEATURE_SPRING      := 1.5
const ARENA_FEATURE_RIVER       := 1.25
const ARENA_FEATURE_RUINS_GOLD  := 15.0
const ARENA_STORM_PERIOD        := 6
const ARENA_STORM_PROD_MULT     := 0.75
const ARENA_STORM_MITIG_MULT    := 0.875
const ARENA_STORM_FOOD          := 2.0
const ARENA_STORM_MITIG_FOOD    := 1.0
const RING_YIELD: Array = [
	[0.00, 0.00, 0.00, 0.00, 0.00],
	[3.00, 6.00, 0.00, 0.00, 0.00],
	[3.50, 6.00, 0.00, 0.00, 0.50],
	[4.00, 6.00, 0.50, 1.00, 1.00],
	[6.00, 6.00, 1.00, 0.50, 1.00],
	[2.00, 1.00, 1.50, 1.00, 1.50],
]
const RING_BONUS: Dictionary = {
	&"farm": { 1: 0.00, 2: 0.00, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"mill": { 1: 0.15, 2: 0.00, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"bakery": { 1: 0.00, 2: 0.10, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"mine": { 1: 0.00, 2: 0.15, 3: 0.20, 4: 0.00, 5: 0.00 },
	&"smithy": { 1: 0.00, 2: 0.20, 3: 0.25, 4: 0.00, 5: 0.00 },
	&"tavern": { 1: 0.00, 2: 0.10, 3: 0.15, 4: 0.00, 5: 0.00 },
	&"trade_post": { 1: 0.00, 2: 0.15, 3: 0.20, 4: 0.00, 5: 0.00 },
	&"school": { 1: 0.10, 2: 0.00, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"market": { 1: 0.00, 2: 0.20, 3: 0.10, 4: 0.00, 5: 0.00 },
	&"shack": { 1: 0.00, 2: 0.10, 3: 0.00, 4: 0.00, 5: 0.00 },
	&"walls": { 1: 0.00, 2: 0.00, 3: 0.10, 4: 0.25, 5: 0.00 },
}

static func ring_yield(ring: int, table: Array = RING_YIELD) -> Dictionary:
	if ring < 1 or ring > ARENA_RADIUS:
		return {}
	var row: Array = table[ring]
	return {
		&"food": float(row[0]),
		&"industry": float(row[1]),
		&"dust": float(row[2]),
		&"science": float(row[3]),
		&"influence": float(row[4]),
	}

static func ring_bonus(def_id: StringName, ring: int, table: Dictionary = RING_BONUS) -> float:
	if not table.has(def_id):
		return 0.0
	var row: Dictionary = table[def_id]
	return float(row.get(ring, 0.0))
