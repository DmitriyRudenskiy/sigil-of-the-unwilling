---
title: Карта систем
tags:
  - reference
  - architecture
status: reference
date: 2026-10-29
---

# Карта систем

Инвентарь собран **из кода**, а не из памяти: `game/project.godot`
(`[autoload]`, `[input]`, `run/main_scene`), `game/scripts/**`, `game/scenes/**`,
`scripts/campaign/save/mvp_save_schema.gd`. Это канон перечней: остальные заметки
ссылаются на эту страницу ([[18-system-map]]), а не пересказывают её — повторение
одного перечня в трёх местах даёт три места расхождения.

Сверяется машиной: `python3 scripts/audit_docs_vs_code.py` (exit ≠ 0, если
автозагрузка, действие ввода, сцена или ключ сейва не названы в `docs/`, или если
док ссылается на несуществующий файл).

## 1. Автозагрузки (`project.godot [autoload]`, 15)

| Автозагрузка | Файл | Ответственность |
| --- | --- | --- |
| `McpInteractionServer` | `tools/mcp/mcp_interaction_server.gd` | отладочный сервер взаимодействия для MCP e2e (4-й уровень верификации); инжектится вендорным аддоном, в релизной сборке не нужен |
| `Settings` | `scripts/autoload/settings.gd` | настройки: режим окна (`apply_display_mode`), зум карты (`get_zoom`, `step_zoom`), флаг взрослого контента |
| `SoundManager` | `scripts/autoload/sound_manager.gd` | `play_sfx` / `play_music` и cue-варианты (`play_sfx_cue`, `play_music_cue`) по `AudioCues`; слушает действие `mute` (см. §7) |
| `GameEventBus` | `scripts/autoload/game_event_bus.gd` | событийная шина игры, 38 сигналов (см. §4) |
| `Spellbook` | `scripts/autoload/spellbook_registry.gd` | реестр книг заклинаний: `ensure_definitions`, загрузка из JSON с `_load_fallback` |
| `PauseController` | `scripts/autoload/pause_controller.gd` | пауза со **счётом ссылок**: несколько систем могут независимо просить паузу, игра разматывается, когда отпущен последний владелец; снимается при смене сцены |
| `CursorController` | `scripts/autoload/cursor_controller.gd` | курсор: меняет форму по контексту, подписывается на `GameEventBus.hero_moving_changed` |
| `TemplateBootstrap` | `scripts/autoload/template_bootstrap.gd` | инициализация шаблонов/контента на старте (24 строки, только `_ready`) |
| `Units` | `scripts/autoload/unit_registry.gd` | реестр юнитов: `get_definition(key) → UnitStats`, `make_stack(key, rng, size_mult)` |
| `Artifacts` | `scripts/autoload/artifact_registry.gd` | реестр артефактов: `get_by_id`, `_register`, моды эффектов (в т.ч. `luck`, D-268) |
| `Spells` | `scripts/autoload/spell_registry.gd` | реестр заклинаний: `_reg(id, name, school, lvl, mana, target…)`, `get_spell` |
| `Resources` | `scripts/autoload/resource_registry.gd` | реестр ресурсов: городские (`_add_city` с ёмкостью), иконки (`get_icon`) |
| `Services` | `scripts/autoload/services.gd` | DI-реестр (см. §2): `resolve(key)`, `register_singleton(key, service)`, `clear_session()` |
| `TileAtlasCache` | `scripts/autoload/tile_atlas_cache.gd` | кэш `TileSet` гекс-тайлов (`build_hex_tileset`) — сборка атласа один раз за сессию |
| `HexGrid` | `scripts/autoload/hex_grid.gd` | калибровка координатной сетки по `TileMapLayer` (`calibrate(tm)`, 12 строк) |

## 2. Services — DI-реестр

`scripts/autoload/services.gd` регистрирует ключи: `event_bus`, `settings`,
`units`, `artifacts`, `spells`, `resources`, `persistence`, `service_registry`.
Смысл слоя: системы получают зависимости через `Services.resolve(&"persistence")`,
а не держат друг друга напрямую; `clear_session()` вызывается при выходе из
сессии, чтобы синглтоны не течли между кампаниями. Потребители записи о
сейв-сервисе: `scripts/ui/save_load_screen.gd`, `scripts/world/world_bootstrap.gd`,
`scripts/world/world_persistence.gd`.

