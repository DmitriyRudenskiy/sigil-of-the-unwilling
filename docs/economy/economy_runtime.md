# Экономика хода (ресурсы, цепочки, рабочие, демография)

Документ описывает **исполнение экономики и демографии в ходу** — те подсистемы,
которые поверх чистой модели города (`city_system.md`) работают как **фазы цикла
хода** (`EconomicTurnProcessor` / `DemographicTurnProcessor` в `TurnScheduler`).
См. [`CORE_TURN_PIPELINE.md`](../architecture/CORE_TURN_PIPELINE.md) — как фазы регистрируются,
сортируются по приоритету и получают `TurnContext`.

Системные характеристики персонажей (статы/навыки/способности), которых касается
демография, описаны в [`CONCEPT_CHARACTER_SYSTEM.md`](../concepts/CONCEPT_CHARACTER_SYSTEM.md).

**Ключевые файлы:**

| Файл | Роль |
| --- | --- |
| `economy/ResourceContext.gd` | Хранилище ресурсов (`id → количество`) с лимитами. |
| `economy/ProductionChain.gd` | Формула и исполнение производства здания. |
| `economy/EconomicTurnProcessor.gd` | Фаза 1 (`priority 10`): авто-ресурсы → цепочки → поддержка. |
| `demographics/DemographicTurnProcessor.gd` | Фаза 2 (`priority 20`): персонажи, потребности, смерть, эпидемии, учёные. |
| `world/WorkerAssignment.gd` | Назначение рабочих на здания (Спринт 7). |
| `world/CityBalance.gd` | Константы баланса (приток, лимиты, еда, репутация). |
| `world/GloryTracker.gd` | Слава за скользящее окно (множитель притока). |
| `data/ResourceRegistry.gd` | Определения ресурсов и ёмкости складов. |
| `data/BuildingDefs.gd` | Каталог зданий с цепочками/upkeep/жильём. |

См. [`city_system.md`](../systems/city_system.md) — модель `City`, население, ход города,
строительство зданий; здесь только экономика- и демография-подсистемы.

---

## Архитектура: фазы хода

Экономика и демография — это **`TurnPhaseProcessor`** (паттерн с приоритетом и
`process(ctx)`), которые `TurnScheduler` пробегает по возрастанию приоритета.
`WorldBootstrap` регистрирует их в планировщике (линия ~243–306):

```
City.process_turn (моалит, city_system.md)   ← рождения, еда, склад
   └─ TurnScheduler.execute_turn():
        [1] EconomicTurnProcessor   priority 10   ← экономика (M1)
        [2] DemographicTurnProcessor priority 20   ← демография (M2)
```

Фаза экономики **не трогает** legacy-`City.storage` — работает через
`city.resource_ctx`. Фаза демографии **не вызывает** `City.process_turn` —
монолит уже отработал ранее; процессор только тикает потребности и даёт
персонаж каждой фигурке. Внешние эффекты (сигналы UI) процессоры **не вызывают**
напрямую — пробрасывает интеграционный слой (`WorldBootstrap` / `GameEventBus`).

---

## 1. Система ресурсов: `ResourceContext`

Глобальное хранилище ресурсов города — единый словарь `StringName → float`
с лимитами по типу. Сериализуется в Dictionary (JSON-совместимо), не зависит от
узлов Godot.

- **Ёмкость** (`_capacities`): из `ResourceDef.capacity` (setup). Неизвестный id
  появляется автоматически при первом `add()` с безлимитной ёмкостью (`INF`) —
  реестр можно расширять без изменения контекста. Городские ёмкости заданы в
  `ResourceRegistry.CITY_RESOURCE_CAPACITIES` (`grain/flour/bread = 20`, `ore = 20`,
  `tools = 10`, `gold = 50`, `scholar_points = 10`).
