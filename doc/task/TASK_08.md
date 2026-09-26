# Аудит проекта «Sigil of the Unwilling» (Godot 4.7)

---

## 1. Архитектура

### 1.1. Общая структура

| Слой | Пути | Оценка |
|---|---|---|
| Core (утилиты, DI, hex-математика) | `core/` | ✅ Чисто |
| Data (дефайны, реестры) | `data/`, `autoload/` | ✅ Хорошо |
| Systems (бой, ИИ, эндшпиль) | `systems/` | ⚠️ Смешано |
| World (карта, герой, персистентность) | `world/` | ⚠️ Перегружено |
| City (город, экономика, арена) | `city/`, `economy/` | ✅ После рефакторинга лучше |
| UI | `ui/` | ⚠️ Завязка на сцены |

### 1.2. Критические проблемы

#### P1. `WorldController` — God Object
**Файл:** `scripts/world/WorldController.gd`

Содержит: инициализацию мира, управление героем, камеру, бой, сохранение, загрузку, сукцессию, эндшпиль, ввод, спавн. ~50+ зависимостей.

#### P2. `City.gd` — перегруженный класс (~600 строк)
Несмотря на частичный рефакторинг (выделены `CityGrowthService`, `CityBuildingService`, `CitySerializer`), `City` всё ещё хранит:
- данные (население, здания, ресурсы, боры);
- логику роста/еды;
- сериализацию-обёртки;
- кэши доходности;
- методы размещения.

#### P3. `MapGenerator.gd` — фасад на три несвязанных класса
```
MapGenerator
├── model: MapModel       (данные)
├── renderer: MapRenderer (отрисовка)
└── spawner: MapSpawner   (спавн сущностей)
```
`MapGenerator` — `Node2D`, но делегирует через свойства `model.terrain_grid`, `model.enemy_stacks`. Это ломает инкапсуляцию: любой код лезет в `model` напрямую.

#### P4. Статическое мутабельное состояние

| Класс | Поле | Риск |
|---|---|---|
| `HexUtils` | `_config`, `_shift_right` | Глобальный мутабельный синглтон |
| `ServiceLocator` | (кэш удалён, но статические методы) | Привязка к дереву сцены |
| `WorldPersistence` | `pending_save`, `pending_new_game` | Статические поля-глобалы |
| `TemplateEngine` | `_handlers` | Статический словарь |

#### P5. Связность через автозагрузки
`GameEventBus` — глобальный сигнал-хаб. Подключаются: `CursorController`, `WorldEventRouter`, `EndgameController`, `HeroLifecycleSystem`, `AdventureUI`. Это **широковещательная шина без типизации подписчиков**.

### 1.3. Положительные паттерны

| Паттерн | Где | Качество |
|---|---|---|
| Service Locator / DI | `ServiceLocator`, `ServiceRegistry`, `services.gd` | ✅ |
| Strategy | `NeedStrategy` → `RestStrategy`, `SocialStrategy`, `InspirationStrategy` | ✅ |
| State Machine | `BattleTurnExecutor.State` | ✅ |
| Observer (сигналы) | Повсеместно | ✅ |
| Builder | `BattleStateBuilder` | ✅ |
| Phase Pipeline | `TurnScheduler` + `TurnPhaseProcessor` | ✅ |
| Factory | `CityFactory`, `HeroModelFactory` | ✅ |

---

## 2. Лучшие практики

### 2.1. Идиомы GDScript / Godot

| Проблема | Где | Серьёзность |
|---|---|---|
| `@onready` в тестах без сцены | `BattleController._ready` использует `@onready var _view` | Medium |
| `extends Node` для чистых данных | `HeroResources extends Node` вместо `RefCounted` | Medium |
| `extends Node2D` для `MapGenerator`, хотя логика в `MapModel` | `MapGenerator` | High |
| Смешение `_process` и ручной анимации | `BattleView`, `CursorOverlay` | Low |
| `get_node_or_null` цепочки вместо типизированных ссылок | UI-скрипты | Low |

### 2.2. SOLID

| Принцип | Нарушение | Пример |
|---|---|---|
| **SRP** | `City` — рост + строительство + сериализация + доход | `City.gd` |
| **SRP** | `WorldController` — 8+ ролей | `WorldController.gd` |
| **OCP** | `SpellCaster.cast()` — `match` по `spell_id` для cure/slow_mass/resurrection | `SpellCaster.gd:60-80` |
| **DIP** | `HeroController` напрямую создаёт `HeroMovementController`, `HeroArmyController` | `HeroController._ready()` |
| **ISP** | `BattleState` — и контейнер, и логика боя, и A* | `BattleState.gd` |

### 2.3. DRY

| Дублирование | Где |
|---|---|
| `_load_sheet()` / `_cell_size()` / кэш текстур — `ResourceAtlas` vs `ResourceIcons` vs `PlaceholderTexture` | 3 параллельных кэша |
| `ring_yield` / `ring_bonus` — обёртки `ArenaRingSystem` → `GameNumbers` → `ArenaModel` | 3 уровня делегирования без добавления логики |
| `_make_hero()` / `_make_city()` — повторяются в 6+ тестовых файлах | `tests/` |

### 2.4. Обработка ошибок

| Проблема | Где | Риск |
|---|---|---|
| `JSON.parse_string` без проверки на `null` в ряде мест | `BuildingDefs._ensure_loaded` | High |
| `FileAccess.open` без проверки `null` в `gen_en_po.gd` | `tools/gen_en_po.gd` | Medium |
| `ResourceLoader.load` без проверки типа | `BattleView.paint_field` → `TileAtlas.build_hex_tileset()` | Medium |
| `hero.get("movement")` через `Variant` без каста | `WorldBattleCoordinator` | Low |

### 2.5. Naming

В целом **хорошо**: `snake_case`, префиксы `_` для приватных, константы `UPPER_CASE`. Исключения:

- `_i100`, `_i50`, `_i30` в `HexMapGenerator` — нечитаемые имена.
- `_sp` в `gen_artifact_icons.gd` — сокращение без контекста.

---

## 3. Алгоритмы

### 3.1. Инвентарь алгоритмов

| Алгоритм | Где | Сложность | Оценка |
|---|---|---|---|
| A* на гекс-графе | `HexPathfinding.astar_path` | O(V log V) | ✅ Корректен |
| BFS (кратчайший путь) | `HexPathfinding.bfs_path` | O(V + E) | ✅ |
| BFS-достижимость | `HexPathfinding.bfs_reachable` | O(V + E) | ✅ |
| Дейкстра | `HexPathfinding.dijkstra` | O(V log V) | ✅ |
| MinHeap (бинарная куча) | `MinHeap.gd` | O(log n) push/pop | ✅ |
| Cube-координаты для гексов | `HexUtils` | O(1) distance | ✅ |
| Ring traversal (оптимизирован) | `HexUtils.ring` | O(r) | ✅ Отмечен как «TASK_06» |
| Кластеризация зданий (BFS) | `ArenaClusterSystem._compute_clusters` | O(B) | ✅ |
| Autotiling (hex) | `HexAutotiler` | O(cells) | ✅ |
| Fog of War (disk fill) | `VisibilityMap._fill_disk` | O(r²) на источник | ⚠️ |
| Кэш достижимости в бою | `BattleState._reachable_cache` | O(1) hit | ✅ |

