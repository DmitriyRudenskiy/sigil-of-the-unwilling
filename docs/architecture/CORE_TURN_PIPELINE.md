# Ядро: цикл хода, контекст, детерминизм, сервисы

Сквозной слой `game/core/`, общий для мира, боя, экономики, демографии и города.
Не привязан к узлам сцены: весь ядро — `RefCounted`-объекты (кроме шины
`GameEventBus`, которая является `Node`-autoload). Читается перед правкой любой
подсистемы, зависящей от хода/состояния/тестов.

Связан с: [`ARCHITECTURE.md`](ARCHITECTURE.md) (слои и запреты),
[`world_adventure.md`](../systems/world_adventure.md) (bootstrap мира, оркестрация хода,
роутер событий), [`economy_runtime.md`](../economy/economy_runtime.md) (фаза экономики),
[`CONCEPT_POPULATION_RUNTIME.md`](../concepts/CONCEPT_POPULATION_RUNTIME.md) (фаза демографии).

---

## 1. Компоненты ядра

| Класс | Роль | Зависит от узлов? |
| --- | --- | --- |
| `TurnContext` | Состояние хода: дата/сезон/погода, срезы мира (`cities`/`heroes`), `global_resources`, очередь событий, RNG. | нет (`RefCounted`) |
| `TurnScheduler` | Оркестратор фаз: пробегает процессоры по возрастанию приоритета, собирает отчёт. | нет |
| `TurnPhaseProcessor` | Базовый класс фазы хода (контракт: `phase_id` / `priority` / `process(ctx)`). | нет |
| `GameSession` | Единый источник `run_seed` и производных RNG (детерминизм сессии). | нет |
| `Platform` | Абстракция окружения: headless / test-server / auto-quit. | нет |
| `GameEventBus` | Глобальная шина кросс-системных событий (autoload `GameEventBus`). | да (`Node`) |
| `GameLogger` | Структурное логирование с тегами и цветами через `print_rich`. | нет |
| `ServiceContainer` | Контейнер сервисов (реестры + системные сервисы), инъекция в подсистемы. | нет |
| `ServiceLocator` | Резолвер сервисов: инжект → `ServiceContainer` → autoload. | нет |

## 2. Цикл хода (turn pipeline)

Ход — это цепочка **фаз**, каждая фаза = отдельный процессор. Планировщик
пробегает фазы по возрастанию `priority` (меньше = раньше) и собирает итоговый
отчёт.

```text
WorldEventRouter._on_end_turn()
        │  (ПОСЛЕ монолита City.process_turn)
        ▼
TurnScheduler.execute_turn(ctx)
        │  1) _turn += 1; ctx.turn_number = _turn
        │  2) ctx.season = Season.from_month(ctx.month)
        │  3) ctx.weather = CLEAR, если < 0
        │  4) для каждого processora (сортировка по priority):
        │        report[phase_id] = proc.process(ctx)
        ▼
{"turn": n, "phases": { <phase_id>: <report> }}
```

**Контрат фазы** (`TurnPhaseProcessor`):

```gdscript
func get_phase_id() -> StringName: return &"economy"   # ключ в отчёте
func get_priority() -> int:     return 10             # порядок (меньше = раньше)
func process(ctx: TurnContext) -> Dictionary:         # отчёт фазы (может пустой)
```

**Принципы фаз:**

- Процессоры **не зависят от узлов Godot** и **не ходят на глобальную шину**
  (`GameEventBus`). Внешние эффекты (UI, шины) пробрасывает интеграционный слой
  (`WorldBootstrap` / `WorldEventRouter`). Это позволяет гонять каждую фазу в
  изолированных headless-тестах.
- **Порядок интеграции:** `WorldBootstrap` создаёт `TurnScheduler`, регистрирует
  процессоры (`city_proc` → `econ` → `demo`), но **вызывает `execute_turn()`**
  `WorldEventRouter` — *после* существующего монолита `City.process_turn`
  (`turn_ended` → `CityManager.on_turn_ended`). Так новые фазы видят уже актуальное
  состояние (рождения, склад и т.п.).
