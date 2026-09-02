# Дизайн: города мира — захват, управление, доход, последователи

## Контекст (состояние кода на момент дизайна)

- **Захват деревни** сегодня: `WorldEventRouter._on_village(cell)` →
  `WorldInteractionController.capture_village_at(cell)` (возвращает `void`) →
  `WorldSpawner.capture_village(cell)` (флаг 🚩→🏳️ на клетке) +
  `world_delta.add_village(cell)`. Объект `City` **не создаётся**;
  `ui_manager.ui.add_city(...)` кладёт город в «карту городов» UI, но без модели.
- **Столица** создаётся при бутстрапе (`WorldBootstrap`, `CityManager.register_city`
  → `uid = cities.size()` — порядок регистрации важен для save).
- **City-движок готов**: `City.process_turn`, `CityTurnProcessor` (priority 5,
  `&"city"`), `EconomicTurnProcessor` (priority 10, `&"economy"`, работает через
  `city.resource_ctx`: цепочки зерно→мука→хлеб, руда→инструменты, таверна/торговля→
  золото, upkeep), `DemographicTurnProcessor` (priority 20). `TurnScheduler.execute_turn(ctx)`
  в мире уже выполняется из `WorldEventRouter._on_end_turn` — `ctx.cities` содержит ВСЕ
  города (`CityManager.cities`).
- **Песочница `CityArena`**: `CityArenaModel` (статика, `game/scripts/city/`) +
  `CityArenaView` (522 строки: гексы Polygon2D + Area2D-кликеры, палитра 12 зданий,
  tooltip, HUD, auto-режим, score, своя Camera2D). Модель города арены — тот же `City`.
- **Ресурсы UI**: `ResourcesPanel` (в `AdventureUI`, т.е. `WorldUIManager.ui`)
  показывает **стратегические** ресурсы героя (`HeroStrategicResources`) и уже
  подписан на `strategic_resources_changed`. `hero.add_strategic_resource(id, n)`
  сам обновит панель. `ResourceBar` — legacy-ресурсы (не цель).
- **CityManager**: `set_tile_yield_provider(fn)` применяет провайдер только к городам,
  существующим на момент вызова → **новые (захваченные) города остаются без
  `tile_yield_fn`** — дефект, нужно чинить. Метода `city_at(cell)` нет.
- **`City.serialize/deserialize`**: serialize содержит `display_name`, но deserialize
  его **не восстанавливает** (дефект). `owner`/garrison отсутствуют.
- **Terrain**: `HexUtils.Terrain { WATER=0, SWAMP=1, SAND=2, GRASS=3, FOREST=4,
  MOUNTAIN=5, SNOW=6 }`; `MapGenerator.get_terrain_id(cell)` (делегация `MapModel`).
- **Последователи**: класса `Follower` нет. У `HeroController` нет списка последователей.
  `PopUnit` (состояния WORKER/FOLLOWER/MILITIA/SCHOLAR) — население города;
  `City.free_followers()` — свободные FOLLOWER-юниты. `TraitRegistry` — реестр черт
  (autoload, instance-методы `roll_traits(rng, n)`, `get_trait(id)`).
- **Вход**: `WorldInput._unhandled_input` (движение героя), `WorldShortcuts._unhandled_input`
  (I/F5/F9/Esc) — оба уже имеют «battle guard» (`is_world_visible`) как образец для
  overlay guard. Сигналы: `hero_moved` эмитится в `HeroMovementController` ДО
  `hero_entered_village` (строка ~422) — порядок важен для захвата.
- **Save**: `WorldPersistence._restore_cities` предполагает, что города уже
  пересозданы (матч по uid из `save.cities[i].uid`); ре-крейтовать захваченные города
  из `WorldStateDelta.captured_villages` — наша задача. `WorldController.save_game()`
  уже сериализует `cities.cities` + персонажей.
- **Тесты**: `game/tests/run_tests.gd` автособирает `test_*.gd` (sync, headless,
  `--filter/--tag`); async-тесты сцены — в `SKIP_FILES` + `godot -s`.
