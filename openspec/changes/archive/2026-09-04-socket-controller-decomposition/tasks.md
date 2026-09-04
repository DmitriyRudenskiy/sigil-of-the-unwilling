## 1. EADDRINUSE (первым, отдельный зелёный шаг)
- [x] `Platform.gd`: `is_socket_server()` (алиас `--socket-server`).
- [x] `SocketController._ready()`: bind при `is_test_server() or is_socket_server()`; listen-ошибка -> `GameLogger.warn` + `server = null`; `_process` с null — пустой возврат.
- [x] Double-instance: второй `--test-server` -> warning, игра жива (см. §5).

## 2. Командная таблица
- [x] `_COMMANDS: Dictionary<StringName, Callable>` в `_init` (все действия, строки ошибок поблочно).
- [x] Helper `_require_world(world) -> Dictionary`; мировые хендлеры через него (+ юнит-тест в test_socket_routing.gd).
- [x] Match-блок удалён; unknown command — тот же ответ.
- [x] Регрессия: сокет-сценарии 1, 5, 9, 11, 12 зелёные (см. §5).

## 3. BattleEmulator
- [x] BattleEmulator (RefCounted) вынесен: `_run_auto_battle`, `_emulate_battle`, `_battle_spell`, `_nearest_enemy`, `_move_toward`, `_army_stack`, `_summarize`; BattleState — аргумент, ServiceLocator для SpellRegistry. _Отклонение: файл в `scripts/autoload/BattleEmulator.gd` (без `class_name`) вместо `scripts/battle/` по D3 — detached-тесты не тянут автозагрузки; spec-требование (RefCounted без TCPServer, headless-constructible) выполнено._
- [x] SocketController: `var _emulator` + 7 делегирований; перенесённые функции удалены.
- [x] `tests/test_battle_emulator.gd`: emulate_battle (победитель/ходы), sequence_battle (ротация heal), cast (воскрешение мёртвой цели) — без сокета.

## 4. Umbrella
- [x] `openspec/changes/world-controller-decoupling/tasks.md`: 3.1–3.3 (декомпозиция) и 6.2 закрыты «закрыто: socket-controller-decomposition».

## 5. Gate
- [x] Полный сьют: 1141/0 зелёный. operability gate CLEAN (в т.ч. double-instance проверки). Шаги зафиксированы в `audit/critical-fixes`.
