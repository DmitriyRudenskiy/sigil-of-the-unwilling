## Why

Корень репозитория превратился в свалку промежуточных состояний: рядом с `game/`
живут четыре носителя разного рода (лаборатория ассетов, демо-проект Godot,
черновики доков, журнал гейтов), три из которых либо уже переехали, либо никогда
не были частью игры. Часть переездов сделана наполовину — `image-clone/` физически
перенесён в `game/image-clone/`, но git по-прежнему считает 29 файлов в корне
отслеживаемыми, а `.gitignore` и код смотрят на старый путь. Пока контракт
«что лежит в корне» нигде не записан, каждый следующий носитель заведётся туда же.

## What Changes

- **`artifacts/` (корень) — удалить из дерева.** Три файла: два журнала гейтов в
  git + один локальный. Это вывод прогонов, а не артефакты поставки. Каталог
  становится gitignored-скратчем; путь журнала в `.gitignore`, новые ссылки — только
  на него. **Не трогать** `game/assets/artifacts/` и резолвер `artifacts/%s.png`
  (иконки артефактов) — это другое значение того же слова, ~20 живых ссылок.
- **`tools/` (корень) — удалить из дерева.** В git остаётся `tools/spellbook_sheets/`
  (6 скриптов, уже удалённых из рабочего дерева); рабочий каталог пуст, кроме
  `.DS_Store`. Владелец переноса — `game/tools/`.
- **`image-clone/` (корень) — снять с отслеживания.** Переезд в `game/image-clone/`
  завершить: `.gitignore` переводится с `/image-clone/…` на `/game/image-clone/…`,
  ссылки в `scripts/gen_map_art.py`, `game/assets/objects/*.json` (`source:`),
  `game/run_tests.sh`, `game/tests/smoke/test_compile_all.gd` и `AGENTS.md`
  перепривязываются к новому пути.
- **`rpg_system.py` — из корня в `game/tools/`.** Механики файла (пять тиров
  материалов, крафт, поселения, расы) уже канон в `docs/` и реализованы в GDScript
  (`game/scripts/systems/weapon_catalog.gd`, `hero_crafting_component.gd`); ссылок
  на модуль в репозитории ноль. Владелец отнёс модуль к игре, а каталога
  `prototypes/` в дереве больше нет — носителем становится `game/tools/`, где
  Python-инструменты (`gen_resource_icons.py`, `gen_icon_sheet.py`) живут и так.
- **`doc/` → `docs/`.** Три файла (`SAVE_MATRIX.md`, `races-economy.md`,
  `social-mechanics.md`) переезжают в vault; `doc/` как каталог перестаёт
  существовать. Правятся `scripts/check_save_matrix.py` (+ его тест) и ссылка
  спеки `save-migration`.
- **`battle-demo/` — ничего не переносится (измерено, не на глаз).** Анимации
  юнитов уже в игре: 176 из 176 общих PNG в `battle-demo/assets/sprites/` и
  `game/assets/sprites/` совпадают по md5, `.sprite_frames.tres` идентичны, в игре
  14 наборов против 10. Единственный набор демо, отсутствующий в игре — `cutthroat`,
  — игрового юнита с таким ключом нет. Что ещё переносить — см. design.md; решение
  о судьбе самого `battle-demo` выносится владельцу, в этом change оно не входит.
- **`concept_art/` — ничего не переносится.** 429 файлов, 48 МБ, уже в
  `.gitignore`; это вывод `scripts/concept_art/`, а не носитель.
- **`.pi/` — остаётся, документируется.** 13 отслеживаемых файлов: 6 промптов
  `/opsx-*` (интерфейс OpenSpec в этом редакторе), 6 проектных скиллов, 1 хвост
  `todos/`. Это инструмент агента, а не мусор; в README его нет — добавить в
  контракт корня.
- **`prototypes/` — удалить из дерева.** Один отслеживаемый файл —
  `battle-hud/index.html`, HTML-макет боевого HUD смены сентября; носитель
  переснят живыми экранами `game/scenes/battle/`.
- **`data/` — удалить с диска.** 99 МБ, **ноль отслеживаемых файлов**, уже в
  `.gitignore`. Это осиротевшее хранилище OpenViking (`viking/`, `vectordb/`,
  `_system/queue/queue.db`), а не данные игры: живой `openviking-server` держит
  своё хранилище в cwd процесса, а не здесь. В git ничего не входит, поэтому
  удаление — расчистка диска, а не изменение репозитория.
