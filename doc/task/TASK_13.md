# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

## 1. Архитектура

### 1.1. Общая оценка
Проект — тактическая стратегия с боями на гексах, менеджментом городов и «роглайк»-циклом героя. Код разбит на слои: `core`, `data`, `systems`, `world`, `city`, `economy`, `demographics`, `ui`, `entities`, `autoload`, `tests`. Это хорошее разделение, но есть системные проблемы.

### 1.2. Ключевые проблемы

| Проблема | Где | Суть |
|---|---|---|
| **Сервис-локатор** | `Services.resolve(&"units")`, `Services.resolve(&"spells")`, `Services.resolve(&"artifacts")` по всему коду | Скрывает зависимости, усложняет тестирование и рефакторинг. Классы не объявляют зависимости явно. |
| **Глобальное состояние гексов** | `HexGrid.shift_right` (автозагрузка) | Глобальный флаг калибровки. `HexUtils` зависит от него. Невозможно иметь две сетки с разной ориентацией. |
| **Свалка констант** | `GameNumbers` (~250 констант) | Нарушение SRP: камера, бой, город, герой, арена, погода — всё в одном файле. |
| **Данные в коде** | `UnitRegistry` (150+ юнитов), `ArtifactRegistry` (50+ артефактов) | Баланс правится в коде, нет валидации, нельзя редактировать без перекомпиляции. |
| **Толстый координатор боя** | `BattleTurnExecutor` | Машина состояний + ввод + ИИ + анимации + пауза в одном классе (~500 строк). |
| **Ручное переподключение героя** | `HeroLifecycleSystem._install_hero` | Перебирает `battle_coordinator`, `interaction_controller`, `bootstrap_result.enemy_proc`, `ui_manager` и вручную переназначает `.hero`. Хрупко. |
| **Фасад города** | `City` наследует `CityData`, делегирует в `CityService`, `CityBuildingService`, `CityGrowthService`, `CityYieldCalculator` | `City` имеет 40+ методов-делегатов. Сложно понять, где реальная логика. |
| **Передача состояния через глобус** | `WorldPersistence.pending_save`, `pending_new_game` | Состояние передаётся между сценами через мутабельные поля синглтона, а не через параметры. |

### 1.3. Паттерны
- **Компонентная композиция героя** (`HeroController` → `Movement`, `Army`, `Resources`, `Magic`, `Skills`, `Tools`) — хорошо.
- **Шина событий** (`GameEventBus`) — используется для развязки, но часть систем ходит напрямую, минуя её.
- **Стратегия** (`NeedStrategy`, `TraitDef`) — корректно.
- **Шаблонный метод** (`TurnPhaseProcessor` + `TurnScheduler`) — хороший каркас для фаз хода.
- **Отсутствует** чёткий слой домена: `BattleState` — и данные, и логика (`build_queue`, `check_end`, `get_reachable`). Лучше отделить.

---

## 2. Лучшие практики

### 2.1. Идиомы Godot / GDScript

| Проблема | Пример | Рекомендация |
|---|---|---|
| Создание `Node` в полях класса | `HeroController`: `var movement := HeroMovementController.new()` в теле класса | Создавать в `_ready()` или `_init()` явно. Поля-узлы, инициализируемые при загрузке скрипта, могут создаваться до дерева. |
| `class_name` + `preload` | `const _HexUtils = preload("res://scripts/core/hex_utils.gd")` при наличии `class_name HexUtils` | Дублирование. Если есть `class_name`, использовать глобальное имя. Если `preload` — убрать `class_name` или наоборот. |
| Статический доступ к дереву сцены | `TileAtlas.build_hex_tileset()` → `Engine.get_main_loop() as SceneTree` → `tree.root.get_node_or_null("/root/TileAtlasCache")` | Статический метод не должен зависеть от дерева. Кэш должен быть инъектирован или вынесен в автозагрузку. |
| Глобальная калибровка | `HexGrid.calibrate(tile_map)` меняет `HexGrid.shift_right` | Передавать ориентацию в `HexUtils` как параметр или хранить в `TileMapLayer`/`MapModel`. |
| `queue_free()` в тестах | Многие тесты вызывают `.free()` напрямую | Для `RefCounted` ок, для `Node` в дереве — `queue_free()`. В тестах `GdUnit4` лучше использовать `auto_free()`. |
| `await get_tree().create_timer(...)` в логике боя | `BattleTurnExecutor._advance_to_next_turn` | Таймеры в логике затрудняют тестирование. Лучше инкапсулировать в отдельный сервис с возможностью замены. |

### 2.2. SOLID, DRY, KISS

- **SRP**: `GameNumbers`, `BattleTurnExecutor`, `City`, `WorldBootstrap.run()` нарушают.
- **OCP**: добавление нового юнита требует правки `UnitRegistry` в коде, а не конфигурации.
- **DIP**: доменные классы (`BattleDamageResolver`, `SpellCaster`, `FollowerSystem`) зависят от `Services.resolve()` — от абстракции, но через локатор, а не инъекцию.
- **DRY**: `CityService` и `City` дублируют сигнатуры. `_find_city` в `WorldPersistence` и `CityManager.get_city_by_uid` делают одно и то же.
- **KISS**: `SuccessionController.transfer_legend` клонирует города через `serialize/deserialize` вместо прямой передачи ссылок.

### 2.3. Обработка ошибок
- `FileAccess.open` проверяется на `null` в большинстве мест — хорошо.
- `JSON.parse_string` без детальной диагностики в `BuildingDefs._ensure_loaded` — при ошибке молча пустой кэш.
- `ResourceLoader.load` без проверки типа в `TileAtlasCache._build_tileset` — есть `push_error`, ок.
- `Services.resolve()` может вернуть `null` — вызывающие не всегда проверяют (`BattleEmulator.cast_spell` проверяет, `FollowerSystem.recruit` — нет).

