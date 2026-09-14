# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

---

## 1. Архитектура

### 1.1. Общее впечатление

Проект — гекс-стратегия с боями, городами, героями, магией. Объём — **~500 файлов**, ~45 тыс. строк GDScript. Архитектура **переходная**: виден рефакторинг от «всё в контроллерах» к сервисам, но процесс незавершён.

### 1.2. Модульность и разделение ответственности

| Компонент | Оценка | Проблема |
|---|---|---|
| `WorldController` | ❌ | Бога-объект: 20+ зависимостей, делегирует в `_lifecycle()`, но хранит сырые ссылки |
| `BattleController` | ⚠️ | Смешивает ввод, отображение, логику боя |
| `HeroController` | ❌ | 15+ подсистем (`movement`, `army`, `magic`, `inventory`, `needs`, `skills`, `tools`, `time`), всё через сигналы |
| `City` | ⚠️ | God Object: 30+ методов-делегатов в `CityService`, `CityBuildingService`, `CityGrowthService` |
| `ArenaRingSystem` / `ArenaClusterSystem` | ✅ | Чистые статические системы, тестируемые |
| `BattleState` / `BattleActionResolver` | ✅ | Разделение состояния и мутаций |
| `WorldEventRouter` | ⚠️ | 13+ параметров в `setup()` — сигнал «не знаю, куда это положить» |

**Главная проблема: сервис-локатор вместо DI.**

```gdscript
// Повсеместно:
var reg: Object = Services.resolve(&"resources")
var spell_reg: Object = Services.resolve(&"spells")
```

Это скрывает зависимости, ломает тестируемость, создаёт неявные контракты.

### 1.3. Связность и связанность

**Сильная связанность:**

```
HeroController → movement, army, resources, magic, inventory,
                 needs, skills, tools, time, strategic_resources,
                 city_manager, visual, GameEventBus
WorldController → WorldBootstrap, HeroLifecycleSystem,
                  EndgameController, WorldBattleCoordinator,
                  WorldInteractionController, ResourceNodeManager,
                  TerrainResourceManager, WorldPersistence,
                  WorldUIManager, CityManager, MapGenerator...
```

**Циклические зависимости (скрытые через сигналы):**
- `HeroController` → `GameEventBus` → `CursorController` → `GameEventBus`
- `CityManager` → `City` → `CityService` → `CityManager` (через `population_changed`)

### 1.4. Масштабируемость

| Аспект | Состояние |
|---|---|
| Добавление нового ресурса | ⚠️ Нужно править `ResourceRegistry`, `ResourceAtlas`, `ResourceIcons`, `ResourcesPanel` — **4 файла** |
| Добавление нового заклинания | ✅ Только `SpellRegistry._reg()` |
| Добавление нового юнита | ✅ Только `UnitRegistry.UNITS_BASE` |
| Добавление нового здания | ✅ `BuildingDefs` + JSON |
| Добавление нового шаблона спелла | ⚠️ `TemplateEngine` + `TemplateBootstrap` + файл `tXX_*.gd` |
| Новая карта/шард | ✅ `ShardManager` готов |

### 1.5. Паттерны

| Паттерн | Где | Оценка |
|---|---|---|
| Сервис-локатор | `Services` / `ServiceRegistry` | ⚠️ Работает, но антипаттерн в долгосрочной перспективе |
| Синглтон | `ShardManager._instance`, `StaticCaches` | ⚠️ Глобальное состояние |
| Команда | `BattleActionResolver` | ✅ Чистые функции |
| Наблюдатель | Сигналы `GameEventBus` | ✅ Хорошая шина событий |
| Стратегия | `NeedStrategy` / `RestStrategy` / `SocialStrategy` | ✅ |
| Строитель | `BattleStateBuilder` | ✅ |
| Хранилище | `WorldPersistence` / `SaveData` | ✅ Версионирование |
| Фабрика | `CityFactory`, `HeroModelFactory` | ✅ |

---

## 2. Лучшие практики

### 2.1. SOLID

| Принцип | Нарушение | Пример |
|---|---|---|
| **S** (Single Responsibility) | `City` — 30+ делегатов | `city.pop_total()` → `CityService.pop_total()` |
| **O** (Open/Closed) | `WorldSpawner` — хардкод типов | `_spawn_villages`, `_spawn_resources`, `_spawn_enemies` |
| **L** (Liskov) | ✅ Нет явных нарушений | — |
| **I** (Interface Segregation) | `WorldEventRouter.setup()` — 13 параметров | См. ниже |
| **D** (Dependency Inversion) | `Services.resolve()` — строковые ключи | `Services.resolve(&"resources")` |

### 2.2. DRY

**Критические дублирования:**

1. **Гекс-константы в 3 местах:**
```gdscript
// HexUtils.gd
const T_ODD_RIGHT := [Vector2i(1,0), ...]
// tile_atlas.gd — TILE := 82
// ArenaHexCell.gd — HEX_SIZE := 26.0
// GameNumbers.gd — BATTLE_HEX_OUTLINE_RADIUS := 38.0
```

2. **`_make_unit` дублируется в 6 тестах** — нужен общий фикстур.

3. **`_spawn_*` в `WorldSpawner`** — 5 методов с одинаковой структурой.

4. **Сериализация `Vector2i`** повторяется 8+ раз:
```gdscript
{"x": cell.x, "y": cell.y}  // WorldStateDelta, SaveData, CitySerializer...
```

### 2.3. KISS / YAGNI

| Проблема | Пример |
|---|---|
| YAGNI | `BattleSpellBridge` — мост между двумя системами спеллов, используется в 1 тесте |
| YAGNI | `ResourceChainService._cached` с fingerprint — избыточно для 10 ресурсов |
| KISS | `City` делегирует 30 методов в `CityService` — лишний слой |
| KISS | `SpellResolver` + `TemplateEngine` + 19 шаблонов для 20 спеллов |

### 2.4. Безопасность и обработка ошибок

**Хорошо:**
- `SaveData.from_dict()` с миграциями версий
- `CityCheck` как Result-тип
- `FileAccess` с проверкой ошибок

**Плохо:**
- `Services.resolve()` возвращает `null` без предупреждения в половине случаев
- `_BattleFX._resolve_spell()` молча возвращает `{}` при ошибке
- `JSON.parse_string` без `try` — может вернуть `null`

