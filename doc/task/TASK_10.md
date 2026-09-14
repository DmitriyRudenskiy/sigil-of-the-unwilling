# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

Кодовая база зрелая: есть DI-контейнер, событийная шина, сериализация с миграциями, централизация констант/текстов/темы, развитый набор тестов (включая MCP-интеграционные). Ниже — конкретные проблемы и план их устранения.

---

## 1. Архитектура

### 1.1. Сильные стороны (коротко)
- Композиция `HeroController` (`Movement/Army/Resources/Visual` как дочерние узлы) — правильный паттерн.
- Сплит города `CityData` (состояние) → `CityService` (операции) → `City` (фасад), аналогично `BoroughRules`, `CityBuildingService`, `CitySerializer` — последовательный SRP.
- `GameNumbers` / `GameText` / `ThemeConfig` — единые точки конфигурации (константы, i18n, тема).
- `SaveData` с цепочкой миграций v1→v6.
- `BattleTurnExecutor` использует token-паттерн для защиты асинхронных переходов (`_is_stale(token)`) — грамотно для стейт-машины на таймерах.

### 1.2. Проблемы

| # | Проблема | Где | Влияние |
|---|----------|-----|---------|
| A1 | **Два параллельных механизма DI**: `Services` (новый) и `ServiceLocator` (deprecated). Миграция наполовину сделана (в коде видны комментарии «ИСПРАВЛЕНИЕ»), но `ServiceLocator.resolve(null, &"units")` остался в продакшене (`SpellRegistry.gd`, `BattleFX.gd`, `EnemyGrowthSystem.gd`, `HeroInventory.gd`) и в свежих хелперах (`TestFactories.make_battle_state`) | `scripts/core/ServiceLocator.gd`, десятки точек вызова | Две точки отказа, часть кода идёт через устаревший fallback-поиск узлов |
| A2 | **Две параллельные системы заклинаний**: `SpellRegistry` (школы/уровни, бой) и `SpellbookRegistry` (JSON, шаблоны карточной системы) + `BattleSpellBridge` + `SpellCaster` + `SpellResolver` | `scripts/autoload/SpellRegistry.gd`, `SpellbookRegistry.gd`, `scripts/systems/SpellCaster.gd`, `scripts/data/SpellResolver.gd` | DRY-нарушение, неочевидно, какой путь канонический; дублирование иммунитета/резиста в `SpellCaster` и `BattleSpellBridge` |
| A3 | **Статическое состояние без единого сброса**: кэши есть в `HexUtils._config/_shift_right`, `TemplateEngine._handlers`, `ShardManager._instance`, `TerrainCostTable._costs`, `ResourceAtlas._map/_sheet/_cache`, `PlaceholderTexture._cache`, `UnitSprites._portrait_cache`, `BattleSpellBridge._EFFECT_TO_KEYWORD`. В `Services.clear_session()` сбрасываются только `HexUtils` (+ точечные `ArenaClusterSystem.reset()` / `ResourceIcons.clear_cache()` в `MainMenu`/`EndgameController`) | `services.gd`, `MainMenu.gd:_clear_session_caches`, `EndgameController._return_to_menu` | Утечка состояния между сессиями; список «что сбрасывать» размазан по вызывающим |
| A4 | **`City` — неполный фасад**: часть операций так и осталась инлайн (`_is_adjacent_to_city_body`, `is_worker_tile_free`, `first_free_worker_tile`, `first_free_build_cell`, `defense_strength`, `request_switch`, `get_yield`, `get_logistics_multiplier`), хотя соседние операции вынесены в `CityService`/`CityBuildingService` | `scripts/world/City.gd` | Сплит R2 формально незавершён; невозможно тестировать правила размещения без живого `City` |
| A5 | **`BattleTurnExecutor` ~700 строк**, смешаны: стейт-машина, последовательность атаки (удары/реталиация/мораль/отступление/пауза) | `scripts/systems/BattleTurnExecutor.gd` | Высокая цена изменения; уже были баги очередности (зафиксированы в тестах) |
| A6 | **`CityArenaView` ~400 строк — view с игровой логикой**: хранение `_turn`, `_starve_days`, вызовы `place_building`, `hire_worker`, апгрейды | `scripts/world/CityArenaView.gd` | Логика арены не переиспользуема без сцены |
| A7 | **Расплоха статических «систем» города** (15+ классов по 1–5 методов): `ProsperitySystem`, `RaidSystem`, `MarketSystem`, `ZoningSystem`, `ScaleShiftManager`, `SpecializationSystem`, `LogisticsCalculator`, `WorkerAssignment`… | `scripts/city/` | Класс-взрыв; навигация и связность хуже, чем была бы у 3–4 тематических модулей |
| A8 | **Мёртвый/неподключённый код**: `CursorSprite` (32 курсора) нигде не используется `CursorController`-ом (у него `MODE_ASSETS` с пустыми путями); `HeroSlot.tscn`/`TownSlot.tscn` дублируют инлайн-слоты `InfoPanel.tscn` | `scripts/data/CursorSprite.gd`, `scripts/autoload/CursorController.gd`, `scenes/ui/HeroSlot.tscn`, `TownSlot.tscn` | Мусор, ложные ожидания у разработчиков |
| A9 | **`GameEventBus` — ~40 сигналов в одном автозагрузе**, часть дублирует сигналы процессоров (`city_level_up`, `raid_occurred` и т.п. пробрасываются вручную в `CityTurnProcessor`→`GameEventBus`) | `scripts/autoload/GameEventBus.gd`, `CityTurnProcessor` | Шина становится «божественным объектом»; ручные пробросы — источник рассинхрона |
| A10 | **Хардкод имён городов** в `WorldBootstrap._create_cities`: `"Перворечье"`, `"Город 2"` | `scripts/world/WorldBootstrap.gd` | Обход `GameText`/фабрики имён |

---

## 2. Лучшие практики

### 2.1. Найденные дефекты (не только стиль)

**Баг 1 (реальный, рендер). `MinimapOverlay._draw_hero_dot` — точка героя не рисуется.**