- **Корневой бойлплейт — удалить: `LICENSE`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `CONTRIBUTING.md`, `.editorconfig`.** Ни один чекер и ни один шаг CI на них не
  ссылаются; отсылают только `README.md` (строки 5, 204, 247, 253) и одна
  архивная задача. **`game/assets/fonts/LICENSE.txt` (OFL, шрифты PT) остаётся**
  — это обязательство перед третьими лицами, к лицензии репо отношения не имеет.
- **Корневой `CHANGELOG.md` — перенести в `docs/` и удалить файл.** Три раздела
  (2026-09-27, 2026-09-25, 2026-02-22); в `docs/CHANGELOG.md` нет ни одного
  упоминания дат 2026-09-25 и 2026-02-22, то есть два раздела существуют только
  здесь. Носитель журнала — `docs/CHANGELOG.md`; навык `.pi/skills/changelog`,
  который это предписывал, удаляется этим же разрезом (см. ниже).
- **`.gitignore` — актуализировать.** Переезд блока `image-clone/` в
  `game/image-clone/`, правило для вывода прогонов, и главное: **`.reserve/`
  игнорируется только локально**, через `.git/info/exclude:9`, — на свежем клоне
  правила нет, и 69 каталогов пойдут в `git add -A`.
- **`.pi/skills/` — остаётся один навык, `ui-grid-review`.** Пятеро соседей
  (`changelog`, `content-audit`, `create-epics`, `loop-me`,
  `verification-before-completion`) удаляются. Ни один чекер, ни один шаг CI и
  ни одна спека `openspec/specs/` на них не ссылается; единственный носитель,
  который их вызывает, — `docs/19-gdd-workflow.md` (шаги 1, 3, 4 и таблица
  строки 104), и он правится в том же разрезе, иначе документ опишет процесс
  без носителей. Промпты `/opsx-*` и `todos/` не затронуты.
- **Граница `scripts/` ↔ `game/tools/` закрепляется, а не стирается.** Массового
  переноса `scripts/` в `game/tools/` не будет: `scripts/` — хостовый Python,
  который сканирует репозиторий (`docs/`, `openspec/`, git-индекс, `.github/`),
  `game/tools/` — инструменты внутри проекта Godot, гоняемые `--path game`.
  Перенос gates в `res://` положил бы репозиторное управление в проект движка.
  Переносятся ровно те носители, у которых уже есть брат в `game/tools/`:
  два генератора из `game/scripts/ui_kit/` (единственный Python внутри
  боевого GDScript-namespace `res://scripts/`) и шесть генераторов ассетов из
  `scripts/ui_kit/`, чьи аналоги (`gen_resource_icons.py`, `pixelart/*.py`) там
  уже живут.
- **Мусор внутри `scripts/` — снять с отслеживания.** `scripts/concept_art/concept_art/**`
  — 45 отслеживаемых сгенерированных курсоров, ноль ссылок; живые курсоры —
  `game/assets/cursors/*.png` (другие md5). Удвоенный путь прошёл сквозь
  `.gitignore:29`, закрывающий только корневой `/concept_art/`. Плюс шесть
  неиспользуемых `spec_copy*.json` и одноразовый `split_02f.py`.
- **Провенанс ассетов — путь генератора обязан существовать.**
  `game/assets/PROVENANCE.md` объявляет генератором
  `game/tools/recolor_button_textures.py` — файла нет. `MANIFEST.json`
  виджетов объявляет `scripts/ui_kit/build_round_button.py` — файл живёт в
  `game/scripts/ui_kit/`. `check_asset_provenance.py` существование
  объявленного пути не проверяет, поэтому обе записи сгнили незаметно.
- **`game/report.sh` — удалить.** Единственный исполнитель решения **D-138**
  («ни одно число в отчёте не пишется по памяти», `docs/DECISIONS.md:328`,
  метод счёта указан прямо там же). Удаление оставляет решение без носителя,
  поэтому в `docs/DECISIONS.md` записывается, что D-138 остаётся правилом,
  но перестал быть автоматизированным.