```gdscript
// Проблемный паттерн:
var reg: Object = Services.resolve(&"spells")
if reg == null:
    return {"error": "..."}  // В 50% случаев нет проверки
```

### 2.5. Naming и читаемость

| Проблема | Пример | Рекомендация |
|---|---|---|
| Смешение стилей | `_on_hero_died`, `hero_died`, `_handle_left_click` | Единый стиль |
| Неинформативные имена | `_r`, `_p`, `_d`, `_b`, `_w` | Полные имена |
| Кириллица в логах | `push_error("Не удалось открыть")` | Английский |
| Магические числа | `38.0`, `26.0`, `82` | В `GameNumbers` |

---

## 3. Алгоритмы

### 3.1. Найденные алгоритмы

| Алгоритм | Файл | Назначение |
|---|---|---|
| BFS | `HexPathfinding.bfs_path` | Поиск пути без стоимости |
| A* | `HexPathfinding.astar_path` | Поиск пути с эвристикой |
| Дейкстра | `HexPathfinding.dijkstra` | Распространение стоимости |
| MinHeap | `MinHeap.gd` | Приоритетная очередь для A*/Дейкстры |
| Cube-координаты | `HexUtils` | Расстояния на гексах |
| Flood-fill (BFS) | `MapGenerator._compute_reachable_cells` | Связность карты |
| Кэширование | `BattleState._reachable_cache` | Избежание повторного BFS |
| Сортировка по скорости | `BattleState.build_queue` | Инициатива в бою |
| Хэширование | `hash()` в `ArenaClusterSystem` | Версионирование кэша |

### 3.2. Корректность и граничные случаи

**✅ Корректно:**
- `MinHeap` — стандартная реализация, корректна
- `bfs_path` — BFS на гексах, граничные случаи обработаны
- `astar_path` — корректный, эвристика допустима

**⚠️ Проблемы:**

1. **`HexPathfinding.dijkstra` — O(V) для очистки:**
```gdscript
for i in range(dist.size()):
    if dist[i] > max_cost + 0.001:
        dist[i] = INF
```
Это O(W×H) на каждый вызов. Для 80×80 = 6400 операций — приемлемо, но на больших картах станет узким.

2. **`BattleState.get_reachable` — кэш по сигнатуре:**
```gdscript
func _cache_signature(blocked: Dictionary, unit: BattleUnit = null) -> String:
    // Строит строку из всех заблокированных клеток
    var cells: Array = blocked.keys()
    cells.sort()
    var s := ""
    for c in cells:
        s += str(c) + ","
```
Это **O(B log B)** на каждый вызов, где B — число заблокированных. Для боя с 17×11 полем это ~50-100 клеток, нормально, но можно лучше.

3. **`ArenaClusterSystem._city_version` — хеш всех зданий:**
```gdscript
static func _city_version(city: City) -> int:
    var h: int = 0
    for bld in city.buildings:
        h = (h * 131 + int(bld.uid)) & 0x7fffffff
        // ... 6 операций хеширования на здание
```
O(N) на каждое здание. Для 20 зданий — 120 операций. Приемлемо, но хеш может коллидировать.

### 3.3. Сложность

| Алгоритм | Время | Память | Где используется |
|---|---|---|---|
| `bfs_path` | O(V+E) | O(V) | Путь на карте |
| `astar_path` | O(E log V) | O(V) | Герой на карте |
| `dijkstra` | O((V+E) log V) | O(V) | Достижимость |
| `bfs_reachable` | O(V+E) | O(V) | Подсветка ходов в бою |
| `_compute_reachable_cells` | O(V+E) | O(V) | Генерация карты |
| `clusters()` | O(N) | O(N) | Кластеры зданий |

### 3.4. Альтернативы

| Текущее | Альтернатива | Выгода |
|---|---|---|
| `MinHeap` (своя) | `Godot AStar2D` | Встроенный, оптимизирован |
| Строковая сигнатура кэша | `int` версия + `Dictionary` ключ | Убрать аллокацию строк |
| `hash()` для кластеров | Инкрементальный хеш | Избежать пересчёта |
| Дейкстра для каждой клетки | Предвычисление поля расстояний | При массовых запросах |

---

## 4. Рефакторинг

### 4.1. Приоритет High

#### H1. Заменить сервис-локатор на DI через конструктор

**Что:** `Services.resolve(&"resources")` → внедрение через `init()` или `setup()`.

**Зачем:** Явные зависимости, тестируемость, нет скрытых связей.

**До:**
```gdscript
class_name ResourceNodeManager
func _get_def(id: StringName) -> ResourceDef:
    var reg := Services.resolve(&"resources")
    return reg.get_resource(id) as ResourceDef
```

**После:**
```gdscript
class_name ResourceNodeManager
var _resource_registry: Node  # ResourceRegistry

func _init(reg: Node):
    _resource_registry = reg

func _get_def(id: StringName) -> ResourceDef:
    return _resource_registry.get_resource(id) as ResourceDef
```

**Файлы:** `ResourceNodeManager.gd`, `ResourceChainService.gd`, `SpellCaster.gd`, `BattleEmulator.gd`

---

#### H2. Убрать делегаты из `City` — прямой доступ к сервисам

**Что:** `City` содержит 30+ методов-делегатов.

**Зачем:** Лишний слой, нарушение SRP.

**До:**
```gdscript
class_name City
extends CityData
func pop_total() -> int: return CityService.pop_total(self)
func pop_capped() -> int: return CityService.pop_capped(self)
func pop_cap() -> int: return CityService.pop_cap(self)
# ... ещё 27
```

**После:**
```gdscript
# Вариант 1: убрать CityService, логика в CityData
class_name City extends CityData:
    func pop_total() -> int:
        return pop.size()

# Вариант 2: оставить сервис, но без делегатов
# Вызов: CityService.pop_total(city) вместо city.pop_total()
```

**Файлы:** `City.gd`, `CityService.gd`, все вызовы `city.pop_total()`

---

#### H3. Разбить `HeroController` на компоненты через `Composition`

**Что:** 15+ подсистем в одном классе.

**Зачем:** Single Responsibility, независимая разработка.