## 3. Слои `game/scripts/`

Количество `.gd` на 2026-10-26 (мера, не оценка): `data` 66, `ui` 51, `world` 50,
`systems` 36, `city` 34, `entities` 34, `core` 25, `battle` 27, `campaign` 19,
`autoload` 17, `probe` 9, `build` 8, `constants` 8, `settlement` 6,
`demographics` 6, `balance` 5, `economy` 4, `managers` 2, `theme` 2, `utils` 1.

- **`core/`** — правила без состояния (`battle_rules.gd`, `hex_utils.gd`,
  `save_data.gd`): арифметика боёв по лестнице (D-222), геометрия гексов.
- **`systems/`** — оркестрация боя и мира: `battle_state.gd` (+ вложенный класс
  `BattleUnit`), `battle_state_builder.gd`, `battle_controller.gd`,
  `battle_view.gd`, `crisis_event_system.gd`.
- **`campaign/`** — кампанийный ход: `turn_driver.gd`, `region_map.gd`,
  `party_system.gd`, `population_system.gd`, `threat_system.gd`,
  `chronicle_log.gd`, `sign_system.gd`, `save/`.
- **`city/`** — город: строительство, районы, обучение, экономика хода.
- **`data/`** — справочники и реестры контента (каноны рас и классов, типы
  ресурсов, Знаки, шаблоны заклинаний): §3б.
- **`world/`** — карта и мировой режим: `map_generator.gd`, `map_renderer.gd`,
  `map_roads.gd`, `map_threat.gd`, `world_camera.gd`, `world_persistence.gd`;
  разбор 19 живущих здесь имён — §3а.
- **`ui/`** — экраны и панели; **`ui_kit/`** пуст (0 `.gd`) — общие виджеты живут in
  `ui/` (FormRow/FormStack) и в теме.
- **`probe/`** — балансовые роли-разведчики (`CollectorRole.gd`, `SurvivalRole.gd`,
  `ScenarioPilot.gd`), не игровой контент.
- **`build/`** — генераторы ассетов и сцен; сгенерированные сцены обязаны правиться
  здесь же (T-219: `gen_inventory_scene.gd` — носитель
  `artifact_inventory_screen.tscn`).

## 3а. Мировой слой `scripts/world/`: карта, город, герой

Каталог `world/` — самый большой по числу незамеченных имён (19 из описи T-279),
и у него двусмысленный статус, который надо называть прямо:

- **Точка входа мирового режима заморожена** (D-157): `scenes/archive/world.tscn`.
  Замер 2026-10-29 по `grep -rn "archive/world.tscn"` по `.gd`/`.tscn`: сцену
  грузят **только тесты** (`tests/functional/test_world_bootstrap.gd`,
  `test_world_scenario.gd`, `test_scene_boot.gd`, `tests/unit/probe/test_trader_role.gd`,
  `tests/unit/data/test_audio_world_entry.gd`) — из production ни одна кнопка
  к ней не ведёт. Судьба слоя (удаление vs носитель) — [[QUESTIONS]] Q-M117.
- **Но сам слой не мёртв:** у **15 из 19** есть production-потребитель вне
  собственного каталога (замер: `grep -rl "\bИмя\b"` по `scripts/` и `scenes/`,
  без `scripts/world/`), а стек карты переиспользуется живым экраном —
  `ui/campaign_hud.gd` держит `MapGenerator`/`MapRenderer`. Сильнее всех
  привязаны к кампании: `WorldPersistence` (сессия и дата для `main/main.gd` и
  всего претейна), `CitySerializer` (сейв города в `campaign_composition.gd`),
  `CityService` (`ui/city_screen.gd`), `PopUnit` (житель в экономике хода,
  репутации, обучении), `Season` (`campaign_calendar.gd`), `WorkerAssignment`
  (`economic_turn_processor.gd`). У четырёх — `Borough`, `MapModel`,
  `WorldInput`, `WorldSpawner` — такого потребителя нет: их держат только
  мировой слой, тесты и балансовые зонды (`probe/`). Поэтому строка
  «замороженный мировой режим» относится к **точке входа**, а не к классу:
  у класса обязан быть живой потребитель, иначе это писатель без читателя.

