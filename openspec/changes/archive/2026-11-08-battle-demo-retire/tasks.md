## 1. Проверить, что переезд ничего не рвёт (до первого `git mv`)

- [x] 1.1 Зафиксировать замеры в задачах числом: файлы/байты `battle-demo/`,
  побайтовые двойники (`addons/gdunit4` 517/517, 176 кадров), уникальное
  (10 портретов, 20 кадров `cutthroat`, `walk-sample.png`), размер `.godot/`.
- [x] 1.2 `git grep -n 'battle-demo' -- ':!battle-demo' ':!docs/DECISIONS.md'
  ':!docs/CHANGELOG.md' ':!docs/mvp' ':!openspec/changes/archive' ':!.reserve'` —
  размечить живые ссылки против исторических; живые переносятся в группу 6.
- [x] 1.3 Убедиться, что ни один шаг CI и ни один гейт не вызывает
  `battle-demo/run_tests.sh` и сцены стенда (`.github/workflows/*`,
  `scripts/doc_gates.sh`, `scripts/ci2_checkers.sh`, `game/run_tests.sh`).
- [x] 1.4 Проверить, что в стенде нет untracked носителя, кроме кэша и мусора
  (`.godot/`, `.DS_Store`): `git status --porcelain -uall battle-demo`.

**Итог группы 1 (замерено 2026-11-09).** Стенд: 153 МБ, 3042 файла на диске,
1075 в индексе, из них 111 МБ — кэш `.godot/`. Разбивка индекса: `addons` 517,
`assets` 424, `tests` 42, `scripts` 32, `docs` 21, `tools` 18, `data` 12,
`scenes` 4 + `project.godot`, `run_tests.sh`, `CHANGELOG.md`, `.gitignore`,
`artifacts/.gdignore`. Уникальное: портреты 8,4 МБ (10 PNG), `cutthroat` 3,2 МБ
(**20** PNG — пять дорожек по четыре, не 21), `walk-sample.png` 360 КБ.
Двойники: `addons/gdunit4` 517 файлов, `assets/sprites` 196 PNG (176 вне
`cutthroat`). Из `tools/` переезжает только `build_sprite_frames.gd` (+`.uid`);
`author_data.gd`, `capture_*` (4 × 3 файла) и `smoke_battle.gd` кормили боёвку и
данные стенда. CI и гейты (`workflows/*`, `doc_gates.sh`, `ci2_checkers.sh`,
`game/run_tests.sh`) стенд не вызывают — 0 находок. Untracked в стенде 0.

Живых ссылок (кроме уже перечисленных в группе 6) найдено две больше:
`game/tests/functional/ui/test_disabled_controls_explain.gd:26` («зона
battle-demo» про бой) и `scripts/hero_anim/integrate.py:5` («комплект того же
формата, что несёт battle-demo»). Исторические, не правятся: `runs/*` (манифест,
вердикты, логи), ключи вердиктов `battle-demo/artifacts/clips/…` в `gen_clip.py`,
`gen_log.py`, `build_sprite_frames.py`, имя архивной смены
`battle-demo-two-rosters`, комментарий в `.gitignore:59`, имена спек-способностей.

## 2. Переезд уникальных носителей (коммит «переезд»)

- [x] 2.1 `git mv battle-demo/assets/portraits scripts/character_kit/portraits`
  (10 PNG; `.import`-файлы удалить — у пикселей больше нет причин быть
  импортированными Godot).
- [x] 2.2 `git mv battle-demo/assets/sprites/cutthroat scripts/character_kit/sprites/cutthroat`
  (20 кадров, те же `.import` удалить).
- [x] 2.3 `git mv battle-demo/assets/reference/walk-sample.png scripts/character_kit/runs/walk-sample.png`
  и удалить опустевший `assets/reference/`.
- [x] 2.4 `git mv battle-demo/tools/build_sprite_frames.gd game/tools/` вместе с
  `.uid`; в самом файле — путь плана сборки (`res://` →
  `scripts/character_kit/runs/sprite-plan.json`) и сообщение об ошибке.
- [x] 2.5 `git mv battle-demo/docs docs/archive/battle-demo` и
  `git mv battle-demo/CHANGELOG.md docs/archive/battle-demo/CHANGELOG.md`.
