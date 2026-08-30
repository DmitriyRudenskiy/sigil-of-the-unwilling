class_name CityBalance
extends RefCounted
## Все константы баланса населения и градостроительства. Единая точка настройки.

# --- Потребление еды (ед./ход на фигурку) ---
const FOOD_PER_WORKER := 1.0
const FOOD_PER_MILITIA := 1.0
const FOOD_PER_FOLLOWER := 0.0  # Допущение №2: ТЗ упоминает потребление только рабочих и ополченцев.
const FOOD_PER_SCHOLAR := 0.5  # Спринт 6: учёный потребляет половину рациона.

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

# --- Репутация (Спринт 6) ---
## Шкала -100..+100. Диапазоны: +80 Золотой век, +30 Процветание, 0 Норма,
## -30 Недовольство, -70 Кризис, -100 Бунт.
const REP_MIN := -100
const REP_MAX := 100
const REP_BAND_GOLDEN_AGE := 80
const REP_BAND_PROSPERITY := 30
const REP_BAND_DISCONTENT := -30
const REP_BAND_CRISIS := -70

## Факторы хода (ReputationSystem.turn_factor).
const REP_FOOD_SURPLUS := 1      # ед./ход при нетто-еде > 0
const REP_STARVING := -5         # голод в этом ходу
const REP_OVERPOP_PER := -2      # за каждую фигурку сверх лимита
const REP_VICTORY := 10          # победа в сражении (столица)
const REP_DISASTER := -10        # пожар, набег, чума

## Миграция (функция репутации).
const MIGRATE_IN_AT := 30        # отсюда иммиграция (Процветание)
const MIGRATE_OUT_AT := -30      # отсюда эмиграция (Недовольство)
const MIGRATE_CRISIS_AT := -70   # усиленная эмиграция (Кризис)
const MIGRATE_IN_PER_TURN := 1
const MIGRATE_CRISIS_PER_TURN := 2

## Базовое жильё поселения: принимает рабочих без зданий (Спринт 7).
const BASE_SETTLEMENT_HOUSING := 10