| Имя | Файл | Ответственность (проверено по коду) | Кто зовёт |
| --- | --- | --- | --- |
| `WorldBootstrap` | `world_bootstrap.gd` | статический `run()` сборки мирового режима: `_assert_core_services()`, подъём `scenes/world/map_generator.tscn`, создание `World`, роутера событий, наследования и жизненного цикла героя | `world_controller.gd`, `world_save_load_service.gd`, `world_event_router.gd`, `autoload/services.gd`, `probe/ScenarioPilot.gd` |
| `WorldController` | `world_controller.gd` | `Node2D`-корень мирового режима: `_ready` вызывает бутстрап, держит `CityManager`, `WorldUIManager`, `WorldStateDelta`, `ShardManager`, обновляет туман (`_on_fog_refreshed`) | `ui/marker_layer.gd`, `entities/hero_controller.gd`, `entities/hero_visual_controller.gd` |
| `WorldInput` | `world_input.gd` | 28 строк: `_unhandled_input` мира (клик по карте/герою); молчит, если не собраны `map`/`hero`/`camera` или мир в терминальном состоянии (`world.is_terminal()`) | `world_bootstrap.gd`, `map_generator.gd` |
| `WorldSpawner` | `world_spawner.gd` | расстановка сущностей карты (`village_entity`, `resource_entity`, `enemy_entity`, `chest_entity`, `scroll_entity`), затемнение невидимого (`apply_fog_visibility`), кэш текстур (`_cached_texture`) | `world_bootstrap.gd`, `world_load_context.gd`, `world_interaction_controller.gd`, `probe/*`, `tools/diag_recruit_block.gd` |
| `WorldPersistence` | `world_persistence.gd` | **живой носитель сессии**: `SaveManager`, `GameSession`, `Chronicle`, дата `{month,week,day}`, `WorldStateDelta`, карта видимости, `reset_session_state()` | `main/main.gd`, `ui/main_menu.gd`, `ui/save_load_screen.gd`, `ui/character_creation_ui.gd`, `campaign/campaign_calendar.gd`, `autoload/services.gd` |
| `WorldBattleCoordinator` | `world_battle_coordinator.gd` | передача боя (`battle_handoff.gd`), сигналы `battle_world_hide/show_requested`, `enemy_stack_defeated(enemy_cell, army)`; `_create_battle_flow()` | `systems/BattleRewards.gd`, `battle/dnd/battle_factory.gd`, `probe/ScenarioRole.gd`, `world_bootstrap.gd` |
| `HeroLifecycleSystem` | `hero_lifecycle_system.gd` | смерть и наследник героя, подъём `scenes/ui/death_sequence.tscn` и `chronicle_screen.tscn`, состояние легенды (`get_legend_state()` через `LegendTracker`); ссылки на мир — `WeakRef`, чтобы не держать сцену | `entities/hero_visual_controller.gd`, `world_persistence.gd`, `world_hero_manager.gd`, `world_save_load_service.gd` |
| `CityManager` | `city_manager.gd` | реестр городов и славы: `register_city(city, make_capital)`, `set_capital`, `add_glory`, сигналы `city_updated`, `cities_changed` (кэш тайл→город, city-hex-layout 4.1), `reputation_changed`, `relocation_completed` | `systems/endgame_controller.gd`, `systems/enemy_growth_system.gd`, `systems/enemy_turn_processor.gd`, мировой слой, `balance/campaign_city_balance_fixture.gd` |
| `CityData` | `city_data.gd` | данные города и их сигналы (`population_changed`, `boroughs_changed`, `buildings_changed`, `storage_changed`, `relocation_completed`), `enum Faction`, `SERIALIZATION_VERSION = 6`, `ensure_resource_ctx()`, `invalidate_yield()` | **база класса `City`** (`world/city.gd`) — кампанийный город живёт через неё; напрямую — `world/city_service.gd`, `data/race_economy.gd` |
| `CitySerializer` | `city_serializer.gd` | `serialize`/`deserialize` города и `_migrate_city_data(data, from_version)` — сейв-контракт версии 6 | `campaign/campaign_training_service.gd`, `campaign/campaign_composition.gd`, мировой слой |
| `CityService` | `city_service.gd` | статические операции над городом: наём (`pop_total`, `_recruit_difficulty(city_level)`, `LeadershipCheck`), оборона (`CampaignDefenseResolver`), воспроизводимость через `set_rng` | `ui/city_screen.gd` (экран города кампании), `systems/weapon_tech_service.gd`, мировой слой |
| `Borough` | `borough.gd` | район города: `cell`, `level`, `uid`, `net_approval()` по `GameNumbers.APPROVAL_NET_PER_BOROUGH_LEVEL` (вне диапазона уровня — 0, а не падение) | `world/borough_rules.gd`, `world/city_arena_view.gd`, `world/city_building_service.gd`, `world/city_data.gd`, `world/city_serializer.gd` |
| `PopUnit` | `pop_unit.gd` | житель как единица состояния: `enum State { WORKER, FOLLOWER, MILITIA, SCHOLAR }`, `request_switch` (запросы состояния/тайла применяются не мгновенно), `is_available`, `is_free_follower` | шире всех: `campaign/campaign_training_service.gd`, `campaign/campaign_city.gd`, `city/reputation_system.gd`, `economy/economic_turn_processor.gd`, `entities/follower_system.gd`, `demographics/*`, `data/needs/*` |
| `WorkerAssignment` | `worker_assignment.gd` | расстановка работников по производственным цепям зданий (`assign_all(city)` читает `chain.required_workers`), приоритеты кампанийных рецептов (`campaign_recipe_priority`, `sort_campaign_recipes`) | `economy/economic_turn_processor.gd`, `city/processors/worker_assignment_processor.gd` |
| `Season` | `season.gd` | месяц → сезон (`from_month`: 12, 1–2 — зима; невалидный месяц → `push_warning` + весна) и `growth_modifier(season)` | `campaign/campaign_calendar.gd`, `systems/crisis_event_system.gd`, `constants/game_text.gd` |
| `MapModel` | `map_model.gd` | модель карты: `generate_noise()`, `get_biome_terrain_id(height, temp, moist)` по порогам `WATER_THRESHOLD 0.35` / `SAND_THRESHOLD 0.40`, `is_walkable(cell)` | `world/map_generator.gd`, `world/map_spawner.gd`, `tools/diag_biome_resources.gd` |
| `MapObjects` | `map_objects.gd` | лист изолированных объектов карты: пиксели `assets/objects/world_map_objects.webp` и раскладка `world_map_objects.json` — продукты `scripts/gen_map_art.py`; координаты читаются **только из манифеста**, отдельного реестра в скрипте нет (такой реестр уже умирал в `tile_atlas.gd`) | `world/map_generator.gd`, `world/map_renderer.gd`, `world/map_roads.gd`, `world/map_spawner.gd`, `entities/resource_node.gd` |
| `MapSpawner` | `map_spawner.gd` | расстановка по `MapModel` (`place_villages()` и далее), реестр юнитов подставляется извне (`setup_registry`) | `world/map_generator.gd`, `world_bootstrap.gd`, `world_spawner.gd`, `systems/enemy_growth_system.gd`, `probe/balance_probe.gd` |
| `ResourceNodeManager` | `resource_node_manager.gd` | узлы ресурсов на карте (`Node`): заводит `scenes/entities/resource_node.tscn`, читает `ResourceDef` и скрытые по биому ресурсы, работает через `Resources`-реестр и переданный `map_to_local`-callable | `world_bootstrap.gd`, `world_load_context.gd`, `world/resource_chain_service.gd`, `systems/extract_rules.gd`, `probe/*` |

