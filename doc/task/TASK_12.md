# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

---

## 1. Архитектура

### 1.1 Общая картина

| Слой | Файлы | Роль |
|---|---|---|
| **Ядро / утилиты** | `core/` (HexUtils, MinHeap, TurnScheduler, VisibilityMap, SaveData…) | Чистая логика, без сцен |
| **Данные / реестры** | `autoload/` (UnitRegistry, ResourceRegistry, SpellRegistry, ArtifactRegistry…), `data/` | Определения сущностей |
| **Системы** | `systems/` (BattleState, BattleAI, BattleTurnExecutor…) | Боевая логика |
| **Город** | `city/`, `world/City*.gd` | Экономика, рост, зонирование |
| **Мир** | `world/` (MapGenerator, WorldController, WorldSpawner…) | Карта, спавн, камера |
| **Сущности** | `entities/` (HeroController, UnitStack, Follower…) | Игровые объекты |
| **UI** | `ui/` (BattleUI, InfoPanel, MinimapPanel…) | Интерфейс |
| **Шаблонные заклинания** | `data/templates/t01…t19` | 19 обработчиков шаблонов |

### 1.2 Сильные стороны

- **Service Locator** через `Services` / `ServiceRegistry` — единая точка доступа к autoload-сервисам.
- **Event Bus** (`GameEventBus`) — глобальный сигнал-хаб, развязывает подсистемы.
- **TurnScheduler + TurnPhaseProcessor** — фазовая модель хода, расширяемая через `register_processor`.
- **Шаблонный движок заклинаний** (`TemplateEngine` + 19 обработчиков) — OCP: новое заклинание = новый шаблон без правки ядра.
- **Город разбит на сервисы** (`CityService`, `CityBuildingService`, `CityGrowthService`) — логика не в одном монолите.

### 1.3 Проблемы

| # | Проблема | Где | Влияние |
|---|---|---|---|
| A-1 | **God-объект `WorldController`** — хранит ссылки на 15+ подсистем, делегирует вызовы | `WorldController.gd` | Любое изменение тянет весь файл |
| A-2 | **`BattleState` совмещает данные + действия** (`apply_attack`, `apply_spell`, `do_move`, `build_queue`) | `BattleState.gd` | Нарушение SRP; тестирование действий требует полного состояния |
| A-3 | **Дублирование ролей между `BattleActionResolver` и `BattleState`** — оба имеют `apply_attack` / `apply_spell` | `BattleState.gd:apply_attack` → `BattleActionResolver.apply_attack` | Двойная диспетчеризация, путаница «кто владелец логики» |
| A-4 | **`City` наследует `CityData`, но добавляет бизнес-методы** (`get_yield`, `process_turn`, `build_building`) | `City.gd` | `City` — фасад на 6+ сервисов; сложно понять, что вызывает что |
| A-5 | **Отсутствие DI-контейнера** — `Services.resolve` вызывается внутри методов бизнес-логики | `SpellCaster.cast`, `ResourceChainService` | Жёсткая привязка к глобальному реестру |
| A-6 | **`BattleController` (Node2D) знает про `_view`, `_ui`, `_executor`, `_input`, `_fx`** | `BattleController.gd` | 5 прямых зависимостей в одном классе |

### 1.4 Рекомендации по архитектуре

**A-1 → Разбить `WorldController` на координаторы.**
Выделить `WorldSceneCoordinator` (жизненный цикл сцены), `WorldSaveCoordinator` (save/load), `WorldTurnCoordinator` (end-turn pipeline). Каждый — < 150 строк.

**A-2/A-3 → Перенести мутации из `BattleState` в `BattleActionResolver`.**
`BattleState` = pure data + запросы (`get_unit_at`, `get_reachable`). Все `apply_*`, `do_move`, `kill_unit` — только в `BattleActionResolver` / `BattleMoveResolver`.

**A-4 → Сделать `City` тонким фасадом.**
Все методы вида `func get_yield()` делегируют в `CityYieldCalculator`, `func build_building()` — в `CityBuildingService`. Убрать дублирование обёрток, оставить только сигналы.

---

## 2. Лучшие практики

### 2.1 Идиомы Godot 4.x

| # | Проблема | Файл / строка | Правка |
|---|---|---|---|
| G-1 | `get_node_or_null` вместо `@onready` / typed access | `CityScreen.gd`, `BattleUI.gd` | Использовать `@onready var _btn: Button = $Path` |
| G-2 | `queue_free()` без проверки `is_inside_tree()` | `ChronicleScreen._populate_list` | Добавить `if is_inside_tree()` или `call_deferred("queue_free")` |
| G-3 | `connect` без `is_connected` guard в `_ready`, но с проверкой в `setup` | `AdventureUI.setup` | Единообразно: всегда `if not sig.is_connected(cb)` |
| G-4 | `TileMapLayer` вместо `TileMap` (Godot 4.3+) — **хорошо**, но `set_cell` вызывается в цикле без батчинга | `MapRenderer.paint` | Использовать `set_cells_terrain_connect` где возможно |
| G-5 | `RenderingServer.set_default_clear_color` в `BattleFlow` — глобальный сайд-эффект | `BattleFlow.gd` | Вынести в тему / настройки сцены |

