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


## 3в. Городской слой `scripts/city/` и ядро `scripts/core/`

Пятый свод T-279. Два слоя в одной таблице-паре намеренно: `core/` — то, чем
городской цикл и бой пользуются не глядя (планировщик фаз, контекст хода,
геометрия гексов, логгер), а `city/` — то, что крутится внутри этого планировщика.
Колонка «кто зовёт» снималась двумя грепами (имя класса и путь `preload`), иначе
половина ядра выглядела бы мёртвой — см. сноску про `Platform`.

### Городской цикл `scripts/city/`

| Класс | Что делает | Кто зовёт |
| --- | --- | --- |
| `CityTurnProcessor` | оркестратор городского хода: запускает под-процессоры из `processors/` в фиксированном порядке и наружу пробрасывает их сигналы (смена масштаба, нарушение зонирования, репутация, миграция, найм, уровень, рейд, событие) | мировой путь — `world/world_bootstrap.gd:389`; живой путь — `city/arena_turn_runner.gd:43` (арена) |
| `CampaignCityProgression` | уровень города → потолок застроенных клеток (`CELL_LIMITS`, 11 уровней) и разбор занятости | `ui/city_screen.gd`, `city/campaign_building_construction_service.gd`, баланс-сценарий |
| `CampaignBuildingPlacement` | куда вообще можно поставить здание: клетки города из колец (`ArenaRingSystem.ARENA_CENTER` + `CITY_RING_MAX`), соседние модификаторы, `CityCheck` с причиной | `ui/campaign_city_board.gd`, `ui/city_screen.gd`, `economy/economic_turn_processor.gd`, `city/campaign_building_merger.gd` |
| `CampaignBuildingConstructionService` | заявка на стройку одним вызовом: `explain_request` (каталог → размещение → прогрессия) → списание ресурсов транзакцией с поток-тегом `construction:<id>` → экземпляр здания в очереди или сразу активный; отказа без причины не бывает | `ui/city_screen.gd` (кнопка стройки), баланс-сценарий |
| `CampaignConstructionProcessor` | фазовый процессор кампанийной стройки (`&"campaign_construction"`, приоритет 9): двигает очередь, доводит завершённые | `campaign/campaign_composition.gd:318` — вызывает `process(ctx)` **напрямую**, не через планировщик |
| `ProsperitySystem` | пересчёт благосостояния города: база + еда − голод + промышленность + вклад зданий | `city/processors/prosperity_processor.gd`, `city/processors/level_up_processor.gd`, `ui/city_screen.gd` |
| `ReputationSystem` | репутация и её полосы (`REBELLION … GOLDEN_AGE`); проверка лидерства через `systems/leadership_check.gd` | `city/raid_system.gd`, `city/city_events.gd`, процессоры благосостояния, `ui/city_screen.gd` |
| `ZoningSystem` | можно ли повесить зону на клетку; причины — живым текстом в `CityCheck`: «Центр города недоступен для застройки», «Производство — не ближе N клеток от центра», «Требуется специальная площадка», «Неизвестный тип зоны» | `city/processors/zoning_processor.gd` |
| `ScaleShiftManager` | полоска масштаба по населению (`SCALE_TIERS` → «Селение/Деревня/Город/Метрополия») | `city/processors/scale_processor.gd` |
| `ArenaTurnRunner` | демо-прогон города без игрока: кольцо, кластеры, шторм, экономика, городской процессор — по оборотам | `world/city_arena_view.gd` (сцена `scenes/city_arena.tscn`, вход из главного меню) |
| `ArenaDemoScenario` | функция оценки для этого прогона: золото, промышленность, благосостояние, уровень, население, запас еды минус дни голода | `world/city_arena_view.gd`, тюнер `build/tune_city_arena.gd` |

### Ядро `scripts/core/`