### 3.2. Найденные проблемы

#### A1. `VisibilityMap._fill_disk` — O(r²) вместо O(r) для гексов
```gdscript
# Текущее: перебор квадрата + проверка расстояния
for dy in range(-radius, radius + 1):
    for dx in range(-radius, radius + 1):
        var nb := Vector2i(center.x + dx, center.y + dy)
        if HexUtils.hex_distance(center, nb) <= radius:
            out[nb] = 1
```
Для `FOG_CITY_SIGHT = 4` это 81 итерация вместо ~37 реальных гексов.

**Альтернатива:** `HexUtils.ring()` + заполнение по кольцам → O(r).

#### A2. `EnemyTurnProcessor._dist_field` — кэш по `(x, y, mp*1000)`
```gdscript
var key := Vector3i(cell.x, cell.y, int(mp * 1000.0))
```
Если `mp` не кратно 0.001, возможны коллизии. На практике `mp = 5.0`, но хрупко.

#### A3. `BattleState._reachable_cache` инвалидация
Кэш очищается в `invalidate_board_cache()`, но вызывается **не всегда** после `do_move` (вызывается, но после `_unit_grid` мутации). Корректно, но порядок хрупок.

#### A4. `ArenaClusterSystem._compute_clusters` — пересчёт по хэшу
```gdscript
func _city_version(city: City) -> int:
    # O(B) хэш всех зданий при каждом вызове
```
Вызывается на каждый `clusters(city)`. При 100 зданиях — 700 операций на вызов. Допустимо, но можно кэшировать версию в `City`.

---

## 4. Рефакторинг

### R1. Декомпозиция `WorldController` — **Priority: HIGH**

**Что:** Разделить на `WorldBootstrap` (уже частично сделано), `WorldInputRouter`, `WorldSaveLoadService`, `WorldCameraManager`.

**Зачем:** `WorldController` содержит 15+ `@onready` и 20+ методов. Невозможно тестировать изолированно.

**До:**
```gdscript
# WorldController.gd — 300+ строк, всё в одном
class_name WorldController extends Node2D
var battle_coordinator, interaction_controller, resource_node_manager
var _hero, _map_gen, _camera, _cities, _rng, _world_delta, _persistence
var _visibility, _resource_chain, _event_router, _bootstrap_result
var _succession, _hero_lifecycle
func _ready(): # 80 строк инициализации
    ...
```

**После:**
```gdscript
# WorldController.gd — тонкий оркестратор
class_name WorldController extends Node2D
var _bootstrap: WorldBootstrap
var _save_service: WorldSaveLoadService
var _input_router: WorldInputRouter

func _ready() -> void:
    _bootstrap = WorldBootstrap.new()
    _bootstrap.run(self, _Platform, _rng)
    _save_service = WorldSaveLoadService.new(_bootstrap.persistence)
    _input_router = WorldInputRouter.new(_bootstrap)
```

---

### R2. Завершить декомпозицию `City` — **Priority: HIGH**

**Что:** Вынести из `City` кэши доходности и логику размещения в отдельные сервисы.

**До:**
```gdscript
# City.gd
var _yield_cache: Dictionary = {}
var _yield_cache_dirty: bool = true
func get_yield() -> Dictionary:
    if not _yield_cache_dirty:
        return _yield_cache.duplicate()
    # 20 строк логики
```

**После:**
```gdscript
# CityYieldCalculator.gd
class_name CityYieldCalculator extends RefCounted
var _cache: Dictionary = {}
var _dirty := true
func calculate(city: City, tile_yield_fn: Callable) -> Dictionary:
    if not _dirty:
        return _cache.duplicate()
    # логика
func invalidate() -> void:
    _dirty = true
```

---

### R3. Убрать статическое мутабельное состояние из `HexUtils` — **Priority: HIGH**

**До:**
```gdscript
static var _config: HexGridConfig = null
static var _shift_right: bool = true
static func calibrate(tm: TileMapLayer) -> void:
    _shift_right = get_config().odd_row_shift_right
```

**После:**
```gdscript
# Передавать конфиг через параметры или инжектить
class_name HexUtils extends RefCounted
static func get_neighbor(cell: Vector2i, bit: int, shift_right: bool = true) -> Vector2i:
    var odd := (cell.y & 1) == 1
    if shift_right:
        return cell + (T_ODD_RIGHT[bit] if odd else T_EVEN_RIGHT[bit])
    return cell + (T_EVEN_RIGHT[bit] if odd else T_ODD_RIGHT[bit])
```

> **Компромисс:** Если менять сигнатуры во всех вызовах дорого — оставить статический, но добавить `HexUtils.reset()` и вызывать в `ServiceLocator.clear_cache()`.

---

### R4. `SpellCaster` — убрать `match` по `spell_id` — **Priority: MEDIUM**

**До:**
```gdscript
elif spell_id == &"cure":
    target_unit.clear_debuffs()
    result.heal = sp * 10
elif spell_id == &"slow_mass":
    target_unit.add_status(_SE.Effect.SLOW, 4)
elif spell_id == &"resurrection":
    # 6 строк
```

**После:**
```gdscript
# SpellRegistry уже хранит `buff_effect` и `damage_multiplier`.
# Расширить: добавить `custom_handler: Callable` в SpellDef.
class SpellDef:
    var custom_handler: Callable = Callable()

# В SpellCaster:
if spell.custom_handler.is_valid():
    result = spell.custom_handler.call(target_unit, sp, rng)
```

---

### R5. `VisibilityMap._fill_disk` → гекс-кольца — **Priority: MEDIUM**

**До:**
```gdscript
func _fill_disk(center, radius, out):
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if HexUtils.hex_distance(center, nb) <= radius:
                out[nb] = 1
```

**После:**
```gdscript
func _fill_disk(center: Vector2i, radius: int, out: Dictionary) -> void:
    out[center] = 1
    for r in range(1, radius + 1):
        for cell in HexUtils.ring(center, r):
            if is_in_bounds(cell):
                out[cell] = 1
```

---

### R6. Унифицировать тестовые фабрики — **Priority: LOW**

**До:** `_make_hero()`, `_make_city()` дублируются в 6 файлах.

**После:**
```gdscript
# tests/helpers/test_factories.gd — уже существует, расширить
static func make_hero(path := &"archivist") -> HeroController:
static func make_city(uid := 1, stronghold := 2) -> City:
static func make_battle_state(atk_key := "swordsmen", def_key := "goblins") -> BattleState:
```

---

### Сводная таблица правок

| # | Правка | Приоритет | Файлы | Риск |
|---|---|---|---|---|
| R1 | Декомпозиция `WorldController` | **High** | `WorldController.gd` + 3 новых | Высокий |
| R2 | Завершить декомпозицию `City` | **High** | `City.gd`, `CityYieldCalculator.gd` | Средний |
| R3 | Убрать static mutable из `HexUtils` | **High** | `HexUtils.gd` + все вызовы | Высокий |
| R4 | `SpellCaster` — убрать match | **Medium** | `SpellCaster.gd`, `SpellRegistry.gd` | Низкий |
| R5 | Fog of War → гекс-кольца | **Medium** | `VisibilityMap.gd` | Низкий |
| R6 | Унификация тестовых фабрик | **Low** | `tests/helpers/` | Минимальный |

