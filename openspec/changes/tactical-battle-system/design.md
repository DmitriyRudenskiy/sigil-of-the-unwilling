# Design: tactical-battle-system

## Technical Approach

### Архитектура компонентов

```
┌─────────────────────────────────────────────────────────────┐
│                    BattleController.gd                       │
│  (оркестрация: начало боя, фазы, переходы, завершение)       │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐   ┌────────────────┐   ┌──────────────┐
│ BattleState  │   │ BattleTurnExec │   │  BattleAI    │
│ (состояние:  │   │ (очередность:  │   │ (решения ИИ: │
│  юниты,гексы)│   │  инициатива,   │   │  приоритеты, │
│              │   │  партии)       │   │  укрытия)    │
└──────────────┘   └────────────────┘   └──────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐   ┌────────────────┐   ┌──────────────┐
│BattleAction  │   │BattleDamage    │   │  BattleView  │
│Resolver      │   │Resolver        │   │  (UI, сетка, │
│ (действия:   │   │ (урон: формулы,│   │   спрайты)   │
│  атака,закл.)│   │  бонусы)       │   │              │
└──────────────┘   └────────────────┘   └──────────────┘
```

### Размер поля и сетка

- **BATTLE_BOARD_W = 17** (константа в `BattleController.gd` или `GameNumbersBattle`)
- Высота адаптируется: `ceil(max(player_units, enemy_units) / 3) + 2`
- Гексы: координаты (q, r) в axial coordinate system
- Визуализация: `BattleView.gd` отрисовывает гексагональную сетку

#### Расхождение: ориентация линий размещения (task 1.3)

Спецификация (scenario «Размещение при начале боя») описывает стороны как «игрок снизу, враг сверху». Реализация (`BattleStateBuilder._build_units`) размещает стороны на противоположных **левом/правом** краях: атакующие — столбец 0, защитники — столбец `BW-1`, column-major вниз. Ключевые требования спеки выполнены: противоположные края, дистанция между линиями ≥ 5 гексов (на 17-широком поле — 16), запрет перезаписи гекса (`_cell_taken`), запрет выхода за границы. Ориентация left/right вместо bottom/top — осознанное отклонение: это существующее поведение, покрытое тестами `test_deployment_line_at_edge` / `test_deployment_max_capacity`; смена на bottom/top ломала бы боевую систему и её тесты без выигрыша по требованиям спеки.

### Инициатива и порядок ходов

**Реализовано (task 3.1, 3.2):** порядок ходов — **партийный** (`BattleState.build_queue`):
каждый раунд сначала действует **вся партия** одной стороны, затем вся партия другой.
Сторона с более высокой **верхней инициативой** (макс. `speed` среди живых юнитов
стороны) ходит первой; внутри партии юниты действуют по убыванию `speed`, затем HP,
затем `uid`. `is_player_turn = (active_unit.side == ATTACKER)`, поэтому в партийном
режиме весь ход игрока — contiguous-блок (до этого очередь была глобально
отсортирована по скорости — interleaved).

**Расхождение: формула инициативы (task 3.1).** Спека описывает
`initiative = agility + class_modifier + race_modifier + d20`. Боевые юниты
(`BattleUnit`) — архетипы с плоской характеристикой `stats.speed`; у них нет класса/
расы/ловкости как отдельных полей, а `d20`-бросок противоречит требованию
детерминизма по seed (task 3.4). Поэтому инициатива = `stats.speed` (через
`BattleUnit.get_speed()`), без случайного компонента. Классовые/расовые модификаторы
и d20 — осознанное отклонение: для их введения нужны соответствующие поля на
`BattleUnit`/`UnitDef` и отказ от строгой детерминизации.

Тесты: `test_initiative_party_order`, `test_initiative_higher_side_goes_first`,
`test_initiative_deterministic_by_seed` (test_battle_state.gd).

### Действия в бою

```gdscript
enum CombatAction {
    MELEE_ATTACK,      # Требует соседства
    RANGED_ATTACK,     # Требует линии видимости
    CAST_SPELL,        # Требует маны, знания заклинания
    WAIT,              # Бонус защиты +20%, контратака
    RETREAT            # Попытка выхода за край поля
}
```

**Атака ближнего боя:**
- Условие: дистанция ≤ 1 гекс
- Урон: `max(1, (attack - defense) * terrain_mod * flank_mod * crit_mod)`
- Crit: базовый шанс 10% + фланг/тыл бонусы

**Атака дальнего боя:**
- Условие: линия видимости (raycast между центрами гексов)
- Штраф дистанции: `-5% урона за гекс сверх 3`
- Препятствия: лес/холм блокируют видимость (если нет зрения сквозь)

