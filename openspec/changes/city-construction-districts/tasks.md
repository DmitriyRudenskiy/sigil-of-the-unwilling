# Tasks

## 1. Реализовано (dead tasks)

- [x] 1.1 52-hex city (ядро 4 + кольца I–III) — `CampaignBuildingPlacement`, `CityData` (city-hex-layout)
- [x] 1.2 Каталог 23 зданий, стоимость, экономика — `campaign_building_catalog.json` (campaign-city-building-economy)
- [x] 1.3 Construction queue (очередь, 52-hex placement, ResourceContext) — campaign-city-construction-queue
- [x] 1.4 DistrictSystem: 7 групп, эмерджентность — `district_system.gd` (T-030)
- [x] 1.5 Worker auto-assignment (min запас/7 дней) — `worker_assignment.gd` (Y7)
- [x] 1.6 Population: k_pop = 0.1/день, min(жильё, floor(прод/k_pop)) — `population_system.gd` (T-040, K-M12, R3)
- [x] 1.7 Биомы: 2 регулярных + босс — `campaign_building_catalog.json` (K-M2)
- [x] 1.8 Без уровней города (K-M3) — campaign-код не использует `city.level` (legacy)

## 2. Разрывы

- [ ] 2.1 «Район создан» — не источник Престижа и не XP (K-M16): проверить `district_system.gd`/`CampaignComposition` (событие без начислений).
- [ ] 2.2 Распад района: теги ниже порога 3 дня → район снимается (таймер на районе, событие в хронику).
- [ ] 2.3 SM здание: GHOST→BUILDING→WORKING→(DISABLED/RUINED→REPAIRING); ауры только от WORKING; маппинг на construction-queue (`construction_turns_remaining`, `state`).
- [ ] 2.4 1 правило соседства MVP (ферма у леса +15%) — проверить/добавить в `settlement_processor.gd`.

## 3. Вердикты владельца (C-2, C-9, C-11)

- [ ] 3.1 C-2: main spec `campaign-city-level-progression` (уровни 1–11) vs K-M3 (аннулированы) + Q-M46/Q-M52 (K-M3 в силе, уровни = 1.0) — вердикт: оставить как 1.0 или пометить superseded.
- [ ] 3.2 C-9: main spec `city-tech-tree` (pre-pivot) — пометка superseded или архивация (реестровый акт).
- [ ] 3.3 C-11: синк `MVP-scope.md` («район создан — источник Престижа (500)» → «не источник», K-M16).

## 4. Верификация

- [ ] 4.1 GdUnit4: 1 клетка = 1 здание; placement по terrain_preference (жёсткая).
- [ ] 4.2 GdUnit4: район создан → 0 Престижа, 0 XP (K-M16); распад через 3 дня.
- [ ] 4.3 GdUnit4: аура только от WORKING; ферма у леса +15%.
- [ ] 4.4 GdUnit4: население от производства (рейд по еде → DEFICIT, не обвал).