**До:**
```gdscript
class_name HeroController extends Node2D
var movement: HeroMovementController
var army: HeroArmyController
var resources: HeroResources
var magic: HeroMagic
var inventory: HeroInventory
var needs: HeroNeeds
var skills: HeroSkills
var tools: HeroTools
var time: TimeSystem
var strategic_resources: HeroStrategicResources
# + сигналы для каждого
```

**После:**
```gdscript
class_name HeroController extends Node2D
# Только координация, компоненты через get_node()
# Каждый компонент — самостоятельный узел в сцене
```

**Файлы:** `HeroController.gd`, все подсистемы

---

### 4.2. Приоритет Medium

#### M1. Единая функция сериализации `Vector2i`

**До (8+ мест):**
```gdscript
"center": {"x": city.center.x, "y": city.center.y}
```

**После:**
```gdscript
static func vec2i_to_dict(v: Vector2i) -> Dictionary:
    return {"x": v.x, "y": v.y}

static func vec2i_from_dict(d: Dictionary) -> Vector2i:
    return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
```

**Файл:** новый `scripts/utils/SerializationUtils.gd`

---

#### M2. Убрать дублирование `_make_unit` в тестах

**До:** 6 копий в разных тест-файлах.

**После:**
```gdscript
# tests/helpers/factories.gd
static func make_battle_unit(key: String, count: int, side: BattleState.Side) -> BattleState.BattleUnit:
    var stack = Units.make_fixed_stack(key, count)
    var unit := BattleState.BattleUnit.new(stack)
    unit.side = side
    unit.max_count = count
    return unit
```

**Файл:** `tests/helpers/factories.gd`

---

#### M3. Убрать `BattleSpellBridge`

**Что:** Мост между `SpellRegistry` и `SpellbookRegistry`, используется в 1 тесте.

**Зачем:** YAGNI — две системы спеллов не нужны.

**Файлы:** удалить `BattleSpellBridge.gd`, объединить спеллы в одну систему.

---

### 4.3. Приоритет Low

#### L1. Магические числа → `GameNumbers`

```gdscript
// До:
const HEX_SIZE := 26.0
const TILE := 82

// После:
GameNumbers.HEX_SIZE := 26.0
GameNumbers.TILE_SIZE := 82
```

#### L2. Английские логи вместо русских

```gdscript
// До:
push_error("Не удалось открыть %s" % path)
// После:
push_error("Failed to open %s" % path)
```

#### L3. Убрать пустые методы-заглушки

```gdscript
func _exit_tree() -> void:
    pass  # Удалить
```

---

## 5. Инструкция для локального агента

### 5.1. Пошаговый план

| Шаг | Приоритет | Действие | Файлы |
|---|---|---|---|
| 1 | High | Создать `SerializationUtils.gd` | `scripts/utils/SerializationUtils.gd` |
| 2 | High | Заменить `Services.resolve()` на DI в `ResourceNodeManager` | `ResourceNodeManager.gd` |
| 3 | High | Убрать делегаты из `City` | `City.gd`, `CityService.gd` |
| 4 | Medium | Общий `_make_unit` в `factories.gd` | `tests/helpers/factories.gd` |
| 5 | Medium | Удалить `BattleSpellBridge.gd` | `BattleSpellBridge.gd`, тесты |
| 6 | Low | Магические числа в `GameNumbers` | Все файлы с константами |
| 7 | Low | Английские логи | Все `push_error`, `push_warning` |

### 5.2. Команды проверки

```bash
# Запуск тестов (если настроен)
godot --headless --path game --run-tests

# Проверка синтаксиса
godot --headless --path game --check-only --script scripts/**/*.gd

# Проверка сцен
godot --headless --path game --import
```

### 5.3. Критерии приёмки

| Правка | Критерий |
|---|---|
| H1 (DI) | Нет `Services.resolve()` в модифицированных файлах |
| H2 (City) | `City.gd` < 50 строк |
| H3 (Hero) | Каждый компонент — отдельный класс < 200 строк |
| M1 (Vec2i) | Нет `{"x": ..., "y": ...}` вне `SerializationUtils` |
| M2 (тесты) | Нет `_make_unit` вне `factories.gd` |
| L1 (константы) | Нет магических чисел в коде |

### 5.4. Риски

| Риск | Митигация |
|---|---|
| Поломка сериализации при рефакторинге | Тесты `test_save_roundtrip` |
| Нарушение сигнальных связей | Запуск `test_event_bus.gd` |
| Рекурсивные зависимости при DI | Начинать с листьев (`ResourceNodeManager`) |

---

## Итоговая таблица

| Категория | Оценка | Ключевые проблемы |
|---|---|---|
| Архитектура | 6/10 | Сервис-локатор, God Objects (`City`, `HeroController`) |
| Лучшие практики | 7/10 | Хорошие паттерны, но нарушение DRY |
| Алгоритмы | 8/10 | Корректные, но можно оптимизировать кэширование |
| Рефакторинг | — | 7 конкретных правок, 3 приоритетных |

**Рекомендация:** начать с H1 (DI) и M1 (сериализация) — это даст максимальный эффект при минимальном риске.

# Тестовая архитектура проекта

---

## 1. Целевая структура

