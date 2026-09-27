# Design: world-controller-decoupling

## Audit Summary (5 dimensions, before → after)

| # | Finding | Before | After / Plan | Ref |
|---|---------|--------|--------------|-----|
| 1 | Тяжёлая логика в координаторе (death/succession/resurrection/chronicle) | WorldController 602 строк | `hero_lifecycle_system.gd` (RefCounted), WC = **141 строка** | R1 ✅ d7131b1 |
| 2 | Глобальное состояние + монолит транспорта/команд | MCP server 205 строк, EADDRINUSE при повторном listen | Транспорт ↔ `mcp_commands_*` ↔ состояние; идемпотентный start/stop | R2 ⬜ |
| 3 | Двойной путь доступа к hero | `_install_hero` на WC + прямые ссылки потребителей | **REJECTED**: coordinator-owned `_hero` + тонкие делегации — архитектурно чище IHeroConsumer (Design D) | R3 🚫 |
| 4 | Untyped Variant-поля | 7 полей в WC-контуре | Типизация + `@export` где уместно | R4 ⬜ |
| 5 | DI drift | `ServiceContainer.current` глобальный alongside DI | Единый контейнер; `.current` обёрнут/удалён | R5 ⬜ |
| 6 | Клейкая координация в WC | Точки роутинга событий разбросаны | Централизация в `world_event_router.gd` | R6 ⬜ |
| 7 | Верификация | — | run_all.sh зелёный + operability CLEAN на каждую фазу | R7 ⬜ |

## Decisions

- **D1 (R1):** HeroLifecycleSystem подписывается на `hero_died` сам — WC не знает о механике смерти. Тесты прокидывают `_hero_lifecycle`; 4 поля death-flow переименованы.
- **D2 (R3 rejected):** введение `IHeroConsumer` добавило бы 10+ адаптеров ради одного метода; оставляем `_install_hero` на координаторе.
- **D3 (R2 scope):** MCP-сервер — dev-tool, не игровой рантайм; декомпозиция допустима с нарушением «headless-only» правила для `scripts/`, т.к. код живёт в `tools/`.
- **Open questions:** ни один пункт не блокирует R2; решение по `.current` (обёртка vs удаление) принимается по числу call-sites на старте R5.

## Verification Protocol (per phase)

1. Godot headless compile (0 errors).
2. `game/tests/run_all.sh` — полный зелёный прогон.
3. Operability check (MCP-сценарий) — CLEAN, 0 warnings.
4. Отдельный коммит на фазу, ссылка коммита в tasks.md.
