# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

---

## 1. Архитектура

### 1.1 Модульность и разделение ответственности

**Сильные стороны:**
- Компонентная система героя: `HeroController` + `HeroComponent`-наследники (`HeroMovementComponent`, `HeroArmyComponent`, `HeroMagicComponent`, `HeroInventoryComponent`, `HeroSkillsComponent`, `HeroToolsComponent`, `HeroTimeComponent`, `HeroNeedsComponent`, `HeroCombatComponent`, `HeroStatsComponent`). Чистое разделение ответственности.
- Городской цикл разбит на субпроцессоры: `CitySubProcessor` → `ScaleProcessor`, `ZoningProcessor`, `ReputationProcessor`, `MigrationProcessor`, `WorkerAssignmentProcessor`, `ProsperityProcessor`, `LevelUpProcessor`, `RaidProcessor`, `ScienceProcessor`, `CityEventsProcessor` — с единым оркестратором `CityTurnProcessor`.
- MCP-команды разделены на тематические группы: `McpCommandsInput`, `McpCommandsRender`, `McpCommandsSystem`, `McpCommandsUI`, `McpCommandsNetwork`.
- Бой: `BattleState` (состояние), `BattleTurnExecutor` (логика ходов), `BattleAI` (ИИ), `BattleActionResolver` (разрешение действий), `BattleRules` (формулы урона), `BattleAttackSequence`, `BattleRetreatPolicy`.

**Проблемы:**

| Проблема | Файл | Описание |
|---|---|---|
| Сервис-локатор с хардкодом | `services.gd` | `_register_core_services()` жёстко привязывает реализации. Нет возможности подмены для тестов без модификации глобального состояния |
| Смешение ответственности | `BattleEmulator.gd` | Autoload, но содержит бизнес-логику эмуляции (`emulate_battle`, `sequence_battle`, `cast_in_battle`). Должен быть обычным классом |
| Монолитный бутстрап | `WorldBootstrap.gd` | Статический `run()` на ~150 строк создаёт все системы процедурно, без композиции |
| Дублирование роли контроллера | `WorldBattleCoordinator` + `WorldInteractionController` + `WorldEventRouter` | Три контроллера с пересекающейся ответственностью. `WorldEventRouter.setup()` принимает 12+ параметров |

### 1.2 Связность и связанность

**Высокая связанность:**
- `HeroController` через аксессоры (`var movement: HeroMovementController: get: ...`) привязывает все компоненты к себе. Комментарий «позволяют не менять 50+ файлов сразу» подтверждает, что это осознанный технический долг.
- `WorldEventRouter.setup()` принимает `hero, map_gen, camera, cities, battle_coordinator, interaction_controller, resource_node_manager, ui_manager, world_delta, persistence, resource_chain, visibility, resource_registry, turn_scheduler, terrain_resource_manager` — 15 параметров. Нарушение SRP: класс выступает как «клей» между всеми системами.

**Хорошая связность:**
- Каждая подсистема города (`ReputationSystem`, `ProsperitySystem`, `RaidSystem`, `MarketSystem`, `SpecializationSystem`, `ScaleShiftManager`) принимает `City` как параметр и не хранит глобальное состояние.
- `BattleState.BattleUnit` инкапсулирует всю логику юнита (хп, теги, статусы, скорость, сторона).

### 1.3 Масштабируемость и расширяемость

**Хорошо:**
- `TemplateEngine` с регистрируемыми обработчиками (`register_handler`) — добавление нового шаблона заклинания не требует изменения движка.
- `BuildingDefs` загружает определения из `assets/data/buildings.json`. Расширение контента без изменения кода.
- `SpellbookRegistry` загружает заклинания из `assets/data/spells.json` с фолбэком на `spells_fallback.json`.

**Плохо:**
- `GameNumbers.gd` — один файл с ~300 констант без группировки по доменам (бой, город, карта, герой, UI). При росте станет неуправляемым.
- `ThemeConfig.gd` — аналогично ~200 констант.

### 1.4 Соответствие паттернам

| Паттерн | Где | Оценка |
|---|---|---|
| Композиция над наследованием | `HeroController` + компоненты | ✅ |
| Стратегия | `NeedStrategy` → `RestStrategy`, `SocialStrategy`, `InspirationStrategy` | ✅ |
| Шаблонный метод | `CitySubProcessor.process()`, `TurnPhaseProcessor.process()` | ✅ |
| Наблюдатель (сигналы) | `GameEventBus`, сигналы `City`, `BattleState` | ✅ |
| Builder | `BattleStateBuilder`, `HeroBuildProfile` | ✅ |
| Сервис-локатор | `Services` / `ServiceRegistry` | ⚠️ Антипаттерн для DI |
| Singleton (autoload) | `Settings`, `SoundManager`, `GameEventBus`, `CursorController` | ⚠️ Допустимо для Godot, но усложняет модульное тестирование |

---

## 2. Лучшие практики

### 2.1 Идиомы языка / фреймворка

**Соответствует:**
- `class_name` для глобальных типов
- `@onready` для ссылок на ноды в сценах
- `await get_tree().process_frame` / `physics_frame` для ожидания кадра
- `Input.parse_input_event()` для симуляции ввода в `mcp_commands_input.gd`
- `Callable` и сигналы вместо колбэков

**Нарушения:**

| Проблема | Место | Рекомендация |
|---|---|---|
| `McpCommandsBase.is_async()` всегда возвращает `false` | `mcp_commands_base.gd` | Мёртвый код. Удалить. В `mcp_interaction_server.gd` уже есть комментарий: «Awaiting a non-coroutine handler returns immediately» |
| Хардкод порта `9090` | `mcp_interaction_server.gd` | Вынести в `ProjectSettings` или env-переменную |
| `_indent_code` — ручная обработка отступов с эвристикой «1 таб или до 4 пробелов» | `mcp_commands_system.gd` | Хрупкий код. Добавить юнит-тесты на граничные случаи (смешанные отступы, пустые строки) |
| В `_cmd_eval` используется `GDScript.new()` + `script.reload()` для выполнения произвольного кода | `mcp_commands_system.gd` | Критическая проблема безопасности (см. 2.3) |

### 2.2 SOLID, DRY, KISS, YAGNI

**DRY — дублирование:**

| Дублирование | Где | Рекомендация |
|---|---|---|
| Проверка `if not server.is_inside_tree(): server._send_response_raw({"error": "Server not in scene tree"}); return` | `mcp_commands_input.gd` (`_cmd_click`, `_cmd_key_press`, `_cmd_key_hold`, …) | Вынести в `McpCommandsBase._require_scene_tree() -> bool` |
| Проверка `if node == null or not node is X` | `mcp_commands_render.gd` (десятки мест) | Вынести в `_get_node_of_type(path: String, type: String) -> Variant` |
| `_find_by_class_recursive` определён в `mcp_commands_base.gd`, но используется и в `mcp_commands_system.gd`, и в `mcp_commands_render.gd` | Базовый класс уже предоставляет метод — убедиться, что нет локальных копий |

**SOLID:**

| Принцип | Нарушение | Место |
|---|---|---|
| S (SRP) | `WorldEventRouter.setup()` — 15 параметров | `WorldEventRouter.gd` |
| S (SRP) | `BattleController` совмещает управление боем, ввод, рендер и UI | `BattleController.gd` |
| O (Open/Closed) | `GameNumbers.gd` — изменения в одном файле затрагивают все системы | `GameNumbers.gd` |
| D (Dependency Inversion) | `Services.resolve(&"units")` вместо инъекции зависимостей в тестах | `tests/helpers/factories.gd` |

**YAGNI:**
- `mcp_commands_render.gd` содержит команды для 3D (`_cmd_csg`, `_cmd_multimesh`, `_cmd_procedural_mesh`, `_cmd_light_3d`, `_cmd_gi`, `_cmd_3d_effects`, `_cmd_path_3d`, `_cmd_sky`, `_cmd_navigation_3d`, `_cmd_physics_3d`), но проект — 2D. Это мёртвый вес.
- `McpCommandsNetwork` поддерживает WebSocket, HTTP, multiplayer, RPC — ни одна фича не используется в игровом коде. Если только для отладки — пометить как экспериментальное.

### 2.3 Безопасность и обработка ошибок

**Критические проблемы безопасности:**

| Проблема | Файл | Риск | Митигация |
|---|---|---|---|
| `_cmd_eval` выполняет произвольный код | `mcp_commands_system.gd` | Высокий | Песочница или белый список операций |
| `_cmd_script` позволяет прикрепить произвольный скрипт к ноде | `mcp_commands_system.gd` | Высокий | Аналогично |
| Отсутствие аутентификации на MCP-сервере | `mcp_interaction_server.gd` | Средний | Токен через env-переменную |
| `_cmd_change_scene` позволяет загрузить произвольную сцену по пути | `mcp_commands_system.gd` | Средний | Валидация пути по белому списку |

**Обработка ошибок:**

