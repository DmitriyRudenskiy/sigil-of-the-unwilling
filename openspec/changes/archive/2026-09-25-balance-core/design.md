# Design: balance-core

## Архитектура

Три слоя (по схеме playtesting, слой 3 + часть слоя 2):

```
Python (pytest, tests/mcp/)          GDScript (game)              Данные
┌─────────────────────────┐   MCP   ┌──────────────────────┐   ┌──────────┐
│ test_balance_probe.py   │ ──────► │ BalanceProbeScenario │   │ report_  │
│  - запускает мир        │         │ (tools/mcp/ или      │   │ balance_ │
│  - ждёт отчёт           │ ◄────── │ scenes/Headless-...) │──►│ <seed>.  │
└─────────────────────────┘         │  - автоигрок         │   │ json     │
                                    └──────────────────────┘   └──────────┘
```

## Автоигрок (каanonическая стратегия)

Один GDScript-класс `BalanceProbeScenario` (RefCounted-логика, вызывается через MCP `eval`/`call_method`):

1. **Сбор**: каждый ход герой идёт к ближайшему доступному ресурсному узлу (BFS по `model.resource_cells`), собирает.
2. **Выгрузка**: когда герой в радиусе 1 от города и рюкзак не пуст → CityScreen.unload_pressed().
3. **Стройка**: приоритетный список зданий по ранней игре: barracks → market → farm → range. Каждый ход, если город может построить (CityCheck ок) — строит.
4. **Рекрутка**: когда есть военное здание и серебро хватает — рекрутит.
5. **Бой**: ближайший враг 1-го кольца в пределах reach → герой идёт и атакует (WorldBattleCoordinator запускает бой; бой доигрывается авто-исполнителем как в test_battle_full_e2e: атакуй ближайшего / жди).
6. **Ходы**: EndTurn через WorldEventRouter.request_end_turn().

Ограничение: лимит 60 ходов или «все метрики собраны».

### Выбор транспорта

MCP-команд `eval`/`call_method` достаточно (так работают все существующие e2e-тесты: INIT_CODE-шаблоны). Отдельная MCP-команда «play_turn» не нужна — прогонка это слой тестов, не игровой инструмент.

## Метрики и пороги

| Метрика | Цель | Источник |
|---|---|---|
| first_building_turn | ≤ 5 | CityService.build (первый успешный) |
| first_recruit_turn | ≤ 10 | CityService.recruit_military (первый успешный) |
| first_win_turn_gap | ≤ 3 хода после первого столкновения | WorldBattleCoordinator |
| losses_total | ≤ 1 | idem |
| stuck_max | ≤ 3 хода подряд без события | логгер шагов |
| storm_stall_ratio | ≤ 2.0 vs clear | два прогона с принудительным сезоном |

Сезоны: `WorldSeasons` статический — для замера Буря/Ясного прогонка дважды: reset + advance до нужного сезона (тестовый доступ к статике допустим: это probe, не геймплей).

## Калибруемые константы (кандидаты)

- `GameNumbersHero`: BACKPACK_TOTAL_CAP (12), BACKPACK_CART_BONUS/COST, HERO_PERSONAL_SPEED, combat_hp базовое
- `GameNumbersCity`: PROSPERITY_LEVEL_REQS (55→), POP_BASE/STEP, BLD_PER
- `buildings.json`: industry-стоимости уровней 1–2
- `GameNumbers`: RESOURCE_AUTO_WOOD/STONE, MAP_ENEMY_COUNT

Механики (кольца, сезоны-цикл, техдерево, бой BW=17) не трогаем — только числа.

## Формат отчёта

`game/tools/mcp/reports/balance_<seed>.json`:
```json
{"seed": 42, "turns": 18, "first_building_turn": 4, "first_recruit_turn": 9,
 "first_collision_turn": 6, "first_win_turn": 8, "losses": 0, "stuck_max": 2,
 "snapshots": [{"turn": 5, "city_level": 1, "storage": {...}, "backpack": 0}, ...],
 "warnings": ["first_recruit_turn 9 > 8 (soft)"]}
```
Пороги в конфиге прогона (не хардкод в константы игры).

## Риски

- **Бой через MCP медленный** (каждый ход тик): лимит — 2 боя в прогоне; больше не нужно для ранней калибровки.
- **Автоигрок может застрять** на pathfinding к узлу за водой: каждый шаг имеет max-повторы действия (3) → далее пропускаем действие (счётчик stuck).
- **Статическое состояние WorldSeasons** между тестами: before/after в pytest — reset().

## Альтернативы (отклонены)

- Ручная прогонка (исходный план): не воспроизводимо, нет «до/после» в цифрах.
- Отдельный headless-режим в Godot (без MCP): дублирует MCP-инфраструктуру, которую уже построили и покрыли тестами.
- Метрики как hard-fail тестов: баланс будет «ломать CI» при любом изменении чисел — warning+отчёт вместо этого.