```gdscript
# scripts/ui/MinimapOverlay.gd
func _hero_current_cell() -> bool:
    return hero_ref.has_method("current_cell") and hero_ref.current_cell != null
```
`current_cell` — **свойство** (геттер на `HeroMovementController`), а не метод → `has_method()` всегда `false` → `cell := _last_hero_cell` (изначально `Vector2i.ZERO`) → дальше `if cell == _last_hero_cell: return` → досрочный выход **до** отрисовки. Точка героя на миникарте не рисуется никогда; плюс при первом совпадении с `(0,0)` — тоже.

**Баг 2 (потенциальный). `TemplateEngine` — нарушенный контракт обработчиков.**

```gdscript
if template == &"COMBAT_TRICK":
    return _handlers[template].call(params, secondary, state, caster, target)
return _handlers[template].call(params, state, caster, target)
```
Один шаблон имеет другую сигнатуру — ветвление по имени шаблона в движке. Любой новый шаблон с особой сигнатурой продолжит эту ветку. (См. рефакторинг R6.)

### 2.2. Таблица наблюдений

| # | Наблюдение | Где | Категория |
|---|-----------|-----|-----------|
| P1 | `has_method()` к свойствам (см. баг 1); для свойств корректно `"prop" in obj` | `MinimapOverlay.gd` | Bug |
| P2 | Ad-hoc Result-паттерн: `{"ok": bool, "reason": String}` независимо реализован в `CityBuildingService.fail`, `MarketSystem._fail`, `ArenaTurnRunner._fail`, `ZoningSystem._fail` | 5+ файлов | DRY/типизация |
| P3 | `Artifact._init` — 12 позиционных параметров | `scripts/data/Artifact.gd` | Читаемость |
| P4 | `SaveManager.SAVE_PATH = "user://save_slot_1.json"` — имя намекает на слоты, но слот один; `load_slot()` каждый раз аллоцирует новый `SaveManager` | `scripts/core/SaveManager.gd` | Naming/KISS |
| P5 | `WorldPersistence.pending_save` / `pending_new_game` — статические глобалы для передачи между сценами | `scripts/world/WorldPersistence.gd` | Допустимо для Godot, но это неявный контракт главного меню и мира |
| P6 | Кастомные цвета в `.tscn` (например, `CityArena.tscn`), хотя `ThemeConfig` декларирует «не использовать прямые Color в UI-коде» | `scenes/CityArena.tscn` и др. | Консистентность темы |
| P7 | Тестовые хелперы дублируются: свои `_make_hero/_make_city/_seeded/_make_unit` в `test_hero_survival`, `test_magic_resistance`, `test_legend_chronicle`, тогда как есть `TestFactories` | `tests/` | DRY |
| P8 | Смешанный стиль освобождения в тестах: местами `auto_free()`, местами ручной `.free()` | `tests/` | Консистентность gdUnit |
| P9 | `CursorController.MODE_ASSETS` — пустые пути, режимы лишь логируются; `CursorSprite` не подключён | `CursorController.gd` | Незавершённая фича |
| P10 | `SpellbookRegistry._by_color` ключуется строкой имени цвета, а `_by_template` — `StringName`; несогласованно | `SpellbookRegistry.gd` | Мелочь |
| P11 | `EquipmentManager._highest_type(..., b_slot := -1, ...)` — `-1` в параметре типа `Artifact.Slot` | `EquipmentManager.gd` | Типизация |
| P12 | `EconomicTurnProcessor` добавляет авто-доход (дерево/камень) **до** цепочек — цепочки потребляют авто-доход того же хода. Поведение зафиксировано тестами, но неявно | `EconomicTurnProcessor.gd` | Нужен комментарий о порядке фаз |
| P13 | `ResourceContext.setup` — первая ёмкость «побеждает» при повторном вызове; неочевидно | `ResourceContext.gd` | Документировать |

### 2.3. Безопасность/ошибки
- Сейв — открытый JSON без контрольных сумм (одиночная игра — приемлемо, но учтите).
- Ошибки ввода/файлов обрабатываются (`FileAccess.open` → guard, `JSON.parse` → guard) — хорошо.
- `SpellbookRegistry._load_from_json` корректно обрабатывает гонку «файл исчез между `file_exists` и `open`» (TASK_06) — образцово.

---

## 3. Алгоритмы и структуры данных

### 3.1. Инвентаризация

| Алгоритм/структура | Где | Сложность | Корректность и граничные случаи |
|--------------------|-----|-----------|--------------------------------|
| A* по гексам | `HexPathfinding.astar_path` | O((V+E)·log V) | Корректен: эвристика — гекс-дистанция (консистентна); `start==goal` → `[start]`; нет пути → `[]`; `g_score` в `PackedFloat32Array` — хорошо по памяти |
| BFS (путь/достижимость) | `HexPathfinding.bfs_path`, `bfs_reachable` | O(V+E) | `bfs_reachable` исключает старт из результата — задокументировано тестами |
| Дейкстра с отсечкой по `max_cost` | `HexPathfinding.dijkstra` | O((V+E)·log V) | Постобработка `dist[i]=INF` за пределами бюджета — O(V), корректно; INF-стоимость входа обрабатывается с `push_warning` |
| Восстановление пути Дейкстры | `dijkstra_path` | O(L·6) | Защита от `INF`-цели; `break` при недостижимом текущем — корректно |
| `MinHeap` (бинарная куча) | `scripts/core/MinHeap.gd` | push/pop O(log n) | Корректна; сравнение только по первому элементу (приоритет) — достаточно; `pop()` из пустой вернёт `[]` — молчаливо, вызывающие это учитывают |
| Гекс-кольцо за O(r) | `HexUtils.ring` | O(r) | Оптимизация с O(r²) выполнена через куб-координаты — математически верно; не зависит от калибровки смещения |
| Заполнение диска видимости | `VisibilityMap._fill_disk` | O(r²) клеток | Оптимально (диск состоит из Θ(r²) клеток); границы карты учитываются |
| Кластеры зданий (связные компоненты) | `ArenaClusterSystem._compute_clusters` | O(B) | Инвалидация по хэш-версии города; коллизия хэша даёт лишь устаревший кэш — допустимо |
| Фишер–Йетс | `MapSpawner.place_resources/place_enemies` | O(n) | Корректен |
| Инициатива боя | `BattleState.build_queue` | O(n log n), n≤14 | Детерминированный компаратор (скорость → hp → сторона → uid) — корректно |
| Кэш достижимости боя | `BattleState._reachable_cache` | — | Инвалидируется `invalidate_board_cache()` при каждом муве/килле — корректно |
| Поле расстояний до героя для ИИ врагов | `EnemyTurnProcessor._rebuild_hero_dist_field` | 1× Дейкстра на всю карту за ход + кэш полей стаков по `Vector3i(x,y,mp*1000)` | Грамотно; для 70×70 (~5 к. клеток) дёшево |
| Посадка летающих ИИ | `BattleAI._find_flying_landing_cell` | O(speed²) ≤ ~441 | Есть fallback-клетка, если все соседние заняты — покрыто тестами |
| Кэш доходности города | `CityYieldCalculator` | инвалидация флагом | Корректно |
| Глубокое копирование городов при сукцессии | `SuccessionController.transfer_legend` через `serialize()/deserialize()` | O(C·S) | Прагматично (сигналы нельзя `duplicate()`), при малом C приемлемо |