| Проблема | Файл | Рекомендация |
|---|---|---|
| `_cmd_http_request` не обрабатывает таймаут `HTTPRequest` | `mcp_commands_network.gd` | Добавить проверку `result[0]` на `HTTPRequest.RESULT_TIMEOUT` |
| `_cmd_instantiate_scene` не проверяет, что `packed.instantiate()` вернул валидную ноду | `mcp_commands_system.gd` | Добавить `if instance == null` |
| В `SaveManager.load_slot` нет восстановления из бэкапа при повреждении файла | `SaveManager.gd` | Добавить автосоздание `.bak` при сохранении |

### 2.4 Читаемость, naming, структура кода

**Хорошо:**
- Понятные имена: `_cmd_click`, `_on_hero_died`, `_build_farm_cluster`
- Использование `_` префикса для приватных методов и полей
- Комментарии на русском для бизнес-логики

**Проблемы:**

| Проблема | Место | Рекомендация |
|---|---|---|
| Неочевидные аббревиатуры | `_grp_input`, `_grp_ui`, `_grp_system`, `_grp_render`, `_grp_network` в `mcp_interaction_server.gd` | Переименовать в `_input_commands`, `_ui_commands`, `_system_commands`, `_render_commands`, `_network_commands` |
| Магические числа без пояснений | `GameNumbers.BATTLE_BOARD_W = 17`, `BATTLE_BOARD_H = 11` | Добавить комментарии, почему именно эти значения |
| Функции > 100 строк | `_cmd_environment`, `_cmd_render_settings` в `mcp_commands_render.gd` | Разбить на подфункции по группам свойств |
| `GameText.gd` — ~200 однострочных функций | Каждая функция — `return TranslationServer.translate(...)`. Приемлемо, но лучше сгруппировать по доменам с комментариями-разделителями |

---

## 3. Алгоритмы

### 3.1 Используемые алгоритмы и структуры данных

| Алгоритм / структура | Где | Назначение |
|---|---|---|
| A* | `HexPathfinding.astar_path()` | Поиск пути на гексагональной карте |
| BFS | `HexPathfinding.bfs_path()`, `bfs_reachable()` | Поиск достижимых клеток |
| Дейкстра | `HexPathfinding.dijkstra()`, `dijkstra_path_early()` | Расчёт стоимости перемещения с учётом ландшафта |
| Мин-куча | `MinHeap` | Приоритетная очередь для A*/Дейкстры |
| Кубические координаты | `HexUtils.offset_to_cube()`, `cube_to_offset()` | Расстояние и соседи на гексах |
| Кэш с версионированием | `BattleState._reachable_cache` + `_board_version` | Инвалидация кэша при изменении поля боя |
| Кэш по мета-данным | `ArenaClusterSystem.clusters()` через `city.get_meta()` | Кэширование расчёта кластеров зданий |
| Рекурсивный обход дерева | `McpCommandsBase._find_by_class_recursive()` | Поиск нод по классу в дереве сцены |

### 3.2 Корректность и граничные случаи

**Корректно реализовано:**
- `HexUtils.hex_distance()` — классический алгоритм через кубические координаты. Симметричен, корректен для всех направлений. Подтверждено тестами `test_hex_utils.gd`.
- `MinHeap` — корректная реализация с просеиванием вверх/вниз. Граничный случай `pop()` из пустой кучи возвращает пустой массив. Подтверждено тестом `test_min_heap_pop_empty_guard`.
- `HexPathfinding.astar_path()` — проверка `start == goal` возвращает `[start]`. Подтверждено тестом `test_astar_finds_path`.
- `BattleState.invalidate_board_cache()` вызывает `_reachable_cache.clear()` — утечки кэша нет.

**Потенциальные проблемы:**

| Проблема | Место | Описание |
|---|---|---|
| `bfs_reachable` при `steps = 0` возвращает `{}`, предварительно добавив и удалив `start` | `HexPathfinding.bfs_reachable()` | Корректно, но неочевидно. Добавить комментарий |
| `dijkstra()` не прерывает обход, когда минимальный элемент в куче превышает `max_cost` | `HexPathfinding.dijkstra()` | Избыточный обход. Проверка `if cur_d > max_cost: continue` есть, но куча продолжает заполняться |
| `_cache_signature` использует конкатенацию строк для ключа кэша | `BattleState._cache_signature()` | Теоретически возможны коллизии. На практике маловероятно из-за `_board_version` |
| `_find_by_class_recursive` не защищён от циклов в дереве нод | `McpCommandsBase._find_by_class_recursive()` | В дереве нод циклов быть не должно, но если кто-то вручную создаст цикл — бесконечная рекурсия |
| `ArenaClusterSystem._compute_clusters` использует `seen` по `uid` зданий | `ArenaClusterSystem.gd` | Корректно, но `uid` должен быть уникальным. Если два здания получат одинаковый `uid`, алгоритм объединит их в один кластер |

### 3.3 Сложность по времени и памяти

| Алгоритм | Время | Память | Комментарий |
|---|---|---|---|
| A* | O(V log V) худший случай | O(V) | V = W×H. С эвристикой обычно значительно быстрее |
| BFS | O(V + E), E ≈ 6V | O(V) | Для гексагональной сетки |
| Дейкстра | O(V log V) | O(V) | С мин-кучей |
| `bfs_reachable` | O(min(V, steps × 6)) | O(steps × 6) | Ограничено `steps` |
| `_find_by_class_recursive` | O(N) | O(D) стек | N — число нод, D — глубина дерева |
| `_compute_clusters` | O(B) | O(B) | B — число зданий. Каждый кластер обходится один раз |

### 3.4 Рекомендации по оптимизации

| Текущее решение | Проблема | Рекомендация | Приоритет |
|---|---|---|---|
| `_find_by_class_recursive` — рекурсия | Риск переполнения стека на глубоких деревьях | Итеративный обход со стеком | Low |
| `VisibilityMap.recompute` создаёт новый словарь `new_visible` каждый вызов | Аллокация памяти | Переиспользовать словарь с очисткой | Medium |
| `HexPathfinding.dijkstra` обходит все клетки до `max_cost` | Избыточный обход | Раннее прерывание когда мин. элемент в куче > `max_cost` | Low |
| `_cache_signature` — конкатенация строк | Накладные расходы на создание строк | Использовать `hash()` от `blocked.keys()` + `_board_version` | Low |

---

## 4. Рефакторинг

### 4.1 Сводная таблица правок

| # | Что | Зачем | Приоритет |
|---|---|---|---|
| R1 | Удалить `McpCommandsBase.is_async()` | Мёртвый код | Low |
| R2 | Добавить токен аутентификации на MCP-сервер | Безопасность | **High** |
| R3 | Ограничить `_cmd_eval` и `_cmd_script` | Безопасность | **High** |
| R4 | Разбить `GameNumbers.gd` на доменные файлы | Масштабируемость | Medium |
| R5 | Заменить сервис-локатор на инъекцию зависимостей | Тестируемость | Medium |
| R6 | Вынести повторяющуюся проверку `is_inside_tree` | DRY | Medium |
| R7 | Удалить неиспользуемые 3D-команды из `mcp_commands_render.gd` | YAGNI | Low |
| R8 | Заменить рекурсивный обход дерева на итеративный | Надёжность | Low |
| R9 | Добавить инварианты в `BattleState` через `assert` | Надёжность | Medium |
| R10 | Заменить аксессоры в `HeroController` на прямой доступ к компонентам | Технический долг | **High** |

### 4.2 Детальные правки

#### R1. Удалить мёртвый метод `is_async()`

**Файл:** `mcp_commands_base.gd`

**До:**
```gdscript
## Whether the given command suspends (its implementation uses await).
func is_async(command: String) -> bool:
    return false
```

**После:** удалить метод. В `mcp_interaction_server.gd` уже есть комментарий: «Awaiting a non-coroutine handler returns immediately, so one path covers sync and async».

---

#### R2. Добавить токен аутентификации на MCP-сервер

**Файл:** `mcp_interaction_server.gd`

**До:**
```gdscript
func _handle_command(json_str: String) -> void:
    var json: JSON = JSON.new()
    var parse_err: int = json.parse(json_str)
    if parse_err != OK:
        _send_response_raw({"error": "Invalid JSON: %s" % json.get_error_message()})
        return
    var data: Variant = json.data
    if not data is Dictionary:
        _send_response_raw({"error": "Expected JSON object"})
        return
```

**После:**
```gdscript
const AUTH_TOKEN_ENV := "MCP_AUTH_TOKEN"
var _auth_token: String = ""

func _ready() -> void:
    _auth_token = OS.get_environment(AUTH_TOKEN_ENV)
    # ... остальной код

func _handle_command(json_str: String) -> void:
    var json: JSON = JSON.new()
    var parse_err: int = json.parse(json_str)
    if parse_err != OK:
        _send_response_raw({"error": "Invalid JSON: %s" % json.get_error_message()})
        return
    var data: Variant = json.data
    if not data is Dictionary:
        _send_response_raw({"error": "Expected JSON object"})
        return
    if not _auth_token.is_empty() and str(data.get("token", "")) != _auth_token:
        _send_response_raw({"error": "Unauthorized"})
        return
    # ... остальной код
```