| Класс | Что делает | Кто зовёт |
| --- | --- | --- |
| `TurnPhaseProcessor` | базовый класс фазы: `get_phase_id()`, `get_priority()`, `process(ctx) → Dictionary` | наследники в `city/processors/` и `economy/`; контракт — тип в сигнатурах планировщика |
| `TurnContext` | контекст оборота: номер хода, дата, сезон, погода, флаг кампании, словарь-перехватчик между фазами | планировщик, `city/city_turn_processor.gd`, экономические процессоры |
| `TurnScheduler` | порядок фаз по приоритету, сигналы `turn_started`/`phase_completed`/`turn_completed` | мировой путь — `world/world_bootstrap.gd:362`; баланс-разбор — `balance/campaign_city_balance_scenario.gd:84`. Кампанийный ход им **не** пользуется (см. ниже) |
| `HexUtils` | осевые координаты гексов: соседи по чётности, расстояния, ядро и кольца, конверсии в экранные координаты | `ui/campaign_city_board.gd`, `ui/marker_layer.gd`, `autoload/battle_emulator.gd`, роли пробника, городской цикл — всего 57 файлов ссылаются на него или на путь `preload` |
| `BattleRules` | разрешение боя по лестнице перевеса (02d v1.2 §3.2, K2): кубиков нет, исход = эффективная атака − эффективная защита, Удача сдвигает пороги зон; полностью детерминировано | `systems/battle_attack_sequence.gd`, `systems/battle_action_resolver.gd`, `systems/battle_input.gd`, `ui/battle_ui.gd` |
| `BattleFX` | эффекты поля боя: каст, попадание, смерть — рисует поверх `BattleView` | `systems/battle_controller.gd` (`setup(view)`) |
| `GameLogger` | цветной лог с ровной колонкой тегов (`TAG_WIDTH`); в headless тег печатается без color-разметки, чтобы не засорять вывод тестов | `autoload/settings.gd`, `autoload/spellbook_registry.gd`, `autoload/template_bootstrap.gd`, `ui/save_load_screen.gd`, `ui/artifact_chest_dialog.gd` |
| `Platform` | три вопроса про окружение: headless ли, автоквита ли, тестовый ли прогон | только через `preload`-алиас `_Platform`: `autoload/settings.gd`, `autoload/sound_manager.gd`, `entities/hero_controller.gd`, `core/game_logger.gd`, `world/world_controller.gd` |
| `SaveData` | форма сейва: `CURRENT_VERSION = 10`, версия генератора карты (`CURRENT_GENERATOR_VERSION = 2` — старые сейвы играют старым правилом, добыча не теряется), сериализация секций | `world/world_save_load_service.gd`, `ui/main_menu.gd`, `ui/save_load_screen.gd`, `world/map_spawner.gd` |

**Планировщик — не общий.** Кампанийный ход (тот, что двигает кнопка HUD) идёт
через `TurnDriver` и `CampaignComposition`, а городской цикл мирового режима —
через `TurnScheduler`. Один и тот же процессор стройки исполняют оба: мировой путь
регистрирует его в планировщике, кампанийный вызывает `process(ctx)` напрямую
(`campaign/campaign_composition.gd:318`, комментарий там же называет это
сознательным). Пока это держится на одном процессе, расхождение не видно; оно
виднó будет в тот день, когда процессор начнёт читать что-то, кроме `ctx`.

**`Platform` не находится грепом по имени.** Все пять потребителей берут его
строкой `const _Platform = preload("res://scripts/core/platform.gd")`, и в
тексте файла слова `Platform` нет вообще. Это тот же урок, что и с `CanonClasses`
в §3б: греп по имени класса находит соседей, а не вызовы, и «никого не зовёт»
после одного грепа — не вывод, а недоказанное утверждение.

## 3г. Боевой слой `scripts/systems/`, `scripts/battle/` и экономика `scripts/economy/`

Шестой свод T-279: то, что происходит внутри боя, и то, что происходит между
боями в городском обороте. Колонка «кто зовёт» — два грепа (имя класса и путь
`preload`), иначе треть слоя выглядела бы мёртвой: алиасы вида
`const _BattleTerrain = preload(...)` не содержат имени класса.

### Бой

