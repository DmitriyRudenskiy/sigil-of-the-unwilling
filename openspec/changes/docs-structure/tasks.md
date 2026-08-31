## 1. Audit (baseline)
- [x] List all 26 docs; note area, one-line purpose, and any stale `scripts/…` refs.
- [x] Confirm `docs/` is untracked (`git ls-files docs/` empty).

## 2. Create `docs/README.md` index
- [x] Group docs into areas (architecture, overview, systems, economy, concepts, howto, reports) with one-line descriptions + links.
- [x] Note the "docs are being filled in" status.

## 3. Reorganize into area folders
- [ ] Move docs into `docs/architecture/`, `docs/systems/`, `docs/economy/`, `docs/concepts/`, `docs/howto/`, `docs/reports/`, `docs/overview/`.
- [ ] Update cross-references in AGENT.md (lines 4, 90, 335–338) and within docs.
- [ ] Verify no dangling `docs/…` link (`grep -rn "docs/" . | grep -vE "\.md:"` sanity check).
- ⏭️ **Deferred** (decision point): flat `docs/*.md` structure kept on purpose. Reorg
  would break production-referenced flat paths in AGENT.md (rules §8/§11) and README;
  low value. User may reorg later, leaving flat structure for gap-fill.

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

## 6. Version control
- [x] `git add docs/` and commit; confirm `git ls-files docs/` now lists files.
- ✅ `94bc212` (docs-versioning) + `42dbb07` (gap-fill). 31 files tracked in `docs/`.

## 7. Validation
- [x] Re-run the agent-run-and-debug gate (CI `--fast`) to confirm docs changes don't break anything — 4/4 PASS.
- [x] Commit scoped to `docs/` + index (README.md).