- **`add(id, amount)`** — добавляет с учётом лимита, возвращает **фактически**
  добавленное (обрезано до ёмкости). Сигнал `resource_changed`; при достижении
  ёмкости — `capacity_reached`.
- **`remove(id, amount)`** — снимает, возвращает фактически снятое.
- **`can_afford(costs)` / `spend(costs)`** — проверка/списание набора
  (`{id: amount}`): `spend` списывает только если хватает **всего**.
- **`set_capacity(id, cap)`** — меняет лимит и режет текущий запас сверху.
- **`get()/serialize()/deserialize()`** — снапшот `{id: amount}` для сохранения.

Сигналы `resource_changed` / `capacity_reached` подписывает UI/интеграция.

### `ResourceDef` / `ResourceRegistry`

`ResourceDef` — определение ресурса (категория `raw/craft/spirit`, ёмкость,
редкость, discovery/extraction-ключи, биомы). `ResourceRegistry` (autoload) —
11 скрытых жил (oak/silver/quartz/saltpeter/…) + базовые wood/stone (последние
не спавняются на карте — только городские цепочки).

---

## 2. Цепочки производства: `ProductionChain`

Формула выхода:

```
output = base_output × min(workers / required_workers, 1.0) × building_eff × logistics_eff
```

- `worker_ratio` — доля занятых рабочих (если рабочих меньше требуемых или нет
  вовсе → `{}`).
- `building_eff` — множитель эффективности здания (уровень; копируется
  per-building при постройке).
- `logistics_eff` — логистика (дистанция/дороги, M3).

`execute(ctx, workers, logistics)` **атомарен**: если входов не хватает
(`can_produce`), возвращает `{}` и **не списывает** входы. При успехе списывает
`inputs` из `ResourceContext` и возвращает фактические выходы. Сериализуется
(`to_dict`/`from_dict`) — состояние здания.

---

## 3. Фаза экономики: `EconomicTurnProcessor`

`get_phase_id() = "economy"`, `priority = 10`. Порядок внутри фазы:

### 3.1. Авто-ресурсы (базовый уклад)

Дрова/камень — вход для цепочек, поэтому идут **первыми**:

```
wood  = GameSettings.RESOURCE_AUTO_WOOD_PER_DAY  × city.auto_resource_mult
stone = GameSettings.RESOURCE_AUTO_STONE_PER_DAY × city.auto_resource_mult
```

### 3.2. Цепочки зданий

Для каждого здания с `production_chain != null`:

```
workers   = building.assigned_workers                 # WorkerAssignment
logistics = city.get_logistics_multiplier(cell)
            × building.zone_multiplier                  # ZoningSystem (M3)
            × AdjacencySystem.building_output_mult      # бонус соседей (Спринт 8)
outputs   = chain.execute(res, workers, logistics)
```

- Рабочих здание считает само (`assigned_workers`), не всё рабочее население.
- Выходы добавляются в тот же `resource_ctx`; если добавлено `0` при наличии
  ёмкости — сигнал `resource_depleted`.
- Цепочка не отработала (нет рабочих / нехватка входов) → `continue`, входы не
  списаны (атомарность `execute`).

### 3.3. Поддержка (upkeep)

За каждое здание с `upkeep != {}`: `effective = upkeep × city.upkeep_mult`,
`res.spend(effective)`. Успех → `upkeep_ok`, неудача → `upkeep_failed` +
сигнал `upkeep_failed`.

Сигналы фазы: `production_completed`, `upkeep_failed`, `resource_depleted`.

---

## 4. Рабочие: `WorkerAssignment`

Спринт 7. **Рабочий = `PopUnit.State.WORKER`**. Назначение — `pop.assigned_to`
(uid здания) + `building.assigned_workers` (счётчик). Назначение **не требует
клетки** (рабочий здания ≠ рабочий тайла legacy-контура).

`assign_all(city)` вызывается каждый ход (`CityTurnProcessor`):

