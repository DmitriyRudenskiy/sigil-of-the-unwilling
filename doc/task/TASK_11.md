# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

---

## 1. Архитектура

### 1.1. Общее впечатление

Проект **хорошо структурирован** для своего масштаба: чёткое разделение по доменам (`core/`, `city/`, `economy/`, `demographics/`, `battle`, `world/`, `ui/`), DI-контейнер (`ServiceRegistry`), фасад `City` поверх `CityData`/`CityService`, `TurnScheduler` с процессорами. Однако есть несколько системных проблем.

### 1.2. Таблица проблем

| # | Проблема | Где | Влияние | Приоритет |
|---|----------|-----|---------|-----------|
| A1 | **Глобальные «бог-файлы»**: `GameNumbers.gd` (~400 строк), `GameText.gd` (~500), `ThemeConfig.gd` (~400) | `scripts/constants/`, `scripts/theme/` | Любое изменение баланса/текста/темы требует правки гигантского файла; конфликты при параллельной разработке; нарушение SRP | **High** |
| A2 | **Статическое состояние, переживающее сессию**: `WorldPersistence.pending_save`, `pending_new_game`; `HexUtils._config`; кэши в `ResourceIcons`, `UnitSprites`, `PlaceholderTexture`, `ResourceAtlas` | `WorldPersistence.gd`, `HexUtils.gd`, `ResourceIcons.gd` и др. | Сложная отладка, неявные зависимости, риск утечки между сессиями. `StaticCaches.reset_all()` — правильный шаг, но не покрывает `WorldPersistence.pending_*` | **High** |
| A3 | **`WorldBootstrap` — статический мега-класс** (~350 строк, все методы `static`) | `scripts/world/WorldBootstrap.gd` | Невозможно подменить/расширить поведение в тестах; нарушение OCP | **Medium** |
| A4 | **Смешение ответственности в `CityArenaView`**: UI, логика, рендер, инпут — всё в одном скрипте (~350 строк) | `scripts/world/CityArenaView.gd` | Нарушение SRP, сложность поддержки | **Medium** |
| A5 | **Дублирование ролей**: `CityArenaModel` делегирует в `ArenaRingSystem`, `ArenaClusterSystem`, `ArenaTurnRunner`, `ArenaStorm` — 5 классов-прослоек для одной подсистемы | `scripts/city/Arena*.gd` | Избыточная абстракция (нарушение KISS/YAGNI); читателю сложно найти реальную логику | **Low** |
| A6 | **`BattleFlow` создаёт сцену и добавляет в корень**, но не управляет её жизненным циклом полностью | `scripts/systems/BattleFlow.gd` | Потенциальный дубль сцены при быстром повторном вызове; `_active` флаг — хрупкая защита | **Medium** |

### 1.3. Паттерны — оценка

| Паттерн | Реализация | Оценка |
|---------|-----------|--------|
| **Service Locator / DI** | `ServiceRegistry` + `Services` автозагрузка | ✅ Хорошо, но `ServiceLocator` (deprecated) всё ещё используется в тестах |
| **Strategy** | `NeedStrategy` → `RestStrategy`, `SocialStrategy`, `InspirationStrategy` | ✅ Чисто |
| **Facade** | `City` над `CityData`/`CityService` | ✅ Хороший сплит |
| **Builder** | `BattleStateBuilder` | ✅ Вынесен из `BattleState` |
| **Observer** | `GameEventBus` (глобальный автозагрузка) | ⚠️ Глобальная шина — допустимо, но сигналы часто коннектятся вручную без `disconnect` |
| **Template Method** | `TurnPhaseProcessor` → конкретные процессоры | ✅ Чисто |
| **Singleton** | `ShardManager.instance()` | ⚠️ Статический `_instance` — см. A2 |

---

## 2. Лучшие практики

### 2.1. Идиомы Godot 4

| # | Проблема | Пример | Исправление | Приоритет |
|---|----------|--------|-------------|-----------|
| B1 | **`get_node_or_null()` со строковыми путями** вместо `@onready` | `BattleUI._connect_skeleton()`: 30+ вызовов `get_node_or_null("top_panel/top_vbox/status")` | Заменить на `@onready var _status: Label = $"top_panel/top_vbox/status"` — компилятор проверит путь при загрузке сцены | **High** |
| B2 | **Ручное создание нод вместо сцен** | `var node := Node2D.new()` в тестах и некоторых системах | Для повторяющихся структур — вынести в `.tscn` | **Low** |
| B3 | **Отсутствие `class_name` в некоторых скриптах** | `scripts/autoload/services.gd` — нет `class_name`, только `extends Node` | Добавить `class_name Services` для единообразия | **Low** |
| B4 | **`await` без проверки `is_inside_tree()`** | `BattleTurnExecutor._advance_to_next_turn()`: `await get_tree().create_timer(...)` — если нода удалена до истечения таймера, будет ошибка | Проверять `is_inside_tree()` после `await` (частично сделано через `_is_stale`, но не везде) | **Medium** |
| B5 | **Сигналы без `disconnect`** | `GameEventBus` подключается в `CursorController._ready()`, но `CursorController` не отключает при `queue_free()` | Использовать `CONNECT_ONE_SHOT` или отключать в `_exit_tree()` | **Medium** |

### 2.2. SOLID / DRY / KISS

| Принцип | Нарушение | Где | Приоритет |
|---------|-----------|-----|-----------|
| **SRP** | `GameNumbers.gd` хранит константы для боя, карты, города, арены, славы, потребностей, демографии — 7+ доменов | `scripts/constants/GameNumbers.gd` | **High** |
| **DRY** | `_make_city()` / `_make_hero()` дублируются в 8+ тестовых файлах вместо использования `TestFactories` | `tests/` | **Medium** |
| **DRY** | Логика `_ring_yield_short()` продублирована в `CityArenaView.gd` и `ArenaHexCell.gd` | оба файла | **Medium** |
| **KISS** | `CityArenaModel` — чистый делегат в 5 других классов, не добавляет логики | `scripts/city/CityArenaModel.gd` | **Low** |
| **YAGNI** | `BattleEmulator.sequence_battle()` — сложный секвенсор для тестов, но используется в 1 тесте | `scripts/autoload/BattleEmulator.gd` | **Low** |

### 2.3. Безопасность и обработка ошибок

| # | Проблема | Где | Приоритет |
|---|----------|-----|-----------|
| B6 | **`JSON.parse_string()` без проверки на `null`** в `SpellbookRegistry._load_from_json()` — если файл повреждён, `data` будет `null`, но код проверяет `data is Array`, что корректно. Однако `BuildingDefs._ensure_loaded()` не проверяет `data is Array` после парсинга | `BuildingDefs.gd:23` | **Medium** |
| B7 | **Деление может возвращать `0`** → `float(wins) / float(decided)` при `decided == 0` → `NaN` | `test_battle_balance.gd:25` | **Medium** |
| B8 | **`FileAccess.open()` без проверки `null`** в `gen_en_po.gd:97` | `tools/gen_en_po.gd` | **Low** |

