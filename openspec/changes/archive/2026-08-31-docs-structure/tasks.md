## 1. Audit (baseline)
- [x] List all 26 docs; note area, one-line purpose, and any stale `scripts/…` refs.
- [x] Confirm `docs/` is untracked (`git ls-files docs/` empty).

## 2. Create `docs/README.md` index
- [x] Group docs into areas (architecture, overview, systems, economy, concepts, howto, reports) with one-line descriptions + links.
- [x] Note the "docs are being filled in" status.

## 3. Reorganize into area folders
- [x] Move docs into area folders (scripted, reversible working-tree change):
  - `docs/overview/` — CONCEPT_GAME/HYBRID/ENDLESS_LEGEND[_ANALYSIS]/LORDS_OF_MAGIC,
    ASSET_PIPELINE, PLAN_MASTER, TASK.
  - `docs/architecture/` — ARCHITECTURE, CORE_TURN_PIPELINE.
  - `docs/systems/` — battle_spells, spells_system, magic_runtime, hero_system,
    inventory_system, inventory_items, city_system, world_adventure, battle_system,
    save_load, BIOME_SYSTEM.
  - `docs/economy/` — ECONOMY_DATA, ECONOMY_BALANCE, economy_runtime.
  - `docs/concepts/` — CONCEPT_BUILDING_SYNERGY/ECONOMIC_SYNERGY/SOCIAL_RACES,
    CONCEPT_POPULATION_RUNTIME/MERGE_AUTO_4/CHARACTER_SYSTEM/ABILITIES,
    TASK_SOCIAL_AND_BUILDINGS, TASK_BUILDING_SCORING_GODOT47.
  - `docs/howto/` — ADDING_UNITS, ADDING_TERRAINS, TESTING, TOOLS.
  - `docs/misc/` — binomials, GRAPH_KNOWLEDGE.
  - `docs/README.md` остаётся корневым индексом (пути-ссылки обновлены скриптом).
- [x] Update cross-references: 86 внутренних markdown-ссылок перелинкованы
  (relpath от нового расположения), `AGENT.md` (lines 4, 90, 370–373) и
  `game/lair/README.md` (repo-relative `docs/…`) обновлены.
- [x] Verify no dangling `docs/…` link — автоматическая проверка 86 ссылок
  (разрешениеотносительно каждого файла): ✅ NO broken links.
- ✅ **Executed** (was previously ⏭️ Deferred): flat structure reverted to area
  folders per spec. Working-tree change only — not yet committed (awaiting commit).

## 4. Fix stale docs
- [x] `REPORT.md`: fix `scripts/…` → `game/…`, or mark as archived open-questions.
- [x] `ADDING_UNITS.md`: fix `scripts/…` → `game/…`.
- [x] Scan all docs for other stale paths; fix or flag.

## 5. Fill initial system-documentation gaps
- [x] Add/expand core-system docs (priority order, all done this cycle):
  - `docs/hero_system.md` — фасад героя, подсистемы, движение, армия, магия.
  - `docs/city_system.md` — модель города, население, ход города, подсистемы.
  - `docs/world_adventure.md` — bootstrap мира, карта, оркестрация хода, роутер.
  - `docs/battle_system.md` — слои боя, BattleState, резолверы, AI, поток.
  - `docs/save_load.md` — 3 уровня персистентности (SaveManager/SaveData/WorldPersistence).
- [x] Keep each doc concise and accurate to current code (facts verified against source).
- [x] **Follow-up: inventory** — `docs/inventory_system.md` — экипировка по слотам +
  рюкзак (`HeroInventory`), оценка оборудования AC/урон/криты (`EquipmentManager`,
  NWN2/D&D 3.5), артефакты (`Artifact`), UI, тесты. Индекс `docs/README.md` обновлён.
- [x] **Follow-up: magic (runtime)** — `docs/magic_runtime.md` — исполнение
  заклинаний в момент каста:
  city subsystems (Arena/Zoning/Specialization/Logistics/Market/Reputation),
  battle (general overview). See `spells_system.md` / `battle_spells.md`.