### 3.2. Возможные улучшения (не критичные)
1. **`dijkstra` + `dijkstra_path`** — два прохода. Для вражеского ИИ можно вернуть путь сразу из первого прохода (храня `came_from`), экономя повторный обход соседей. Эффект мал, приоритет низкий.
2. **Элементы кучи как `Array`** (`[f, g, cell]`) — аллокация на каждый пуш. На масштабах боя (≤187 клеток) и карты (≤5 тыс.) это шум; не трогать, пока не станет узким местом.
3. **`BattleState` для летающих**: полный скан `BW×BH` (187 проверок) — приемлемо, замена не требуется.
4. **`EnemyTurnProcessor`**: поле героя строится на весь мир даже если стаков мало — можно ограничить радиусом `ENEMY_AGGRO_RADIUS`, но текущая цена мала.

---

## 4. Рефакторинг (конкретные правки)

Обозначения приоритета: **High** — делать в первую очередь, **Medium** — в ближайшем спринте, **Low** — по остаточному принципу.

### R1 — High. Починить точку героя на миникарте
**Файл:** `scripts/ui/MinimapOverlay.gd`
**Зачем:** точка не рисуется никогда (баг из §2.1).
**До:**
```gdscript
func _draw_hero_dot(size: Vector2) -> void:
    if hero_ref == null or map_ref == null:
        return
    var cell: Vector2i = hero_ref.current_cell if _hero_current_cell() else _last_hero_cell
    if cell == _last_hero_cell:
        return
    _last_hero_cell = cell
    ...
func _hero_current_cell() -> bool:
    return hero_ref.has_method("current_cell") and hero_ref.current_cell != null
```
**После:**
```gdscript
func _draw_hero_dot(size: Vector2) -> void:
    if hero_ref == null or map_ref == null:
        return
    if not ("current_cell" in hero_ref):
        return
    var cell: Vector2i = hero_ref.current_cell
    if cell == _last_hero_cell:
        cell = _last_hero_cell          # рисуем всегда, кэш только для источника
    _last_hero_cell = cell
    var pos := _world_to_overlay(map_ref.map_to_local(cell), size)
    draw_circle(pos, HERO_RADIUS, ThemeConfig.C_MINIMAP_HERO)
    draw_arc(pos, HERO_RADIUS + 2.0, 0, TAU, 16, ThemeConfig.C_MINIMAP_HERO_RING, 1.0)
```
(Суть: убрать ранний `return` **до** отрисовки и заменить `has_method` на `"current_cell" in hero_ref`.)
**Приёмка:** новый тест `MinimapOverlayTest`: стаб-герой со свойством `current_cell` → `_draw_hero_dot` не выходит рано; визуально — точка видна после движения камеры.

### R2 — High. Завершить миграцию на `Services`, удалить `ServiceLocator` из продакшена
**Файлы:** все, где встречается `ServiceLocator.resolve(...)` (см. A1); сам `scripts/core/ServiceLocator.gd` — оставить только как совместимый мост до финального выпиливания.
**Зачем:** один путь резолва, убираем двойную логику и fallback-поиск по дереву.
**До:**
```gdscript
var reg: Node = ServiceLocator.resolve(null, &"spells")
```
**После:**
```gdscript
var reg: Node = Services.resolve(&"spells")
```
Плюс в тестах — передавать реестр параметром (паттерн уже применён в `BattleSpellbookPanel.setup(..., registry)`), чтобы не зависеть от автозагрузок в юнит-тестах.
**Приёмка:** `grep -rn "ServiceLocator" scripts/` пуст (кроме самого файла-моста и его тестов); все тесты зелёные.

### R3 — High. Разрезать `BattleTurnExecutor` на три класса
**Файл:** `scripts/systems/BattleTurnExecutor.gd`
**Зачем:** 700-строчный класс смешивает стейт-машину, боевую последовательность и политику отступления; изменения рискуют сломать очередность (уже были такие дефекты).
**Целевая структура:**

| Новый класс | Ответственность | Что переезжает |
|---|---|---|
| `BattleTurnExecutor` (худой) | стейт-машина `State`, `advance_to_next_turn`, пауза/токены | `_transition_to`, `_is_stale`, `pause/resume`, сигналы фаз |
| `BattleAttackSequence` | удары, двойной удар, реталиация, первый удар, мораль-ход | `_start_attack`, `_do_next_attack_strike`, `_start_retaliation`, `_try_morale_extra_turn`, `_can_retaliate` |
| `BattleRetreatPolicy` | очередь и исполнение отступления | `_retreat_requested`, `request_retreat`, `force_retreat`, `_execute_retreat` |

**Приёмка:** существующие тесты (`test_battle_retreat_queue.gd`, `test_applied_fixes.gd`, `test_battle_spell_executor.gd`) проходят без изменений; публичные сигналы экзекьютора сохранены.

### R4 — Medium. Единый тип результата операций города
**Файлы:** `CityBuildingService`, `MarketSystem`, `ArenaTurnRunner`, `ZoningSystem`, `CityScreen`.
**Зачем:** 4 независимых клона `{"ok": bool, "reason": String}`; опечатки в ключах не отлавливаются типами.
**До:**
```gdscript
static func fail(reason: String) -> Dictionary:
    return {"ok": false, "cost": 0.0, "reason": reason}
```
**После:**
```gdscript
# scripts/city/CityCheck.gd
class_name CityCheck extends RefCounted
var ok := false
var reason := ""
var payload := {}
static func pass(payload: Dictionary = {}) -> CityCheck: ...
static func fail(reason: String) -> CityCheck: ...
```
Вызывающие: `check.ok`, `check.reason` — компилируемые свойства вместо строк-ключей.
**Приёмка:** замена всех `Dictionary`-результатов; тесты города зелёные.