- **Сцены**: `World.tscn` и `CityArena.tscn` — минимальные script-stubs; композиция
  узлами в коде (не редактируем tscn).

## Цели

1. Захват деревни создаёт персистентный `City` (реестр `CityManager`).
2. Игрок заходит в город (герой на клетке) и управляет им через переиспользуемый
   экран `CityScreen` (общий для арены и мира).
3. Выходы клеток — из реального terrain (детерминированная таблица).
4. Доход городов → стратегические ресурсы игрока, виден в `ResourcesPanel`.
5. Нанятые последователи — именованные индивиды, выходящие из населения города.
6. Владелец и гарнизон города персистентны.
7. Песочница `CityArena` сохраняется как есть.

## Не-цели

- Падение/потеря городов (рейды уже считаются через `defense_strength`, но
  mechanics захвата врагами — отдельный change).
- Реальная система путей героя: `Follower.path` — заготовка
  (`&"unaligned"`, персистентное поле).
- Редактирование `.tscn` (композиция — в коде).

## Решения

### 1. Захват: `capture_village_at -> bool` + фабрика города

**`WorldInteractionController.capture_village_at(cell) -> bool`** (было `void`):
true только если `WorldSpawner.capture_village(cell)` реально переключил флаг
(клетка была деревней и не захвачена).

**`WorldEventRouter._on_village(cell)`** — новый порядок:

```gdscript
var city: City = cities.city_at(cell)          # повторный заход в захваченную
if city == null:
    if interaction_controller.capture_village_at(cell):
        city = CityFactory.create_village(cell, name_for(cell), seed)
        cities.register_city(city)             # uid + yield-провайдер (см. п. 2)
        world_delta.add_village(cell)
        ui_manager.ui.add_city(...)            # как сейчас
        village_captured.emit(cell)
if city != null:
    ui_manager.open_city_screen(city, hero.current_cell)
```

**Вход в любой город** (в т.ч. столица — она не в `village_cells`):
`_on_hero_moved` в конце проверяет `cities.city_at(hero.current_cell) != null` →
открывает экран. Для свежезахваченной деревни этот check отработает ДО захвата
(`hero_moved` раньше `hero_entered_village`), поэтому дублирующий open в
`_on_village` обязателен (см. выше). Экран идемпотентен: если уже открыт для
этого города — не пересоздаётся.

**`CityFactory`** — новый `game/scripts/world/CityFactory.gd` (static, RefCounted):

- `create_village(center, display_name, seed) -> City`:
  `City.new()`; `center`, `display_name`, `owner = &"player"`, `stronghold_level = 1`;
  `storage[&"industry"] = CityBalance.VILLAGE_START_INDUSTRY`;
  `food_stockpile = CityBalance.VILLAGE_START_FOOD`;
  `ensure_resource_ctx()` + `resource_ctx.add(&"gold", CityBalance.VILLAGE_START_GOLD)`;
  `VILLAGE_START_WORKERS` × `add_migrant(WORKER)` с **детерминированной** расстановкой
  на свободные клетки-соседи центра (порядок `HexUtils.get_all_neighbors` фиксирован;
  проверка `is_worker_tile_free`).
- `village_name(seed, cell) -> String`: имя из статической таблицы (~16 имён) по
  индексу `hash([seed, cell.x, cell.y])` — одинаковое для захвата и рестора с сейва.

**Столица**: в `WorldBootstrap` после создания — `capital.owner = &"player"`.

**MapModel не трогаем** (решение от 2026-07-04 подтверждено): деревня остаётся
«входимой» клеткой — повторный заход ре-открывает экран; визуальный маркер — флаг
спавнера 🏳️. Source of truth «город на клетке» — `CityManager.city_at`.

### 2. `CityManager`: фикс провайдера + `city_at`

- `set_tile_yield_provider(fn)`: хранить в `var _tile_yield_provider: Callable`;
  применять к существующим городам **и в `register_city`** к новым (чинит gap:
  захваченные после бутстрапа города сейчас остаются без `tile_yield_fn`).