| Класс | Что делает | Кто зовёт |
| --- | --- | --- |
| `BattleFlow` | узел-владелец живой сцены боя: `_BATTLE_SCENE` под `root`, сигналы `battle_started`/`battle_completed`, держит ссылку до оверлея «Продолжить» (иначе следующая авто-битва оставила бы сироту под root) | `battle/dnd/battle_factory.gd`, `systems/battle_handoff.gd`, `world/world_battle_coordinator.gd` |
| `BattleTurnExecutor` | порядок ходов: инициатива, смена фазы, перемещение и атака активного юнита — всё наружу сигналами (`execute_move`, `execute_attack`, `pulse_unit`, `floating_text`), UI только слушает | `systems/battle_controller.gd`, `systems/battle_retreat_policy.gd`, `systems/battle_attack_sequence.gd`, пробник баланса |
| `BattleActionResolver` | разрешение действий по лестнице перевеса (T17/D2, 02d v1.2): атака, спасение умирающего (`RESCUE_DC = 10`), захват, толчок; детерминированно, без ГСЧ | `systems/battle_attack_sequence.gd`, `autoload/battle_emulator.gd`, `probe/balance_probe.gd`, `systems/battle_retreat_policy.gd` |
| `BattleDamageResolver` | урон по той же лестнице: все проки (petrify/blind/крит rogue) срабатывают на Триумфе, местность даёт множители защиты и «удар вниз» | `systems/battle_action_resolver.gd` (единственный вызывающий — так и задумано: урон считается в одном месте) |
| `BattleTerrain` | модификатели местности боя (plain/forest/hill/water/fort): лес +30%, холм +50%, форт +75%, вода блокирует, с холма +20% атаки; строится поверх `TerrainCostTable` (`world_to_battle`) | `battle/battle_line_of_sight.gd`, `systems/battle_ai.gd`, `systems/battle_view.gd`, `systems/battle_state.gd` |
| `DNDAbilityScores` | шесть характеристик и модификаторы по таблице (0 → −5 … 20 → +5) | `ui/battle_ui.gd` (HUD), `battle/dnd/battle_factory.gd`, `battle/dnd/battle_bridge.gd`, `battle/dnd/combatant_profile.gd` |
| `DNDAbilityCheck` | d20-проверка с модификатором и преимуществом/помехой; переиспользуется для соперничающих проверок (захват, толчок), спасбросков, Stealth/Perception | `battle/dnd/{grapple,shove,vertical_movement,ability_check}.gd` и живое спасение умирающего в `systems/battle_action_resolver.gd:405` |
| `DNDDeathSaves` | спасброски смерти: 10+ успех, 9− провал, натуральная 20 → 1 HP, натуральная 1 → два провала, 3/3 → стабилен/смерть | `systems/battle_state.gd` (состояние юнита), `systems/battle_turn_executor.gd`, `systems/battle_action_resolver.gd` |
| `RelationshipSystem` | связи команды (team-romance-roleplay D4/D5): bond/trust/romance, стадии, тик хода; `process_turn()` чистый — последствия применяет `HeroRelationshipsComponent.end_turn` | `ui/hero_status_panel.gd`, `systems/TeamDialogSystem.gd`, `entities/hero/components/HeroRelationshipsComponent.gd`, мировой бутстрап |
| `CharismaEvents` | события низкой харизмы лидера: cha 6–7 — стимулы, cha 4–5 — мораль −1, cha 1–3 — d20 против 18 (побег/дезертирство/отказ приказа); детерминизм через `set_rng` на session seed | `city/processors/migration_processor.gd`, `systems/RelationshipSystem.gd` |
| `FactionReputation` | репутация героя с 6 фракциями (−100…+100), полосы и история последних 20 изменений с причиной | `ui/faction_screen.gd`, `systems/quest_system.gd`, `entities/hero/components/hero_stats_component.gd` |
| `WeaponCatalog` | 5 этапов оружия (дерево/камень/железо/сталь/редкое-магия) с весом, прочностью и уроном | `autoload/artifact_registry.gd`, `systems/weapon_tech_service.gd` |
| `LawManager` | ветви законов (Order/Faith/Survival), дерево по `requires`, пассивные модификаторы активных законов, `to_dict`/`from_dict` | **продом — никем.** `LawManager.new()` вызывается только из `tests/unit/systems/test_law_manager.gd`; канал `unlock_law` снят (Q-M81 → (а), D-200), ключ сейва `"law"` из старых сохранений игнорируется явно (`crisis_event_system.gd:310`). Возврат — только с носителем пассивных эффектов: **T-130** |

### Экономика оборота