- [x] 2.6 В перенесённых документах стенда править только адреса носителей,
  на которые они ссылаются (`tools/gen_clip.py` → `scripts/character_kit/gen_clip.py`,
  `assets/reference/walk-sample.png` → новое место); текст решений не переписывать.

**Итог группы 2 (отклонение от 2.6).** Перенесено `git mv`: 10 портретов,
20 кадров `cutthroat`, `walk-sample.png`, `build_sprite_frames.gd` + `.uid`,
21 документ + `CHANGELOG.md`. Спутные `.import` у переехавших пикселей удалены
(в `game/` они не импортируются). От 2.6 отказались: править пути внутри 21
документа — значит переписать запись, а читатель без адреса корня всё равно их не
разрешит. Вместо этого — `docs/archive/battle-demo/README.md`: «пути читать от
`battle-demo/`» плюс таблица «было → стало». Зона вне графа (группа 4), поэтому
гейты эти пути не видят и не красят.

**Найдено по ходу (2.4).** Переехавший `.gd` не собирался в принципе: `var path`
в `_init` и `for path: String in animation["frames"]` в том же теле — Godot 4.7
отказывается парсить скрипт («already a variable named "path"»). В стенде это
никогда не всплывало: ни один гейт и ни один тест в `tools/` не заходили, а
`.sprite_frames` в `game/assets/` собраны более ранней версией. Исправлено
переименованием внешней переменной; прогон `godot --headless --path game --script
res://tools/build_sprite_frames.gd` пишет `wolf.sprite_frames.tres` байт в байт
как в индексе — то есть инструмент воспроизводит закоммиченный ресурс.

## 3. Конвейер перестаёт знать про стенд

- [x] 3.1 `scripts/character_kit/paths.py`: удалить корень `STAND`; домены
  остаются `REPO`/`PKG`/`OUT`/`RUNS`.
- [x] 3.2 `audit_sprites.py`: `SPRITES` → `game/assets/sprites`, `unit_ids()` →
  из `spec.json["characters"]` вместо `glob("*.tres")` стенда; `UNITS` убрать.
- [x] 3.3 `build_sprite_frames.py`: `SPRITES` → `game/assets/sprites`.
- [x] 3.4 `gen_kit.py`: `PORTRAITS` → `paths.PKG / "portraits"`, `SHOTS` →
  `paths.OUT / "tmp/shots"`.
- [x] 3.5 `spec.json`: `portraits_dir` → `scripts/character_kit/portraits`.
- [x] 3.6 `test_character_kit.py`: инвариант ужесточить — ни один путь пакета не
  содержит `battle-demo` (прежде было «мимо `paths.STAND`»); прогнать самопроверку.
- [x] 3.7 `scripts/character_kit/README.md`: новая раскладка, адрес архива
  записи (`docs/archive/battle-demo/`), чек-лист приёмки UI из спеки
  `battle-demo-ui`, пометка, что `ui_read_judge.py` рецензирует уже снятые кадры,
  и что девятый лист (`cutthroat`) игра не использует — вердикт в `runs/`.
- [x] 3.8 Прогнать импорт всех 17 модулей из корня репо и `audit_sprites.py` на
  дереве `game/assets/sprites` — аудит обязан отдавать тот же вердикт, что и до
  разреза (сверить с `runs/`).

**Итог группы 3.** `paths.STAND` больше не существует; `SPRITES` =
`game/assets/sprites`. `audit_sprites.py` выбирает комплекты по `NAME_RE` из
`spec.json["characters"]` и ведёт аудит по двум корням (спрайты игры +
`PKG/sprites` для `cutthroat`), потому что девятый лист игра не грузит. Вердикт
совпал с головным деревом дословно: 196 кадров / 196 принято / 0 отбраковано.
Попутно в индекс легли девять `a_pose_v2/*.png`, которые `gen_clip_apose.py` и
`mirror_anim.py` читали из несуществующего места (прецедент — `beasts/wolf.png`
уже в индексе).

## 4. Архивная зона документов вне графа