**Ожидание:**
- Эффект: `defense *= 1.2` до следующего хода
- Контратака: если враг входит в соседний гекс, автоматическая атака без расхода действия

#### Расхождения с реализацией (Phase 4)

**Дальний бой (task 4.3) — DEFERRED.** Реализовано: дальнобойный юнит бьёт на
distance > 1 (гейт в `BattleAttackSequence`/`BattleInput`/`BattleAI`), при дистанции 1
применяется `RANGED_MELEE_PENALTY = 0.5` (штраф за ближний бой). НЕ реализовано из спеки:
линия видимости (raycast), штраф за дальность («−5% за гекс сверх 3»), max range и
«препятствия блокируют видимость». Причина: LoS/препятствия требуют типов местности
(Phase 5, ещё не реализована), а штраф за дальность опционален по спеке («если
применимо») и живёт в `BattleRules.gd` (вне мандата «приведения кода» — там
BattleController/BattleAI/BattleTurnExecutor). Реализовать вместе с Phase 5.

**Ожидание (task 4.4) — реализовано под другими именами.** Спека: «ожидание → +20%
защиты + контратака». В коде это два механизма: `do_defend` → `defending = true` →
`DEFEND_DEFENSE_BONUS = 1.2` (ровно +20% защиты, `BattleRules.damage_multiplier`) +
retaliation-система (`BattleAttackSequence.can_retaliate`/`start_retaliation`: melee-
защитник бьёт в ответ, 1/раунд). Отдельный `do_wait` = «задержка» (перенос хода в конец
очереди раунда), не «оборонительное ожидание». Тесты: `test_damage_multiplier_defending_boosts_defense`,
`test_calculate_attack_ranged_melee_penalty`, `test_first_strike_triggers`, `test_wait_order`.

### Бонусы местности

| Тип | Защита | Атака | Движение | Видимость |
|-----|--------|-------|----------|-----------|
| Равнина | 0% | 0% | 100% | Полная |
| Лес | +30% | 0% | −20% | Ограничена (1 гекс) |
| Холм | +50% | +20% (вниз) | −30% | Полная |
| Укрепление | +75% | 0% | −50% | Полная |
| Вода | N/A | N/A | Блокирует | Полная |

Реализация (Phase 5, `BattleTerrain.gd` + `BattleState` + `BattleDamageResolver`):

- **Источник местности** — вариант 1 (подтверждён пользователем): генерация из seed боя, а не с карты. Самодостаточно, детерминировано, не трогает стратегический слой (ограничение proposal).
- **`BattleTerrain.gd`** (новый, `class_name` + `preload` в ссылках): enum `TerrainType {PLAIN, FOREST, HILL, FORT, WATER}`; таблицы защиты `1.0/1.3/1.5/1.75/1.0`, высоты `0/0/1/1/0`, скорости `1.0/0.6/0.7/0.5/0.0`; `DOWNHILL_ATTACK_MULT = 1.2`; `is_blocking()` = только вода.
- **Генератор** `generate(rng, bw, bh, density=0.1)`: Fisher–Yates, пропускает колонки развёртки (`x≤0`, `x≥BW-1`), взвешенно 45% лес / 25% холм / 15% укрепление / 15% вода (вода редкая, чтобы не резать поле). Плотность 0.1 → ~16 клеток на 17×11.
- **Seed**: `_generate_terrain()` в `BattleController.start_battle` переиспользует `_obstacle_seed` отдельным экземпляром RNG (не смешивает поток с препятствиями). Вызывается после `_place_obstacles()`, до `place_army`.
- **Урон**: `BattleRules.damage_multiplier` и `calculate_attack` расширены параметрами `terrain_atk_mult`, `terrain_def_mult` (int→float арифметика, `absi`→`absf`; при =1.0 математика идентична старой). `BattleDamageResolver` считает `terrain_def_mult` по гексу защитника и `terrain_atk_mult=1.2` если высота атакующего > высоты защитника.
- **Вода блокирует движение**: `BattleState.build_all_blocked` добавляет блокирующие клетки из `terrain_grid`.

Расхождения/отложено:
- **Снижение скорости по местности** (−20/−30/−50%) — DEFERRED: BFS (`HexPathfinding.bfs_reachable`) использует единый радиус, без стоимости на клетку. `speed_multiplier()` уже в `BattleTerrain` для будущего использования.
- **Preview-функция** (`calculate_attack` → String) не имеет доступа к state/местности → оставляет дефолты 1.0 (косметический gap в превью-тексте).
- **`BattleView` (5.2)** — DEFERRED (UI, не верифицируется headless); данные для рендера уже в `BattleState.terrain_grid`.

### Фланговые атаки