1. рабочих со сломанными ссылками (здание удалено) освобождаем;
2. заполняем недостачу (`required_workers − assigned_workers`) свободными
   рабочими;
3. переназначение существующих **не** делается (стабильность): если рабочее
   место высвободилось, его займёт свободный рабочий.

Рабочие, занятые за клеткой (`u.tile`), и закреплённые (`assigned_to != -1`)
в перебалансировку не лезут.

---

## 5. Последователи: модель и лимиты

См. `city_system.md` (PopUnit, состояния). Здесь — экономическая роль и
механики использования.

### 5.1. Ёмкость (лимит крепости)

```
pop_cap()   = POP_CAP_BY_STRONGHOLD[stronghold_level − 1] + housing_total()
pop_capped()= рабочие + последователи   (ополченцы НЕ учитываются, ТЗ 3.3)
```

`POP_CAP_BY_STRONGHOLD = [10, 20, 35]` (индекс = уровень − 1). Ёмкость жилья —
из `def.housing` зданий (`shack → worker +10`, `manor → scholar +2`,
`barracks → militia +5`); у рабочих — базовое жильё поселения
(`BASE_SETTLEMENT_HOUSING = 10`) без зданий. `free_housing(state)` — слоты
минус занятые.

### 5.2. Свободные последователи

`free_followers()` — фигурки `is_free_follower()` (не закреплённые, не
переключающиеся). Идут на:

- **Улучшения зданий** — `LevelReq.followers` закрепляется зданию
  (`_assign_followers` списывает из свободных). Проверка в `can_upgrade_building`
  (`_check_req`: industry + special + `free_followers() >= req.followers`).
- **Найм войск** — `City.recruit_followers(n)` списывает n свободных последователей.

### 5.3. Циклический приток (в столицу, каждые 7 ходов)

`CityManager.capital_inflow(month)` (Спринт 3.2):

```
base = INFLOW_BASE(2) + INFLOW_PER_TEMPLE_LEVEL(2) × great_temple_level
glory_mod = 1 + glory_last_window / INFLOW_GLORY_DIVISOR(50)
season_mod = Season.growth_modifier(month)
arrivals = floor(base × glory_mod × season_mod)
```

- **Великий Храм** (`great_temple`, BuildingDefs) — даёт базовый приток +2 за
  уровень, требует площадки-святилища.
- **Слава** (`GloryTracker`) — слава за скользящее окно в `CITY_CYCLE_TURNS`
  (7) ходов: победы, деревни, квесты, подземелья. `add_glory(amount, turn, reason)`.
- **Сезон** — модификатор `Season` (лето/зима/весна-осень).

Приток применяется **только в столицу** (`current_turn % 7 == 0`), через
`capital.add_followers(arrivals)`. Лимит столицы приток **не блокирует** —
переполнение возвращается как `overflow` и показывает статус-сообщение
«Столица переполнена… требуют распределения».

> **Связь с ТЗ 3.2:** «последователи прибывают в столицу каждые 7 ходов в зависимости
> от Известности» — это и есть `capital_inflow` (Слава = Известность, окно 7 ходов).

---

## 6. Здания: экономические поля

См. `city_system.md` (строительство/улучшение). Здесь — поля, отвечающие за
производство:

`UniqueBuilding`:

| Поле | Назначение |
| --- | --- |
| `production_chain` | Цепочка (M1). `null` = здание не производит. Копия из `def.production_chain` (per-building `building_eff`). |
| `upkeep` | Поддержка `StringName → float` в день. |
| `zone_type` / `zone_multiplier` | Зонирование (M3); `1.0` = без бонусов. Обновляет `CityTurnProcessor`. |
| `assigned_workers` | Назначенные рабочие (WorkerAssignment). |
| `assigned_followers` | Закреплённые на улучшении последователи. |

### Каталог зданий (BuildingDefs)

**Базовые/спец.:** великий храм, рынок, казармы, древнее хранилище, стены.