### 2.2 SOLID / DRY / KISS

| # | Принцип | Нарушение | Пример |
|---|---|---|---|
| S-1 | **SRP** | `HeroController` содержит `movement`, `army`, `resources`, `visual`, `magic`, `skills`, `tools`, `time`, `strategic_resources`, `inventory`, `needs` — 11 подсистем в одном узле | Разбить на компоненты через `add_child` + интерфейсы |
| S-2 | **DRY** | `_TerrainCostTable.get_cost_with_effects` дублирует логику `get_cost` для воды | `HexPathfinding._pf_cost_fn` и `TerrainCostTable` |
| S-3 | **DRY** | `CityArenaModel` — 100 % делегирование в `ArenaRingSystem`, `ArenaClusterSystem`, `ArenaStorm`, `ArenaTurnRunner` — 30+ однострочных методов | Убрать фасад, использовать системы напрямую |
| S-4 | **KISS** | `BattleAttackSequence` + `BattleRetreatPolicy` + `BattleTurnExecutor` — три класса для одного конечного автомата боя | Объединить в один `BattleStateMachine` с enum состояний |
| S-5 | **YAGNI** | `SpellEnums.EffectType` — 24 значения, из них используется ~6 | Удалить неиспользуемые |

### 2.3 Обработка ошибок и безопасность

| # | Проблема | Где | Риск |
|---|---|---|---|
| E-1 | `JSON.parse_string` без проверки `null` в `SpellbookRegistry._load_from_json` | `SpellbookRegistry.gd` | Crash на битом JSON |
| E-2 | `FileAccess.open` без проверки `null` в `SaveManager.load_game` — **есть**, но в `tune_city_arena.gd` — **нет** | `tune_city_arena.gd:_write_balance_file` | Crash при отсутствии файла |
| E-3 | `assert` используется только в тестах; в рантайме — `push_error` + продолжение | Везде | Тихие ошибки |
| E-4 | `ResourceLoader.exists` проверяется, но `load()` результат не проверяется на `null` | `UnitSprites.find_portrait` → `BattleView.create_unit_sprite` | Потенциальный `null` в `sp.texture` |
| E-5 | `var spell = reg.get_spell(spell_id)` — `Variant`, далее `spell.target_type` без проверки `null` | `BattleController._on_spell_chosen` | Runtime error если спелл не найден |

### 2.4 Нейминг и читаемость

| Проблема | Примеры | Рекомендация |
|---|---|---|
| Смешение `snake_case` и `camelCase` в сигналах | `hero_moving_changed` vs `hero_moved` | Единообразно: `hero_moving_changed` → `hero_is_moving_changed` |
| Однобуквенные переменные | `var c`, `var b`, `var d` в `CitySerializer` | `var city_data`, `var building_data` |
| `_` как имя для неиспользуемого | `func _on_resource_extracted(_cell, _rid, _amount)` | ОК для Godot, но > 2 параметров — вынести в `_` |
| Магические числа | `0.35` (длительность твина), `0.6` (время исчезновения) | В `GameNumbers` как `const` |
| `var _t := 0.0` | `DestMarker`, `StatusOrb` | `_elapsed_time` |

---

## 3. Алгоритмы

### 3.1 Используемые алгоритмы

| Алгоритм | Где | Сложность | Замечания |
|---|---|---|---|
| **A\* (hex)** | `HexPathfinding.astar_path` | O(V log V) | Корректен; `MinHeap` — бинарная куча |
| **BFS** | `HexPathfinding.bfs_path`, `bfs_reachable` | O(V + E) | Используется для движения юнитов |
| **Dijkstra** | `HexPathfinding.dijkstra` | O(V log V) | Для Enemy AI и превью движения |
| **Cube coordinates** | `HexUtils.offset_to_cube` / `cube_to_offset` | O(1) | Корректно; `_shift_right` — глобальный mutable state |
| **Flood fill / BFS** | `VisibilityMap.recompute` | O(R²) на источник | `_fill_disk` через `HexUtils.ring` |
| **MinHeap** | `MinHeap.gd` | O(log n) push/pop | Ручная реализация, корректна |
| **Hash-based cache** | `ArenaClusterSystem.clusters` (meta на `City`) | O(B) на пересчёт | Инвалидация через `_city_version` |
| **Fisher-Yates shuffle** | `MapSpawner.place_resources` | O(n) | Корректная in-place перестановка |
| **Генетический / hill-climb** | `tune_city_arena.gd` | O(evals × turns) | Для балансировки арены |

### 3.2 Проблемы и граничные случаи