- `city_at(cell: Vector2i) -> City`: первый город с `center == cell`, иначе null.

### 3. Выходы клеток из terrain

**`game/scripts/world/CityYieldTable.gd`** (static, только данные):
`yield_for_terrain(terrain_id: int) -> Dictionary` с ключами FIDSI
(`food/industry/dust/studying/influence`). Стартовые значения (одна точка тюнинга):

| terrain    | food | industry | dust | influence |
|------------|------|----------|------|-----------|
| water      | 0    | 0        | 0    | 0         |
| swamp      | 1    | 1        | 0    | 0         |
| sand       | 0    | 1        | 0    | 0         |
| grass      | 3    | 2        | 0    | 0         |
| forest     | 1    | 2        | 0   | 0         |
| mountain   | 0    | 3        | 1    | 0         |
| snow       | 1    | 0        | 0    | 0         |

`science` не генерируется terrain'ом (даётся училищем) — ключ присутствует с 0.

**`WorldBootstrap._make_tile_yield_provider`**: заменяем заглушку
(`{food:5, industry:5}`) на
`func(cell): return CityYieldTable.yield_for_terrain(map_gen.get_terrain_id(cell))`.
Песочница арены не использует этот провайдер (есть собственный `ArenaBalance`) —
незатронута.

### 4. Доход: `CityIncomeProcessor` + дань золотом

`City` получает `var owner: StringName = &"none"` (+serialize/deserialize,
аддитивно; старые сейвы → `&"none"`). Столица и захваченные деревни —
`&"player"`.

**`game/scripts/economy/CityIncomeProcessor.gd`** — новый
`TurnPhaseProcessor`, `phase_id = &"city_income"`, **priority 15**
(после economy 10, до demographics 20). `process(ctx)`:

- для каждого `city in ctx.cities` с `owner == &"player"` и `resource_ctx != null`:
  `royalty = int(floor(city.resource_ctx.amount(&"gold") * CityBalance.ROYALTY_FRACTION))`;
  если `> 0` → `city.resource_ctx.remove(&"gold", royalty)`;
- отчёт: `{"total": {&"gold": N}, "per_city": [{"uid": u, "royalty": r}, ...]}`.

Регистрация в `WorldBootstrap._register_turn_phases`. Внешний эффект (перевод
ресурсов герою) — в интеграционном слое: `WorldEventRouter._on_end_turn` после
`execute_turn` читает отчёт фазы и вызывает `hero.add_strategic_resource(id, n)`
по каждому элементу `total` + `GameLogger.world("Дань городов: +N gold")`. Панель
`ResourcesPanel` обновится сама (сигнал `strategic_resources_changed`).

Формула: **пропорциональный налог с казны города** (`resource_ctx` gold).
Почему не surplus FIDSI: FIDSI хранится в legacy `city.storage`, тратится на
строительство и не является «деньгами»; золото в `resource_ctx` — реальный
продукт цепочек (таверна, торговый пост). Начальное `VILLAGE_START_GOLD = 5`
даёт +1 gold уже в первый ход — доход виден сразу. Песочница: у города арены
`owner == &"none"` → фаза его пропускает (изоляция гарантирована).

Баланс-константы (`CityBalance`): `ROYALTY_FRACTION := 0.25`,
`VILLAGE_START_WORKERS := 4`, `VILLAGE_START_INDUSTRY := 30.0`,
`VILLAGE_START_GOLD := 5.0`, `VILLAGE_START_FOOD := 10.0`.

### 5. Последователи: `Follower` + найм из населения

**`game/scripts/entities/Follower.gd`** (RefCounted, без зависимостей от autoload):

```gdscript
var uid := 0
var name := ""
var race: StringName = &"human"      # заглушка до матрицы рас-классов
var path: StringName = &"unaligned"  # заглушка до системы путей героя
var trait_ids: Array = []            # StringName (TraitRegistry id)
```

`serialize()/deserialize()` — JSON-совместимо.