**Как сверять слой при правке.** Точка входа одна — `scenes/archive/world.tscn`
(тесты `tests/functional/test_world_*.gd`), кампанийная точка — `main/main.gd`
для `WorldPersistence` и `ui/campaign_hud.gd` для стека карты. Класс, у которого
не осталось ни одного production-потребителя, — кандидат не в «дописать строчку»,
а в акт заморозки/удаления (Q-M117), иначе опись T-279 врёт: имя по-прежнему
названо, но назвать его некому.

## 3б. Слой данных `scripts/data/`: каноны, справочники, таблицы

Правило слоя: **числа и имена — в JSON, код — только доступ** (K-M15 для Знаков,
`mvp_catalog.json` для канонов). Отсюда и род проверок: у класса данных спрашивают
не «что он посчитал», а «чей JSON он читает и кто этот JSON зовёт». Потребитель
замерен `grep -rl` по `scripts/`, `scenes/`, `tools/` плюс поиск по пути preload:
preload пишет `_Classes = preload("…/canon_classes.gd")`, и по имени класса такое
не находится.

| Имя | Файл | Ответственность (проверено по коду) | Кто зовёт |
| --- | --- | --- | --- |
| `CanonClasses` | `canon_classes.gd` | канон-каталог классов (T-113, K1) из `assets/data/mvp_catalog.json`: 11 классов, Колдуна нет, «mage» = Волшебник; `classes()`, `hireable()` — маска MVP-наёма (6), `by_id`; кэш `_cache` | `ui/character_creation_ui.gd` (preload под именем `_Classes`) |
| `CanonRaces` | `canon_races.gd` | канон-каталог рас (Q-M100 → (а), D-239), тот же JSON: первый эшелон 7 по флагу `first_tier`, `races()`, `by_id`, `name_for`. Чисел здесь нет намеренно: `modifiers` каталога читает не кто, носитель — T-176 | `ui/pregame_flow_model.gd` |
| `HeroRaces` | `hero_races.gd` | легаси-таблица 6 рас пре-пивота (human/elf/dwarf/aumaua/orlan/godlike) с бонусами и подрасами; фолбэк подписи и бонусов для легаси-идов, диспозиция — Q-M44 (корзина B, T-128) | `ui/character_creation_ui.gd`, `data/hero_build_profile.gd` |
| `HeroFactions` | `hero_factions.gd` | `const FACTIONS`: 6 фракций по расам, id фракции = id расы (родная раса даёт +10 к репутации своей фракции), `faction_name(id)` | `ui/quest_journal_screen.gd`, `ui/faction_screen.gd`, `systems/faction_reputation.gd` |
| `RaceClassRegistry` | `race_class_registry.gd` | реестр `assets/data/races_classes.json` по доменам: `_races` (`RaceDef`), `_classes` (`ClassDef`), кровные линии, домены, престиж, черты; `ensure()` / `reset()` | `entities/follower_system.gd` |
| `RaceEconomy` | `race_economy.gd` | 7 расовых экономических профилей из `assets/data/race_economy.json`; хуки production/synergy/conflict/needs; анти-имба: `best_production_mult` берёт **максимум**, а не сумму нескольких рас в здании | `economy/economic_turn_processor.gd`, `world/city_service.gd` |
| `ResourceType` | `resource_type.gd` | `enum ID` ресурсов (WOOD…GOLD и далее) + `all_ids()`, `classic_ids()`, `is_valid(id)`, имена и количества подбора (`pickup_amount`) | `ui/resource_bar.gd`, `ui/resources_panel.gd`, `autoload/resource_registry.gd`, `economy/economic_turn_processor.gd`, `entities/resource_node.gd` |
| `ResourceAtlas` | `resource_atlas.gd` | ASSET-1: иконка ресурса — свой файл 32×32 `assets/ui/icons/resources/icon_resource_<id>.png`, продукт `tools/gen_resource_icons.py` по формуле art-bible §7.1; в классе только кэш `load()` и `TYPE_TO_ID` (порядок = `ResourceType.ID`). До ASSET-1 здесь кроили чужую ячейку HoMM III (102 px, 4×4) | `ui/city_screen.gd`, `ui/resources_panel.gd`, `theme/IconRegistry.gd`, `entities/resource_node.gd`, `core/static_caches.gd`, `world/world_spawner.gd` |
| `ResourceIcons` | `resource_icons.gd` | фасад над `ResourceType` и `ThemeConfig`: `res_type_id`/`res_type_amount` (обёртки подбора), `get_color`, кэш реестра ресурсов. `get_texture()` **для классических 7 возвращает null намеренно** — ветка унаследована из времени, когда своих иконок не было («классические — null: попап рисует кружок из get_color»), и закреплена тестами; для остальных id делегирует `ResourceAtlas`. `DATA` с семью пустыми `texture` — остаток прежнего носителя иконок. Предпосылка ветки умерла в ASSET-1 (`aaa2a4aa`, 2026-10-14): свои `icon_resource_wood…gold.png` лежат в репо, и `tests/unit/assets/test_resource_icons_asset1.gd` требует, что они грузятся. Открытый вопрос — T-284 | `ui/resource_collect_popup.gd` (на null рисует `PlaceholderTexture.circle`), `probe/ScenarioPilot.gd`, `probe/balance_probe.gd`, `core/static_caches.gd` |
| `ScenarioTargets` | `scenario_targets.gd` | const-таблица целей автопилота (D3 autopilot-scenario-matrix): `ROLES` (collector/traveler/builder/survival/adventurer) с `max_turns` и целями, `role_ids()`, `survival_seeds()`; калибровка — правкой этих чисел по отчётам, не кодом. Не игровой контент | `probe/ScenarioPilot.gd`, `tools/matrix_report.gd`, `tools/survival_report.gd` |
| `Signs` | `signs.gd` | каталог 8 Знаков (T-002, docs/02c-signs.md, финальная редакция автора 2026-09-30, имена и девизы verbatim); выбор 1 из 8 на всю игру, Престиж косметический; числа и имена живут только в `data/signs.json` (K-M15) — здесь `all()`, `ids()`, `by_id()` | `ui/sign_choice_ui.gd`, `campaign/campaign_composition.gd` |
| `StatusEffects` | `status_effects.gd` | `enum Effect` из 13 эффектов (HASTE…BLIND) и классификаторы `is_debuff`, `is_stun`, `get_name` | `autoload/spell_registry.gd`, `systems/battle_turn_executor.gd`, `core/battle_fx.gd` |
| `SpellbookDef` | `spellbook_def.gd` | домен карты и книги заклинания: `id`, `template`, `speed`, `cost`, `color`, `influence_req`, `from_dict` / `to_dict` — граница между JSON реестра и кодом боя | `autoload/spellbook_registry.gd`, `data/battle_spell_bridge.gd` |
| `BattleSpellBridge` | `battle_spell_bridge.gd` | мост «ключевое слово карты → эффект статуса» (`KEYWORD_TO_EFFECT`) и имена шаблонов (`T_DIRECT_DAMAGE`, `T_KEYWORD_BUFF`, …) | `autoload/battle_emulator.gd` — сам не autoload, его поднимают `battle/dnd/battle_factory.gd` и `tools/winrate_baseline.gd` |
| `TemplateEngine` | `template_engine.gd` | реестр обработчиков шаблонов: `register_handler(template, handler)`, `execute`, `reset`; 19 обработчиков `data/templates/T01…T19` регистрирует autoload `TemplateBootstrap` | `autoload/template_bootstrap.gd` |
| `SpellResolver` | `spell_resolver.gd` | **старый фасад разрешения заклинаний: в production не вызывается никем.** Замер: `grep -rn` по имени и по пути preload — вызовы только в `tests/unit/data/test_spell_system.gd`. Живой путь боя — `SpellCaster.cast()` из `systems/battle_action_resolver.gd` и `autoload/battle_emulator.gd` | тесты: `tests/unit/data/test_spell_system.gd` (писатель без читателя — T-283) |