| Класс | Что делает | Кто зовёт |
| --- | --- | --- |
| `EconomicTurnProcessor` | фаза экономики: производственные цепочки, содержание зданий, истощение ресурсов, еда на резидента (`CAMPAIGN_RESIDENT_FOOD_PER_PERSON = 0.1`) | мировая сборка (`world/world_bootstrap.gd`), арена (`city/arena_turn_runner.gd`), баланс-разбор |
| `ProductionChain` | одна цепочка: входы, выходы, нужные работники, эффект здания → `calculate_output(workers, logistics)` | `economy/economic_turn_processor.gd`, `world/city_building_service.gd`, арена |
| `ResourceContext` | реестр ресурсов города с ёмкостями и строгим режимом: `transact(costs, {}, "construction:<id>")` — транзакция с поток-тегом, сигналы `resource_changed`/`capacity_reached`/`transaction_committed` | `economy/production_chain.gd`, `economy/economic_turn_processor.gd`, `city/processors/scale_processor.gd`, заявка стройки (`City.ensure_resource_ctx`) |

**d20 живёт точечно, а не «легаси целиком».** Комментарий в
`systems/battle_action_resolver.gd` говорит, что d20-путь (`battle/dnd/`) выключен
из основного флоу, — и про **атаку** это правда (T17/D2: атака идёт по лестнице
перевеса). Но три класса того же каталога вызываются живым боем напрямую:
`DNDAbilityCheck` — бросок спасателя (`battle_action_resolver.gd:405`),
`DNDDeathSaves` — состояния DYING/STABLE (`battle_state.gd:423`),
`DNDAbilityScores` — модификаторы в HUD (`battle_ui.gd:211`). Читать
«легаси» как «мёртвый код» здесь значит собрать не тот тикет.

**Имя файла врёт, и греп верит файлу.** `scripts/systems/BattleTerrain.gd`
содержит класс **`HexTerrain`**: при слиянии двух боевых систем класс
переименовали, а файл оставили как был (сноска в шапке об этом говорит).
Живой `BattleTerrain` лежит в `battle/battle_terrain.gd`. Оба живые, но греп по
имени класса находит не тот файл, а две строки `preload` в
`systems/battle_state.gd` и `systems/battle_damage_resolver.gd` маскируют
различие алиасом `_BattleTerrain`. Файл стоит переименовать в имя по классу
(правится вместе с двумя `preload` и `.uid`) — **T-285**.

## 3д. Кампанийный слой `scripts/campaign/` и герой `scripts/entities/`

Седьмой свод T-279: системы, которые живут между боями (население, снабжение,
угрозы, этика), и то, чем в кампании играют — герой-координатор с компонентами.
Почти весь этот слой собирается в одном месте — `campaign/campaign_composition.gd`
— и это не случайность, а способ держать порядок инициализации (см. сноску).

### Кампания

| Класс | Что делает | Кто зовёт |
| --- | --- | --- |
| `CampaignBattle` | бой K-канона кампании: единичные комбатанты (стэков нет), лестница 02d через `BattleRules` с трассировкой ступеней, инициатива «Удача + Ловкость» один раз на бой, Долг судьбы по таблице Б.4, лимит 20 раундов с ничьёй (D-128); без ГСЧ — те же входы дают `battle_report` байт в байт | `campaign/campaign_composition.gd` (сборка и вызов), `ui/battle_info_model.gd` (что показать), баланс-метрики |
| `PopulationSystem` | реестр жителей города вместо счётчика: возрастная модель (трудоспособные 16–60, наставники 60+, `lifespan = 60 + Удача`), рождения по схеме k_pop с аккумулятором дробей, порядок — по uid | `campaign/campaign_composition.gd`, `managers/game_manager.gd`, баланс-метрики |
| `SupplySystem` | еда в походе: ёмкость 10, расход 1/персонаж/переход, >50% ёмкости → +2 к первому спасброску, голод → −2 к атакам до пополнения в городе | `campaign/campaign_composition.gd` (единственный владелец — снабжение нельзя «подключить» откуда-то ещё) |
| `ThreatSystem` | фаза угроз: давление `Base × Wealth × Anomalies × Region_History × Global_Phase`, аккумулятор города, пороги тиров 1–3 → волны, динамические лагеря (D-130), директивы K-R3 | `campaign/campaign_composition.gd`, `campaign/region_map.gd` (лагеря на карте) |
| `EthicsSystem` | этический минимум: журнал событий, оси «Порядок/Свобода · Роскошь/Аскеза · Открытость/Изоляция», сверка на ходах 10 и 20 → репутация; события не пересчитываются при загрузке (I1) | `campaign/campaign_composition.gd`, `campaign/settlement_processor.gd`, `managers/game_manager.gd` |
| `CampaignTrainingService` | тренировка и найм: стоимость по составу партии, «10 жителей на юнит» как предложение (ждёт вердикта автора, носитель — `campaign.json → training.population_per_unit`), alive-модель лимита (D-221: DEAD не занимают слот) | `ui/party_screen.gd` и `ui/party_screen_model.gd` (экран), `ui/campaign_hud.gd`, `campaign/campaign_composition.gd` |

