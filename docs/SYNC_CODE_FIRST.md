# SYNC_CODE_FIRST — результаты аудита «код vs GDD» (2026-10-02)

**Метод:** полный инвентарь `game/scripts/` (359 .gd, 604 с addons) + целевые чтения
констант, данных (JSON) и ключевых систем; сверка со всеми docs (00–09, 02b–02g,
MVP-scope, 02e/02f). **Код не изменялся.** Факты ниже — состояние кода на
`doc/sync-audit` (main `9c0e0ce`). Матрица решений — в [[SYNC_DECISIONS]] (блок
«Sync audit 2026-10-02»).

## 0. Архитектура кода: ДВА режима игры

Код содержит два параллельных режима, и GDD описывает их по одному документу на
каждый — но не говорит, какой режим является «игрой»:

| Режим | Код | GDD |
|---|---|---|
| **Кампания**: герой + партия + карта + город + бои + рейды | `world/` (city_*, map_*, bootstrap), `entities/hero/*`, `battle/`, `systems/battle_*`, `city/raid_system`, `ui/` (20+ экранов) | 01–08, MVP-scope (основной GDD) |
| **TerraScape-арена**: компактная сота, виды, Штормы, очки | `settlement/` (Settlement, SettlementAdvanced, SmolderingCity, settlement_species), `city/arena_*` (ring/cluster/storm/turn_runner), `ui/arena_hex_cell` | 02g-city-hex («центральная система проекта», 2026-10-01) |

Главное меню (`ui/main_menu.gd`): Continue / New Game / **Arena** / Load / Chronicle.

