---
description: "Декомпозиция SocketController (899 строк): EADDRINUSE — сервер слушает только с флагом, командная таблица вместо 150-строчного match, эмуляторы боя/заклинаний в RefCounted (юнит-тесты без сокета)."
---

## Why

- `SocketController.gd` — 899 строк, autoload. Внутри четыре разнородных слоя:
  транспорт (~90 строк), match-роутинг ~20 команд (~150 строк, с повторением
  префикс-проверок «Not in World mode»/terminal), эмуляция боя и заклинаний
  (~500 строк: EMULATE_BATTLE / CAST_IN_BATTLE / SEQUENCE_BATTLE / BATTLE_SPELL /
  GET_SPELLS / CAST_SPELL / SPELL_REGISTRY), мировые обработчики (~200:
  GET_STATE / MOVE_TO / END_TURN / CITY_* / SAVE/LOAD / RETREAT) + кэш
  контроллеров и метрики.
- Новая команда = правка match + копирование префикс-проверок.
- Эмуляторы боя существуют только внутри сокета: headless-юнит-тест
  BattleState-эмуляции невозможен без TCP round-trip (эмуляторы не
  RefCounted-конструируемы).
- **EADDRINUSE (root cause найден):** `SocketController._ready()`
  (строки 24–30) безусловен `server.listen(9095)`. Флаг `--test-server` уже
  распознаётся (`Platform.is_test_server()`, scripts/core/Platform.gd), но
  SocketController его не спрашивает. Второй инстанс (оконная игра + тест-сервер,
  два headless-процесса) → `EADDRINUSE (address in use)` в консоли → gate DIRTY.
  Сервер реально нужен только в сценариях: play_scenario.sh:45 запускает
  `--headless --test-server`.

## Proposed Change

1. **EADDRINUSE (первое, ~10 строк):** слушать порт только если запущено с
   `--test-server` или `--socket-server` (новый алиас, та же семантика); при
   неудаче listen — одна строка `GameLogger.warn` (не error) и работа без
   сервера (пустые peers, команды не приходят — это ожидаемо для оконного
   запуска).
2. **Командная таблица:** `_COMMANDS: Dictionary[String, Callable]`
   (action → `handler(req) -> Dictionary`); match-блок исчезает. Префикс-проверки
   — helper `require_world(world_ctrl) -> Dictionary` (пустой dict = ок, иначе
   готовый error-ответ), вызывается в каждом мировом хендлере. JSON-протокол
   (формы запросов/ответов, строки ошибок) не меняется — сокет-сценарии =
   регрессия.
3. **Эмуляторы в RefCounted:** `scripts/battle/BattleEmulator.gd` — перенос
  эмуляционного блока (~500 строк: `_army_stack`, `_summarize`, `_nearest_enemy`,
  `_move_toward`, `_run_auto_battle`, `_emulate_battle`, `_total_count`,
  `_cast_in_battle`, `_sequence_battle`, `_battle_spell`, `_spell_registry`,
  `_get_spells`, `_cast_spell`). Без TCPServer; SpellRegistry/Spellbook — через
  ServiceLocator (ядро, не autoload-импорт). Сокет делегирует.
4. **Остаток в autoload:** транспорт, таблица, мировые обработчики (нуждают
  живых контроллеров), кэш контроллеров, метрики. Цель: SocketController ≤ ~400
  строк.

## Scope

- **In:** `SocketController.gd` (flag-gate, таблица, делегирование),
  `scripts/battle/BattleEmulator.gd` (новый), `tests/test_battle_emulator.gd`
  (новый), `Platform.gd` (алиас `--socket-server`), пометки в umbrella (R2/R6).
- **Out:** изменение JSON-протокола, перенос мировых обработчиков (они связаны с
  живыми контроллерами — отдельный вопрос, не сейчас), новые TCP-механики.

## Dependencies

- Независим от hero-lifecycle-boundary и lifecycle-test-strategy.
- Порядок внутри: EADDRINUSE → командная таблица → BattleEmulator (каждый шаг
  отдельно зелёный: сценарии + сьют + gate).
- `world-controller-decoupling` R2 (декомпозиция) и R6 (порт) — закрываются этим
  change.