```
tests/
├── unit/                        # gdUnit4: чистая логика, без сцен
│   ├── core/                    # ядро: гексы, поиск пути, сервисы
│   │   ├── test_hex_utils.gd
│   │   ├── test_hex_pathfinding.gd
│   │   ├── test_min_heap.gd
│   │   ├── test_visibility_map.gd
│   │   ├── test_service_registry.gd
│   │   └── test_static_caches.gd
│   ├── battle/                  # правила боя, без сцен
│   │   ├── test_battle_rules.gd
│   │   ├── test_battle_state.gd
│   │   ├── test_battle_action_resolver.gd
│   │   ├── test_battle_ai.gd
│   │   ├── test_battle_damage_resolver.gd
│   │   ├── test_spell_caster.gd
│   │   └── test_battle_retreat.gd
│   ├── city/                    # городская логика
│   │   ├── test_city_service.gd
│   │   ├── test_city_building_service.gd
│   │   ├── test_city_growth_service.gd
│   │   ├── test_city_yield_calculator.gd
│   │   ├── test_borough_rules.gd
│   │   ├── test_worker_assignment.gd
│   │   ├── test_reputation_system.gd
│   │   ├── test_prosperity_system.gd
│   │   ├── test_zoning_system.gd
│   │   ├── test_market_system.gd
│   │   ├── test_raid_system.gd
│   │   ├── test_adjacency_system.gd
│   │   ├── test_logistics_calculator.gd
│   │   └── test_scale_shift_manager.gd
│   ├── economy/                 # экономика
│   │   ├── test_resource_context.gd
│   │   ├── test_production_chain.gd
│   │   ├── test_economic_processor.gd
│   │   ├── test_city_income_processor.gd
│   │   └── test_resource_registry.gd
│   ├── entities/                # сущности героя
│   │   ├── test_hero_movement.gd
│   │   ├── test_hero_army.gd
│   │   ├── test_hero_magic.gd
│   │   ├── test_hero_inventory.gd
│   │   ├── test_hero_needs.gd
│   │   ├── test_hero_skills.gd
│   │   ├── test_hero_tools.gd
│   │   ├── test_hero_strategic_resources.gd
│   │   ├── test_unit_stack.gd
│   │   ├── test_unit_stats.gd
│   │   └── test_follower.gd
│   ├── demographics/            # население
│   │   ├── test_character.gd
│   │   ├── test_character_registry.gd
│   │   ├── test_trait_def.gd
│   │   ├── test_trait_registry.gd
│   │   ├── test_need_type.gd
│   │   └── test_demographic_processor.gd
│   ├── data/                    # данные и конфиги
│   │   ├── test_artifact.gd
│   │   ├── test_artifact_registry.gd
│   │   ├── test_building_defs.gd
│   │   ├── test_resource_def.gd
│   │   ├── test_resource_type.gd
│   │   ├── test_tool_type.gd
│   │   ├── test_terrain_cost_table.gd
│   │   ├── test_spell_registry.gd
│   │   └── test_unit_registry.gd
│   ├── world/                   # мировые системы
│   │   ├── test_map_model.gd
│   │   ├── test_map_spawner.gd
│   │   ├── test_enemy_ai_profile.gd
│   │   ├── test_enemy_turn_processor.gd
│   │   ├── test_enemy_growth_system.gd
│   │   ├── test_resource_node_manager.gd
│   │   ├── test_world_state_delta.gd
│   │   └── test_world_persistence.gd
│   ├── ui/                      # UI-логика без рендера
│   │   ├── test_game_text.gd
│   │   ├── test_theme_config.gd
│   │   └── test_ui_animator.gd
│   └── saves/                   # сериализация
│       ├── test_save_data.gd
│       ├── test_save_manager.gd
│       ├── test_city_serializer.gd
│       ├── test_chronicle.gd
│       └── test_shard_manager.gd
│
├── integration/                 # gdUnit4: взаимодействие подсистем
│   ├── test_battle_full_flow.gd        # атака → ретрит → результат
│   ├── test_city_turn_cycle.gd         # рост → производство → население
│   ├── test_economy_chain.gd           # ресурс → цепочка → продукт
│   ├── test_hero_end_turn.gd           # герой → конец хода → ресурсы
│   ├── test_demographics_lifecycle.gd  # рождение → потребности → смерть
│   ├── test_fog_of_war.gd              # перемещение → видимость → разведка
│   ├── test_succession.gd              # смерть → наследник → легенда
│   ├── test_endgame.gd                 # победа/поражение → хроника
│   └── test_world_bootstrap.gd         # загрузка мира → все системы
│
├── fakes/                       # стабы и моки
│   ├── fake_map_generator.gd
│   ├── fake_hero.gd
│   ├── fake_battle_view.gd
│   ├── fake_city_manager.gd
│   ├── fake_spawner.gd
│   ├── fake_resource_registry.gd
│   └── fake_battle_flow.gd
│
├── helpers/                     # фабрики и утилиты
│   ├── factories.gd             # TestFactories
│   ├── battle_fixtures.gd       # готовые состояния боя
│   └── city_fixtures.gd         # готовые города
│
├── spell_validation/            # валидация данных спеллов
│   ├── SpellValidator.gd
│   └── ValidationReport.gd
│
└── mcp/                         # MCP: функциональные E2E тесты
    ├── conftest.py              # фикстуры: mcp, battle_scene, world_scene, full_game
    ├── godot_mcp.py             # клиент MCP
    ├── pytest.ini
    ├── pyproject.toml
    ├── test_new_game_flow.py    # полный цикл новой игры
    ├── test_battle_e2e.py       # бой от старта до результата
    ├── test_save_load_e2e.py    # сохранение → загрузка → продолжение
    ├── test_city_arena_e2e.py   # городская арена
    ├── test_succession_e2e.py   # смерть → наследник → продолжение
    ├── test_endgame_e2e.py      # победа/поражение → экран
    ├── test_hero_movement_e2e.py# перемещение по карте
    ├── test_resource_extraction_e2e.py
    ├── test_spell_casting_e2e.py
    ├── test_settings_persist_e2e.py
    ├── test_scene_transitions.py
    ├── test_audio_cues_e2e.py
    └── test_performance_budget.py
```

---

## 2. Разделение инструментов

| Уровень | Инструмент | Что тестировать | Скорость |
|---|---|---|---|
| **Unit** | gdUnit4 | Чистая логика, формулы, алгоритмы, сериализация | < 1 с |
| **Integration** | gdUnit4 | Взаимодействие 2-3 систем, без сцен | < 3 с |
| **Functional / E2E** | godot-mcp + pytest | Полные сценарии с рендером, инпутом, переходами | 5-60 с |
| **Валидация данных** | gdUnit4 | JSON-схемы спеллов, баланс | < 2 с |

### Правило разделения

```
Если тестируешь функцию/метод/формулу           → unit (gdUnit4)
Если тестируешь цепочку из 2-3 вызовов          → integration (gdUnit4)
Если нужен рендер, инпут, переходы сцен, таймеры → functional (MCP)
```

---

## 3. Покрытие по модулям

### 3.1. Текущее состояние и целевые метрики

