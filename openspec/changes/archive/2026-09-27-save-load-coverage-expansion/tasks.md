# Tasks: save-load-coverage-expansion

> **Status (2026-09-27):** Phase 1–4 done; Phase 5 (close cycle) in progress.

## 1. Аудит и матрица

- [x] 1.1 Инвентаризовать все stateful-подсистемы (grep `var _` по systems/managers/entities/world + static vars)
  - Основной live-путь: `WorldPersistence.save_game()` → `SaveData` (v7) →
    `apply_loaded_save()`. Legacy-путь (orphaned): `GameManager.save_game()`
    (JSON, v1) — живёт в `scenes/main/main.tscn`, который нигде не загружается.
- [x] 1.2 Построить матрицу «подсистема → сериализовано? → roundtrip-тест?» в `doc/SAVE_MATRIX.md`
  - 16 строк; gaps: LegendTracker (мёртвое `save_data.legend`), GloryTracker
    (нет serialize), WorldSeasons (static), Crisis (legacy, без roundtrip-теста);
    D&D profiles — `[~]` deferred (не live-wired); ArtifactRegistry — N/A
    (каталог, не player-state).
- [x] 1.3 Найти все `static var` с игровым состоянием (baseline: `WorldSeasons._turns_in_season`)
  - Полный grep: **единственное** игровое — `WorldSeasons._turns_in_season`.
    Остальные static — кэши/RNG/service-locator (таблица в матрице).

## 2. Версионирование

- [x] 2.1 Поле `save_version` в world-state dict; loader читает отсутствующее как v1
  - **Аудит: уже выполнено.** `SaveData.version` (CURRENT_VERSION=7);
    `from_dict`: `int(data.get("version", 1))` — отсутствующее = v1;
    `generator_version` для мап-генератора.
  - v7 добавлен без явной миграции (новые поля читаются с дефолтами — no-op,
    допустимо; зафиксировано в матрице).
- [x] 2.2 Каркас миграций `migrate_vN_to_vN+1()` + тест на фикстуре v1
  - **Аудит: уже выполнено.** `_migrate_v1_to_v2` … `_migrate_v5_to_v6` в
    `SaveData.from_dict`; тесты: `test_save_v3.gd` (фикстура v2 → current),
    `test_save_data_garbage.gd` (фикстура v1 + мусор + version=999).

## 3. Закрытие gaps (по матрице 1.2)

- [x] 3.1 Crisis: активный кризис (фаза, таймеры, выбранные варианты) в save/load
  - Legacy-система self-contained: `serialize_state/deserialize_state` уже
    покрывают фаза/таймеры/события/законы (включая восстановление
    `_crisis_start_day` из истории). В main SaveData не вешать — live-мира
    кризисов пока нет (контент придёт в crisis-content-seasonal-rare-events).
  - ✅ `tests/functional/save_roundtrip_crisis.gd` (4 теста).
- [x] 3.2 Seasons: `_turns_in_season` → инстанс-состояние или явная запись в сейв (+тест)
  - `WorldSeasons.get_turns()/set_turns(n)`; `WorldStateDelta.season_turns`;
    запись в `WorldPersistence.save_game`, restore в `apply_loaded_save`.
  - ✅ `tests/functional/save_roundtrip_seasons.gd` (4 теста).
- [x] 3.3 Quests/reputation: прогресс квестов и репутация фракций roundtrip
  - ✅ `tests/functional/save_roundtrip_quests_reputation.gd` (4 теста:
    прогресс, completed, faction_rep + rep_history, legacy-формат).
- [x] 3.4 Legend/glory trackers roundtrip
  - `GloryTracker.serialize()/deserialize()`; `WorldStateDelta.glory_state`
    (restore в `apply_loaded_save`); `save_data.legend` оживлён:
    `WorldPersistence.legend_state`, `HeroLifecycleSystem.get_legend_state()/
    restore_legend_state()`, `WorldSaveLoadService.set_lifecycle()`,
    wiring в `WorldController._ready` + restore в `world_bootstrap`.
  - ✅ `tests/functional/save_roundtrip_legend_glory.gd` (5 тестов).
- [x] 3.5 ArtifactRegistry: собранные артефакты roundtrip
  - **Аудит: N/A.** ArtifactRegistry — каталог определений (перерегистрируется
    в `_ready`); собранные артефакты живут в hero inventory (строка 1).
- [~] 3.6 D&D combatant profiles — только если live-wired (иначе `[~]` deferred до Phase 6 dnd-battle-system)
  - **Deferred.** `DnDCombatantProfile.new()` не вызывается в live-коде
  (battle-scoped, выводится из hero-статов при создании боя).

## 4. Регрессия и политики

- [x] 4.1 Набор `game/tests/functional/save_roundtrip_*.gd`: по одному тесту на строку матрицы
  - `save_roundtrip_seasons.gd`, `save_roundtrip_legend_glory.gd`,
    `save_roundtrip_crisis.gd`, `save_roundtrip_quests_reputation.gd`,
    `save_roundtrip_world_state.gd` (session/chronicle/shards/characters).
    Hero — `test_hero_serialize.gd` + `test_save_roundtrip.gd`;
    world-delta/cities/date/fog — существующие тесты.
- [x] 4.2 Правило в спеке: новая stateful-подсистема без roundtrip-теста не мержится (checklist в CONTRIBUTING)
  - Раздел «Правило save/load» в `CONTRIBUTING.md` + ссылка на SAVE_MATRIX.md.
- [x] 4.3 Полный прогон зелёный
  - 1802 тестов (1781 baseline + 21 новых) | 62 errors + 4 failures =
    baseline (test_spells_json, test_crisis_events — pre-existing). 0 регрессий.

## 5. Закрытие цикла

- [x] 5.1 Обновить матрицу до «все зелёные»
  - `doc/SAVE_MATRIX.md`: все 16 строк ✅/N/A/`[~]`; план закрытия gaps — выполнен.
- [ ] 5.2 `/opsx-sync` save-migration → main specs
- [ ] 5.3 Архивация