---

## 5. Инструкция для локального агента

### Фаза 1: Подготовка (день 1)

```bash
# 1. Убедиться, что проект собирается
cd /Users/user/sigil-of-the-unwilling/game
godot --headless --export-release "Linux/X11" /dev/null 2>&1 | head -50

# 2. Прогнать существующие тесты
# (через GdUnit4 или встроенный тест-раннер)
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/

# 3. Зафиксировать текущее состояние (коммит / тег)
git tag pre-refactor-audit
```

**Критерий приёмки:** Все существующие тесты проходят.

### Фаза 2: R5 — Fog of War (день 1, низкий риск)

**Файл:** `scripts/core/VisibilityMap.gd`

1. Заменить `_fill_disk` на реализацию через `HexUtils.ring()`.
2. Заменить `_explore` аналогично.
3. Прогнать тесты `test_fog_of_war.gd`.

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/test_fog_of_war.gd
```

**Критерий:** Все 8 тестов `test_fog_of_war` проходят. `visible.size()` и `explored.size()` не изменились для `radius ≤ 4`.

### Фаза 3: R4 — SpellCaster (день 2)

**Файлы:** `scripts/systems/SpellCaster.gd`, `scripts/autoload/SpellRegistry.gd`

1. Добавить поле `custom_handler: Callable` в `SpellDef`.
2. В `SpellRegistry._reg()` для `cure`, `slow_mass`, `resurrection` назначить лямбды.
3. В `SpellCaster.cast()` заменить `elif` цепочку на `if spell.custom_handler.is_valid()`.
4. Прогнать:

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add tests/test_magic_resistance.gd \
  --add tests/test_spell_system.gd
```

**Критерий:** Все тесты магии проходят. `cast(&"resurrection", ...)` возвращает `revive_count`.

### Фаза 4: R6 — Тестовые фабрики (день 2)

**Файл:** `tests/helpers/test_factories.gd`

1. Добавить `make_hero()`, `make_battle_state()`, `make_city_with_temple()`.
2. Заменить дубликаты в `test_hero_survival.gd`, `test_legend_chronicle.gd`, `test_succession.gd`.
3. Прогнать все тесты.

### Фаза 5: R2 — City декомпозиция (день 3–4)

**Файлы:** `City.gd`, новый `CityYieldCalculator.gd`, `City.gd`

1. Создать `scripts/city/CityYieldCalculator.gd`.
2. Перенести `_yield_cache`, `_yield_cache_dirty`, `get_yield()`, `_invalidate_exploited()`.
3. В `City` оставить делегирование:
```gdscript
var _yield_calc := CityYieldCalculator.new()
func get_yield() -> Dictionary:
    return _yield_calc.calculate(self, tile_yield_fn)
```
4. Обновить `CitySerializer.serialize/deserialize` если кэш сериализовался.
5. Прогнать:

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add tests/test_city_model.gd \
  --add tests/test_city_chains.gd \
  --add tests/test_city_processor.gd \
  --add tests/test_city_yield_table.gd
```

**Критерий:** Все 50+ городских тестов проходят. `city.get_yield()` возвращает те же значения.

### Фаза 6: R3 — HexUtils (день 5, высокий риск)

**Файл:** `scripts/core/HexUtils.gd` + все файлы, вызывающие `get_neighbor`, `ring`, `hex_distance`.

**Стратегия (безопасная):**
1. Добавить `static func reset() -> void` для сброса `_config` и `_shift_right`.
2. Вызывать `HexUtils.reset()` в `ServiceLocator.clear_cache()` и `MainMenu._clear_session_caches()`.
3. Не менять сигнатуры — только добавить возможность сброса.

```gdscript
static func reset() -> void:
    _config = null
    _shift_right = true  # default
```

**Критерий:** Все тесты `test_hex_utils.gd`, `test_hex_pathfinding.gd` проходят. Повторная калибровка после `reset()` даёт тот же результат.

### Фаза 7: R1 — WorldController (день 6–8, самый высокий риск)

**Стратегия: инкрементальная, без big-bang.**

1. Выделить `WorldSaveLoadService`:
   - Перенести `save_game()`, `load_game()`, `apply_save()`, `get_last_save_dict()` из `WorldController`.
   - `WorldController.save_game()` → делегирование.

2. Выделить `WorldHeroManager`:
   - Перенести `_finit_hero`, `_install_hero`, `_remove_hero`, `_detach_hero`.

3. Прогнать **все** тесты + ручную проверку:
   - Новая игра → сохранение → загрузка → бой → конец хода.

```bash
# Полный прогон
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/
```

**Критерий приёмки финальный:**
- [ ] Все существующие тесты проходят (0 failures).
- [ ] `WorldController.gd` < 150 строк.
- [ ] Ручной сценарий: новая игра → бой → сохранение → загрузка → смерть героя → сукцессия — без ошибок.

---

### Матрица рисков

| Фаза | Риск | Откат |
|---|---|---|
| 2 (Fog) | Низкий | `git revert` одного коммита |
| 3 (Spell) | Низкий | `git revert` |
| 4 (Тесты) | Минимальный | `git revert` |
| 5 (City) | Средний | Ветвление, откат до тега |
| 6 (Hex) | Средний | Тег `pre-refactor-audit` |
| 7 (World) | **Высокий** | Ветвление + ежедневные коммиты |

---

### Общие рекомендации (не вошли в фазы)

1. **Добавить `typed` аннотации** для всех публичных методов: `func foo(x: int) -> Dictionary:`.
2. **Заменить `get_node_or_null` цепочки** в UI на `@onready` с `as Type`.
3. **`GameEventBus`** — рассмотреть типизированные сигналы через `class Signal` или замену на `EventAggregator` с методом `emit(event: GameEvent)`.
4. **Убрать `extends Node`** для `HeroResources`, `HeroMagic`, `HeroNeeds` → `RefCounted`. Они не используют узловую функциональность.
5. **`PlaceholderTexture._cache`** — статический словарь без ограничения размера. Добавить `LRU` или очистку по `ServiceLocator.clear_cache()`.

# Исправленный код

## 1. `VisibilityMap.gd` — O(r²) → O(r)

```gdscript
# res://scripts/core/visibility_map.gd
extends RefCounted
class_name VisibilityMap

var visible: Dictionary = {}
var explored: Dictionary = {}
var _map_width: int = 0
var _map_height: int = 0

func set_map_size(width: int, height: int) -> void:
	_map_width = width
	_map_height = height

func recompute(hero_cell: Vector2i, sight_sources: Array, hero_sight: int, city_sight: int) -> bool:
	var new_visible: Dictionary = {}
	if hero_cell is Vector2i and is_in_bounds(hero_cell):
		_fill_disk(hero_cell, hero_sight, new_visible)
		_explore(hero_cell, hero_sight)
	for src in sight_sources:
		if src is Vector2i and is_in_bounds(src) and src != hero_cell:
			_fill_disk(src, city_sight, new_visible)
			_explore(src, city_sight)
	var changed := visible.size() != new_visible.size()
	if not changed:
		for c in new_visible:
			if not visible.has(c):
				changed = true
				break
	visible = new_visible
	return changed