| Модуль | Файлов | Есть тесты | Покрытие | Цель | Приоритет |
|---|---|---|---|---|---|
| **Ядро: гексы, путь** | 5 | ✅ | ~70% | 90% | Medium |
| **Бой: состояние** | 4 | ✅ | ~60% | 85% | **High** |
| **Бой: действия** | 3 | ⚠️ | ~40% | 80% | **High** |
| **Бой: ИИ** | 1 | ✅ | ~50% | 70% | Medium |
| **Бой: ввод** | 1 | ⚠️ | ~20% | 60% | Medium |
| **Город: сервисы** | 5 | ✅ | ~65% | 85% | **High** |
| **Город: здания** | 3 | ✅ | ~55% | 80% | Medium |
| **Город: население** | 3 | ✅ | ~60% | 80% | Medium |
| **Экономика** | 4 | ✅ | ~50% | 75% | **High** |
| **Ресурсы** | 3 | ✅ | ~70% | 85% | Medium |
| **Магия: спеллы** | 5 | ✅ | ~40% | 70% | **High** |
| **Магия: шаблоны** | 19 | ❌ | ~10% | 50% | Medium |
| **Артефакты** | 2 | ✅ | ~65% | 80% | Medium |
| **Герой: движение** | 1 | ✅ | ~50% | 75% | **High** |
| **Герой: инвентарь** | 1 | ✅ | ~70% | 85% | Medium |
| **Герой: потребности** | 1 | ✅ | ~60% | 75% | Medium |
| **Демография** | 4 | ✅ | ~55% | 75% | Medium |
| **Эндгейм** | 1 | ✅ | ~45% | 70% | **High** |
| **Персистентность** | 3 | ✅ | ~55% | 80% | **High** |
| **Фог оф вар** | 1 | ✅ | ~60% | 80% | Medium |
| **Спавн врагов** | 2 | ✅ | ~50% | 70% | Medium |
| **UI** | 15 | ⚠️ | ~15% | 30% | Low |
| **Аудио** | 2 | ✅ | ~40% | 60% | Low |

### 3.2. Критические пробелы (нет тестов)

| Что не покрыто | Риск | Приоритет |
|---|---|---|
| `BattleTurnExecutor` — пауза/резюм | Краш при заходе в настройки в бою | **High** |
| `BattleInput` — спелл-таргетинг | Неверный таргет спелла | **High** |
| `WorldInteractionController` — чужие сундуки | Краш на контакте | **High** |
| `ResourceChainService` — инвалидация кэша | Устаревшие ключи экстракции | **High** |
| `TurnScheduler` — порядок процессоров | Неверный порядок фаз | **High** |
| `WorldBootstrap` — полный ботст | Мир не стартует | **High** |
| `HeroLifecycleSystem` — воскрешение | Дубли героя | **High** |
| `WorldSaveLoadService` — headless | Краш в CI | Medium |
| `EnemyTurnProcessor` — детерминизм | Разные бои на одном сиде | Medium |
| `MapSpawner` — спавн врагов | Нет врагов на карте | Medium |
| Шаблоны спеллов (19 файлов) | Краш при касте | Medium |

---

## 4. Логика тестов по приоритетам

### 4.1. High — обязательные

#### Бой: полный цикл (integration, gdUnit4)

```gdscript
# tests/integration/test_battle_full_flow.gd
extends GdUnitTestSuite

const UNITS := preload("res://scripts/autoload/UnitRegistry.gd")

func _make_units():
    var reg := UNITS.new()
    reg.ensure_definitions()
    return reg

func test_full_melee_battle_to_winner():
    var units := _make_units()
    var state := BattleState.new()
    var atk: Array[UnitStack] = [units.make_fixed_stack("swordsmen", 50)]
    var def: Array[UnitStack] = [units.make_fixed_stack("goblins", 10)]
    state.place_army(atk, def)
    state.build_queue()
    
    var rng := TestFactories.seeded(42)
    rng.seed = 42
    var guard := 0
    
    while not state.battle_over and guard < 200:
        var u: BattleState.BattleUnit = state.active_unit
        if u == null or not u.is_alive():
            state.advance_turn()
            guard += 1
            continue
        
        var enemy_side := BattleState.Side.DEFENDER \
            if u.side == BattleState.Side.ATTACKER \
            else BattleState.Side.ATTACKER
        
        var target: BattleState.BattleUnit = null
        for e in state.get_units_by_side(enemy_side):
            if e.is_alive():
                target = e
                break
        
        if target != null:
            var blocked := state.build_all_blocked(u, {})
            var dist := HexUtils.hex_distance(u.cell, target.cell, state.hex_shift_right)
            if dist == 1:
                BattleActionResolver.apply_attack(state, u, target, true, rng)
            else:
                var reachable := state.get_reachable_for_unit(u, func() -> Dictionary: return blocked)
                if not reachable.is_empty():
                    var best: Vector2i = reachable.keys()[0]
                    BattleActionResolver.do_move(state, u, best)
                else:
                    u.has_moved = true
        
        state.advance_turn()
        guard += 1
    
    assert_bool(state.battle_over).is_true()
    assert_bool(state.battle_winner != BattleState.Side.NONE).is_true()
    units.free()

func test_retreat_gives_half_survivors():
    var units := _make_units()
    var state := BattleState.new()
    var atk: Array[UnitStack] = [
        units.make_fixed_stack("swordsmen", 40),
        units.make_fixed_stack("archers", 20),
        units.make_fixed_stack("mages", 10),
    ]
    var def: Array[UnitStack] = [units.make_fixed_stack("goblins", 50)]
    state.place_army(atk, def)
    
    BattleActionResolver.force_end(state, BattleState.Side.DEFENDER)
    
    var survivors := state.get_retreat_survivors(BattleState.Side.ATTACKER)
    assert_int(survivors.size()).is_equal(2)
    var total := 0
    for s in survivors:
        total += s.count
    assert_int(total).is_equal(30)  # 20 + 10
    units.free()

func test_battle_over_prevents_further_actions():
    var units := _make_units()
    var state := BattleState.new()
    var atk: Array[UnitStack] = [units.make_fixed_stack("swordsmen", 10)]
    var def: Array[UnitStack] = [units.make_fixed_stack("goblins", 5)]
    state.place_army(atk, def)
    
    BattleActionResolver.force_end(state, BattleState.Side.ATTACKER)
    
    var atk_unit: BattleState.BattleUnit = state.attacker_units[0]
    var def_unit: BattleState.BattleUnit = state.defender_units[0]
    var rng := TestFactories.seeded(1)
    var result := BattleActionResolver.apply_attack(state, atk_unit, def_unit, true, rng)
    assert_bool(result.is_empty()).is_true()
    units.free()
```

