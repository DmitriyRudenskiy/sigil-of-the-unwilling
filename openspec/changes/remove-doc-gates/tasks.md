## 1. Коммит 1 — удаление носителей

- [x] 1.1 Удалить `scripts/doc_gates.sh`
- [x] 1.2 Удалить 13 проверщиков: `check_docs_links.py`, `gen_docs_index.py`, `audit_docs_vs_code.py`, `check_hero_layout_map.py`, `check_save_matrix.py`, `gdd_gate.py`, `gdd_grounding.py`, `check_asset_provenance.py`, `check_hero_frames.py`, `audit_hero_frames.py`, `check_openspec_specs.py`, `testmap.py`, `gen_tier_table.py`
- [x] 1.3 Удалить `scripts/testmap.baseline.json` и комплект измерителей сцен: `measure_scene_lattice.py`, `measure_scene_clusters.py`, `annotate_scenes.py`, `fit_scene_cells.py`
- [x] 1.4 Удалить 11 самопроверок удалённых объектов: `test_check_docs_links.py`, `test_audit_docs_vs_code.py`, `test_gdd_gate.py`, `test_gdd_grounding.py`, `test_testmap.py`, `test_check_hero_layout_map.py`, `test_check_openspec_specs.py`, `test_check_save_matrix.py`, `test_check_asset_provenance.py`, `test_check_hero_frames.py`, `test_audit_hero_frames.py`
- [x] 1.5 Сверить замыкание: ни один из удалённых модулей не импортируется и не вызывается из оставшегося кода (`git grep -nE 'doc_gates|check_docs_links|gen_docs_index|audit_docs_vs_code|check_hero_layout_map|check_save_matrix|gdd_gate|gdd_grounding|check_asset_provenance|check_hero_frames|audit_hero_frames|check_openspec_specs|testmap|gen_tier_table|measure_scene|annotate_scenes|fit_scene_cells' -- '*.py' '*.sh' '*.yml' '*.gd'` — **пустой вывод**. Уточнение по ходу (2026-11-10): исполняемых ссылок (импорт, вызов, шаг CI) быть не должно вовсе; историческую строку «носитель снят сменой remove-doc-gates» задача 2.5 требует наоборот, поэтому она вынесена из-под критерия явно: приёмка читает вывод и смотрит, чтобы ни одно имя не стояло в позиции вызова)
- [x] 1.6 Убедиться, что выжившие исполнители целы: `game/run_tests.sh` вызывает `check_autoloads.py`, `check_node_paths.py`, `check_test_tiers.py`; `scripts/ci2_checkers.sh` вызывает `check_repo_layout.py`; `classify_mcp_junit.py` вызывается раннером
- [x] 1.7 Тестовый леджер в сводку: `−11 файлов / +0 / нетто −11`, причина — «объект теста удалён»

## 2. Коммит 2 — переподвязка исполнителей

- [x] 2.1 `game/run_tests.sh`: снять ссылки на удалённых проверщиков из комментариев и строк вердикта; переименовать литералы `NODE-PATHS` и `GATE=` по таблице Д2, не меняя логику маппинга exit-кодов (GdUnit4 `0`/`101` → зелёный)
- [x] 2.2 `.github/workflows/ci2.yml`: убрать шаг `STATIC (check_docs_links.py)` и его строку в `/tmp/ci2-levels.txt`; вердиктную строку `CI2-VERDICT:` пересчитать на 3 уровня; артефакт `ci2-run-logs` переименовать (решение Open Question зафиксировать в сообщении коммита)
- [x] 2.3 `scripts/ci2_checkers.sh`: убрать упоминание `check_docs_links.py` из шапки, проверить, что перечни уровней и артефактов совпадают с `ci2.yml`
- [x] 2.4 `.gitignore`: снять комментарий про `gen_docs_index.py`/`check_docs_links.py`
- [x] 2.5 `docs/mvp/TEST-MAP.md` и `docs/mvp/SCENE-SLICE-MEASURE.md`: заменить разделы, ссылающиеся на `testmap.py --check`, `gen_tier_table.py --check` и измерители сцен, на явное «носитель снят сменой remove-doc-gates» — молчание вместо строки запрещено
- [x] 2.6 Прогон `MCP_SSH_HOST= game/run_tests.sh --tier=smoke` зелёный; затем `--tier=fast`