**Что разбор делает видимым.** Он поймал и собственную ошибку: первая версия
этой таблицы утверждала, что `get_texture()` возвращает null всегда, — вывод по
пустой таблице `DATA`, сделанный до того, как дочитан метод. На деле у null-ветки
есть авторское обоснование, а потеряно оно было не эволюцией кода, а правкой
`520a5ae8` (2026-09-09, «strip all comments from scripts/ and tests/»), которая
срезала единственную строку, объяснявшую ветку. Дальше сработали тесты: они
закрепили поведение, и следующий читатель уже не отличает «так задумано» от
«так вышло». Отсюда правило слоя: **обоснование ветки живёт в коде или в тикете,
но не в памяти автора**; T-284 — именно про то, что ASSET-1 сделал прежний
вердикт устаревшим, а отменить его никто не сел.

Настоящий писатель без читателя в слое один: `SpellResolver` (T-283) — его не
зовёт никто, кроме теста.


## 4. Событийная шина `GameEventBus`

38 сигналов (все — `scripts/autoload/game_event_bus.gd`), по группам:

- **бой**: `battle_started`, `battle_completed(winner, enemy_cell)`,
  `battle_won(enemy_cell)`, `battle_lost(enemy_cell)`;
- **ход и мир**: `turn_ended(turn, month)`, `hero_moving_changed(moving)`,
  `hero_died(cause)`, `hero_successor(hero)`, `weather_changed(new_weather)`,
  `game_ended(result, reason, summary)`;
