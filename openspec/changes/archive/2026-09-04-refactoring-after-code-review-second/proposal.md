# Proposal: refactoring-after-code-review-second

## Why

Вторая волна внешнего аудита (2026-09-04). В отличие от первой волны
(12 findings → 5 реальных, из них 4 уже были закрыты к моменту верификации),
эта волна почти полностью ложная: **13 из 14 findings либо уже реализованы в
коде, либо невалидны по семантике GDScript 4, либо предложены «фиксы» — no-op
или регрессии**. Проверено построчно против текущего кода (evidence ниже).

Одна реальная проблема осталась: `SocketController._find_controller(script)`
без null-guard. Для `script == null` сравнение `node.get_script() == script`
становится `null == null` и матчится на **первый попавшийся узел без скрипта**
(часто корень сцены) — такой узел возвращается и кешируется как
«world/battle controller». Путь достижим при провале `load()` в
`_ensure_scripts_loaded()` (файл скрипта недоступен) и из тестовых вызовов:
вместо ожидаемого `null` команда получает чужой узел, и
`_require_world(root_window)` падает на несуществующем методе.

## What Changes

- `game/scripts/autoload/SocketController.gd`: guard `if script == null:
  return null` в `_find_controller` (1 строка + комментарий).
- `game/tests/test_socket_routing.gd`: regression-тест
  `_find_controller(null) → null`.

## Верификация аудита (почему остальные findings отвергнуты)

| # | Finding аудита | Приоритет | Вердикт | Evidence (текущий код) |
|---|---|---|---|---|
| R1 / B3 / B8 | `_extract_action`: нет `resp == null` после `JSON.parse_string` | High | ❌ ложный | `if req is Dictionary and req.has(...)` — `is` на `null` даёт `false` и short-circuit: `has` не вызывается. Поведение зафиксировано тестом `test_extract_action_reads_field` (включая "garbage" → "UNKNOWN"). |
| R2 / B4 / B6 | `_route_command`: нет проверки `line.length()` / `req == null` до/после парсинга | High | ❌ уже реализовано | `SocketController.gd:165-168`: length-check + `if req == null or not (req is Dictionary): return {"error": "Invalid JSON"}`. Тесты `test_route_line_too_large_returns_error`, `test_route_invalid_json_returns_error` существуют. |
| R3 / B7 | `_process`: нет `STATUS_CONNECTED` до `get_available_bytes()` | High | ❌ уже реализовано | `SocketController.gd:116-118` — ровно «После»-вариант аудита, плюс `available > 0`, buffer-overflow guard (R7b) и idle-timeout (R7a). |
| B1 | `get_available_bytes()` может вернуть 0 — нужна проверка | Low | ❌ уже реализовано | `SocketController.gd:118`: `if available > 0:`. |
| A2 / R5 | `_require_world(world: Node)` — тип не аннотирован; предложили `Variant` + `has_method` | Medium | ❌ ложный + регрессия | `world.is_world_visible()` на `Node`-типе **компилируется и работает в Godot 4.7.2** (проверено минимальным проектом). Предлагаемый `Variant` + `has_method` **уславнивает** типизацию — anti-fix. |
| A3 | `HeroMovementController` без `class_name` | High | ❌ ложный | `HeroMovementController.gd:2`: `class_name HeroMovementController` присутствует; типизированное поле `HeroController.movement` работает. |
| A1 | Порядок `_validate_args` / `_ensure_scripts_loaded` в `_route_command` | Medium | ❌ невалиден | Текст аудита самопротиворечив («Это корректно»). Текущий порядок: validation → script-load → controller-lookup — осознанный (detached-тесты не имеют дерева; см. комментарий в `_route_command`). |
| R6 | `_find_controller` — обход дерева, нет null-guard | Low | ✅ **принят** | Реально: см. Why. Плюс к «трате на обход» — потенциальный wrong-node return (см. выше). |
| R4 | `bfs_path` — «компактизация очереди» `queue.slice(head)` | Low | ❌ вредный no-op | `slice` — O(n) и сработает сотни раз на карте 30k клеток; память BFS держит словарь `from` (O(V)), очередь не освободить без потери путей. `O(V)` для BFS — норма. |
| R7 | `dijkstra` — «оптимизация `dist.fill(INF)`» | Low | ❌ no-op | «До» и «После» в аудите **пословно идентичны**. |
| C1 / C3 | `bfs_path` queue / `dist.fill` — память/скорость | Low | ❌ не баг | `O(V)` — inherent для BFS/Dijkstra; карта ~30k клеток, пиковые десятки МБ. |
| A5 | Инвалидация кэша `node_added`/`node_removed` «может быть избыточной» | Low | ❌ спекуляция | Кэш самовосстанавливающийся (`is_instance_valid + is_inside_tree`); «может быть» без измерения = не баг. |
| A4 | UI-скрипты строят ноды кодом вместо `.tscn` | Medium | ⏸ out of scope | Реальный дизайн-долг, но это отдельный объёмный рефакторинг UI, не связанный с этим fix'ом. Отложить в отдельный чейндж (по желанию пользователя). |
| B2 / B5 / B9 / C2 / C4 | — | — | ✅ аудитор сам отметил «ОК» | — |

## Impact

- **Files:** `SocketController.gd` (+2 строки), `test_socket_routing.gd` (+1 тест).
- **Contract:** внешний контракт не меняется — ответы на malformed input те же
  (spec `socket-command-validation` в main specs покрывает); guard меняет
  только вырожденный путь `script == null` (было: случайный узел без скрипта;
  стало: `null`).
- **Тесты:** полный GUT-набор + `run_all_ci_checks.sh --fast`; scenario 1 —
  end-to-end sanity.
- **Specs:** `skip_specs: true` — чистое hardening без изменения контракта.