- **Регистрация** (`WorldBootstrap`): `register_processor(city_proc)`,
  `register_processor(econ)`, `register_processor(demo)`. Порядок вызова
  значения не имеет — сортировка по `priority`.

**Сигналы `TurnScheduler`:** `turn_started(turn)`,
`phase_completed(phase_id, report)`, `turn_completed(turn, report)`.

**Приоритеты фаз** (из интеграции и кода): фаза города — **5** (раньше всех),
экономика — **10**, демография — **20** (позже всех). Порядок: город →
экономика → демография (см. `economy_runtime.md` /
`CONCEPT_POPULATION_RUNTIME.md`).

## 3. TurnContext — что передаётся в фазы

`TurnContext` (RefCounted) — «срезы» мира + состояние времени. Процессоры
**читают** мир через `ctx`, мутация допустима только через публичные API сущностей.

| Поле | Тип | Назначение |
| --- | --- | --- |
| `turn_number` | `int` | Номер хода (ставится планировщиком) |
| `month` / `week` / `day` | `int` | Календарь |
| `season` | `int` (`Season.ID`) | Пересчитывается из `month` (`Season.from_month`) |
| `weather` | `int` (`GameSettings.WEATHER_*`) | По умолчанию CLEAR |
| `cities` | `Array[City]` | Города мира (срединка из `CityManager`) |
| `heroes` | `Array` | Герои (не типизированно — entities-слой не должен зависеть от core) |
| `global_resources` | `Variant` | Глобальное хранилище ресурсов (M1). `null` до инициализации экономики |
| `event_queue` | `Array[Dictionary]` | События хода; процессоры кладут сюда для обработки последующими фазами / интеграционным слоем |
| `rng` | `RandomNumberGenerator` | RNG для недетерминированных фаз. `null` = процессор сидирует сам (воспроизводимо по `(ход, сущность)`) |

`get_date_label()` → «день N (day/week/month)».

**Политика RNG (детерминизм):** если `ctx.rng == null`, процессор (напр.
`DemographicTurnProcessor`) выводит детерминированный сид из
`(turn_number, uid сущности)`. Это даёт воспроизводимость фазы без глобального
состояния.

## 4. GameSession — источник детерминизма

`GameSession` (RefCounted) — единый источник истины для `run_seed` и производных
RNG.

```gdscript
func _init(seed_value: int = -1)     # -1 → сид из системного времени
func next_seed() -> int              # выжигает новое семя из main RNG
func make_rng() -> RandomNumberGenerator  # независимый дочерний RNG для подсистемы
```

**Связь с сохранением:** `run_seed` персистится в `SaveData.run_seed`
(валидация `run_seed > 0` в `SaveManager`), поэтому загруженная игра
воспроизводит исходную последовательность. В инструментах
(`benchmark_all.gd`, `memory_profile.gd`) `run_seed` жёстко ставится (=12345)
для сравнительных прогонов.

> В текущем turn-контексте детерминизм фаз обеспечивается политикой из §3
> (`ctx.rng` / сид от `(ход, сущность)`); `GameSession` — более высокий уровень
> (сессия в целом), сейчас используется в сохранениях/инструментах.

## 5. Platform — абстракция окружения

`Platform` (RefCounted, static) — единое место, где проверяется окружение.
Заменил разбросанные `OS.has_feature("headless")`.

| Метод | Логика |
| --- | --- |
| `is_headless()` | `DisplayServer.get_name() == "headless"` (в Godot 4.7 `OS.has_feature("headless")` **не** вернёт `true` для `--headless`) |
| `is_test_server()` | есть аргумент `--test-server` в `OS.get_cmdline_args()` |
| `should_auto_quit()` | есть аргумент `--autoquit` |

Используется в `Settings`, `SoundManager`, `WorldController`, `HeroController`
для отключения анимаций/звука в headless и авто-выхода после прогонов.