- **ресурсы и производство**: `resource_discovered`, `resource_extracted`,
  `resource_exhausted`, `resource_depleted`, `production_completed`,
  `upkeep_failed`, `trade_completed`;
- **город и здания**: `building_constructed`, `scale_shift`, `zone_violation`,
  `city_level_up`, `city_event_occurred`, `relocation_completed`;
- **демография и отношения**: `character_born`, `character_died`,
  `character_need_critical`, `disease_outbreak`, `migration_occurred`,
  `relationship_stage_changed`, `romance_event`, `follower_betrayal`, `marriage`;
- **прогресс и кризисы**: `glory_earned`, `reputation_changed`, `raid_occurred`,
  `faith_milestone`, `chronicle_entry_added`, `village_captured`.

Кампанийный путь выбора события (D-202): `UIManager.decision_made` →
`GameManager._on_decision_made` → `CrisisEventSystem.resolve_event_choice`.
Ход дня: `main.gd._advance_day()` → `GameManager.on_day_passed()` →
`crisis_event_system.gd` (триггеры событий и кризисов).

**Работающий носитель панели события** — fallback
`UIManager._create_simple_decision_panel` / `_create_simple_crisis_panel`;
сцен `assets/ui/panels/decision_panel.tscn` и `crisis_panel.tscn` в репо нет
(Q-M83/T-132), класс `scripts/ui/decision_panel.gd` никем не instantiated.