## 3. Коммит 3 — словарь в коде и живых документах

- [x] 3.1 Составить таблицу фиксированных сочетаний (Д2): `семантика гейта`, `блок вердикта`, `артефакт гейта`, `документальная проверка`, `MCP-секция`, `NODE-PATHS`, `DOCUMENTATION CHECKS`, `ci2-run-logs`, `documentation checks`, `the gate` — и прогнать её первым проходом по `game/`, `scripts/`, `.github/`, `docs/` (кроме реестров), `AGENTS.md`
- [x] 3.2 Второй проход: остаточный стем `гейт` → `прогон`/`проверка`; латиница — только `\b[Gg]ates?\b` и `\bGATES?\b` (граница слова обязательна: `negate`, `propagate`, `mitigated`, `obligated`, `surrogate`, `gateway` не трогаются)
- [x] 3.3 Вычитать `git diff` по `game/**/*.gd` и `game/**/*.sh`: убедиться, что ни одна константа движка, имя узла, input action и save-ключ не изменены; `gdlint` и `gdformat --check` по изменённым `.gd`
- [x] 3.4 `AGENTS.md`: убрать строку «Проверка связности перед пушем: python3 scripts/check_docs_links.py», обновить таблицу «Верификация» и секции, где «гейт» значился как имя слоя; переименовать `NODE-PATHS` (T-296) по таблице
- [~] 3.5 Имена capability (Д6): `openspec/specs/ui-verification-gates` → `ui-verification-checks`, `openspec/specs/world-map-art-gates` → `world-map-art-checks`, обновить ссылки в живых сменах; `attribute-gated-actions` не трогать
- [x] 3.6 Проверить игровой словарь нетронутым: `git grep -n "gate_ok\|population_gate\|_check_class_gate\|\"gate\""` даёт тот же набор, что до смены
- [x] 3.7 `MCP_SSH_HOST= game/run_tests.sh --tier=fast` зелёный (заменён одним полным прогоном 5.4 — слой fast входит в full)

## 4. Коммит 4 — словарь в истории и спеках

- [~] 4.1 Прогнать таблицы 3.1–3.2 по `docs/mvp/TICKETS.md`, `docs/DECISIONS.md`, `docs/CHANGELOG.md`, `docs/mvp/matrix/**`
- [x] 4.2 Прогнать таблицы по `openspec/changes/**` (включая `archive/**`) и `openspec/specs/**`
- [x] 4.3 Запись в `docs/DECISIONS.md` (номер выдаёт реестр): форма документальных проверок и её носители удалены, слово «гейт» выведено из верификационного словаря, что именно перестало проверяться машиной
- [x] 4.4 Запись в `docs/CHANGELOG.md`: переименован словарь протоколов `docs/mvp/matrix/**` (R1) — читатель расходящейся цитаты знает причину
- [x] 4.5 Зеркало тикетов: закрытые тикеты, чей носитель удалён (уровни `doc_gates.sh`, `testmap`-рэтчет, `check_asset_provenance`, `check_hero_frames`), получают строку «носитель удалён сменой remove-doc-gates» без изменения их вердиктов
- [x] 4.6 Свести дельты в носимые спеки (`openspec/specs/`): `verification-naming` создаётся, 7 остальных изменены; заголовок `## ADDED Requirements` в носителе запрещён. После сведения проверить, что пара `RENAMED` + `MODIFIED` (dev-verification-loop, ci-pipeline, gdd-phase-workflow) действительно применилась под новым именем, а старое имя не осталось в носителе

## 5. Приёмка