### R5 — Medium. Завершить фасад `City`
**Файл:** `scripts/world/City.gd`
**Что:** перенести в сервисы инлайн-остатки:
- `is_worker_tile_free`, `first_free_worker_tile`, `first_free_build_cell`, `_is_adjacent_to_city_body` → `CityBuildingService`;
- `defense_strength` → `CityService`;
- `request_switch` → `CityService` (с эмитом сигналов на фасаде).
**До:** тело метода в `City.gd` (30–40 строк).
**После:** однострочный делегат вида `func defense_strength() -> int: return CityService.defense_strength(self)` — по образцу уже сделанных методов в том же файле.
**Приёмка:** `City.gd` содержит только сигналы, свойства, делегаты; правила размещения покрываются юнит-тестами без сцены.

### R6 — Medium. Унифицировать контракт `TemplateEngine`
**Файлы:** `scripts/data/TemplateEngine.gd`, `t05_combat_trick.gd`, `TemplateBootstrap.gd`
**Зачем:** убрать спецветку по имени шаблона (баг 2 из §2.1).
**До:**
```gdscript
if template == &"COMBAT_TRICK":
    return _handlers[template].call(params, secondary, state, caster, target)
return _handlers[template].call(params, state, caster, target)
```
**После:** единая сигнатура `handle(params, state, caster, target, secondary)`, `secondary` по умолчанию `[]`; в `execute` всегда передаётся массив. `T05` получает вторым аргументом с конца.
**Приёмка:** `test_spell_system.gd` (раздел `test_all_templates_exist`) зелёный; в движке нет ветвления по имени шаблона.

### R7 — Medium. Реестр статических кэшей
**Файлы:** новый `scripts/core/StaticCaches.gd`; правки в `services.gd`, `MainMenu.gd`, `EndgameController.gd`
**Зачем:** сегодня «что сбросить на границе сессии» решается в трёх местах независимо (A3).
```gdscript
class_name StaticCaches
static func reset_all() -> void:
    HexUtils.reset()
    TemplateEngine.reset()
    ShardManager.reset()
    ArenaClusterSystem.reset()
    ResourceIcons.clear_cache()
    TileAtlasCache.clear_cache()
    UnitSprites.clear_caches()      # добавить метод
    PlaceholderTexture.clear()      # добавить метод
    ResourceAtlas.clear()           # добавить метод
```
`Services.clear_session()` вызывает `StaticCaches.reset_all()`; из `MainMenu._clear_session_caches` и `EndgameController._return_to_menu` убрать ручные сбросы.
**Приёмка:** один тест «`reset_all()` не падает и обнуляет кэши»; в коде не остаётся прямых вызовов отдельных `reset()` вне `StaticCaches`.

### R8 — Medium. Консолидация тестовых фабрик
**Файлы:** `tests/helpers/test_factories.gd` + тесты из §2.2-P7
**Что:** перенести дублирующиеся `_make_hero`, `_make_city`, `_make_temple_city`, `_make_unit`, `_seeded` в `TestFactories` (частично уже существует) и удалить локальные копии.
**Приёмка:** `grep -rn "func _make_hero" tests/` — только фабрика.

### R9 — Low. Убрать мёртвый код
- Либо подключить `CursorSprite` в `CursorController.MODE_ASSETS` (заполнив пути), либо удалить `CursorSprite` и пустые записи.
- Проверить использование `HeroSlot.tscn`/`TownSlot.tscn`; если не инстанцируются — удалить (структура продублирована в `InfoPanel.tscn`).
**Приёмка:** `grep` по именам сцен/скриптов не находит ссылок.

### R10 — Low. Мелочи
| Что | Как |
|---|---|
| `Artifact._init` 12 параметров | перейти на именованный конструктор `Artifact.from_dict(def)` в `ArtifactRegistry._register` |
| `SpellbookRegistry._by_color` | ключевать `int`-значением `SpellColor`, не строкой |
| `EquipmentManager._highest_type(b_slot := -1)` | перегрузка/массив слотов вместо «-1 как отсутствие» |
| `WorldBootstrap._create_cities` | имена городов через `GameText`/фабрику |
| `EconomicTurnProcessor` | комментарий «авто-доход начисляется до цепочек — цепочки могут его потреблять в тот же ход» (закреплено тестом) |

---

## 5. Инструкция для локального агента

> Работать строго по фазам, каждую фазу завершать зелёным прогоном тестов. Коммит на фазу.

### Фаза 0 — Базовая линия
1. Прогнать полный набор тестов и зафиксировать эталон:
   ```bash
   # проект использует gdUnit4 (см. Platform.is_test_framework_run и упоминание run_tests.sh)
   sh run_tests.sh            # либо:
   godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests -a
   ```
2. Компиляционный смоук:
   ```bash
   godot --headless --editor --quit
   ```
**Критерий:** эталонный список проходящих/падающих тестов сохранён (дальше сравниваем с ним — деградаций быть не должно).

### Фаза 1 — Критический баг (R1)
**Файлы:** `scripts/ui/MinimapOverlay.gd`; новый тест `tests/unit/ui/MinimapOverlayTest.gd`.
**Шаги:** применить правку из R1; добавить тест на стаб-героя со свойством `current_cell`; проверить, что `_draw_hero_dot` доходит до `draw_circle` (через мок/флаг или через отсутствие раннего возврата).
**Приёмка:** новый тест зелёный; регрессий нет.

