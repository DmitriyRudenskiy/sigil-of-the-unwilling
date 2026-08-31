# Концепция: Социальная составляющая TerraScape — население, потребности, мораль, штормы

> Образец: прототип **TerraScape: Hex Core** (гексовый градостроительный симулятор
> в стиле *Against the Storm* / *Manor Lords*). Источник — файл-транскрипт
> с HTML-прототипом и его портом на **Godot 4.7** (`globals.gd`,
> `population_manager.gd`, `building_manager.gd`, `grid_manager.gd`).
>
> Цель: зафиксировать **алгоритмы социальной составляющей** (потребности → мораль
> → штормы → караваны → репутация) и механику **авто-слияния ×4** как образец
> для демографики/города проекта. Данные рас/построек переиспользуются из
> [`CONCEPT_SOCIAL_RACES.md`](CONCEPT_SOCIAL_RACES.md) и
> [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md);
> городская модель — [`city_system.md`](../systems/city_system.md).

---

## 🧭 Обзор архитектуры прототипа

Прототип — это **единый цикл хода** на открытой гекс-карте:

```
GridManager  →  BuildingManager  →  PopulationManager  →  UIManager
 (карта/биомы)    (размещение/слияние)   (жители/потребности/мораль)   (UI/очки)
```

Все игровые данные — в **одном словаре `Globals`** (`globals.gd`), а не в
ресурсах. Это упрощение прототипа; в проекте данные должны жить в
`@export`-ресурсах/реестрах (см. «Связь с проектом»).

Ключевые отличия прототипа от «классического» city-builder:
- **Авто-слияние ×4** — четвёртое одинаковое здание в кластере автоматически
  превращается в улучшенное (не рецепт по кнопке, а правило размещения).
- **Шторы (`fire`)** — раз в 3 сезона, урон по зданиям зависит от расовой
  **устойчивости** (`resilience`).
- **Репутация (`rep`)** растёт только когда все потребности закрыты.

---

## 🧬 1. Данные рас — `SPECIES`

7 рас. У каждой: `base` (базовый Resolve 0–50), `decadence` (множитель
разрастания), `resilience` (×0.25 у Ящеров, ×2 у лис-хранителей),
`comfort` / `prof` (комфорт/профиль: `City` / `Culture` / `Water` / `Cooperation`),
`services` (какие услуги нужны жителю), `fire` (модификатор топлива при шторме),
`start` (стартовый бонус).

| Раса | base | decadence | resilience | comfort | prof | services | fire | start |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- | :--- |
| **Human** | 5 | 1.0 | 1.0 | City | City | Religion | fuel −0.2 | cloth +50 |
| **Beaver** | 5 | 1.0 | 1.0 | City | City | Religion | fuel −0.2 | tools +100, cloth +50 |
| **Lizard** | 5 | **2.0** | **0.25** | City | City | Religion | — | — |
| **Harpie** | 5 | **0.25** | 1.0 | Culture | Culture | Religion | — | — |
| **Fox** | 5 | 1.0 | 1.0 | **Cooperation** | City | Religion | — | — |
| **Frog** | 5 | 1.0 | 1.0 | **Water** | Water | Religion | — | — |
| **Bat** | 5 | 1.0 | 1.0 | City | City | Religion | — | — |

> Полный разбор рас (Favoring, «Преданность» батов, «Хранители Огня»,
> расовые здания) — в [`CONCEPT_SOCIAL_RACES.md`](CONCEPT_SOCIAL_RACES.md).
> Здесь важны только поля, которые **используются в алгоритмах ниже**:
> `resilience` (штор), `comfort`/`prof` (бонус в здании), `fire` (штор).

---

## 🏠 2. Потребности (`needs`) — против спроса

Каждый ход (`recompute_needs`) считается **ёмкость** (cap) и **спрос** (demand)
по 8 категориям: `food, cloth, Leisure, Religion, Education, Treatment, Brawling, Luxury`.

### Ёмкость (`cap`) — от зданий
Для каждого здания, дающего услугу (`prov`), вклад = `prov[k] × ratio`, где
`ratio = min(1.0, workers / jobs)` — коэффициент занятости (если здание
неполностью укомплектовано, услуга даётся частично):