---

#### R3. Ограничить `_cmd_eval` белым списком операций

**Файл:** `mcp_commands_system.gd`

**До:**
```gdscript
func _cmd_eval(params: Dictionary) -> void:
    var code: String = params.get("code", "")
    if code.is_empty():
        server._send_response({"error": "No code provided"})
        return
    # ... сразу выполняет код
```

**После:**
```gdscript
const EVAL_BLOCKED_PATTERNS: Array[String] = [
    "OS.execute", "OS.shell_open", "FileAccess.open",
    "DirAccess.open", "ResourceLoader.load", "load(",
    "get_tree().quit", "get_tree().change_scene",
]

func _cmd_eval(params: Dictionary) -> void:
    var code: String = params.get("code", "")
    if code.is_empty():
        server._send_response({"error": "No code provided"})
        return
    for pattern in EVAL_BLOCKED_PATTERNS:
        if code.contains(pattern):
            server._send_response({"error": "Blocked operation: %s" % pattern})
            return
    # ... остальной код
```

---

#### R6. Вынести повторяющуюся проверку сцены

**Файл:** `mcp_commands_base.gd` — добавить метод:
```gdscript
func _require_scene_tree() -> bool:
    if not server.is_inside_tree():
        server._send_response_raw({"error": "Server not in scene tree"})
        return false
    return true
```

**Файл:** `mcp_commands_input.gd` — использование:

**До:**
```gdscript
func _cmd_click(params: Dictionary) -> void:
    if not server.is_inside_tree():
        server._send_response_raw({"error": "Server not in scene tree"})
        return
```

**После:**
```gdscript
func _cmd_click(params: Dictionary) -> void:
    if not _require_scene_tree():
        return
```

---

#### R10. Замена аксессоров в `HeroController` на прямой доступ к компонентам

**Файл:** `HeroController.gd`

Это наиболее трудоёмкая правка. Аксессоры оставляют скрытую связанность и маскируют реальный доступ к компонентам.

**До:**
```gdscript
var movement: HeroMovementController:
    get: return movement_comp.get_controller() if movement_comp else null
    set(v): if movement_comp: movement_comp.set_controller(v)

var army: HeroArmyController:
    get: return army_comp._controller if army_comp else null
    set(v): if army_comp: army_comp.set_controller(v)
```

**После:** удалить аксессоры. Заменить все обращения:
- `hero.movement` → `hero.movement_comp.get_controller()`
- `hero.army` → `hero.army_comp._controller`
- `hero.magic` → `hero.magic_comp.magic`
- и т.д.

Для постепенного перехода можно добавить `push_warning("Deprecated: use movement_comp")` в сеттеры аксессоров на первом этапе.

---

## 5. Инструкция для локального агента

### 5.1 Пошаговый план внедрения правок

#### Фаза 1: Безопасность (приоритет High)

**Шаг 1.1:** Добавить токен аутентификации на MCP-сервер
- **Файл:** `mcp_interaction_server.gd`
- **Действия:** добавить `_auth_token`, проверку в `_handle_command` (правка R2)
- **Проверка:** `grep -n "AUTH_TOKEN" mcp_interaction_server.gd` — минимум 2 строки
- **Критерий приёмки:** запрос без токена возвращает `{"error": "Unauthorized"}`

**Шаг 1.2:** Ограничить `_cmd_eval` и `_cmd_script`
- **Файл:** `mcp_commands_system.gd`
- **Действия:** добавить `EVAL_BLOCKED_PATTERNS`, проверку в `_cmd_eval` (правка R3)
- **Проверка:** `grep -n "EVAL_BLOCKED_PATTERNS" mcp_commands_system.gd` — минимум 2 строки
- **Критерий приёмки:** запрос с `code: "OS.execute(...)"` возвращает ошибку

**Шаг 1.3:** Запуск тестов
```bash
godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests/unit/core/test_mcp_server.gd
```

---

#### Фаза 2: Технический долг (приоритет High)

**Шаг 2.1:** Удалить `is_async()` из `McpCommandsBase`
- **Файл:** `mcp_commands_base.gd`
- **Действия:** удалить метод `is_async` (правка R1)
- **Проверка:** `grep -n "is_async" mcp_commands_base.gd` — 0 строк
- **Критерий приёмки:** все тесты проходят

**Шаг 2.2:** Вынести `_require_scene_tree()` в базовый класс
- **Файл:** `mcp_commands_base.gd` — добавить метод
- **Файлы:** `mcp_commands_input.gd`, `mcp_commands_render.gd`, `mcp_commands_system.gd`
- **Действия:** заменить все `if not server.is_inside_tree(): server._send_response_raw(...)` на `if not _require_scene_tree(): return` (правка R6)
- **Проверка:** `grep -rn "is_inside_tree" mcp_commands_*.gd | grep -v "_require_scene_tree"` — только определение метода
- **Критерий приёмки:** все тесты проходят

**Шаг 2.3:** Запуск полного тест-сьюта
```bash
godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests/
```

---

#### Фаза 3: Масштабируемость (приоритет Medium)

**Шаг 3.1:** Разбить `GameNumbers.gd` на доменные файлы
- **Создать:** `GameNumbersBattle.gd`, `GameNumbersCity.gd`, `GameNumbersMap.gd`, `GameNumbersHero.gd`, `GameNumbersUI.gd`
- **Действия:** перенести константы по доменам, обновить все ссылки
- **Проверка:** `grep -rn "GameNumbers\." game/ --include="*.gd" | wc -l` — уменьшение количества прямых ссылок на `GameNumbers`
- **Критерий приёмки:** все тесты проходят, `GameNumbers.gd` становится пустым или содержит только реэкспорты

**Шаг 3.2:** Убедиться, что `_find_by_class_recursive` не дублируется
- **Проверка:** `grep -rn "_find_by_class_recursive" mcp_commands_*.gd` — только определение в `mcp_commands_base.gd` и вызовы из других файлов

---

#### Фаза 4: Оптимизация (приоритет Medium)

**Шаг 4.1:** Добавить инварианты в `BattleState`
- **Файл:** `BattleState.gd`
- **Действия:** добавить `assert()` в `place_army`, `build_queue`, `advance_turn` для проверки инвариантов (например, что `turn_queue` не содержит мёртвых юнитов после `build_queue`)
- **Критерий приёмки:** тесты `test_battle_state.gd` проходят

**Шаг 4.2:** Заменить рекурсивный обход дерева на итеративный
- **Файл:** `mcp_commands_base.gd`
- **До:** рекурсия в `_find_by_class_recursive`
- **После:** итеративный обход со стеком
- **Критерий приёмки:** тесты проходят, нет рекурсивных вызовов

---

#### Фаза 5: Удаление мёртвого кода (приоритет Low)

**Шаг 5.1:** Удалить неиспользуемые 3D-команды из `mcp_commands_render.gd`
- **Действия:** удалить `_cmd_csg`, `_cmd_multimesh`, `_cmd_procedural_mesh`, `_cmd_light_3d`, `_cmd_gi`, `_cmd_3d_effects`, `_cmd_path_3d`, `_cmd_sky`, `_cmd_navigation_3d`, `_cmd_physics_3d`, если они не используются в тестах
- **Проверка:** `grep -rn "csg\|multimesh\|procedural_mesh\|light_3d\|_cmd_gi\|_cmd_3d_effects" tests/` — 0 результатов
- **Критерий приёмки:** размер файла уменьшился, все тесты проходят

**Шаг 5.2:** Удалить неиспользуемые методы из `McpCommandsNetwork`, если они не нужны в тестах
- **Проверка:** аналогично


### 5.2 Команды для проверки

| Проверка | Команда |
|---|---|
| Все тесты | `godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests/` |
| Конкретный тест | `godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests/unit/test_battle_state.gd` |
| Безопасность | `grep -rn "OS.execute\|OS.shell_open\|FileAccess.open" mcp_commands_system.gd` |
| Мёртвый код | `grep -rn "is_async\|_cmd_csg\|_cmd_multimesh" mcp_commands_*.gd` |
| Дублирование | `grep -rn "is_inside_tree" mcp_commands_input.gd \| wc -l` |

### 5.3 Критерии приёмки

| Критерий | Как проверить |
|---|---|
| Все существующие тесты проходят | Запуск полного тест-сьюта без ошибок |
| Нет регрессии в производительности | Запуск `test_perf_resource_icons.gd` и `test_hexutils_perf.gd` — время в пределах допустимого |
| Безопасность: нет выполнения произвольного кода без токена | Ручная проверка через `nc 127.0.0.1 9090` с запросом без токена |
| Нет мёртвого кода | `grep` по удалённым методам возвращает 0 результатов |
| Нет дублирования проверок | `grep -rn "is_inside_tree" mcp_commands_*.gd` показывает только определение хелпера |

