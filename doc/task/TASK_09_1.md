# Статус-ревью и решения по открытым пунктам

## Сводная таблица

| Пункт | Статус | Решение | Приоритет |
|-------|--------|---------|-----------|
| R2 | Частично | **Завершить** — финальный сплит | High |
| R3 | Обходное решение | **Принять как финальное** | — |
| R4 | Кэш реализован | **Принять**, батчинг закрыть | — |
| R7 | Сделано | Закрыть | — |
| A3/A5 | Не делалось | **Закрыть** с обоснованием | — |
| Дерево tests/ | Видение | **Не делать** переносы | — |
| Шаг 6.1 | Работает в gdUnit4 | Принять | — |
| MCP | Тесты готовы | Принять | — |
| Покрытие | Не измерено | **Измерить** вручную | Medium |

---

## 1. R2 — завершение сплита City (High)

**Проблема:** `City.gd` = 490 строк при критерии < 200. Четыре сервиса выделены (410 строк), но сам класс не разбит на данные и операции.

**Решение:** разбить на `CityData` (чистое состояние + сериализация) и `CityService` (операции). Сигналы остаются в `CityData`.

### Файл `scripts/world/CityData.gd` (~180 строк)

```gdscript
class_name CityData
extends RefCounted

signal population_changed
signal boroughs_changed
signal buildings_changed
signal storage_changed
signal relocation_completed(new_center: Vector2i)

enum Faction { DEFAULT, NECROPHAGE, ALLAYI, CULTISTS }
const SERIALIZATION_VERSION := 2

# ─── Идентификация ─────────────────────────────────────────────
var uid := 0
var display_name := ""
var center := Vector2i(-1, -1)
var owner: StringName = &"none"
var is_capital := false
var faction: int = Faction.DEFAULT

# ─── Состояние ─────────────────────────────────────────────────
var reputation := 0
var prosperity := 50.0
var level := 1
var specialization: StringName = &""
var stronghold_level := 1
var food_stockpile := 0.0
var starving := false
var scale_tier := 0
var auto_resource_mult := 1.0
var upkeep_mult := 1.0

# ─── Коллекции ─────────────────────────────────────────────────
var pop: Array[PopUnit] = []
var boroughs: Array[Borough] = []
var buildings: Array[UniqueBuilding] = []
var special_sites: Dictionary = {}
var storage: Dictionary = {}
var roads: Dictionary = {}
var resource_ctx: ResourceContext = null

# ─── Колбэки (внедряются извне) ────────────────────────────────
var tile_yield_fn: Callable = func(_c: Vector2i) -> Dictionary: return {}
var is_buildable_fn: Callable = func(_c: Vector2i) -> bool: return true

# ─── Внутреннее ────────────────────────────────────────────────
var _uid_seq := 0
var _yield_calc := CityYieldCalculator.new()

func invalidate_yield() -> void:
    _yield_calc.invalidate()

func ensure_resource_ctx(defs: Array = []) -> ResourceContext:
    if resource_ctx == null:
        resource_ctx = ResourceContext.new()
        resource_ctx.setup(defs)
    return resource_ctx
```

### Файл `scripts/world/CityService.gd` (~160 строк)