### 2.4. Naming и структура

| Проблема | Пример | Рекомендация |
|----------|--------|-------------|
| Смешение языков в комментариях | `// ИСПРАВЛЕНИЕ: Services.resolve` рядом с `// FIX: prevent tween overlap` | Стандартизировать на английский |
| Имена файлов: `services.gd` (lowercase) vs `ServiceLocator.gd` (PascalCase) | `scripts/autoload/services.gd` | Привести к `PascalCase` для `class_name`-файлов |
| `_t`, `_p`, `_s`, `_r` в `tune_city_arena.gd` | повсюду в тунере | Развернуть: `_tick`, `_proc`, `_score` |

---

## 3. Алгоритмы и структуры данных

### 3.1. Обнаруженные алгоритмы

| Алгоритм | Где | Сложность | Оценка |
|----------|-----|-----------|--------|
| **A\* pathfinding** | `HexPathfinding.astar_path()` | O(V log V) | ✅ Корректно, `MinHeap` бинарный — оптимален |
| **BFS** | `HexPathfinding.bfs_path()`, `bfs_reachable()` | O(V + E) | ✅ Корректно |
| **Dijkstra** | `HexPathfinding.dijkstra()` | O(V log V) | ✅ Корректно, `PackedFloat32Array` — хороший выбор |
| **Hex ring (O(r))** | `HexUtils.ring()` | O(r) | ✅ Оптимизировано с O(r²) |
| **Flood fill (visibility)** | `VisibilityMap._fill_disk()` | O(r²) через `ring()` | ✅ Использует `ring()` → O(r) |
| **Hex cube coordinates** | `HexUtils.offset_to_cube()` | O(1) | ✅ Стандартный подход |
| **Sorting: initiative** | `BattleState.build_queue()` | O(n log n) | ✅ Корректно |
| **Random map generation** | `MapModel.generate_noise()` | O(W×H) | ✅ FastNoiseLite |

### 3.2. Граничные случаи

| # | Проблема | Где | Приоритет |
|---|----------|-----|-----------|
| C1 | **`HexPathfinding.dijkstra_path()`**: если `cost_fn.call(c)` возвращает `INF` для текущей клетки, `break` выходит из цикла, но `path` может содержать только часть. Предупреждение логируется, но возвращается неполный путь. | `HexPathfinding.gd:178-183` | **Medium** |
| C2 | **`MinHeap` не поддерживает `decrease-key`** — при обновлении приоритета добавляется дубликат. Это корректно (ленивое удаление через `if cur_g > g_score[cur_idx]: continue`), но увеличивает память до O(E) в худшем случае. | `HexPathfinding.astar_path()` | **Low** (допустимо для текущего размера карт) |
| C3 | **`HexUtils.ring()`**: `dirs` массив содержит `Vector2i`, но кубические направления требуют `Vector3i`. Код строит `Vector3i(dirs[i].x, -dirs[i].x - dirs[i].y, dirs[i].y)` — корректно, но хрупко при изменении `dirs`. | `HexUtils.gd:92-97` | **Low** |
| C4 | **`ArenaClusterSystem._city_version()`**: хеш-функция использует `bld.def.id.hash()` — при коллизии хешей двух разных `StringName` версия совпадёт ложно. Вероятность мала, но для надёжности лучше добавить `bld.cell` в хеш (уже сделано). | `ArenaClusterSystem.gd:80` | **Low** |

### 3.3. Потенциальные оптимизации

| # | Что | Где | Предложение | Приоритет |
|---|-----|-----|-------------|-----------|
| C5 | `VisibilityMap.recompute()` создаёт новый `Dictionary` каждый раз | `VisibilityMap.gd` | Переиспользовать буфер, если `visible` не изменился (частично сделано через `changed`) | **Low** |
| C6 | `BattleState._reachable_cache` — `Dictionary[cell][speed]`, но инвалидация полная | `BattleState.gd` | Для больших боёв — версионирование кэша по `_board_version` вместо полной очистки | **Low** |
| C7 | `GameText` вызывает `TranslationServer.translate()` при каждом обращении | `GameText.gd` | Для горячих путей (каждый кадр) — кэшировать результат | **Low** |

---

## 4. Рефакторинг — конкретные правки

### R1. Разделение `GameNumbers.gd` на доменные модули — **High**

**Что:** Разбить один файл на подфайлы по доменам.

**Зачем:** Устранение конфликтов при параллельной разработке, улучшение навигации, SRP.

**До:**
```
# scripts/constants/GameNumbers.gd — 400+ строк, всё в одном файле
const CAMERA_SPEED := 600.0
const BATTLE_HEX_OUTLINE_RADIUS := 38.0
const MAP_SIZE_MIN := 40
const CITY_CYCLE_TURNS := 7
const ARENA_RADIUS := 5
const PROSPERITY_BASE := 50.0
const RAID_CHANCE_BASE := 0.10
...
```

**После:**
```
# scripts/constants/GameNumbers.gd — фасад
class_name GameNumbers
const Camera    = preload("res://scripts/constants/numbers_camera.gd")
const Battle    = preload("res://scripts/constants/numbers_battle.gd")
const Map       = preload("res://scripts/constants/numbers_map.gd")
const City      = preload("res://scripts/constants/numbers_city.gd")
const Arena     = preload("res://scripts/constants/numbers_arena.gd")
const Prosperity= preload("res://scripts/constants/numbers_prosperity.gd")
const Raid      = preload("res://scripts/constants/numbers_raid.gd")
# Обратная совместимость:
const CAMERA_SPEED = Camera.CAMERA_SPEED
const BATTLE_HEX_OUTLINE_RADIUS = Battle.BATTLE_HEX_OUTLINE_RADIUS
# ... и т.д.
```

**Альтернатива (проще):** Оставить один файл, но разбить на `# ─── Домен ───` секции и использовать `gdformat` для автоформатирования. Для текущего размера проекта это может быть достаточно.

---

### R2. Устранение статического состояния `WorldPersistence` — **High**

**Что:** Заменить `static var pending_save` / `pending_new_game` на инъекцию через `Services`.

**Зачем:** Неявная глобальная мутация, сложно тестировать, не сбрасывается в `StaticCaches.reset_all()`.