```gdscript
for bldg in buildings:
    var b = BUILDINGS[bldg.base_type]
    if b.has("prov"):
        var ratio = 1.0
        if b.jobs > 0: ratio = min(1.0, bldg.workers / b.jobs)
        for k in b.prov: cap[k] += ceil(b.prov[k] * ratio)
```

### Спрос (`dem`) — от жителей
- Базовый: `food = cloth = villagers.size()` (каждому жителю еда и одежда).
- Услуги: за каждую услугу (`services`) расы жителя +1 к спросу.

### Проверка (`ok`)
`ok[k] = (dem[k] == 0) or (cap[k] >= dem[k])`. Дальше флаги `ok` идут в формулу
морали.

---

## 😊 3. Мораль / Resolve (`recalc_resolve`)

`Resolve` жителя — скаляр **0–50** (не шкала 0–1 как в текущем проекте
`Character.NEED_KEYS`). Пересчитывается каждый ход после размещения/назначения.

Формула (в порядке применения):

```gdscript
var r = sp_data.base                       # 5 для всех
r += 5 if needs_stats.ok.food else -10     # еда
r += 3 if needs_stats.ok.cloth else -8     # одежда
for s in sp_data.services:
    r += 3 if needs_stats.ok.get(s) else -6 # услуги
# Жильё — расово-зависимое (см. ниже)
if storm_active:
    r -= STORM_PEN[sp_data.res] * (0.75 if human_perk else 1.0)
if lizard_perk: r += 1
if v.species == "Bat": r += min(6, floor(mourning / 2))
if not v.job.is_empty():
    if BUILDINGS[v.job.base_type].spec == sp_data.comfort: r += 5  # комфорт расы
v.resolve = r
```

### Жильё (`housing`) — расовые нюансы
- **Лягушки** не требуют базового крова: их доля обеспечена (`frog` beds) даёт
  +8 при ratio ≥ 1, −12 при полном дефиците.
- **Остальные**: +4, если общий Shelter покрывает всех non-frog; иначе −10.
- Индивидуальный ratio = `beds(species) / count(species)` → +8 / −6.

### Комфорт в здании
Житель получает **+5**, если профиль здания (`spec`) совпадает с его `comfort`
(`City`/`Culture`/`Water`/`Cooperation`). **Для Лис: +5, если в здании ≥3
представителя расы** (групповая концентрация).

### Штора (`storm_active`)
Урон = `STORM_PEN[res] × 1.0` (или `×0.75`, если в поселении есть трудящийся
человек — `human_perk`, «Хранитель Огня»). `res` — расовый ресурс здания.

---

## 🌦 4. Сезоны, штормы, караваны, репутация

- **Сезон** — логическая единица времени. Кнопка «Сезон +» сдвигает цикл.
- **Штора** — раз в **3-й** сезон: `storm_active = true`, применяет штрафы к
  Resolve (разд. 3), далее `storm_active = false`.
- **Караван** — раз в **2-й** сезон: выдаёт награды (стартовые бонусы, ресурсы).
- **Репутация (`rep`)** — `rep_score`, растёт на +1 за каждый сезон, когда
  **все** потребности закрыты (`all_ok`). Начальное значение 50.

```gdscript
# В next_season():
if season % 3 == 0: storm_active = true
if season % 2 == 0: spawn_caravan()
if all_ok: rep += 1
```

Итоговый счёт игры: `total = recalc_all_scores()` (сумма очков зданий) +
`rep_score` (репутация).

---

## 🔗 5. Авто-слияние ×4 (`auto_merge`)

> Полный разбор механики — в [`CONCEPT_MERGE_AUTO_4.md`](CONCEPT_MERGE_AUTO_4.md):
> условия срабатывания, BFS-компонент, здание `_BIG`, переселение работников, триггер в цикле размещения.

Отличие прототипа от рецептурного слияния (`CONCEPT_BUILDING_SYNERGY.md`, §4):
**встроенное** слияние по правилу «4 одинаковых → 1 улучшенное».

Алгоритм (`building_manager.gd._auto_merge`):
1. При размещении здания с `deck` и `merges` ≠ [] запускаем **BFS** по
   4-связанному компоненту одинаковых `deck`-зданий (вверх/вниз/влево/вправо).
2. Если в компоненте **≥4** зданий — берём 4 (включая только что поставленное),
   удаляем их с карты, ставим merged-здание (`base_type = merges[0]`).
3. `is_merged = true`, `last_parts` = список прироста (base/radius/jobs/
   per_worker/adjacency), `score` = сумма компонентов + бонус.

