# Design: socket-controller-decomposition

## Контекст

899 строк в одном autoload-узле. Проблема — три разнородные обязанности в одном
файле + безусловный bind порта. Разрезаем по обязанностям, не по «красивой
архитектуре».

## D1. EADDRINUSE: flag-gate (делаем первым)

- Факт: `Platform.is_test_server()` уже ищет `--test-server`; сценарии
  (play_scenario.sh:45) его передают, оконный запуск — нет.
- **Решение:** в `SocketController._ready()`:
  - сервер создаётся и слушает ТОЛЬКО если `Platform.is_test_server()` или
    `Platform.is_socket_server()` (новый алиас `--socket-server`, та же
    семантика, чтобы не привязываться к слову «test»);
  - иначе — ни bind, ни подписки на node_added/removed (peers остаются пустыми);
  - при ошибке `listen` — `GameLogger.warn` (не error) и `server = null`;
    `_process` с `server == null` — пустой возврат. ERROR в консоли не пишем:
    занятый порт в оконном запуске — ожидаемое состояние, не сбой.
- Проверка: два процесса `--test-server` — второй логирует warning, игра
  работает; gate CLEAN.

## D2. Командная таблица

```
var _commands: Dictionary = {}  # action: String -> Callable(req: Dictionary) -> Dictionary
```

- Строится один раз в `_ready` (до проверки флага — 20 записей, цена нулевая;
  код один).
- Контроллер мира резолвится НА КАЖДЫЙ запрос (сцена появляется/исчезает), а
  не на момент постройки таблицы — текущее поведение хендлеров сохраняется.
  Форма записи: лямбда захватывает действие, вызов вида
  `_commands["MOVE_TO"] = func(req): return _handle_move(req)`, где
  `_handle_move` внутри делает `_get_world_ctrl()` + guard.
- Префикс-проверки — helper:
  ```
  func _require_world(world: Node) -> Dictionary:
      if world == null: return {"ok": false, "error": "Not in World mode"}
      # + terminal-проверка там, где она нужна сейчас
      return {}
  ```
  Каждый мировой хендлер начинает с `var err := _require_world(...); if not err.is_empty(): return err`.
- Match-блок (~150 строк) заменяется:
  ```
  var h: Callable = _commands.get(action, Callable())
  if h.is_valid(): return h.call(req)
  return {"ok": false, "error": "Unknown command: " + action}
  ```
- Протокол: формы запросов/ответов и строки ошибок НЕ меняются (сценарии =
  регрессия). Порядок добавления: таблица → перенос хендлеров → удаление match.

## D3. BattleEmulator (RefCounted)

- Перенос в `scripts/battle/BattleEmulator.gd` (class_name BattleEmulator,
  extends RefCounted): `_army_stack`, `_side_name`, `_summarize`,
  `_nearest_enemy`, `_move_toward`, `_run_auto_battle`, `_emulate_battle`,
  `_total_count`, `_cast_in_battle`, `_sequence_battle`, `_battle_spell`,
  `_spell_registry`, `_get_spells`, `_cast_spell` (~500 строк, смещение строк
  — не суть, перенос по границе «BattleState + armies»).
- Зависимости: BattleState (RefCounted, ок), ServiceLocator для SpellRegistry/
  Spellbook (статическое ядро — не autoload-импорт, headless-безопасно).
- Сокет хранит `var _emulator := BattleEmulator.new()` и делегирует 7
  командных хендлеров.
- Win: `tests/test_battle_emulator.gd` — emulate_battle/sequence_battle/cast
  проверяются БЕЗ TCP: конструктор, armies, assert по результату.

## D4. Что остаётся в autoload (и почему)

Транспорт (TCPServer/peers — по определению только в узле), командная
таблица, мировые обработчики (GET_STATE/MOVE_TO/END_TURN/CITY_*/SAVE/LOAD/
RETREAT — нужны живые контроллеры сцены; их перенос = другой срез, не сейчас),
кэш контроллеров (`_battle_state`/`_battle_controller` — связаны с
`tree_change`-циклом), метрики (GET_METRICS + `_tick`-таймеры).

Цель: SocketController ≤ ~400 строк, BattleEmulator ~450.

## Риски

- Лямбды в таблице захватывают `self` (autoload живёт вечно) — безопасно.
- Терминальные guard'ы в разных хендлерах сейчас расписаны по-разному; helper
  должен сохранить ТЕКУЩИЕ строки ошибок поблочно (не «унифицировать» —
  протокол).
- Кэш контроллеров: при переносе эмуляторов убедиться, что `_battle_state`
  резолвится до делегирования (эмулятор получает BattleState как аргумент,
  не сам ищет).