**`game/scripts/entities/FollowerSystem.gd`** (static):
- `make_follower(uid, name, trait_ids) -> Follower` — чистый конструктор (для тестов);
- `recruit(city: City, hero, rng, registry: Variant = null) -> Follower`:
  1. свободный `FOLLOWER`-юнит города (первый по uid среди `is_free_follower()`),
     иначе → null (UI показывает «Никого нанимать»);
  2. `city.pop.erase(u)` — население/гарнизон уменьшается (условие спеки);
  3. имя: таблица имён FollowerSystem, индекс `rng.randi_range` (rng — сид мира);
  4. черты: `registry.roll_traits(rng, 1..2)` (по умолчанию autoload `TraitRegistry`),
     в `Follower` — только `trait_ids`;
  5. `hero.followers.append(follower)`.

**`HeroController`**: `var followers: Array = []` + `serialize/deserialize`
(аддитивный ключ `"followers"`).

Экран города (мир) получает кнопку «Нанять» (см. п. 6) → `FollowerSystem.recruit`.

### 6. Экран города: извлечение `CityScreen`

**`game/scripts/ui/CityScreen.gd`** — `class_name CityScreen extends Node2D`:
переезжает из `CityArenaView` (гексы, Area2D-кликеры, палитра, tooltip, лог,
камера, refresh). Конфигурируется хостом:

```gdscript
setup(city: City, cfg: Dictionary)
# cfg:
#  palette: Array[[id, emoji, name]]
#  actions: Array[[label, Callable]]         # кнопки нижней панели
#  top_hud_fn: Callable (city) -> String     # строка верхнего HUD
#  tooltip_fn: Callable (city, cell) -> String
#  ring_color_fn: Callable (ring) -> Color   # arena: CityArenaModel.ring_color, мир: нейтральный
#  cell_feature_fn / clusters_fn: Callable   # опционально (arena-only), в мире не ставятся
#  build_fn: Callable (city, def, cell) -> Dictionary
#      # arena: CityArenaModel.place_building; мир (по умолчанию):
#      # city.can_build_building/build_building напрямую
#  upgrade_hero_cell: Vector2i               # arena: (-1,-1), мир: hero.current_cell
open() / close()  # видимость + включение/выключение своей Camera2D
```

Логика клика общая (работает на любом `City`): центр — не строится; постройка →
`_try_upgrade` (`can_upgrade_building(b, upgrade_hero_cell)`); район —
`can_build_borough/build_borough`; здание — `build_fn`. Тултип мира читает
`city.tile_yield_fn.call(cell)` (реальные выходы terrain).

**`CityArenaView`** становится тонким хостом: создаёт `CityScreen` (cfg с
`CityArenaModel`-wire'ом), держит state песочницы (turn counter, auto-timer,
starve, score HUD, кнопки «Ход/Авто/Нанять/Уровень/Заново/Меню»).
`CityArena.tscn` не меняется. Поведение арены — без изменений (тесты
`test_city_arena` + async `test_city_arena_view` проходят).

**Хост в мире** — `WorldUIManager` (Node, в дереве мира):
- `_init_city_screen()`: `CityScreen.new()`, добавляется как ребёнок
  `WorldUIManager` (Node2D-родитель), `visible = false` (headless — не создаётся).
  cfg: палитра — те же 12 записей; actions: «Нанять», «Уровень», «✕ Закрыть»;
  `tooltip_fn` — generic (terrain-выходы + здание/район); `top_hud_fn` —
  `🌾 еда (нетто) | 🏭 промышленность | 🪙 золото | 👥 население | уровень`.
- `open_city_screen(city, hero_cell)` / `close_city_screen()` /
  `city_overlay_open() -> bool` (идемпотентно).
- Mouse: в CanvasLayer UI CityScreen — full-rect Control с `mouse_filter = STOP`
  (глотает клики, `WorldInput._unhandled_input` их не видит); гексы-кликеры
  CityScreen — поверх карты.
- Camera: своя `Camera2D` включается при `open()` (позднее в дереве → становится
  current); при `close()` — выключается, мировой `Camera2D` возвращается (tree-order
  fallback).