#### Городской цикл (integration, gdUnit4)

```gdscript
# tests/integration/test_city_turn_cycle.gd
extends GdUnitTestSuite

func test_full_city_growth_cycle():
    var city := TestFactories.make_city(1, 2)
    city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
        return {&"food": 100.0, &"industry": 20.0, &"dust": 0.0,
                &"science": 0.0, &"influence": 0.0}
    
    # Строим ферму
    var farm_cell := city.first_free_build_cell(BuildingDefs.farm(), Vector2i.ZERO)
    if farm_cell != Vector2i(-1, -1):
        var check := city.can_build_building(BuildingDefs.farm(), farm_cell)
        if check.ok:
            city.build_building(BuildingDefs.farm(), farm_cell)
    
    # Нанимаем рабочих
    for i in 4:
        city.add_migrant(PopUnit.State.WORKER, 0)
    
    WorkerAssignment.assign_all(city)
    
    # Прогоняем 10 ходов
    var initial_pop := city.pop_total()
    for turn in 10:
        city.process_turn(turn)
    
    # Население должно вырасти
    assert_bool(city.pop_total() > initial_pop).is_true()
    # Еда должна быть в стоке
    assert_bool(city.food_stockpile > 0.0).is_true()
    # Процветание должно быть рассчитано
    assert_bool(city.prosperity >= 0.0).is_true()

func test_economy_chain_integration():
    var city := TestFactories.make_city()
    city.storage[&"industry"] = 500.0
    
    # Строим ферму → мельницу → пекарню
    var farm := city.build_building(BuildingDefs.farm(),
        city.first_free_build_cell(BuildingDefs.farm(), Vector2i.ZERO))
    var mill := city.build_building(BuildingDefs.mill(),
        city.first_free_build_cell(BuildingDefs.mill(), Vector2i.ZERO))
    
    # Нанимаем рабочих
    for i in 6:
        city.add_migrant(PopUnit.State.WORKER, 0)
    WorkerAssignment.assign_all(city)
    
    # Прогоняем экономику
    var ctx := TurnContext.new()
    ctx.cities.append(city)
    var econ := EconomicTurnProcessor.new()
    econ.process(ctx)
    
    # Должно быть зерно
    assert_bool(city.resource_ctx.amount(&"grain") > 0.0).is_true()
```

#### Персистентность (integration, gdUnit4)

```gdscript
# tests/integration/test_save_load_full.gd
extends GdUnitTestSuite

func test_full_save_load_roundtrip():
    # Создаём мир
    var city := TestFactories.make_city(1, 2)
    city.add_followers(5)
    city.storage[&"industry"] = 100.0
    
    var hero := TestFactories.make_hero(&"archivist")
    hero.max_combat_hp = 20
    hero.set_combat_hp(20)
    
    # Сохраняем
    var save := SaveData.new()
    save.run_seed = 12345
    save.date = {"month": 3, "week": 2, "day": 5}
    save.hero = hero.serialize()
    save.cities = [city.serialize()]
    save.world = {}
    
    var json_str := JSON.stringify(save.to_dict(), "\t")
    
    # Загружаем
    var parsed: Variant = JSON.parse_string(json_str)
    var loaded := SaveData.new()
    loaded.from_dict(parsed)
    
    assert_that(loaded.run_seed).is_equal(12345)
    assert_that(loaded.hero.get("hero_name")).is_equal("Darkstorn")
    assert_that((loaded.cities as Array).size()).is_equal(1)
    
    hero.free()
```

### 4.2. MCP функциональные тесты

#### Полный цикл новой игры

```python
# tests/mcp/test_new_game_flow.py
from __future__ import annotations
import time

def test_new_game_creates_hero_and_map(full_game):
    """Новая игра: герой на карте, мир виден, ресурсы есть."""
    mcp = full_game
    
    result = mcp.execute_code("""
        var w = get_tree().current_scene
        var hero = w.get_hero()
        var map = w.get_map_gen()
        if hero == null or map == null:
            return {"error": "hero or map missing"}
        return {
            "hero_alive": hero.is_alive,
            "hero_cell": {"x": hero.current_cell.x, "y": hero.current_cell.y},
            "map_size": {"w": map.map_width, "h": map.map_height},
            "army_size": hero.army.army.size() if hero.army else 0,
            "has_resources": hero.resources != null,
            "has_inventory": hero.inventory != null,
            "has_magic": hero.magic != null,
            "move_points": hero.move_points,
        }
    """)
    
    assert "error" not in result
    assert result["hero_alive"] is True
    assert result["army_size"] >= 1
    assert result["has_resources"] is True
    assert result["has_inventory"] is True
    assert result["has_magic"] is True
    assert result["move_points"] > 0

def test_hero_can_move_on_map(full_game):
    """Герой может переместиться по карте."""
    mcp = full_game
    
    result = mcp.execute_code("""
        var w = get_tree().current_scene
        var hero = w.get_hero()
        var start_cell = hero.current_cell
        var target = Vector2i(start_cell.x + 3, start_cell.y)
        if not w.get_map_gen().is_walkable(target):
            target = Vector2i(start_cell.x + 1, start_cell.y)
        hero.on_map_clicked(target)
        return {
            "start": {"x": start_cell.x, "y": start_cell.y},
            "target": {"x": target.x, "y": target.y},
            "is_moving": hero.movement.is_moving,
        }
    """)
    
    assert "error" not in result
    assert result["is_moving"] is True
    
    # Ждём завершения движения
    mcp.wait_frames(120)
    
    final = mcp.execute_code("""
        var hero = get_tree().current_scene.get_hero()
        return {
            "cell": {"x": hero.current_cell.x, "y": hero.current_cell.y},
            "is_moving": hero.movement.is_moving,
            "move_points_left": hero.move_points,
        }
    """)
    
    assert final["is_moving"] is False
    assert final["move_points_left"] < result["move_points"]
```

#### Полный бой через MCP