## 5. Пайплайн сцен

- Корневая сцена: `run/main_scene = res://scenes/main_menu.tscn`.
- Переходы меню (`scripts/ui/main_menu.gd`): «Продолжить» → `SCENE_CONTINUE`,
  «Новая игра» → `character_creation.tscn`, отдельная точка входа в арену —
  `res://scenes/city_arena.tscn`.
- Корневые сцены: `main_menu.tscn`, `main/main.tscn` (кампания/мир),
  `battle.tscn` (бой), `city_arena.tscn`, `battle_view.tscn` (поле боя),
  `world/map_generator.tscn` (генерация карты), `probe/balance_probe.tscn` и
  `probe/ScenarioPilot.tscn` (балансовые прогоны).
- **Все 51 сцена репо к чему-то подвешены** (замер 2026-10-26: сцен, не
  загружаемых и не инстансируемых ни из одного `.gd`/`.tscn`, — 0). «Мёртвых»
  сцен в списке нет; расхождение доков с кодом — это пробел в описаниях, а не
  мусор в игре.
- Панели боя и HUD (`ui/battle_ui.tscn`, `ui/battle_spellbook_panel.tscn`,
  `ui/damage_number.tscn`, `ui/status_orb.tscn`, `ui/retaliation_arrow.tscn`)
  поднимаются сценой боя; юнит-сущности — `entities/*.tscn`
  (`enemy_entity.tscn`, `hero_visuals.tscn`, `resource_node.tscn`,
  `dest_marker.tscn` и др.).