## O(r) вместо O(r²): обход по гекс-кольцам через HexUtils.ring().
## Для radius=4: 37 итераций вместо 81.
func _fill_disk(center: Vector2i, radius: int, out: Dictionary) -> void:
	if radius < 0:
		return
	if is_in_bounds(center):
		out[center] = 1
	for r in range(1, radius + 1):
		for cell in HexUtils.ring(center, r):
			if is_in_bounds(cell):
				out[cell] = 1

## Аналогично для explored — O(r).
func _explore(center: Vector2i, radius: int) -> void:
	if radius < 0:
		return
	if is_in_bounds(center):
		explored[center] = 1
	for r in range(1, radius + 1):
		for cell in HexUtils.ring(center, r):
			if is_in_bounds(cell):
				explored[cell] = 1

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _map_width and cell.y >= 0 and cell.y < _map_height

func is_visible(cell: Vector2i) -> bool:
	return visible.has(cell)

func is_explored(cell: Vector2i) -> bool:
	return explored.has(cell)

func serialize_explored() -> Array:
	var arr: Array = []
	for cell in explored:
		arr.append({"x": cell.x, "y": cell.y})
	return arr

func load_explored(arr: Array) -> void:
	for item in arr:
		var cell := Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))
		if is_in_bounds(cell):
			explored[cell] = 1
```

---

## 2. `BattleState.gd` — чистый контейнер состояния

```gdscript
# res://scripts/systems/battle_state.gd
class_name BattleState
extends RefCounted

## Чистый контейнер состояния боя.
## Вся логика размещения — в BattleStateBuilder.
## Вся логика атаки/заклинаний — в BattleActionResolver.
## Вся логика урона — в BattleDamageResolver.

const _StatusEffects = preload("res://scripts/data/status_effects.gd")
const BattleActionResolver = preload("res://scripts/systems/battle_action_resolver.gd")

var attacker_units: Array[BattleUnit] = []
var defender_units: Array[BattleUnit] = []
var active_unit: BattleUnit = null
var turn_queue: Array[BattleUnit] = []
var turn_idx := 0
var is_player_turn := true
var battle_over := false

enum Side { NONE, ATTACKER, DEFENDER }
var battle_winner: BattleState.Side = Side.NONE

var attacker_hero_bonus: Dictionary[StringName, int] = {
	&"attack": 0, &"defense": 0, &"spell_power": 0, &"knowledge": 0,
}
var defender_hero_bonus: Dictionary[StringName, int] = {
	&"attack": 0, &"defense": 0, &"spell_power": 0, &"knowledge": 0,
}

var _reachable_cache: Dictionary = {}
var _board_version: int = 0
var _uid := 0
var _unit_grid: Dictionary = {}
var _attacker_alive_count := 0
var _defender_alive_count := 0

const BW := 17
const BH := 11

class BattleUnit extends RefCounted:
	var stack: UnitStack
	var cell := Vector2i(-1, -1)
	var side: BattleState.Side = Side.ATTACKER
	var alive := true
	var has_moved := false
	var defending := false
	var has_retaliated := false
	var uid := 0
	var statuses: Dictionary = {}
	var max_count: int = 0
	var distance_moved_this_turn: int = 0
	var already_reborn: bool = false

	func _init(p_stack = null) -> void:
		stack = p_stack

	func is_alive() -> bool:
		return alive and stack != null and stack.is_alive()

	func get_key() -> String:
		return stack.get_key() if stack != null else ""

	func get_display_name() -> String:
		return stack.get_display_name() if stack != null else ""

	func get_count() -> int:
		return stack.count if stack != null else 0

	func set_count(value: int) -> void:
		if stack == null:
			alive = false
			return
		stack.count = max(0, value)

	var stats: UnitStats:
		get: return stack.stats if stack != null and stack.stats != null else null

	func get_speed() -> int:
		return stats.speed if stats != null else 0

	func get_base_damage() -> int:
		return stats.base_damage if stats != null else 0

	func get_hp() -> int:
		return stats.hp if stats != null else 1

	func get_defense() -> int:
		return stats.defense if stats != null else 0

	func get_attack() -> int:
		return stats.attack if stats != null else 0

	func has_tag(tag: String) -> bool:
		if stack == null or stack.stats == null:
			return false
		return stack.stats.has_tag(tag)

	func is_ranged() -> bool:
		return has_tag("ranged")

	func is_flying() -> bool:
		return has_tag("flying")

	func is_no_retaliation() -> bool:
		return has_tag("no_retaliation")

	func is_double_strike() -> bool:
		return has_tag("double_strike")

	func has_morale() -> bool:
		return has_tag("morale")

	func is_defending() -> bool:
		return defending

	func do_defend() -> void:
		defending = true

	func add_status(effect: int, duration: int) -> void:
		statuses[effect] = max(statuses.get(effect, 0), duration)

	func clear_debuffs() -> void:
		var to_remove: Array = []
		for eff in statuses.keys():
			if _StatusEffects.is_debuff(eff):
				to_remove.append(eff)
		for eff in to_remove:
			statuses.erase(eff)

	func is_stunned() -> bool:
		for eff in statuses.keys():
			if _StatusEffects.is_stun(eff):
				return true
		return false

## Размещение делегируется в BattleStateBuilder.
func place_army(
	attacker_stacks: Array[UnitStack],
	defender_stacks: Array[UnitStack],
	attacker_artifact_mods: Dictionary = {},
	defender_artifact_mods: Dictionary = {}
) -> void:
	var builder := BattleStateBuilder.new()
	builder.set_attacker_army(attacker_stacks)
	builder.set_defender_army(defender_stacks)
	builder.set_attacker_artifact_mods(attacker_artifact_mods)
	builder.set_defender_artifact_mods(defender_artifact_mods)
	builder.build_into(self)

func kill_unit(unit: BattleUnit) -> void:
	if not unit.alive:
		return
	unit.alive = false
	unit.set_count(0)
	if unit.side == Side.ATTACKER:
		_attacker_alive_count -= 1
	else:
		_defender_alive_count -= 1
	_unit_grid.get(unit.side, {}).erase(unit.cell)
	invalidate_board_cache()
	check_end()

func revive_unit(unit: BattleUnit) -> void:
	if unit == null:
		return
	if not unit.alive:
		unit.alive = true
		if unit.get_count() <= 0:
			unit.set_count(unit.max_count)
		if unit.side == Side.ATTACKER:
			_attacker_alive_count += 1
		else:
			_defender_alive_count += 1
		_unit_grid.get(unit.side, {})[unit.cell] = unit
	invalidate_board_cache()

func build_queue() -> void:
	turn_queue.clear()
	for u in attacker_units:
		if u.is_alive():
			turn_queue.append(u)
	for u in defender_units:
		if u.is_alive():
			turn_queue.append(u)
	turn_queue.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.get_speed() != b.get_speed():
			return a.get_speed() > b.get_speed()
		if a.get_hp() != b.get_hp():
			return a.get_hp() > b.get_hp()
		if a.side != b.side:
			return a.side == Side.ATTACKER
		return a.uid < b.uid
	)
	turn_idx = -1

