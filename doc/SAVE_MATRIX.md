# SAVE_MATRIX — матрица покрытия сериализации

> Требование спеки `save-migration` (`openspec/specs/save-migration/spec.md:10`):
> для каждой подсистемы игрового состояния существует запись здесь и functional-тест
> `save → load → deep-equal`. Файл был заведён в цикле `save-load-coverage-expansion`
> (2026-09-27, 16 строк), удалён при реструктуризации GDD (`5f412a37`) и с тех пор
> ссылка спеки жила в пустоту — T-301. Переснята с кода 2026-10-29, а не с прошлой
> таблицы: прошлая описывала мир как live-носитель, это больше не так.
>
> **Правило (T-301):** строка добавляется вместе с миграцией/секцией, а не
> постфактум. Миграция без строки — незакрытая задача: «покрытие сейва» не должно
> снова восстанавливаться грепом.
>
> Легенда: ✅ покрыто · ⚠️ gap (нет ассерта) · N/A — не состояние игрока.
>
> Файл лежит в `doc/` (адрес из спеки), а не в `docs/`-хранилище: wikilinks здесь
> не работают, `check_docs_links.py` и `audit_docs_vs_code.py` сканируют `docs/`.
> Проверка ссылок этого файла — `scripts/check_save_matrix.py`.

## 1. Три носителя сейва (факт 2026-10-29)

### 1.1 Кампейн-сейв — единственный live-носитель MVP

- Запись: `game/scripts/main/main.gd:201` (конец хода, по настройке
  `Settings.auto_save`, по умолчанию выключена) и `main.gd:_on_menu_requested`
  (выход в меню — всегда, иначе «В меню» теряет прохождение) →
  `save_campaign_slot()` → `MvpSaveManager.save_slot(CAMPAIGN_SLOT, composition.build_save_state())`.
- Чтение: `main.gd:82` → `MvpSaveManager.load_slot(...)` → `CampaignComposition.load_save_state(...)`.
- Схема: `game/scripts/campaign/save/mvp_save_schema.gd` — `SECTIONS` (8 секций,
  только они разрешены на верхнем уровне), `DERIVED_KEYS` (рекурсивный запрет:
  `ladder`, `prestige_balance`, `effective_stats`, `morale`), `SLOT_COUNT = 3`,
  мажорная версия обязана совпадать (`CURRENT_MAJOR = 1`, `CURRENT_MINOR = 0`).
- Контракт round-trip — **байтовый** (T-110): `MvpSaveManager.serialize(state)`
  совпадает после записи/чтения и после пересборки в свежей композиции.
  Вершины: `game/tests/campaign/test_cutover_composite.gd::test_save_load_roundtrip`,
  `game/tests/campaign/test_campaign_victory.gd::test_full_campaign_victory_save_roundtrip`.
- **Слепое место контракта:** под-ключ, пустой с обеих сторон, потерей не считается.
  Зубы — `game/tests/campaign/test_mvp_save.gd::test_finished_campaign_leaves_no_empty_save_section`
  (завершённая кампания обязана оставлять нетривиальным каждый покрываемый
  под-ключ), батарея —
  `game/tools/mut_save_sections.sh` (M1 `map.threats`, M2 `city.sm`, M3 `birth_carry`).

### 1.2 Мир (`SaveData`) — наследный путь, сцена в архиве

`SaveData.CURRENT_VERSION = 10`, `CURRENT_GENERATOR_VERSION = 2`
(`game/scripts/core/save_data.gd`). Носитель сцены — `game/scenes/archive/world.tscn`
(туда же смотрит `game/scripts/autoload/world_state_serializer.gd:130`); живое меню
(`game/scenes/main_menu.tscn`) в мир не ведёт: Continue → `scenes/main/main.tscn`.
Тесты пути зелёные и исполняются в гейте, но из игрового пути вызова нет — строки
раздела 3 помечены «наследие». Смежные хвосты: T-268 (`world_state_serializer.gd`
не зарегистрирован), T-273 (`city_state_serializer.gd` осиротел).