---

## 3. Алгоритмы

### 3.1. Используемые структуры и алгоритмы

| Область | Алгоритм | Сложность | Оценка |
|---|---|---|---|
| `HexPathfinding.astar_path` | A* с бинарной кучей (`MinHeap`) | O(E log V) | Корректно. Эвристика `hex_distance * weight` допустима. |
| `HexPathfinding.bfs_path` | BFS | O(V+E) | Ок. |
| `HexPathfinding.dijkstra` | Дейкстра с кучей | O(E log V) | Ок. `max_cost` ограничивает. |
| `HexPathfinding.bfs_reachable` | BFS на глубину `steps` | O(V) в пределах радиуса | Ок. |
| `MinHeap` | Бинарная куча на массиве | O(log n) | Корректна, но сравнивает только по `item[0]`. Нет вторичного ключа. |
| `HexUtils.offset_to_cube` / `cube_to_offset` | Кубические координаты | O(1) | Корректно при верном `shift_right`. |
| `BattleState.get_reachable_for_unit` | BFS + кэш по сигнатуре | O(V) на запрос | Кэш хорош, но сигнатура — хэш, возможны коллизии. |
| `ArenaClusterSystem._compute_clusters` | BFS по связным компонентам | O(N) | Кэш через `city.meta` + `_city_version`. |
| `VisibilityMap._fill_disk` | Обход колец `HexUtils.ring` | O(r²) | Ок для радиуса 3–4. |
| `EnemyTurnProcessor.process` | Дейкстра по карте для поля героя | O(E log V) на ход | Один раз на процесс, ок. |

### 3.2. Граничные случаи и риски

1. **Кэш достижимости по хэшу** (`BattleState._cache_signature`):
   ```gdscript
   var h := 0
   for cell in blocked:
       var p := cell as Vector2i
       h = (h * 31 + p.x * 73856093) & 0x7FFFFFFF
       h = (h * 31 + p.y * 19349663) & 0x7FFFFFFF
   return (_board_version + 1) * 1000003 + h
   ```
   Хэш может дать коллизию для разных наборов `blocked`. Если сигнатура совпадёт, кэш вернёт неверную достижимость. **Риск высокий** в бою с большим числом юнитов.

2. **`MinHeap` без вторичного ключа**: при равных приоритетах порядок нестабилен. Для A* это не ломает корректность, но может менять путь между запусками при одинаковом `seed` и разной реализации кучи. В тестах это может давать нестабильность.

3. **`HexGrid.shift_right` глобален**: если в одном процессе две сцены с разными `TileMapLayer` (бой + мир), калибровка одной перезапишет другую. В проекте `BattleView` и `MapGenerator` вызывают `HexGrid.calibrate`.

4. **`EnemyTurnProcessor._rebuild_hero_dist_field`** строит полную Дейкстру от героя. Если герой не задан или карта большая — дорого. Есть `_hero_dist_field_valid`, но инвалидация не привязана к изменению карты.

5. **`WorldBootstrap._place_in_hero_component`** при полном исключении клеток возвращает `cand` (не `best`), что может быть клетка вне достижимости героя.

---

## 4. Рефакторинг: конкретные правки

### 4.1. Таблица приоритетов

| # | Что | Зачем | Приоритет |
|---|---|---|---|
| R1 | Убрать `HexGrid.shift_right` как глобус | Устранить глобальное состояние, сделать сетки независимыми | **High** |
| R2 | Заменить сервис-локатор на явную инъекцию | Тестируемость, явные зависимости | **High** |
| R3 | Разбить `GameNumbers` на модули | Читаемость, поиск, ответственность | **Medium** |
| R4 | Вынести данные юнитов/артефактов в JSON | Баланс без кода, валидация | **Medium** |
| R5 | Разделить `BattleTurnExecutor` | Машина состояний ≠ обработка запросов | **High** |
| R6 | Исправить кэш достижимости | Устранить риск коллизий хэша | **High** |
| R7 | Убрать статический доступ к дереву в `TileAtlas` | Хрупкость, тестирование | **Medium** |
| R8 | Упростить `City` / сервисы | Убрать 40+ делегатов | **Low** |

### 4.2. Примеры «до / после»

#### R1. Глобальная ориентация гексов → параметр

**До** (`HexUtils.get_neighbor`):
```gdscript
static func get_neighbor(cell: Vector2i, bit: int) -> Vector2i:
    var odd := (cell.y & 1) == 1
    if HexGrid.shift_right:
        return cell + (T_ODD_RIGHT[bit] if odd else T_EVEN_RIGHT[bit])
    else:
        return cell + (T_EVEN_RIGHT[bit] if odd else T_ODD_RIGHT[bit])
```

**После**:
```gdscript
# HexUtils.gd
static func get_neighbor(cell: Vector2i, bit: int, shift_right: bool = true) -> Vector2i:
    var odd := (cell.y & 1) == 1
    var table := T_ODD_RIGHT if (odd == shift_right) else T_EVEN_RIGHT
    return cell + table[bit]
```
Вызывающие (`MapGenerator`, `BattleState`, `City`) хранят `shift_right` в себе и передают. `HexGrid.calibrate` возвращает значение, а не пишет в глобус.

#### R2. Сервис-локатор → инъекция

**До** (`FollowerSystem.recruit`):
```gdscript
static func recruit(city: _City, hero, rng: RandomNumberGenerator,
        registry: _Trait = null) -> _Follower:
    ...
    var rc: _RaceClass = raceclass_registry()  # Services.resolve внутри
```