func advance_turn() -> void:
	turn_idx += 1
	_normalize_active_unit()

func _normalize_active_unit() -> void:
	while turn_idx < turn_queue.size():
		var u: BattleUnit = turn_queue[turn_idx]
		if u.is_alive():
			break
		turn_idx += 1
	if turn_idx >= turn_queue.size():
		start_new_round()
		return
	active_unit = turn_queue[turn_idx]
	is_player_turn = (active_unit.side == Side.ATTACKER)

func start_new_round() -> void:
	for u in attacker_units:
		if u.is_alive():
			u.has_moved = false
			u.defending = false
			u.distance_moved_this_turn = 0
			u.already_reborn = false
	for u in defender_units:
		if u.is_alive():
			u.has_moved = false
			u.defending = false
			u.distance_moved_this_turn = 0
			u.already_reborn = false
	build_queue()
	if turn_queue.is_empty():
		check_end()
		if not battle_over:
			force_end(Side.DEFENDER)
		return
	turn_idx = 0
	active_unit = turn_queue[0]
	is_player_turn = (active_unit.side == Side.ATTACKER)

func get_turn_info() -> String:
	if active_unit == null:
		return ""
	var side_txt := GameText.battle_your_turn() if is_player_turn else GameText.battle_enemy_turn()
	return GameText.battle_turn_info(side_txt, active_unit.get_display_name(), active_unit.get_count())

func get_unit_at(cell: Vector2i, side: BattleState.Side) -> BattleUnit:
	if not _unit_grid.has(side):
		return null
	var u = _unit_grid[side].get(cell, null)
	return u if (u != null and u.is_alive()) else null

func rebuild_unit_grid() -> void:
	_unit_grid = {Side.ATTACKER: {}, Side.DEFENDER: {}}
	for u in attacker_units:
		if u.is_alive():
			_unit_grid[Side.ATTACKER][u.cell] = u
	for u in defender_units:
		if u.is_alive():
			_unit_grid[Side.DEFENDER][u.cell] = u

func get_units_by_side(side: BattleState.Side) -> Array[BattleUnit]:
	return attacker_units if side == Side.ATTACKER else defender_units

func get_reachable_for_unit(unit: BattleUnit, blocked_fn: Callable) -> Dictionary:
	if unit == null:
		return {}
	if unit.is_flying():
		var blocked: Dictionary = blocked_fn.call()
		var result: Dictionary = {}
		for y in BH:
			for x in BW:
				var c := Vector2i(x, y)
				if c == unit.cell:
					continue
				if blocked.has(c):
					continue
				var dist: int = HexUtils.hex_distance(unit.cell, c)
				if dist <= unit.get_speed():
					result[c] = dist
		return result
	return get_reachable(unit.cell, unit.get_speed(), blocked_fn, unit)

func get_reachable(cell: Vector2i, speed: int, blocked_fn: Callable, _unit: BattleUnit = null) -> Dictionary:
	var speed_cache: Dictionary = _reachable_cache.get(cell, {})
	if speed_cache.has(speed):
		return speed_cache[speed].duplicate()
	var blocked: Dictionary = blocked_fn.call()
	var reachable := HexPathfinding.bfs_reachable(cell, speed, blocked, BW, BH)
	if not _reachable_cache.has(cell):
		_reachable_cache[cell] = {}
	_reachable_cache[cell][speed] = reachable
	return reachable.duplicate()

func get_unreachable_ring(unit: BattleUnit, blocked_fn: Callable) -> Dictionary:
	if unit == null:
		return {}
	if unit.is_flying():
		var blocked: Dictionary = blocked_fn.call()
		var speed := unit.get_speed()
		var ring: Dictionary = {}
		for y in BH:
			for x in BW:
				var c := Vector2i(x, y)
				if c == unit.cell or blocked.has(c):
					continue
				if HexUtils.hex_distance(unit.cell, c) == speed + 1:
					ring[c] = HexUtils.hex_distance(unit.cell, c)
		return ring
	var near: Dictionary = get_reachable(unit.cell, unit.get_speed() + 1, blocked_fn, unit)
	var reach: Dictionary = get_reachable(unit.cell, unit.get_speed(), blocked_fn, unit)
	var ring: Dictionary = {}
	for c in near:
		if not reach.has(c):
			ring[c] = near[c]
	return ring

func invalidate_board_cache() -> void:
	_board_version += 1
	_reachable_cache.clear()

func build_all_blocked(except_unit: BattleUnit, obstacles: Dictionary) -> Dictionary:
	var b: Dictionary = {}
	for u in attacker_units:
		if u != except_unit and u.is_alive():
			b[u.cell] = true
	for u in defender_units:
		if u != except_unit and u.is_alive():
			b[u.cell] = true
	for o in obstacles:
		b[o] = true
	return b

func apply_attack(
	atk: BattleUnit, def: BattleUnit,
	is_melee_attack: bool, rng: RandomNumberGenerator,
	consume_action: bool = true
) -> Dictionary:
	return BattleActionResolver.apply_attack(self, atk, def, is_melee_attack, rng, consume_action)