**До:**
```gdscript
# WorldPersistence.gd
static var pending_save: SaveData = null
static var pending_new_game: _HeroProfile = null

# CharacterCreationUI.gd
func _on_create() -> void:
    WorldPersistence.pending_new_game = _profile
    get_tree().change_scene_to_file(_WORLD_SCENE)
```

**После:**
```gdscript
# WorldPersistence.gd — нестатические поля, экземпляр в Services
var pending_save: SaveData = null
var pending_new_game: _HeroProfile = null

# services.gd — регистрация
registry.register_singleton(&"persistence", WorldPersistence.new())

# CharacterCreationUI.gd
func _on_create() -> void:
    var persistence = Services.resolve(&"persistence")
    persistence.pending_new_game = _profile
    get_tree().change_scene_to_file(_WORLD_SCENE)
```

---

### R3. Замена `get_node_or_null()` на `@onready` — **High**

**Что:** В `BattleUI._connect_skeleton()` и аналогичных методах.

**Зачем:** Компилятор Godot проверяет пути при загрузке сцены; исчезают опечатки в строковых путях; быстрее (не парсит путь при каждом вызове).

**До:**
```gdscript
func _connect_skeleton() -> void:
    _status = get_node_or_null("top_panel/top_vbox/status") as Label
    _active_info = get_node_or_null("top_panel/top_vbox/active_info") as Label
    _preview = get_node_or_null("top_panel/top_vbox/preview") as Label
    _bottom_bar = get_node_or_null("bottom_bar") as HBoxContainer
    _initiative_list = get_node_or_null("initiative_panel/initiative_list") as ItemList
    # ... ещё 20+ строк
```

**После:**
```gdscript
@onready var _status: Label = $"top_panel/top_vbox/status"
@onready var _active_info: Label = $"top_panel/top_vbox/active_info"
@onready var _preview: Label = $"top_panel/top_vbox/preview"
@onready var _bottom_bar: HBoxContainer = $"bottom_bar"
@onready var _initiative_list: ItemList = $"initiative_panel/initiative_list"

func _connect_skeleton() -> void:
    # Только подключение сигналов и настройка, без get_node
    _end_turn_btn.pressed.connect(func(): end_turn_pressed.emit())
    # ...
```

---

### R4. Устранение дублирования `_ring_yield_short()` — **Medium**

**Что:** Вынести в `ArenaRingSystem` или `GameNumbers`.

**До (в обоих файлах):**
```gdscript
# CityArenaView.gd и ArenaHexCell.gd — идентичный код
func _ring_yield_short(ring: int) -> String:
    var y: Dictionary = GameNumbers.ring_yield(ring)
    var food: float = float(y.get(&"food", 0.0))
    var ind: float = float(y.get(&"industry", 0.0))
    var parts: Array[String] = []
    if food > 0.0: parts.append("🌾" + ("%.1f" % food))
    if ind > 0.0: parts.append("🏭" + ("%.1f" % ind))
    return ", ".join(parts)
```

**После:**
```gdscript
# ArenaRingSystem.gd — один источник
static func ring_yield_label(ring: int) -> String:
    var y: Dictionary = GameNumbers.ring_yield(ring)
    var parts: Array[String] = []
    for key in [&"food", &"industry"]:
        var v: float = float(y.get(key, 0.0))
        if v > 0.0:
            var icon := "🌾" if key == &"food" else "🏭"
            parts.append(icon + ("%.1f" % v))
    return ", ".join(parts)
```

---

### R5. Защита от деления на ноль в тестах баланса — **Medium**

**До:**
```gdscript
func _side_rate(...) -> float:
    ...
    return float(wins) / float(decided)  # decided может быть 0
```

**После:**
```gdscript
func _side_rate(...) -> float:
    ...
    if decided == 0:
        return 0.5  # нет решённых боёв — считаем 50/50
    return float(wins) / float(decided)
```

---

### R6. `BattleFlow` — защита от повторного старта — **Medium**

**До:**
```gdscript
func start_battle(...) -> void:
    if _active:
        return
    _active = true
    var battle := _BATTLE_SCENE.instantiate()
    get_tree().root.add_child(battle)
    battle.battle_finished.connect(_on_battle_finished.bind(battle))
    battle.call_deferred("start_battle", ...)
```

**После:**
```gdscript
var _active_battle: Node = null

func start_battle(...) -> void:
    if _active_battle != null and is_instance_valid(_active_battle):
        return
    _active_battle = _BATTLE_SCENE.instantiate()
    get_tree().root.add_child(_active_battle)
    _active_battle.battle_finished.connect(_on_battle_finished.bind(_active_battle))
    _active_battle.call_deferred("start_battle", ...)

func _on_battle_finished(..., battle: Node) -> void:
    _active_battle = null
    battle.queue_free()
    ...
```

---

### R7. Отключение сигналов `GameEventBus` в `CursorController` — **Medium**

**До:**
```gdscript
func _ready() -> void:
    _connect_context(GameEventBus)
# Нет _exit_tree()
```

**После:**
```gdscript
func _exit_tree() -> void:
    if GameEventBus.hero_moving_changed.is_connected(_on_hero_moving_changed):
        GameEventBus.hero_moving_changed.disconnect(_on_hero_moving_changed)
    if GameEventBus.resource_extracted.is_connected(_on_resource_extracted):
        GameEventBus.resource_extracted.disconnect(_on_resource_extracted)
    if GameEventBus.battle_completed.is_connected(_on_battle_ended):
        GameEventBus.battle_completed.disconnect(_on_battle_ended)
    if GameEventBus.battle_lost.is_connected(_on_battle_ended):
        GameEventBus.battle_lost.disconnect(_on_battle_ended)
```

---

## 5. Инструкция для локального агента

### Пошаговый план

#### Фаза 1 — Критические правки (1-2 дня)

| Шаг | Файл | Действие | Проверка |
|-----|------|----------|----------|
| 1.1 | `scripts/autoload/WorldPersistence.gd` | Убрать `static` с `pending_save`, `pending_new_game`; зарегистрировать экземпляр в `Services` | `grep -r "pending_save\|pending_new_game" --include="*.gd"` → нет `static` |
| 1.2 | `scripts/ui/CharacterCreationUI.gd`, `scripts/ui/MainMenu.gd` | Обновить обращения к `pending_*` через `Services.resolve(&"persistence")` | Запуск: `godot --headless -s tests/test_city_screen.gd` |
| 1.3 | `scripts/core/StaticCaches.gd` | Добавить сброс `WorldPersistence` в `reset_all()` | `grep "WorldPersistence" scripts/core/StaticCaches.gd` |
| 1.4 | `tests/test_battle_balance.gd` | Добавить защиту от `decided == 0` | `godot --headless -s tests/test_battle_balance.gd` |

#### Фаза 2 — Структурные правки (2-3 дня)