**После**:
```gdscript
static func recruit(
    city: _City,
    hero,
    rng: RandomNumberGenerator,
    trait_registry: _Trait,
    race_class_registry: _RaceClass
) -> _Follower:
    ...
```
Композиция в `WorldBootstrap`:
```gdscript
var trait_reg := TraitRegistry.new()
var rc_reg := RaceClassRegistry.new()
rc_reg.ensure()
var follower := FollowerSystem.recruit(city, hero, rng, trait_reg, rc_reg)
```

#### R3. Разбиение `GameNumbers`

**До**: один файл с 250+ константами.

**После**:
```
scripts/constants/
  BattleNumbers.gd      # BATTLE_*, ATK_*, DEF_*, LUCK_*, MORALE_*
  CityNumbers.gd        # CITY_*, PROSPERITY_*, REP_*, RAID_*
  HeroNumbers.gd        # HERO_*, CHEST_*, RESOURCE_CAPACITY
  CameraNumbers.gd      # CAMERA_*, ZOOM_*
  ArenaNumbers.gd       # ARENA_*
  UiNumbers.gd          # ADVENTURE_*, MENU_*
```
`GameNumbers` оставить как фасад с `@deprecated` или удалить.

#### R4. Данные юнитов в JSON

**До** (`UnitRegistry`):
```gdscript
const UNITS_BASE := {
    "swordsmen": ["Swordsman", 4, 10, 5, 2],
    ...
}
```

**После** (`assets/data/units.json`):
```json
[
  { "id": "swordsmen", "name": "Swordsman", "attack": 4,
    "base_damage": 4, "hp": 10, "speed": 5, "defense": 2,
    "tags": ["melee"] },
  ...
]
```
`UnitRegistry` загружает и валидирует при старте. Это позволяет вынести баланс в внешний инструмент.

#### R5. Разделение `BattleTurnExecutor`

Выделить:
- `BattleStateMachine` — `enum State`, `transition_to`, сигналы `phase_changed`.
- `BattleRequestHandler` — `request_move`, `request_attack`, `request_spell`, валидация.
- `BattleAnimationCoordinator` — `execute_move`, `execute_attack`, пауза/возобновление.

`BattleTurnExecutor` становится тонким фасадом.

#### R6. Кэш достижимости без коллизий

**До**:
```gdscript
func _cache_signature(blocked: Dictionary) -> int:
    var h := 0
    for cell in blocked: ...
```

**После**:
```gdscript
# Ключ — сам словарь, но храним его копию в кэше
func _cache_key(blocked: Dictionary) -> Dictionary:
    return blocked.duplicate(true)  # или сериализация в строку

var _reachable_cache: Dictionary = {}  # ключ: { "version": int, "blocked_hash": String }
```
Либо использовать `HashingContext` и SHA-256 от сериализованных клеток, либо хранить `blocked` как ключ напрямую (дорого по памяти, но надёжно). Для боя 7×7 это допустимо.

#### R7. `TileAtlas` без дерева сцены

**До**:
```gdscript
static func build_hex_tileset() -> TileSet:
    var main_loop := Engine.get_main_loop()
    ...
    var cache := tree.root.get_node_or_null("/root/TileAtlasCache")
```

**После**:
```gdscript
# TileAtlasCache.gd (автозагрузка)
var _hex_tileset: TileSet
func build_hex_tileset() -> TileSet:
    if _hex_tileset: return _hex_tileset
    _hex_tileset = _build()
    return _hex_tileset

# TileAtlas.gd
class_name TileAtlas
static func build_hex(tileset_cache: TileAtlasCache) -> TileSet:
    return tileset_cache.build_hex_tileset()
```
Или вызывать `TileAtlasCache.build_hex_tileset()` напрямую из мест использования.

---

## 5. Инструкция для локального агента

### 5.1. Пошаговый план

#### Фаза 0. Подготовка
1. Убедиться, что проект открывается: `godot --headless --editor --quit`.
2. Прогнать существующие тесты: `godot --headless --script tests/run_all.gd` (или команда проекта).
3. Создать ветку `refactor/architecture-cleanup`.

#### Фаза 1. Устранение глобального состояния гексов (R1, High)
**Файлы**:
- `scripts/autoload/hex_grid.gd`
- `scripts/core/HexUtils.gd`
- `scripts/world/MapGenerator.gd`
- `scripts/systems/BattleView.gd`
- `scripts/systems/BattleState.gd`
- `scripts/city/ArenaRingSystem.gd`
- Все вызовы `HexUtils.get_neighbor`, `hex_distance`, `ring`, `offset_to_cube`

**Действия**:
1. Добавить параметр `shift_right: bool = true` в `get_neighbor`, `get_all_neighbors`, `offset_to_cube`, `cube_to_offset`, `hex_distance`, `ring`.
2. В `MapGenerator`, `BattleState`, `City` сохранить `var hex_shift_right: bool = true`.
3. `HexGrid.calibrate` возвращает `bool` вместо записи в глобус.
4. Заменить все вызовы на версионированные с передачей ориентации.
5. Удалить `HexGrid.shift_right`.

**Проверка**:
```bash
godot --headless --script tools/check_no_global_hex.gd  # grep по "HexGrid.shift_right"
godot --headless --script tests/run_all.gd
```
**Критерий**: ноль обращений к `HexGrid.shift_right`; все тесты пути и боя зелёные.

#### Фаза 2. Кэш достижимости (R6, High)
**Файл**: `scripts/systems/BattleState.gd`

**Действия**:
1. Заменить `_cache_signature(blocked: Dictionary) -> int` на ключ, устойчивый к коллизиям:
   ```gdscript
   func _cache_key(blocked: Dictionary) -> String:
       var arr: Array = blocked.keys()
       arr.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
       var s := ""
       for c in arr: s += "%d,%d;" % [c.x, c.y]
       return s
   ```
2. Ключ кэша: `"%d:%s" % [_board_version, _cache_key(blocked)]`.
3. Убедиться, что `invalidate_board_cache` очищает `_reachable_cache`.

