# Документация проекта

Индекс документации **Sigil of the Unwilling** (Godot 4.7, hex strategy).
Все документы лежат в этой папке плоско (`docs/*.md`).

> ⚠️ **Документация активно дополняется.** Разделы «системы» (world, city, hero,
> бой, save/load) покрыты не полностью — см. список пробелов внизу. Если вы
> добавляете фичу, обновите или создайте соответствующий документ.

Перед правкой кода читайте **[`ARCHITECTURE.md`](ARCHITECTURE.md)** — там описаны
слои и запреты между модулями.

---

## 🗂 Области

### Overview / Концепция
Общее представление о игре, источник и дорожная карта.

- [`CONCEPT_GAME.md`](CONCEPT_GAME.md) — полная концепция «Знак Нежелавших».
- [`CONCEPT_HYBRID.md`](CONCEPT_HYBRID.md) — гибридный синтез (Endless Legend + Lords of Magic).
- [`CONCEPT_ENDLESS_LEGEND.md`](CONCEPT_ENDLESS_LEGEND.md) — концепт системы управления империей.
- [`CONCEPT_ENDLESS_LEGEND_ANALYSIS.md`](CONCEPT_ENDLESS_LEGEND_ANALYSIS.md) — технический анализ референса.
- [`CONCEPT_LORDS_OF_MAGIC.md`](CONCEPT_LORDS_OF_MAGIC.md) — храмы и последователи.
- [`ASSET_PIPELINE.md`](ASSET_PIPELINE.md) — обзор ассетов и pipeline.
- [`PLAN_MASTER.md`](PLAN_MASTER.md) — мастер-план разработки.
- [`TASK.md`](TASK.md) — список задач и roadmap.

### Architecture
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — слои, координаторы, запреты между модулями (читать первым).

### Systems (игровые системы)
Покрыто не полностью — см. «Пробелы» ниже.

- **Бой / Магия**
  - [`battle_spells.md`](battle_spells.md) — боевые заклинания, быстрая архитектура боя.
  - [`spells_system.md`](spells_system.md) — система заклинаний в целом (данные, шаблоны, валидатор).
  - [`magic_runtime.md`](magic_runtime.md) — исполнение заклинаний в момент каста: SpellResolver, TemplateEngine, SpellCaster, BattleSpellBridge, свитки.
- **Экономика**
  - [`ECONOMY_DATA.md`](ECONOMY_DATA.md) — экономические данные игры.
  - [`ECONOMY_BALANCE.md`](ECONOMY_BALANCE.md) — экономика и баланс.
  - [`economy_runtime.md`](economy_runtime.md) — исполнение экономики в ходу:
    ResourceContext, ProductionChain, EconomicTurnProcessor, WorkerAssignment,
    приток последователей, здания, DemographicTurnProcessor.
- **Тайлы / Биомы**
  - [`BIOME_SYSTEM.md`](BIOME_SYSTEM.md) — биомы, текстуры и тайлкеты.
- **Герой**
  - [`hero_system.md`](hero_system.md) — фасад героя: движение, армия, ресурсы, магия, навыки.
- **Инвентарь**
  - [`inventory_system.md`](inventory_system.md) — экипировка по слотам + рюкзак, оценка оборудования (AC/урон/криты, NWN2/D&D 3.5).
  - [`inventory_items.md`](inventory_items.md) — каталог артефактов (воин / лучник / маг) и их эффекты.
- **Город**
  - [`city_system.md`](city_system.md) — модель города, население, ход города, подсистемы.
- **Мир / Приключения**
  - [`world_adventure.md`](world_adventure.md) — bootstrap мира, карта, оркестрация хода, роутер событий.
- **Бой**
  - [`battle_system.md`](battle_system.md) — слои боя, BattleState, резолверы, порядок ходов, AI, интеграция с миром.
- **Сохранение**
  - [`save_load.md`](save_load.md) — 3 уровня: JSON-менеджер, SaveData, WorldPersistence.

### How-to / Tooling
- [`ADDING_UNITS.md`](ADDING_UNITS.md) — как добавить нового юнита.
- [`ADDING_TERRAINS.md`](ADDING_TERRAINS.md) — как добавить новый биом/террейн.
- [`TESTING.md`](TESTING.md) — headless-запуск сцен и тестов.
- [`TOOLS.md`](TOOLS.md) — инструменты разработки (CI, ассет-пайплайн, линтеры).

### Concepts (исследовательские)
- [`CONCEPT_BUILDING_SYNERGY.md`](CONCEPT_BUILDING_SYNERGY.md) — взаимосвязи построек (TerraScape-скоринг).
- [`CONCEPT_ECONOMIC_SYNERGY.md`](CONCEPT_ECONOMIC_SYNERGY.md) — экономическая синергия (анализ Endless Legend).
- [`CONCEPT_SOCIAL_RACES.md`](CONCEPT_SOCIAL_RACES.md) — социальная составляющая и расы.
- [`TASK_SOCIAL_AND_BUILDINGS.md`](TASK_SOCIAL_AND_BUILDINGS.md) — задачи по социалке и постройки.

### Misc / Research
- [`binomials.md`](binomials.md) — механика биномиев.
- [`GRAPH_KNOWLEDGE.md`](GRAPH_KNOWLEDGE.md) — knowledge graph и связи данных.

---

## 🕳 Пробелы в документации (нужно написать)

Большинство центральных систем уже документированы (world, city, hero, inventory,
battle, save/load, spells, economy). Остаются более узкие/перспективные разделы:

- **Город: подсистемы хода** — Arena, Zoning, Specialization, Logistics,
  Market, Reputation, Prosperity, Raid (`city/`), подробнее, чем в `city_system.md`.
- **Battle (общее)** — общий архитектурный обзор боя (не только заклинания).

Как написать документ: кратко, точно под текущий код, без выдумок. Если системный
документ создаётся впервые — положите его в `docs/` и обновите этот индекс.
