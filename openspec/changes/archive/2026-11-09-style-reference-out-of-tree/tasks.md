# Tasks: стиль-референс вне рабочего дерева

Мера по умолчанию для всех групп: `python3 scripts/check_reference_index.py` и
`python3 scripts/check_repo_layout.py`. Исторические носители (`docs/DECISIONS.md`,
`docs/mvp/TICKETS.md`, `docs/CHANGELOG.md`, архивные смены, логи `docs/mvp/matrix/`)
в группах 1–5 не правятся.

## 1. Переезд носителя

- [x] 1.1 MD5-снимок всех 12 пикселей `reference/` сверен с картой и сохранён
      (`/tmp/canon-md5-before.txt`); расхождений до начала разреза нет.
- [x] 1.2 Создан `~/sigil-reference/`, в него перенесены 10 файлов (`02`–`05`,
      `07`–`12`). `mv` и любое удаление — разными вызовами (правило 1 D-192).
- [x] 1.3 `battle_snow.png`, `battle_swamp.png` удалены из дерева как побайтовые
      копии носителей в `game/assets/ui/backgrounds/` (md5 совпадают).
- [x] 1.4 `reference/INDEX.md` → `docs/style-reference-index.md` через `git mv`,
      добавлен frontmatter (`title/tags/status/date`), текст карты не переписывается.
- [x] 1.5 `reference/spellbook/` → `docs/spellbook-sheets/` через `git mv` (4 файла).
- [x] 1.6 Каталога `reference/` в рабочем дереве нет: `ls reference` → «No such file
      or directory», `git status` чист по этому пути.
- [x] 1.7 Мера переезда: md5 десяти файлов в `~/sigil-reference/` равны снимку 1.1;
      двух удалённых — равны копиям в git.

## 2. Чекер карты

- [x] 2.1 `scripts/check_reference_index.py`: карта читается как
      `docs/style-reference-index.md`, каталог пикселей берётся из
      `SIGIL_REFERENCE_DIR` (дефолт `$HOME/sigil-reference`).
- [x] 2.2 Третий вердикт `CANON DIR ABSENT (<путь>)` с кодом 2 — отделён от
      расхождения (1) и от «согласовано» (0).
- [x] 2.3 Шапка скрипта описывает переменную и три кода возврата.
- [x] 2.4 Все три состояния прогонены вручную: согласован / дрейф (подмешать лишний
      файл) / каталог отсутствует.

## 3. Состав корня

- [x] 3.1 `scripts/check_repo_layout.py`: `reference` убран из перечня (14 → 13).
- [x] 3.2 `scripts/test_check_repo_layout.py`: фикстуры и ожидания не ссылаются на
      `reference/`.
- [x] 3.3 `.gitignore`: снят блок `reference/*` (6 правил) — игнорировать нечего.
- [x] 3.4 `README.md`: строка дерева без `reference/`, носитель комплекта назван.

## 4. Ретаргет живых потребителей

- [x] 4.1 `game/tools/ui_kit/build_round_button.py` — замеры по макету `11` читаются
      с нового носителя.
- [x] 4.2 `game/assets/ui/widgets/MANIFEST.json` — поля `mockup`/`source` (`09`, `11`).
- [x] 4.3 `game/assets/PROVENANCE.md` — строки про референсы.
- [x] 4.4 `docs/13-art-bible.md`, `docs/17-ui-style-guide.md`,
      `docs/20-ux-hero-screen.md`, `docs/21-ux-map-screen.md` — ссылки на карту и
      комплект.
- [x] 4.5 `docs/QUESTIONS.md` — только открытые строки Q-M (включая Q-M89): исторические
      акты и закрытые вопросы не переписываются.
- [x] 4.6 `scripts/measure_frame_vs_content.py` — пример вызова.
- [x] 4.7 Мера: живой ссылки на старый путь не остаётся; вхождение `reference/`
      находится только в исторических носителях (список выше).

