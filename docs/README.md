# Документация проекта

Индекс документации **Sigil of the Unwilling** (Godot 4.7, hex strategy).
Документы разложены по областям-подпапкам: `docs/{architecture,concepts,systems,howto,misc}/`.

> ⚠️ **Документация активно дополняется.** Разделы «системы» (world, city, hero,
> бой, save/load) покрыты не полностью — см. список пробелов внизу. Если вы
> добавляете фичу, обновите или создайте соответствующий документ.

Перед правкой кода читайте **[`ARCHITECTURE.md`](architecture/ARCHITECTURE.md)** — там описаны
слои и запреты между модулями.

---

## 🗂 Области

### Overview / Концепция
Общее представление о игре, источник и дорожная карта.

- [`CONCEPT_GAME.md`](overview/CONCEPT_GAME.md) — полная концепция «Знак Нежелавших».
- [`CONCEPT_HYBRID.md`](overview/CONCEPT_HYBRID.md) — гибридный синтез (Endless Legend + Lords of Magic).
- [`CONCEPT_ENDLESS_LEGEND.md`](overview/CONCEPT_ENDLESS_LEGEND.md) — концепт системы управления империей.
- [`CONCEPT_ENDLESS_LEGEND_ANALYSIS.md`](overview/CONCEPT_ENDLESS_LEGEND_ANALYSIS.md) — технический анализ референса.
- [`CONCEPT_LORDS_OF_MAGIC.md`](overview/CONCEPT_LORDS_OF_MAGIC.md) — храмы и последователи.
- [`ASSET_PIPELINE.md`](overview/ASSET_PIPELINE.md) — обзор ассетов и pipeline.
- [`PLAN_MASTER.md`](overview/PLAN_MASTER.md) — мастер-план разработки.
- [`TASK.md`](overview/TASK.md) — список задач и roadmap.

### Architecture
- [`ARCHITECTURE.md`](architecture/ARCHITECTURE.md) — слои, координаторы, запреты между модулями (читать первым).
- [`CORE_TURN_PIPELINE.md`](architecture/CORE_TURN_PIPELINE.md) — ядро хода: `TurnContext`, `TurnScheduler`, `TurnPhaseProcessor`, `GameSession` (детерминизм/seed), `Platform` (headless), `GameEventBus`, `GameLogger`, `ServiceContainer`/`ServiceLocator`, направления зависимостей.

### Systems (игровые системы)
Покрыто не полностью — см. «Пробелы» ниже.

- **Бой / Магия**
  - [`battle_spells.md`](systems/battle_spells.md) — боевые заклинания, быстрая архитектура боя.
  - [`spells_system.md`](systems/spells_system.md) — система заклинаний в целом (данные, шаблоны, валидатор).
  - [`magic_runtime.md`](systems/magic_runtime.md) — исполнение заклинаний в момент каста: SpellResolver, TemplateEngine, SpellCaster, BattleSpellBridge, свитки.
- **Экономика**
  - [`ECONOMY_DATA.md`](economy/ECONOMY_DATA.md) — экономические данные игры.
  - [`ECONOMY_BALANCE.md`](economy/ECONOMY_BALANCE.md) — экономика и баланс.
  - [`economy_runtime.md`](economy/economy_runtime.md) — исполнение экономики в ходу:
    ResourceContext, ProductionChain, EconomicTurnProcessor, WorkerAssignment,
    приток последователей, здания, DemographicTurnProcessor.
- **Тайлы / Биомы**
  - [`BIOME_SYSTEM.md`](systems/BIOME_SYSTEM.md) — биомы, текстуры и тайлкеты.
- **Герой**
  - [`hero_system.md`](systems/hero_system.md) — фасад героя: движение, армия, ресурсы, магия, навыки.
- **Инвентарь**
  - [`inventory_system.md`](systems/inventory_system.md) — экипировка по слотам + рюкзак, оценка оборудования (AC/урон/криты, NWN2/D&D 3.5).
  - [`inventory_items.md`](systems/inventory_items.md) — каталог артефактов (воин / лучник / маг) и их эффекты.
- **Город**
  - [`city_system.md`](systems/city_system.md) — модель города, население, ход города, подсистемы.
- **Мир / Приключения**
  - [`world_adventure.md`](systems/world_adventure.md) — bootstrap мира, карта, оркестрация хода, роутер событий.
- **Бой**
  - [`battle_system.md`](systems/battle_system.md) — слои боя, BattleState, резолверы, порядок ходов, AI, интеграция с миром.
- **Сохранение**
  - [`save_load.md`](systems/save_load.md) — 3 уровня: JSON-менеджер, SaveData, WorldPersistence.