**Проверка**: юнит-тесты `test_battle_state_cache.gd` должны проходить. Добавить тест на коллизию: два разных `blocked` с одинаковым старым хэшем (если был).

**Критерий**: тесты кэша зелёные, нет регрессии в бое.

#### Фаза 3. Разбиение `GameNumbers` (R3, Medium)
**Файлы**: `scripts/constants/GameNumbers.gd` → новые файлы.

**Действия**:
1. Создать `scripts/constants/BattleNumbers.gd`, `CityNumbers.gd`, `HeroNumbers.gd`, `CameraNumbers.gd`, `ArenaNumbers.gd`, `UiNumbers.gd`.
2. Перенести константы по группам.
3. Заменить все ссылки `GameNumbers.X` на `BattleNumbers.X` и т.д. (автозамена по префиксу).
4. Оставить `GameNumbers` как пустой `class_name` с `@deprecated` комментарием или удалить.

**Проверка**:
```bash
grep -r "GameNumbers\." scripts/ --include="*.gd" | wc -l  # должно быть 0 после миграции
godot --headless --script tests/run_all.gd
```

#### Фаза 4. Инъекция зависимостей в ключевых сервисах (R2, High)
**Файлы**:
- `scripts/entities/FollowerSystem.gd`
- `scripts/systems/BattleDamageResolver.gd` (если использует `Services`)
- `scripts/systems/SpellCaster.gd`
- `scripts/autoload/BattleEmulator.gd`

**Действия**:
1. Для `FollowerSystem.recruit`, `SpellCaster.cast`, `BattleEmulator.emulate_battle` добавить явные параметры реестров.
2. В `WorldBootstrap` создавать реестры и передавать.
3. Оставить `Services.resolve` только в точках композиции (автозагрузки, `WorldBootstrap`).

**Критерий**: в доменных классах (`scripts/city`, `scripts/economy`, `scripts/systems`, `scripts/entities`) нет вызовов `Services.resolve`. Проверка:
```bash
grep -r "Services.resolve" scripts/city scripts/economy scripts/systems scripts/entities --include="*.gd"
```

#### Фаза 5. Данные в JSON (R4, Medium)
**Файлы**:
- `assets/data/units.json` (новый)
- `assets/data/artifacts.json` (новый)
- `scripts/autoload/UnitRegistry.gd`
- `scripts/autoload/ArtifactRegistry.gd`

**Действия**:
1. Экспортировать текущие данные в JSON скриптом-генератором.
2. Переписать `ensure_definitions` на загрузку из файла с валидацией схемы.
3. Добавить тесты валидности: все юниты имеют `hp > 0`, `speed >= 1`, теги непустые.

**Проверка**: существующие тесты `test_unit_registry.gd`, `test_artifact_system.gd` должны проходить без изменений.

#### Фаза 6. Разделение `BattleTurnExecutor` (R5, High)
**Файлы**:
- `scripts/systems/BattleTurnExecutor.gd`
- Новые: `scripts/systems/BattleStateMachine.gd`, `BattleRequestHandler.gd`

**Действия**:
1. Вынести `enum State`, `_transition_to`, `_state_token` в `BattleStateMachine`.
2. Вынести `request_move`, `request_attack`, `request_spell`, `request_sacrifice` в `BattleRequestHandler`.
3. `BattleTurnExecutor` использует оба через композицию.

**Критерий**: `BattleTurnExecutor` < 200 строк. Все тесты боя проходят.

### 5.2. Общие команды проверки
```bash
# Статическая проверка синтаксиса всех скриптов
godot --headless --check-only --script tools/check_all_scripts.gd

# Запуск тестов (пример, зависит от конфигурации)
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/

# Проверка отсутствия глобального состояния
grep -rn "HexGrid.shift_right" scripts/
grep -rn "Services.resolve" scripts/city scripts/economy scripts/systems scripts/entities --include="*.gd"

# Проверка констант
grep -rn "GameNumbers\." scripts/ --include="*.gd" | grep -v "constants/"
```

### 5.3. Критерии приёмки
1. Все существующие тесты зелёные до и после.
2. Нет обращений к `HexGrid.shift_right` вне `MapGenerator.calibrate` (если оставлен как локальный).
3. `Services.resolve` отсутствует в `scripts/city`, `scripts/economy`, `scripts/systems`, `scripts/entities`.
4. `GameNumbers` разбит; ни один файл не содержит более 80 констант.
5. `BattleTurnExecutor` не превышает 200 строк.
6. Данные юнитов/артефактов загружаются из JSON; тесты валидации проходят.
7. Кэш достижимости в бою не даёт ложных результатов при изменении блокировок (покрыто тестом).

# Тестовая архитектура: структура, покрытие, логика

## 1. Целевая структура каталогов

