# SAVE_MATRIX — матрица покрытия сериализации мира

> save-load-coverage-expansion, задача 1.2. Аудит от 2026-09-27.
> Легенда: ✅ покрыто · ⚠️ gap (закрыть) · `[~]` deferred · N/A

## Архитектура сейвов (факт)

**Основной путь (live):** `WorldPersistence.save_game()` → `SaveData` (JSON через
`SaveManager`, `user://save.json`) → `apply_loaded_save(data, ctx)`.
Вызывается из `WorldController.save_game()` / `WorldSaveLoadService` /
`world_shortcuts.gd` (F5/F9).

**Версионирование:** `SaveData.CURRENT_VERSION := 7`, `generator_version := 1`.
Миграции: `_migrate_v1_to_v2` … `_migrate_v5_to_v6`. Отсутствующее поле
`version` трактуется как v1 (`int(data.get("version", 1))`). v7 добавлен без
явной миграции (новые поля читаются с дефолтами — no-op миграция, допустимо).

**Legacy-путь (orphaned):** `GameManager.save_game(slot)` — отдельный JSON
(`user://saves/<slot>.json`, `SAVE_FORMAT_VERSION := 1`) со своим
`crisis_state`. `GameManager` + `CrisisEventSystem` живут в `scenes/main/main.tscn`,
который **ниоткуда не загружается** (main scene = `main_menu.tscn`, live-мир =
`scenes/world.tscn`). Путь self-contained, но не live.

## Матрица

| # | Подсистема | Состояние | Сериализовано? | Roundtrip-тест? | Статус |
|---|---|---|---|---|---|
| 1 | Hero (11 компонентов: stats/inventory/magic/followers/needs/movement/tools/skills/resources/combat/strategic) | `hero.serialize()` | ✅ `save_data.hero` | ✅ `test_save_roundtrip` + `test_hero_serialize` (stats/army/resources) | ✅ |
| 2 | Квесты + репутация фракций (`HeroStatsComponent.quest_state`, `faction_rep`, `rep_history`) | dict | ✅ через hero-компонент | ✅ `save_roundtrip_quests_reputation` | ✅ |
| 3 | WorldStateDelta (villages/enemies/resources/chests/fog/enemy_growth) | `delta.serialize()` | ✅ `save_data.world` | ✅ `test_world_delta_roundtrip` | ✅ |
| 4 | Города (`city.serialize()`) | per-city dict | ✅ `save_data.cities` | ✅ `test_city_persistence` | ✅ |
| 5 | Персонажи (`character_registry`) | array | ✅ `save_data.characters` | ✅ `save_roundtrip_world_state` | ✅ |
| 6 | GameSession (state/battles/successions) | `session.serialize()` | ✅ `save_data.session` | ✅ `save_roundtrip_world_state` | ✅ |
| 7 | Chronicle | `chronicle.to_array()` | ✅ `save_data.chronicle` | ✅ `save_roundtrip_world_state` | ✅ |
| 8 | Date (month/week/day) | dict | ✅ `save_data.date` | ✅ `test_save_roundtrip` | ✅ |
| 9 | Fog/visibility | `world_delta.fog_explored` | ✅ | ✅ (в составе 3) | ✅ |
| 10 | Shards (мульти-шарды) | dict | ✅ `save_data.shards` | ✅ `save_roundtrip_world_state` (JSON-цикл) | ✅ |
| 11 | **LegendTracker** (`hero_lifecycle_system._legend`: path/level/glory/generation/battles/deaths) | fields | ✅ `save_data.legend` (3.4: `WorldSaveLoadService.set_lifecycle` + `WorldPersistence.legend_state`; bootstrap-restore в `world_bootstrap`) | ✅ `save_roundtrip_legend_glory` | ✅ |
| 12 | **GloryTracker** (`CityManager.glory`: events/total) | fields | ✅ `WorldStateDelta.glory_state` (3.4: serialize/deserialize + restore в `apply_loaded_save`) | ✅ `save_roundtrip_legend_glory` | ✅ |
| 13 | **WorldSeasons._turns_in_season** | **static var** | ✅ `WorldStateDelta.season_turns` (3.2: `WorldSeasons.get_turns/set_turns`) | ✅ `save_roundtrip_seasons` | ✅ |
| 14 | **CrisisEventSystem** (legacy, orphaned main.tscn: фаза/таймеры/варианты) | fields | ✅ `serialize_state()` wired в GameManager-JSON (legacy-путь) | ✅ `save_roundtrip_crisis` | ✅ |
| 15 | ArtifactRegistry (autoload) | каталог определений | N/A — не player-state; перерегистрируется в `_ready`; собранные артефакты — в hero inventory (строка 1) | N/A | ✅ (3.5 закрыт аудитом) |
| 16 | D&D combatant profiles (`BattleUnit.dnd_profile`) | battle-scoped | N/A — **не live-wired** (`DnDCombatantProfile.new()` только в тестах) | N/A | `[~]` **3.6** — deferred до dnd-battle-system |

## `static var` с игровым состоянием (задача 1.3)

Полный grep `static var` по `scripts/`:

| Файл | Поле | Игровое состояние? |
|---|---|---|
| `world_seasons.gd:15` | `_turns_in_season` | **ДА** (единственное) — gap 3.2 |
| `shard_manager.gd:9` | `_instance` | Нет — service-locator (singleton) |
| `reputation_system.gd:52`, `weapon_tech_service.gd:10`, `city_service.gd:8-9` | `_rng` | Нет — RNG без персист-состояния (seed не критичен: детерминизм через `session.make_rng()`) |
| `follower_system.gd:11-12` | `_default_registry`, `_default_raceclass` | Нет — ленивые кэши реестров |
| `hero_tools.gd:6`, `unit_sprites.gd:4-5`, `theme_config.gd:155`, `placeholder_texture.gd:7`, `hex_draw.gd:7`, `building_defs.gd:11-13`, `need_type.gd:7`, `resource_icons.gd:48`, `resource_atlas.gd:11/49-50`, `template_engine.gd:4`, `terrain_cost_table.gd:15-17`, `battle_spell_bridge.gd:9-25` | кэши/константы | Нет |

**Итог 1.3:** единственный `static var` с игровым состоянием —
`WorldSeasons._turns_in_season`.

## План закрытия gaps (выполнено)

- **3.1 Crisis:** ✅ `tests/functional/save_roundtrip_crisis.gd` — roundtrip
  `CrisisEventSystem.serialize_state/deserialize_state` (legacy-система
  self-contained; в main SaveData не вешать — live-мира кризисов пока нет, новый
  контент придёт в `crisis-content-seasonal-rare-events`).
- **3.2 Seasons:** ✅ `WorldStateDelta.season_turns` + `WorldSeasons.get_turns/set_turns`;
  test `save_roundtrip_seasons.gd`.
- **3.3 Quests/rep:** ✅ `save_roundtrip_quests_reputation.gd` через
  `HeroStatsComponent.serialize/deserialize`.
- **3.4 Legend/Glory:** ✅ `save_data.legend` оживлён (`WorldSaveLoadService.set_lifecycle`,
  `WorldPersistence.legend_state`, restore в `world_bootstrap`); GloryTracker —
  `serialize/deserialize` + `WorldStateDelta.glory_state` + restore в
  `apply_loaded_save`; test `save_roundtrip_legend_glory.gd`.
- **4.1:** ✅ `save_roundtrip_world_state.gd` (session/chronicle/shards/characters).
  Правило зафиксировано в CONTRIBUTING.md («Правило save/load»).