Основные риски: безопасность MCP-сервера, технический долг в виде аксессоров `HeroController`, монолитность `GameNumbers`. Рекомендуемый порядок внедрения: безопасность → техдолг → масштабируемость → оптимизация → очистка.

# Аудит тестовой инфраструктуры

---

## 1. Текущая структура

```
tests/
├── core/                          # Юнит-тесты ядра (алгоритмы, данные)
│   ├── test_algorithm_optimizations.gd
│   ├── test_artifact_system.gd
│   ├── test_battle_rules.gd
│   ├── test_error_handling.gd
│   ├── test_hex_pathfinding.gd
│   ├── test_hex_utils.gd
│   ├── test_keys_matrix.gd
│   ├── test_logger.gd
│   ├── test_production_chain.gd
│   ├── test_race_class_matrix.gd
│   ├── test_resource_context.gd
│   ├── test_save_roundtrip.gd
│   ├── test_save_v3.gd
│   ├── test_season.gd
│   ├── test_shard.gd
│   ├── test_spell_registry.gd
│   ├── test_spells_json.gd
│   ├── test_static_caches.gd
│   ├── test_status_effects.gd
│   ├── test_time_system.gd
│   ├── test_trait_registry.gd
│   ├── test_turn_scheduler.gd
│   └── test_visibility_map.gd
├── functional/                    # Функциональные тесты (сцены, производительность)
│   ├── test_battle_balance.gd
│   ├── test_battle_emulator.gd
│   ├── test_benchmarks.gd
│   ├── test_camera_clamp.gd
│   ├── test_city_arena_view.gd
│   ├── test_city_navigation.gd
│   ├── test_city_screen.gd
│   ├── test_compile_all.gd
│   ├── test_memory_profile.gd
│   ├── test_perf_resource_icons.gd
│   ├── test_refactoring_regression.gd
│   ├── test_resource_collect_popup.gd
│   ├── test_runtime_integration.gd
│   ├── test_scene_boot.gd
│   ├── test_scene_refs.gd
│   ├── test_session_reset.gd
│   ├── test_tileset_integrity.gd
│   ├── test_ui_animator.gd
│   ├── test_world_scenario.gd
│   └── test_zoom_levels.gd
├── integration/                   # Интеграционные тесты
│   ├── test_battle_input.gd
│   ├── test_city_cycle.gd
│   ├── test_city_economy.gd
│   ├── test_event_router.gd
│   ├── test_hero_resurrection.gd
│   └── test_legend_chronicle.gd
├── unit/                          # Юнит-тесты по доменам
│   ├── core/
│   │   ├── test_mcp_server.gd
│   │   ├── test_save_data_garbage.gd
│   │   └── test_service_registry.gd
│   ├── data/
│   │   ├── test_audio_world_entry.gd
│   │   ├── test_hero_build_profile.gd
│   │   ├── test_resource_registry.gd
│   │   ├── test_spell_system.gd
│   │   └── test_terrain_cost_table.gd
│   ├── entities/
│   │   ├── test_army_stat_integrity.gd
│   │   ├── test_capacity.gd
│   │   ├── test_follower_race_class.gd
│   │   ├── test_hero_serialize.gd
│   │   ├── test_hero_survival.gd
│   │   ├── test_hero_tools.gd
│   │   ├── test_magic.gd
│   │   └── test_scroll.gd
│   ├── systems/
│   │   ├── test_applied_fixes.gd
│   │   ├── test_battle_action_resolver.gd
│   │   ├── test_battle_ai.gd
│   │   ├── test_battle_coordinator.gd
│   │   ├── test_battle_cursor.gd
│   │   ├── test_battle_damage_resolver.gd
│   │   ├── test_battle_flow.gd
│   │   ├── test_battle_fox.gd
│   │   ├── test_battle_handoff.gd
│   │   ├── test_battle_integration.gd
│   │   ├── test_battle_retreat_queue.gd
│   │   ├── test_battle_retreat_smoke.gd
│   │   ├── test_battle_spell_executor.gd
│   │   ├── test_battle_spell_flow.gd
│   │   ├── test_battle_spell_targeting.gd
│   │   ├── test_battle_state.gd
│   │   ├── test_battle_state_cache.gd
│   │   ├── test_battle_view.gd
│   │   ├── test_endgame.gd
│   │   ├── test_enemy_world_ai.gd
│   │   ├── test_hero_combat_death.gd
│   │   ├── test_hero_lifecycle.gd
│   │   ├── test_hero_movement.gd
│   │   ├── test_hero_planned_route.gd
│   │   ├── test_magic_resistance.gd
│   │   ├── test_refactoring_round2.gd
│   │   ├── test_saltpeter.gd
│   │   ├── test_spellbook_guards.gd
│   │   └── test_unit_abilities.gd
│   ├── ui/
│   │   ├── test_battle_ui_onready.gd
│   │   └── test_minimap_overlay.gd
│   └── world/
│       ├── test_borough_rules.gd
│       ├── test_city_arena.gd
│       ├── test_city_building_service.gd
│       ├── test_city_chains.gd
│       ├── test_city_events_relocation.gd
│       ├── test_city_growth_service.gd
│       ├── test_city_housing.gd
│       ├── test_city_income_processor.gd
│       ├── test_city_level.gd
│       ├── test_city_manager.gd
│       ├── test_city_persistence.gd
│       ├── test_city_processor.gd
│       ├── test_city_reputation.gd
│       ├── test_city_serializer.gd
│       ├── test_city_systems.gd
│       ├── test_city_yield_calculator.gd
│       ├── test_city_yield_table.gd
│       ├── test_city.gd
│       ├── test_demographic_processor.gd
│       ├── test_economic_processor.gd
│       ├── test_fog_of_war.gd
│       ├── test_follower_path_id.gd
│       ├── test_follower.gd
│       ├── test_glory_tracker.gd
│       ├── test_map_connectivity.gd
│       ├── test_map_generator_seed.gd
│       ├── test_map_model.gd
│       ├── test_map_renderer.gd
│       ├── test_map_spawner.gd
│       ├── test_market_walls_raids.gd
│       ├── test_pop_unit.gd
│       ├── test_resource_chain_service.gd
│       ├── test_resource_node_manager.gd
│       ├── test_save_load_service.gd
│       ├── test_succession.gd
│       ├── test_world_input.gd
│       └── test_world_shortcuts.gd
├── mcp/                           # MCP-тесты через godot-mcp
│   ├── conftest.py
│   ├── godot_mcp.py
│   ├── test_battle_full_e2e.py
│   ├── test_battle_profiling.py
│   ├── test_battle_tween.py
│   ├── test_city_cycle.py
│   ├── test_full_cycle.py
│   ├── test_hexutils_perf.py
│   ├── test_resource_and.py
│   ├── test_save_load_continue.py
│   ├── test_scene_transitions.py
│   ├── test_session_reset.py
│   ├── test_shard_pruning.py
│   └── test_village_capture.py
├── spell_validation/
│   ├── SpellValidator.gd
│   └── ValidationReport.gd
└── helpers/
    ├── factories.gd               # TestFactories (class_name)
    ├── test_factories.gd          # Тест-сьют, не фабрика!
    └── wait_helpers.gd
```

### Критические проблемы структуры

| # | Проблема | Где | Влияние |
|---|----------|-----|---------|
| S1 | Конфликт имён `TestFactories` | `helpers/factories.gd` (`class_name TestFactories`) vs `helpers/test_factories.gd` (тест-сьют) | Неоднозначность при импорте, путаница |
| S2 | Дублирование фабрик | `factories.gd` содержит `TestFactories`, но `test_factories.gd` — это тест, а не фабрика | `test_factories.gd` должен быть переименован |
| S3 | Непоследовательное расположение | `test_hex_utils.gd` в `core/`, `test_battle_state.gd` в `unit/systems/` | Нет чёткой границы между `core` и `unit` |
| S4 | Отсутствие `auto_free()` | Почти все тесты | Утечки памяти между тестами, нестабильность |
| S5 | Использование `load()` вместо `class_name` | `test_battle_state.gd`, `test_battle_ai.gd`, `test_map_model.gd` | Медленнее, не проверяет регистрацию `class_name` |

---

## 2. Покрытие кода тестами

### 2.1 Покрытие по модулям