| # | Алгоритм | Проблема | Приоритет |
|---|---|---|---|
| AL-1 | `HexUtils._shift_right` | **Глобальный `static var`** — не потокобезопасен, не сбрасывается между сценами кроме `reset()` | High |
| AL-2 | `HexPathfinding.astar_path` | `g_score` и `came_from` — `PackedFloat32Array` / `PackedInt32Array` размером `w*h`. Для карты 80×80 = 6400 элементов — ОК. Для 200×200 = 40 000 — уже заметное аллокация на каждый вызов | Medium |
| AL-3 | `VisibilityMap._fill_disk` | Вызывает `HexUtils.ring()` для каждого радиуса → аллокация массива на каждый радиус. Для `sight=5` — 5 аллокаций | Low |
| AL-4 | `BattleState.get_reachable` | Кэш `_reachable_cache` по `(cell, speed)`, но не учитывает `blocked`. Если `blocked` меняется (юниты двигаются) — **кэш протухает**, но `invalidate_board_cache` вызывается только при `do_move` | High |
| AL-5 | `ArenaClusterSystem._compute_clusters` | BFS по графу зданий — O(B). Но `_city_version` хеширует все здания каждый раз → O(B) на проверку кэша. При 100+ зданиях — накладные расходы | Low |
| AL-6 | `EnemyTurnProcessor.process` | Для **каждого** стека вызывает `dijkstra` → O(E × V log V) на стек. 20 стеков × карта 60×60 = тяжело | High |
| AL-7 | `MinHeap` | Нет `decrease_key` → при обновлении `g_score` в A* в кучу пушится дубликат. Корректно (проверка `cur_g > g_score`), но память растёт | Low |

### 3.3 Рекомендации по оптимизации

**AL-4 (High):** Кэш достижимости должен включать хеш `blocked`:

```gdscript
# До:
func get_reachable(cell, speed, blocked_fn, _unit):
    var speed_cache = _reachable_cache.get(cell, {})
    if speed_cache.has(speed):
        return speed_cache[speed].duplicate()
    var blocked = blocked_fn.call()
    ...

# После:
func get_reachable(cell, speed, blocked_fn, _unit):
    var blocked = blocked_fn.call()
    var key := Vector3i(cell.x, cell.y, speed)
    var blocked_hash := blocked.hash()  # или _board_version
    var cache_entry = _reachable_cache.get(key)
    if cache_entry != null and cache_entry["bv"] == _board_version:
        return cache_entry["cells"].duplicate()
    var reachable := HexPathfinding.bfs_reachable(cell, speed, blocked, BW, BH)
    _reachable_cache[key] = {"bv": _board_version, "cells": reachable}
    return reachable.duplicate()
```

**AL-6 (High):** Для врагов на одной карте — **один общий Dijkstra** от героя, а не от каждого стека:

```gdscript
# До (в EnemyTurnProcessor.process):
for start_cell in cells:
    var dist := _dist_field(cell, mp, cost_fn, dist_cache)  # dijkstra на каждый стек

# После:
# 1. Один Dijkstra от героя на всю карту (уже есть _hero_dist_field)
# 2. Для каждого стека — жадный шаг в сторону уменьшения расстояния до цели
# 3. Полный pathfinding только если стек в радиусе атаки
```

**AL-1 (High):** Убрать глобальный `static var _shift_right`, передавать калибровку как параметр или хранить в `MapModel`:

```gdscript
# До:
static var _shift_right: bool = true

# После:
# Хранить в MapModel / TileMapLayer, передавать в функции
static func get_neighbor(cell: Vector2i, bit: int, shift_right: bool = true) -> Vector2i:
```

---

## 4. Рефакторинг

### 4.1 Высокий приоритет

#### R-1: Разделить `BattleState` на данные и действия (High)

**Что:** Перенести `apply_attack`, `apply_spell`, `apply_sacrifice`, `do_move`, `do_defend`, `do_wait`, `do_skip`, `kill_unit`, `revive_unit`, `force_end` из `BattleState` в `BattleActionResolver`.

**Зачем:** `BattleState` сейчас — и данные, и логика мутаций. Тестирование действий требует полного `BattleState`. После разделения `BattleState` — immutable-ish data holder, действия — чистые функции.

**До:**
```gdscript
# BattleState.gd
func apply_attack(atk, def, is_melee, rng, consume_action=true) -> Dictionary:
    return BattleActionResolver.apply_attack(self, atk, def, is_melee, rng, consume_action)

func do_move(unit: BattleUnit, target: Vector2i) -> void:
    unit.cell = target
    ...
```

**После:**
```gdscript
# BattleState.gd — только данные и запросы
# Убрать все apply_*, do_*, kill_unit, revive_unit

# BattleActionResolver.gd — все мутации
static func do_move(state: BattleState, unit: BattleState.BattleUnit, target: Vector2i) -> void:
    unit.cell = target
    state.invalidate_board_cache()
```

**Файлы:** `BattleState.gd`, `BattleActionResolver.gd`, `BattleTurnExecutor.gd`, `BattleController.gd`, все тесты.

---

#### R-2: Убрать `CityArenaModel`-фасад (High)

**Что:** `CityArenaModel` содержит 30+ методов, каждый — однострочный вызов `ArenaRingSystem.*`, `ArenaClusterSystem.*`, `ArenaTurnRunner.*`, `ArenaStorm.*`.

