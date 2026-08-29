extends RefCounted
class_name GameSettings
## Centralized constants so magic numbers live in one place.

# --- Hero / Inventory ---
const MAX_BACKPACK_SIZE := 16
## Максимум юнитов, которыми герой может командовать на карте/в бою.
const MAX_HERO_ARMY_SIZE := 7
## Максимум юнитов (инициатив) в бою с каждой из сторон.
const BATTLE_MAX_UNITS_PER_SIDE := 7
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

# --- Battle ---
const BATTLE_AI_THINK_TIME := 0.7
const BATTLE_TURN_DELAY := 0.15
const BATTLE_RETREAT_LOSS_FRACTION := 0.5
const BATTLE_DEFEND_BONUS_DEFENSE := 0.20
const BATTLE_SPELL_ANIM_TIME := 0.35
const BATTLE_ATTACK_ANIM_SEC := 0.3
const ASTAR_HEURISTIC_WEIGHT := 1.0  # 1.0 = optimal path, >1.0 = faster but not optimal

# --- Map ---
const MAP_SIZE_MIN := 40
const MAP_SIZE_MAX := 70
const MAP_VILLAGE_COUNT := 8
const MAP_RESOURCE_COUNT := 25
const MAP_ENEMY_COUNT := 20
const MAP_ENEMY_DEFENSE_BONUS_MIN := 2
const MAP_ENEMY_DEFENSE_BONUS_MAX := 6

# --- World ---
const EDITOR_SEED := 12345

# --- Weather (M5, TurnContext.weather) ---
const WEATHER_CLEAR := 0
const WEATHER_RAIN := 1
const WEATHER_SNOW := 2
const WEATHER_STORM := 3

# --- Save/Load ---
const SAVE_MAGIC := "SIG_SAVE"

# --- Camera / Zoom ---
const ZOOM_LEVELS := [0.5, 0.7, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.25]
const ZOOM_DEFAULT_INDEX := 2  # 1.0

# --- Resource Chains ---
const RESOURCE_CAPACITY := 10  # max units per resource type
const RESOURCE_NODE_CHANCE := 0.08  # per-cell hidden node chance
const RESOURCE_AUTO_WOOD_PER_DAY := 2
const RESOURCE_AUTO_STONE_PER_DAY := 2
const SALTPETER_EXPLOSION_DMG_MULT := 2.0  # double damage to adjacent
const RESOURCE_NODE_REMOVAL_DAYS := 3  # days after exhaustion before removal
const TOOL_INVENTORY_SLOTS := 8

# --- Battle magic numbers ---
const STATUS_PROC_CHANCE := 0.20  # petrify / blind
const REBIRTH_CHANCE := 0.20
const CHARGE_MULT := 1.5
const BREATH_DMG_RATIO := 0.5
const RETREAT_STACK_LIMIT := 2
const CLICK_RADIUS_PX := 60.0
const INF := 1e9  # float, compatible with PackedFloat32Array

# --- Battle View ---
const BATTLE_FIELD_RING := 5
const BATTLE_HEX_OUTLINE_RADIUS := 38.0
const BATTLE_ATTACK_LUNGE_PX := 26.0
const BATTLE_MOVE_TWEEN_SEC := 0.15
const BATTLE_FLOATING_TEXT_OFFSET := Vector2(-30, -60)
const BATTLE_DAMAGE_NUMBER_OFFSET := Vector2(-16, -50)

# --- World Spawner ---
const SPAWN_RESOURCE_NODE_CHANCE := 0.08
const SPAWN_DECOR_SAND_CHANCE := 0.04
const SPAWN_SCROLL_MAX_ATTEMPTS := 200
const SPAWN_CHEST_MIN_BORDER := 3
const SPAWN_ENEMY_MIN_BORDER := 3

# --- World Camera ---
const CAMERA_SPEED := 600.0
const CAMERA_EDGE_ZONE := 20
const CAMERA_ZOOM_TWEEN_SEC := 0.175

# --- Main Menu UI ---
const MENU_COL_OFFSET_LEFT := -380
const MENU_COL_OFFSET_RIGHT := -60
const MENU_COL_OFFSET_TOP := 120
const MENU_COL_OFFSET_BOTTOM := -120
const MENU_COL_SEPARATION := 20
const MENU_BTN_MIN_SIZE := Vector2(300, 70)
const MENU_LOCK_MIN_SIZE := Vector2(300, 180)

# --- Adventure UI ---
const ADVENTURE_RIGHT_PANEL_W := 252
const ADVENTURE_INITIATIVE_PANEL_W := 190
const ADVENTURE_BATTLE_STATUS_H := 92
const ADVENTURE_BOTTOM_BAR_OFFSET := -58

# --- City Panel ---
const CITY_PANEL_W := 340.0
const CITY_PANEL_OFFSET := 12.0
const CITY_PANEL_TOP := 40.0
const CITY_PANEL_BOTTOM := -40.0