- **Интерфейс (UI)**
  - [`UI_AUDIT.md`](systems/UI_AUDIT.md) — аудит динамического UI: классификация панелей
    (статический скелет / динамический список / гибрид), приоритет перевода на `.tscn`,
    палитра/стили и геометрия окон. Основа цикла `ui-scenes`.

### How-to / Tooling
- [`ADDING_UNITS.md`](howto/ADDING_UNITS.md) — как добавить нового юнита.
- [`ADDING_TERRAINS.md`](howto/ADDING_TERRAINS.md) — как добавить новый биом/террейн.
- [`TESTING.md`](howto/TESTING.md) — headless-запуск сцен и тестов.
- [`TOOLS.md`](howto/TOOLS.md) — инструменты разработки (CI, ассет-пайплайн, линтеры).

### Concepts (исследовательские)
- [`CONCEPT_BUILDING_SYNERGY.md`](concepts/CONCEPT_BUILDING_SYNERGY.md) — взаимосвязи построек (TerraScape-скоринг).
- [`CONCEPT_ECONOMIC_SYNERGY.md`](concepts/CONCEPT_ECONOMIC_SYNERGY.md) — экономическая синергия (анализ Endless Legend).
- [`CONCEPT_SOCIAL_RACES.md`](concepts/CONCEPT_SOCIAL_RACES.md) — социальная составляющая и расы.
- [`CONCEPT_POPULATION_RUNTIME.md`](concepts/CONCEPT_POPULATION_RUNTIME.md) — соц. составляющая TerraScape-прототипа в ходу: потребности (cap/demand/ok), мораль/Resolve, штормы, караваны, репутация.
- [`CONCEPT_MERGE_AUTO_4.md`](concepts/CONCEPT_MERGE_AUTO_4.md) — авто-слияние ×4 (BFS связного компонента, «здание II» _BIG, переселение работников, триггер в цикле размещения). Отдельно от рецептурного слияния.
- [`CONCEPT_CHARACTER_SYSTEM.md`](concepts/CONCEPT_CHARACTER_SYSTEM.md) — единые 8 характеристик, 31 навык, производные характеристики (формулы), модификаторы/генерация/архитекция эффектов.
- [`CONCEPT_ABILITIES.md`](concepts/CONCEPT_ABILITIES.md) — единый список 134 способностей (48 черт/70 перков/16 особых) — вынесен из `CONCEPT_CHARACTER_SYSTEM.md` как справочный блок.
- [`TASK_SOCIAL_AND_BUILDINGS.md`](concepts/TASK_SOCIAL_AND_BUILDINGS.md) — задачи по социалке и постройки.
- [`TASK_BUILDING_SCORING_GODOT47.md`](concepts/TASK_BUILDING_SCORING_GODOT47.md) — самодостаточное ТЗ: размещение зданий, радиальный скорнинг, слияние (GridManager/ScoringManager/MergeSystem, сборка в Godot Editor).

### Misc / Research
- [`binomials.md`](misc/binomials.md) — механика биномиев.
- [`GRAPH_KNOWLEDGE.md`](misc/GRAPH_KNOWLEDGE.md) — knowledge graph и связи данных.
- [`audit-docs-tests-2026-08-31.md`](misc/audit-docs-tests-2026-08-31.md) — однократный аудит документации и тестов (2026-08-31): findings + рекомендации (исправление — отдельный change).

---

## 🕳 Пробелы в документации (нужно написать)

Большинство центральных систем уже документированы (world, city, hero, inventory,
battle, save/load, spells, economy). Покрыто также: подсистемы хода города
(`city_system.md` §80) и общий архитектурный обзор боя (`battle_system.md`).

Остаются более узкие разделы (приоритет по охвату кода):

- **UI-слой (19 файлов)** — `WorldUIManager`, `ArmyPanel`, `CityPanel`, `BattleUI`,
  `ResourceBar`, `SkillsPanel` и др. Полностью undocumented.
- **Стоимость перемещения по местности** — `TerrainCostTable` (OD-затраты по террейнам,
  левитация, зарезервированные тайлы); питает Dijkstra в `HeroMovementController`.
- **Статусы/состояния** — наложение/истечение/приоритет эффектов статуса (связано с
  `battle_spells.md` / `magic_runtime.md`).
- **Визуал юнитов** — `UnitSprites` (мелко, возможно относится к `ASSET_PIPELINE.md`).

Как написать документ: кратко, точно под текущий код, без выдумок. Если системный
документ создаётся впервые — положите его в `docs/` и обновите этот индекс.

> ⚠️ Все ссылки в этом индексе проверены: битых не найдено.