**Зачем:** Лишний уровень индирекции без добавленной ценности. Усложняет навигацию и стек вызовов.

**До:**
```gdscript
# CityArenaModel.gd
static func ring_of(cell: Vector2i) -> int:
    return ArenaRingSystem.ring_of(cell)
static func clusters(city: City) -> Array:
    return ArenaClusterSystem.clusters(city)
static func storm_production_mult(city: City, turn: int) -> float:
    return ArenaStorm.storm_production_mult(city, turn)
# ... ещё ~25 таких
```

**После:**
```gdscript
# Удалить CityArenaModel.gd
# В вызывающем коде:
ArenaRingSystem.ring_of(cell)
ArenaClusterSystem.clusters(city)
ArenaStorm.storm_production_mult(city, turn)
```

**Файлы:** Удалить `CityArenaModel.gd`. Заменить импорты в `CityArenaView.gd`, `ArenaDemoScenario.gd`, тестах.

---

#### R-3: Guard от `null` при загрузке ресурсов (High)

**Что:** В `BattleView.create_unit_sprite`, `BattleController._place_obstacles` и др. результаты `load()` / `get_spell()` не проверяются.

**До:**
```gdscript
# BattleController.gd
func _on_spell_chosen(spell_id: StringName) -> void:
    var reg: Node = Services.resolve(&"spells")
    var spell = reg.get_spell(spell_id)
    if spell == null: return  # ← есть, но дальше:
    var side := ally_side if spell.target_type == ... # spell может быть не тем типом
```

**После:**
```gdscript
func _on_spell_chosen(spell_id: StringName) -> void:
    var reg: Node = Services.resolve(&"spells")
    if reg == null:
        GameLogger.error("Spell registry unavailable", "Battle")
        return
    var spell: SpellRegistry.SpellDef = reg.get_spell(spell_id)
    if spell == null:
        GameLogger.warn("Unknown spell: %s" % spell_id, "Battle")
        return
    ...
```

---

#### R-4: Кэш достижимости с версией доски (High)

См. AL-4 выше. Конкретная правка в `BattleState.get_reachable`.

---

### 4.2 Средний приоритет

#### R-5: Вынести магические числа в `GameNumbers` (Medium)

**Что:** Длительности твинов, размеры шрифтов, отступы захардкожены в `.tscn` и `.gd`.

**До:**
```gdscript
# BattleView.gd
tw.tween_property(node, "position", target, 0.15)  # MOVE_TWEEN_SEC уже в GameNumbers — ОК
tw.tween_property(label, "modulate:a", 0.0, 0.6)   # ← магическое число
```

**После:**
```gdscript
# GameNumbers.gd
const FLOATING_TEXT_FADE_SEC := 0.6
const DAMAGE_NUMBER_FADE_SEC := 0.5

# BattleView.gd
tw.tween_property(label, "modulate:a", 0.0, GameNumbers.FLOATING_TEXT_FADE_SEC)
```

---

#### R-6: Убрать дублирование в `ResourceChainService` (Medium)

**Что:** `build_discovery_keys` и `build_extraction_keys` имеют схожую структуру кэширования через fingerprint.

**До:** Два метода с одинаковым паттерном `_cache[iid] = {"fp": fp, "keys": keys}`.

**После:**
```gdscript
func _cached_keys(hero: HeroController, cache: Dictionary, builder: Callable) -> Dictionary:
    var iid := hero.get_instance_id()
    var fp: String = builder.call(hero, true)  # fingerprint mode
    var cached = cache.get(iid, {})
    if cached.get("fp") == fp and cached.has("keys"):
        return cached["keys"]
    var keys: Dictionary = builder.call(hero, false)
    cache[iid] = {"fp": fp, "keys": keys}
    return keys
```

---

#### R-7: Типизация сигналов `GameEventBus` (Medium)

**Что:** Сигналы без типов параметров или с `Variant`.

**До:**
```gdscript
signal resource_extracted(cell: Vector2i, resource_id: StringName, amount: int)  # ОК
signal battle_completed(winner: BattleState.Side, enemy_cell: Vector2i)  # ОК
signal hero_died(cause: StringName)  # ОК
signal chronicle_entry_added(entry_id: StringName, text: String)  # ОК
```

Здесь уже хорошо. Но в `CursorController`:
```gdscript
func _on_battle_ended(_winner_or_cell: Variant, _enemy_cell: Variant = null) -> void:
```

**После:**
```gdscript
func _on_battle_ended(_winner: BattleState.Side, _enemy_cell: Vector2i) -> void:
```

---

#### R-8: `WorldBootstrap.run` → Builder / конфиг (Medium)

**Что:** `run()` — 80+ строк, создаёт 10+ объектов. Сложно читать и тестировать.

**После:** Разбить на `_create_map`, `_create_hero`, `_create_camera`, `_create_input`, `_create_cities`, `_create_ui`, `_create_subsystems` (частично уже сделано, но `run` всё ещё длинный).

---

### 4.3 Низкий приоритет