Определение направления:
- Каждый юнит имеет `facing_direction` (гекс "лицом")
- Фронт: гекс направления + соседние 2
- Фланг: 2 боковых гекса (±60° от фронта)
- Тыл: 3 гекса сзади (180° ± 60°)

Бонусы:
- Фланг: `crit_chance += 0.25`, `shield_bonus_ignored = true`
- Тыл: `crit_chance += 0.50`, `enemy_defense *= 0.5`

Реализация (Phase 6, `BattleState` + `BattleRules` + `BattleDamageResolver`):
- `BattleUnit.facing` — бит соседства 0..5 (0=E, 1=NE, 2=NW, 3=W, 4=SW, 5=SE;
  бит = угол/60° против часовой). Ставится в `place_army`: attacker→0 (east, к
  противнику), defender→3 (west, к противнику). **Статическое** направление:
  обновление при движении/атаке отложено — статика уже даёт рабочую модель
  фронт/фланг/тыл.
- `BattleState.attack_aspect(attacker_cell, defender) -> int`: находит бит
  соседства атакующего относительно цели (`_neighbor_bit`), считает
  `diff = (bit - facing) mod 6` (с нормализацией в 0..5) → 0=фронт, 1/5=фланг
  (±60°), 2/3/4=тыл; -1 если атакующий не сосед.
- **Разрешение расхождения спеки**: спека даёт фронт=3, фланг=2, тыл=3 (сумма 8
  > 6 соседей). Реализация по работоспособным бонусам: фронт=1 (без бонуса),
  фланг=2 (±60°), тыл=3 (±120°..180°) — совпадает по числу бонусных гексов.
- Крит: в `BattleRules.calculate_attack` добавлен параметр `flank_aspect` (по
  умолчанию -1). Фланг → `crit_chance=FLANK_CRIT_CHANCE_FLANK (0.25)`; тыл →
  `crit_chance=FLANK_CRIT_CHANCE_REAR (0.50)` **и** `REAR_DEFENSE_MULT (0.5)`
  складывается в `terrain_def_mult` (→ выше множитель урона). Крит-рос после
  luck-рос: при `rng.randf() < crit_chance` урон ×`FLANK_CRIT_MULTIPLIER (2.0)`,
  в результат добавляется `"crit": bool`.
- Интеграция: `BattleDamageResolver.resolve` вычисляет `state.attack_aspect(...)`
  и передаёт в `calculate_attack`. Фланк/тыл — только для **ближней** атаки по
  соседнему гексу (позиционная модель); дальний фланк отложен.
- «Игнор щита» — **N/A**: систем щитов в боевом ядре нет (grep пуст).
- Константы в `GameNumbersBattle` (реэкспорт в `GameNumbers`):
  `FLANK_CRIT_CHANCE_FLANK=0.25`, `FLANK_CRIT_CHANCE_REAR=0.50`,
  `REAR_DEFENSE_MULT=0.5`, `FLANK_CRIT_MULTIPLIER=2.0`.
- Тесты: `tests/unit/systems/test_battle_flanking.gd` (12).

### ИИ-доктрина

Приоритет целей (score越高优先):
```python
threat_score = unit.attack * unit.health_pct * distance_factor
wounded_score = (1.0 - unit.health_pct) * 2.0 if unit.health_pct < 0.3 else 0
ranged_score = unit.is_ranged * 1.5

final_score = threat_score + wounded_score + ranged_score
```

Поведение:
1. Выбор цели: макс. score среди видимых врагов
2. Позиционирование: если под огнём → движение в укрытие
3. Атака: если цель в досягаемости → атака, иначе → движение к цели
4. Отступление: если `army_health_pct < 0.3` → путь к ближайшему краю

Агрессивность:
- Животные: `aggression = 1.5` (игнорируют потери, всегда атакуют)
- Гуманоиды: `aggression = 1.0` (баланс атаки/защиты)
- Монстры: `aggression = 0.5` (медленные, но мощные; игнорируют малые потери)