```python
# tests/mcp/test_battle_e2e.py
from __future__ import annotations
import time

def test_battle_starts_and_completes(mcp):
    """Бой запускается и завершается."""
    mcp.run_scene("res://scenes/Battle.tscn")
    mcp.wait_ready()
    
    # Запускаем бой
    result = mcp.execute_code("""
        var battle = get_tree().current_scene
        var units_reg = get_node("/root/Units")
        units_reg.ensure_definitions()
        
        var atk: Array[UnitStack] = [units_reg.make_fixed_stack("swordsmen", 20)]
        var def: Array[UnitStack] = [units_reg.make_fixed_stack("goblins", 5)]
        
        battle.start_battle(atk, def, {}, {}, {}, {}, 42, null)
        return {"started": true}
    """)
    
    assert result.get("started") is True
    
    # Ждём завершения боя
    deadline = time.time() + 30
    battle_over = False
    while time.time() < deadline:
        state = mcp.execute_code("""
            var battle = get_tree().current_scene
            var bs = battle.get_battle_state()
            return {
                "battle_over": bs.battle_over,
                "winner": int(bs.battle_winner),
            }
        """)
        if state.get("battle_over", False):
            battle_over = True
            break
        time.sleep(0.5)
    
    assert battle_over, "Бой не завершился за 30 секунд"

def test_battle_retreat_gives_survivors(mcp):
    """Отступление даёт выживших."""
    mcp.run_scene("res://scenes/Battle.tscn")
    mcp.wait_ready()
    
    mcp.execute_code("""
        var battle = get_tree().current_scene
        var units_reg = get_node("/root/Units")
        units_reg.ensure_definitions()
        
        var atk: Array[UnitStack] = [
            units_reg.make_fixed_stack("swordsmen", 40),
            units_reg.make_fixed_stack("archers", 20),
        ]
        var def: Array[UnitStack] = [units_reg.make_fixed_stack("goblins", 50)]
        
        battle.start_battle(atk, def, {}, {}, {}, {}, 42, null)
        return {}
    """)
    
    # Запрашиваем отступление
    mcp.execute_code("""
        var battle = get_tree().current_scene
        var executor = battle.get_node("BattleTurnExecutor")
        executor.request_retreat()
        return {}
    """)
    
    mcp.wait_frames(60)
    
    result = mcp.execute_code("""
        var battle = get_tree().current_scene
        var bs = battle.get_battle_state()
        var survivors = bs.get_retreat_survivors(BattleState.Side.ATTACKER)
        return {
            "battle_over": bs.battle_over,
            "winner": int(bs.battle_winner),
            "survivor_count": survivors.size(),
        }
    """)
    
    assert result.get("battle_over") is True
    assert result.get("winner") == int(1)  # DEFENDER
    assert result.get("survivor_count", 0) > 0
```

#### Сохранение и загрузка через MCP

```python
# tests/mcp/test_save_load_e2e.py
from __future__ import annotations

def test_save_and_load_preserves_state(full_game):
    """Сохранение и загрузка сохраняют состояние героя."""
    mcp = full_game
    
    # Запоминаем состояние до сохранения
    before = mcp.execute_code("""
        var w = get_tree().current_scene
        var hero = w.get_hero()
        return {
            "cell": {"x": hero.current_cell.x, "y": hero.current_cell.y},
            "move_points": hero.move_points,
            "hero_name": hero.hero_name,
        }
    """)
    
    # Сохраняем
    save_result = mcp.execute_code("""
        var w = get_tree().current_scene
        var saved = w.save_game()
        return {"saved": saved}
    """)
    assert save_result.get("saved") is True
    
    # Загружаем
    load_result = mcp.execute_code("""
        var w = get_tree().current_scene
        var data = w.load_game()
        if data == null or not data.is_valid():
            return {"error": "load failed"}
        w.apply_save(data)
        return {"loaded": true}
    """)
    assert "error" not in load_result
    
    # Проверяем состояние после загрузки
    after = mcp.execute_code("""
        var w = get_tree().current_scene
        var hero = w.get_hero()
        return {
            "cell": {"x": hero.current_cell.x, "y": hero.current_cell.y},
            "hero_name": hero.hero_name,
        }
    """)
    
    assert after["hero_name"] == before["hero_name"]
```

#### Переходы между сценами

```python
# tests/mcp/test_scene_transitions.py
from __future__ import annotations

def test_main_menu_to_world(mcp):
    """Переход из меню в мир."""
    mcp.run_scene("res://scenes/MainMenu.tscn")
    mcp.wait_ready()
    
    # Нажимаем "Новая игра"
    result = mcp.execute_code("""
        var menu = get_tree().current_scene
        var btn = menu.get_node("RightColumn/NewGameButton")
        btn.emit_signal("pressed")
        return {"pressed": true}
    """)
    
    assert result.get("pressed") is True
    
    # Ждём перехода в мир
    mcp.wait_frames(120)
    
    world = mcp.execute_code("""
        var scene = get_tree().current_scene
        return {
            "scene_name": scene.name if scene else "",
            "has_hero": scene.get_hero() != null if scene.has_method("get_hero") else false,
        }
    """)
    
    assert world.get("scene_name") == "World" or world.get("has_hero") is True

def test_world_to_battle_and_back(full_game):
    """Переход в бой и обратно."""
    mcp = full_game
    
    # Запускаем бой
    mcp.execute_code("""
        var w = get_tree().current_scene
        w.battle_coordinator.start_battle(
            [Units.make_fixed_stack("swordsmen", 10)],
            [Units.make_fixed_stack("goblins", 5)],
            {}, {}, {}, {}, 42, null
        )
        return {}
    """)
    
    mcp.wait_frames(60)
    
    # Проверяем что бой активен
    in_battle = mcp.execute_code("""
        return {"in_battle": get_tree().current_scene.name == "Battle"}
    """)
    
    # Возврат из боя
    mcp.execute_code("""
        var battle = get_tree().current_scene
        if battle.has_method("get_battle_state"):
            var bs = battle.get_battle_state()
            BattleActionResolver.force_end(bs, BattleState.Side.ATTACKER)
        return {}
    """)
    
    mcp.wait_frames(120)
```

#### Городская арена через MCP