### Фаза 2 — Единый DI и кэши (R2, R7)
**Файлы:** все продакшен-файлы с `ServiceLocator.resolve` (найти: `grep -rn "ServiceLocator" scripts/ tests/`); `scripts/core/services.gd`; новый `scripts/core/StaticCaches.gd`; `scripts/ui/MainMenu.gd`; `scripts/systems/EndgameController.gd`; добавить `clear`-методы в `UnitSprites`, `PlaceholderTexture`, `ResourceAtlas`.
**Шаги:**
1. Заменить вызовы на `Services.resolve(&"key")`; в тестах, где реестр доступен параметром, — передавать параметром.
2. Создать `StaticCaches.reset_all()`, подключить в `Services.clear_session()`.
3. Убрать ручные цепочки сбросов из `MainMenu` и `EndgameController`.
**Приёмка:** `grep -rn "ServiceLocator" scripts/` — только сам файл-мост; тест сессии (`test_session_reset.gd`, MCP `test_session_reset.py`) зелёные; смоук главного меню.

### Фаза 3 — Боевой экзекьютор (R3)
**Файлы:** `scripts/systems/BattleTurnExecutor.gd` → разрезать на 3 файла; новые `BattleAttackSequence.gd`, `BattleRetreatPolicy.gd`; трогать `BattleController.gd` только при изменении сигнатур сигналов (не менять их).
**Приёмка:** `test_battle_retreat_queue.gd`, `test_applied_fixes.gd`, `test_battle_spell_executor.gd`, `test_spellbook_guards.gd`, MCP-сценарий `test_battle_tween.py` — без изменений и зелёные.

### Фаза 4 — Городской слой (R4, R5)
**Файлы:** новый `scripts/city/CityCheck.gd`; `CityBuildingService.gd`, `MarketSystem.gd`, `ZoningSystem.gd`, `ArenaTurnRunner.gd`, `City.gd`, `CityService.gd`, `CityScreen.gd`, `WorldUIManager.gd` (`city_screen_action`).
**Шаги:** ввести `CityCheck`; мигрировать возвращаемые типы; перенести инлайн-методы `City` в сервисы делегатами.
**Приёмка:** зелёные `test_city_*` (chains, systems, housing, screen, persistence, navigation, growth, serializer, yield), `test_borough_rules.gd`.

### Фаза 5 — Шаблоны и заклинания (R6, A2)
**Файлы:** `TemplateEngine.gd`, `t05_combat_trick.gd`, `TemplateBootstrap.gd`; далее — задокументировать канонический путь боевого каста (`SpellCaster` + `SpellRegistry`), `SpellbookRegistry`+`SpellResolver`+мосты пометить `## @deprecated`/областью применения (эмулятор/карточный режим).
**Приёмка:** `test_spell_system.gd`, `test_spellbook_guards.gd`, `test_magic_resistance.gd`, MCP `test_battle_profiling.py`.

### Фаза 6 — Зачистка (R8, R9, R10)
**Файлы:** `tests/helpers/test_factories.gd`, тесты с дублями; `CursorController.gd`/`CursorSprite.gd`; `HeroSlot.tscn`/`TownSlot.tscn`; `Artifact.gd`/`ArtifactRegistry.gd`; `SpellbookRegistry.gd`; `EquipmentManager.gd`; `WorldBootstrap.gd`.
**Приёмка:** `grep -rn "func _make_hero" tests/` — только фабрика; нет ссылок на удалённые сцены; смоук всех четырёх сцен:
```bash
godot --headless --quit-after 120 res://scenes/MainMenu.tscn
godot --headless --quit-after 240 res://scenes/World.tscn
godot --headless --quit-after 120 res://scenes/CityArena.tscn
godot --headless --quit-after 120 res://scenes/Battle.tscn
```

### Общие критерии приёмки всего плана
1. Полный прогон тестов не хуже эталона фазы 0.
2. Нет новых `push_error`/`push_warning` в смоук-запусках.
3. `ServiceLocator` отсутствует в продакшен-коде.
4. Точка героя видна на миникарте (ручная проверка или скриншот-тест).
5. Границы сессий: повторный вход в мир после выхода в меню не несёт состояния прошлой партии (проверка `test_session_reset.gd`).

---

### Сводка приоритетов

| Приоритет | Правки |
|-----------|--------|
| **High** | R1 (баг миникарты), R2 (единый DI), R3 (разрезка экзекьютора) |
| **Medium** | R4 (CityCheck), R5 (фасад City), R6 (TemplateEngine), R7 (StaticCaches), R8 (фабрики тестов) |
| **Low** | R9 (мёртвый код), R10 (мелочи: Artifact-init, `_by_color`, `_highest_type`, имена городов, комментарий фаз экономики) |

# Аудит тестовой инфраструктуры

---

## 1. Структура тестов: текущее состояние

### 1.1. Инвентаризация

| Слой | Файлы | Фреймворк | Статус |
|---|---|---|---|
| `tests/core/` | `BattleRulesTest`, `HexPathfindingTest`, `HexUtilsTest`, `TurnSchedulerTest` | gdUnit4 | ✅ |
| `tests/entities/` | `EquipmentManagerTest` | gdUnit4 | ✅ |
| `tests/systems/` | `BattleDamageResolverTest`, `city/BoroughRulesTest` | gdUnit4 | ✅ |
| `tests/integration/` | `BattleInputTest`, `EventRouterTest` | gdUnit4 | ✅ |
| `tests/unit/` | 12 файлов (`core/`, `data/`, `systems/`, `world/`) | gdUnit4 | ✅ |
| `tests/functional/` | 10 файлов (`test_benchmarks`, `test_compile_all`, …) | gdUnit4 | ✅ |
| `tests/spell_validation/` | `SpellValidator`, `ValidationReport` | gdUnit4 | ✅ |
| `tests/fakes/` | 5 файлов (`fake_battle_flow`, `MockBattleView`, …) | gdUnit4 | ✅ |
| `tests/helpers/` | `test_factories.gd`, **`mcp_client.py`** | gdUnit4 / **самописный** | ⚠️ |
| `tests/mcp/` | `conftest.py`, 6 тестовых `.py` | **pytest + самописный MCP** | 🔴 |
| Корень `tests/` | ~50 файлов `test_*.gd`, `Test*.gd` | gdUnit4 | ⚠️ дубли |

### 1.2. Проблемы структуры

**Дублирование тестовых файлов:**