- [x] 5.1 `git grep -inE 'гейт|[[:<:]]gates?[[:>:]]'` — остаток только из разрешённого: игровой словарь (`gate_ok`, `population_gate_city`, `_check_class_gate`, ключ каталога `"gate"`) и `attribute-gated-actions`; вывод прикладывается к сводке
- [x] 5.2 `git grep -n "doc_gates"` — пусто; `git ls-files scripts/` не содержит удалённых файлов
- [x] 5.3 `openspec validate --all --no-interactive` и `--all --strict` — падений, вызванных сменой, нет
- [ ] 5.4 Один полный `MCP_SSH_HOST= game/run_tests.sh` зелёный (GdUnit exit 0/101, MCP-секция с явным вердиктом) — основание для push
- [ ] 5.5 Сводка в треде: дифф по четырём коммитам, леджер тестов, вывод 5.1–5.3, CI не проверялся (по инструкции)
- [ ] 5.6 `git push origin main` по собранному вердикту (D-224, публикация по готовности от 2026-10-30)


## Ход исполнения (2026-11-10)

**Почему `[~]`, а не `[x]`.**

- **3.5 — снято с исполнения до слова владельца.** Capability `ui-verification-gates`
  и `world-map-art-gates` помянуты в дельтах активных смен
  (`world-hex-cell-art/specs/world-map-art-gates/`, `world-map-scene-slicing`), и
  имя каталога дельты обязано совпасть с именем носителя при сведении: переименование
  без пересводки всех дельт ломает `openspec archive` чужой смены ради слова в
  заголовке. Итог: литералы, печатаемые прогоном, переименованы (это машинные
  потребители), имена capability — нет; записано в D-322 как явное «не трогать».
- **4.1 — конфликт мандатов, решает владелец.** Д5 этой смены требует прогнать
  словарь по `docs/mvp/TICKETS.md` (464 упоминания), `docs/DECISIONS.md` (156),
  `docs/mvp/matrix/**` (608) и `openspec/changes/archive/**` (656), а AGENTS.md
  объявляет реестры append-only, а архивные логи — «не редактируются». Правка
  необратима по смыслу (в реестрах читают, что было решено тогда), поэтому
  реестры, архивы и протоколы матрицы оставлены как были, а расхождение словаря
  объяснено записью 2026-11-10 в `docs/CHANGELOG.md` и строкой реестра в конце
  `docs/mvp/TICKETS.md`. Нужно слово: переписывать историю по Д5 или снять Д5.

**Что свип сделал не так и было исправлено вторым проходом (3.3).** Стем
заменялся механически, и в трёх местах это меняло смысл, а не слово: там, где
«гейт» значил игровой порог (`02-mechanics`, `02d-classes-skills`, `03-progression`
→ «порог», «фильтрация»), там, где значил конкретного сверщика (`13-art-bible`,
`ui-graphics`, `world-map-art-gates` → «проверка»), и в самом требовании
`verification-naming`, которое перечисляет удаляемое слово — после свипа оно
запрещало собственный результат. Плюс `RENAMED` с `FROM == TO` в дельте
`dev-verification-loop` (носитель был переименован тем же свипом) — секция снята,
`--strict` зелёный. Замороженные свипом файлы (реестры, архивные логи,
`docs/reference/map-baseline`, `VERDICT-REQUEST`, `docs/archive/battle-demo`)
возвращены к содержимому `ab770323`.

**Молчание исполнителей (2.1–2.3).** После удаления уровня четыре живых сверщика
(`check_autoloads.py`, `check_node_paths.py`, `check_test_tiers.py`,
`check_repo_layout.py`) и разбор матрицы сцен остались без вызова — их pytest-
самопроверки были в списке `TESTS` снятого уровня. Вызов переехал в
`game/run_tests.sh` (блок `CHECKERS`, 65 тестов, 0.08 с), `test_gen_map_art.py`
переехал в `game/tests/mcp/`.

**Леджер тестов:** −11 файлов самопроверок (объект удалён), +0 новых, нетто −11;
было 3621 в слое fast → 3621 (сверщики переехали исполнителем, не счётчиком).
