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

Реализация: `BattleState.get_hex_terrain(q, r) → TerrainType`

### Фланговые атаки

Определение направления:
- Каждый юнит имеет `facing_direction` (гекс "лицом")
- Фронт: гекс направления + соседние 2
- Фланг: 2 боковых гекса (±60° от фронта)
- Тыл: 3 гекса сзади (180° ± 60°)

Бонусы:
- Фланг: `crit_chance += 0.25`, `shield_bonus_ignored = true`
- Тыл: `crit_chance += 0.50`, `enemy_defense *= 0.5`

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