| Дубль 1 | Дубль 2 | Пересечение |
|---|---|---|
| `tests/core/HexUtilsTest.gd` | `tests/TestHexUtils.gd` | `hex_distance`, `cube_roundtrip` |
| `tests/core/BattleRulesTest.gd` | `tests/TestBattleRules.gd` | `calculate_attack` |
| `tests/core/TurnSchedulerTest.gd` | `tests/test_turn_scheduler.gd` | фазы, приоритеты, сигналы |
| `tests/systems/city/BoroughRulesTest.gd` | `tests/test_borough_rules.gd` | `max_boroughs`, `cost`, `level_up` |
| `tests/test_city_systems.gd` | `tests/unit/world/CityTest.gd` | `pop_cap`, `boroughs`, `buildings` |

**Несогласованность именования:** три стиля в одном проекте — `TestXxx.gd`, `test_xxx.gd`, `XxxTest.gd`.

**`TestCityEconomy.gd`** — тест города в корне, дублирует `tests/unit/world/CityGrowthServiceTest.gd`.

---

## 2. Следы GUT: результат проверки

Проведён поиск по всем файлам `tests/` по сигнатурам GUT:

| Паттерн GUT | Найдено |
|---|---|
| `extends GutTest` / `extends "res://addons/gut/test.gd"` | ❌ |
| `assert_eq`, `assert_ne`, `assert_true`, `assert_false` | ❌ |
| `assert_null`, `assert_not_null`, `assert_has` | ❌ |
| `before_each`, `after_each`, `before_all`, `after_all` | ❌ |
| `gut.p()`, `watch_signals()`, `assert_signal_emitted()` | ❌ |
| `double()`, `stub()`, `pending()` | ❌ |
| `addons/gut/`, `.gutignore`, `gut_config.json` | ❌ |

**Вывод: следов GUT нет.** Все `.gd`-тесты уже на gdUnit4 (`extends GdUnitTestSuite`, `assert_bool/that/int/float/str/object/array/dict/vector/error`, `before_test/after_test`). Конвертация не требуется.

---

## 3. Рефакторинг на tugcantopaloglu/godot-mcp

### 3.1. Что заменяем

Текущий `tests/helpers/mcp_client.py` — **самописный** JSON-RPC-транспорт поверх `asyncio.create_subprocess_exec`. Он вручную реализует:
- инициализацию MCP-сессии (`initialize` → `notifications/initialized`),
- чтение/запись JSON-RPC по строкам,
- управление `_pending`-фьючерсами,
- обработку ошибок и таймаутов.

Всё это уже предоставляет пакет `mcp` (Python SDK для Model Context Protocol). Серверная часть — `tugcantopaloglu/godot-mcp` (`build/index.js`) — остаётся без изменений.

### 3.2. Новый `tests/helpers/mcp_client.py`

```python
"""
Клиент для tugcantopaloglu/godot-mcp на базе официального mcp-пакета.
Заменяет самописный JSON-RPC-транспорт.
"""
from __future__ import annotations

import asyncio
import json
import os
from contextlib import AsyncExitStack
from typing import Any

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

PROJECT_PATH = os.environ.get(
    "GODOT_PROJECT_PATH",
    "/Users/user/sigil-of-the-unwilling/game",
)

SERVER_JS = os.environ.get(
    "GODOT_MCP_SERVER",
    "/Users/user/sigil-of-the-unwilling/godot-mcp/build/index.js",
)


class GodotMCPClient:
    """Обёртка над tugcantopaloglu/godot-mcp через mcp.client.stdio."""

    def __init__(
        self,
        server_command: str = "node",
        server_args: list[str] | None = None,
    ) -> None:
        self.server_command = server_command
        self.server_args = server_args if server_args is not None else [SERVER_JS]
        self._stack = AsyncExitStack()
        self._session: ClientSession | None = None

    # ── lifecycle ────────────────────────────────────────────────

    async def connect(self) -> None:
        params = StdioServerParameters(
            command=self.server_command,
            args=self.server_args,
        )
        read, write = await self._stack.enter_async_context(
            stdio_client(params)
        )
        self._session = await self._stack.enter_async_context(
            ClientSession(read, write)
        )
        await self._session.initialize()

    async def disconnect(self) -> None:
        await self._stack.aclose()
        self._session = None

    # ── tools ────────────────────────────────────────────────────

    async def _call(self, tool: str, arguments: dict) -> Any:
        assert self._session is not None, "Not connected"
        result = await self._session.call_tool(tool, arguments)
        if result.isError:
            text = result.content[0].text if result.content else "unknown"
            raise RuntimeError(f"MCP tool {tool} failed: {text}")
        return json.loads(result.content[0].text)

    async def execute_code(self, code: str) -> Any:
        data = await self._call("game_eval", {"code": code})
        if isinstance(data, dict) and "result" in data:
            return data["result"]
        return data

    async def get_scene_tree(self) -> dict:
        return await self._call("game_get_scene_tree", {})

    async def get_node_property(self, path: str, prop: str) -> Any:
        return await self._call(
            "game_get_property", {"nodePath": path, "property": prop}
        )

    async def set_node_property(self, path: str, prop: str, value: Any) -> None:
        await self._call(
            "game_set_property",
            {"nodePath": path, "property": prop, "value": value},
        )

    async def call_method(
        self, path: str, method: str, args: list | None = None
    ) -> Any:
        return await self._call(
            "game_call_method",
            {"nodePath": path, "method": method, "args": args or []},
        )

    async def find_nodes_by_type(self, node_type: str) -> list[str]:
        return await self._call(
            "game_find_nodes_by_class", {"className": node_type}
        )

    async def run_scene(self, scene_path: str) -> None:
        await self._call(
            "run_project",
            {"projectPath": PROJECT_PATH, "scene": scene_path},
        )

    async def stop_running_scene(self) -> None:
        await self._call("stop_project", {})

    # ── helpers ──────────────────────────────────────────────────

    async def wait_frames(self, frames: int = 10) -> None:
        await asyncio.sleep(frames / 60.0)

    async def wait_ready(self, timeout: float = 60.0) -> None:
        loop = asyncio.get_running_loop()
        deadline = loop.time() + timeout
        while loop.time() < deadline:
            try:
                await self.execute_code("return 1")
                return
            except (RuntimeError, TimeoutError, OSError):
                await asyncio.sleep(1.0)
        raise TimeoutError("Game interaction server not ready")
```

### 3.3. Обновлённый `tests/mcp/conftest.py`

