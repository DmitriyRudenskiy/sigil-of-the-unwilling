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

- [x] 2.1 «Район создан» — не источник Престижа и не XP (K-M16): проверить `district_system.gd`/`CampaignComposition` (событие без начислений). *(Верифицировано: Престиж — только ledger battle_victory (T-112), XP — только бой/узел/рейд (T-060); строительство и районный процесс без начислений. Тесты: `test_district_no_grant.gd` (4).)*
- [ ] 2.2 Распад района: теги ниже порога 3 дня → район снимается (таймер на районе, событие в хронику).
- [ ] 2.3 SM здание: GHOST→BUILDING→WORKING→(DISABLED/RUINED→REPAIRING); ауры только от WORKING; маппинг на construction-queue (`construction_turns_remaining`, `state`).
- [ ] 2.4 1 правило соседства MVP (ферма у леса +15%) — проверить/добавить в `settlement_processor.gd`.

## 3. Вердикты владельца (C-2, C-9, C-11)

- [ ] 3.1 C-2: main spec `campaign-city-level-progression` (уровни 1–11) vs K-M3 (аннулированы) + Q-M46/Q-M52 (K-M3 в силе, уровни = 1.0) — вердикт: оставить как 1.0 или пометить superseded.
- [ ] 3.2 C-9: main spec `city-tech-tree` (pre-pivot) — пометка superseded или архивация (реестровый акт).
- [ ] 3.3 C-11: синк `MVP-scope.md` («район создан — источник Престижа (500)» → «не источник», K-M16).

## 4. Верификация

- [x] 4.1 GdUnit4: 1 клетка = 1 здание; placement по terrain_preference (жёсткая). (2026-10-19, локальный агент: покрыто — `test_city_layout_is_52_cells_and_placement_respects_terrain_and_occupancy` (terrain-жёсткость: wrong_terrain → ok=false; occupied → ok=false; footprint [[0,0]] → 1 клетка) + новый `test_mvp_catalog_one_cell_per_building` (инвариант данных: все 98 зданий MVP-каталога — footprint ровно 1 клетка-якорь [0,0]).)
- [ ] 4.2 GdUnit4: район создан → 0 Престижа, 0 XP (K-M16); распад через 3 дня.
- [ ] 4.3 GdUnit4: аура только от WORKING; ферма у леса +15%.
- [x] 4.4 GdUnit4: население от производства (рейд по еде → DEFICIT, не обвал). (2026-10-19, локальный агент: покрыто — `test_start_state_one_turn` (поток еды → SM DEFICIT, pop стабилен), `test_t122_raid_hits_pre_production_stocks` (рейд бьёт запасы ДО production), `test_afk_cascade_no_chain_collapse` (10 рейдов — цепного обвала нет) + новый `test_raid_food_deficit_no_population_collapse` (рейд по еде → SM DEFICIT, население > 0 и не ниже стартового; MVP m-множители = 1, K-M12).)