- [x] **Follow-up: economy (runtime)** — `docs/economy_runtime.md` — исполнение
  экономики и демографии в ходу: `ResourceContext`, `ProductionChain`,
  `EconomicTurnProcessor` (фаза 1: авто-ресурсы → цепочки → поддержка),
  `WorkerAssignment`, приток последователей (столица, слава, храм, сезон),
  экономические поля зданий, `DemographicTurnProcessor` (фаза 2). Индекс
  `docs/README.md` обновлён, «Экономика хода» убран из «Пробелов».
- [x] **Follow-up: building scoring (Godot 4.7 ТЗ)** — `docs/TASK_BUILDING_SCORING_GODOT47.md`
  — самодостаточное ТЗ на стратегическое размещение зданий на гексах: радиальный
  скорнинг (base + biome + adjacency в `input_radius` + иерархия тиров), слияние
  (`MergeSystem`), архитектура `GridManager` (autoload) / `ScoringManager` / `MergeSystem`
  с сигнатурами методов, пошаговая сборка в Godot Editor (TileMapLayer, .tres, визуализация
  радиуса), критерии приемки + тесты. Привязка к `core/HexUtils.gd`,
  `game/city/AdjacencySystem.gd`, `data/BuildingDefs.gd`. Не дублирует
  `CONCEPT_BUILDING_SYNERGY.md` (дизайн) и `TASK_SOCIAL_AND_BUILDINGS.md` (фаза 2/3).
  Индекс `docs/README.md` обновлён.
- [x] **Follow-up: population/runtime (TerraScape-прототип)** — `docs/CONCEPT_POPULATION_RUNTIME.md`
  — соц. составляющая в ходу: потребности (cap/demand/ok), мораль/Resolve, штормы,
  караваны, репутация, авто-слияние ×4, скорнинг. (commit `4898d78`).
- [x] **Follow-up: авто-слияние ×4 (отдельно)** — `docs/CONCEPT_MERGE_AUTO_4.md`
  — BFS связного компонента, «здание II» _BIG, переселение работников, триггер в цикле
  размещения. Отдельно от рецептурного слияния. (commit `2aaeddb`).
- [x] **Follow-up: character system** — `docs/CONCEPT_CHARACTER_SYSTEM.md` — единые 8
  характеристик (Мочь/Ловкость/Сойкость/Разум/Чутьё/Воля/Обаяние/Судьба), 31 навык,
  производные характеристики (формулы Fallout 2: ОЗ/ОД/КЗ/Инициатива/Грузоподъёмность/
  Шанс крита + recalc-by-signal), архитектура эффектов (StatModifier: Override→
  Multiply→Add; ADD/MULTIPLY/OVERRIDE/FLAT_OVERRIDE; game-rule flags; context stats),
  генерация/модификаторы, Черты vs Способности, каталог сложности 🟢/🟡/🔴, D&D 5e 18
  навыков по 6 способностям. Обогащена также `docs/inventory_system.md` (концептуальная
  модель NWN2/D&D 3.5). (commit `a40389a`).
- [x] **Follow-up: abilities (декомпозиция)** — `docs/CONCEPT_ABILITIES.md` — единый
  справочный список 134 способностей (48 черт / 70 перков / 16 особых) вынесен из
  `CONCEPT_CHARACTER_SYSTEM.md`; оставлен как самодостаточный каталог, связан обратной
  ссылкой. Индекс `docs/README.md` обновлён.
- [x] **Follow-up: core turn pipeline** — `docs/CORE_TURN_PIPELINE.md` — ядро хода:
  `TurnContext`, `TurnScheduler`, `TurnPhaseProcessor`, `GameSession` (run_seed/детерминизм),
  `Platform` (headless/test-server), `GameEventBus`, `GameLogger`,
  `ServiceContainer`/`ServiceLocator`, направления зависимостей. Связан с
  `economy_runtime.md` / `hero_system.md` / `world_adventure.md` / `city_system.md`.
  Индекс `docs/README.md` обновлён.

## 6. Version control
- [x] `git add docs/` and commit; confirm `git ls-files docs/` now lists files.
- ✅ `94bc212` (docs-versioning) + `42dbb07` (gap-fill). 31 files tracked in `docs/`.

## 7. Validation
- [x] Re-run the agent-run-and-debug gate (CI `--fast`) to confirm docs changes don't break anything — 4/4 PASS.
- [x] Commit scoped to `docs/` + index (README.md).