#### R-9: Заменить `PlaceholderTexture` на `GradientTexture2D` / `FastNoiseLite` (Low)

Генерация пиксельных кружков вручную — медленно при первом вызове. Встроенные текстуры быстрее.

#### R-10: `SpellbookRegistry._load_fallback` → вынести в JSON-файл (Low)

13 захардкоженных словарей в коде. Уже есть `JSON_PATH`, но fallback дублирует данные.

#### R-11: Удалить неиспользуемые `SpellEnums.EffectType` значения (Low)

24 enum-значения, реально используются ~6. Остальные — мёртвый код.

---

## 5. Инструкция для локального агента

### Фаза 1 — Критические правки (High)

| Шаг | Файлы | Действие | Проверка |
|---|---|---|---|
| 1.1 | `BattleState.gd` | Перенести `apply_attack`, `apply_spell`, `do_move`, `do_defend`, `do_wait`, `do_skip`, `kill_unit`, `revive_unit`, `force_end` в `BattleActionResolver.gd`. В `BattleState` оставить только данные и геттеры. | `gdscript_lint` + запуск `tests/systems/BattleActionResolverTest.gd`, `tests/unit/systems/test_battle_state.gd` |
| 1.2 | `BattleTurnExecutor.gd`, `BattleController.gd`, `BattleInput.gd` | Обновить вызовы: `state.apply_attack(...)` → `BattleActionResolver.apply_attack(state, ...)` | Все тесты боя проходят |
| 1.3 | `BattleState.gd:get_reachable` | Добавить `_board_version` в ключ кэша (см. R-4) | Тест `test_reachable_reflects_move` проходит |
| 1.4 | Удалить `CityArenaModel.gd` | Заменить все `CityArenaModel.xxx()` на прямые вызовы `ArenaRingSystem`, `ArenaClusterSystem`, `ArenaStorm`, `ArenaTurnRunner` в `CityArenaView.gd`, `ArenaDemoScenario.gd`, тестах | `tests/unit/world/test_city_arena.gd` проходит |
| 1.5 | `HexUtils.gd` | Заменить `static var _shift_right` на параметр функции или поле в `MapModel`. Обновить `calibrate()`. | Все тесты `HexUtilsTest` проходят |

**Команды проверки:**
```bash
# Запуск всех unit-тестов
godot --headless --path . --script tests/run_all.gd

# Или через gdUnit4
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/

# Линтер
gdscript-lint --path scripts/
```

### Фаза 2 — Средние правки (Medium)

| Шаг | Файлы | Действие |
|---|---|---|
| 2.1 | `GameNumbers.gd` | Добавить `FLOATING_TEXT_FADE_SEC`, `DAMAGE_NUMBER_FADE_SEC`, `SPELL_TARGETING_PULSE_SEC` |
| 2.2 | `BattleView.gd` | Заменить магические числа на константы из `GameNumbers` |
| 2.3 | `ResourceChainService.gd` | Рефакторинг кэширования через общий `_cached_keys` |
| 2.4 | `CursorController.gd` | Типизировать параметры `_on_battle_ended` |
| 2.5 | `WorldBootstrap.gd` | Разбить `run()` на приватные методы `_create_*` |
| 2.6 | `BattleController.gd`, `SpellCaster.gd` | Добавить null-guard для `reg.get_spell()` |

**Критерий приёмки:** Все существующие тесты проходят, `push_error` / `push_warning` не появляются в логах при запуске.

### Фаза 3 — Низкие правки (Low)

| Шаг | Файлы | Действие |
|---|---|---|
| 3.1 | `SpellEnums.gd` | Удалить неиспользуемые `EffectType` значения |
| 3.2 | `SpellbookRegistry.gd` | Вынести fallback-данные в `res://assets/data/spells_fallback.json` |
| 3.3 | `PlaceholderTexture.gd` | Рассмотреть замену на `GradientTexture2D` |
| 3.4 | Все `.gd` | Заменить `_t` → `_elapsed_time`, `c` → `cell`, `b` → `building` |

### Итоговый чек-лист приёмки

- [ ] `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/` — **0 failures**
- [ ] `godot --headless --path . --quit` — **0 errors** в выводе
- [ ] `CityArenaModel.gd` удалён, ни одного импорта не осталось
- [ ] `BattleState.gd` не содержит методов `apply_*`, `do_*`, `kill_unit`, `revive_unit`
- [ ] `HexUtils._shift_right` не является `static var`
- [ ] Все `load()` / `get_spell()` / `Services.resolve()` имеют null-guard
- [ ] В `GameNumbers` нет дублирования констант, все магические числа из `BattleView` вынесены



# Аудит тестовой инфраструктуры

## 1. Текущая структура