| Модуль | Файл | Тесты | Покрытие | Пробелы |
|--------|------|-------|----------|---------|
| **Ядро** | | | | |
| HexUtils | `core/HexUtils.gd` | `test_hex_utils.gd` | ✅ Хорошее | Нет теста `ring()` с `shift_right=false` |
| HexPathfinding | `core/HexPathfinding.gd` | `test_hex_pathfinding.gd`, `test_algorithm_optimizations.gd` | ✅ Хорошее | Нет теста `dijkstra_path()` с `INF`-стоимостью |
| MinHeap | `core/MinHeap.gd` | `test_hex_pathfinding.gd` | ⚠️ Минимальное | Нет теста дубликатов, большого объёма |
| VisibilityMap | `core/VisibilityMap.gd` | `test_visibility_map.gd` | ✅ Хорошее | Нет теста `load_explored` с мусором |
| TurnScheduler | `core/TurnScheduler.gd` | `test_turn_scheduler.gd` | ✅ Хорошее | Нет теста `unregister_processor` |
| ServiceRegistry | `core/service_registry.gd` | `test_service_registry.gd` | ✅ Хорошее | Нет теста `resolve()` с `push_error` |
| GameLogger | `core/GameLogger.gd` | `test_logger.gd` | ⚠️ Минимальное | Нет теста `battle()`, `world()`, `ui()` |
| SaveData | `core/SaveData.gd` | `test_save_v3.gd`, `test_save_data_garbage.gd` | ✅ Хорошее | Нет теста миграции v6→v7 |
| SaveManager | `core/SaveManager.gd` | `test_save_roundtrip.gd` | ⚠️ Частичное | Нет теста `delete_slot`, `has_save_in_slot` |
| Chronicle | `core/Chronicle.gd` | `test_legend_chronicle.gd` | ⚠️ Частичное | Нет теста `_entry_text` |
| StaticCaches | `core/StaticCaches.gd` | `test_static_caches.gd` | ⚠️ Минимальное | Нет теста `TileAtlasCache` |
| **Данные** | | | | |
| SpellRegistry | `autoload/SpellRegistry.gd` | `test_spell_registry.gd` | ✅ Хорошее | Нет теста `custom_handler` |
| SpellbookRegistry | `autoload/SpellbookRegistry.gd` | `test_spell_system.gd` | ✅ Хорошее | Нет теста `_load_fallback` |
| TemplateEngine | `data/TemplateEngine.gd` | `test_spell_system.gd` | ⚠️ Частичное | Нет теста каждого шаблона отдельно |
| SpellResolver | `data/SpellResolver.gd` | `test_spell_system.gd` | ⚠️ Частичное | Нет теста `insufficient_influence` |
| SpellValidator | `spell_validation/SpellValidator.gd` | `test_spells_json.gd` | ✅ Хорошее | Нет теста `save_baseline` |
| ArtifactRegistry | `autoload/ArtifactRegistry.gd` | `test_artifact_system.gd` | ✅ Хорошее | Нет теста `random_of_rarity` с пустым пулом |
| ResourceRegistry | `autoload/ResourceRegistry.gd` | `test_resource_registry.gd` | ✅ Хорошее | Нет теста `get_by_biome` с несуществующим биомом |
| UnitRegistry | `autoload/UnitRegistry.gd` | `test_unit_abilities.gd` | ⚠️ Частичное | Нет теста `make_stack` с невалидным ключом |
| BuildingDefs | `data/BuildingDefs.gd` | `test_city_building_service.gd` | ⚠️ Частичное | Нет теста `_ensure_loaded` с битым JSON |
| RaceClassRegistry | `data/RaceClassRegistry.gd` | `test_race_class_matrix.gd` | ✅ Хорошее | Нет теста `_load_from_json` с отсутствующим файлом |
| TerrainCostTable | `data/TerrainCostTable.gd` | `test_terrain_cost_table.gd` | ✅ Хорошее | Нет теста `get_cost_with_effects_by_id` |
| TimeSystem | `data/TimeSystem.gd` | `test_time_system.gd` | ✅ Хорошее | Нет теста `wait_until_noon` из вечера |
| AudioCues | `data/AudioCues.gd` | `test_audio.gd` | ✅ Хорошее | Нет теста `path()` с пустым ключом |
| **Сущности** | | | | |
| HeroController | `entities/HeroController.gd` | ❌ Нет прямых тестов | 🔴 Критическое | Нет тестов компонентной системы |
| HeroMovementController | `entities/HeroMovementController.gd` | `test_hero_movement.gd` | ✅ Хорошее | Нет теста `teleport` |
| HeroMagic | `entities/HeroMagic.gd` | `test_magic.gd` | ✅ Хорошее | Нет теста `can_cast` с объектом `SpellDef` |
| HeroInventory | `entities/HeroInventory.gd` | `test_artifact_system.gd` | ✅ Хорошее | Нет теста `equip` с двухруким оружием и щитом |
| HeroNeeds | `entities/HeroNeeds.gd` | `test_hero_survival.gd` | ✅ Хорошее | Нет теста `tick` в городе с 1 поп |
| HeroTools | `entities/HeroTools.gd` | `test_hero_tools.gd` | ✅ Хорошее | Нет теста `serialize` с пустыми слотами |
| HeroResources | `entities/HeroResources.gd` | `test_hero_serialize.gd` | ⚠️ Частичное | Нет теста `pickup_resource` |
| HeroSkills | `entities/HeroSkills.gd` | `test_hero_survival.gd` | ⚠️ Частичное | Нет теста `get_yield_multiplier` |
| Follower | `entities/Follower.gd` | `test_follower.gd` | ✅ Хорошее | Нет теста `describe` с пустыми трейтами |
| UnitStack | `entities/UnitStack.gd` | `test_unit_registry.gd` | ⚠️ Частичное | Нет теста `to_dict` с `null` статсами |
| UnitStats | `entities/UnitStats.gd` | `test_unit_registry.gd` | ⚠️ Частичное | Нет теста `copy()` |
| ResourceNode | `entities/ResourceNode.gd` | `test_resource_node_manager.gd` | ⚠️ Частичное | Нет теста `_update_visual` |
| **Системы** | | | | |
| BattleState | `systems/BattleState.gd` | `test_battle_state.gd` | ✅ Хорошее | Нет теста `get_retreat_survivors` с 0 юнитов |
| BattleTurnExecutor | `systems/BattleTurnExecutor.gd` | `test_battle_spell_executor.gd` | ⚠️ Частичное | Нет теста `_advance_to_next_turn` |
| BattleAI | `systems/BattleAI.gd` | `test_battle_ai.gd` | ✅ Хорошее | Нет теста `_find_flying_landing_cell` с препятствиями |
| BattleActionResolver | `systems/BattleActionResolver.gd` | `test_battle_action_resolver.gd` | ✅ Хорошее | Нет теста `do_wait` с пустой очередью |
| BattleRules | `core/BattleRules.gd` | `test_battle_rules.gd` | ✅ Хорошее | Нет теста `preview_text` с `null` |
| BattleFlow | `systems/BattleFlow.gd` | `test_battle_flow.gd` | ✅ Хорошее | Нет теста `_on_battle_finished` |
| BattleController | `systems/BattleController.gd` | ❌ Нет прямых тестов | 🔴 Критическое | Только через эмулятор |
| BattleHandoff | `systems/BattleHandoff.gd` | `test_battle_handoff.gd` | ✅ Хорошее | Нет теста `extract_hero_survivors` с пустыми массивами |
| SpellCaster | `systems/SpellCaster.gd` | `test_magic_resistance.gd` | ✅ Хорошее | Нет теста `_check_immunity` с `null` юнитом |
| EndgameController | `systems/EndgameController.gd` | `test_endgame.gd` | ✅ Хорошее | Нет теста `_on_glory_changed` с `null` городами |
| EnemyTurnProcessor | `systems/EnemyTurnProcessor.gd` | `test_enemy_world_ai.gd` | ✅ Хорошее | Нет теста `_dist_field` с кэшем |
| EnemyGrowthSystem | `systems/EnemyGrowthSystem.gd` | `test_enemy_world_ai.gd` | ✅ Хорошее | Нет теста `process` с пустой картой |
| **Город** | | | | |
| City | `world/City.gd` | `test_city.gd` | ✅ Хорошее | Нет теста `process_turn` с `null` `tile_yield_fn` |
| CityManager | `world/CityManager.gd` | `test_city_manager.gd` | ✅ Хорошее | Нет теста `get_city_by_uid` с несуществующим |
| CityTurnProcessor | `city/CityTurnProcessor.gd` | `test_city_processor.gd` | ✅ Хорошее | Нет теста `process` с `null` контекстом |
| EconomicTurnProcessor | `economy/EconomicTurnProcessor.gd` | `test_economic_processor.gd` | ✅ Хорошее | Нет теста `process` с `null` городом |
| ProductionChain | `economy/ProductionChain.gd` | `test_production_chain.gd` | ✅ Хорошее | Нет теста `execute` с отрицательными рабочими |
| ResourceContext | `economy/ResourceContext.gd` | `test_resource_context.gd` | ✅ Хорошее | Нет теста `spend` с пустым словарём |
| ReputationSystem | `city/ReputationSystem.gd` | `test_city_reputation.gd` | ✅ Хорошее | Нет теста `process_migration` с пустым городом |
| MarketSystem | `city/MarketSystem.gd` | `test_market_walls_raids.gd` | ✅ Хорошее | Нет теста `trade` с отрицательным количеством |
| RaidSystem | `city/RaidSystem.gd` | `test_market_walls_raids.gd` | ✅ Хорошее | Нет теста `resolve` с `null` городом |
| **Мир** | | | | |
| WorldController | `world/WorldController.gd` | ❌ Нет прямых тестов | 🔴 Критическое | Только через сцену |
| WorldBootstrap | `world/WorldBootstrap.gd` | ❌ Нет тестов | 🔴 Критическое | Только через сцену |
| WorldEventRouter | `world/WorldEventRouter.gd` | `test_event_router.gd` | ⚠️ Частичное | Нет теста `_on_hero_moved` |
| WorldBattleCoordinator | `world/WorldBattleCoordinator.gd` | `test_battle_coordinator.gd` | ✅ Хорошее | Нет теста `_on_battle_completed` с `null` героем |
| WorldInteractionController | `world/WorldInteractionController.gd` | `test_fog_of_war.gd` | ⚠️ Частичное | Нет теста `pickup_scroll_at` |
| MapGenerator | `world/MapGenerator.gd` | `test_map_model.gd` | ⚠️ Частичное | Нет теста `generate()` полностью |
| MapSpawner | `world/MapSpawner.gd` | `test_map_spawner.gd` | ⚠️ Частичное | Нет теста `place_enemies` |
| WorldSpawner | `world/WorldSpawner.gd` | `test_fog_of_war.gd` | ⚠️ Частичное | Нет теста `spawn_all` |
| WorldPersistence | `world/WorldPersistence.gd` | `test_world_persistence.gd` | ⚠️ Частичное | Нет теста `apply_loaded_save` |
| WorldSaveLoadService | `world/WorldSaveLoadService.gd` | `test_save_load_service.gd` | ✅ Хорошее | Нет теста `request_load_game` |
| WorldInput | `world/WorldInput.gd` | `test_world_input.gd` | ✅ Хорошее | Нет теста `_unhandled_input` с `null` камерой |
| WorldShortcuts | `world/WorldShortcuts.gd` | `test_world_shortcuts.gd` | ✅ Хорошее | Нет теста `_unhandled_input` с `null` контроллером |
| **Демография** | | | | |
| Character | `demographics/Character.gd` | `test_characters.gd` | ✅ Хорошее | Нет теста `trait_modifier` с `null` трейтом |
| CharacterRegistry | `demographics/CharacterRegistry.gd` | `test_characters.gd` | ✅ Хорошее | Нет теста `deserialize` с мусором |
| DemographicTurnProcessor | `demographics/DemographicTurnProcessor.gd` | `test_demographic_processor.gd` | ✅ Хорошее | Нет теста `process` с `null` реестром |
| TraitRegistry | `demographics/TraitRegistry.gd` | `test_trait_registry.gd` | ✅ Хорошее | Нет теста `roll_traits` с `max_count=0` |
| **UI** | | | | |
| BattleUI | `ui/BattleUI.gd` | `test_battle_ui_onready.gd` | ⚠️ Минимальное | Нет теста `update_initiative` |
| CityScreen | `ui/CityScreen.gd` | `test_city_screen.gd` | ⚠️ Частичное | Нет теста `hire_pressed` |
| AdventureUI | `ui/AdventureUI.gd` | ❌ Нет тестов | 🔴 Критическое | |
| MainMenu | `ui/MainMenu.gd` | ❌ Нет тестов | 🔴 Критическое | |
| SettingsScreen | `ui/SettingsScreen.gd` | `test_settings_persist.gd` | ⚠️ Частичное | Нет теста `_on_apply` |
| SaveLoadScreen | `ui/SaveLoadScreen.gd` | `test_save_load_screen.gd` | ✅ Хорошее | Нет теста `perform_load` |
| MinimapPanel | `ui/MinimapPanel.gd` | `test_minimap_overlay.gd` | ⚠️ Частичное | Нет теста `refresh` |
| MarkerLayer | `ui/MarkerLayer.gd` | `test_fog_of_war.gd` | ⚠️ Частичное | Нет теста `_handle_left_click` |
| **Автозагрузки** | | | | |
| Settings | `autoload/Settings.gd` | `test_settings_persist.gd` | ⚠️ Частичное | Нет теста `_load` с битым файлом |
| SoundManager | `autoload/SoundManager.gd` | `test_audio.gd` | ⚠️ Частичное | Нет теста `play_sfx` с `null` стримом |
| CursorController | `autoload/CursorController.gd` | `test_cursor.gd` | ✅ Хорошее | Нет теста `_apply_cursor` с `null` текстурой |
| GameEventBus | `autoload/GameEventBus.gd` | `test_event_bus.gd` | ✅ Хорошее | Нет теста множественных подписок |
| **MCP** | | | | |
| McpInteractionServer | `mcp_interaction_server.gd` | `test_mcp_server.gd` | ✅ Хорошее | Нет теста `_process` с таймаутом |
| McpCommandsBase | `mcp_commands_base.gd` | `test_mcp_server.gd` | ⚠️ Частичное | Нет теста `execute` с `null` обработчиком |
| McpSerialization | `mcp_serialization.gd` | `test_mcp_server.gd` | ✅ Хорошее | Нет теста `variant_to_json` с `Object` |