**Цепочки производства (Спринт 8):**

| Здание | Рабочих | Входы → Выход | Поддержка |
| --- | --- | --- | --- |
| Ферма | 2 | → `grain` 3 | — |
| Мельница | 1 | `grain` 2 → `flour` 2 | wood 1 (бонус у 2+ ферм ×1.5) |
| Пекарня | 1 | `flour` 2 → `bread` 2 | wood 1 |
| Рудник | 2 | → `ore` 2 | — |
| Кузница | 1 | `ore` 1 + wood 1 → `tools` 1 | wood 1 (бонус у рудника ×3) |
| Училище | 1 | → `scholar_points` 1 | wood 2 |
| Таверна | 1 | → `gold` 1 | — (бонус: +2 репутации у жилья) |
| Торговый пост | 2 | `bread` 1 → `gold` 2 | — |

**Жильё:** хижина (`+10 worker`), особняк (`+2 scholar`).

---

## 7. Фаза демографии: `DemographicTurnProcessor`

`get_phase_id() = "demographics"`, `priority = 20`. `setup(CharacterRegistry)`.
Нарративная оболочка над PopUnit:

1. **Персонаж за фигуркой** — для каждой pop без персонажа: `registry.create()` +
   `character_born`. Монолит `City.process_turn` (рождения/смерти) здесь **не**
   дублируется.
2. **Тик потребностей** — базовый распад (`DECAY: hunger 0.15, rest 0.10,
   social 0.08, belief 0.05`) + восстановление от города + модификаторы черт.
   Восстановление зависит от состояния: голодающий город → распад сытости,
   ополченец не спит (`rest`), и т.д.
3. **Критика** (`< 0.2`) — сигнал `character_need_critical` раз в эпизод (не
   каждый ход).
4. **Смерть** — потребность = 0 три хода подряд (`DEATH_STREAK`) →
   `character_died` + `city.remove_pop`. Причины: голод → `starvation`, усталость
   → `exhaustion`, изоляция → `isolation`, отчаяние → `despair`.
5. **Эпидемия** — 2+ персонажа с 2+ критическими потребностями (или 1, если
   город маленький) при кулдауне 5 ходов → `disease_outbreak`, снижает `rest`/
   `belief`.
6. **Повышение учёных** (Спринт 7): баллы `scholar_points` → самый старый
   свободный последователь становится `SCHOLAR` (требует жилья особняка,
   `free_housing(SCHOLAR) > 0`). Состояние живёт на PopUnit.

Сигналы: `character_born`, `character_died`, `character_need_critical`,
`disease_outbreak`.

---

## Тесты

`tests/test_city_chains.gd` (цепочки/production), `test_city_system.gd`
(циклический приток со славой/сезоном/храмом), `test_demographic_processor.gd`,
`test_pop_unit.gd`, `test_city_housing.gd`, `test_city_processor.gd`,
`test_city_manager.gd`, `test_capacity.gd`.

---

## Известные особенности / уточнения

- **Атомарность цепочки:** при нехватке входов `execute()` возвращает `{}` и не
  списывает входы — ход «перескакивает» здание.
- **Лимит не блокирует приток:** `add_followers` возвращает переполнение, но
  не останавливает прибытие — разбор (распределение/найм) руками.
- **Рабочий здания ≠ рабочий тайла:** WorkerAssignment не привязан к клетке,
  legacy-рабочие на тайлах обрабатываются монолитом `City.process_turn`.
- **Ресурсы-«запасники»:** gold/scholar_points/инструменты накапливаются в
  `resource_ctx` под ёмкостью и тратятся цепочками/событиями, а не складом
  `City.storage` (последний — legacy-контур build-стоимостей).
- **`auto_resource_mult` / `upkeep_mult`:** множители фазы города, задаются
  `CityTurnProcessor` (M3) — зависят от масштаба/процветания.

[1 more lines in file. Use offset=199 to continue.]