- Кто поднимает отдельные сцены (замер по вызовам `load`/`instantiate`):
  `world_spawner.gd` — объекты карты `entities/village_entity.tscn`,
  `entities/chest_entity.tscn`, `entities/scroll_entity.tscn`,
  `entities/resource_entity.tscn`; `battle_view.gd` — бой: `entities/hero_figure.tscn`,
  `ui/floating_text.tscn`, `ui/obstacle_label.tscn`; `endgame_controller.gd` —
  `ui/game_over_screen.tscn`; `ui/resource_collect_popup.tscn` инстансируется
  сценой `ui/adventure_ui.tscn`.
- Сгенерированная сцена: `ui/artifact_inventory_screen.tscn` из
  `scripts/build/gen_inventory_scene.gd` — правка сцены без правки генератора
  расходится (T-219).

## 6. Сейв-пайплайн

- **Носитель**: `scripts/campaign/save/mvp_save_manager.gd` (`class_name
  MvpSaveManager`), путь `user://mvp_save_slot_%d.json`
  (`PATH_TEMPLATE`), `SLOT_COUNT = 3`, кампанийный слот — `CAMPAIGN_SLOT = 1`.
- **Конверт**: `{"version": {"major", "minor"}, "state": {...}}`
  (`MvpSaveSchema.current_version()`, `CURRENT_MAJOR = 1`, `CURRENT_MINOR = 0`).
- **Секции `state`** (`MvpSaveSchema.SECTIONS`, тип проверяется при загрузке):

| Ключ | Тип | Что внутри (комментарий схемы) |
| --- | --- | --- |
| `campaign` | Dictionary | `{turn, seed, phase}` |
| `resources` | Dictionary | `{food, wood, iron, …}` |
| `population` | Dictionary | `{count, housing}` |
| `party` | Array | `[{id, class, race, level, xp, stats{}, luck}]` |
| `city` | Dictionary | здания, районы, гексы (T-030) |
| `map` | Dictionary | регион, туман, узлы |
| `prestige` | Dictionary | `{ledger: [{turn, source, amount}]}` — **только ledger** |
| `sign` | Dictionary | состояние Знака (R1) |

- **Запрещённые ключи** (`MvpSaveSchema.DERIVED_KEYS` — производные, в сейве быть
  не может): `ladder`, `prestige_balance`, `effective_stats`, `morale`.
  Пункт `morale` — то же основание, что и у снятия шкалы «морали» (K-M14):
  производное состояние не хранится, а пересчитывается.
- **Проверка**: `MvpSaveSchema` валидирует наличие секций, их типы и отсутствие
  производных ключей; тесты — `tests/campaign/test_mvp_save.gd`,
  `tests/campaign/test_campaign_victory.gd`, `tests/campaign/test_turn_driver.gd`.
- **Хроника** (`chronicle_log.gd`) — отдельный писатель, секции `chronicle` в
  схеме нет; описание хроники в [[08-tech]] обязано это отражать.

## 7. Ввод (из `project.godot [input]`)

В игре **пять** именованных действий. Всё остальное — прямые клавиши UI-сцен
(Tab/Esc/H и т. п.), они в `InputMap` не объявлены и описаны в
[[07-ui-ux#Управление (по input map)]].

| Действие | Привязки | Обработчик |
| --- | --- | --- |
| `camera_up` | `W`, `↑` | `scripts/world/world_camera.gd` (`Input.is_action_pressed`) |
| `camera_down` | `S`, `↓` | `scripts/world/world_camera.gd` |
| `camera_left` | `A`, `←` | `scripts/world/world_camera.gd` |
| `camera_right` | `D`, `→` | `scripts/world/world_camera.gd` |
| `mute` | `M` | `scripts/autoload/sound_manager.gd` (`_unhandled_input` → `is_action_pressed(&"mute")`) |

## 8. Как сверять

```bash
python3 scripts/audit_docs_vs_code.py          # текст; exit 1 — есть расхождение
python3 scripts/audit_docs_vs_code.py --json   # машиночитаемо
python3 scripts/check_docs_links.py            # связность wikilink-графа
```
