# Tasks: archive-completed-changes

> **Status (2026-09-27):** процессный цикл; **выполнен 2026-09-27**: sync 8 delta-specs → main specs, 13 циклов перенесены в archive/2026-09-27-*. Порядок важен: сначала sync, потом archive.

## 1. Sync delta-specs → main specs

- [x] 1.1 `dynamic-world-crisis-system`: crisis-manager, event-manager, event-dialog → `openspec/specs/`
- [x] 1.2 Проверить актуальность уже синхронизированных (tactical-combat, balance-probe, hero-identity и др.) против кода
- [x] 1.3 Зафиксировать отсутствующие main specs для архивных циклов (audit-only правка README в specs/)

## 2. Архивация legacy-циклов (completed, backfilled)

- [x] 2.1 auto-balance-mcp-framework → archive/2026-09-27-…
- [x] 2.2 beta-readiness-polish → archive
- [x] 2.3 class-specific-scenarios-stress-test → archive
- [x] 2.4 content-expansion-pack-1 → archive
- [x] 2.5 core-game-loops-expansion → archive
- [x] 2.6 localization-ready → archive
- [x] 2.7 nwn-arsenal-integration → archive
- [x] 2.8 spell-system-audit-class-race-progression → archive
- [x] 2.9 map-generation-improvement → archive (Implemented; deferred-пункты помечены Won't)

## 3. Архивация основных завершённых циклов

- [x] 3.1 dnd-battle-system → archive (условие: dnd-verticality-falling создан ✅, Notes обновлены)
- [x] 3.2 dynamic-world-crisis-system → archive (условие: задачи 2.4/2.5 вынесены в crisis-content-seasonal-rare-events ✅; sync п.1.1 выполнен)
- [x] 3.3 tactical-battle-system → archive (условие: реализация вынесена в tactical-combat-implementation ✅; spec synced ✅)

## 4. Гигиена

- [x] 4.1 Удалить пустые каталоги/заглушки, проверить `.openspec.yaml` у каждого оставшегося цикла
- [x] 4.2 Обновить индекс/README в `openspec/changes/` (если ведётся)
- [x] 4.3 Прогнать доступную валидацию структуры (manual review при отсутствии CLI)

## 5. Итог выполнения (2026-09-27)

- Синхронизированы новые main specs: crisis-manager, event-manager, event-dialog, rivers, roads, terrain, core-mechanics, height-system (итого 24 capability в openspec/specs/).
- В архив перемещены 13 циклов (12 полных + dynamic-ecosystem-scarce-crafting-overhaul как partially-completed со ссылкой на scarce-crafting-system).
- Открытые циклы после уборки: world-controller-decoupling (R2–R7), tactical-combat-implementation, scarce-crafting-system, dnd-verticality-falling, crisis-content-seasonal-rare-events, save-load-coverage-expansion и этот процессный цикл (закрытие настоящим коммитом).