```
tests/
├── unit/                          # gdUnit4: быстрые, изолированные, без сцены
│   ├── core/                      # HexUtils, Pathfinding, VisibilityMap, TurnScheduler
│   ├── systems/                   # BattleState, BattleActionResolver, BattleAI, SpellCaster
│   ├── city/                      # CityService, BuildingService, Growth, Market, Raid, Events
│   ├── economy/                   # ProductionChain, EconomicTurnProcessor, Logistics
│   ├── hero/                      # Movement, Needs, Magic, Inventory, Army
│   ├── world/                     # MapModel, Spawner, FogOfWar, EnemyTurnProcessor
│   └── data/                      # Валидация реестров (спеллы, юниты, ресурсы)
├── integration/                   # gdUnit4: узлы и сигналы, без полной сцены
│   ├── battle/                    # BattleController + BattleTurnExecutor + View
│   ├── city/                      # City + CityTurnProcessor + EconomicTurnProcessor
│   └── persistence/               # SaveManager + WorldPersistence + миграции
├── mcp/                           # godot-mcp: E2E-сценарии через запущенную игру
│   ├── conftest.py                # фикстуры: mcp, world_scene, battle_scene
│   ├── test_world_boot.py          # запуск мира, появление героя
│   ├── test_battle_flow.py        # полный бой до победы
│   ├── test_city_build.py         # постройка и апгрейд
│   ├── test_save_load.py          # сохранение и восстановление
│   ├── test_succession.py         # смерть → преемник
│   └── test_performance.py        # профилирование под нагрузкой
├── helpers/
│   ├── factories.gd               # TestFactories: make_city, make_hero, seeded
│   ├── battle_factory.gd          # сборка BattleState с фиксированными позициями
│   └── assertions.gd              # доменные ассерты (клетки, ресурсы, юниты)
├── fakes/
│   ├── fake_map.gd                # MapGenerator без тайлмапа
│   ├── fake_hero.gd               # герой без движения
│   ├── fake_battle_flow.gd        # перехват вызовов
│   ├── fake_services.gd           # замена сервис-локатора
│   └── fake_rng.gd                # детерминированный RNG
└── spell_validation/              # валидаторы данных (не тесты, но запускаются в CI)
```

**Что убрать из текущей структуры:**
- `tests/functional/` на gdUnit4 — перенести в `tests/mcp/` (настоящие функциональные тесты) или в `tests/integration/` если они без сцены.
- Тесты, которые делают `get_tree().root.add_child(...)` и `free()` вручную — переписать на `auto_free()` gdUnit4.

---

## 2. Разделение зон ответственности

| Уровень | Инструмент | Что тестирует | Время | Зависимости |
|---|---|---|---|---|
| **Юнит** | gdUnit4 | Чистая логика: формулы, правила, алгоритмы, валидация данных | <50 мс/тест | Только `RefCounted`, без `Node`, без `Services` |
| **Интеграция** | gdUnit4 | Взаимодействие узлов, сигналы, фазы хода, сериализация | <500 мс/тест | `Node` + `auto_free`, без полной сцены |
| **Функциональный** | godot-mcp (Python) | Пользовательские сценарии: запуск сцены, ввод, анимации, переходы | 2–30 с/тест | Запущенный проект, `game_eval`, `run_project` |
| **Валидация данных** | gdUnit4 + скрипт | JSON/реестры: уникальность, диапазоны, обязательные поля | <100 мс | Только файлы |

**Правило:** если тесту нужен `TileMapLayer`, `Camera2D`, рендер, ввод мышью, `await` на таймере — это **только** `godot-mcp`. gdUnit4 не должен ждать кадры.

---

## 3. Покрытие по модулям

### 3.1. Бой (приоритет: High)

| Модуль | Юнит (gdUnit4) | Интеграция (gdUnit4) | Функциональный (MCP) |
|---|---|---|---|
| `BattleRules` | Множитель урона, клампы, удача/мораль, превью | — | — |
| `BattleState` | Очередь инициативы, `_unit_grid`, достижимость, кэш | — | — |
| `BattleActionResolver` | Атака, заклинание, жертва, убийство/воскрешение | Полный ход с сигналами | Полный бой до победы |
| `BattleTurnExecutor` | Машина состояний, пауза/возобновление | Переходы фаз с фейковым `BattleView` | Бой с реальными анимациями |
| `BattleAI` | Выбор цели, движение, полёт | — | — |
| `SpellCaster` | Урон, иммунитеты, резист | — | Каст в бою |

### 3.2. Город (приоритет: High)

| Модуль | Юнит | Интеграция | Функциональный |
|---|---|---|---|
| `CityService` | Население, лимиты, жильё, защита | — | — |
| `CityBuildingService` | Валидация постройки, апгрейд, район | Город + фаза хода | Постройка в арене |
| `CityGrowthService` | Потребление, порог роста, рождение | Полный цикл `process_turn` | — |
| `MarketSystem` | Ставки, торговля, ограничения | — | — |
| `RaidSystem` | Шанс, сила, исход, разграбление | Сигналы процессора | — |
| `CityEvents` | Детерминизм, эффекты, пул | — | — |
| `CityTurnProcessor` | Фаза, репутация, миграция, уровень | Интеграция с `TurnScheduler` | — |

### 3.3. Герой и мир (приоритет: High)

| Модуль | Юнит | Интеграция | Функциональный |
|---|---|---|---|
| `HeroMovementController` | Путь, частичный ход, блокировка | Движение с фейковой картой | Клик по карте |
| `HeroNeeds` | Декей, восстановление, смерть | Сигнал `hero_died` | — |
| `HeroMagic` | Мана, школы, каст | — | Каст в бою |
| `HeroInventory` | Экипировка, двуручное, лимиты | — | Открытие инвентаря |
| `HeroArmyController` | Лимит 7, дубли, применение боя | — | — |
| `MapModel` | Генерация, биомы, детерминизм | — | — |
| `MapSpawner` | Деревни, ресурсы, враги, отступы | — | — |
| `VisibilityMap` | Диск видимости, разведка, сериализация | Туман + движение | — |
| `EnemyTurnProcessor` | Движение к герою, атака, захват | Полный ход врагов | — |

### 3.4. Экономика и персистентность (приоритет: Medium)

| Модуль | Юнит | Интеграция | Функциональный |
|---|---|---|---|
| `ProductionChain` | Расчёт, вход/выход, эффективность | Цепочка с `ResourceContext` | — |
| `EconomicTurnProcessor` | Авто-доход, содержание, сигналы | Интеграция с городом | — |
| `LogisticsCalculator` | Дистанция, дороги, клампы | — | — |
| `SaveManager` | Ошибки файлов, парсинг, валидация | — | Сохранение/загрузка |
| `WorldPersistence` | Миграции, сериализация, осколки | Раундтрип героя+городов | Загрузка сейва в игре |
| `SuccessionController` | Выбор преемника, трансфер легенды | Смерть → преемник | Смерть в игре |

