## Why

`scripts/doc_gates.sh` — отчётная форма, которую никто не исполняет: её не зовёт ни
`game/run_tests.sh`, ни CI-2 (`ci2.yml` поднимает только `run_tests.sh`,
`ci2_checkers.sh` и `check_docs_links.py`). Она существует с задачи 2.5 смены
`gdd-phase-workflow` как «то, что краснеет, когда документация расходится», но
единственный её потребитель — агент, который вспомнит запустить. Слово «гейт» при
этом стало общим именем для четырёх разных вещей (полный прогон `run_tests.sh`,
слои `--tier=`, CI-2, документальные проверки), и каждая ссылка «прошёл гейт»
требует сначала выяснить, о каком из четырёх речь.

Убираем и форму, и слово: проверки либо имеют исполнителя, которого реально кто-то
зовёт, либо не существуют; слой верификации называется своим носителем.

## What Changes

- **BREAKING** Удалён `scripts/doc_gates.sh` — исполнитель документальных проверок.
- **BREAKING** Удалены 13 проверщиков, чьим единственным исполнителем был он:
  `check_docs_links.py`, `gen_docs_index.py`, `audit_docs_vs_code.py`,
  `check_hero_layout_map.py`, `check_save_matrix.py`, `gdd_gate.py`,
  `gdd_grounding.py` (импортирует `gdd_gate`), `check_asset_provenance.py`,
  `check_hero_frames.py`, `audit_hero_frames.py`, `check_openspec_specs.py`,
  `testmap.py` (+ `testmap.baseline.json`), `gen_tier_table.py`, и комплект
  измерителей сцен `measure_scene_lattice.py` / `measure_scene_clusters.py` /
  `annotate_scenes.py` / `fit_scene_cells.py` — всего 18 файлов.
- **BREAKING** Удалены 11 pytest-самопроверок удалённых проверщиков (тест
  инструмента, которого больше нет, не оставляет после себя покрытия).
- Выживают, потому что имеют другого исполнителя: `check_autoloads.py`,
  `check_node_paths.py`, `check_test_tiers.py` (их зовёт `game/run_tests.sh`),
  `check_repo_layout.py` (его зовёт `scripts/ci2_checkers.sh`),
  `classify_mcp_junit.py`, `check_reference_index.py`, `check_ui_assets.py`,
  `check_map_art.py`, `check_fog_model.py` — и их тесты.
- **BREAKING** CI-2: уровень `DOCS-LINKS` статического job'а снимается вместе с
  инструментом; вердиктная строка `CI2-VERDICT:` теряет слагаемое.
- **BREAKING** Слово «гейт»/`gate` выводится из верификационного словаря: 1 535
  вхождений слова `gate` + 455 `gates` + 4 963 вхождений «гейт» по живым документам,
  истории (`TICKETS.md`, `DECISIONS.md`, `CHANGELOG.md`, `docs/mvp/matrix/**`),
  архиву OpenSpec, `AGENTS.md`, `game/run_tests.sh`, `game/tools/**`, тестам и CI.
  Каждому слою возвращается имя носителя: «полный прогон `run_tests.sh`»,
  «слой `smoke`/`fast`», «прогон CI-2», «вердикт readiness».
- Не меняется игровой словарь: `canon_classes.gate_ok()`, ключ каталога `"gate"`
  (`game/assets/data/mvp_catalog.json`), `population_gate_city`, `_check_class_gate`
  — это механика найма классов, а не слой проверки (см. Non-goals).

## Capabilities

### New Capabilities
- `verification-naming`: чем именован каждый слой проверки и чего в репозитории
  быть не может — общего имени «гейт» без носителя и слова `gate` вне игрового
  словаря механик.

### Modified Capabilities
- `docs-code-sync`: машинная сверка «доки ↔ код» снимается с носителя —
  `audit_docs_vs_code.py` удаляется, требование про divergence-check как гейт
  аннулируется.
- `gdd-phase-workflow`: состояние секций больше не проверяется документальным
  гейтом — носитель `gdd_gate.py` удалён, требование переформулировано к
  frontmatter как к носителю без машинного вердикта.
- `gdd-economy-audit`: «`scripts/gdd_gate.py` SHALL be green» — носитель удалён.
- `test-suite-tiers`: замер межфайловых дублей `scripts/testmap.py` и таблица
  слоёв `gen_tier_table.py --check` остаются требованием к содержанию, но теряют
  машину; сводится к инварианту, который держит ревью диффа.
- `repo-layout`: сценарии «состава корня» и «провенанса ассетов» ссылаются на
  удалённые `check_docs_links.py` и `check_asset_provenance.py`.
- `dev-verification-loop`: `check_docs_links.py` выпадает из списка быстрых
  проверок шага.
- `ci-pipeline`: уровень `DOCS-LINKS` уходит из раскладки CI-2, «гейт-семантика»
  переименовывается по носителю.

## Impact

- **Код:** 18 скриптов + 11 тестов удалены (~4 700 строк Python проверщиков и их
  самопроверок); `game/run_tests.sh`, `.github/workflows/ci2.yml`,
  `scripts/ci2_checkers.sh` — правки ссылок и вердиктных строк; `.gitignore`
  (строка-комментарий про `gen_docs_index.py`).
- **Документация:** ~2 000 правок в `docs/**` (включая 464 в `TICKETS.md`, 156 в
  `DECISIONS.md`, 608 в протоколах `docs/mvp/matrix/**`), 25 в `AGENTS.md`,
  752 в `openspec/changes/**` (из них 656 — архив), 82 в `openspec/specs/**`.
- **Спеки:** 1 новая capability, 7 дельт; `openspec validate --all --strict`
  обязан остаться зелёным после сведения.
- **Что теряется без замены:** машинная ловля расхождений «доки ↔ код», битых
  wikilinks, подмены кадров героев, немых автолоадов (вне `run_tests.sh`),
  дельта-заголовков в сведённых спеках, рэтчета карты тестов, провенанса ассетов.
  Всё это было зелено или красно только в момент ручного запуска.
- **Риск:** `docs/mvp/matrix/**` — дословные транскрипты вывода инструментов;
  правка слова меняет цитату (см. design.md, R1).

## Non-goals

- Игровой словарь механик: `gate_ok`, `population_gate_city`, `_check_class_gate`,
  ключ каталога `"gate"`, имена тестов `test_*_gate*`.
- Английские слова и константы движка, содержащие `gate` как подстроку:
  `negate` (328), `PROPAGATE_CHILD_FLAGS` (312), `obligated` (306), `navigate`
  (121), `delegate` (89), `surrogate` (77), `mitigated` (55), `aggregate` (42),
  `gateway` (26) — правится только целое слово, подстрока не трогается.
- Git-история (коммиты) и `.reserve/` (gitignored) — не переписываются.
- `game/run_tests.sh` и CI-2 как исполнители — остаются, меняется только имя в
  текстах.