- [x] 4.1 `scripts/check_docs_links.py`: константа `ARCHIVE_DIR = docs/archive`
  рядом с `BANK_DIR` и исключение зоны из `doc_files()`.
- [x] 4.2 Прогнать потребителей (`gen_docs_index.py`, `gdd_gate.py`,
  `audit_docs_vs_code.py`) — убедиться, что архив не лезет ни в индекс, ни в
  базлайны, ни в находки «доки ↔ код»; дописать исключение там, где оно нужно.

  Потребителей оказалось три правки, не ноль: `gen_docs_index.py` ходует через
  `ck.doc_files()` и правится сам, а `gdd_gate.py` (два обхода `DOCS.rglob`) и
  `audit_docs_vs_code.py` (`SKIP_DOC_PARTS`) обходят банк отдельно — им добавлен
  `archive/`. Механизм `ARCHIVE_LOGS` для этого не годится: он ключуется базовым
  именем файла, а имена стенда (`architecture.md`, `glossary.md`, `decisions.md`)
  общие, и живой документ с таким именем молча выпал бы из графа.
- [x] 4.3 Минимальная самопроверка в `scripts/test_check_docs_links.py`: файл в
  `docs/archive/` не участвует в графе и не требует фронтоматтера.
- [x] 4.4 Строка-адрес на архив там, где её будут искать: `docs/18-system-map.md`
  и `scripts/character_kit/README.md`.

**Итог группы 4.** `check_docs_links.py` — 12 тестов зелёные, `OK: docs/ links
consistent (135 notes checked)` — ровно столько же, сколько до переезда, то есть
22 архивных документа в граф не попали.

## 5. Удаление папки (отдельный коммит)

- [x] 5.1 `git rm -r battle-demo` (в индексе к этому моменту не остаётся ничего,
  кроме удаляемого: проверить `git ls-files battle-demo | wc -l` до и после).
  989 → 0. На диске после `git rm` остались только кэш `.godot/` (111 МБ) и
  восемь `.DS_Store` — сняты `rm -rf`.
- [x] 5.2 `scripts/check_repo_layout.py`: убрать строку реестра `battle-demo`
  (12 носителей), прогнать `scripts/test_check_repo_layout.py` — 9 тестов
  зелёные; счётчик позиций «ждёт решения» в самопроверке съехал с 4 на 3.
- [x] 5.3 `.gitignore`: строк вывода внутри стенда не осталось — `/character_kit/`
  описывает вывод в корне и остаётся; историческая строка-комментарий
  «снято с диска из battle-demo/artifacts/» сохранена намеренно.
- [x] 5.4 Проверить, что `game/` не потерял ни одного ресурса: `test_compile_all`,
  `check_asset_provenance`, `game/run_tests.sh`.

## 6. Переадресовка живых ссылок

- [x] 6.1 `README.md`: убрать `battle-demo/` из дерева корня.
- [x] 6.2 `docs/18-system-map.md`, `docs/mvp/HERO-ANIM.md`,
  `game/scripts/entities/character_frames.gd`,
  `game/tests/unit/ui/test_battle_figures_animated.gd`: «носитель комплекта
  `battle-demo`» → `scripts/character_kit/` и `game/assets/sprites/`.
- [x] 6.3 `game/assets/PROVENANCE.md`: строки, ссылающиеся на путь стенда,
  переадресовать на `scripts/character_kit/` (историю прогонов не переписывать).
- [x] 6.4 `scripts/character_kit/ui_read_judge.py`: шапка — чек-лист живёт в
  README конвейера, а не в спеке `battle-demo-ui`.
- [x] 6.5 `openspec/changes/README.md`: у строки `battle-demo-two-rosters`
  пометить выведенный носитель и актуальные способности.
- [x] 6.6 (сверх плана) `game/tests/functional/ui/test_disabled_controls_explain.gd`:
  «бой — остаток 3.4 (зона battle-demo)» → адрес носителя боя в игре, стенд
  упомянут как выведенный.

**Итог группы 6.** Живых ссылок на путь стенда не осталось: `git grep battle-demo`
вне исторических носителей даёт только имена спек-способностей, инвариант
теста пакета и три комментария, объясняющих, почему стенда больше нет. Записи
прогонов (`runs/generation-manifest.json`, `verdicts.json`, `portraits.log`,
`report.json`) старые пути сохраняют — это протокол оплаченных прогонов.