### Герой

| Класс | Что делает | Кто зовёт |
| --- | --- | --- |
| `HeroController` | тонкий координатор героя (481 строка): регистрирует компоненты из `entities/hero/components/`, маршрутизирует их сигналы, делегирует сериализацию, держит обратную совместимость аксессорами (`hero.magic`, `hero.inventory`, `hero.path_id`); компоненты создаются в `_init`, чтобы аксессоры работали до `_ready` | почти весь UI и бой: `ui/hero_model_factory.gd`, `ui/battle_ui.gd`, `ui/info_panel.gd`, `ui/city_screen.gd`, `ui/artifact_inventory_screen.gd`, мировой контроллер |
| `HeroArmyController` | армия героя: `army: Array[UnitStack]`, реестр юнитов через `Services.resolve(&"units")`, новая партия начинается с пустой армии (`start_empty`) | `entities/hero_controller.gd`, `entities/hero/components/hero_army_component.gd`, `ui/artifact_inventory_screen.gd` |
| `HeroMagic` | мана и книжка: `mana_current`/`mana_max` (по умолчанию 20), школы, список `spellbook`, сигнал `changed` | `ui/battle_ui.gd`, `ui/battle_spellbook_panel.gd`, `systems/battle_action_resolver.gd`, `systems/battle_controller.gd` |
| `HeroResources` | карман классических ресурсов героя: стартовые количества по `ResourceType.classic_ids()`, подбор (`pickup_resource`), вклад модификаторов инвентаря; всё наружу одним `resources_changed` | `entities/hero_controller.gd`, `entities/hero/components/hero_resources_component.gd` |
| `HeroRelationshipsComponent` | состояние отношений команды (team-romance-roleplay D1): `pairs` герой↔последователь (bond 0, trust 50, romance 0), `duos` последователь↔последователь (ревность), `last_*_stage` — кэш для детекта переходов | `entities/hero_controller.gd` (как компонент), `systems/RelationshipSystem.gd` (считает стадии из этих чисел) |
| `HeroVisualController` | как герой выглядит на карте: листы персонажа (`scenes/entities/hero_visuals.tscn`, единственный путь — константа, эвристика скана `assets/raw` удалена), маркер цели, орб статуса | `entities/hero_controller.gd`, `entities/hero/components/hero_visual_component.gd`; сам лист превращает в `SpriteFrames` сосед `core/knight_frames_builder.gd` (нормализация кадра по alpha-bbox, иначе анимация дрожит) |
| `Follower` | данные последователя: uid, имя, раса, путь, архетип, черты, модификаторы, способности | `entities/follower_system.gd` (`Follower.new()` при генерации), `entities/hero/components/hero_followers_component.gd` (загрузка из сейва) |
| `CharacterFrames` | анимированные фигурки на поле боя: комплект `battle-demo` (холст 512×512, ступни в (256, 448), дорожки `idle/walk/attack/hit/turn`); таблица — не «все юниты», а только те, кому кадр подходит силуэтом | `systems/battle_view.gd` (единственный рисующий) |

**Слой собирается в одном месте — и это носитель, а не дублирование.**
`campaign/campaign_composition.gd` держит конструкторы `CampaignBattle`,
`PopulationSystem`, `SupplySystem`, `ThreatSystem`, `EthicsSystem`,
`CampaignTrainingService`: у этих систем нет состояния до инициализации, и
единственный владелец порядка их создания — композиция. Исключения видны в
колонке «кто зовёт» и они осмысленны: `ThreatSystem` нужен ещё и `region_map`
(лагеря), `EthicsSystem` — processor'у поселения, тренировка — экрану партии.

**`HeroController` — координатор, а не бог.** Про «бога-героя» судят по 481
строке, но внутри только регистрация компонентов, маршрутизация сигналов,
делегирование сериализации и аксессоры обратной совместности; логика живёт в
`entities/hero/components/` (армия, инвентарь, магия, движение, нужды, крафт,
последователи, отношения, визуал). Снимать этот класс «как лишний» — значит
вернуть 481 строку в девять файлов, где она и была.

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