| Шаг | Файл | Действие | Проверка |
|-----|------|----------|----------|
| 2.1 | `scripts/ui/BattleUI.gd` | Заменить `get_node_or_null()` на `@onready` | `godot --headless --check-only -s scripts/ui/BattleUI.gd` + запуск боевой сцены |
| 2.2 | `scripts/world/CityArenaView.gd`, `scripts/ui/ArenaHexCell.gd` | Вынести `_ring_yield_short()` в `ArenaRingSystem.ring_yield_label()` | `godot --headless -s tests/test_city_arena.gd` |
| 2.3 | `scripts/systems/BattleFlow.gd` | Добавить `_active_battle` вместо `_active` флага | Ручной тест: два быстрых старта боя |
| 2.4 | `scripts/autoload/CursorController.gd` | Добавить `_exit_tree()` с отключением сигналов | Запуск/выход из мировой сцены 5 раз, проверка логов |

#### Фаза 3 — Разделение `GameNumbers` (опционально, 1-2 дня)

| Шаг | Файл | Действие | Проверка |
|-----|------|----------|----------|
| 3.1 | `scripts/constants/` | Создать `numbers_camera.gd`, `numbers_battle.gd`, `numbers_map.gd`, `numbers_city.gd`, `numbers_arena.gd` | `godot --headless --check-only` на каждом |
| 3.2 | `scripts/constants/GameNumbers.gd` | Оставить как фасад с `const X = preload(...)` | Полный прогон тестов |

#### Фаза 4 — Тесты и приёмка

```bash
# Прогон всех тестов
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/

# Статическая проверка
godot --headless --check-only

# Проверка отсутствия статических мутаций
grep -rn "static var" scripts/ --include="*.gd" | grep -v "_cache\|_handlers\|_config"

# Проверка сигналов без disconnect
grep -rn "GameEventBus\.\w*\.connect" scripts/ --include="*.gd" | wc -l
grep -rn "GameEventBus\.\w*\.disconnect" scripts/ --include="*.gd" | wc -l
```

### Критерии приёмки

| Критерий | Метрика |
|----------|---------|
| Все тесты проходят | `gdUnit4` — 0 failures |
| Нет `static var` для сессионного состояния | `grep` — 0 совпадений вне кэшей |
| Нет `get_node_or_null()` в `BattleUI` | `grep` — 0 совпадений |
| Дублирование `_ring_yield_short` устранено | Функция существует только в `ArenaRingSystem` |
| `BattleFlow` не создаёт дублей | Ручной тест: 3 последовательных боя без краша |
| Сигналы `GameEventBus` отключаются | `grep` — количество `disconnect` ≥ количеству `connect` для `CursorController` |

---

## Итоговая оценка

| Направление | Оценка | Комментарий |
|-------------|--------|-------------|
| Архитектура | **7/10** | Хороший DI, сплит моделей, но «бог-файлы» и статическое состояние |
| Лучшие практики | **6/10** | Много ручного `get_node_or_null`, смешение языков, не все сигналы отключаются |
| Алгоритмы | **8/10** | Корректный A*, BFS, Dijkstra; hex-математика правильная; O(r) ring |
| Тестируемость | **7/10** | Хороший набор тестов, `TestFactories`, но часть тестов дублирует фабрики |
| Масштабируемость | **6/10** | `GameNumbers`/`GameText`/`ThemeConfig` станут узким местом при росте команды |

**Главный приоритет:** R1 (разделение `GameNumbers`) + R2 (статика `WorldPersistence`) + R3 (`@onready` вместо `get_node_or_null`). Эти три изменения снизят количество конфликтов, улучшат тестируемость и уберут класс ошибок «опечатка в строковом пути ноды».

# Аудит тестовой инфраструктуры «Sigil of the Unwilling»

---

## 1. Ревизия фреймворка: GUT vs gdUnit4

### 1.1. Фактический статус

Провёл поиск по всем маркерам GUT в предоставленном коде:

| Маркер GUT | Найден? | Где искал |
|---|---|---|
| `extends "res://addons/gut/test.gd"` / `extends GutTest` | ❌ нет | все `tests/**/*.gd` |
| `gut.p()`, `gut.assert_*` | ❌ нет | все тесты |
| `assert_eq` / `assert_true` / `assert_false` (GUT-сигнатура) | ❌ нет | все тесты |
| `before_each` / `after_each` / `before_all` / `after_all` | ❌ нет | все тесты |
| `.gutconfig.json`, `gut_config.json`, `.gut/` | ❌ нет | дерево файлов |
| `parametrize`-декораторы GUT | ❌ нет | все тесты |

**Вывод: следов GUT в предоставленном коде нет.** Все тесты уже на gdUnit4:
- базовый класс `GdUnitTestSuite`;
- ассерты `assert_that / assert_bool / assert_int / assert_float / assert_str / assert_object / assert_vector / assert_dict / assert_array / assert_error`;
- хуки `before()` (suite-level), `before_test()` / `after_test()` (per-test);
- `auto_free()` для управления памятью.

Детектор фреймворка в `scripts/core/Platform.gd` также проверяет только gdUnit4:
```gdscript
static func is_test_framework_run() -> bool:
    for arg in OS.get_cmdline_args():
        if arg.begins_with("--add") and arg.contains("gdUnit4"): return true
        if arg.begins_with("--gdUnit4"): return true
        if arg.ends_with("GdUnitCmdTool.gd"): return true
    return false
```

### 1.2. Чек-лист верификации в полном проекте

Предоставленный дамп не содержит `project.godot` и `addons/`. Чтобы гарантировать отсутствие GUT, выполнить:

```bash
# 1. Аддон GUT не установлен
ls addons/ | grep -i gut && echo "GUT FOUND — удалить" || echo "OK: GUT нет"

# 2. В project.godot нет автозагрузки/ссылок на GUT
grep -ri "gut" project.godot

# 3. Нет конфигов GUT
find . -name ".gutconfig.json" -o -name "gut_config*.json" -o -type d -name ".gut"

# 4. Ни один скрипт не наследует GUT
grep -rl 'addons/gut' tests/ scripts/
```

Если хотя бы одна команда что-то вернёт — удалить аддон `addons/gut/`, вычистить ключи из `project.godot` и сконвертировать найденные тесты (см. шаблон ниже). В текущем дампе конвертация **не требуется**.

<details>
<summary>Шаблон конвертации GUT → gdUnit4 (на случай, если найдётся в полном проекте)</summary>