**D1 РЕШЕНО (автор, 2026-10-02):** игра = кампания; TerraScape-соты — это город
внутри кампании (02g = документ города кампании), а не отдельный режим.
`settlement/*` — отключённый автономный слой (прототип/legacy, в игре не
инстансируется). Подробности — [[SYNC_DECISIONS#D1. Архитектура: какой режим — игра? — РЕШЕНО (автор, 2026-10-02)]]

## A. Противоречия (код ≠ GDD)

| # | Область | GDD (канон) | Код (факт) | Где в коде |
|---|---|---|---|---|
| A1 | **Разрешение боя** | K2: **нет кубов**, лестница 5 ступеней (Триумф/Успех/Частичный/Провал/Критпровал), полная детерминизм (02d v1.2 §3.2, 08-tech) | Полный d20: `rng.randi_range(1,20)`, advantage/disadvantage (2d20), natural 20/1, proficiency bonus | `battle/dnd/ability_check.gd`, `attack_roll.gd` (+25 файлов слоя) |
| A2 | **Статы** | 6 D&D-статов (STR/DEX/CON/INT/WIS/CHA, 8–18, mod=(x−10)/2) + Удача как 7-й (сдвигает пороги лестницы) | **8 маленьких статов**: attack/defense/spell_power/knowledge + int/wis/cha/luk (база 2, бонусы рас/класса/культуры/бэкграунда) | `entities/hero/components/hero_stats_component.gd:9`, `data/hero_build_profile.gd` |
| A3 | **Классы** | 11 (без Warlock): Варвар, Бард, Жрец, Друид, Воин, Монах, Паладин, Следопыт, Плут, Чародей, Волшебник | Два набора: (1) `hero_classes.gd` — 11, но имена свои: priest, cipher, chanter (вместо жрец/чародей/бард); (2) `races_classes.json` — **Pathfinder: Kingmaker**: 16 классов (alchemist, inquisitor, kineticist, magus, witch + 11 общих), bloodlines, 31 domain, 7 prestige, 14 feats | `data/hero_classes.gd`, `assets/data/races_classes.json` (meta: «Pathfinder: Kingmaker — адаптация») |
| A4 | **Расы** | 54 (02e 9.4, канон); MVP — 3 культуры | (1) `hero_races.gd` — 6 рас (human/elf/dwarf/**aumaua/orlan/godlike** — PF-расы) с subraces; (2) `races_classes.json` — 6 PF-рас (aasimar/dwarf/elf/gnome/halfling/human) | `data/hero_races.gd`, `assets/data/races_classes.json` |
| A5 | **Карта кампании** | 24×24 (07-ui-ux, 08-tech save) | 40–70 (`MAP_SIZE_MIN 40`, `MAP_SIZE_MAX 70`) | `constants/game_numbers_map.gd:5-6` |
| A6 | **Поле боя** | 8×8 MVP / 12×12 1.0 (02b, 07-ui-ux) | 17×11 (`BATTLE_BOARD_W/H`) | `constants/game_numbers_battle.gd:4-5` |
| A7 | **Движение героя** | 6 очков/день (02-mechanics §3.1) | 10/день (`HERO_DAILY_MOVEMENT 10.0`) | `constants/game_numbers_hero.gd:4` |
| A8 | **Рейды** | Фикс-расписание 7/10/14/17/21, сила 1.0/1.5/2.0/2.5/3.0 (02-mechanics §3.8); MVP-scope: 7/14/21 | Случайные: шанс 2–30% (база 10% − репутация/500), сила случайная в диапазоне | `city/raid_system.gd`, `constants/game_numbers_city.gd:80-85` |
| A9 | **Сезоны** | 4 сезона × 5 ходов, зима −50% (02 §3.8) | 3 сезона × 20 ходов: clear/drizzle/storm, множители 1.0/1.2/0.4, буря: враги ×1.25 | `systems/world_seasons.gd` |
| A10 | **Местность боя** | MVP: 3 типа (болото/шипы/высота), 1.0: 8 (02b C3) | 5: PLAIN/FOREST/HILL/FORT/WATER | `systems/BattleTerrain.gd:17` |
| A11 | **Статусы/условия** | MVP: prone; лестница поглощает остальное (02d/02b) | **14 D&D 5e conditions** (blinded…unconscious) + механики каждого | `battle/dnd/condition_manager.gd` |
| A12 | **Ресурсы города** | еда/дерево/камень/железо/оружие (канон 5.1, 06-economy) | Зерно/мука/хлеб/руда/инструменты/золото/scholar_points (основной режим); арена: food/industry/dust/science/influence | `autoload/resource_registry.gd:102-109`, `city/arena_ring_system.gd:12` |
| A13 | **Здания** | MVP 5 / 1.0 = 15 (02e 6.4) / 02g = 23 (свои списки) | **18** в `buildings.json`: great_temple, market, barracks, ancient_vault, walls, farm, mill, bakery, mine, smithy, school, tavern, trade_post, shack, manor, range, library, stables — `ancient_vault/bakery/shack/manor` нет ни в одном GDD-списке | `assets/data/buildings.json` |
| A14 | **Удача** | 7-й стат, сдвигает пороги лестницы (02d §3.2) | `LUCK_CHANCE 0.10` — вероятность 10% (legacy-боя) | `constants/game_numbers_battle.gd:21` |
| A15 | **Опыт/уровни героя** | Уровни 1–5, XP 100/250/450/700/1000 (03-progression) | Плоский `_xp += amount`, **логики level-up нет**; `HERO_LEVEL_UP_EXP 100` не используется никем | `entities/hero_controller.gd:376-383` |
| A16 | **Поле TerraScape** | 52 клетки: ядро 4 + ряды 10/16/22, rings 0–3 (02g §2) | `ARENA_RADIUS 5`, rings 1–5 → 91 клетка, центр 1 | `constants/game_numbers_city.gd:112`, `city/arena_ring_system.gd` |
| A17 | **Биномы** | 02b: ядро боя, пары классов, MVP-бином «Фланг» с хода 1 | **Не реализованы** (только поле `binom_pair` в `data/resource_def.gd:24`) | — |

**Совпадений (проверено, не противоречие):** уровни города 1–11 (02g) = `CITY_LEVEL_MAX 11` ✓;
Хроника (04) = `core/chronicle.gd` ✓; fog of war — есть (`core/visibility_map.gd`) ✓;
production chains (06) = `economy/production_chain.gd` ✓.

## B. Code-first (реализовано в коде, в GDD нет)

### B1. Социальный слой 02f (BANK, «не в MVP») — реализован
- Квесты: `systems/quest_system.gd` + `ui/quest_journal_screen.gd`
- Законы: `systems/law_manager.gd` — 3 ветки (Order/Faith/Survival), дерево `requires`
- Крафт: `systems/crafting_system.gd`, `data/config/crafting_recipes.json`, `hero_crafting_component.gd`
- Оружейная технология: `systems/weapon_tech_service.gd`, `weapon_catalog.gd`
- Диалоги команды (10 JSON): romance, flirt, proposal, wedding, jealousy, betrayal,
  conflict, talk_* — `systems/TeamDialogSystem.gd`, `assets/data/team_dialogs/`,
  `ui/TeamDialogScreen.gd`
- Отношения: `systems/RelationshipSystem.gd`, `HeroRelationshipsComponent.gd`
- Харизма/обман: `systems/CharismaEvents.gd`, `deception_check.gd`, `leadership_check.gd`
- Фракции: `systems/faction_reputation.gd`, `ui/faction_screen.gd`
- **Follower с полом и скрытой ориентацией** (hetero/homo/bi, роллится при рекруте):
  `entities/follower.gd`

### B2. Контент сверх GDD
- **508 заклинаний** (`assets/data/spells.json`) + 13 fallback (включая Blink из 02b C2);
  GDD списка заклинаний не содержит вообще
- **Артефакты** с механиками D&D 3.5e (base_ac, max_dex_bonus, acp, asf):
  `autoload/artifact_registry.gd`, `ui/artifact_inventory_screen.gd`, `artifact_chest_dialog.gd`
- **Pathfinder-контент**: bloodlines (8), domains (31), prestige classes (7), feats (14) —
  `assets/data/races_classes.json`
- **36 событий** в `data/events/`: crisis_01–07, rare_01–05, сезонные (spring_flood,
  winter_starvation…), разовые (meteor, comet, dragon_sighting, gold_vein…)
- **Уникальные здания на местах**: ruins/shrine/meadow (`SITE_*` в `data/building_defs.gd`)
- **Демография с индивидуумами**: `demographics/` (character_registry,
  demographic_turn_processor, trait_registry) — GDD считает население числом (k_pop)
- **Передача преемника**: `hero_followers_component.has_eligible_successor(path_id)` —
  преемник того же пути; в GDD смерти перманентны, преемственности нет
- **Нужды героя** (survival-тики): `hero_needs_component.gd`, `hero_needs.gd`
- **Рост врагов**: `systems/enemy_growth_system.gd` (по сезонам, фракции, карта)
- **Endgame**: `systems/endgame_controller.gd`, `ui/game_over_screen.gd`,
  `ui/death_sequence.gd`
- **Слухи**: зачатки в `world/city_service.gd` ("rumor"), `leadership_check.gd` —
  GDD-движок SEED→SPREAD→DISTORT (04) целиком не реализован

### B3. Инфраструктура/инструменты (не контент)
- **MCP-сервер** для плейтеста: `tools/mcp/mcp_interaction_server.gd` (autoload),
  `ui/mcp_canvas_draw_node.gd` — в GDD нет
- **Баланс-пробы**: `probe/balance_probe.gd` + 5 AI-ролей (Adventurer/Builder/Collector/
  Trader/Traveler) + ScenarioPilot — GDD 08-tech требует «авто-тест баланса»,
  реализация шире описания
- **Генераторы ассетов**: `build/gen_*` (иконки зданий/ресурсов/артефактов, wav, текстуры)
- **UI 20+ экранов** против 6–7 в GDD MVP: character_creation, faction, quest_journal,
  artifact_*, TeamDialog, chronicle, death_sequence, game_over, army_panel, skills_panel,
  resources_panel, resource_bar, decision_panel, tools_panel, minimap, save_load,
  settings, arena_hex_cell…

## C. В GDD есть, в коде нет

| # | Что | GDD | Статус в коде |
|---|---|---|---|
| C1 | **8 Знаков + SignSystem** (престиж, еженедельные испытания, последователи) | 02c, 01, 04, 08-tech | **Полностью отсутствует** (ни данных, ни системы, ни UI) |
| C2 | **Предыгра Q18**: конструктор → знак → земной шар → города (штраф после 2-го) → партия (5 попутчиков, тренировка) | 00-overview [КАНОН 2026-10-02] | Конструктор есть (`character_creation_ui`); **земной шар, выбор городов, попутчики/тренировка — нет** |
| C3 | **Биномы** (включая MVP-бином «Фланг») | 02b | Нет (см. A17) |
| C4 | **Лестница исходов** | 02d v1.2, K2 | Нет (d20 вместо, A1) |
| C5 | **Фикс-расписание рейдов** | 02-mechanics §3.8 | Нет (случайные, A8) |
| C6 | **Слуховой движок** (SEED→SPREAD→DISTORT, 2–3 слуха/нед) | 04 | Частично (B2) |
| C7 | **Кривая XP 100/250/450/700/1000, уровни 1–5** | 03 | Нет (A15) |
| C8 | **Урок 0** «лестница и удача за минуту» | 07, 09 | Не найден (обучение = бит хода 1 в хронике) |

## D. Противоречия внутри GDD (код не при чём)

| # | Где | Конфликт |
|---|---|---|
| D1 | MVP-scope vs 00-overview (Q18) | 3 знака в MVP (Время/Тень/Основание) vs «знак выбирается из 8 на всю игру» |
| D2 | MVP-scope vs 02-mechanics §3.8 | рейды 7/14/21 vs 7/10/14/17/21 |
| D3 | 07-ui-ux/08-tech vs 02g | город = сетка 24×24 (save: `"grid": 24`) vs TerraScape 52 гекс-клетки |
| D4 | 02e §6.4 vs 02g | 15 зданий (1.0) vs 23 здания (02g) — разные списки |
| D5 | 02g vs основной GDD | 02g: «основная механика города — центральная система проекта» (2026-10-01), но MVP-scope описывает кампанию с другим городом |

## E. Итог для решений

Код — это **не реализация MVP по GDD**, а более ранний/расширенный проект
(Pathfinder-конструктор + survival-город + D&D 5e бой + TerraScape-арена),
к которому GDD (пивот 2026-09-30, канон 2026-10-01/02) написан **как новый целевой
контур**. Совпадения есть (уровни города 1–11, хроника, fog, production chains),
но ядро (бой, статы, классы/расы, ресурсы, рейды, сезоны) — разошлось.

Матрица решений D1–D10 с вариантами А/Б — в [[SYNC_DECISIONS]], блок
«Sync audit 2026-10-02». Ждём выбор по каждому пункту; код не трогаем до решений.
