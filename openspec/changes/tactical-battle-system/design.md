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

### Инициатива

Формула: `initiative = agility + class_modifier + race_modifier + d20(roll)`

- `agility`: характеристика ловкости юнита
- `class_modifier`: из `hero_classes.gd` (Воин +2, Следопыт +4, Плут +6, etc.)
- `race_modifier`: из `hero_races.gd` (эльф +2, гном +1, etc.)
- `d20(roll)`: случайный бросок 1d20 для вариативности

Сортировка: по убыванию initiative, разделение на партии (игрок / враг).

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