---

## 4. Логика тестов: обязательные правила

### 4.1. Детерминизм
```gdscript
# Каждый тест фиксирует сид
var rng := TestFactories.seeded(42)  # внутри: seed = 42

# Бой: фиксированные позиции
func _setup_battle() -> BattleState:
    var state := BattleState.new()
    var atk := [Units.make_fixed_stack("swordsmen", 20)]
    var def := [Units.make_fixed_stack("goblins", 5)]
    state.place_army(atk, def)
    state.attacker_units[0].cell = Vector2i(5, 5)
    state.defender_units[0].cell = Vector2i(6, 5)  # соседняя
    state._rebuild_unit_grid()
    return state
```

### 4.2. Изоляция от сервис-локатора
В юнит-тестах **запрещён** `Services.resolve`. Использовать явную инъекцию:
```gdscript
# Плохо
var reg: Node = Services.resolve(&"spells")

# Хорошо
var reg := SpellRegistry.new()
reg.ensure_definitions()
var result := SpellCaster.cast(&"magic_arrow", target, {"spell_power": 5}, {}, rng, reg)
reg.free()
```

Для существующего кода, который требует `Services`, создать `FakeServiceRegistry`:
```gdscript
# tests/fakes/fake_services.gd
class_name FakeServices
static func register(key: StringName, service: Object) -> void:
    Services.registry.register_singleton(key, service)
static func clear() -> void:
    Services.clear_session()
```

### 4.3. Управление памятью
```gdscript
# Плохо: ручной free()
var h := HeroController.new()
add_child(h)
# ... тест ...
h.free()

# Хорошо: автоочистка
func test_something() -> void:
    var h := auto_free(HeroController.new())
    add_child(h)
    # ... тест ...
```

### 4.4. Тестирование сигналов
```gdscript
func test_raid_emits_signal() -> void:
    var city := TestFactories.make_city()
    var proc := CityTurnProcessor.new()
    var events: Array = []
    proc.raid_occurred.connect(
        func(uid: int, repelled: bool): events.append([uid, repelled]))
    
    proc._process_city(city, 12)
    
    assert_that(events.size()).is_equal(1)
    assert_that(events[0][0]).is_equal(city.uid)
    proc.free()
```

### 4.5. Граничные случаи для формул
Обязательно проверять:
- Клампы (`MIN_DAMAGE_MULTIPLIER`, `MAX_DAMAGE_MULTIPLIER`, `REP_MIN/MAX`)
- Деление на ноль (защита в `damage_multiplier`)
- Пустые массивы (`get_retreat_survivors` при 0 юнитов)
- Отрицательные значения (`add_glory(-5)`)
- Переполнение (`pop > cap`, `mana_current > mana_max`)

---

## 5. Шаблоны кода

### 5.1. Юнит-тест (gdUnit4)

```gdscript
# tests/unit/systems/test_battle_rules.gd
extends GdUnitTestSuite
const _BattleRules := preload("res://scripts/core/battle_rules.gd")
const _UnitStats := preload("res://scripts/entities/unit_stats.gd")
const _UnitStack := preload("res://scripts/entities/unit_stack.gd")
const _BattleUnit := preload("res://scripts/systems/battle_state.gd").BattleUnit

func _unit(atk: int, def: int, tags: Array = []) -> BattleState.BattleUnit:
    var stats := UnitStats.new("t", "T", atk, 5, 10, 3, def, tags)
    return BattleUnit.new(UnitStack.new(stats, 10))

func test_damage_multiplier_attack_advantage() -> void:
    var atk := _unit(15, 0)
    var def := _unit(0, 10)
    # diff = 15-10 = 5 → 1 + 5*0.05 = 1.25
    assert_float(_BattleRules.damage_multiplier(atk, def, 0, 0)) \
        .is_equal_approx(1.25, 0.001)

func test_damage_multiplier_clamped_to_max() -> void:
    var atk := _unit(100, 0)
    var def := _unit(0, 0)
    assert_float(_BattleRules.damage_multiplier(atk, def, 0, 0)) \
        .is_equal(GameNumbers.MAX_DAMAGE_MULTIPLIER)

func test_damage_multiplier_defending() -> void:
    var atk := _unit(10, 0)
    var def := _unit(0, 10)
    def.defending = true
    # def = 10 * 1.2 = 12, diff = -2 → 1 - 2*0.025 = 0.95
    assert_float(_BattleRules.damage_multiplier(atk, def, 0, 0)) \
        .is_equal_approx(0.95, 0.001)

func test_luck_immune_for_undead() -> void:
    assert_bool(_BattleRules.can_luck(_unit(1, 1, ["undead"]))).is_false()
    assert_bool(_BattleRules.can_luck(_unit(1, 1, ["elemental"]))).is_false()
    assert_bool(_BattleRules.can_luck(_unit(1, 1))).is_true()
```

### 5.2. Интеграционный тест (gdUnit4)

