# Система городов

Город — узел производства, роста и обороны на карте мира.

**Модель:** `world/City.gd` (`class_name City`). Это **чистая модель без узлов
Godot** — UI подписывается на сигналы (тот же паттерн, что и `BattleState`).
Управление — через `world/CityManager.gd`.

## Модель города (`City`)

Основные поля состояния:

| Поле | Тип | Значение |
| --- | --- | --- |
| `center` | `Vector2i` | Клетка центра |
| `pop` | `Array[PopUnit]` | Население (фигурки) |
| `boroughs` | `Array[Borough]` | Районы (растут от населения) |
| `buildings` | `Array[UniqueBuilding]` | Уникальные здания |
| `special_sites` | `Dictionary` | Спец. площадки региона (`Vector2i -> StringName`) |
| `food_stockpile` | `float` | Запас еды |
| `storage` | `Dictionary` | `StringName -> float`: industry, gold, dust, science, influence |
| `reputation` | `int` | −100…+100 (ReputationSystem.band) |
| `prosperity` | `float` | 0…100 (ProsperitySystem) |
| `level` | `int` | 1…5 |
| `specialization` | `StringName` | С 2-го уровня (SpecializationSystem) |

### Население (`PopUnit`)

Состояния (`enum State`): **WORKER, FOLLOWER, MILITIA, SCHOLAR**.
- Рабочие и последователи учитываются в лимите крепости; ополченцы — нет.
- Рабочий закреплен за клеткой (`tile`); можно переключить состояние
  (`request_switch`) — вступает в силу в начале следующего хода.
- Ополченец может встать на патрулирование (`patrol`) — плюс безопасность.
- `garrison_size()` — все ополченцы при осаде автоматически формируют гарнизон
  (WorldController собирает из них стеки для осадного боя).

### Урожайность

`tile_yield_fn: Callable(cell) -> {food, industry, dust, science, influence}` —
провайдер урожайности тайлов (инжектируется `CityManager.set_tile_yield_provider`).
`get_yield()` суммирует эксплуатированные клетки (+ множитель специализации agrarian
к еде).

## Ход города (`process_turn`)

Вызывается `CityManager.on_turn_ended(month)` **раз в ход**. Порядок:

1. **Переключения фигурок** (`apply_pending`) — применяются отложенные смены состояний.
2. **Еда:** `net_food() = yield.food − food_consumption()`. Запас пополняется,
   `starving = net_food < 0`.
3. **Рождения:** пока `pop_capped < pop_cap()` и `food_stockpile >= growth_threshold()`,
   тратится порог и рождается последователь. `growth_threshold = 5 × N^2.75`
   (N = рабочие + последователи).
4. **Уровни районов** (`BoroughRules.process_level_ups`) — могут дать соседям 4-го уровня.
5. **Склад:** industry/dust/science/influence накапливаются (расход на строительство).

## Районы и здания

- **Район** (`build_borough`) — примыкает к городу/району, лимит «1 район на N
  населения» (`BoroughRules.pop_ratio`), расходует industry.
- **Здание** (`build_building`) — уникальное, из `UniqueBuilding.Def`. Требует
  площадку (`requires_site`) или дистанцию от города, тратит требования уровня,
  назначает последователей (`_assign_followers`), копирует production_chain/
  upkeep/зону из определения.

`approval()` = сумма `net_approval()` районов − штраф за голод.

## Управление в мире (`CityManager`)

- `cities: Array[City]`, `capital: City`, `glory: GloryTracker`, `current_turn`.
- `on_turn_ended(month)`: обрабатывает все города, затем **каждые
  `CITY_CYCLE_TURNS`** — циклический приток последователей в столицу
  (`capital_inflow = floor(База × Слава × Сезон)`). Переполнение столицы —
  статус-сообщение о распределении.
- `apply_reputation`, `set_capital`, `register_city`, сигналы (`city_updated`,
  `cycle_completed`, `reputation_changed`, `relocation_completed`).

## Подсистемы (`city/`)

| Подсистема | Назначение |
| --- | --- |
| `ProsperitySystem` | Процветание (0…100) и уровень города (1…5) |
| `ReputationSystem` | Репутация (−100…+100) и миграция, `band()` |
| `SpecializationSystem` | Специализации с 2-го уровня (бонусы, напр. food_yield) |
| `ScaleShiftManager` | Рост масштабами: селение → деревня → … |
| `ZoningSystem` | Зонирование: правила размещения зон и множитель |
| `CityTurnProcessor` | M3: фаза города (приоритет 5 — первая среди каскадных фаз) |
| `LogisticsCalculator` | Затухание эффективности по дистанции + бонус дороги |
| `AdjacencySystem` | Матрица adjacency-бонусов (Спринт 8) |
| `MarketSystem` | Спринт 10: торговля запасами на золото |
| `RaidSystem` | Спринт 10: шансы города стать целью рейда варваров |
| `CityEvents` | Спринт 11: детерминированные события от (uid, turn) |
| `CityArenaModel` / `ArenaBalance` | Строительная арена — hex-карта с кольцами и приростами ресурсов |

## Тесты

`tests/test_city_systems.gd`, `test_city_arena.gd`, `test_city_housing.gd`,
`test_city_processor.gd`, `test_city_events_relocation.gd`, `test_city_chains.gd`,
`test_city_manager.gd`, `test_city_reputation.gd`, `test_capacity.gd`,
`tests/unit/test_city_system.gd`.