```
tests/
├── core/                    # 24 файла — юнит-тесты ядра (дублирует unit/)
├── fakes/                   # 4 файла — моки/фейки
├── functional/              # 20 файлов — функциональные (запускаются в Godot)
├── helpers/                 # 2 файла — фабрики
├── integration/             # 5 файлов — интеграционные
├── mcp/                     # 6 .py + conftest — MCP-тесты (внешний процесс)
│   ├── conftest.py
│   ├── godot_mcp.py
│   ├── test_battle_profiling.py
│   ├── test_battle_tween.py
│   ├── test_hexutils_perf.py
│   ├── test_resource_and.py
│   ├── test_session_reset.py
│   └── test_shard_pruning.py
├── spell_validation/        # 2 файла — валидатор заклинаний
├── systems/                 # 2 файла — системные тесты боя
├── unit/                    # 68 файлов — юнит-тесты по доменам
│   ├── core/
│   ├── data/
│   ├── entities/
│   ├── systems/
│   ├── ui/
│   └── world/
└── world/                   # 1 файл — вне общей структуры
```

---

## 2. Проблемы структуры

| # | Проблема | Где | Влияние |
|---|---|---|---|
| T-1 | **Дублирование**: `tests/core/HexUtilsTest.gd` и `tests/core/test_hex_utils.gd` тестируют одно и то же | `tests/core/` | Поддержка двух копий, расхождение ожиданий |
| T-2 | **Несогласованная номенклатура**: `*Test.gd` vs `test_*.gd` вперемешку | Везде | Невозможно фильтровать по паттерну |
| T-3 | **`tests/core/` дублирует `tests/unit/core/`** и `tests/unit/data/` | 24 файла в `core/` | Неясно, какой набор канонический |
| T-4 | **`tests/world/SuccessionControllerTest.gd`** — вне `tests/unit/world/` | 1 файл | Потерянный тест |
| T-5 | **Отсутствует `tests/run_all.gd`** или конфиг для gdUnit4 | — | Нет единой точки запуска |
| T-6 | **MCP-тесты не интегрированы** в CI-пайплайн проекта | `tests/mcp/` | Запускаются вручную |

---

## 3. Проблемы покрытия

### 3.1 Не покрыто тестами

| Модуль | Файл | Критичность |
|---|---|---|
| `MapRenderer` | `world/MapRenderer.gd` | High — отрисовка карты |
| `MapSpawner` | `world/MapSpawner.gd` | High — спавн объектов |
| `WorldInput` | `world/WorldInput.gd` | Medium — ввод |
| `WorldCamera` | `world/WorldCamera.gd` | Medium — камера |
| `BattleFX` | `core/BattleFX.gd` | Medium — эффекты боя |
| `WorldBootstrap` | `world/WorldBootstrap.gd` | High — инициализация мира |
| `WorldEventRouter` | `world/WorldEventRouter.gd` | High — маршрутизация событий |
| `WorldSaveLoadService` | `world/WorldSaveLoadService.gd` | High — сохранение |
| `ResourceChainService` (кэш) | `world/ResourceChainService.gd` | Medium — инвалидация |
| `TemplateContext` | `data/templates/template_context.gd` | Medium — условия шаблонов |
| `CursorController` (полный цикл) | `autoload/CursorController.gd` | Low |
| `TileAtlasCache` | `autoload/tile_atlas_cache.gd` | Low |
| UI-панели (кроме `BattleUI`, `MinimapOverlay`) | `ui/*.gd` | Medium |

### 3.2 Слабое покрытие

| Область | Что есть | Что нужно |
|---|---|---|
| `BattleState.get_reachable` кэш | 1 тест (`test_reachable_reflects_move`) | Тест инвалидации при `do_move`, `kill_unit`, `revive_unit` |
| `EnemyTurnProcessor` | 1 интеграционный тест | Тесты `_pick_goal`, `_candidate_goals`, гразонирование |
| `CityBuildingService.first_free_build_cell` | Косвенно через `CityScreen` | Прямой тест с `bounds`, `requires_site` |
| `SpellCaster._check_immunity` | Через `test_magic_resistance` | Прямой тест всех комбинаций тегов |
| `HeroMovementController._get_affordable_path` | Косвенно | Тест обрезки пути при нехватке MP |

---

## 4. Проблемы логики тестов

### 4.1 Пустые/номинальные ассерты

```gdscript
# test_battle_fox.gd — бессмысленный тест
func test_fx_instantiation() -> void:
    var fx := _BattleFX.new()
    assert_that(fx).is_not_null()
    fx.free()

func test_setup_null() -> void:
    var fx := _BattleFX.new()
    fx.setup(null)
    assert_bool(true).is_true()  # ← ничего не проверяет
    fx.free()
```

```gdscript
# test_spellbook_guards.gd — тавтология
func test_spellbook_button_is_action_button() -> void:
    var action = true
    assert_bool(action).is_true()  # ← всегда проходит

func test_shortcuts_gated_by_world_visibility() -> void:
    var world_visible = false
    var should_gate = not world_visible
    assert_bool(should_gate).is_true()  # ← всегда проходит
```

### 4.2 Утечки в тестах

```gdscript
# test_city_arena_view.gd — after_test не освобождает _view корректно
func after_test() -> void:
    if _view != null and is_instance_valid(_view):
        _view.free()  # ← может упасть если _view в сцене
        _view = null
```

**Исправление**: использовать `queue_free()` + `await get_tree().process_frame`.