### 1.3 Legacy JSON `GameManager` (кризисы)

`game/scripts/managers/game_manager.gd` — отдельный JSON `user://saves/<slot>.json`,
`SAVE_FORMAT_VERSION = 1`, свой `crisis_state`. `GameManager` — нода в
`game/scenes/main/main.tscn` (строка 14), то есть в живом дереве, но записи идут
только из `save_game(slot)` (F5/F9 мира, не кампейн-цикла). Состояние кризисов
сериализует `game/scripts/systems/crisis_event_system.gd` (`serialize_state` /
`deserialize_state`), покрытие — `game/tests/functional/save_roundtrip_crisis.gd`
(4 кейса, включая «разрешённый кризис не возвращается активным»).

## 2. Матрица кампейн-сейва (live)

Секция/под-ключ → носитель (пишет / читает) → тест → примечание. Значения в
скобках — снимок завершённой кампании (сид 12345, ход 21, `victory`), он же
зафиксирован ассертами в
`test_mvp_save.gd::test_finished_campaign_leaves_no_empty_save_section`.

| Секция · под-ключ | Носитель (write ← read) | Тест | Статус |
|---|---|---|---|
| `campaign` (ход, фаза, статус, seed) | `TurnDriver.to_dict()` ← `from_dict()`, `campaign_composition.gd:701` / `:777` | `test_mvp_save.gd::test_round_trip_i1`, `test_cutover_composite.gd::test_save_load_roundtrip` | ✅ (turn 21, status `victory`) |
| `campaign.final_battle_seen`, `final_raid_repelled` | `campaign_composition.gd:702-703` / `:804-805` | `test_campaign_victory.gd::test_full_campaign_victory_save_roundtrip` (байтовая пересборка после load), `test_mvp_save.gd::test_finished_campaign_leaves_no_empty_save_section` (оба true на финале) | ✅ |
| `campaign.hero_name` | `campaign_composition.gd:704` / `:778` | `test_campaign_wiring.gd::test_hero_name_reaches_save_and_back`, `test_empty_hero_name_roundtrip` | ✅ (на финальной линии — пустая строка, покрыта отдельным кейсом) |
| `campaign.chronicle` (под-ключ) | `ChronicleLog.to_dict()` `:708` / `:796` | `test_chronicle_writers.gd::test_chronicle_survives_save_roundtrip`, `test_old_save_without_chronicle_section_yields_empty_feed` | ✅ (2 записи) |
| `campaign.goals` (под-ключ) | `CampaignGoalTracker.to_dict()` `:711` / `:843` | `test_campaign_goals_m3.gd::test_goals_survive_save_roundtrip`, `test_save_without_goals_section_restores_the_default_set`, `test_ruins_goal_still_reachable_after_load` | ✅ (1 трек) |
| `campaign.ethics` (под-ключ) | `EthicsSystem.to_dict()` `:714` / `:859` | `test_ethics_system.gd::test_composition_ethics_wiring_and_save_migration` | ✅ (7 полей) |
| `campaign.supply` (под-ключ) | `SupplySystem.to_dict()` `:718` / `:789-793` | `test_supply_system.gd::test_composition_integration` | ✅ (4 поля) |
| `resources` | `settlement.stocks` `:721` / `:817` (секция = **вектор поселения**, K-D5) | `test_stocks_registers_seam.gd::test_save_resources_section_is_the_settlement_vector`, `test_mvp_save.gd::test_finished_campaign_leaves_no_empty_save_section` | ✅ (−593.3 / 197.1 / 94.35). Второй регистр (`city.resource_ctx`) в секцию не входит — Q-M120, T-309 |
| `population` | `PopulationSystem.to_dict()` `:722` / `:806` (`birth_carry`, `mig_carry` — `population_system.gd:245-246` / `:255-256`) | `test_cutover_composite.gd::test_save_load_roundtrip`, `test_mvp_save.gd::test_population_carries_survive_save_roundtrip` | ✅ (18 резидентов). Переносы на K-канон-линии = 0.0 (голод, Репутация 0) → whole-state контракт их потерю не видит, поэтому кейс про переносы отдельный |
| `party` | `party.duplicate(true)` `:723` / `:807-814` (+`level` из xp, `ensure_hp` V-5/D-220) | `test_party_wiring.gd::test_party_save_roundtrip`, `test_defeat_status_save_roundtrip`, `test_party_hp_rest.gd::test_migration_on_loaded_save`, `test_mvp_save.gd::test_campaign_city_and_trained_party_state_round_trip` | ✅ (2 юнита) |
| `city.housing`, `city.buildings`, `city.sm`, `city.party_size` | `SettlementProcessor` `:724-728` / `:816-824` (`population` при загрузке — производная ростери, не из сейва) | `test_mvp_save.gd::test_campaign_city_and_trained_party_state_round_trip`, `test_mvp_save.gd::test_finished_campaign_leaves_no_empty_save_section` (buildings 3, sm 3, housing 20, party_size 2) | ✅ |
| `city.districts` | `DistrictSystem.to_dict()` `:730` / `:847` (конфиг и работы берутся из каталога, в сейве — только настроение) | `test_district_system.gd::test_composition_wires_districts_into_save` | ✅ (2 района) |
| `city.campaign_city` | `CampaignCity.serialize()` `:735` / `:828-830` (сначала стартовый город из `campaign.json`, поверх — сохранённое; внутри — `CitySerializer` → `resource_ctx.deserialize`) | `test_campaign_city_carrier.gd::test_save_without_city_section_restores_start_city`, `test_stocks_registers_seam.gd::test_city_spending_skips_the_save_resources_section_but_survives_roundtrip` | ✅ (30 ключей) |
| `map.threats` | `ThreatSystem.to_dict()` `:737` / `:831` | `test_threat_system.gd` (пара `to_dict`/`from_dict`), `test_mvp_save.gd::test_finished_campaign_leaves_no_empty_save_section` (11 ключей на финале) | ✅ (композиционный round-trip — только байтовым контрактом, поэтому кейс о непустоте обязателен) |
| `map.region` | `RegionMap.to_dict()` `:737` / `:833` (+`_connect_region_map()`) | `test_campaign_wiring.gd::test_region_map_in_save_and_back`, `test_old_save_without_region_starts_in_city` | ✅ (9 регионов) |
| `prestige.ledger` | `prestige_ledger` `:738` / `:849` (в сейве **только** журнал, баланс — `DERIVED_KEYS`) | `test_cutover_composite.gd::test_prestige_ledger_shape_and_balance`, `test_mvp_save.gd::test_derived_keys_rejected` | ✅ (12 записей) |
| `sign` | `SignSystem.to_dict()` `:739` / `:781-785` (обратная совместимость `{id}` → `sign_id`) | `test_signs.gd::test_save_roundtrip_preserves_sign`, `test_save_roundtrip_empty_sign_stays_empty`, `test_sign_chronicle.gd::test_load_replays_no_sign_events` | ✅ (`state` DORMANT…, `id` на финале пуст — покрыто кейсом пустого Знака) |
| версия схемы | `MvpSaveSchema.current_version()` / `is_compatible()` | `test_mvp_save.gd::test_version_minor_compatible`, `test_version_major_incompatible` | ✅ |
| слоты, атомарность, мусор | `MvpSaveManager.save_slot` / `load_slot` | `test_mvp_save.gd::test_three_slots_and_bounds`, `test_atomic_no_tmp_left`, `test_byte_determinism`, `test_unknown_and_missing_sections`, `test_every_missing_section_rejected` | ✅ |