```gdscript
# БЫЛО (GUT):
extends "res://addons/gut/test.gd"
var _obj
func before_each(): _obj = MyObj.new()
func after_each(): _obj.free()
func test_value():
    assert_eq(_obj.value(), 42, "сообщение")
    assert_true(_obj.is_valid())

# СТАЛО (gdUnit4):
extends GdUnitTestSuite
var _obj: MyObj
func before_test(): _obj = MyObj.new()
func after_test(): _obj.free()   # либо auto_free(_obj) в before_test
func test_value() -> void:
    assert_int(_obj.value(), "сообщение").is_equal(42)
    assert_bool(_obj.is_valid()).is_true()
```
Маппинг ассертов: `assert_eq→assert_*(...).is_equal`, `assert_true→assert_bool(...).is_true`, `assert_false→.is_false`, `assert_null→assert_object(...).is_null`, `assert_has→assert_array(...).contains`, `assert_string_contains→assert_str(...).contains`.
</details>

---

## 2. Структура тестов

### 2.1. Текущее дерево и найденные дефекты

```
tests/
├── core/                    ← модульные ( Организовано )
├── entities/
├── systems/city/
├── functional/
├── integration/
├── unit/{core,data,systems,ui,world}/
├── mcp/                     ← Python, MCP-тесты
├── helpers/                 ← фабрики + САМОПИСНЫЙ MCP-клиент
├── spell_validation/        ← валидатор (не тесты)
├── fakes/
├── TestBattleRules.gd       ← ⚠️ дубль
├── TestCityEconomy.gd       ← ⚠️ дубль
├── TestHexUtils.gd          ← ⚠️ дубль
└── test_*.gd (~40 файлов)   ← ⚠️ свалка в корне
```

### 2.2. Критичные структурные проблемы

| # | Проблема | Файлы | Приоритет |
|---|---|---|---|
| S1 | **Дублирование тестов**: корневые `Test*.gd` пересекаются с организованными | `TestBattleRules.gd` ↔ `core/BattleRulesTest.gd`; `TestHexUtils.gd` ↔ `core/HexUtilsTest.gd`; `TestCityEconomy.gd` ↔ `unit/world/CityGrowthServiceTest.gd` | **High** |
| S2 | **Три конвенции именования одновременно**: `Test*.gd`, `test_*.gd`, `*Test.gd` | весь `tests/` | **Medium** |
| S3 | **~40 файлов свалены в корень** `tests/` без разделения по доменам | `tests/test_*.gd` | **High** |
| S4 | **Самописный MCP-клиент** дублирует возможности tugcantopaloglu/godot-mcp | `helpers/mcp_client.py`, `mcp/conftest.py` | **High** |
| S5 | **Нет разделения unit/integration в `unit/`**: `unit/test_city_system.gd` фактически интеграционный | `unit/test_city_system.gd` | **Medium** |
| S6 | Отсутствует `test.gd`-агрегатор/сьюты по доменам — нельзя запустить «только город» или «только бой» | — | **Low** |

### 2.3. Разбор дублей (S1) — что оставить

| Корневой файл | Организованный аналог | Решение |
|---|---|---|
| `TestBattleRules.gd` (тест урона + 7v7-перф) | `core/BattleRulesTest.gd` (множитель, luck, morale, превью) | **Объединить в `core/BattleRulesTest.gd`**, перф-кейс перенести в `functional/`; корневой удалить |
| `TestHexUtils.gd` (distance, cube roundtrip) | `core/HexUtilsTest.gd` (полный набор: ring, neighbors, idx) | **Удалить корневой** — полностью покрыт |
| `TestCityEconomy.gd` (starvation, growth) | `unit/world/CityGrowthServiceTest.gd` + `unit/test_city_system.gd` | **Удалить корневой** — логика продублирована |

### 2.4. Целевая структура

```
tests/
├── unit/                      # чистые, без сцены/автозагрузок, < 50 мс
│   ├── core/  data/  systems/  world/  ui/
├── integration/               # несколько систем + автозагрузки
├── functional/                # запуск сцен, перф, память
├── mcp/                       # только через tugcantopaloglu/godot-mcp
├── helpers/                   # test_factories.gd (БЕЗ mcp_client.py)
├── fakes/
└── suites/                    # доменные агрегаторы (опционально)
    ├── CityTestSuite.gd
    ├── BattleTestSuite.gd
    └── WorldTestSuite.gd
```

---

## 3. Покрытие кода тестами

### 3.1. Матрица покрытия по модулям

| Домен | Скрипт | Тест | Покрытие |
|---|---|---|---|
| **Ядро** | `HexUtils`, `HexPathfinding`, `MinHeap` | `core/HexUtilsTest`, `core/HexPathfindingTest`, `test_min_heap` | ✅ хорошее |
| | `BattleRules` | `core/BattleRulesTest` + `TestBattleRules` | ✅ |
| | `TurnScheduler` | `core/TurnSchedulerTest` | ✅ |
| | `VisibilityMap` | `unit/core/VisibilityMapTest` | ✅ |
| | `StaticCaches` | `unit/core/StaticCachesTest` | ⚠️ только «не падает» |
| **Данные** | `ResourceRegistry`, `ResourceDef` | `unit/data/ResourceRegistryTest`, `test_keys_matrix` | ✅ |
| | `TerrainCostTable` | `unit/data/TerrainCostTableTest` | ✅ |
| | `BuildingDefs` | косвенно в `CityBuildingServiceTest` | ⚠️ нет прямого |
| | `SpellbookRegistry` | `test_spell_registry`, `test_spell_system` | ✅ |
| | `UnitRegistry` | `test_unit_registry` | ✅ |
| | `ArtifactRegistry` | `test_artifact_system` | ✅ |
| | `RaceClassRegistry` | `test_race_class_matrix` | ✅ |
| **Бой** | `BattleState` | частично в `BattleRulesTest`, `test_battle_state` | ⚠️ неполное (нет тестов `build_queue`, `advance_turn`, `do_wait`) |
| | `BattleTurnExecutor` | `test_applied_fixes`, частично | ⚠️ слабое |
| | `BattleAI` | `test_battle_ai` | ✅ |
| | `BattleActionResolver` | `test_battle_action_resolver` | ✅ |
| | `BattleView` / `BattleInput` | `unit/systems/BattleViewTest`, `integration/BattleInputTest` | ✅ |
| **Город** | `CityBuildingService` | `unit/world/CityBuildingServiceTest` | ✅ |
| | `CityGrowthService` | `unit/world/CityGrowthServiceTest` | ✅ |
| | `CitySerializer` | `unit/world/CitySerializerTest` | ✅ |
| | `City` (модель) | `unit/world/CityTest`, `unit/test_city_system` | ✅ (дубль) |
| | `BoroughRules`, `MarketSystem`, `RaidSystem`, `ReputationSystem`, `ZoningSystem` | `test_city_*`, `test_market_walls_raids` | ✅ |
| **Демография** | `Character`, `CharacterRegistry`, `DemographicTurnProcessor`, `TraitRegistry` | `test_characters`, `test_demographic_processor`, `test_trait_registry` | ✅ |
| **Экономика** | `EconomicTurnProcessor`, `CityIncomeProcessor`, `ProductionChain`, `ResourceContext` | `test_production_chain`, `test_resource_context`, `test_city_chains` | ✅ |
| **Мир** | `WorldBattleCoordinator` | `test_battle_coordinator`, `test_refactoring_round2` | ⚠️ |
| | `WorldPersistence`, `SaveManager`, `SaveData` | `test_save_roundtrip`, `test_save_v3`, `unit/test_world_persistence` | ✅ |
| | `WorldController` | `test_worldcontroller_succession_wiring`, `test_legend_chronicle` | ⚠️ только wiring |
| | `SuccessionController`, `HeroLifecycleSystem` | `test_succession`, `test_hero_survival`, `test_hero_lifecycle` | ✅ |
| **Герой** | `HeroMovementController` | `test_hero_movement`, `test_hero_planned_route` | ✅ |
| | `HeroInventory`, `HeroMagic`, `HeroNeeds`, `HeroSkills`, `HeroTools` | `test_magic`, `test_hero_serialize`, `test_inventory` | ✅ |
| **UI** | все панели (`AdventureUI`, `BattleUI`, `CityScreen`, `MainMenu`, `SettingsScreen`, …) | ❌ практически нет | **пробел** |
| **Рендер/карта** | `MapGenerator`, `MapModel`, `TileAtlas`, `HexAutotiler` | `functional/test_tileset_integrity`, `test_map_*` | ⚠️ частичное |

