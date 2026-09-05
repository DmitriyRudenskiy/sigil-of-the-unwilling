## scripts/core/MapConfig.gd
## Константы карты мира/героя/ресурсов (аудит #16: вынесено из GameSettings).
class_name MapConfig
extends RefCounted

## Centralized constants so magic numbers live in one place.
# --- Hero / Inventory ---
const MAX_BACKPACK_SIZE := 16

## Максимум юнитов, которыми герой может командовать на карте/в бою.
const MAX_HERO_ARMY_SIZE := 7

const HERO_BASE_SPEED := 120.0  # pixels/sec on world map

const HERO_DAILY_MOVEMENT := 10.0  # float, ОД в день

const HERO_RETREAT_LOSS_FRACTION := 0.5

const HERO_LEVEL_UP_EXP := 100

# Artifact movement bonuses (new scale):
#   polar_boots: +3, wayfarer_ring: +2
const HERO_BASE_MANA := 20

const HERO_MANA_TICK := 1

# --- Chest / Loot ---
const CHEST_GOLD_MIN := 30

const CHEST_GOLD_MAX := 80  # CHEST_GOLD_MIN + 50

const CHEST_COUNT := 5

const CHEST_PLACE_ATTEMPTS := 2000

const MONSTER_DROP_CHANCE := 0.05

# --- Map ---
const MAP_SIZE_MIN := 40

const MAP_SIZE_MAX := 70

const MAP_VILLAGE_COUNT := 8

const MAP_RESOURCE_COUNT := 25

## Размер «кольца запрета» (в гексах) вокруг каждого размещённого ресурса —
## задаёт равномерность распределения: ресурсы не стоят кучно и не оставляют
## пустых карманов (Poisson-like). Рассчитывается как map_size / DIVISOR, чтобы
## равномерность не зависела от размера карты. Настроено свепом по размерам
## 50–70 (DIVISOR = 6, clamp[MIN, MAX]): CV≈0.5, 25/25 ресурсов размещено.
const MAP_RESOURCE_SPACING_DIVISOR := 6.0

const MAP_RESOURCE_SPACING_MIN := 5

const MAP_RESOURCE_SPACING_MAX := 13

const MAP_ENEMY_COUNT := 20

const MAP_ENEMY_DEFENSE_BONUS_MIN := 2

const MAP_ENEMY_DEFENSE_BONUS_MAX := 6

# enemy-world-ai: параметры ИИ вражеских стеков.
const ENEMY_AGGRO_RADIUS := 8

# fog-of-war: радиус обзора (в гексах) у героя и у городов (odd-r диск).
const FOG_HERO_SIGHT := 3

const FOG_CITY_SIGHT := 4

const ENEMY_MP := 5.0

const ENEMY_RESPAWN_TURNS := 6

# --- World ---
const EDITOR_SEED := 12345

# --- Weather (M5, TurnContext.weather) ---
const WEATHER_CLEAR := 0

const WEATHER_RAIN := 1

const WEATHER_SNOW := 2

const WEATHER_STORM := 3

# --- Resource Chains ---
const RESOURCE_CAPACITY := 10  # max units per resource type

const RESOURCE_NODE_CHANCE := 0.08  # per-cell hidden node chance

const RESOURCE_AUTO_WOOD_PER_DAY := 2

const RESOURCE_AUTO_STONE_PER_DAY := 2

const SALTPETER_EXPLOSION_DMG_MULT := 2.0  # double damage to adjacent

const RESOURCE_NODE_REMOVAL_DAYS := 3  # days after exhaustion before removal

const TOOL_INVENTORY_SLOTS := 8

# --- World Spawner ---
const SPAWN_RESOURCE_NODE_CHANCE := 0.08

const SPAWN_DECOR_SAND_CHANCE := 0.04

const SPAWN_SCROLL_MAX_ATTEMPTS := 200

const SPAWN_CHEST_MIN_BORDER := 3

const SPAWN_ENEMY_MIN_BORDER := 3