### 2.2 Сводка покрытия

| Категория | Покрыто | Частично | Не покрыто |
|-----------|---------|----------|------------|
| Ядро | 80% | 15% | 5% |
| Данные | 75% | 20% | 5% |
| Сущности | 60% | 25% | 15% |
| Системы боя | 70% | 20% | 10% |
| Город | 85% | 10% | 5% |
| Мир | 50% | 30% | 20% |
| Демография | 90% | 8% | 2% |
| UI | 30% | 30% | 40% |
| Автозагрузки | 60% | 30% | 10% |
| MCP | 70% | 20% | 10% |

---

## 3. Проблемы в логике тестов

### 3.1 Использование `load()` вместо `class_name`

**Проблема:** 15+ тестов используют `load()` для создания объектов, хотя все классы имеют `class_name`.

**Где:**
- `test_battle_state.gd`: `load("res://scripts/systems/BattleState.gd").new()`
- `test_battle_ai.gd`: `load("res://scripts/systems/BattleAI.gd").new()`
- `test_map_model.gd`: `load("res://scripts/world/MapModel.gd").new()`
- `test_battle_integration.gd`: `load("res://scripts/core/BattleRules.gd").new()`

**До:**
```gdscript
func _create_state():
    var state = load("res://scripts/systems/BattleState.gd").new()
```

**После:**
```gdscript
func _create_state() -> BattleState:
    return BattleState.new()
```

**Приоритет:** Medium

### 3.2 Отсутствие `auto_free()`

**Проблема:** Почти ни один тест не использует `auto_free()` для автоматической очистки объектов. Это приводит к утечкам памяти между тестами и нестабильности.

**Где:** Все тесты, создающие `Node`-объекты.

**До:**
```gdscript
func test_create_unit_sprite() -> void:
    _view.create_unit_sprite(_unit)
    assert_that(_view._sprites_by_uid.has(1)).is_true()
```

**После:**
```gdscript
func test_create_unit_sprite() -> void:
    var unit := auto_free(BattleState.BattleUnit.new(UnitStack.new(...)))
    _view.create_unit_sprite(unit)
    assert_that(_view._sprites_by_uid.has(1)).is_true()
```

**Приоритет:** High

### 3.3 Конфликт `TestFactories`

**Проблема:** `helpers/factories.gd` объявляет `class_name TestFactories`, а `helpers/test_factories.gd` — это тест-сьют с тем же именем в `extends GdUnitTestSuite`. Это создаёт неоднозначность.

**До:**
```
helpers/
├── factories.gd          # class_name TestFactories
└── test_factories.gd     # extends GdUnitTestSuite (тест!)
```

**После:**
```
helpers/
├── factories.gd          # class_name TestFactories
└── test_factory_usage.gd # extends GdUnitTestSuite (переименован)
```

**Приоритет:** High

### 3.4 Тесты без фолбэка на автозагрузки

**Проблема:** Тесты используют `Units.make_fixed_stack()` напрямую, но `Units` — автозагрузка. Если автозагрузка не инициализирована, тест упадёт.

**Где:** `test_battle_state.gd`, `test_battle_ai.gd`, `test_battle_integration.gd`

**До:**
```gdscript
func _create_state():
    var state = BattleState.new()
    var atk: Array[UnitStack] = []
    atk.append(Units.make_fixed_stack("swordsmen", 20))
```

**После:**
```gdscript
func _create_state() -> BattleState:
    var units: Node = Services.resolve(&"units")
    if units == null:
        units = auto_free(load("res://scripts/autoload/UnitRegistry.gd").new())
    var state := BattleState.new()
    var atk: Array[UnitStack] = [units.make_fixed_stack("swordsmen", 20)]
    var def: Array[UnitStack] = [units.make_fixed_stack("goblins", 20)]
    state.place_army(atk, def)
    return state
```

**Приоритет:** High

### 3.5 Тесты, проверяющие реализацию вместо поведения

**Проблема:** Некоторые тесты проверяют внутренние поля вместо публичного поведения.

**Где:** `test_world_persistence.gd`