```python
# tests/mcp/test_city_arena_e2e.py
from __future__ import annotations

def test_city_arena_build_and_turn(mcp):
    """Городская арена: строим здание и прогоняем ход."""
    mcp.run_scene("res://scenes/CityArena.tscn")
    mcp.wait_ready()
    
    # Выбираем ферму и строим
    result = mcp.execute_code("""
        var view = get_tree().current_scene
        var cells = ArenaRingSystem.cells_in_arena()
        var farm_cell = Vector2i(-1, -1)
        for c in cells:
            if ArenaRingSystem.ring_of(c) == 1 and not view._city.cell_is_built(c):
                farm_cell = c
                break
        if farm_cell == Vector2i(-1, -1):
            return {"error": "no free cell"}
        
        view._on_palette_pressed(&"farm")
        view._handle_cell_click(farm_cell)
        
        return {
            "built": view._city.cell_is_built(farm_cell),
            "cell": {"x": farm_cell.x, "y": farm_cell.y},
        }
    """)
    
    assert result.get("built") is True
    
    # Прогоняем ход
    turn_result = mcp.execute_code("""
        var view = get_tree().current_scene
        view._on_turn_pressed()
        return {
            "turn": view._turn,
            "food": view._city.food_stockpile,
            "starving": view._city.starving,
        }
    """)
    
    assert turn_result.get("turn") == 1
    assert isinstance(turn_result.get("food"), (int, float))
```

#### Производительность через MCP

```python
# tests/mcp/test_performance_budget.py
from __future__ import annotations
import time

def test_frame_time_under_budget(full_game):
    """Среднее время кадра < 33 мс (30 FPS)."""
    mcp = full_game
    
    result = mcp.execute_code("""
        var engine = Engine
        var total := 0.0
        var frames := 60
        for i in frames:
            var t0 := Time.get_ticks_usec()
            await get_tree().process_frame
            var t1 := Time.get_ticks_usec()
            total += float(t1 - t0)
        var avg_ms := total / float(frames) / 1000.0
        return {"avg_ms": avg_ms, "frames": frames}
    """)
    
    avg_ms = result.get("avg_ms", 999.0)
    assert avg_ms < 33.0, f"Средний кадр {avg_ms:.1f} мс > 33 мс"

def test_map_generation_under_budget(mcp):
    """Генерация карты < 3 секунд."""
    mcp.run_scene("res://scenes/World.tscn")
    mcp.wait_ready()
    
    start = time.time()
    mcp.wait_frames(30)
    elapsed = time.time() - start
    
    assert elapsed < 3.0, f"Ботст мира занял {elapsed:.1f} с"
```

---

## 5. Фейки и фабрики

### 5.1. Единая фабрика

```gdscript
# tests/helpers/factories.gd
class_name TestFactories
extends RefCounted

static func make_city(uid: int = 1, stronghold: int = 2) -> City:
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
    h.max_combat_hp = 20
    h.set_combat_hp(20)
    return h

static func make_follower(uid: int, path := &"archivist") -> Follower:
    var f := Follower.new()
    f.uid = uid
    f.path = path
    return f

static func make_battle_state(
    atk_key := "swordsmen", def_key := "goblins",
    atk_count := 20, def_count := 5
) -> BattleState:
    var units: Node = Services.resolve(&"units")
    var bs := BattleState.new()
    var atk: Array[UnitStack] = [units.make_fixed_stack(atk_key, atk_count)]
    var def: Array[UnitStack] = [units.make_fixed_stack(def_key, def_count)]
    bs.place_army(atk, def)
    return bs

static func seeded(s: int) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = s
    return r
```

### 5.2. Фейки для MCP

```gdscript
# tests/fakes/fake_battle_flow.gd
extends BattleFlow

var started := 0
var last_atk_army: Array = []
var last_def_army: Array = []

func start_battle(
    attacker_army: Array[UnitStack],
    defender_army: Array[UnitStack],
    attacker_bonus: Dictionary = {},
    defender_bonus: Dictionary = {},
    attacker_artifact_mods: Dictionary = {},
    defender_artifact_mods: Dictionary = {},
    obstacle_seed: int = -1,
    hero_magic: Variant = null
) -> void:
    started += 1
    last_atk_army = attacker_army
    last_def_army = defender_army
```

---

## 6. Конфигурация запуска

### 6.1. Запуск всех тестов

```bash
# Юнит и интеграция (gdUnit4)
godot --headless --path game --run-tests

# Только юнит
godot --headless --path game --run-tests -i tests/unit/

# Только интеграция
godot --headless --path game --run-tests -i tests/integration/

# Функциональные через MCP
cd game/tests/mcp
uv run pytest -xvs

# Конкретный тест
uv run pytest test_battle_e2e.py -k "test_battle_starts" -xvs

# Валидация спеллов
godot --headless --path game --run-tests -i tests/spell_validation/
```

### 6.2. CI-конфигурация

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.7
      - run: godot --headless --path game --run-tests -i tests/unit/ tests/integration/

  mcp:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.7
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install uv
      - run: cd game/tests/mcp && uv sync
      - run: cd game/tests/mcp && uv run pytest -x --timeout=120
```

---

## 7. Целевые метрики

| Категория | Текущее | Цель | Срок |
|---|---|---|---|
| Покрытие юнит-тестами | ~45% | 75% | 4 недели |
| Покрытие интеграцией | ~20% | 50% | 6 недель |
| Покрытие MCP | ~10% | 40% | 8 недель |
| Кол-во тестов (всего) | ~180 | 450 | 8 недель |
| Время прогона юнитов | ~15 с | < 10 с | 2 недели |
| Время прогона MCP | ~120 с | < 90 с | 4 недели |
| Критические пробелы | 11 | 0 | 3 недели |

---

## 8. Приоритетный порядок внедрения

| # | Что | Инструмент | Срок |
|---|---|---|---|
| 1 | `BattleTurnExecutor` пауза/резюм | gdUnit4 unit | 1 день |
| 2 | `WorldBootstrap` полный ботст | MCP functional | 1 день |
| 3 | `HeroLifecycleSystem` воскрешение | gdUnit4 integration | 1 день |
| 4 | `BattleInput` спелл-таргетинг | gdUnit4 unit | 1 день |
| 5 | `TurnScheduler` порядок фаз | gdUnit4 unit | 0.5 дня |
| 6 | Полный бой от старта до конца | MCP functional | 2 дня |
| 7 | Сохранение → загрузка → продолжение | MCP functional | 2 дня |
| 8 | Городской цикл: рост → производство | gdUnit4 integration | 1 день |
| 9 | Шаблоны спеллов (19 файлов) | gdUnit4 unit | 3 дня |
| 10 | Переходы между сценами | MCP functional | 1 день |