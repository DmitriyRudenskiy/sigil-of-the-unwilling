# ТЗ: Стратегическое размещение зданий с радиальным скорнингом и слиянием (TerraScape-style)

> Формат: самодостаточное техническое задание для **Godot 4.7** (GDScript).
> Объект: открытая карта / деревни, где здания — отдельные объекты на гексах,
> чей рейтинг пересчитывается по соседям в радиусе, биому и правилам слияния.
> Образец: механика скорнинга TerraScape
> ([TerraScape Fandom — Library](https://terrascape.fandom.com/wiki/Library)).
> Детальный дизайн-разбор: [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md).
>
> **Не изобретать велосипед.** Соседство и гексы уже есть в `core/HexUtils.gd`,
> городской adjacency-скоринг — в `game/city/AdjacencySystem.gd`. Новая система —
> это **картографический** слой (размещение на открытой карте + village-сквоттинг),
 который работает поверх / независимо от городского `AdjacencySystem`.

---

## 🎯 Цель

Модульная система, где:
1. Здания размещаются на гекс-сетке (`TileMapLayer`).
2. Итоговый рейтинг здания динамически пересчитывается по:
   - базовому счёту,
   - бонусу биома под тайлом,
   - правилам соседства (`adjacency_rules`) в радиусе `input_radius`,
   - иерархии тиров («Ресурс → Переработка → Город»),
   - правилам слияния (`merge_recipes`).
3. При размещении/удалении пересчитывается не только новое здание, но и **все соседи
   в их радиусе** (обратное влияние).
4. Баланс — через `@export`/ресурсы `BuildingData.tres`, **без харкодa в логике**.

---

## 🔗 Связь с существующим кодом

| Что | Где | Как использовать |
| --- | --- | --- |
| Гекс-геометрия, соседство, расстояние | `core/HexUtils.gd` | `get_all_neighbors()`, `hex_distance()`, `get_config()` (odd-r offset). **Не писать свою математику сетки.** |
| Городской adjacency (production mult + reputation) | `game/city/AdjacencySystem.gd` | Уже покрывает «мельница у полей ×1.5», «кузница у рудника ×3». Картографический скорнинг — отдельный слой; не трогать эту матрицу, если не требуется миграция правил. |
| Определение зданий | `game/data/BuildingDefs.gd`, `game/data/UniqueBuilding.gd` | Источник `def`-ов для городов/уникальных зданий. Новая система вводит **отдельный** `BuildingData`-слой для стандартных зданий открытой карты (не путать с `UniqueBuilding.Def`). |
| Сериализация мира | `SaveData`, `WorldBootstrap` | Состояние `GridManager.placed` должно сериализоваться. |

> **Вывод:** ядро скорнинга (счёт + биом + adjacency + иерархия) — **новое**,
> но геометрия гекса и сериализация — **переиспользуются**.

---

## 📦 1. Архитектура данных (Custom Resources)

### 1.1 `BuildingData` (ресурс, `class_name BuildingData extends Resource`)

```gdscript
class_name BuildingData extends Resource

@export var id: StringName
@export var display_name: String
@export var base_score: int = 0
@export var input_radius: int = 1          # радиус сканирования соседей (гексы)
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]  # сколько гексов занимает (мердж = 2–6)
@export var tier: int = Tier.CITY          # см. Tier ниже
@export var biome_bonus: Dictionary = {}   # {terrain-name: points}
@export var adjacency_rules: Dictionary = {} # {target-id: points} (+бафф / −штраф)
@export var merge_recipes: Array[StringName] = []  # во что можно слияться
@export var is_unique: bool = false
```

```gdscript
## 1.2 Tier — иерархия «Ресурс → Переработка → Город»
class_name BuildingTier
enum Tier { RESOURCE = 0, PROCESSING = 1, CITY = 2 }
```

### 1.3 `TerrainBonus` / биомы

Биомы берём из `HexUtils.Terrain` (`WATER, SWAMP, SAND, GRASS, FOREST, MOUNTAIN, SNOW`)
+ при необходимости свой `biome_name` на тайле (`TileMapLayer.get_cell_atlas_coords` →
атлас → слой биома). `biome_bonus` мапит `terrain-name -> points` (напр. `{"grass": 10,
"forest": 15}`).

### 1.4 Файлы `.tres`

Создать в `game/data/buildings/` по одному `.tres` на здание:
`library.tres`, `school.tres`, `university.tres`, `smithy.tres`, `farm.tres` …
Значения (`base_score`, `input_radius`, `biome_bonus`, `adjacency_rules`, `merge_recipes`)
берутся из [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md) — **не харкодить
в коде**.

---

## ⚙️ 2. Основные компоненты

### 2.1 `GridManager` — автозагрузка (Singleton)

Отвечает за «землю» размещённых зданий на карте. Хранит карту `cell -> BuildingInstance`.

```gdscript
class_name GridManager
extends Node

## autoload: "GridManager"
var placed: Dictionary = {}                     # Vector2i -> BuildingInstance
var tilemap: TileMapLayer                       # заполняется в _ready (get_node)

## Все здания в чебышевском/гексовом радиусе от cell (включая self, если нужно).
func get_buildings_in_radius(cell: Vector2i, radius: int) -> Array[BuildingInstance]:
	var out: Array[BuildingInstance] = []
	for key in placed.keys():
		if HexUtils.hex_distance(cell, key) <= radius:
			out.append(placed[key])
	return out

## Число соседей в радиусе, удовлетворяющих предикату (id или tier).
func count_neighbors_in_radius(cell: Vector2i, radius: int, predicate: Callable) -> int:
	var n := 0
	for b in get_buildings_in_radius(cell, radius):
		if predicate.call(b):
			n += 1
	return n

func place(cell: Vector2i, data: BuildingData) -> BuildingInstance
func remove(cell: Vector2i) -> void
func building_at(cell: Vector2i) -> BuildingInstance
```

`BuildingInstance` — простой класс-обёртка (`extends RefCounted`) с полями
`id: StringName`, `data: BuildingData`, `cell: Vector2i`, `node: Node2D`.

> **Гексы vs квадраты:** проект — гексы (odd-r, `HexUtils.get_config`). Для радиуса
> использовать `HexUtils.hex_distance`, а **не** чебышевское расстояние. Квадратная
> модель TerraScape «как есть» не переносится — см. примечание в конце.

### 2.2 `ScoringManager` — расчёт рейтинга

```gdscript
class_name ScoringManager
extends RefCounted

## Итоговый рейтинг здания: base + biome + adjacency(в радиусе) + tier-bonus.
func calculate_score(data: BuildingData, cell: Vector2i) -> int:
	var score := data.base_score
	score += _biome_bonus(data, cell)
	score += _adjacency_score(data, cell)
	score += _tier_bonus(data, cell)
	return score

## Бонус/штраф от соседей в input_radius по adjacency_rules.
func _adjacency_score(data: BuildingData, cell: Vector2i) -> int:
	var total := 0
	for target in data.adjacency_rules.keys():
		var rule: int = data.adjacency_rules[target]
		var count := GridManager.count_neighbors_in_radius(
			cell, data.input_radius, _make_predicate(target))
		total += rule * count
	return total

## Бонус иерархии: +b за здание предыдущего тира в радиусе (Рудник→Кузница→Таверна).
func _tier_bonus(data: BuildingData, cell: Vector2i) -> int
func _biome_bonus(data: BuildingData, cell: Vector2i) -> int
```

**Динамическое обновление:** при `place/remove` пересчитываем новое здание **и**
все здания, для которых оно попало в радиус (обратное влияние). Реализовать через
сигнал `GridManager.building_changed(cell)` → `ScoringManager.refresh_affected(cell)`.

```gdscript
## Пересчёт здания и всех, чей radius достигает cell.
func refresh_affected(cell: Vector2i) -> void:
	var affected := _cells_affected_by(cell)
	for c in affected:
		var b := GridManager.building_at(c)
		if b != null:
			_update_rating_ui(b)
```

### 2.3 `MergeSystem` — слияние

```gdscript
class_name MergeSystem
extends RefCounted

## Проверяет рецепт: components + config (линейно/2×2/…) -> merged-id.
## Возвращает merged BuildingData или null.
func recipe_for(components: Array[StringName], config: Array[Vector2i]) -> BuildingData

## Попытка слияния: если в target_pos здание + new_id образуют рецепт —
## удалить компоненты, спавн merged-здания, VFX, обновить GridManager + UI.
func try_merge(target_pos: Vector2i, new_id: StringName) -> bool
```

Рецепты (напр. `School + Library -> University`,
`School + Library + Tavern -> Citadel`) описаны в `.tres` через `merge_recipes` +
конфигурацию размещения. Харкодить рецепты в коде — нельзя.

---

## 🛠️ 3. Пошаговая сборка в Godot 4.7

### Шаг 1. Сцена и сетка
1. Создать основную сцену с `TileMapLayer` (`grid_layer`) для зданий.
2. Отдельный `TileMapLayer` (`biome_layer`) для биомов/декораций.
3. Настроить слои (Layers): коллизии (`CollisionShape2D` по footprint),
   визуализация радиуса (отдельный `Line2D`/`Polygon2D`, включается при прицеливании).
4. В `project.godot` → `Autoload` добавить `GridManager` (сцену `GridManager.tscn`
   с `Node`-корнем, `tilemap` резолвится по пути).

### Шаг 2. Ресурсы зданий
1. В инспекторе создать `game/data/buildings/*.tres` для `BuildingData`.
2. Заполнить поля по [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md):
   - **Library:** `input_radius=4`, `biome_bonus={urban:25}`, `adjacency_rules={citadel:40, school:35, hospital:30, city_district:25, longhouse:20, university:15, chapel:15, houses:10}`, `adjacency_rules.library=-120` (самоштраф), `merge_recipes=[university, citadel]`.
   - **School / University / Citadel / …** — аналогично из таблицы.
3. Завести реестр `BuildingRegistry.gd` (`Dictionary[StringName -> BuildingData]`)
   с загрузкой всех `.tres` через `DirAccess`.

### Шаг 3. Размещение и визуальная обратная связь
1. Режим «здание в руке»: `EditorPlacementController` по клику на гекс.
2. Подсветка тайлов в `input_radius` (зелёный = выгодное размещение, красный =
   штраф, напр. −120 за соседнюю библиотеку).
3. При размещении: `GridManager.place()` → эмит `building_changed` →
   `ScoringManager.refresh_affected()` → сигнал `rating_changed(cell, score)`.

### Шаг 4. Слияние
1. `try_merge()`: проверить `recipe_for(components, config)`.
2. Если да → удалить ноды компонентов, спавн merged-здания (footprint 2–6 гексов),
   проиграть VFX (анимация слияния), обновить `GridManager` + UI-рейтинги соседей.

### Шаг 5. Оптимизация и развязка зависимостей
1. Связь через сигналы (`building_changed`, `rating_changed`), **не** через жёсткие
   ссылки — избегать циклических зависимостей `GridManager <-> ScoringManager`.
2. Кэш рейтингов в `BuildingInstance.rating`; пересчёт только затронутых клеток.
3. Для больших карт — кеширование `get_buildings_in_radius` по радиусу.

---

## ✅ 4. Критерии приемки (Definition of Done)

- [ ] Здание размещается на гексе, занимает корректные footprint-клетки.
- [ ] Размещение Библиотеки рядом со Школой (+1 гекс) повышает её рейтинг на **+35**.
- [ ] Две Библиотеки в радиусе 4 получают штраф **−120** каждая (пересчёт обоих).
- [ ] Размещение на тайле Urban/`grass` → **+25** (библиотека), биом читается с тайла.
- [ ] Слияние Школа+Библиотека → Университет: компоненты удалены, спавн merged-здания,
      его radius-баффы пересчитаны у соседей.
- [ ] Самоштрафы «один тип — один штраф» (Библиотека −120, Кузнец −80, Лесопилка −55).
- [ ] Инархия тиров: здание уровня CITY получает бонус от PROCESSING/RESOURCE в радиусе.
- [ ] Код типизирован (`Vector2i`, `StringName`, `Array[BuildingInstance]`),
      баланс — через `@export`/`.tres`, **без hardcoded-значений** в логике расчёта.
- [ ] Состояние `GridManager.placed` серизуется в `SaveData`.

---

## 🧪 5. Тесты (`core/tests/` или `project://res://tests/`)

- `test_scoring_library_next_to_school` → +35.
- `test_scoring_library_library_penalty` → −120 × 2.
- `test_scoring_biome_bonus` → +25 на urban.
- `test_merge_recipe_university` → components удалены, spawned `university`.
- `test_refresh_affected_backward` → сосед потерял/получил рейтинг после place/remove.
- `test_hex_radius_vs_chebyshev` → радиус корректен на гексах (не квадрате).

---

## ⚠️ 6. Примечания и риски

- **Гексы, а не квадраты.** В Godot 4.7 для гексов (odd-r) расстояние считается через
  кубические координаты: `HexUtils.offset_to_cube()` → `max(dx, dy, dz)`.
  Чебышевская (`max(|dx|,|dy|)`) и манхэттенская (`|dx|+|dy|`) модели **неверны** для
  гексов — использовать `HexUtils.hex_distance`.
- **Не дублировать городской скорнинг.** `game/city/AdjacencySystem.gd` уже даёт
  `building_output_mult` + `reputation_bonus` для зданий **внутри города**. Новая система —
  это картографический слой для открытой карты/деревень; правила не копировать, а держать
  в `BuildingData.adjacency_rules`.
- **Merged-здания — хабы баффов.** Здания 2–6 гексов (Citadel = 6) сами дают баффы
  окружению; `refresh_affected` должен пересчитывать и их соседей.
- **Производительность.** При спаме пересчётами кэшировать рейтинги, пересчитывать
  только затронутые клетки, а не всю карту.

---

## 📚 Зависимости и источники

- [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md) — дизайн-разбор
  взаимосвязей всех зданий TerraScape.
- [`TASK_SOCIAL_AND_BUILDINGS.md`](TASK_SOCIAL_AND_BUILDINGS.md) — фаза 2/3 (та же тема,
  но в составе задачи «социалка + постройки»).
- `core/HexUtils.gd`, `game/city/AdjacencySystem.gd`, `game/data/BuildingDefs.gd`,
  `game/data/UniqueBuilding.gd`.
