class_name CityBalance
extends RefCounted
## Все константы баланса населения и градостроительства. Единая точка настройки.

# --- Потребление еды (ед./ход на фигурку) ---
const FOOD_PER_WORKER := 1.0
const FOOD_PER_MILITIA := 1.0
const FOOD_PER_FOLLOWER := 0.0  # Допущение №2: ТЗ упоминает потребление только рабочих и ополченцев.

# --- Естественный прирост: Порог = 5 × N^2.75, N = рабочие + последователи ---
const GROWTH_THRESHOLD_BASE := 5.0
const GROWTH_THRESHOLD_EXP := 2.75

# --- Циклический приток (каждые CITY_CYCLE_TURNS ходов, только в столицу) ---
const CITY_CYCLE_TURNS := 7
const INFLOW_BASE := 2.0
const INFLOW_PER_TEMPLE_LEVEL := 2.0
const INFLOW_GLORY_DIVISOR := 50.0
const INFLOW_SUMMER_MOD := 1.0
const INFLOW_WINTER_MOD := 0.5
const INFLOW_SPRING_AUTUMN_MOD := 1.0  # Допущение №3.

# --- Лимит населения по уровню крепости (индекс = уровень - 1) ---
const POP_CAP_BY_STRONGHOLD := [10, 20, 35]

# --- Районы ---
const BOROUGH_BASE_COST := 20.0
const BOROUGH_COST_STEP := 10.0        # каждый следующий район дороже
const BOROUGH_POP_RATIO_DEFAULT := 2.0 # 1 район на 2 населения
const BOROUGH_POP_RATIO_WIDE := 1.0    # Некрофаги и Аллайи: 1 на 1
const BOROUGH_LEVELUP_NEIGHBORS := 4   # окружение районами того же уровня
const BOROUGH_MAX_LEVEL := 3
## Нетто-одобрение за район уровня 1/2/3 (L2 = -10 база +15 бонус = +5, по ТЗ).
const APPROVAL_NET_PER_BOROUGH_LEVEL := [-10, 5, 15]

# --- Уникальные здания ---
const BUILDING_MAX_LEVEL := 3
const BUILDING_MAX_BUILD_DISTANCE := 3  # от центра города или района

# --- Безопасность / голод ---
const SAFETY_PER_PATROL_MILITIA := 5
const STARVING_APPROVAL_PENALTY := 10
