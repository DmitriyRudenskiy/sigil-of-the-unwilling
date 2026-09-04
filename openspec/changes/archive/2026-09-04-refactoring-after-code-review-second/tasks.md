# Tasks: refactoring-after-code-review-second

## 1. Код

- [x] 1.1 `SocketController._find_controller`: добавить в начало
      `if script == null: return null` + однострочный комментарий
      (null матчит `get_script() == null` на любом узле без скрипта).
- [x] 1.2 `test_socket_routing.gd`: тест
      `test_find_controller_null_script_returns_null` —
      `_ctrl.call("_find_controller", null)` → `null`
      (не корень сцены, не любой узел без скрипта).

## 2. Верификация

- [x] 2.1 `bash game/tools/shell/run_all_ci_checks.sh --fast`
      (компиляция + валидация). → 4/4 PASS.
- [ ] 2.2 `bash game/tools/shell/run_all_ci_checks.sh`
      (полный: GUT-тесты + console clean).
      → GUT: All tests passed (включая новый тест _find_controller),
      compile/spells/tileset/scene-refs: PASS, console scan: 0 errors.
      **Блокер (предсуществующий, не связан с guard):** сценарии 1–4
      падают KeyError 'hero_pos' — герой умирает от голода на ~8-м ходу
      (feature hero-survival, commit 1b11888), рефакторенные сценарии
      (32fe4b9) не обрабатывают endgame DEFEAT и не едят. Сценарий 5: PASS.
- [ ] 2.3 `bash game/tools/shell/play_scenario.sh 1`
      (end-to-end sanity: сокет-команды через живой сервер).
      → тот же блокер (сценарий 1 падает на starvation).