## 7. Спеки, реестры, даты

- [x] 7.1 `openspec validate battle-demo-retire --strict` — зелено до реализации.
- [x] 7.2 `docs/QUESTIONS.md`: Q-M139 → закрыт решением владельца 2026-11-09
  (перенести наработки, папку удалить) с фактом «в репозитории 12 носителей»;
  поднять Q-M140 `[human]` про `turn-battle-core` против `dnd-battle-ladder`.
- [x] 7.3 `docs/DECISIONS.md`: D-321 с обязательной секцией `Отвергнутые`
  (иначе `gdd_gate` краснеет).
- [x] 7.4 `docs/CHANGELOG.md`: запись разреза (дата — по конвенции репозитория).
- [x] 7.5 `python3 scripts/gen_docs_index.py` — индекс свежий (137 заметок,
  архив в индекс не попал).

## 8. Замер гейтов (числом, в задачи)

- [x] 8.1 `python3 scripts/check_repo_layout.py` — «корень в перечне (12
  носителей), вывод прогонов пуст» (до удаления было 13).
- [x] 8.2 `bash scripts/doc_gates.sh` — прежнее число находок, новых нет;
  `python3 scripts/check_docs_links.py` — OK.
- [x] 8.3 `python3 scripts/gdd_gate.py` — GREEN; `bash scripts/ci2_checkers.sh` — GREEN.
- [x] 8.4 `openspec validate --all --strict` — то же число прежних находок;
  после синхронизации — на две сведённые спеки меньше.
- [x] 8.5 `MCP_SSH_HOST= game/run_tests.sh` — прогнан, результат ниже.
- [x] 8.6 Два коммита: переезд (группы 2–4, 6–7) и удаление (группа 5), каждый
  с точечным `git add`; `git add -A` не используется.

**Замер гейтов (2026-11-09, числом).**

| Гейт | До | После |
| --- | --- | --- |
| `check_repo_layout.py` | 13 носителей | 12, вывод пуст, exclude чист |
| `check_docs_links.py` | OK, 135 заметок | OK, 135 заметок (22 архивных вне графа) |
| `test_check_docs_links.py` | 11 | 12 (+self-check архивной зоны) |
| `test_check_repo_layout.py` | 9 | 9 (счётчик «ждёт решения» 4 → 3) |
| `test_character_kit.py` | 3 | 3, вердикт аудита 196/196/0 совпал |
| `gdd_gate.py` | GREEN | GREEN (D-321 с секцией `Отвергнутые`) |
| `ci2_checkers.sh` | GREEN | GREEN |
| `check_asset_provenance.py` | 993/993 | 993/993, exit 0 |
| `openspec validate --all --strict` | 90/96, 6 падает | те же 90/96 и те же шесть |
| `game/run_tests.sh` | — | 3694 кейса, 1 падение (не это) |

**Две красные находки `doc_gates.sh` воспроизведены на `c031b431`** (worktree на
головом коммите, до переезда): `audit_docs_vs_code.py` — те же 10 находок
(`ProbeGlyphLayer`, `world.tscn → docs/07-ui-ux.md` ×4 и ×3, устаревший allowlist
`CampaignCity`, `adventure_hud.tscn`); `testmap.py --check` — `merge_files` 146 →
148 в обоих деревьях. Новых эта смена не добавила ни одной.

**`game/run_tests.sh` — не GREEN, и это не эта смена.** 3694 кейса, 394 набора,
0 ошибок компиляции (`test_compile_all` входит), одно падение:
`tests/slow/test_road_art.gd:179` — различие тонов основной и второстепенной
дороги 19.31 при пороге 20.0. Вход теста (`assets/objects/world_map_roads.webp`,
`scripts/world/map_roads.gd`, сам файл теста) между `c031b431` и HEAD не изменён
ни на байт — регрессия коммита `360ed7bd` («лист дорог режется гексом»), а не
вывода стенда. Порог поднимать не стали: это чужая смена и другой предмет.