```gdscript
func _auto_merge(deck, pos):
    if not BUILDINGS[deck].has("merges"): return
    var comp = _connected_components(deck)   # BFS по 4-связности
    for c in comp:
        if c.size() >= 4:
            var cells = c.slice(0, 4)
            for cell in cells: remove_building(cell)
            place_merged(merges[0], pos)
```

> Это **отдельная** механика от рецептурного слияния (Школа+Библиотека→
> Университет) в `CONCEPT_BUILDING_SYNERGY.md`. В проекте их легко спутать:
> авто-слияние — по числу одинаковых в кластере; рецептурное — по составу +
> конфигурации.

---

## 🏗️ 6. Scoring — итоговый рейтинг здания

```gdscript
func building_score(bldg):
    var b = BUILDINGS[bldg.base_type]
    var score = b.base
    score += b.biome.get(map_data[bldg.pos], 0)     # бонус биома под тайлом
    score += b.feat.get(map_features[bldg.pos], 0)  # бонус фичи (forest/river/…)
    if b.has("per_worker"): score += b.per_worker * bldg.workers
    # adjacency в радиусе input_radius
    for neighbor in get_neighbors_in_radius(bldg.pos, b.radius):
        var n = BUILDINGS[neighbor.base_type]
        score += n.adj.get(bldg.base_type, 0)
        score += b.adj.get(neighbor.base_type, 0)
    return score
```

Порядок слагаемых: **base → biome → feat → per_worker → adjacency**. Самоштрафы
(«один тип — один штраф», напр. Библиотека −120, Кузнец −80) реализованы теми же
`adj`-ключами (здание читает само себя в радиусе).

---

## 🔗 Связь с проектом (`Sigil of the Unwilling`)

| Механика прототипа | Где в проекте | Что переносить / не дублировать |
| --- | --- | --- |
| Resolve 0–50, `scripts/demographics/` | `DemographicTurnProcessor`, `Character.NEED_KEYS` (0–1) | Resolve — **новая** скалярная величина, не замена шкале потребностей (см. фаза 0.4 `TASK_SOCIAL_AND_BUILDINGS.md`). |
| Потребности (cap/demand/ok) | `scripts/economy/ProductionChain`, `DemographicTurnProcessor` | Модель «ёмкость от зданий × ratio занятости» — заимствовать, но через `@export`-данные, а не `Globals`. |
| `resilience`/`decadence`/`comfort` | `scripts/demographics/TraitRegistry`, `TraitDef` | Уже есть в системе черт; маппинг расовых полей на теги `body/mind/soul`. |
| Шторы (`fire`) | `scripts/world/` цикл сезона | Модификатор урона по сезонам; `human_perk` = «Хранитель Огня». |
| Авто-слияние ×4 | `scripts/world/City`, `building_*` | Отдельно от городского adjacency (`game/scripts/city/AdjacencySystem.gd`) и рецептурного слияния. |
| Scoring (base/biome/feat/adj) | `game/scripts/city/AdjacencySystem.gd`, `BuildingDefs.gd` | Картографический слой поверх города (см. `TASK_BUILDING_SCORING_GODOT47.md`). |

> ⚠️ **В прототипе данные — в глобальном словаре `Globals` (харкод).**
> В проекте баланс должен быть в `@export`-ресурсах / реестрах, а не в
> едином `Globals`. Геометрия гекса и расстояние — только через
> `scripts/core/HexUtils.gd` (odd-r), а не чебышевская квадратная модель прототипа.

---

## 📚 Зависимости и источники

- [`CONCEPT_SOCIAL_RACES.md`](CONCEPT_SOCIAL_RACES.md) — roster рас, Favoring,
  «Преданность», «Хранители Огня», расовые здания.
- [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md) — полный разбор
  построек: биомы, adjacency, штрафы, рецептурное слияние.
- [`TASK_BUILDING_SCORING_GODOT47.md`](TASK_BUILDING_SCORING_GODOT47.md) — ТЗ на
  размещение/скорнинг/слияние в Godot 4.7.
- [`TASK_SOCIAL_AND_BUILDINGS.md`](TASK_SOCIAL_AND_BUILDINGS.md) — фазы реализации
  соц. составляющей.
- [`city_system.md`](../systems/city_system.md) — городская модель проекта (PopUnit, boroughs).