## 3. Матрица наследного мира (`SaveData` v10)

Версия → поле/система → тест → примечание. Цепочка миграций: `from_dict` применяет
`if version < N` последовательно (`save_data.gd:48-63`); отсутствующий `version`
трактуется как v1. Миграции v6→v7 нет — v7 был no-op (новые поля читаются с
дефолтами), условие `version < 8` перепрыгивает через него намеренно.

| Версия | Поле / система | Тест | Статус |
|---|---|---|---|
| v1→v2 | `hero.time_mp_spent` (default 0.0) | — | ⚠️ дефолт никто не ассертит: фикстуры (`test_save_v3.gd:12`, `test_save_data_garbage.gd:28`) приходят с уже готовым ключом |
| v2→v3 | `cities`, `characters` (мусор → пустые массивы) | `test_save_v3.gd::test_v2_migration_adds_empty_cities`, `test_from_dict_garbage_collections` | ✅ |
| v3→v4 | `successor`, `legend`, `hero.path_id` | — | ⚠️ миграцию никто не проверяет (поля как таковые покрыты: `save_roundtrip_legend_glory.gd`, `test_legend_chronicle.gd`) |
| v4→v5 | `session` | `test_endgame.gd::test_migrate_v4_to_v5_defaults` | ✅ |
| v5→v6 | `chronicle`, `shards` | `test_legend_chronicle.gd::test_savedata_v5_migrates_to_v6_with_empty_chronicle` | ✅ |
| v6→v7 | нет миграции (no-op) | — | N/A |
| v7→v8 | `hero.crafting` (scarce-crafting-system) | `save_roundtrip_crafting.gd::test_save_data_v7_to_v8_migration`, `test_legacy_hero_save_without_crafting_key` | ✅ |
| v8→v9 | `generator_version` (world-map-art-variety 9.3) | `test_resource_terrain_fit.gd::test_save_migration_markers`, `test_legacy_generation_keeps_old_rules` | ✅ |
| v9→v10 | рюкзак: сетка вместо списка (`inventory.cells`, «перевес» −1,−1, идемпотентность) | `save_roundtrip_inventory.gd::test_v9_flat_list_migrates_without_loss`, `test_v9_migration_is_idempotent`, `test_placements_survive_save_load`, `test_rotated_placement_survives_save_load` | ✅ |