### 3.2. Критичные пробелы (добавить)

| # | Что не покрыто | Предлагаемый тест | Приоритет |
|---|---|---|---|
| C1 | `BattleState.build_queue` / `advance_turn` / `do_wait` (порядок инициативы, переходы ходов) | `unit/systems/BattleStateQueueTest.gd` | **High** |
| C2 | UI-логика: `BattleUI._connect_skeleton`, `SettingsScreen._restore_state`, `CityScreen.build_pressed` | вынести логику из `_ready`/`get_node` и покрыть | **High** |
| C3 | `GameLogger` (уровни, формат тега) | `unit/core/GameLoggerTest.gd` | Low |
| C4 | `GameSession.serialize/deserialize` граничные (битый `state`) | расширить `test_succession` | Medium |
| C5 | `TileAtlas.build_hex_tileset` при отсутствии листа | `unit/world/TileAtlasFallbackTest.gd` | Medium |
| C6 | `WorldPersistence.apply_loaded_save` на повреждённых данных | `integration/PersistenceCorruptTest.gd` | Medium |
| C7 | Negativ-кейсы `BattleInput` (клик вне поля, ПКМ во время таргетинга) | расширить `integration/BattleInputTest` | Medium |

### 3.3. Измерение покрытия

В проекте не подключён инструмент покрытия. Включить через gdUnit4:

```bash
# Запуск с отчётом о покрытии (gdUnit4 поддерживает --ignoreHeadlessMode и отчёт)
godot --headless --path . \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add tests/unit --add tests/integration \
  --ignoreHeadlessMode \
  --reportJunit ./reports/junit.xml
```

Для реального процента строк подключить `gdCoverage`/внешний `gcov`-подобный инструмент или `GutPlugin`-аналог на базе `ScriptAnalyzer`; минимум — фиксировать количество исполненных тестов и маппинг на модули в CI.

---

## 4. Логика тестов: найденные дефекты

### 4.1. Хрупкие / флакающие тесты

| # | Файл | Дефект | Исправление | Приоритет |
|---|---|---|---|---|
| L1 | `mcp/conftest.py` | `asyncio.sleep(10)` / `sleep(10)` как ожидание готовности сцены | заменить на поллинг-ожидание признака (см. §5.4 `wait_ready` по `game_eval`) | **High** |
| L2 | `mcp/conftest.py` | хардкод порта `9090` в `_wait_port_free` | вынести в `ENV`/константу, проверять занятость без привязки к номеру | Medium |
| L3 | `mcp/test_battle_tween.py` | `bs.attacker_units[player['idx']]` — индекс из сериализации может не совпадать с позицией в массиве | резолвить юнит по `uid`, а не по `idx` | **High** |
| L4 | `functional/test_world_scenario.gd` | `await _wait(2.0)` — тайминговая зависимость | ждать сигнала/состояния (`is_death_sequence_open`), а не время | **High** |
| L5 | `helpers/test_factories.gd` → `make_battle_state` | `Services.resolve(&"units")` — падает, если автозагрузка не поднята в headless | передавать реестр параметром с фолбэком на `UnitRegistry.new()` | Medium |
| L6 | `test_session_reset.gd` | полагается на `ArenaClusterSystem` static-кэш между кейсами | каждый кейс начинать с `reset()` (частично сделано) | Low |
| L7 | `mcp/test_shard_pruning.py` | использует `mock`-объекты `MockWorld` со `weakref` и ручным `get_hero` — дублирует реальный `WorldController` | использовать реальный `WorldController` + `WorldBootstrap` или выделенный фейк из `tests/fakes` | Medium |

### 4.2. Логические ошибки в ассертах/подготовке

| # | Файл | Проблема | Фикс |
|---|---|---|---|
| L8 | `TestBattleRules.gd::test_battle_7v7_performance` | `emulate_battle` собирает `UnitStats` из полей spec'а, но передаёт только `id/name/count` → юниты со статом по умолчанию 3/50 могут не дать завершённого боя | передавать реальные `attack/defense/hp/speed` из `UnitRegistry` (частично закомментировано как фикс — применить) |
| L9 | `test_battle_ai.gd` | в `test_flying_ai_*` `obstacles` передаётся как `{}`, но комментарии описывают занятые клетки — кейс «все соседние заняты» фактически не проверяется | построить `obstacles` из соседей цели |
| L10 | `unit/test_world_persistence.gd::test_chain_service_has_methods` | проверяет только наличие методов, а не поведение; `get_script() == ResourceChainService` — хрупкое сравнение | проверить кэш: два вызова `build_extraction_keys` с одинаковым героем возвращают идентичный результат |
| L11 | `test_refactoring_round2.gd::test_marker_click_no_double` | тело `assert_bool(true).is_true()` — тест-заглушка, ничего не проверяет | либо реализовать, либо удалить |
| L12 | `test_settings_guard.gd` | `settings.apply_display_mode()` в headless лишь «не падает», не проверяет поведение | как минимум проверить `DisplayServer.window_set_mode` не вызван через заглушку |