- **`game/dbg_stats.gd` — в `game/tools/`.** Единственный `.gd` в корне проекта
  Godot: 15 строк, `extends SceneTree`, одноразовая диагностика, ни одного
  загрузчика. Соседи (`diag_*.gd`, `map_shot.gd`, `ui_dump.gd`) живут в
  `game/tools/`. Переезд меняет покрытие `test_compile_all.gd`: `tools` входит
  в его `SKIP`, поэтому счётчик в комментарии (строка 26) требует правки.

## Capabilities

### New Capabilities
- `repo-layout`: контракт верхнего уровня репозитория — какие каталоги имеют право
  лежать в корне, где живут вывод прогонов, лаборатории ассетов и Python вне
  игрового кода, обязан ли корень хранить юридический и community-бойлплейт,
  где граница между репозиторным и внутрипроектным инструментом, обязана ли
  запись провенанса разрешаться в существующий файл, и как всё это проверяется
  машиной, а не чтением `ls`.

### Modified Capabilities
- `save-migration`: требование о матрице покрытия сейва ссылается на
  `doc/SAVE_MATRIX.md` — адрес меняется на `docs/save-matrix.md`
  (в `docs/` политика именования — только латиница, см. `check_docs_links.py`).
- `image-clone-lab`: лаборатория привязана к путям `image-clone/…` (очередь,
  эталоны, пары, style card) — носитель переезжает в `game/image-clone/…`.

## Impact

- **Код/скрипты:** `scripts/check_save_matrix.py`, `scripts/test_check_save_matrix.py`,
  `scripts/gen_map_art.py`, `scripts/ui_diff.py` (крах `--help`),
  `scripts/check_asset_provenance.py`, `game/run_tests.sh`,
  `game/tests/smoke/test_compile_all.gd`, `game/assets/objects/world_map_*.json`,
  `game/dbg_stats.gd` (+ `.uid`), `game/scripts/ui_kit/` → `game/tools/ui_kit/`,
  `scripts/ui_kit/` → `game/tools/ui_kit/`.
- **Удаление:** `game/report.sh`, пять навыков `.pi/skills/`,
  `scripts/concept_art/concept_art/**` (45 файлов), шесть `spec_copy*.json`,
  `scripts/split_02f.py`.
- **Провенанс:** `game/assets/PROVENANCE.md`, `game/assets/ui/widgets/MANIFEST.json`
  (оба объявляют несуществующие пути генераторов).
- **Конфиг:** `.gitignore` (блоки `artifacts/`, `image-clone/`, `reserve/`),
  `.git/info/exclude` (правило `.reserve/` оттуда уходит), `README.md`
  (§ «Структура проекта», строки 5, 204, 247, 253), `AGENTS.md`.
- **Спеки:** `openspec/specs/save-migration/spec.md`,
  `openspec/specs/image-clone-lab/spec.md`.
- **Гейты:** `scripts/check_docs_links.py` (переехавшие доки входят в wikilink-граф
  и обязаны получить frontmatter), `scripts/check_openspec_specs.py`, CI `ci2.yml`.
- **Документация:** `docs/CHANGELOG.md` (принимает три раздела корневого
  журнала), `docs/DECISIONS.md` (переезды + утрата носителя D-138),
  `docs/QUESTIONS.md`, `docs/19-gdd-workflow.md` (теряет пять вызываемых
  навыков), `AGENTS.md`.
- **Навык `ui-grid-review` — проверен живым прогоном, работает:** self-check OK,
  сетка на макет 2816×1584, кроп `D5 --zoom 3`, `ui_dump.gd` выдал 15 узлов
  ячейки D5, `ui_diff.py` корректно нашёл тронутые ячейки и фильтрует по
  `--cell`. Единственный дефект — `ui_diff.py --help` (`ValueError:
  unsupported format character`, неэкранированный `%` в help-строке
  `--min-change`, строка 55); той же веткой `p.error()` падает и на
  некорректном аргументе. Канонический кадр (шаг 1, pytest + MCP) не проверялся:
  требует сервер и X-дисплей.
- **Не затрагивается:** `game/assets/artifacts/`, `game/assets/fonts/LICENSE.txt`,
  `battle-demo/`, `concept_art/`, `docs/` (кроме приёма трёх файлов, трёх
  разделов журнала и правки `19-gdd-workflow.md`), игровой код,
  `game/tests/mcp/` (40 pytest-файлов — правильное место),
  `scripts/hero_anim/out/**/picked.json` (трекаются намеренно: `.gitignore:71`
  прямо объясняет «в git попадает только вердикт выбора варианта»).
