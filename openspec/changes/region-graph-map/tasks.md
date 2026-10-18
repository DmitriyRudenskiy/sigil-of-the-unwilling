# Tasks

## 1. Данные графа

- [ ] 1.1 `game/data/campaign/region_graph.json` — MAP-1: фиксированный граф 40–48 регионов (id, биом, рёбра, terrain_preference узлов). *(не начат; MVP работает на маске S1 из movement.json.)*
- [x] 1.2 MVP-маска: связное подмножество 5 регионов (K-R4) + 1 стартовый регион. *(реализовано в `movement.json → mvp_mask`, S1: R01–R05; единый источник данных, отдельный файл не нужен.)*
- [x] 1.3 Узлы MVP: 4 узла (camp R02, ruin R03, ore R04, [camp,ruin] R05) + 1 город игрока (R01). *(жёсткая привязка в movement.json; нейтральные поселения — post-MVP.)*
- [x] 1.4 One-time loot (Y4): руины 10 дерева + 5 железа + 300 XP; руда 20 железа + 300 XP; лагерь 5 еды + 10 железа + 400 XP — каталог `RegionMap.loot_catalog()`. *(детерминизм: нижняя граница XP.)*

## 2. Runtime (region_map.gd)

- [x] 2.1 Туман: множество открытых регионов, радиус 1 (Q-M54→(а)); свой город всегда видим. *(RegionMap.open_regions, _fog_radius_1.)*
- [x] 2.2 Движение: переход = рёберный шаг (D-191); стоимость входа = entry_cost_days[биом] (K-M4, movement.json); еда 1/персонаж/переход (R7, Q-M75→(б)), ёмкость 10. *(RegionMap.travel.)*
- [x] 2.3 SM героя: EXPLORE/ENGAGE/BATTLE/VICTORY/DEFEAT/RETREAT; авто-режим при 2 днях без выбора; отступление = авто-возврат за 1 день без боёв (Y10). *(RegionMap hero_state + retreat/tick_days.)*
- [ ] 2.4 FS: скорость ≤ 0 → ход заканчивается на текущем регионе; окружение → ENGAGE обязателен; рейд по региону героя → бой, победа → −50% последствий.
- [x] 2.5 Инвариант доходимости якорей 7/14/21 (K-M4): `RegionMap.unreachable_regions()` (BFS из старта); MVP-маска S1 — связный путь, инвариант выполнен по данным. *(авто-балансировщик для генерации MAP-1 — post-MVP, вместе с 1.1.)*
- [x] 2.6 Шов в `TurnDriver`: player-фаза — переходы героя (`TurnDriver.player_hook` → `RegionMap.tick_days`); шов в `ThreatSystem`: «герой в городе → бой (CR 1/2/6)», «герой в походе → авто-рейд» (R5) — `hero_in_city` из позиции героя в `CampaignComposition._threat_context`.

## 3. Сейв

- [x] 3.1 Секция карты в сейве: `map.region` (позиция героя, открытые регионы, visited-узлы, SM, запас); миграция fail-fast (save-migration) + старый сейв без секции → старт в городе. *(RegionMap.to_dict/from_dict + SCHEMA_VERSION; `CampaignComposition.build_save_state/load_save_state`.)*

## 4. Верификация

- [x] 4.1 GdUnit4: связность MVP-маски; туман (радиус 1, город всегда видим); one-time loot (второй визит — пусто). *(test_region_map.gd.)*
- [x] 4.2 GdUnit4: расход еды за переходы (2 × 1 = 2; горы 2 × 3 = 6); голод при 0 (reject). *(test_region_map.gd.)*
- [x] 4.3 GdUnit4: авто-режим (2 дня без выбора → возврат в город); отступление (1 день, без боёв). *(test_region_map.gd.)*
- [x] 4.4 GdUnit4: доходимость якорей 7/14/21 на MVP-маске (`test_reachability_all_regions_from_start`). *(FS скорость ≤ 0 — с 2.4, post-MVP.)*