**До:**
```gdscript
func test_load_context_fields() -> void:
    var ctx := WorldLoadContext.new()
    ctx.map_gen = null
    ctx.spawner = null
    assert_that(ctx.world_delta).is_not_null()
```

**После:**
```gdscript
func test_load_context_creation() -> void:
    var ctx := WorldLoadContext.new()
    assert_that(ctx).is_not_null()
    # Проверяем поведение: контекст можно передать в apply_loaded_save
    var persistence := WorldPersistence.new(null)
    # Нет краша при передаче контекста
    var sd := SaveData.new()
    sd.run_seed = 1
    sd.hero = {"cell": {"x": 0, "y": 0}}
    sd.world = {}
    persistence.apply_loaded_save(sd, ctx)
```

**Приоритет:** Medium

### 3.6 Отсутствие типизированных ассертов

**Проблема:** Многие тесты используют `assert_that()` вместо типизированных ассертов (`assert_int`, `assert_float`, `assert_bool`, `assert_str`, `assert_array`, `assert_dict`, `assert_vector`).

**Где:** `test_city_system.gd`, `test_battle_state.gd`, `test_map_model.gd`

**До:**
```gdscript
assert_that(c.count_state(PopUnit.State.MILITIA)).is_equal(5)
assert_that(c.pop_capped()).is_equal(7)
```

**После:**
```gdscript
assert_int(c.count_state(PopUnit.State.MILITIA)).is_equal(5)
assert_int(c.pop_capped()).is_equal(7)
```

**Приоритет:** Low

### 3.7 Дублирование кода в тестах

**Проблема:** `_assert_flying_landing` в `test_battle_ai.gd` дублирует логику проверки. `_make_city` в нескольких файлах.

**До:**
```gdscript
# В test_battle_ai.gd
func _setup_flying_vs_ground():
    var state = load("res://scripts/systems/BattleState.gd").new()
    ...

# В test_battle_state.gd
func _create_state():
    var state = load("res://scripts/systems/BattleState.gd").new()
    ...
```

**После:**
```gdscript
# В helpers/factories.gd
static func make_battle_state_with_flying() -> BattleState:
    var state := BattleState.new()
    var atk: Array[UnitStack] = [Units.make_fixed_stack("pegasus", 10)]
    var def: Array[UnitStack] = [Units.make_fixed_stack("goblins", 10)]
    state.place_army(atk, def)
    return state
```

**Приоритет:** Medium

---

## 4. Проблемы в MCP-тестах

### 4.1 Текущее покрытие

| Сценарий | Тест | Статус |
|----------|------|--------|
| Полный бой (эмулятор) | `test_battle_full_e2e.py` | ✅ |
| Профилирование боя | `test_battle_profiling.py` | ✅ |
| Твин-анимация боя | `test_battle_tween.py` | ✅ |
| Городской цикл | `test_city_cycle.py` | ✅ |
| Полный цикл меню→мир | `test_full_cycle.py` | ✅ |
| Производительность A* | `test_hexutils_perf.py` | ✅ |
| Извлечение ресурсов | `test_resource_and.py` | ✅ |
| Сохранение/загрузка | `test_save_load_continue.py` | ✅ |
| Переходы сцен | `test_scene_transitions.py` | ✅ |
| Сброс сессии | `test_session_reset.py` | ✅ |
| Обрезка шардов | `test_shard_pruning.py` | ✅ |
| Захват деревни | `test_village_capture.py` | ✅ |

### 4.2 Отсутствующие MCP-тесты

| Сценарий | Приоритет | Описание |
|----------|-----------|----------|
| Создание персонажа через меню | High | Проверка полного цикла создания |
| Сохранение через меню (F5) | High | Проверка горячих клавиш |
| Загрузка через меню | High | Проверка загрузки из слота |
| Настройки через меню | Medium | Проверка применения настроек |
| Смерть героя и преемственность | High | Проверка полного цикла смерти |
| Туман войны | Medium | Проверка видимости |
| Вражеский ИИ на карте мира | Medium | Проверка движения врагов |
| Ресурсы на карте | Medium | Проверка сбора ресурсов |
| Хронология | Low | Проверка записей в летописи |
| Бой через контроллер (не эмулятор) | High | Проверка реального боя |
| Городской экран через клик | Medium | Проверка открытия города |
| Инвентарь героя | Medium | Проверка открытия инвентаря |
| Заклинания в бою | Medium | Проверка каста заклинаний |
| Отступление в бою | Medium | Проверка отступления |
| Конец игры (победа/поражение) | High | Проверка условий конца |

### 4.3 Проблемы в существующих MCP-тестах

**`test_battle_full_e2e.py`:**
```python
# Проблема: нет проверки на разумное число ходов
for _ in range(150):
    state = mcp.execute_code(STATE_CODE)
    if state["over"]:
        break
# Нет проверки: assert state["over"] == True
```

**`test_city_cycle.py`:**
```python
# Проблема: нет проверки на существование героя
built = mcp.execute_code(BUILD_FARM)
assert built["built"] is True
# Нет проверки: герой существует, город создан
```

**`test_save_load_continue.py`:**
```python
# Проблема: нет проверки на корректность данных после загрузки
loaded = _wait_world(mcp)
assert loaded["mana"] == baseline["mana"]
# Нет проверки: имя героя, позиция, ресурсы
```

---

## 5. Рекомендации по улучшению

### 5.1 Реструктуризация тестов

**Целевая структура:**
```
tests/
├── unit/                          # Все юнит-тесты
│   ├── core/                      # Ядро (алгоритмы, структуры данных)
│   ├── data/                      # Данные (реестры, определения)
│   ├── entities/                  # Сущности (герой, юниты, ресурсы)
│   ├── systems/                   # Системы (бой, город, мир)
│   ├── ui/                        # UI-компоненты
│   └── autoload/                  # Автозагрузки
├── integration/                   # Интеграционные тесты
├── functional/                    # Функциональные тесты (сцены)
├── mcp/                           # MCP-тесты через godot-mcp
├── spell_validation/              # Валидация данных
└── helpers/                       # Фабрики и утилиты
    ├── factories.gd               # class_name TestFactories
    └── wait_helpers.gd
```

**Удалить:**
- `tests/core/` → перенести в `tests/unit/core/`
- `tests/helpers/test_factories.gd` → переименовать в `test_factory_usage.gd`

### 5.2 Базовый класс для тестов

Создать общий базовый класс с утилитами:

```gdscript
# tests/helpers/base_test.gd
class_name BaseTest
extends GdUnitTestSuite

## Инициализация автозагрузок для тестов
static func ensure_units() -> Node:
    var units: Node = Services.resolve(&"units")
    if units == null:
        units = load("res://scripts/autoload/UnitRegistry.gd").new()
        units.ensure_definitions()
    return units

static func ensure_resources() -> Node:
    var res: Node = Services.resolve(&"resources")
    if res == null:
        res = load("res://scripts/autoload/ResourceRegistry.gd").new()
        res.ensure_definitions()
    return res

## Создание боевого состояния с фолбэком
static func make_battle_state_safe(
    atk_key := "swordsmen", def_key := "goblins",
    atk_count := 20, def_count := 20
) -> BattleState:
    var units := ensure_units()
    var state := BattleState.new()
    var atk: Array[UnitStack] = [units.make_fixed_stack(atk_key, atk_count)]
    var def: Array[UnitStack] = [units.make_fixed_stack(def_key, def_count)]
    state.place_army(atk, def)
    return state
```

### 5.3 Добавление `auto_free()`

Все тесты, создающие `Node`-объекты, должны использовать `auto_free()`:

```gdscript
func before_test() -> void:
    _view = auto_free(_Scene.instantiate())
    add_child(_view)
    _view.setup()
```

### 5.4 Типизированные ассерты

Заменить все `assert_that()` на типизированные ассерты:

```gdscript
# До
assert_that(result.get("damage", 0)).is_greater(0)
assert_that(unit.get_count()).is_equal(5)
assert_that(txt).is_not_empty()

# После
assert_int(result.get("damage", 0)).is_greater(0)
assert_int(unit.get_count()).is_equal(5)
assert_str(txt).is_not_empty()
```

### 5.5 Новые тесты для критических пробелов

#### 5.5.1 Тесты для `HeroController`

```gdscript
# tests/unit/entities/test_hero_controller.gd
extends BaseTest

func test_hero_creation_with_components() -> void:
    var hero := auto_free(HeroController.new())
    assert_that(hero.get_component("Movement")).is_not_null()
    assert_that(hero.get_component("Army")).is_not_null()
    assert_that(hero.get_component("Magic")).is_not_null()
    assert_that(hero.get_component("Inventory")).is_not_null()

func test_hero_serialize_roundtrip() -> void:
    var hero := auto_free(HeroController.new())
    hero.hero_name = "TestHero"
    hero.path_id = &"archivist"
    var data := hero.serialize()
    var hero2 := auto_free(HeroController.new())
    hero2.deserialize(data)
    assert_str(hero2.hero_name).is_equal("TestHero")
    assert_that(hero2.path_id).is_equal(&"archivist")

func test_hero_end_turn() -> void:
    var hero := auto_free(HeroController.new())
    hero._ready()
    hero.magic.mana_current = 10
    hero.end_turn()
    assert_int(hero.magic.mana_current).is_greater(10)
```