## 6. GameEventBus — шина кросс-системных событий

`Node`-autoload. Через неё проходят **все** кросс-системные события; процессоры
сами по себе на шину не ходят — её триггерят интеграционные слои. Группы:

- **Бой:** `battle_started`, `battle_completed`, `battle_won/lost`.
- **Мир:** `village_captured`, `turn_ended(turn, month)`.
- **Ресурсы:** `resource_discovered/extracted/exhausted`.
- **Слава:** `glory_earned(amount, reason)`.
- **Экономика (M1):** `production_completed`, `resource_depleted`, `upkeep_failed`.
- **Демография (M2):** `character_born/died`, `character_need_critical`, `disease_outbreak`.
- **Город (M3+M6):** `building_constructed`, `scale_shift`, `zone_violation`,
  `reputation_changed`, `migration_occurred`, `city_level_up`, `raid_occurred`,
  `trade_completed`, `city_event_occurred`, `relocation_completed`.
- **Нарратив (M5):** `chronicle_entry_added`, `weather_changed`, `faith_milestone`.

## 7. GameLogger — логирование

`RefCounted`, static-методы с тегом (ширина 14) и цветами через `print_rich`:
`info` / `warn` (`push_warning`) / `error` (`push_error`) / `trace` (только в
debug-билдах). Есть тематические обёртки: `battle`, `world`, `inventory`, `ui`,
`hero`.

## 8. Инъекция зависимостей: ServiceContainer + ServiceLocator

**`ServiceContainer`** — единый контейнер сервисов. Создаётся в `WorldBootstrap`
(`setup_global`) / `BattleController`, передаётся в подсистемы через `setup()`:

```gdscript
var services := ServiceContainer.new()
services.units = UnitRegistry      # autoload «Units»
services.resources = ResourceRegistry
services.spells = SpellRegistry
services.artifacts = ArtifactRegistry
services.spellbook = SpellbookRegistry
services.settings = Settings
services.event_bus = GameEventBus
my_system.setup(services)
```

Поля: реестры (`units`/`resources`/`spells`/`artifacts`/`spellbook`) + системные
сервисы (`settings`/`event_bus`). `validate()` возвращает массив пропущенных
критичных сервисов.

**`ServiceLocator`** — резолвер «инъекция → `ServiceContainer` → autoload»:
если передан инжект — он и возвращается; иначе берётся из
`ServiceContainer.current`; иначе по имени autoload (`_AUTOLOAD`).
Заменил дублирующиеся `_get_*_registry()`-функции.

**Обратная совместимость:** `ServiceContainer.current` — глобальный доступ
«немибилизованного» кода:
`ServiceContainer.current.resources.get_resource(id)`.

## 9. Направления зависимостей (запреты)

- **entities / city / economy / demographics НЕ зависят от `core/` напрямую** в
  фазовых процессорах: они получают мир через `TurnContext` (варианты `City`/
  `Variant` намеренно нетипизированы) и сервисы через `setup()`/`ServiceLocator`.
- **Ядро (`core/`) не зависит от визуала** (`ui/`, `assets/`) и от тяжёлой логики
  подсистем.
- **Фаза-процессор не ходит на `GameEventBus`** — эффекты пробрасывает интеграция.
- Визуал (`BattleView`, `HeroVisualController`) не меняет игровое состояние.

## 10. Тесты

`tests/test_turn_scheduler.gd` — приоритеты фаз, дубликаты/`null`-проверки,
сигналы, `execute_turn(null)`. Изолированные прогоны фаз:
`test_economic_processor.gd`, `test_city_processor.gd`,
`test_demographic_processor.gd` (каждая строит свой `TurnScheduler` и регистрирует
нужные процессоры). Детерминизм семла/сохранений: `test_save_roundtrip.gd`,
`test_save_v3.gd`, `test_applied_fixes.gd` (одинаковый `run_seed` → одинаковые
спеллы).
