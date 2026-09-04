# Design: project audit — worthwhile findings

## Контекст

Аудит (11 пунктов, R1–R11) охватывал UI, алгоритмы, best-practices и
рефакторинг. Проверка каждого пункта против реального кода показала, что
большинство пунктов — теоретические, уже обработанные или большой рефакторинг.
Ниже — верификация каждого пункта и решение по нему.

### R1 — ArtifactChestDialog: кнопка Close мертва (ВКЛЮЧИТЬ)

Сцена `ArtifactChestDialog.tscn` имеет кнопку `cancel` (label "Close") на
`Margin/VBox/cancel` (line 57). Скрипт соединяет только `take` и `gold`.
`_on_close()` существует, но вызывается только из `_on_gold_taken`/`_on_take`
неверно — сам `cancel` никуда не подключён. Клик "Close" = noop. Реальный баг,
фикс — одна строка: `cancel.pressed.connect(_on_close)`.

### R2 — BattleUI: collapse-кнопка прячет себя (ВКЛЮЧИТЬ)

`collapse_btn` в `BattleUI.tscn` — `parent="bottom_bar"` (line 76).
`_on_collapse()` делает `_bottom_bar.visible = not _bottom_bar.visible`.
Поскольку кнопка внутри `bottom_bar`, после сворачивания она исчезает и
развернуть панель обратно нельзя. Реальный баг. Фикс — вынести `collapse_btn`
в корень CanvasLayer и поправить путь в `_connect_btn("collapse_btn", ...)`.
Требует правки `.tscn` + `.gd`.

### R3 — EquipmentManager.roll_attack не учитывает AC (НЕ НУЖНО)

`roll_attack(d20, crit_threat)` — заглушка с комментарием
`d20 vs AC handled by caller`. У неё **ноль вызовов** в коде
(`grep roll_attack` вне определения → пусто). Возвращаемый словарь
`{"roll","is_crit","threat_range_end"}` — без `is_hit`, поэтому формулировка
аудита «попадание только при 20» неточна: AC применяется вызывающим, а не
внутри функции. Меняя сигнатуру (`roll_attack(d20, attack_bonus, target_ac,
crit_threat)`), мы ничего не исправим (вызовов нет) и рискуем там, где риска
нет. Отклоняем.

### R4 — SocketController: O(n) DFS вместо групп (Отложить)

`_find_controller` делает рекурсивный DFS по дереву на каждом промахе кэша;
`_on_tree_changed` сбрасывает кэш на каждый `node_added`/`node_removed`.
Это уже решено декомпозицией `socket-controller-decomposition`: DFS
намеренно script-based, чтобы не тащить compile-time зависимости автозагрузок
(коммент в коде). Предложение аудита «использовать группы» противоречит этой
цели. Улучшение перфа маржинально (промах только на промахе кэша). Откладываем
в отдельный perf-change, не рискуем декомпозицией.

### R5 — ArenaClusterSystem: кэш не инвалидируется после десериализации (ВКЛЮЧИТЬ)

`static var _cache` keyed on `city.uid`; `invalidate()` вызывается только из
`ArenaTurnRunner.place_building` (line 140). `City.deserialize` (line 700)
очищает и заново наполняет `buildings` (lines 52–58), но `invalidate` не
вызывает. Загруженный город показывает старые кластеры. Реальный баг
save/load. Фикс — одна строка `ArenaClusterSystem.invalidate(uid)` в
`City.deserialize`.

### R6 — дубликат mcp-сценариев ×3 (Отложить)

`game/tools/scenarios` против `mcp_tests/scenarios` — один и тот же код в
двух местах. Настоящий выигрыш — закидать `build/` в `.gitignore`
(`mcp_tests/build/`, `game/build/`), чтобы сборка Neovim не мусорила в git.
Полный рефакторинг (один источник + shared lib) — большой, потенциально
конфликтующий, должен быть отдельным change. Откладываем; остаётся только
опциональный `.gitignore`.

### R7 — MinHeap.pop: guard на пустой кэш (Отклонить)

`pop()` намеренно `return []` на пустом кэше — в коде есть комментарий
«ponytail: empty-heap guard … defensive … return [] rather than null».
Тест `test_hex_utils.gd:114` активно утверждает `heap.pop().is_empty() == true`.
`assert(false)` из аудита сломал бы этот тест в debug-режиме. Несоответствие
контракта — миф. Отклоняем.

### R8 — MapRenderer.diversify() мёртвый код (ВКЛЮЧИТЬ — cleanup)

`func diversify(_tile_map) -> void: pass` с комментарием
«биома один базовый вариант — диверсификация не нужна». Мёртвый код, удаляется
безопасно. Убираем метод + один вызов в `MapGenerator` (line 92).

### R9 — validate_spells: fragile class_name regex (ВКЛЮЧИТЬ — cleanup)

`_load_src` режет `class_name` через `line.strip_edges().begins_with("class_name ")`.
Если токен встречается внутри строки-источника, стрип неверен. Фикс —
regex-aware (отрезать только строку `class_name X` в начале). Безопасно,
edge-case.

### R10 — BattleState: ленивая инвалидация по версии (Отклонить)

`_board_version` инкрементируется в `invalidate_board_cache()`, но сам по себе
для ленивой проверки не используется — кэш маленький, поведение корректно.
Предложение аудита «проверять версию вместо clear» — теоретическая оптимизация
перфа с реальным риском корректности. Отклоняем.

### R11 — WorldController: partial-failure guard (Отклонить)

Аудит утверждает «no checks for null result». Реальный `_ready()` уже имеет
проверки: `_map_gen.renderer != null`, `_bootstrap_result.services != null`,
и `_hero_lifecycle == null` в `_finit_subsystems`/лайфцикле. Формальный
пробел (await process_frame между шагами) не создаёт краша. Отклоняем как
теоретическое.

## Решения

- **R1** — соединить `cancel.pressed → _on_close()` в `_connect_buttons()`.
- **R2** — переместить `collapse_btn` из `bottom_bar` в корень
  CanvasLayer в `.tscn`; поправить `_connect_btn` на `get_node_or_null("collapse_btn")`.
- **R5** — добавить `ArenaClusterSystem.invalidate(_uid)` в `City.deserialize`
  после наполнения `buildings`.
- **R8** — удалить `diversify()` и вызов в `MapGenerator`.
- **R9** — regex-aware стрип `class_name` в `_load_src`.

Реализация R9 не меняет наблюдаемое поведение при нормальных входных данных,
поэтому для неё нет delta-спекта (только задача). R8 — чистое удаление мёртвого
кода, тоже без спекта.