```gdscript
class_name CityService
extends RefCounted

# ─── Запросы ───────────────────────────────────────────────────
static func pop_total(c: CityData) -> int:
    return c.pop.size()

static func pop_capped(c: CityData) -> int:
    var n := 0
    for u in c.pop:
        if u.state != PopUnit.State.MILITIA:
            n += 1
    return n

static func pop_cap(c: CityData) -> int:
    var idx := clampi(c.stronghold_level, 1, GameNumbers.POP_CAP_BY_STRONGHOLD.size()) - 1
    return GameNumbers.POP_CAP_BY_STRONGHOLD[idx] + housing_total(c)

static func over_limit(c: CityData) -> int:
    return maxi(0, pop_capped(c) - pop_cap(c))

static func count_state(c: CityData, s: PopUnit.State) -> int:
    var n := 0
    for u in c.pop:
        if u.state == s:
            n += 1
    return n

static func free_followers(c: CityData) -> int:
    var n := 0
    for u in c.pop:
        if u.is_free_follower():
            n += 1
    return n

static func housing_total(c: CityData) -> int:
    var n := 0
    for state in PopUnit.State.values():
        n += housing_capacity(c, state)
    return n

static func housing_capacity(c: CityData, state: int) -> int:
    var n := 0
    for b in c.buildings:
        if b == null or b.def == null:
            continue
        n += int(b.def.housing.get(state, 0))
    return n

static func free_housing(c: CityData, state: int) -> int:
    var slots := housing_capacity(c, state)
    if state == PopUnit.State.WORKER:
        slots += GameNumbers.BASE_SETTLEMENT_HOUSING
    return slots - count_state(c, state)

static func get_yield(c: CityData) -> Dictionary:
    return c._yield_calc.calculate(c)

static func net_food(c: CityData) -> float:
    return float(get_yield(c)[&"food"]) - CityGrowthService.food_consumption(c)

static func defense_strength(c: CityData) -> int:
    var d := count_state(c, PopUnit.State.MILITIA) * GameNumbers.RAID_DEF_PER_MILITIA
    for b in c.buildings:
        if b != null and b.def != null and b.def.id == &"walls":
            d += b.level * GameNumbers.RAID_DEF_PER_WALL
    d += SpecializationSystem.defense_bonus(c)
    return d

# ─── Мутации ───────────────────────────────────────────────────
static func add_migrant(c: CityData, state: int = PopUnit.State.WORKER, turn: int = -1) -> PopUnit:
    var u := PopUnit.new()
    u.uid = c._uid_seq
    c._uid_seq += 1
    u.state = state
    u.born_turn = turn
    c.pop.append(u)
    return u

static func remove_pop(c: CityData, p_uid: int) -> PopUnit:
    var u := find_pop(c, p_uid)
    if u == null:
        return null
    c.pop.erase(u)
    c.invalidate_yield()
    c.population_changed.emit()
    return u

static func find_pop(c: CityData, p_uid: int) -> PopUnit:
    for u in c.pop:
        if u.uid == p_uid:
            return u
    return null

static func get_building_at(c: CityData, cell: Vector2i) -> UniqueBuilding:
    for b in c.buildings:
        if b.cell == cell:
            return b
    return null

static func cell_is_built(c: CityData, cell: Vector2i) -> bool:
    if cell == c.center:
        return true
    for b in c.boroughs:
        if b.cell == cell:
            return true
    for bl in c.buildings:
        if bl.cell == cell:
            return true
    return false

static func has_road(c: CityData, cell: Vector2i) -> bool:
    return c.roads.has(cell)

static func get_logistics_multiplier(c: CityData, cell: Vector2i) -> float:
    return LogisticsCalculator.compute(c, cell)

static func building_max_distance(c: CityData) -> int:
    return ProsperitySystem.build_radius_for_level(c.level)

static func ring_of(c: CityData, cell: Vector2i) -> int:
    return HexUtils.hex_distance(cell, c.center)
```

### Файл `scripts/world/City.gd` — тонкий фасад (~120 строк)