```gdscript
# tests/integration/battle/test_battle_turn_flow.gd
extends GdUnitTestSuite
const _BattleState := preload("res://scripts/systems/battle_state.gd")
const _Executor := preload("res://scripts/systems/battle_turn_executor.gd")
const _AI := preload("res://scripts/systems/battle_ai.gd")
const _Units := preload("res://scripts/autoload/unit_registry.gd")

var _units: Node

func before_test() -> void:
    _units = _Units.new()
    _units.ensure_definitions()

func after_test() -> void:
    _units.free()

func test_full_player_attack_cycle() -> void:
    var state := BattleState.new()
    var atk := [_units.make_fixed_stack("swordsmen", 20)]
    var def := [_units.make_fixed_stack("goblins", 5)]
    state.place_army(atk, def)
    state.attacker_units[0].cell = Vector2i(5, 5)
    state.defender_units[0].cell = Vector2i(6, 5)
    state._rebuild_unit_grid()
    state.build_queue()

    var exec := auto_free(_Executor.new())
    exec.setup(state, _AI.new(), {})
    
    var move_emitted := false
    var attack_emitted := false
    exec.execute_move.connect(func(_u, _p): move_emitted = true)
    exec.execute_attack.connect(func(_a, _d, _r): attack_emitted = true)

    # Имитация: игрок выбирает юнит и атакует
    state.active_unit = state.attacker_units[0]
    exec._state = _Executor.State.WAITING_INPUT
    exec.request_attack(state.attacker_units[0], state.defender_units[0])

    assert_bool(attack_emitted).is_true()
    assert_bool(state.defender_units[0].get_count() < 5).is_true()
```

### 5.3. Функциональный тест (godot-mcp)

```python
# tests/mcp/test_battle_flow.py
from __future__ import annotations
import time

BATTLE_SCENE = "res://scenes/battle.tscn"

def test_battle_starts_and_player_can_act(mcp):
    """Бой запускается, игрок может выбрать юнит и атаковать."""
    mcp.run_scene(BATTLE_SCENE)
    mcp.wait_ready()

    # Инициализация боя
    init = mcp.execute_code("""
    var battle = get_tree().current_scene
    if battle == null or not battle.has_method("start_battle"):
        return {"error": "Battle not ready"}
    var units_reg = get_node("/root/Units")
    units_reg.ensure_definitions()
    var atk = [units_reg.make_fixed_stack("swordsmen", 20)]
    var def = [units_reg.make_fixed_stack("goblins", 5)]
    battle.start_battle(atk, def, {"attack": 5}, {"defense": 2}, {}, {}, 42, null)
    return {"started": true}
    """)
    assert init.get("started") is True, f"Init failed: {init}"

    # Ждём, пока бой не начнётся и не появится активный юнит
    deadline = time.time() + 10
    active = None
    while time.time() < deadline:
        state = mcp.execute_code("""
        var bs = get_tree().current_scene.get_battle_state()
        if bs == null or bs.battle_over:
            return {"over": true}
        return {
            "over": false,
            "is_player_turn": bs.is_player_turn,
            "has_active": bs.active_unit != null,
        }
        """)
        if state.get("over"):
            break
        if state.get("is_player_turn") and state.get("has_active"):
            active = True
            break
        mcp.wait_frames(1)
    assert active is True, "Ход игрока не начался за 10 с"

    # Атака: выбираем юнита и атакуем ближайшего врага
    result = mcp.execute_code("""
    var battle = get_tree().current_scene
    var executor = battle.get_node("BattleTurnExecutor")
    var bs = battle.get_battle_state()
    var atk = bs.attacker_units[0]
    var def = bs.defender_units[0]
    if atk == null or def == null:
        return {"error": "units missing"}
    # Ставим рядом для атаки
    def.cell = Vector2i(atk.cell.x + 1, atk.cell.y)
    bs._rebuild_unit_grid()
    bs.active_unit = atk
    executor.request_attack(atk, def)
    return {"requested": true, "def_count_before": def.get_count()}
    """)
    assert result.get("requested") is True

    # Ждём завершения атаки
    deadline = time.time() + 10
    attacked = False
    while time.time() < deadline:
        state = mcp.execute_code("""
        var bs = get_tree().current_scene.get_battle_state()
        var def = bs.defender_units[0]
        return {"count": def.get_count() if def != null else -1}
        """)
        if state.get("count", -1) < 5:
            attacked = True
            break
        mcp.wait_frames(2)
    assert attacked is True, "Урон не был применён за 10 с"

    mcp.stop_running_scene()


def test_battle_ends_with_winner(mcp):
    """Бой завершается победой одной из сторон."""
    mcp.run_scene(BATTLE_SCENE)
    mcp.wait_ready()

    mcp.execute_code("""
    var battle = get_tree().current_scene
    var units_reg = get_node("/root/Units")
    var atk = [units_reg.make_fixed_stack("swordsmen", 100)]
    var def = [units_reg.make_fixed_stack("goblins", 1)]
    battle.start_battle(atk, def, {}, {}, {}, {}, 42, null)
    """)

    deadline = time.time() + 30
    winner = None
    while time.time() < deadline:
        state = mcp.execute_code("""
        var bs = get_tree().current_scene.get_battle_state()
        return {"over": bs.battle_over, "winner": bs.battle_winner}
        """)
        if state.get("over"):
            winner = state.get("winner")
            break
        mcp.wait_frames(5)
    assert winner is not None, "Бой не завершился за 30 с"
    assert winner == 1, f"Ожидалась победа атакующего (1), получено {winner}"
    mcp.stop_running_scene()
```

### 5.4. Тест производительности (godot-mcp)

