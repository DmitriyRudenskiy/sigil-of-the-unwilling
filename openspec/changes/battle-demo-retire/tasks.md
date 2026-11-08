## 1. Проверить, что переезд ничего не рвёт (до первого `git mv`)

- [ ] 1.1 Зафиксировать замеры в задачах числом: файлы/байты `battle-demo/`,
  побайтовые двойники (`addons/gdunit4` 517/517, 176 кадров), уникальное
  (10 портретов, 21 кадр `cutthroat`, `walk-sample.png`), размер `.godot/`.
- [ ] 1.2 `git grep -n 'battle-demo' -- ':!battle-demo' ':!docs/DECISIONS.md'
  ':!docs/CHANGELOG.md' ':!docs/mvp' ':!openspec/changes/archive' ':!.reserve'` —
  размечить живые ссылки против исторических; живые переносятся в группу 6.
- [ ] 1.3 Убедиться, что ни один шаг CI и ни один гейт не вызывает
  `battle-demo/run_tests.sh` и сцены стенда (`.github/workflows/*`,
  `scripts/doc_gates.sh`, `scripts/ci2_checkers.sh`, `game/run_tests.sh`).
- [ ] 1.4 Проверить, что в стенде нет untracked носителя, кроме кэша и мусора
  (`.godot/`, `.DS_Store`): `git status --porcelain -uall battle-demo`.

## 2. Переезд уникальных носителей (коммит «переезд»)

- [ ] 2.1 `git mv battle-demo/assets/portraits scripts/character_kit/portraits`
  (10 PNG; `.import`-файлы удалить — у пикселей больше нет причин быть
  импортированными Godot).
- [ ] 2.2 `git mv battle-demo/assets/sprites/cutthroat scripts/character_kit/sprites/cutthroat`
  (21 кадр, те же `.import` удалить).
- [ ] 2.3 `git mv battle-demo/assets/reference/walk-sample.png scripts/character_kit/runs/walk-sample.png`
  и удалить опустевший `assets/reference/`.
- [ ] 2.4 `git mv battle-demo/tools/build_sprite_frames.gd game/tools/` вместе с
  `.uid`; в самом файле — путь плана сборки (`res://` →
  `scripts/character_kit/runs/sprite-plan.json`) и сообщение об ошибке.
- [ ] 2.5 `git mv battle-demo/docs docs/archive/battle-demo` и
  `git mv battle-demo/CHANGELOG.md docs/archive/battle-demo/CHANGELOG.md`.
- [ ] 2.6 В перенесённых документах стенда править только адреса носителей,
  на которые они ссылаются (`tools/gen_clip.py` → `scripts/character_kit/gen_clip.py`,
  `assets/reference/walk-sample.png` → новое место); текст решений не переписывать.

## 3. Конвейер перестаёт знать про стенд

- [ ] 3.1 `scripts/character_kit/paths.py`: удалить корень `STAND`; домены
  остаются `REPO`/`PKG`/`OUT`/`RUNS`.
- [ ] 3.2 `audit_sprites.py`: `SPRITES` → `game/assets/sprites`, `unit_ids()` →
  из `spec.json["characters"]` вместо `glob("*.tres")` стенда; `UNITS` убрать.
- [ ] 3.3 `build_sprite_frames.py`: `SPRITES` → `game/assets/sprites`.
- [ ] 3.4 `gen_kit.py`: `PORTRAITS` → `paths.PKG / "portraits"`, `SHOTS` →
  `paths.OUT / "tmp/shots"`.
- [ ] 3.5 `spec.json`: `portraits_dir` → `scripts/character_kit/portraits`.
- [ ] 3.6 `test_character_kit.py`: инвариант ужесточить — ни один путь пакета не
  содержит `battle-demo` (прежде было «мимо `paths.STAND`»); прогнать самопроверку.
- [ ] 3.7 `scripts/character_kit/README.md`: новая раскладка, адрес архива
  записи (`docs/archive/battle-demo/`), чек-лист приёмки UI из спеки
  `battle-demo-ui`, пометка, что `ui_read_judge.py` рецензирует уже снятые кадры,
  и что девятый лист (`cutthroat`) игра не использует — вердикт в `runs/`.
- [ ] 3.8 Прогнать импорт всех 17 модулей из корня репо и `audit_sprites.py` на
  дереве `game/assets/sprites` — аудит обязан отдавать тот же вердикт, что и до
  разреза (сверить с `runs/`).

