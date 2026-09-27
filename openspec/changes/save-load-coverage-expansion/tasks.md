# Tasks: save-load-coverage-expansion

> **Status (2026-09-27):** propose готов; apply не начинался.

## 1. Аудит и матрица

- [ ] 1.1 Инвентаризовать все stateful-подсистемы (grep `var _` по systems/managers/entities/world + static vars)
- [ ] 1.2 Построить матрицу «подсистема → сериализовано? → roundtrip-тест?» в `doc/SAVE_MATRIX.md`
- [ ] 1.3 Найти все `static var` с игровым состоянием (baseline: `WorldSeasons._turns_in_season`)

## 2. Версионирование

- [ ] 2.1 Поле `save_version` в world-state dict; loader читает отсутствующее как v1
- [ ] 2.2 Каркас миграций `migrate_vN_to_vN+1()` + тест на фикстуре v1

## 3. Закрытие gaps (по матрице 1.2)

- [ ] 3.1 Crisis: активный кризис (фаза, таймеры, выбранные варианты) в save/load
- [ ] 3.2 Seasons: `_turns_in_season` → инстанс-состояние или явная запись в сейв (+тест)
- [ ] 3.3 Quests/reputation: прогресс квестов и репутация фракций roundtrip
- [ ] 3.4 Legend/glory trackers roundtrip
- [ ] 3.5 ArtifactRegistry: собранные артефакты roundtrip
- [ ] 3.6 D&D combatant profiles — только если live-wired (иначе `[~]` deferred до Phase 6 dnd-battle-system)

## 4. Регрессия и политики

- [ ] 4.1 Набор `game/tests/functional/save_roundtrip_*.gd`: по одному тесту на строку матрицы
- [ ] 4.2 Правило в спеке: новая stateful-подсистема без roundtrip-теста не мержится (checklist в CONTRIBUTING)
- [ ] 4.3 Полный прогон зелёный

## 5. Закрытие цикла

- [ ] 5.1 Обновить матрицу до «все зелёные»
- [ ] 5.2 `/opsx-sync` save-migration → main specs
- [ ] 5.3 Архивация