Поле → покрытие (поля `SaveData.to_dict()`, наследный путь):

| Поле | Тест | Статус |
|---|---|---|
| `run_seed`, `hero` (клетка, компоненты) | `test_save_roundtrip.gd::test_save_data_roundtrip` | ✅ |
| `date` | — | ⚠️ лежит в фикстуре `test_save_data_roundtrip`, ассерта на месяц/неделю/день нет (в прошлой матрице строка была ✅ — не подтвердилось) |
| `world` (`WorldStateDelta`: деревни, враги, ресурсы, сундуки) | `test_save_roundtrip.gd::test_world_delta_roundtrip` | ✅ |
| `world.fog_explored` | `test_marker_layer_fog.gd`, `test_fog_of_war.gd` (логика тумана), delta-пара — в составе `WorldStateDelta.serialize` | ✅ |
| `world.glory_state`, `legend` | `save_roundtrip_legend_glory.gd` (5 кейсов) | ✅ |
| `world.season_turns` (перезапись `WorldSeasons._turn_count`) | `save_roundtrip_seasons.gd` (4 кейса) | ✅ |
| `cities` (`CitySerializer`) | `test_save_v3.gd::test_city_roundtrip_full`, `test_city_uid_seq_continuity`, `test_city_unknown_building_skipped`, `test_city_serializer.gd` (в т.ч. миграции v1→v2 города) | ✅ |
| `characters`, `session`, `chronicle`, `shards` | `save_roundtrip_world_state.gd` (4 кейса) | ✅ |
| `generator_version` | `test_resource_terrain_fit.gd::test_save_migration_markers` | ✅ |
| `active_shard_id` | `save_roundtrip_world_state.gd::test_shards_memory_roundtrip` (в составе), отдельного ассерта нет | ⚠️ |
| `is_valid`, битый JSON, будущая версия | `test_save_manager.gd` (15 кейсов), `test_save_data_garbage.gd` (6 кейсов) | ✅ |
| сервис сейва мира (делегаты, endgame-статус) | `test_save_load_service.gd` (6 кейсов) | ✅ |
| экран слотов (UI) | `test_save_load_screen.gd` (2 кейса), `test_campaign_continue.py` (MCP, живое меню) | ✅ |