### 4.3. Проблемы изоляции и детерминизма

- **Общее состояние автозагрузок.** Тесты читают/пишут `Resources`, `Spells`, `Units`, `GameEventBus`. Между кейсами нужен сброс:
  ```gdscript
  func before_test() -> void:
      Resources.reset(); Spells.reset(); Units.reset()
  ```
  Сейчас это делается выборочно (`before_test` в `test_artifact_system.gd` есть, в других — нет).
- **Подписки на `GameEventBus` без отписки.** `test_hero_survival.gd`, `test_legend_chronicle.gd` подключают `GameEventBus.hero_died/hero_successor` и отключают их вручную. Риск утечки при падении теста. Обернуть в `try/finally`-подобный паттерн или использовать `auto_free` + локальный экземпляр шины вместо глобальной:
  ```gdscript
  var bus := GameEventBus.new()   # изолированная шина для теста
  add_child(bus); auto_free(bus)
  ```
- **Детерминизм случайности.** Часть тестов фиксирует `rng.seed` (хорошо), часть полагается на `RandomNumberGenerator.new()` без сида → потенциальный флак. Правило: любой `RandomNumberGenerator` в тесте — только с явным `seed`.

---

## 5. MCP: конвертация на `tugcantopaloglu/godot-mcp`

### 5.1. Что является «самописным» и подлежит замене

| Файл | Роль | Действие |
|---|---|---|
| `tests/helpers/mcp_client.py` | Самописный `GodotMCPClient` на сыром `asyncio` + ручном JSON-RPC | **УДАЛИТЬ** |
| `tests/mcp/conftest.py` | Фикстуры, используют `GodotMCPClient` из helpers | **Переписать** на официальный MCP-клиент |
| `tests/mcp/test_*.py` (6 файлов) | Используют методы `mcp.execute_code`, `mcp.run_scene` и т.д. | Оставить, **методы-обёртки сохранить** тот же интерфейс, чтобы тело тестов почти не менялось |

Текущий `conftest.py` уже целится в `godot-mcp/build/index.js` (это и есть **сервер** `tugcantopaloglu/godot-mcp`), но общается с ним через самописный транспорт. Самописный клиент содержит комментарий, объясняющий, почему избегали официальный `mcp` SDK:

```python
# транспорт на чистом asyncio (JSON-RPC по строкам), без mcp SDK:
# stdio_client (anyio task group) требует вход/выход cancel scope в одной task,
# а pytest-фикстуры живут в разных — вешал teardown (проверено empirically).
```

Задача: использовать штатный механизм `tugcantopaloglu/godot-mcp` (официальный `mcp` SDK), корректно решив проблему anyio/pytest.

### 5.2. Зависимости

```toml
# tests/mcp/pyproject.toml
[project]
name = "sigil-mcp-tests"
requires-python = ">=3.11"
dependencies = [
    "pytest>=8.0",
    "pytest-asyncio>=0.24",
    "mcp>=1.2",          # официальный MCP-клиент для tugcantopaloglu/godot-mcp
    "anyio>=4.4",
]
```

```ini
# tests/mcp/pytest.ini
[pytest]
asyncio_mode = auto
asyncio_default_fixture_loop_scope = function
timeout = 300
addopts = -xvs --tb=short
```

### 5.3. Новая обёртка `tests/mcp/godot_mcp.py`

Тонкая обёртка над `ClientSession`, сохраняющая прежний высокоуровневый интерфейс — это позволяет **не переписывать тела 6 тестовых файлов**:

```python
"""Обёртка над tugcantopaloglu/godot-mcp через официальный MCP SDK."""
from __future__ import annotations

import json
import os
from typing import Any

from mcp import ClientSession

PROJECT_PATH = os.environ.get(
    "GODOT_PROJECT_PATH", "/Users/user/sigil-of-the-unwilling/game"
)


class GodotMCP:
    """Делегирует в ClientSession (tugcantopaloglu/godot-mcp)."""

    def __init__(self, session: ClientSession) -> None:
        self._session = session

    # ─── низкоуровневый вызов инструмента ─────────────────────
    async def _call(self, tool: str, **args: Any) -> Any:
        result = await self._session.call_tool(tool, args)
        # tugcantopaloglu/godot-mcp отдаёт результат в content[0].text как JSON
        text = result.content[0].text if result.content else "{}"
        return json.loads(text)

    # ─── высокоуровневый API (совместим со старыми тестами) ───
    async def execute_code(self, code: str) -> Any:
        data = await self._call("game_eval", code=code)
        if isinstance(data, dict) and "success" in data and "result" in data:
            if not data.get("success"):
                raise RuntimeError(f"game_eval failed: {data}")
            return data["result"]
        return data

    async def get_scene_tree(self) -> dict:
        return await self._call("game_get_scene_tree")

    async def get_node_property(self, path: str, prop: str) -> Any:
        return await self._call("game_get_property", nodePath=path, property=prop)

    async def set_node_property(self, path: str, prop: str, value: Any) -> None:
        await self._call("game_set_property", nodePath=path, property=prop, value=value)

    async def call_method(self, path: str, method: str, args: list | None = None) -> Any:
        return await self._call("game_call_method", nodePath=path, method=method, args=args or [])

    async def find_nodes_by_type(self, node_type: str) -> list[str]:
        return await self._call("game_find_nodes_by_class", className=node_type)

    async def run_scene(self, scene_path: str) -> None:
        await self._call("run_project", projectPath=PROJECT_PATH, scene=scene_path)

    async def stop_running_scene(self) -> None:
        await self._call("stop_project")

    async def wait_frames(self, frames: int = 10) -> None:
        # кадрируем через game_eval, а не asyncio.sleep
        await self.execute_code(f"await get_tree().process_frame; return {frames}")

    async def wait_ready(self, timeout_s: float = 60.0, poll_s: float = 0.5) -> None:
        """Поллинг готовности вместо asyncio.sleep(10)."""
        import asyncio

        deadline = asyncio.get_running_loop().time() + timeout_s
        last_err: Exception | None = None
        while asyncio.get_running_loop().time() < deadline:
            try:
                await self.execute_code("return 1")
                return
            except Exception as exc:  # noqa: BLE001
                last_err = exc
                await asyncio.sleep(poll_s)
        raise TimeoutError(f"godot-mcp not ready in {timeout_s}s") from last_err
```

### 5.4. Новый `tests/mcp/conftest.py`

Ключевой момент — корректная работа `stdio_client` (anyio task group) с pytest. Использую **`loop_scope`-совместимую фикстуру** и запускаю клиент так, чтобы вход/выход из контекстных менеджеров происходил в одной задаче:

```python
"""Фикстуры для MCP-тестов поверх tugcantopaloglu/godot-mcp (официальный SDK)."""
from __future__ import annotations

import os

import pytest
import pytest_asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from .godot_mcp import GodotMCP

SERVER_JS = os.environ.get(
    "GODOT_MCP_SERVER",
    "/Users/user/sigil-of-the-unwilling/godot-mcp/build/index.js",
)
STARTUP_TIMEOUT = float(os.environ.get("GODOT_MCP_STARTUP_TIMEOUT", "60"))

# Порты/ожидания больше не хардкодим: готовность определяем по game_eval.


@pytest_asyncio.fixture
async def mcp():
    """Подключение к tugcantopaloglu/godot-mcp на время теста.

    Важно: вход и выход из `stdio_client`/`ClientSession` находятся в одной
    задаче фикстуры — это обходит проблему anyio cancel scope, из-за которой
    раньше использовали самописный транспорт.
    """
    params = StdioServerParameters(command="node", args=[SERVER_JS])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            client = GodotMCP(session)
            yield client


@pytest_asyncio.fixture
async def battle_scene(mcp: GodotMCP):
    """Запуск сцены боя + ожидание готовности."""
    await mcp.run_scene("res://scenes/battle.tscn")
    await mcp.wait_ready(STARTUP_TIMEOUT)
    await mcp.wait_frames(30)
    yield mcp
    await mcp.stop_running_scene()


@pytest_asyncio.fixture
async def world_scene(mcp: GodotMCP):
    """Запуск мировой сцены + ожидание готовности."""
    await mcp.run_scene("res://scenes/world.tscn")
    await mcp.wait_ready(STARTUP_TIMEOUT)
    await mcp.wait_frames(60)
    yield mcp
    await mcp.stop_running_scene()
```

> Если используемая сборка `tugcantopaloglu/godot-mcp` поддерживает **SSE-транспорт** (HTTP), заменить `stdio_client` на `mcp.client.sse.sse_client(url)` — это полностью снимает проблему anyio task group и упрощает фикстуры. Проверить наличие флага/порта запуска сервера в `--help`.

### 5.5. Точечные правки в телах тестов

Интерфейс `GodotMCP` сохранён, поэтому правки минимальны:

**`test_battle_tween.py` — фикс L3 (резолв по `uid` вместо `idx`):**
```python
async def _get_unit_by_uid(mcp, uid: int, side: str) -> dict:
    return await mcp.execute_code(f"""
var bs = get_tree().current_scene.get_battle_state()
var arr = bs.attacker_units if "{side}" == "attacker" else bs.defender_units
for u in arr:
    if u.uid == {uid}:
        return {{"cell": {{"x": u.cell.x, "y": u.cell.y}}, "side": "{side}"}}
return {{"error": "unit not found"}}
""")
```
и в тесте после получения `units` выбирать цель по `uid`, а не по `idx`.

**`test_battle_profiling.py`, `test_hexutils_perf.py`, `test_resource_and.py`, `test_session_reset.py`, `test_shard_pruning.py`** — тела не меняются (используют `execute_code`), только убрать прямой импорт `GodotMCPClient`, если он был, и полагаться на фикстуру `mcp`.

### 5.6. Удаление самописного клиента

```bash
rm tests/helpers/mcp_client.py
# убедиться, что на него нет ссылок
grep -rn "mcp_client" tests/ && echo "ОСТАЛИСЬ ССЫЛКИ" || echo "OK: чисто"
```

---

## 6. Пошаговый план внедрения

### Фаза 1 — ревизия фреймворка (0.5 дня)
1. Выполнить чек-лист из §1.2 в полном проекте.
2. Если GUT найден — удалить `addons/gut/`, вычистить `project.godot`, сконвертировать по шаблону §1.2. В текущем дампе действий не требуется.

### Фаза 2 — реструктуризация тестов (1 день)
1. Удалить дубли: `tests/TestBattleRules.gd`, `tests/TestHexUtils.gd`, `tests/TestCityEconomy.gd`, предварительно перенеся уникальные кейсы (7v7-перф → `functional/`).
2. Переместить `tests/test_*.gd` из корня в `tests/{unit,integration,functional}/<домен>/` по матрице §3.1.
3. Привести имена к единой конвенции `test_<subject>.gd`.
4. Удалить тесты-заглушки (L11) или реализовать их.

### Фаза 3 — конвертация MCP (1 день)
1. `rm tests/helpers/mcp_client.py`.
2. Создать `tests/mcp/godot_mcp.py` (код §5.3).
3. Переписать `tests/mcp/conftest.py` (код §5.4).
4. Обновить `pyproject.toml` и `pytest.ini` (§5.2).
5. Применить фикс `uid`-резолва в `test_battle_tween.py` (§5.5).
6. Прогнать: `cd tests/mcp && pytest -q`.

### Фаза 4 — закрытие пробелов покрытия и фикс логики (2 дня)
1. Добавить тесты из §3.2 (приоритет High: C1 `BattleStateQueueTest`, C2 UI-логика).
2. Исправить флакающие кейсы §4.1 (заменить `asyncio.sleep`/`_wait` на ожидание состояния).
3. Ввести обязательный `rng.seed` для всех генераторов в тестах.
4. Изолировать `GameEventBus` в тестах подписок (§4.3).
5. Подключить отчёт junit/покрытие в CI (§3.3).

### Команды проверки
```bash
# GDScript-тесты (gdUnit4, headless)
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add tests/unit --add tests/integration --add tests/functional \
  --ignoreHeadlessMode --reportJunit reports/junit.xml

# MCP-тесты
cd tests/mcp && pytest -q

# Линтеры структуры: дублей в корне быть не должно
ls tests/Test*.gd && echo "ДУБЛИ ОСТАЛИСЬ" || echo "OK"
grep -rn "mcp_client" tests/ && echo "САМОПИСНЫЙ КЛИЕНТ ОСТАЛСЯ" || echo "OK"
```

### Критерии приёмки
| Критерий | Проверка |
|---|---|
| Нет следов GUT | чек-лист §1.2 пуст |
| Все тесты на gdUnit4 | `grep -rL "extends GdUnitTestSuite" tests/**/*.gd` пуст |
| Нет самописного MCP-клиента | `tests/helpers/mcp_client.py` удалён, ссылок нет |
| MCP-тесты используют официальный клиент | в `conftest.py` импорт `from mcp import ClientSession` |
| Нет дублей тестов | удалены корневые `Test*.gd` |
| Нет тестов-заглушек | нет `assert_bool(true).is_true()` как единственной проверки |
| Детерминизм | все `RandomNumberGenerator` в тестах имеют явный `seed` |
| MCP-тесты проходят | `pytest tests/mcp -q` — зелёные без `asyncio.sleep(10)` |