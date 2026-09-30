# Proposal: archive-completed-changes

**Status:** Completed — выполнено 2026-09-27 (sync + archive, см. tasks.md §5).

## Why

Аудит незакрытых циклов (2026-09-27) выявил: 8 legacy-изменений имеют статус completed, но не архивированы; у нескольких активных изменений delta-specs не синхронизированы в `openspec/specs/` (crisis-manager/event-manager/event-dialog из dynamic-world-crisis-system — tactical-combat уже синхронизирован). Каталог `changes/` остаётся засорённым → нарушается принцип «specs = истина, changes = черновики».

## What Changes

Только операции жизненного цикла OpenSpec, без правок кода:

1. **Sync:** перенести оставшиеся delta-specs завершённых работ в main specs (`openspec/specs/`).
2. **Archive:** переместить завершённые изменения в `openspec/changes/archive/YYYY-MM-DD-<name>/`:
   - 8 legacy-циклов со статусом completed (backfilled proposals): auto-balance-mcp-framework, beta-readiness-polish, class-specific-scenarios-stress-test, content-expansion-pack-1, core-game-loops-expansion, localization-ready, nwn-arsenal-integration, spell-system-audit-class-race-progression
   - map-generation-improvement (Implemented)
   - dnd-battle-system — ПОСЛЕ подтверждения, что scope-out TASK_11/12 принят (создан `dnd-verticality-falling`) ✅
   - dynamic-world-crisis-system — ПОСЛЕ закрытия верифицируемых пунктов и создания `crisis-content-seasonal-rare-events` ✅
3. Оставить открытыми: `world-controller-decoupling` (R2–R7), `tactical-battle-system` (до решения о судьбе 3.x–9.x → создан `tactical-combat-implementation`), новые propose-циклы.

## Capabilities

- Нет изменений спеков содержимого; только перенос артефактов.

## Impact

- `openspec/changes/` → `openspec/changes/archive/`
- `openspec/specs/` (+ новые main specs из deltas)
- Риск: нулевой для рантайма; единственная проверка — целостность ссылок между proposal'ами (Related Documents).

## Acceptance Criteria

- [x] 1. В `changes/` остались только незавершённые циклы
- [x] 2. Каждая archived-запись имеет дату и полный набор артефактов
- [x] 3. Main specs содержат все синхронизированные возможности
- [x] 4. Кросс-ссылки между циклами не битые