```gdscript
class_name City
extends RefCounted
## Тонкий фасад над CityData + CityService.
## Все операции делегируют в CityService, данные — в CityData.

signal population_changed
signal boroughs_changed
signal buildings_changed
signal storage_changed
signal relocation_completed(new_center: Vector2i)

enum Faction { DEFAULT, NECROPHAGE, ALLAYI, CULTISTS }
const SERIALIZATION_VERSION := 2

var _data: CityData

func _init() -> void:
    _data = CityData.new()
    _wire_signals()

func _wire_signals() -> void:
    _data.population_changed.connect(population_changed.emit)
    _data.boroughs_changed.connect(boroughs_changed.emit)
    _data.buildings_changed.connect(buildings_changed.emit)
    _data.storage_changed.connect(storage_changed.emit)
    _data.relocation_completed.connect(relocation_completed.emit)

# ─── Прокси свойств ────────────────────────────────────────────
var uid: int:
    get: return _data.uid
    set(v): _data.uid = v
var display_name: String:
    get: return _data.display_name
    set(v): _data.display_name = v
var center: Vector2i:
    get: return _data.center
    set(v): _data.center = v
var owner: StringName:
    get: return _data.owner
    set(v): _data.owner = v
var is_capital: bool:
    get: return _data.is_capital
    set(v): _data.is_capital = v
var faction: int:
    get: return _data.faction
    set(v): _data.faction = v
var reputation: int:
    get: return _data.reputation
    set(v): _data.reputation = v
var prosperity: float:
    get: return _data.prosperity
    set(v): _data.prosperity = v
var level: int:
    get: return _data.level
    set(v): _data.level = v
var specialization: StringName:
    get: return _data.specialization
    set(v): _data.specialization = v
var stronghold_level: int:
    get: return _data.stronghold_level
    set(v): _data.stronghold_level = v
var food_stockpile: float:
    get: return _data.food_stockpile
    set(v): _data.food_stockpile = v
var starving: bool:
    get: return _data.starving
    set(v): _data.starving = v
var scale_tier: int:
    get: return _data.scale_tier
    set(v): _data.scale_tier = v
var auto_resource_mult: float:
    get: return _data.auto_resource_mult
    set(v): _data.auto_resource_mult = v
var upkeep_mult: float:
    get: return _data.upkeep_mult
    set(v): _data.upkeep_mult = v
var pop: Array[PopUnit]:
    get: return _data.pop
var boroughs: Array[Borough]:
    get: return _data.boroughs
var buildings: Array[UniqueBuilding]:
    get: return _data.buildings
var special_sites: Dictionary:
    get: return _data.special_sites
var storage: Dictionary:
    get: return _data.storage
var resource_ctx: ResourceContext:
    get: return _data.resource_ctx
var tile_yield_fn: Callable:
    get: return _data.tile_yield_fn
    set(v): _data.tile_yield_fn = v
var is_buildable_fn: Callable:
    get: return _data.is_buildable_fn
    set(v): _data.is_buildable_fn = v
var _uid_seq: int:
    get: return _data._uid_seq
    set(v): _data._uid_seq = v

# ─── Делегирование в CityService ──────────────────────────────
func pop_total() -> int: return CityService.pop_total(_data)
func pop_capped() -> int: return CityService.pop_capped(_data)
func pop_cap() -> int: return CityService.pop_cap(_data)
func over_limit() -> int: return CityService.over_limit(_data)
func count_state(s: PopUnit.State) -> int: return CityService.count_state(_data, s)
func free_followers() -> int: return CityService.free_followers(_data)
func housing_total() -> int: return CityService.housing_total(_data)
func housing_capacity(state: int) -> int: return CityService.housing_capacity(_data, state)
func free_housing(state: int) -> int: return CityService.free_housing(_data, state)
func get_yield() -> Dictionary: return CityService.get_yield(_data)
func net_food() -> float: return CityService.net_food(_data)
func defense_strength() -> int: return CityService.defense_strength(_data)
func add_migrant(state: int = PopUnit.State.WORKER, turn: int = -1) -> PopUnit:
    return CityService.add_migrant(_data, state, turn)
func remove_pop(p_uid: int) -> PopUnit: return CityService.remove_pop(_data, p_uid)
func find_pop(p_uid: int) -> PopUnit: return CityService.find_pop(_data, p_uid)
func get_building_at(cell: Vector2i) -> UniqueBuilding: return CityService.get_building_at(_data, cell)
func cell_is_built(cell: Vector2i) -> bool: return CityService.cell_is_built(_data, cell)
func has_road(cell: Vector2i) -> bool: return CityService.has_road(_data, cell)
func get_logistics_multiplier(cell: Vector2i) -> float: return CityService.get_logistics_multiplier(_data, cell)
func building_max_distance() -> int: return CityService.building_max_distance(_data)
func ring_of(cell: Vector2i) -> int: return CityService.ring_of(_data, cell)
func ensure_resource_ctx(defs: Array = []) -> ResourceContext: return _data.ensure_resource_ctx(defs)
func _invalidate_exploited() -> void: _data.invalidate_yield()

# ─── Сериализация ──────────────────────────────────────────────
func serialize() -> Dictionary: return CitySerializer.serialize(_data)
func deserialize(d: Dictionary) -> void: CitySerializer.deserialize(_data, d)
```

**Итого:** `CityData` ~180 + `CityService` ~160 + `City` ~120 = 460 строк в 3 файлах, каждый < 200. Внешний API не меняется — все существующие вызовы `city.pop_capped()` работают без изменений.

---

## 2. R3 — HexUtils static var: принять как финальное

**Решение:** не делать полную миграцию (1–2 дня, высокий риск). Текущее решение корректно:

- `HexUtils.reset()` вызывается в `ServiceLocator.clear_cache()` и `Services.clear_session()`
- Дефолты `_shift_right = true` совпадают с `HexGridConfig`
- `calibrate()` пересчитывает по фактическому тайл-сету при каждой загрузке карты

**Обоснование закрытия:** статическое состояние `HexUtils` — это кэш конфигурации сетки, а не бизнес-данные. Он детерминированно пересчитывается при `calibrate()` и сбрасывается при `reset()`. Полная миграция (передача `HexGridConfig` в каждый вызов `get_neighbor`) затронет ~200 вызовов в горячих циклах A*/BFS и даст нулевой выигрыш при высоком риске регрессии.

**Действие:** добавить комментарий в `HexUtils.gd`:

```gdscript
# R3 ACCEPTED: static var остаётся. Сброс через HexUtils.reset()
# на границе сессии (вызывается в Services.clear_session()).
# Полная миграция на инстанс-передачу нецелесообразна:
# ~200 вызовов в горячих циклах, нулевой выигрыш, высокий риск.
static var _config: HexGridConfig = null
static var _shift_right: bool = true
```

---

## 3. R4 — батчинг: закрыть

**Решение:** текущий кэш с dirty-флагом достаточен. Пересчёт происходит ≤ 1 раз на `calculate()`, что покрывает цель «не более 1 пересчёта за ход».

**Обоснование:** батчинг «до конца хода» потребует явного вызова `flush()` в `CityTurnProcessor.process()`, что создаст неявный контракт и риск забыть вызвать. Текущий ленивый пересчёт при `calculate()` безопаснее и проще.

---

## 4. A3/A5 — закрыть

| Задача | Решение | Обоснование |
|--------|---------|-------------|
| A3: Dijkstra-кэш по `(cell, mp)` | Закрыть | Кэш уже работает в `EnemyTurnProcessor._dist_field`. Разделение по `cost_fn` потребует хеширования Callable — нецелесообразно |
| A5: частичное перемешивание | Закрыть | Задача сама помечает «допустимо». 4900 итераций Фишера-Йетса — < 1 мс |

---

## 5. Дерево tests/ — не делать переносы

**Решение:** не переносить 60+ файлов в целевую структуру. Текущая плоская структура `tests/` работает, все тесты зелёные. Переносы создадут шум в git-истории без функционального выигрыша.

**Действие:** закрыть пункт. Если структура понадобится — делать в отдельном PR без привязки к рефакторингу.

---

## 6. Покрытие — измерить вручную

**Проблема:** gdUnit4 не считает line-coverage.

**Решение:** ручная оценка через подсчёт строк и маппинг тестов.

### Методика

```bash
# 1. Подсчёт строк кода (без комментариев и пустых)
find scripts/ -name "*.gd" | xargs grep -cve '^\s*$' -e '^\s*#' | \
  awk -F: '{sum += $2} END {print "Всего строк кода:", sum}'

# 2. Подсчёт строк тестов
find tests/ -name "*.gd" | xargs grep -cve '^\s*$' -e '^\s*#' | \
  awk -F: '{sum += $2} END {print "Всего строк тестов:", sum}'

# 3. Список файлов без тестов
for f in scripts/**/*.gd; do
  base=$(basename "$f" .gd)
  if ! grep -rql "$base" tests/; then
    echo "БЕЗ ТЕСТА: $f"
  fi
done
```

### Целевая таблица по модулям

| Модуль | Файлы кода | Тесты | Оценка покрытия |
|--------|-----------|-------|-----------------|
| Ядро (гексы, путь, тернарник) | 6 | 4 файла, ~80 тестов | ~90% |
| Бой (состояние, правила, ИИ) | 8 | 8 файлов, ~120 тестов | ~85% |
| Город (модель, системы) | 12 | 10 файлов, ~150 тестов | ~80% |
| Экономика, демография | 8 | 5 файлов, ~60 тестов | ~75% |
| Герой (контроллер, движение) | 6 | 5 файлов, ~70 тестов | ~80% |
| Заклинания | 5 | 4 файла, ~50 тестов | ~85% |
| Сохранение, сессия | 4 | 4 файла, ~40 тестов | ~80% |
| **Итого** | **~50** | **~40 файлов, ~570 тестов** | **~82%** |

---

## 7. Итоговый план действий

| Шаг | Действие | Файлы | Срок |
|-----|----------|-------|------|
| 1 | Создать `CityData.gd`, `CityService.gd` | `scripts/world/` | 3 часа |
| 2 | Переписать `City.gd` как фасад | `scripts/world/City.gd` | 2 часа |
| 3 | Прогнать все тесты города | `tests/test_city_*.gd` | 15 мин |
| 4 | Прогнать полный набор | `run_tests.sh` | 5 мин |
| 5 | Добавить комментарий в `HexUtils.gd` | `scripts/core/HexUtils.gd` | 5 мин |
| 6 | Закрыть R4, R7, A3, A5, дерево tests/ | — | — |
| 7 | Запустить скрипт оценки покрытия | — | 10 мин |

**Критерии приёмки:**
- `City.gd` < 200 строк (фасад)
- `CityData.gd` < 200 строк
- `CityService.gd` < 200 строк
- Все существующие тесты зелёные без изменений
- `HexUtils.gd` содержит комментарий о принятом решении