```python
# tests/mcp/test_performance.py
import time

MAX_MAP_GEN_MS = 3000
MAX_ASTAR_MS = 200

def test_map_generation_performance(mcp):
    """Генерация карты 80×80 не дольше 3 секунд."""
    mcp.run_scene("res://scenes/world.tscn")
    mcp.wait_ready()

    result = mcp.execute_code("""
    var t0 = Time.get_ticks_msec()
    var model = MapModel.new()
    model.map_width = 80
    model.map_height = 80
    model.seed_value = 42
    model.generate_noise()
    model.smooth_invalid_adjacencies()
    return {"elapsed_ms": Time.get_ticks_msec() - t0}
    """)
    assert result["elapsed_ms"] < MAX_MAP_GEN_MS, \
        f"Генерация заняла {result['elapsed_ms']} мс (лимит {MAX_MAP_GEN_MS})"
    mcp.stop_running_scene()


def test_astar_performance(mcp):
    """A* на карте 80×80 не дольше 200 мс."""
    mcp.run_scene("res://scenes/world.tscn")
    mcp.wait_ready()

    result = mcp.execute_code("""
    var model = MapModel.new()
    model.map_width = 80
    model.map_height = 80
    model.seed_value = 42
    model.generate_noise()
    var start = Vector2i(2, 2)
    var goal = Vector2i(77, 77)
    while not model.is_walkable(start): start.x += 1
    while not model.is_walkable(goal): goal.x -= 1
    var blocked = model.get_blocked_cells()
    var times = []
    for i in 10:
        var t0 = Time.get_ticks_msec()
        HexPathfinding.astar_path(start, goal, blocked, 80, 80)
        times.append(Time.get_ticks_msec() - t0)
    var avg = 0.0
    for t in times: avg += t
    avg /= times.size()
    return {"avg_ms": avg}
    """)
    assert result["avg_ms"] < MAX_ASTAR_MS, \
        f"A* в среднем {result['avg_ms']} мс (лимит {MAX_ASTAR_MS})"
    mcp.stop_running_scene()
```

---

## 6. Фабрики и фейки

### 6.1. `tests/helpers/factories.gd`

```gdscript
class_name TestFactories
extends RefCounted

static func seeded(seed: int) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = seed
    return r

static func make_city(uid := 1, stronghold := 2) -> City:
    var city := City.new()
    city.uid = uid
    city.display_name = "TestTown %d" % uid
    city.center = Vector2i(5, 5)
    city.stronghold_level = stronghold
    city.storage[&"industry"] = 500.0
    return city

static func make_hero(path := &"archivist") -> HeroController:
    var h := HeroController.new()
    h.hero_name = "Darkstorn"
    h.path_id = path
    return h

static func make_battle_state(
    atk_key := "swordsmen", def_key := "goblins",
    atk_count := 20, def_count := 5
) -> BattleState:
    var units := Services.resolve(&"units")
    if units == null:
        units = load("res://scripts/autoload/unit_registry.gd").new()
    var state := BattleState.new()
    var atk := [units.make_fixed_stack(atk_key, atk_count)]
    var def := [units.make_fixed_stack(def_key, def_count)]
    state.place_army(atk, def)
    return state
```

### 6.2. `tests/fakes/fake_map.gd`

```gdscript
class_name FakeMap
extends MapGenerator

func _init(size := 12) -> void:
    model = MapModel.new()
    model.map_width = size
    model.map_height = size
    for x in size:
        for y in size:
            model.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS

func has_valid_tilemap() -> bool:
    return false  # тесты без рендера

func get_tile_size() -> Vector2i:
    return Vector2i(82, 82)
```

---

## 7. Команды запуска и CI

### 7.1. Локальный запуск

```bash
# Юнит + интеграция (gdUnit4)
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/unit/ tests/integration/

# Только юниты (быстрые)
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/unit/

# Валидация данных
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/unit/data/

# MCP-тесты (нужен запущенный godot-mcp сервер)
cd tests/mcp
python -m pytest -xvs --tb=short
```

### 7.2. CI (GitHub Actions)

```yaml
name: Tests
on: [push, pull_request]

jobs:
  unit-integration:
    runs-on: ubuntu-latest
    container: barichello/godot:4.7
    steps:
      - uses: actions/checkout@v4
      - name: Import project
        run: godot --headless --editor --quit
      - name: Unit + Integration
        run: godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/unit/ tests/integration/

  data-validation:
    runs-on: ubuntu-latest
    container: barichello/godot:4.7
    steps:
      - uses: actions/checkout@v4
      - run: godot --headless --editor --quit
      - run: godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/unit/data/

  mcp-functional:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - name: Install dependencies
        run: pip install pytest mcp anyio
      - name: Build godot-mcp
        run: cd addons/godot-mcp && npm install && npm run build
      - name: Run MCP tests
        run: cd tests/mcp && python -m pytest -xvs --tb=short
        env:
          GODOT_PATH: /usr/local/bin/godot
```

---

## 8. Критерии приёмки

| Критерий | Значение |
|---|---|
| Юнит-тесты проходят | 100% |
| Юнит-тест без `Services.resolve` | 100% (кроме интеграции) |
| Юнит-тест без `add_child` / `Node` | 100% |
| Интеграция использует `auto_free` | 100% |
| MCP-тесты покрывают 6 ключевых сценариев | 100% |
| Покрытие формул боя (множитель, удача, мораль) | 100% |
| Покрытие граничных случаев (клампы, пустые массивы) | 100% |
| Детерминизм: одинаковый сид → одинаковый результат | 100% |
| Время юнит-теста | <50 мс |
| Время интеграционного теста | <500 мс |
| Время MCP-теста | <30 с |
| Валидация данных (спеллы, юниты, ресурсы) | 100% записей |

---

## 9. Приоритеты внедрения

| Фаза | Что | Приоритет |
|---|---|---|
| **1** | Фабрики + фейки + изоляция от `Services` в юнитах | High |
| **2** | Юнит-тесты боя: `BattleRules`, `BattleState`, `BattleActionResolver` | High |
| **3** | Юнит-тесты города: `CityService`, `CityGrowthService`, `MarketSystem`, `RaidSystem` | High |
| **4** | MCP: запуск мира, полный бой, сохранение/загрузка | High |
| **5** | Интеграция: `TurnScheduler` + городские процессоры | Medium |
| **6** | Юнит-тесты героя: движение, потребности, инвентарь | Medium |
| **7** | MCP: постройка города, смерть → преемник | Medium |
| **8** | Производительность: генерация карты, A*, сериализация | Low |
| **9** | Валидация данных: все реестры из кода в JSON + тесты | Low |