## 5. Реестры решений

- [x] 5.1 `docs/DECISIONS.md`: запись D-319 с обязательной секцией «Отвергнутые»
      (рячет `gdd_gate.py`).
- [x] 5.2 `docs/CHANGELOG.md`: запись разреза.
- [x] 5.3 `docs/00-INDEX.md` перегенерирован `python3 scripts/gen_docs_index.py`.

## 6. Мерка

- [x] 6.1 `check_reference_index.py`: 0 с выставленным `SIGIL_REFERENCE_DIR`,
      2 без комплекта, 1 при подмешанном файле.
- [x] 6.2 `check_repo_layout.py`, `check_asset_provenance.py`, `check_docs_links.py` —
      зелёные.
- [x] 6.3 `scripts/ci2_checkers.sh` — зелёный (7 проверок).
- [x] 6.4 `scripts/doc_gates.sh` — только две прежние находки (`audit_docs_vs_code`,
      testmap), новых нет.
- [x] 6.5 `gdd_gate.py` — GREEN.
- [x] 6.6 `openspec validate --all --strict` — те же 6 pre-existing падений, новых нет.
- [x] 6.7 `game/run_tests.sh` с `MCP_SSH_HOST=` — `GATE VERDICT: GREEN` (карта
      трогает `game/assets/`, манифест и генератор кнопки).

## Итог прогона (2026-11-09)

- 1.7: md5 десяти файлов в `~/sigil-reference/` равны снимку; двух удалённых — равны
  копиям в git (`cmp`).
- 2.4: `0` — «OK: docs/style-reference-index.md ↔ /Users/user/sigil-reference
  согласованы (14 файлов комплекта)»; `1` — подмешанный `zyzz_test.png` →
  `FILE WITHOUT ROW`; `2` — `CANON DIR ABSENT (/tmp/нет-такого-каталога)`.
- 3.1: `РАСПОЛОЖЕНИЕ: корень в перечне (13 носителей)`.
- 4.7: переадресовано 49 строк в 24 файлах + 5 строк в `docs/QUESTIONS.md`
  (открытые Q-M89/Q-M112/Q-M113/Q-M114) + `scripts/concept_art/map_spec.json`.
  Живых ссылок на старый путь не осталось; исторические (акты D-203/D-185,
  закрытые Q-M, T-298, аудит 55 файлов, `docs/reference/map-baseline/`,
  `.reserve/`, архивные смены) сохранены намеренно.
- 6.1–6.6: `check_docs_links` OK (135 заметок, индекс 137); `ci2_checkers.sh`
  GREEN; `gdd_gate.py` GREEN, `d_without_rejected 170 (базлайн 170)`,
  `dead_paths 3 (базлайн 4)` — рэтчет улучшился; `doc_gates.sh` — только две
  прежние находки (docs↔code: ProbeGlyphLayer / world.tscn×7 / CampaignCity /
  adventure_hud.tscn; testmap 146→148); `openspec validate --all --strict` —
  89 passed / 6 failed (та же шестёрка, +1 прошедшая — эта смена).
- 6.7: `MCP_SSH_HOST= game/run_tests.sh` → `GATE VERDICT: GREEN`
  (pytest 123 passed / 2 skipped / 0 failed, GENART 6, классификатор 13).

## Найденное по ходу (вне scope смены)

- `openspec/specs/spellbook-icon-sheets/spec.md` (11 требований) описывает конвейер,
  генератор которого (`tools/spellbook_sheets/`, 6 файлов) снят с отслеживания
  `77913c83` и на диске отсутствует. Спека жива, носителя у неё нет.
- Требование «Эталон не переопределяется документацией» карты перечисляет словарь
  статусов (`канон`, `pending`, `не стиль`, `уже в каноне`) уже, чем словарь самой
  карты (`утрачен`, `вытеснен`, `отвергнуто`). Чекер берёт словарь из карты, поэтому
  расхождение не находится.