Реализация (Phase 7, `BattleAI.gd`):
- `_pick_target` + `_score_target`: `score = threat + wounded + ranged`, где `threat = attack * health_pct * (1.0 / max(1, dist))`, `wounded = WOUNDED_BONUS * (1.0 - health_pct)` при `health_pct < WOUNDED_THRESHOLD`, `ranged = RANGED_BONUS`. Максимальный score выигрывает; при равенстве — ближе. С одним врагом возвращается именно он (совпадает со старым «ближайший»).
- `_pick_landing_cell`: по умолчанию `path[steps]` (ближе всех к цели). Под огнём (`_is_under_fire` — есть живой дальний враг) сканирует `path[1..steps-1]` и берёт гекс с бóльшим `defense_multiplier`, только если строго лучше (не жертвует подходом к цели).
- Отступление: `_should_retreat` (`_army_health_pct < RETREAT_ARMY_PCT`, health = `sum(count)/sum(max_count)` по стороне) + `_try_retreat` (BFS к ближайшему краю из 4 кандидатов, `MOVE` вдоль пути).
- `_aggression` по тегам юнита: `beast|animal|wild` → 1.5, `monster|undead|dragon|elemental` → 0.5, иначе 1.0 (гуманоид).
- **Ключевое решение**: отступают ТОЛЬКО гуманоиды (`aggression == AGGR_HUMANOID`). Дикие животные и монстры не отступают — оба типа держатся (spec: «дикие животные — агрессивны, монстры — игнорируют потери»). Проверка `_should_retreat`: `if _aggression(unit) != AGGR_HUMANOID: return false`.
- Константы в `BattleAI.gd`: `RETREAT_ARMY_PCT=0.3`, `WOUNDED_THRESHOLD=0.3`, `WOUNDED_BONUS=2.0`, `RANGED_BONUS=1.5`, `AGGR_ANIMAL=1.5`, `AGGR_HUMANOID=1.0`, `AGGR_MONSTER=0.5`.
- Тесты: `tests/unit/systems/test_battle_ai_doctrine.gd` (5 тестов). Полный свит 1806 тестов, 0 ошибок/падений.

### Исход боя

**Победа:**
- Все юниты противника: `health <= 0` ИЛИ `retreated = true`
- Награды: `xp = sum(enemy_level * 10)`, `loot = drop_table.roll()`

**Отступление:**
- Условие: свободный гекс на краю поля (не занят врагом)
- Эффект: юнит помечается `retreated = true`, удаляется с поля
- Последствия: бой проигран, но юнит выживает

**Ранение героя:**
- При поражении: `hero.wounded = true`, `hero.wounded_turns = 3`
- Эффект: `hero.stats *= 0.7` пока `wounded = true`
- Снятие: после боя или отдых 3 хода

## Data Structures

### BattleState

```gdscript
class BattleState:
    var board_width: int = 17
    var board_height: int
    var units: Array[Unit]  # Все юниты
    var hex_map: Dictionary  # (q,r) → Unit|null
    var current_turn: int
    var turn_order: Array[Unit]  # Сортировано по инициативе
    var current_party: Party  # PLAYER или ENEMY
    var terrain: HexMap  # Типы гексов
```

### Unit

```gdscript
class Unit:
    var id: String
    var unit_type: String
    var health: int
    var max_health: int
    var attack: int
    var defense: int
    var agility: int
    var initiative: int
    var is_player: bool
    var position: Vector2i  # (q, r)
    var facing_direction: Vector2i
    var actions_remaining: int
    var status_effects: Array[StatusEffect]
```

## Migration Plan

1. **Фаза 1**: Спецификация и анализ расхождений (tasks 1.x)
2. **Фаза 2**: Тактическая сетка и инициатива (tasks 2.x, 3.x)
3. **Фаза 3**: Боевые действия и бонусы (tasks 4.x, 5.x, 6.x)
4. **Фаза 4**: ИИ и исход боя (tasks 7.x, 8.x)
5. **Фаза 5**: Интеграция и регрессия (tasks 9.x, 10.x)

## Risks & Mitigations

| Риск | Вероятность | Влияние | Митигация |
|------|-------------|---------|-----------|
| Расхождение кода и spec | Высокая | Среднее | Поэтапная сверка, тесты на каждое требование |
| Производительность (гексы, ИИ) | Средняя | Низкое | Оптимизация raycast, кэширование путей |
| Баланс бонусов | Высокая | Высокое | MCP-прогонка, калибровка констант |
| Сложность UI | Средняя | Среднее | Простая подсветка, постепенное добавление |

## Testing Strategy

- **Unit-тесты**: каждое требование spec → отдельный тест
- **Интеграционные**: полные бои с проверкой исхода
- **MCP-проба**: автопроход ранней игры с боями (seed 20260913)
- **Визуальная**: ручная проверка отображения сетки, бонусов, направлений

## Constants (GameNumbersBattle)

```gdscript
BATTLE_BOARD_W = 17
INITIATIVE_DICE = 20
WAIT_DEFENSE_BONUS = 1.2
FLANK_CRIT_BONUS = 0.25
BACK_CRIT_BONUS = 0.50
BACK_DEFENSE_PENALTY = 0.5
TERRAIN_FOREST_DEFENSE = 0.30
TERRAIN_HILL_DEFENSE = 0.50
TERRAIN_FORT_DEFENSE = 0.75
RETREAT_HEALTH_THRESHOLD = 0.30
WOUNDED_STAT_PENALTY = 0.7
WOUNDED_TURNS = 3
```