## 4. Чем покрытие НЕ является

- `game/tests/unit/battle/test_dnd_saves.gd` — **спасбросы** D&D (saving throws:
  формула, DC, криты, смертельные броски), к персистентности отношения не имеет.
  Греп `grep -l save tests/` даёт этот файл первым сверху — в матрицу он не входит
  намеренно.
- `game/tests/ui/test_save_load_screen.gd` — UI-слой слотов (пустые слоты,
  удаление), состояние не сериализуется.
- `game/tests/campaign/test_mvp_save.gd::test_round_trip_i1` — round-trip
  **менеджера** на рукописном литерале состояния, а не пары
  `build_save_state`/`load_save_state`. Пара покрыта другими кейсами того же файла
  и вершинами из §1.1.

## 5. `static var` с игровым состоянием

Перебор `grep -rn "static var" game/scripts`. Состояние игрока несут три поля:

| Файл | Поле | Сейв |
|---|---|---|
| `game/scripts/systems/world_seasons.gd:33` | `_turn_count` | Наследный путь: `world_persistence.gd:73/176` (секция `world.season_turns`). Кампейн-путь: **не хранится**, выводится из `campaign.turn` при загрузке (`campaign_composition.gd:295`) — дедвейна нет, источник один |
| `game/scripts/systems/battle_trophy_service.gd:13` | `_roll_counter` | Не сериализуется: счётчик детерминированных трофеев боя. Между ходами боя не остаётся (трофей начисляется в бою, сейв — на конце хода), сброс на загрузке безвреден |
| `game/scripts/campaign/population_system.gd:52-53` | `_birth_carry`, `_mig_carry` | instance-поля (не `static`), но риск того же класса: «забыли в to_dict»: в сейве (`population_system.gd:245-246`), ассерт — `test_mvp_save.gd::test_population_carries_survive_save_roundtrip` |

Остальное — кэши текстур/иконок/артов (`battle_ui.gd:23`,
`campaign_city_board.gd:40`, `campaign_art.gd:26-27`, `theme_config.gd:164`,
`icon_registry.gd:8-9`, `unit_sprites.gd:4-5`), ленивые реестры
(`follower_system.gd:17-18`), РНГ без персист-состояния (`reputation_system.gd:52`,
`migration_processor.gd:25`, `weapon_tech_service.gd:10`, `charisma_events.gd:10`,
`relationship_system.gd:41`) и словари контента (`team_dialog_system.gd:7`,
`hero_tools.gd:6`). Ни одно — не состояние игрока.

## 6. Дыры, которые матрица фиксирует

1. **Состояние идущего боя не сериализуется ни в одном носителе.** У кампейн-сейва
   нет секции боя, у боя нет `serialize`/`to_dict`: выход из-под боя = потеря боя
   (не кампании — ход ещё не записан). Для MVP это осознанно: автосейв пишется на
   конце хода, бой короткий. Строка здесь, чтобы следующий цикл не считал это
   находкой.
2. **`date`, `active_shard_id`, миграции v1→v2 и v3→v4** — ⚠️ выше: поля живут,
   ассертов на них нет. Дешёвое закрытие — по одному кейсу на строку, адрес тот же.
3. **Переносы населения на канонической линии равны 0.0** — whole-state контракт
   слеп, зубы у этой строки только у отдельного кейса (§2, `population`) — и то
   только со стороны записи: round-trip-равенство на мутант «`to_dict` пишет 0.0»
   зелёное (0.0 == 0.0 с обеих сторон), поэтому кейс сверяет `to_dict` с живым
   полем, а не только друг с другом (M3).
4. **Два живых регистра припасов** (`settlement.stocks` ↔ `city.resource_ctx`): в
   сейв уходит только вектор поселения, траты города живут в `campaign_city`.
   Сведение — вопрос владельцу **Q-M120**, замер — T-309; пока вопрос открыт,
   обе строки (§2 `resources`, §2 `city.campaign_city`) обязательны к прочтению
   перед любой правкой экономики.
