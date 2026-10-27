# Proposal

## Why

GDD 01-core-loop задаёт канон post-pivot кампании (21 ход, ход = сезон = 20 дней, порядок фаз, бит-каркас, метрики, fail states). Часть уже реализована (`TurnDriver` T-010/T-122, `WorldSeasons`, `TurnScheduler`), но в OpenSpec post-pivot core loop не описан: main specs описывают pre-pivot legacy-слой, а `core-mechanics`/`2026-09-27-core-game-loops-expansion` — устаревшие итерации. Без формального изменения требования «6 фаз», «21 ход», «детерминизм I1», «статус кампании» и «метрики» остаются только в GDD и коде.

## What Changes

- Фиксирует канон: ход = сезон = 20 дней, кампания = 21 ход (Q-M26), season_index = (turn−1) % 4, ход 1 = весна.
- Фиксирует порядок фаз: settlement → player → [caravans, diplomacy — post-MVP no-op слоты] → threats → production (production после threats — T-122); `TurnDriver` — единственный носитель порядка.
- Фиксирует бит-каркас K-M9 (ходы 1/7/14/17/21), детерминизм I1, статус кампании (поражение = wipe партии — единственный путь, Q-M68→(а), D-190; победа = пережить рейд хода 21, R5).
- Вводит требования к метрикам core loop (TTFD, rate, decision ratio, loop closure, D1/D7) как телеметрию событий.
- Фиксирует fail states: AFK-капы (per-ресурс, см. `raid-pressure-system`), голод (−2 к атакам), инвариант «≥2 доступных глагола».

## Capabilities

### New Capabilities
- `campaign-core-loop`: структура хода, фазы, бит-каркас, статус кампании, метрики, fail states.

### Modified Capabilities
- None.

## Deduplication and status (v4)

- **Дубликаты (archive):** `2026-09-27-core-game-loops-expansion` (pre-pivot «полные долгосрочные циклы»: tech tree, события, квесты) — аннулирован пивором; не дублируется, supersedes-отношение.
- **Пересечение (main specs):** `core-mechanics` (6 атрибутов/модификаторы) — пересечение с `party-characters`, боевая формула «10 + prof» в main spec устарела (K-T6); `save-migration` — покрывает миграции сейвов, здесь только ссылка.
- **Dead tasks (уже реализовано):** порядок 6 фаз (T-010/T-122), 21 ход + бит-каркас (T-010), сезоны (Q-M27/Q-M29), детерминизм I1, статус кампании (T-071) — помечены `[x]` в tasks.md.

## Impact

- Код: `turn_driver.gd`, `turn_scheduler.gd`, `world_seasons.gd` — уже соответствуют; новые требования — телеметрия (пока нет) и AFK-капы (через `raid-pressure-system` T-127).
- Не затрагивает: UI-навигацию (mvp-ui-flow), рейды (raid-pressure-system), партию (party-characters).

## Contradictions

- **C-4 (docs vs code, T-127):** per-ресурсные капы AFK (еда ≤40%, железо ≤30% за рейд — Q-M58→(в), D-189) vs единый `loss_cap_fraction = 0.3` в `threat_system.gd`/`raids.json`. Документация ведёт код; задача в `raid-pressure-system`.
- **C-11 (docs vs docs):** `MVP-scope.md` «район создан — источник Престижа (500)» vs K-M16/02-mechanics §3.5 «район создан — не источник Престижа». Канон = K-M16 (самокоррекция K-M1); `MVP-scope.md` — устаревшая строка, синк в docs.