```python
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import pytest
import pytest_asyncio

sys.path.insert(0, str(Path(__file__).parent.parent))
from helpers.mcp_client import GodotMCPClient


async def _wait_port_free(port: int = 9090, timeout: float = 30.0) -> None:
    loop = asyncio.get_running_loop()
    deadline = loop.time() + timeout
    while loop.time() < deadline:
        try:
            _, writer = await asyncio.open_connection("127.0.0.1", port)
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass
        except (ConnectionRefusedError, OSError):
            return
        await asyncio.sleep(0.2)
    raise TimeoutError(f"port {port} still in use after {timeout}s")


@pytest_asyncio.fixture
async def mcp() -> GodotMCPClient:
    client = GodotMCPClient()
    await client.connect()
    yield client
    await client.disconnect()


@pytest_asyncio.fixture
async def battle_scene(mcp: GodotMCPClient):
    await _wait_port_free()
    await mcp.run_scene("res://scenes/Battle.tscn")
    await asyncio.sleep(10)
    await mcp.wait_ready(60)
    await mcp.wait_frames(30)
    yield mcp
    await mcp.stop_running_scene()
    await _wait_port_free()


@pytest_asyncio.fixture
async def world_scene(mcp: GodotMCPClient):
    await _wait_port_free()
    await mcp.run_scene("res://scenes/World.tscn")
    await asyncio.sleep(10)
    await mcp.wait_ready(60)
    await mcp.wait_frames(60)
    yield mcp
    await mcp.stop_running_scene()
    await _wait_port_free()
```

### 3.4. Обновлённый `tests/mcp/pyproject.toml`

```toml
[project]
name = "sigil-mcp-tests"
requires-python = ">=3.11"
dependencies = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "mcp>=1.0",
]
```

### 3.5. Миграция тестов

Сами тестовые файлы (`test_battle_profiling.py`, `test_battle_tween.py`, `test_hexutils_perf.py`, `test_resource_and.py`, `test_session_reset.py`, `test_shard_pruning.py`) **не меняются**: они используют только публичные методы (`mcp.execute_code`, `mcp.run_scene`, `mcp.wait_frames`, `mcp.stop_running_scene`), сигнатуры которых сохранены.

---

## 4. Покрытие кода тестами: пробелы

### 4.1. Покрыто (основные модули)

| Домен | Модули | Тестов |
|---|---|---|
| Бой | `BattleState`, `BattleRules`, `BattleAI`, `BattleTurnExecutor`, `BattleInput`, `BattleView`, `BattleActionResolver`, `BattleDamageResolver`, `BattleEmulator`, `BattleFlow`, `BattleFX` | ~15 |
| Заклинания | `SpellRegistry`, `SpellbookRegistry`, `SpellCaster`, `TemplateEngine`, `SpellResolver`, `BattleSpellBridge` | ~5 |
| Город | `City`, `CityService`, `CityBuildingService`, `CityGrowthService`, `CitySerializer`, `CityYieldCalculator`, `CityManager`, `CityTurnProcessor`, `BoroughRules`, `ReputationSystem`, `MarketSystem`, `RaidSystem`, `ProsperitySystem`, `ZoningSystem`, `ScaleShiftManager`, `LogisticsCalculator`, `AdjacencySystem`, `ArenaClusterSystem`, `CityEvents`, `SpecializationSystem`, `WorkerAssignment` | ~20 |
| Экономика | `EconomicTurnProcessor`, `CityIncomeProcessor`, `ProductionChain`, `ResourceContext` | ~5 |
| Демография | `DemographicTurnProcessor`, `Character`, `CharacterRegistry`, `TraitDef`, `TraitRegistry` | ~4 |
| Герой | `HeroController`, `HeroMovementController`, `HeroArmyController`, `HeroResources`, `HeroMagic`, `HeroInventory`, `HeroNeeds`, `HeroBuildProfile`, `HeroStrategicResources` | ~10 |
| Карта | `MapGenerator`, `MapModel`, `VisibilityMap`, `HexUtils`, `HexPathfinding`, `MinHeap`, `TerrainCostTable` | ~8 |
| Мир | `WorldController`, `WorldBattleCoordinator`, `WorldBootstrap`, `WorldPersistence`, `WorldEventRouter`, `WorldSpawner`, `WorldInteractionController`, `WorldCamera`, `TurnScheduler` | ~8 |
| Данные | `SaveManager`, `SaveData`, `GameSession`, `GloryTracker`, `EndgameController`, `ShardManager`, `Artifact`, `ArtifactRegistry`, `EquipmentManager`, `ResourceRegistry`, `ResourceNodeManager`, `TerrainResourceManager` | ~10 |
| UI | `SettingsScreen`, `CityScreen`, `CityArenaView`, `DeathSequence`, `ChronicleScreen`, `HeroStatusPanel`, `ResourceCollectPopup`, `BattleUI`, `UIAnimator` | ~8 |

### 4.2. Не покрыто или покрыто слабо

| Модуль | Причина | Приоритет |
|---|---|---|
| `WorldStateSerializer` | Нет прямого теста сериализации мира | **High** |
| `CityStateSerializer` | Нет прямого теста сериализации города для MCP | **High** |
| `WorldShortcuts` | Только косвенный тест в `test_spellbook_guards` | **Medium** |
| `HeroVisualController` | Визуальный, но `_find_sheet` и `_build_anim_from_sheet` тестируемы | **Medium** |
| `MapRenderer` | Нет юнит-теста `paint()` / `apply_fog()` | **Medium** |
| `MapSpawner` | Нет юнит-теста `place_villages` / `place_resources` / `place_enemies` | **Medium** |
| `WorldUIManager` | Нет юнит-теста `setup()` / `city_screen_action()` | **Medium** |
| `AdventureUI` | Нет юнит-теста | **Low** |
| `ArmyPanel`, `ResourceBar`, `ResourcesPanel`, `SkillsPanel`, `ToolsPanel`, `MinimapPanel` | Нет юнит-тестов | **Low** |
| `ArenaHexCell`, `ItemSlotUI` | Нет юнит-тестов | **Low** |
| `DestMarker`, `StatusOrb`, `CursorOverlay`, `HighlightOverlay` | Нет юнит-тестов (визуальные) | **Low** |
| `HexMapGenerator`, `HexAutotiler` | Editor-tools, не критично | **Low** |
| `BorderContainer` | Пустой класс | **Low** |
| `ParticlePresets` | Визуальный, не критично | **Low** |