### 7. Guard на вход (мир под оверлеем)

- `WorldShortcuts._unhandled_input`: если `ui_manager.city_overlay_open()` —
  только `Esc` закрывает экран; `I/F5/F9` блокируются.
- `WorldInput._unhandled_input`: если оверлей открыт — игнор клавиш движения
  (паттерн как у battle guard `is_world_visible`).
- `Esc` в `WorldShortcuts` проверяет город оверлей ПЕРЕД инвентарём.

### 8. Персистентность

- **`City.serialize`** + `"owner"`; **`deserialize`**: восстанавливать `owner`
  (дефолт `&"none"`) **и `display_name`** (фикс найденного дефекта: serialize
  содержит, deserialize игнорирует).
- **Гарнизон** — производный, не храним отдельно: `City.garrison_count() -> int`
  (= `count_state(MILITIA)`); в сейве ополчение уже персистентно через `pop`-массив.
  `defense_strength()` уже масштабирует оборону от ополчения + стен — условие
  спеки «границы масштабируют защиту» выполняется.
- **`HeroController`** + `followers` (п. 5).
- **`WorldPersistence._restore_cities`**: перед матчем по uid — ре-крейт:
  для каждой клетки `world_delta.captured_villages` (порядок = порядок захвата):
  если `cities.city_at(cell) == null` → `CityFactory.create_village(cell,
  CityFactory.village_name(run_seed, cell), run_seed)` + `cities.register_city`.
  Порядок uids совпадает с сейвом: столица (uid 0, бутстрап) → захваченные в
  порядке дельты. Затем существующий цикл `deserialize(save.cities[i])`.
  Имя детерминировано от `(run_seed, cell)` → совпадает с именем на момент захвата.
  Yield-провайдер ставится при `register_city` (п. 2) — к моменту load уже сохранён.

## Риски и митигация

| Риск | Митигация |
|------|-----------|
| Два Camera2D (мир + город): приоритет | CityScreen-камера включается только пока открыт; тест сценарием (открыл → закрыл → камера мира целая) |
| Оверлей проглатывает ввод, ломая save/inv | Guard'ы в `WorldShortcuts`/`WorldInput`; `Esc` всегда закрывает; F5 работает из мира без оверлея |
| Порядок uids при load не совпадёт с сейвом | Регистрация строго: столица (бутстрап) → дельта в порядке захвата; тест round-trip (п. 9) |
| Ретракт арены при извлечении CityScreen | Тонкий хост, cfg-инъекция, без изменений `CityArenaModel`; существующие тесты + async view-тест |
| Дань обнуляет казну и блокирует стройку | 25% (не 100%), казна в `resource_ctx` неограничена (capacity INF), золото растёт через цепочки; константа в `CityBalance` |
| Нанять при 0 свободных FOLLOWER | `recruit` → null, UI-сообщение; рост населения (`process_turn`) пополняет FOLLOWER |

## Тесты (plan)

- `test_city_yield_table.gd` — ключи ⊆ FIDSI; water → нули; pin значений grass/mountain.
- `test_city_income_processor.gd` — city owner `&"player"`, gold 10 → royalty 2,
  казна −2, total в отчёте; owner `&"none"` (арена) → пропуск.
- `test_city_persistence.gd` — round-trip `owner` + `display_name` (фикс);
  `CityFactory.village_name` детерминирован; гарнизон (MILITIA) переживает round-trip
  через `pop`; `city_at` + провайдер для города, зарегистрированного ПОСЛЕ
  `set_tile_yield_provider` (фикс).
- `test_follower.gd` — round-trip `Follower`; `recruit` убирает pop у города и
  кладёт в `hero.followers`; null при 0 свободных.
- `test_city_screen.gd` — `setup` строит гексы/палитру; клик по клетке строит
  (build_fn); tooltip fn вызывается.
- Интеграция: сценарий (scenario runner / operability): захватить деревню →
  открыть экран → построить → end turn → gold в `ResourcesPanel` вырос;
  save → load → город на месте, uid совпадает.