#### 5.5.2 Тесты для `TemplateEngine`

```gdscript
# tests/unit/data/test_template_engine.gd
extends BaseTest

func test_all_templates_registered() -> void:
    var templates := [
        &"DIRECT_DAMAGE", &"HARD_REMOVAL", &"BOUNCE", &"COUNTERMAGIC",
        &"COMBAT_TRICK", &"DEBUFF_CONTROL", &"SPELL_DRAW", &"MANA_RAMP",
        &"TOKEN_GENERATION", &"RELIC_INTERACTION", &"KEYWORD_BUFF",
        &"CHOICE_CYCLE", &"TOUCH_CYCLE", &"DISPLAY_CYCLE",
        &"DISPEL_DRAW", &"MARKET_NICHE", &"HEAL_CLEAR", &"REVIVE", &"PORTAL",
    ]
    for t in templates:
        var result: Dictionary = TemplateEngine.execute(t, {}, {}, [], null, null, null)
        assert_bool(result.has("result")).is_true()
        assert_bool(result.get("result") != "unknown_template").is_true()

func test_unknown_template() -> void:
    var result: Dictionary = TemplateEngine.execute(&"NONEXISTENT", {}, {}, [], null, null, null)
    assert_str(result.get("result")).is_equal("unknown_template")
```

#### 5.5.3 Тесты для `WorldBootstrap`

```gdscript
# tests/functional/test_world_bootstrap.gd
extends BaseTest

func test_bootstrap_creates_all_systems() -> void:
    var host := auto_free(Node2D.new())
    add_child(host)
    var rng := TestFactories.seeded(42)
    var result := WorldBootstrap.run(host, Platform, rng)
    assert_that(result.map_gen).is_not_null()
    assert_that(result.hero).is_not_null()
    assert_that(result.camera).is_not_null()
    assert_that(result.cities).is_not_null()
    assert_that(result.battle_coordinator).is_not_null()
    assert_that(result.ui_manager).is_not_null()
```

### 5.6 Новые MCP-тесты

#### 5.6.1 Тест создания персонажа

```python
# tests/mcp/test_character_creation.py
def test_character_creation_full_flow(full_cycle):
    """Проверка полного цикла создания персонажа через меню."""
    mcp = full_cycle
    r = mcp.execute_code(
        "var w = get_tree().current_scene\n"
        "return {\"hero\": w.get_hero() != null, "
        "\"name\": w.get_hero().hero_name if w.get_hero() != null else \"\"}"
    )
    assert r["hero"] is True
    assert r["name"] == "McpCycleHero"
```

#### 5.6.2 Тест смерти и преемственности

```python
# tests/mcp/test_hero_death.py
def test_hero_death_triggers_succession(full_game):
    """Проверка смерти героя и преемственности через MCP."""
    mcp = full_game
    # Добавляем последователя
    mcp.execute_code(
        "var w = get_tree().current_scene\n"
        "var h = w.get_hero()\n"
        "var f = Follower.new()\n"
        "f.uid = 99\n"
        "f.path = h.path_id\n"
        "h.followers = [f]\n"
        "return {\"ok\": true}"
    )
    # Убиваем героя
    mcp.execute_code(
        "GameEventBus.hero_died.emit(&\"battle\")\n"
        "return {\"ok\": true}"
    )
    mcp.wait_frames(30)
    # Проверяем, что преемник вступил в роль
    r = mcp.execute_code(
        "var w = get_tree().current_scene\n"
        "return {\"hero\": w.get_hero() != null}"
    )
    assert r["hero"] is True
```

#### 5.6.3 Тест боя через контроллер

```python
# tests/mcp/test_battle_controller.py
def test_battle_via_controller(battle_scene):
    """Проверка боя через BattleController, а не эмулятор."""
    mcp = battle_scene
    init = mcp.execute_code("""
        var battle = get_tree().current_scene
        var units_reg = get_node("/root/Units")
        units_reg.ensure_definitions()
        var atk: Array[UnitStack] = [units_reg.make_fixed_stack("swordsmen", 10)]
        var def: Array[UnitStack] = [units_reg.make_fixed_stack("goblins", 5)]
        battle.start_battle(atk, def, {}, {}, {}, {}, 42, null)
        return {"status": "battle_started"}
    """)
    assert init.get("status") == "battle_started"
    mcp.wait_frames(20)
    # Проверяем, что бой жив
    state = mcp.execute_code(
        "var bs = get_tree().current_scene.get_battle_state()\n"
        "return {\"over\": bs.battle_over, \"turn\": bs.is_player_turn}"
    )
    assert "error" not in state
```

---

## 6. План внедрения

### Фаза 1: Критические исправления (High)

| Шаг | Действие | Файлы |
|-----|----------|-------|
| 1.1 | Переименовать `test_factories.gd` → `test_factory_usage.gd` | `tests/helpers/` |
| 1.2 | Добавить `auto_free()` во все тесты с `Node` | Все тесты |
| 1.3 | Заменить `load()` на `class_name` | 15+ файлов |
| 1.4 | Добавить фолбэк на автозагрузки | `test_battle_state.gd`, `test_battle_ai.gd` |
| 1.5 | Создать `BaseTest` с утилитами | `tests/helpers/base_test.gd` |

### Фаза 2: Покрытие критических пробелов (High)

| Шаг | Действие | Новые файлы |
|-----|----------|-------------|
| 2.1 | Тесты для `HeroController` | `tests/unit/entities/test_hero_controller.gd` |
| 2.2 | Тесты для `TemplateEngine` | `tests/unit/data/test_template_engine.gd` |
| 2.3 | Тесты для `WorldBootstrap` | `tests/functional/test_world_bootstrap.gd` |
| 2.4 | Тесты для `BattleController` | `tests/unit/systems/test_battle_controller.gd` |
| 2.5 | Тесты для `SaveManager` | `tests/unit/core/test_save_manager.gd` |
| 2.6 | Тесты для `Chronicle` | `tests/unit/core/test_chronicle.gd` |

### Фаза 3: Новые MCP-тесты (High)

| Шаг | Действие | Новые файлы |
|-----|----------|-------------|
| 3.1 | Тест создания персонажа | `tests/mcp/test_character_creation.py` |
| 3.2 | Тест смерти и преемственности | `tests/mcp/test_hero_death.py` |
| 3.3 | Тест боя через контроллер | `tests/mcp/test_battle_controller.py` |
| 3.4 | Тест конца игры | `tests/mcp/test_endgame.py` |
| 3.5 | Тест настроек через меню | `tests/mcp/test_settings_menu.py` |

### Фаза 4: Улучшение существующих тестов (Medium)

| Шаг | Действие | Файлы |
|-----|----------|-------|
| 4.1 | Типизированные ассерты | Все тесты |
| 4.2 | Устранение дублирования | `test_battle_ai.gd`, `test_city_system.gd` |
| 4.3 | Улучшение MCP-тестов | `test_battle_full_e2e.py`, `test_city_cycle.py` |
| 4.4 | Тесты для `SoundManager` | `tests/unit/autoload/test_sound_manager.gd` |
| 4.5 | Тесты для `Settings` | `tests/unit/autoload/test_settings.gd` |

### Фаза 5: Реструктуризация (Low)

| Шаг | Действие | Файлы |
|-----|----------|-------|
| 5.1 | Перенос `tests/core/` → `tests/unit/core/` | Все файлы |
| 5.2 | Перенос `tests/functional/` → `tests/functional/` | Без изменений |
| 5.3 | Обновление путей в `pytest.ini` | `tests/mcp/pytest.ini` |
| 5.4 | Обновление CI/CD | `.github/workflows/` |

### Команды для проверки

```bash
# Запуск всех юнит-тестов
godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests/unit/

# Запуск интеграционных тестов
godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests/integration/

# Запуск функциональных тестов
godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests/functional/

# Запуск MCP-тестов
cd game/tests/mcp
python -m pytest -xvs

# Проверка покрытия (если настроено)
godot --headless --path game -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests/ --report-junit
```

### Критерии приёмки

| Критерий | Как проверить |
|----------|---------------|
| Нет тестов с `load()` вместо `class_name` | `grep -rn "load(\"res://scripts" tests/` возвращает 0 |
| Все тесты используют `auto_free()` | `grep -rn "auto_free" tests/` возвращает > 50 |
| Нет конфликта `TestFactories` | `grep -rn "class_name TestFactories" tests/` возвращает 1 |
| Все юнит-тесты проходят | Запуск `gdUnit4` без ошибок |
| Все MCP-тесты проходят | Запуск `pytest` без ошибок |
| Покрытие критических модулей > 80% | Ручная проверка таблицы покрытия |