## 4. Архивная зона документов вне графа

- [ ] 4.1 `scripts/check_docs_links.py`: константа `ARCHIVE_DIR = docs/archive`
  рядом с `BANK_DIR` и исключение зоны из `doc_files()`.
- [ ] 4.2 Прогнать потребителей (`gen_docs_index.py`, `gdd_gate.py`,
  `audit_docs_vs_code.py`) — убедиться, что архив не лезет ни в индекс, ни в
  базлайны, ни в находки «доки ↔ код»; дописать исключение там, где оно нужно.
- [ ] 4.3 Минимальная самопроверка в `scripts/test_check_docs_links.py`: файл в
  `docs/archive/` не участвует в графе и не требует фронтоматтера.
- [ ] 4.4 Строка-адрес на архив там, где её будут искать: `docs/18-system-map.md`
  и `scripts/character_kit/README.md`.

## 5. Удаление папки (отдельный коммит)

- [ ] 5.1 `git rm -r battle-demo` (в индексе к этому моменту не остаётся ничего,
  кроме удаляемого: проверить `git ls-files battle-demo | wc -l` до и после).
- [ ] 5.2 `scripts/check_repo_layout.py`: убрать строку реестра `battle-demo`
  (12 носителей), прогнать `scripts/test_check_repo_layout.py`.
- [ ] 5.3 `.gitignore`: снять строки, описывающие вывод внутри стенда, если они
  остались; `/character_kit/` остаётся.
- [ ] 5.4 Проверить, что `game/` не потерял ни одного ресурса: `test_compile_all`,
  `check_asset_provenance`, `game/run_tests.sh`.

## 6. Переадресовка живых ссылок

- [ ] 6.1 `README.md`: убрать `battle-demo/` из дерева корня.
- [ ] 6.2 `docs/18-system-map.md`, `docs/mvp/HERO-ANIM.md`,
  `game/scripts/entities/character_frames.gd`,
  `game/tests/unit/ui/test_battle_figures_animated.gd`: «носитель комплекта
  `battle-demo`» → `scripts/character_kit/` и `game/assets/sprites/`.
- [ ] 6.3 `game/assets/PROVENANCE.md`: строки, ссылающиеся на путь стенда,
  переадресовать на `scripts/character_kit/` (историю прогонов не переписывать).
- [ ] 6.4 `scripts/character_kit/ui_read_judge.py`: шапка — чек-лист живёт в
  README конвейера, а не в спеке `battle-demo-ui`.
- [ ] 6.5 `openspec/changes/README.md`: у строки `battle-demo-two-rosters`
  пометить выведенный носитель и актуальные способности.

## 7. Спеки, реестры, даты

- [ ] 7.1 `openspec validate battle-demo-retire --strict` — зелено до реализации.
- [ ] 7.2 `docs/QUESTIONS.md`: Q-M139 → закрыт решением владельца 2026-11-09
  (перенести наработки, папку удалить) с фактом «в репозитории 12 носителей»;
  поднять Q-M140 `[human]` про `turn-battle-core` против `dnd-battle-ladder`.
- [ ] 7.3 `docs/DECISIONS.md`: D-321 с обязательной секцией `Отвергнутые`
  (иначе `gdd_gate` краснеет).
- [ ] 7.4 `docs/CHANGELOG.md`: запись разреза (дата — по конвенции репозитория).
- [ ] 7.5 `python3 scripts/gen_docs_index.py` — индекс свежий.

## 8. Замер гейтов (числом, в задачи)

- [ ] 8.1 `python3 scripts/check_repo_layout.py` — «корень в перечне (12
  носителей), вывод прогонов пуст».
- [ ] 8.2 `bash scripts/doc_gates.sh` — прежнее число находок, новых нет;
  `python3 scripts/check_docs_links.py` — OK.
- [ ] 8.3 `python3 scripts/gdd_gate.py` — GREEN; `bash scripts/ci2_checkers.sh` — GREEN.
- [ ] 8.4 `openspec validate --all --strict` — то же число прежних находок;
  после синхронизации — на две сведённые спеки меньше.
- [ ] 8.5 `MCP_SSH_HOST= game/run_tests.sh` — `GATE VERDICT: GREEN`.
- [ ] 8.6 Два коммита: переезд (группы 2–4, 6–7) и удаление (группа 5), каждый
  с точечным `git add`; `git add -A` не используется.