func apply_spell(
	spell_id: StringName, caster: BattleUnit, target: BattleUnit,
	caster_hero_bonus: Dictionary, target_hero_bonus: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	return BattleActionResolver.apply_spell(
		self, spell_id, caster, target, caster_hero_bonus, target_hero_bonus, rng)

func apply_sacrifice(
	sacrifice: Dictionary, acting: BattleUnit,
	target: BattleUnit, cost: Variant, rng: RandomNumberGenerator
) -> Dictionary:
	return BattleActionResolver.apply_sacrifice(self, acting, sacrifice, target, cost, rng)

func do_move(unit: BattleUnit, target: Vector2i) -> void:
	var dist := HexUtils.hex_distance(unit.cell, target)
	unit.distance_moved_this_turn += dist
	var old_cell := unit.cell
	unit.cell = target
	unit.has_moved = true
	var side_grid: Dictionary = _unit_grid.get(unit.side, {})
	side_grid.erase(old_cell)
	side_grid[target] = unit
	invalidate_board_cache()

func do_defend(unit: BattleUnit) -> void:
	unit.has_moved = true
	unit.defending = true
	invalidate_board_cache()

func do_wait(unit: BattleUnit) -> void:
	if unit == null:
		return
	var idx := turn_queue.find(unit)
	if idx < 0:
		return
	var old_size := turn_queue.size()
	turn_queue.remove_at(idx)
	turn_queue.append(unit)
	if idx == old_size - 1:
		turn_idx = idx
	else:
		turn_idx = idx - 1
	invalidate_board_cache()

func do_skip(unit: BattleUnit) -> void:
	if unit != null:
		unit.has_moved = true
	invalidate_board_cache()

func force_end(winner: BattleState.Side) -> void:
	battle_over = true
	battle_winner = winner

func check_end() -> BattleState.Side:
	if battle_over:
		return battle_winner
	if _attacker_alive_count == 0:
		force_end(Side.DEFENDER)
	elif _defender_alive_count == 0:
		force_end(Side.ATTACKER)
	return battle_winner

func get_survivors(side: BattleState.Side) -> Array[UnitStack]:
	var r: Array[UnitStack] = []
	var units := attacker_units if side == Side.ATTACKER else defender_units
	for u in units:
		if u.is_alive():
			r.append(u.stack)
	return r

func get_retreat_survivors(side: BattleState.Side) -> Array[UnitStack]:
	var all_survivors: Array[UnitStack] = []
	var units := get_units_by_side(side)
	for u in units:
		if u.is_alive():
			var stack: UnitStack = u.stack.duplicate_stack()
			stack.count = max(1, int(ceil(float(stack.count) * GameNumbers.RETREAT_SURVIVAL_RATIO)))
			all_survivors.append(stack)
	all_survivors.sort_custom(func(a: UnitStack, b: UnitStack): return a.count > b.count)
	var result: Array[UnitStack] = []
	for i in min(GameNumbers.RETREAT_STACK_LIMIT, all_survivors.size()):
		result.append(all_survivors[i])
	return result

func set_hero_bonuses(attacker_bonus: Dictionary, defender_bonus: Dictionary) -> void:
	attacker_hero_bonus = _normalize_hero_bonus(attacker_bonus)
	defender_hero_bonus = _normalize_hero_bonus(defender_bonus)

func _normalize_hero_bonus(bonus: Dictionary) -> Dictionary[StringName, int]:
	return {
		&"attack": int(bonus.get(&"attack", bonus.get("attack", 0))),
		&"defense": int(bonus.get(&"defense", bonus.get("defense", 0))),
		&"spell_power": int(bonus.get(&"spell_power", bonus.get("spell_power", 0))),
		&"knowledge": int(bonus.get(&"knowledge", bonus.get("knowledge", 0))),
	}
```

---

## 3. `WorldSaveLoadService.gd` — извлечение из WorldController

```gdscript
# res://scripts/world/world_save_load_service.gd
class_name WorldSaveLoadService
extends RefCounted

## Вынесено из WorldController: вся логика сохранения/загрузки.
## WorldController делегирует сюда.

var _persistence: WorldPersistence
var _world_delta: WorldStateDelta

func _init(persistence: WorldPersistence, world_delta: WorldStateDelta) -> void:
	_persistence = persistence
	_world_delta = world_delta

func save_game(hero: HeroController, cities: Array, characters: Array = []) -> bool:
	_persistence.world_delta = _world_delta
	return _persistence.save_game(hero, cities, characters)

func load_game() -> SaveData:
	return _persistence.load_game()

func get_last_save_dict() -> Dictionary:
	return _persistence.last_save_dict()

func request_load_game() -> void:
	var data = _persistence.request_load_game()
	if data != null:
		Engine.get_main_loop().call_deferred("reload_current_scene")

func restart_game(seed_value: int) -> void:
	_persistence.restart_game(seed_value)
	Engine.get_main_loop().call_deferred("reload_current_scene")

func apply_save(data: SaveData, ctx: WorldLoadContext) -> void:
	_persistence.apply_loaded_save(data, ctx)

func get_session() -> GameSession:
	return _persistence.session

func is_terminal() -> bool:
	var s := get_session()
	return s != null and s.is_terminal()

func get_endgame_state() -> Dictionary:
	var s := get_session()
	if s == null:
		return {"state": "RUNNING", "end_reason": ""}
	var names := {
		GameSession.GameState.RUNNING: "RUNNING",
		GameSession.GameState.VICTORY: "VICTORY",
		GameSession.GameState.DEFEAT: "DEFEAT",
	}
	return {"state": names.get(s.state, "RUNNING"), "end_reason": s.end_reason}
```

---

## 4. `WorldController.gd` — тонкий оркестратор

```gdscript
# res://scripts/world/world_controller.gd
class_name WorldController
extends Node2D

## Тонкий оркестратор. Вся тяжёлая логика вынесена в сервисы:
## - WorldBootstrap — инициализация
## - WorldSaveLoadService — сохранение/загрузка
## - WorldEventRouter — события
## - HeroLifecycleSystem — смерть/сукцессия
## - EndgameController — победа/поражение

const _Platform = preload("res://scripts/core/platform.gd")

var battle_coordinator: Node = null
var interaction_controller: Node = null
var resource_node_manager: Node = null

var _hero: Node = null
var _map_gen: MapGenerator = null
var _camera: Camera2D = null
var _cities: CityManager = null
var _rng: RandomNumberGenerator = null
var _world_delta: WorldStateDelta = null
var _persistence = null
var _visibility = null
var _resource_chain = null
var _event_router: WorldEventRouter = null
var _bootstrap_result = null
var _succession = null
var _hero_lifecycle = null
var _save_service: WorldSaveLoadService = null

@onready var _ui_manager: WorldUIManager = $WorldUI

func _ready() -> void:
	SoundManager.play_music_cue(&"music_world")
	_rng = RandomNumberGenerator.new()
	var _shard := ShardManagerScript.instance().get_active()
	_bootstrap_result = WorldBootstrap.run(self, _Platform, _rng, _shard.seed, _ui_manager)
	_map_gen = _bootstrap_result.map_gen
	_hero = _bootstrap_result.hero
	_camera = _bootstrap_result.camera
	_cities = _bootstrap_result.cities
	battle_coordinator = _bootstrap_result.battle_coordinator
	interaction_controller = _bootstrap_result.interaction_controller
	resource_node_manager = _bootstrap_result.resource_node_manager
	_world_delta = _bootstrap_result.world_delta
	_persistence = _bootstrap_result.persistence
	_resource_chain = _bootstrap_result.resource_chain
	_visibility = _VisibilityMapScript.new()
	_visibility.set_map_size(_map_gen.map_width, _map_gen.map_height)
	_map_gen.visibility = _visibility
	if _map_gen.renderer != null:
		_map_gen.renderer.fog_refreshed.connect(_on_fog_refreshed)
	_save_service = WorldSaveLoadService.new(_persistence, _world_delta)
	var loaded_save := _bootstrap_result.loaded_save
	await get_tree().process_frame
	_finit_hero(loaded_save)
	_camera.set_map_rect(_bootstrap_result.map_rect)
	_finit_subsystems()
	_persistence.world_delta = _world_delta
	_event_router = WorldEventRouter.new()
	_event_router.name = "EventRouter"
	add_child(_event_router)
	_event_router.setup(
		_hero, _map_gen, _camera, _cities,
		battle_coordinator, interaction_controller,
		resource_node_manager, _ui_manager,
		_world_delta, _persistence, _resource_chain,
		_visibility,
		ServiceLocator.resolve(null, &"resources"),
		_bootstrap_result.turn_scheduler,
		_bootstrap_result.terrain_resource_manager if _bootstrap_result != null else null
	)
	_event_router.end_turn_requested.connect(_on_end_turn_from_router)
	_succession = SuccessionController.new()
	_hero_lifecycle = HeroLifecycleSystemScript.new()
	_hero_lifecycle.setup(
		self, _persistence, _rng, _cities, _map_gen, _event_router,
		_ui_manager, battle_coordinator, interaction_controller,
		_bootstrap_result, _succession, _camera)
	if loaded_save != null:
		_persistence.apply_loaded_save(loaded_save, _build_load_context())
	if _bootstrap_result.endgame != null:
		_bootstrap_result.endgame.restore()
	else:
		if _map_gen.has_valid_tilemap():
			_map_gen.apply_fog(_visibility)
	GameLogger.world("Scene ready, seed=%d" % _persistence.session.run_seed)
	_handle_headless_exit()

func _finit_hero(loaded_save: SaveData) -> void:
	_hero.setup(_map_gen)
	if loaded_save != null:
		_hero.deserialize(loaded_save.hero)
	if _map_gen.has_valid_tilemap():
		_hero.position = _map_gen.map_to_local(_hero.current_cell)

func _finit_subsystems() -> void:
	battle_coordinator.setup(
		_hero, _map_gen, _bootstrap_result.spawner, _rng,
		self, _ui_manager, _camera, _bootstrap_result.input_controller, _world_delta
	)
	var chest_dialog: ArtifactChestDialog = _ui_manager.chest_dialog if _ui_manager != null else null
	interaction_controller.setup(_hero, _bootstrap_result.spawner, chest_dialog)
	interaction_controller.connect_chest_signals()
	interaction_controller.world_delta = _world_delta
	interaction_controller.visibility = _visibility
	interaction_controller.status_cb = (
		_ui_manager.set_status if _ui_manager != null and _ui_manager.has_method("set_status") else Callable())
	_persistence.visibility = _visibility
	var sight_sources: Array = []
	if _cities != null:
		for c in _cities.cities:
			if c != null and c.owner == &"player" and c.center is Vector2i:
				sight_sources.append(c.center)
	_visibility.recompute(_hero.current_cell, sight_sources,
		GameNumbers.FOG_HERO_SIGHT, GameNumbers.FOG_CITY_SIGHT)
	if _map_gen.has_valid_tilemap():
		_map_gen.apply_fog(_visibility)

func _on_fog_refreshed() -> void:
	if _bootstrap_result != null and _bootstrap_result.spawner != null:
		_bootstrap_result.spawner.apply_fog_visibility(_visibility)
	if resource_node_manager != null and resource_node_manager.has_method("apply_fog_visibility"):
		resource_node_manager.apply_fog_visibility(_visibility)

func get_fog():
	return _visibility

func _on_end_turn_from_router() -> void:
	pass

func _on_hero_died(cause: StringName) -> void:
	if _hero_lifecycle == null:
		return
	_hero_lifecycle.on_hero_died(cause)

func is_death_sequence_open() -> bool:
	if _hero_lifecycle == null:
		return false
	return _hero_lifecycle.is_death_sequence_open()

func _plan_succession(deceased: HeroController) -> HeroController:
	if _hero_lifecycle == null:
		return null
	return _hero_lifecycle._plan_succession(deceased)

func _find_resurrection_city(deceased: HeroController) -> City:
	if _hero_lifecycle == null:
		return null
	return _hero_lifecycle._find_resurrection_city(deceased)

func _on_resurrection_chosen() -> void:
	if _hero_lifecycle != null:
		_hero_lifecycle._on_resurrection_chosen()

func _execute_succession() -> void:
	if _hero_lifecycle != null:
		_hero_lifecycle._execute_succession()

func get_camera() -> Camera2D:
	return _camera

func center_camera_on(cell: Vector2i) -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		_camera.center_on(_map_gen.map_to_local(cell))

func get_session() -> GameSession:
	return _save_service.get_session()

func get_hero() -> HeroController:
	return _hero

func set_hero(hero: HeroController) -> void:
	_hero = hero

func get_map_gen() -> MapGenerator:
	return _map_gen

func get_cities() -> CityManager:
	return _cities

func get_ui_manager() -> WorldUIManager:
	return _ui_manager

func is_world_visible() -> bool:
	if _Platform.is_headless():
		return true
	return visible

func do_end_turn() -> void:
	if _save_service.is_terminal():
		return
	if _event_router:
		_event_router.request_end_turn()

func is_terminal() -> bool:
	return _save_service.is_terminal()

func get_endgame_state() -> Dictionary:
	return _save_service.get_endgame_state()

## Делегирование в WorldSaveLoadService
func save_game() -> bool:
	var chars: Array = []
	if _bootstrap_result != null and _bootstrap_result.character_registry != null:
		chars = _bootstrap_result.character_registry.serialize()
	return _save_service.save_game(_hero, _cities.cities, chars)

func load_game() -> SaveData:
	return _save_service.load_game()

func get_last_save_dict() -> Dictionary:
	return _save_service.get_last_save_dict()

func request_load_game() -> void:
	_save_service.request_load_game()

func restart_game(seed_value: int) -> void:
	_save_service.restart_game(seed_value)

func apply_save(data: SaveData) -> void:
	_save_service.apply_save(data, _build_load_context())

func _build_load_context():
	var ctx := WorldLoadContext.new()
	ctx.map_gen = _map_gen
	ctx.spawner = _bootstrap_result.spawner
	ctx.resource_node_manager = resource_node_manager
	if _bootstrap_result != null:
		ctx.terrain_resource_manager = _bootstrap_result.terrain_resource_manager
	ctx.ui_manager = _ui_manager
	ctx.camera = _camera
	ctx.hero = _hero
	ctx.world_delta = _world_delta
	ctx.cities = _cities
	if _bootstrap_result != null:
		ctx.character_registry = _bootstrap_result.character_registry
	return ctx

func try_extract_resource(cell: Vector2i) -> Dictionary:
	return _resource_chain.try_extract(resource_node_manager, _hero, cell)

func show_reach_markers(hero_cell: Vector2i, mp: float, dist: Dictionary) -> void:
	if _ui_manager:
		_ui_manager.show_reach_markers(hero_cell, mp, dist)

func hide_reach_markers() -> void:
	if _ui_manager:
		_ui_manager.hide_reach_markers()

func _handle_headless_exit() -> void:
	if (_Platform.is_headless() or _Platform.should_auto_quit()) and not _Platform.is_test_framework_run():
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()
```

---

## 5. `UIBinding.gd` — отвязка UI от сцен

```gdscript
# res://scripts/ui/UIBinding.gd
class_name UIBinding
extends RefCounted

## Утилита для безопасного получения узлов из сцены.
## Заменяет прямые $-ссылки и get_node_or_null цепочки.
## Использование:
##   var binding := UIBinding.new($Panel)
##   var title: Label = binding.get_typed("Title", Label)
##   var btn: Button = binding.get_typed("Buttons/OK", Button)

var _root: Node

func _init(root: Node) -> void:
	_root = root

## Безопасно получить типизированный узел. Возвращает null если не найден или тип не совпадает.
func get_typed(path: String, expected_type: Variant = null) -> Variant:
	if _root == null:
		return null
	var node := _root.get_node_or_null(path)
	if node == null:
		return null
	if expected_type != null and not (node is expected_type):
		push_warning("UIBinding: '%s' is %s, expected %s" % [path, node.get_class(), str(expected_type)])
		return null
	return node

## Получить массив однотипных узлов по префиксу имени.
## Пример: get_typed_array("Slot", Panel, 8) -> [Slot0..Slot7]
func get_typed_array(prefix: String, expected_type: Variant, count: int) -> Array:
	var result: Array = []
	for i in count:
		var node = get_typed("%s%d" % [prefix, i], expected_type)
		result.append(node)
	return result

## Подключить сигнал если ещё не подключён.
func connect_safe(node: Node, signal_name: String, callable: Callable) -> bool:
	if node == null:
		return false
	if not node.has_signal(signal_name):
		return false
	if node.is_connected(signal_name, callable):
		return true
	node.connect(signal_name, callable)
	return true

## Локализовать кнопку/лейбл по маппингу.
func localize(node: Node, text: String) -> void:
	if node is Button:
		(node as Button).text = text
	elif node is Label:
		(node as Label).text = text
```

---

## 6. Пример использования `UIBinding` в `BattleUI.gd`

```gdscript
# res://scripts/ui/battle_ui.gd (фрагмент _connect_skeleton с UIBinding)
class_name BattleUI
extends CanvasLayer

signal retreat_requested
signal wait_requested
signal attack_mode_requested
signal skip_requested
signal defend_requested
signal spellbook_requested
signal spell_chosen(spell_id: StringName)
signal settings_requested
signal settings_closed

var _status: Label
var _active_info: Label
var _preview: Label
var _bottom_bar: HBoxContainer
var _initiative_list: ItemList
var _action_buttons: Array[Button] = []
var _attack_button: Button = null
var _binding: UIBinding

@onready var _settings_screen: SettingsScreen = $SettingsScreen
@onready var _spellbook_panel: BattleSpellbookPanel = $BattleSpellbookPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_binding = UIBinding.new(self)
	_connect_skeleton()
	if _status != null:
		_status.text = GameText.battle_select_unit()
	if not _spellbook_panel.spell_chosen.is_connected(_on_spellbook_chosen):
		_spellbook_panel.spell_chosen.connect(_on_spellbook_chosen)

func _connect_skeleton() -> void:
	_status = _binding.get_typed("top_panel/top_vbox/status", Label)
	_active_info = _binding.get_typed("top_panel/top_vbox/active_info", Label)
	_preview = _binding.get_typed("top_panel/top_vbox/preview", Label)
	_bottom_bar = _binding.get_typed("bottom_bar", HBoxContainer)
	_initiative_list = _binding.get_typed("initiative_panel/initiative_list", ItemList)
	if _status != null:
		_status.add_theme_color_override("font_color", ThemeConfig.C_TEXT_PRIMARY)
	if _active_info != null:
		_active_info.add_theme_color_override("font_color", ThemeConfig.C_ACTIVE_INFO)
	if _preview != null:
		_preview.add_theme_color_override("font_color", ThemeConfig.C_TEXT_GOLD)
	_action_buttons = []
	_connect_btn("retreat_btn", _on_retreat, true)
	_connect_btn("wait_btn", _on_wait, true)
	_connect_btn("attack_btn", _on_attack_mode, true)
	_connect_btn("defend_btn", _on_defend, true)
	_connect_btn("skip_btn", _on_skip, true)
	_connect_btn("spellbook_btn", _on_spellbook, true)
	_connect_btn("settings_btn", _on_settings, true)
	_attack_button = _binding.get_typed("bottom_bar/attack_btn", Button)
	if _attack_button != null:
		_attack_button.disabled = true

func _connect_btn(name: String, cb: Callable, is_action: bool) -> void:
	var btn := _binding.get_typed("bottom_bar/%s" % name, Button)
	if btn == null:
		return
	_binding.connect_safe(btn, "pressed", cb)
	if is_action:
		_action_buttons.append(btn)

func _on_spellbook_chosen(id: StringName) -> void:
	close_spellbook()
	spell_chosen.emit(id)

func set_status(text: String) -> void:
	if _status:
		_status.text = text

func set_attack_preview(text: String) -> void:
	if _preview:
		_preview.text = text

func update_active_unit(unit: BattleState.BattleUnit) -> void:
	if _active_info == null:
		return
	if unit == null or unit.stack == null or unit.stack.stats == null:
		_active_info.text = ""
		return
	var stats: UnitStats = unit.stack.stats
	_active_info.text = GameText.battle_unit_info(
		stats.display_name, unit.get_count(), stats.hp,
		stats.attack, stats.defense, stats.speed, ", ".join(stats.tags))

func update_initiative(units: Array[BattleState.BattleUnit], active_unit: BattleState.BattleUnit) -> void:
	if _initiative_list == null:
		return
	_initiative_list.clear()
	for unit in units:
		if unit == null:
			continue
		var text = GameText.battle_unit_short(unit.get_display_name().left(8), unit.get_count())
		var idx = _initiative_list.add_item(text)
		if unit == active_unit:
			_initiative_list.set_item_custom_fg_color(idx, Color.GOLD)
		elif unit.side == BattleState.Side.ATTACKER:
			_initiative_list.set_item_custom_fg_color(idx, ThemeConfig.C_INITIATIVE_YOUR)
		else:
			_initiative_list.set_item_custom_fg_color(idx, ThemeConfig.C_INITIATIVE_ENEMY)

func set_controls_enabled(enabled: bool) -> void:
	for btn in _action_buttons:
		if btn != null:
			btn.disabled = not enabled
	if _attack_button != null and not enabled:
		_attack_button.disabled = true

func set_attack_enabled(enabled: bool) -> void:
	if _attack_button != null:
		_attack_button.disabled = not enabled

func close_spellbook() -> void:
	if _spellbook_panel != null:
		_spellbook_panel.visible = false

func open_spellbook(_state: BattleState, magic: HeroMagic = null) -> void:
	if _spellbook_panel == null:
		return
	if magic != null:
		_spellbook_panel.setup(null, magic, null)
	_spellbook_panel.visible = true

func open_settings() -> void:
	_binding.connect_safe(_settings_screen, "applied", _on_settings_applied)
	_binding.connect_safe(_settings_screen, "closed", _on_settings_closed)
	_settings_screen.setup(get_node_or_null("/root/Settings"))
	_settings_screen.show()

func _on_retreat() -> void: retreat_requested.emit()
func _on_wait() -> void: wait_requested.emit()
func _on_attack_mode() -> void: attack_mode_requested.emit()
func _on_defend() -> void: defend_requested.emit()
func _on_skip() -> void: skip_requested.emit()
func _on_spellbook() -> void: spellbook_requested.emit()
func _on_settings() -> void: settings_requested.emit()
func _on_settings_applied() -> void: pass
func _on_settings_closed() -> void: settings_closed.emit()
```

---

## Сводка изменений

| Файл | Что исправлено | Приоритет |
|---|---|---|
| `VisibilityMap.gd` | `_fill_disk` O(r²)→O(r) через `HexUtils.ring()` | **High** |
| `BattleState.gd` | Убрано `_rebuild_unit_grid` → публичный `rebuild_unit_grid()`, чистый контейнер | **High** |
| `WorldSaveLoadService.gd` | Новый файл — вся логика save/load извлечена из WorldController | **High** |
| `WorldController.gd` | Тонкий оркестратор, делегирует в сервисы | **High** |
| `UIBinding.gd` | Новый файл — безопасный доступ к узлам сцены | **Medium** |
| `BattleUI.gd` | Использует `UIBinding` вместо прямых `get_node` | **Medium** |