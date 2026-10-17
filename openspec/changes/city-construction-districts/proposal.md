# Proposal

## Why

GDD 02-mechanics §3.5 + 02g — город = ядро MVP (K-M1): районы, здания, рабочие, население, 52 hex, без уровней города (K-M3). Реализовано в основном (DistrictSystem T-030, worker_assignment, PopulationSystem T-040, 52-hex city, каталог 23 зданий, construction queue) + покрыто active changes (campaign-city-building-economy, campaign-city-construction-queue, campaign-city-balance-tuning). Но GDD-канон города как единой спеки в OpenSpec нет, а main spec `campaign-city-level-progression` (уровни 1–11) противоречит K-M3 (уровни аннулированы) — C-2.

## What Changes

- Фиксирует: город = 52 hex (ядро 4 + кольца I–III, 02g §2.1); 1 клетка = 1 здание.
- Фиксирует районы (K-M1, MVP-ядро): эмерджентные, не здание; 7 групп; появляются при наборе требуемых тегов в радиусе; «район создан» — не источник Престижа и не XP (K-M16, самокоррекция K-M1); распад: теги ниже порога 3 дня → район снимается.
- Фиксирует SM здания: GHOST→BUILDING→WORKING→(DISABLED/RUINED→REPAIRING); ауры — только от WORKING; 1 правило соседства MVP (ферма у леса +15%).
- Фиксирует рабочих (Y7): авто-назначение на самое дефицитное здание (min запас/7 дней); ручное — Post-MVP.
- Фиксирует население (K-M12, R3): population = min(жильё, floor(продовольствие_в_сутки / k_pop)), k_pop = 0.1/день; от производства, не от запаса.
- Фиксирует биомы (K-M2): 2 регулярных (равнина/лес) + босс-биом; горы — 1.0; terrain_preference — жёсткая привязка (P-3).
- Фиксирует: без уровней города (K-M3) — лимиты = административные здания; «городская слава» = только персональная.

## Capabilities

### New Capabilities
- `city-construction-districts`: GDD-канон города post-pivot (районы, здания, рабочие, население, 52 hex, без уровней).

### Modified Capabilities
- None.

## Deduplication and status (v4)

- **Дубликаты (active changes):** `campaign-city-building-economy` (каталог 23 зданий, стоимость, экономика) — **зависимость, не дублирование**; `campaign-city-construction-queue` (очередь строительства, 52-hex placement, ResourceContext) — **зависимость**; `campaign-city-balance-tuning` (баланс) — **зависимость**. Здесь — только GDD-канонические требования (районы K-M1, рабочие Y7, k_pop K-M12, SM здания, биомы K-M2, без уровней K-M3); реализация — в тех изменениях.
- **Дубликаты (main specs):** `city-hex-layout` (52 hex) — пересечение (канон совпадает); `settlement-buildings`, `settlement-reputation`, `settlement-resolve`, `settlement-species` — pre-pivot поселения (legacy), **superseded** 02g/K-M3 (виды → расы K-A6, Resolve → настроение, слава → персональная); `city-tech-tree` (уровни 1–11) — **superseded** K-M3 (см. C-2).
- **Дубликаты (archive):** `2026-09-17-settlement-system`, `2026-10-04-terrascape-hex-city-builder` (SUPERSEDED campaign-city-building-economy), `2026-10-07-campaign-city-management-ui`, `2026-10-08-campaign-city-level-progression` — pre-pivot/уточнения; не дублируются.
- **Dead tasks (реализовано):** 52-hex city, каталог зданий, construction queue, DistrictSystem, worker auto-assignment, PopulationSystem (k_pop) — помечены `[x]`.

## Impact

- Код: `district_system.gd`, `worker_assignment.gd`, `population_system.gd`, `settlement_processor.gd`, `campaign_building_catalog.json` — уже соответствуют канону; новые требования — SM здание (DISABLED/RUINED/REPAIRING), распад района, «район создан» без Престижа.
- Не затрагивает: караваны (Post-MVP), стены (Post-MVP), камень/кузница (Post-MVP), ручное назначение рабочих (1.0).

## Contradictions

- **C-2 (cross-spec, флаг владельцу):** main spec `campaign-city-level-progression` (2026-10-08: уровни 1–11 активны, CELL_LIMITS = [4,9,14,...,52], «владелец направил возродить трек») vs K-M3 (2026-10-02: «уровни города» аннулированы, лимиты = административные здания) + Q-M46/Q-M52 (2026-10-16: K-M3 в силе, уровни = 1.0/post-MVP, код = legacy). Хронология: K-M3 (02.10) → spec (08.10) → Q-M46/Q-M52 (16.10). Вердикт Q-M46/Q-M52 новее spec, но spec не пометен. Нужен вердикт владельца: оставить spec (уровни = 1.0) или пометить superseded.
- **C-11 (docs vs docs):** `MVP-scope.md` «район создан — источник Престижа (500 — баланс-конфиг)» vs K-M16 + 02-mechanics §3.5 «район создан — не источник Престижа (самокоррекция K-M1)». Канон = K-M16; строка MVP-scope.md устарела.
- **C-9 (main spec superseded):** `city-tech-tree` (уровни 1–11, tech tree) — pre-pivot, superseded K-M3; main spec не удалён.
