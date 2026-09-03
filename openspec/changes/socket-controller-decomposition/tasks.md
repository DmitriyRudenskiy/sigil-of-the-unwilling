## 1. EADDRINUSE (первым, отдельный зелёный шаг)
- [ ] `Platform.gd`: добавить `is_socket_server()` (алиас `--socket-server`).
- [ ] `SocketController._ready()`: bind только при `is_test_server() or is_socket_server()`; при ошибке listen — `GameLogger.warn` и `server = null`; `_process` с null — пустой возврат.
- [ ] Проверка: два `--test-server` одновременно — второй warning, игра жива; gate CLEAN.

## 2. Командная таблица
- [ ] `_commands: Dictionary` в `_ready` (все ~20 действий, текущие строки ошибок поблочно).
- [ ] Helper `_require_world(world) -> Dictionary`; мировые хендлеры через него.
- [ ] Удалить match-блок; unknown command — тот же ответ.
- [ ] Регрессия: сокет-сценарии 1, 5, 9, 11, 12 зелёные.

## 3. BattleEmulator
- [ ] `scripts/battle/BattleEmulator.gd`: перенос эмуляционного блока (~500 строк); BattleState — аргумент, ServiceLocator для SpellRegistry/Spellbook.
- [ ] SocketController: `var _emulator` + делегирование 7 хендлеров; удаление перенесённых функций.
- [ ] `tests/test_battle_emulator.gd`: emulate_battle (победитель/ходы), sequence_battle (ротация heal), cast (воскрешение мёртвой цели) — без сокета.

## 4. Umbrella
- [ ] `openspec/changes/world-controller-decoupling/tasks.md`: пометить 2.x (декомпозиция) и 6.2–6.3 (порт) «закрыто: socket-controller-decomposition».

## 5. Gate
- [ ] Полный тест-сьют зелёный, operability gate CLEAN (в т.ч. double-instance проверка), точный коммит по шагам 1/2/3.