### 4.3. Приоритетные пробелы

1. **`WorldStateSerializer`** — сериализация мира для MCP. Ошибка здесь ломает сохранение/загрузку.
2. **`CityStateSerializer`** — сериализация города для MCP-запросов.
3. **`WorldShortcuts`** — горячие клавиши. Нет теста на `_unhandled_input`.
4. **`MapSpawner`** — спавн ресурсов/врагов/сундуков. Ошибка здесь ломает генерацию мира.

---

## 5. Логика тестов: замечания

### 5.1. Ручное освобождение вместо `auto_free()`

В `test_battle_coordinator.gd`, `test_hero_survival.gd`, `test_legend_chronicle.gd` объекты освобождаются вручную (`hero.free()`, `mgr.free()`). gdUnit4 предоставляет `auto_free()` — безопаснее при падении теста.

**Было:**
```gdscript
hero.free()
mgr.free()
wc.free()
```
**Стало:**
```gdscript
auto_free(hero)
auto_free(mgr)
auto_free(wc)
```

### 5.2. Вызов `_ready()` без добавления в дерево

В `test_hero_survival.gd`:
```gdscript
var h := _Hero.new()
h._ready()  # ← вызов без родителя
```
`_ready()` в `HeroController` создаёт дочерние узлы (`movement`, `army`, `resources`, `visual`) через `add_child()`. Без родителя `add_child` работает, но `is_inside_tree()` вернёт `false`. Лучше:
```gdscript
var parent := Node2D.new()
add_child(parent)
parent.add_child(h)
```

### 5.3. Детерминизм в `TestBattleRules.gd`

Тест `test_battle_7v7_performance` использует `BattleEmulator.emulate_battle()`, который внутри создаёт `RandomNumberGenerator.new()` с `rng.randomize()` — **недетерминированный**. Для стабильности тестов нужно передавать сид:
```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = 42
```
Но `emulate_battle` не принимает `rng`. Это архитектурный пробел.

### 5.4. `test_world_scenario.gd` — тяжёлый функциональный тест

Тест инстанцирует `World.tscn` и ждёт 2 секунды. Это медленно и хрупко. Рекомендуется:
- Разбить на более мелкие тесты (сохранение, загрузка, смерть, преемственность).
- Вынести в отдельную категорию `@slow` для пропуска в CI.

### 5.5. `test_city_arena_view.gd` — инстанцирование тяжёлой сцены

```gdscript
var packed := load("res://scenes/CityArena.tscn") as PackedScene
_view = packed.instantiate() as CityArenaView
add_child(_view)
await get_tree().process_frame
```
Сцена `CityArena.tscn` содержит 12 кнопок палитры, 6 кнопок бара, таймер, камеру. Для юнит-тестов лучше использовать `CityArenaModel` напрямую без сцены.

---

## 6. Пошаговый план

### Фаза 0 — Базовая линия
```bash
# Прогнать все тесты, зафиксировать эталон
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests -a
```

### Фаза 1 — Удаление дублей (1 коммит)

| Действие | Файл | Куда мержить |
|---|---|---|
| Удалить | `tests/TestHexUtils.gd` | в `tests/core/HexUtilsTest.gd` |
| Удалить | `tests/TestBattleRules.gd` | в `tests/core/BattleRulesTest.gd` |
| Удалить | `tests/test_turn_scheduler.gd` | в `tests/core/TurnSchedulerTest.gd` |
| Удалить | `tests/test_borough_rules.gd` | в `tests/systems/city/BoroughRulesTest.gd` |
| Удалить | `tests/TestCityEconomy.gd` | в `tests/unit/world/CityGrowthServiceTest.gd` |
| Переименовать | `tests/core/BattleRulesTest.gd` → `test_battle_rules.gd` | единый стиль |

**Критерий:** количество тестов не уменьшилось, дублей нет.

### Фаза 2 — Рефакторинг MCP (1 коммит)

1. Заменить `tests/helpers/mcp_client.py` на новую реализацию (раздел 3.2).
2. Обновить `tests/mcp/conftest.py` (раздел 3.3).
3. Обновить `tests/mcp/pyproject.toml` — добавить `mcp>=1.0` (раздел 3.4).
4. Убедиться, что `tests/mcp/pytest.ini` не меняется.
5. Прогнать MCP-тесты:
```bash
cd tests/mcp && python -m pytest -xvs
```

**Критерий:** все MCP-тесты проходят, самописный JSON-RPC удалён.

### Фаза 3 — Замена `auto_free` (1 коммит)

Заменить ручное `.free()` на `auto_free()` в:
- `test_battle_coordinator.gd`
- `test_hero_survival.gd`
- `test_legend_chronicle.gd`
- `test_world_scenario.gd`
- `test_worldcontroller_succession_wiring.gd`

**Критерий:** нет утечек при падении тестов.

### Фаза 4 — Тесты для непокрытых модулей (по приоритету)

| Приоритет | Модуль | Тест |
|---|---|---|
| **High** | `WorldStateSerializer` | `tests/unit/world/WorldStateSerializerTest.gd` |
| **High** | `CityStateSerializer` | `tests/unit/world/CityStateSerializerTest.gd` |
| **Medium** | `WorldShortcuts` | `tests/unit/world/WorldShortcutsTest.gd` |
| **Medium** | `MapSpawner` | `tests/unit/world/MapSpawnerTest.gd` |
| **Medium** | `MapRenderer` | `tests/unit/world/MapRendererTest.gd` |

### Фаза 5 — Финальная проверка
```bash
# Все тесты
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd res://tests -a

# MCP-тесты
cd tests/mcp && python -m pytest -xvs

# Проверка отсутствия самописного транспорта
grep -rn "create_subprocess_exec" tests/helpers/mcp_client.py  # должно быть пусто
grep -rn "_pending" tests/helpers/mcp_client.py                # должно быть пусто
```

**Критерий приёмки:** все тесты зелёные, в `mcp_client.py` нет самописного JSON-RPC, используется `mcp.client.stdio.stdio_client` + `ClientSession` из пакета `mcp`, серверная часть — `tugcantopaloglu/godot-mcp`.