### 4.3 Хрупкие тесты на сидах

```gdscript
# test_city_arena.gd — полагается на конкретные координки фич
func test_cell_features_deterministic() -> void:
    # Полагается на конкретный хеш — ломается при изменении алгоритма
    assert_that(_Model.cell_feature(city, quarry)).is_equal(&"quarry")
```

### 4.4 MCP-тесты: гонки по времени

```python
# test_battle_tween.py — фиксированный sleep вместо ожидания состояния
for _ in range(30):
    pos = mcp.execute_code(...)
    positions.append(pos)
    time.sleep(1 / 60.0)  # ← может не совпадать с кадрами игры
```

---

## 5. Рекомендуемая целевая структура

```
tests/
├── unit/                          # gdUnit4, без запуска сцены
│   ├── core/                      # HexUtils, MinHeap, Pathfinding, VisibilityMap
│   ├── data/                      # Registry, Templates, Enums
│   ├── entities/                  # UnitStack, Hero*, Follower
│   ├── systems/                   # BattleState, BattleAI, Processors
│   └── world/                     # City*, Borough, Map*, Persistence
├── integration/                   # gdUnit4, с инстанцированием узлов
│   ├── battle/                    # BattleController + Input + Executor
│   ├── city/                      # CityManager + Processors
│   └── world/                     # WorldBootstrap + EventRouter
├── functional/                    # godot-mcp (Python), полный запуск игры
│   ├── conftest.py
│   ├── godot_mcp.py
│   ├── test_battle_flow.py
│   ├── test_city_lifecycle.py
│   ├── test_hero_movement.py
│   ├── test_save_load.py
│   └── test_performance.py
├── helpers/
│   └── factories.gd
├── fakes/
│   ├── MockBattleView.gd
│   ├── FakeHero.gd
│   └── FakeMapGenerator.gd
└── gdunit4.cfg                    # конфиг запуска
```

---

## 6. Конкретные правки

### 6.1 Удалить дубли (High)

| Удалить | Оставить |
|---|---|
| `tests/core/test_hex_utils.gd` | `tests/core/HexUtilsTest.gd` |
| `tests/core/HexPathfindingTest.gd` (частично дублирует `test_algorithm_optimizations.gd`) | Объединить |
| `tests/core/test_min_heap.gd` | Включить в `HexPathfindingTest.gd` |
| `tests/world/SuccessionControllerTest.gd` | Переместить в `tests/unit/world/` |

### 6.2 Убрать пустые ассерты (High)

**До:**
```gdscript
func test_setup_null() -> void:
    var fx := _BattleFX.new()
    fx.setup(null)
    assert_bool(true).is_true()
    fx.free()
```

**После:**
```gdscript
func test_setup_null_no_crash() -> void:
    var fx := _BattleFX.new()
    fx.setup(null)
    # Проверяем, что вызовы не падают
    fx.show_spell_cast(Vector2i.ZERO, &"test")
    fx.show_heal(Vector2i.ZERO, 10)
    fx.show_damage(Vector2i.ZERO, 5)
    fx.free()
```

### 6.3 Добавить недостающие тесты (High)

**`tests/unit/world/test_map_spawner.gd`:**
```gdscript
extends GdUnitTestSuite

func test_place_villages_count() -> void:
    var model := MapModel.new()
    model.map_width = 60; model.map_height = 60
    model.seed_value = 42
    model.generate_noise()
    var spawner := MapSpawner.new(model)
    spawner.setup_registry(Services.resolve(&"units"))
    spawner.place_villages()
    assert_int(model.village_cells.size()).is_equal(GameNumbers.MAP_VILLAGE_COUNT)

func test_place_resources_spacing() -> void:
    var model := MapModel.new()
    model.map_width = 60; model.map_height = 60
    model.seed_value = 42
    model.generate_noise()
    model.smooth_invalid_adjacencies()
    var spawner := MapSpawner.new(model)
    spawner.setup_registry(Services.resolve(&"units"))
    var reachable := model.get_blocked_cells()
    spawner.place_resources(reachable)
    # Проверяем минимальное расстояние между ресурсами
    var cells := model.resource_cells.keys()
    for i in cells.size():
        for j in range(i + 1, cells.size()):
            assert_int(HexUtils.hex_distance(cells[i], cells[j])) \
                .is_greater_equal(GameNumbers.MAP_RESOURCE_SPACING_MIN)
```

**`tests/unit/systems/test_battle_state_cache.gd`:**
```gdscript
extends GdUnitTestSuite

func test_reachable_cache_invalidated_on_kill() -> void:
    var state := BattleState.new()
    var atk := [Units.make_fixed_stack("swordsmen", 10)]
    var def := [Units.make_fixed_stack("goblins", 10), Units.make_fixed_stack("goblins", 10)]
    state.place_army(atk, def)
    var unit := state.attacker_units[0]
    var blocked_fn := func() -> Dictionary: return state.build_all_blocked(unit, {})
    var r1 := state.get_reachable_for_unit(unit, blocked_fn)
    state.kill_unit(state.defender_units[1])
    var r2 := state.get_reachable_for_unit(unit, blocked_fn)
    # После смерти юнита клетка должна стать достижимой
    var freed_cell: Vector2i = state.defender_units[1].cell
    assert_bool(r2.has(freed_cell)).is_true()

func test_reachable_cache_invalidated_on_move() -> void:
    var state := BattleState.new()
    var atk := [Units.make_fixed_stack("swordsmen", 10)]
    var def := [Units.make_fixed_stack("goblins", 10)]
    state.place_army(atk, def)
    var unit := state.attacker_units[0]
    var other := state.defender_units[0]
    var blocked_fn := func() -> Dictionary: return state.build_all_blocked(unit, {})
    var r1 := state.get_reachable_for_unit(unit, blocked_fn)
    var old_cell := other.cell
    state.do_move(other, Vector2i(15, 10))
    var r2 := state.get_reachable_for_unit(unit, blocked_fn)
    assert_bool(r2.has(old_cell)).is_true()
```

### 6.4 Исправить MCP-тесты (Medium)

**До** (`test_battle_tween.py`):
```python
for _ in range(30):
    pos = mcp.execute_code(...)
    positions.append(pos)
    time.sleep(1 / 60.0)
```

**После:**
```python
# Ждём завершения твина через состояние игры
mcp.execute_code("""
var battle = get_tree().current_scene
var executor = battle.get_node("BattleTurnExecutor")
# Ждём перехода в следующий стейт
while executor.get_current_state() == BattleTurnExecutor.State.PLAYER_ANIMATING:
    await get_tree().process_frame
return {"done": true}
""")
# Теперь проверяем позицию
pos = mcp.execute_code("""
var battle = get_tree().current_scene
var view = battle.get_node("BattleView")
var unit = battle.get_battle_state().attacker_units[0]
var sprite = view._sprites_by_uid.get(unit.uid)
return {"x": sprite.position.x, "y": sprite.position.y}
""")
```

### 6.5 Добавить `gdunit4.cfg` (High)

```ini
# tests/gdunit4.cfg
[gdunit4]
test_suite_folder=tests/unit
test_suite_pattern=test_*.gd
ignored_folders=tests/mcp,tests/helpers,tests/fakes
timeout=30000
```

### 6.6 Добавить `conftest.py` фикстуру для полного цикла (Medium)

```python
@pytest.fixture
def full_game(mcp):
    """Полный игровой цикл: мир → бой → возврат."""
    mcp.run_scene("res://scenes/World.tscn")
    mcp.wait_ready()
    yield mcp
    mcp.stop_running_scene()

@pytest.fixture
def battle_from_world(full_game):
    """Запуск боя из мира через столкновение."""
    mcp = full_game
    mcp.execute_code("""
        var world = get_tree().current_scene
        var hero = world.get_hero()
        var map = world.get_map_gen()
        # Находим ближайшего врага и телепортируем героя рядом
        for cell in map.enemy_stacks:
            hero.movement.teleport(cell)
            break
        return {"started": true}
    """)
    mcp.wait_frames(30)
    return mcp
```

---

## 7. Пошаговый план внедрения

| Шаг | Действие | Файлы | Приоритет |
|---|---|---|---|
| 1 | Удалить `tests/core/test_hex_utils.gd`, `tests/world/` | — | High |
| 2 | Переименовать `*Test.gd` → `test_*.gd` для единообразия | 6 файлов | High |
| 3 | Создать `tests/gdunit4.cfg` | Новый файл | High |
| 4 | Убрать пустые ассерты (`assert_bool(true)`) | 4 файла | High |
| 5 | Добавить тесты `MapSpawner`, `WorldBootstrap` | 2 новых файла | High |
| 6 | Добавить тесты инвалидации кэша `BattleState` | 1 новый файл | High |
| 7 | Исправить утечки в `after_test` (заменить `free()` на `queue_free()`) | 3 файла | Medium |
| 8 | Переписать MCP-тесты с ожиданием состояния вместо `sleep` | 3 файла | Medium |
| 9 | Добавить фикстуру `full_game` в `conftest.py` | 1 файл | Medium |
| 10 | Покрыть `WorldEventRouter`, `WorldSaveLoadService` | 2 новых файла | Medium |
| 11 | Добавить тесты `ResourceChainService` кэширования | 1 новый файл | Low |
| 12 | Перенести `tests/functional/` в MCP-формат | 20 файлов | Low |

---

## 8. Критерии приёмки

- [ ] `gdUnit4` запускается одной командой: `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd tests/unit/`
- [ ] 0 дублирующих тест-файлов
- [ ] 0 ассертов вида `assert_bool(true).is_true()`
- [ ] MCP-тесты запускаются: `cd tests/mcp && uv run pytest`
- [ ] Покрытие ключевых модулей (Battle, City, Map, Hero) > 80% по строкам
- [ ] Все `after_test` используют `queue_free()` вместо `free()`
- [ ] Нет тестов, зависящих от конкретного `randi()` без фиксации сида