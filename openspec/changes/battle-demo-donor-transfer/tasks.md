## 1. Блокатор: чем на самом деле зависит конвейер

> Пройден 2026-11-09 и **остановил перенос**: зависимости оказались больше, чем
> принято в design.md. Факты в конце группы.

- [x] 1.1 `grep -n '\.py' battle-demo/tools/*.gd battle-demo/tools/*.tscn` — убедиться, что `.gd`-инструменты не дёргают переносимый Python; если дёргают — остановиться и зафиксировать, что именно зависит
- [x] 1.2 `grep -rn 'tools/[a-z_]*\.py' battle-demo --include='*.gd' --include='*.tscn' --include='*.md' --include='*.sh'` — выписать полный список ссылок на переносимые файлы (включая `run_tests.sh` стенда и его `docs/`)
- [x] 1.3 Проверить, что ни один из 17 `.py` не импортирует то, что остаётся в стенде (кроме взаимных импортов самого пакета) — `grep -hn '^import \|^from ' battle-demo/tools/*.py`
- [x] 1.4 Сверить `tools/spec.json` и `tools/workflows/` с `scripts/concept_art/spec.json`: чем отличаются, нет ли общей части, которую нельзя разорвать

Найденное (2026-11-09), опровергает design.md «правка путей не требуется»:

1. **Пути разрешаются тремя разными способами.** `ROOT = parents[1]` у
   `audit_sprites.py`, `build_sprite_frames.py`, `gen_contact_sheet.py` даёт корень
   **стенда**; `comfy.py` берёт `parents[2]` — корень **репозитория**;
   `ui_read_judge.py` — `parent.parent`. После переезда в `scripts/character_kit/`
   первые начнут молча писать в `scripts/`. Строка `"battle-demo"` зашита в 12+ местах
   (`mirror_anim.py`, `gen_kit.py`, `gen_beast.py`, `gen_log.py`, …).
2. **Конвейер работает деревом стенда.** Читает/пишет `battle-demo/assets/{a_pose,
   a_pose_v2,beasts,kit,poses}` и `battle-demo/artifacts/{generation-manifest,
   verdicts,clip-manifest,sprite-plan,sprite-audit}.json`. Без этого дерева он не
   запускается, то есть требование «кадр собирается без стенда» переносом одних
   `.py` не выполняется.
3. **Рабочие кадры не в git.** `assets/a_pose` — 0 файлов в индексе при 2,6 МБ на
   диске, `assets/kit` — 0 при 21 МБ, `a_pose_v2` — 2, `beasts` — 2. Единственный
   экземпляр в рабочем дереве — тот же класс риска, из-за которого из дерева уже
   вынесли стиль-референсы (D-192).
4. **Связь идёт и в обратную сторону:** `gen_beast.py:32` делает
   `sys.path.insert(0, <корень>/scripts/concept_art)` — инструмент стенда уже
   зависит от конвейера основного проекта через хак пути.
5. `tools/spec.json` и `scripts/concept_art/spec.json` общие имеют только `comfy`
   (адрес сервера): графы непересекающиеся, рвать нечего; `comfy.py` читает
   `spec.json` рядом с собой, значит файл обязан ехать вместе с ним.
6. `build_sprite_frames.gd` (остаётся в стенде) требует план, который пишет
   переносимый `build_sprite_frames.py` (`artifacts/sprite-plan.json`) — вызова нет,
   есть рукопожатие файлом через границу переноса.

## 2. Перенос

- [x] 2.1 `scripts/character_kit/`: `git mv` 17 файлов `battle-demo/tools/*.py`, `spec.json`, `workflows/`
- [x] 2.2 `git mv` входные носители: `assets/poses` → `poses/`, `assets/portraits` → `portraits/`, `assets/reference` → `reference/`, `assets/a_pose_v2` → `a_pose_v2/`, `assets/beasts` → `beasts/`
- [x] 2.3 `git mv` запись прогонов: `battle-demo/artifacts/*.{json,md}` и отчётные `jpg` → `scripts/character_kit/runs/`
- [x] 2.4 `paths.py` пакета: `REPO`/`KIT`/`OUT`/`STAND`; в 17 файлах убрать `parents[N]` и зашитое `"battle-demo"` (список — в группе 1)
- [x] 2.5 Вывод (вне git: `a_pose`, `kit`, `clips`, `clips-apose`, `clips-mirror`, `gen`, `mirror-src`, `screenshots`, `frames`) — `mv` в `<корень>/character_kit/` + правило `.gitignore` с комментарием по образу `/concept_art/`
- [x] 2.6 `python3 -c "import …"` каждым модулем пакета из корня репо; в `battle-demo/tools/` не осталось `.py`

## 3. Переадресация ссылок

- [x] 3.1 Ссылки внутри `battle-demo/` (из 1.2) — на `scripts/character_kit/…`, с явной пометкой, что инструмент больше не часть стенда
- [x] 3.2 Сообщение `build_sprite_frames.gd` об отсутствующем плане — на новый путь запуска; путь плана читается так, чтобы `.gd` и `.py` сходились в одном месте
- [x] 3.3 Живые спеки: дельта этой смены правит `battle-demo-sprites` (`dwpose-cli.py` → `scripts/character_kit/dwpose_cli.py`, `tools/gen_frames.py` → `scripts/character_kit/gen_frames.py`); проверить, что больше путей стенда в `openspec/specs/` не осталось
- [x] 3.4 `docs/mvp/HERO-ANIM.md`, `docs/18-system-map.md`, `README.md`, `game/assets/PROVENANCE.md` — где инструмент назван носителем, новый путь; исторические акты и архивные смены не трогать
- [x] 3.5 `grep -rn 'tools/gen_\|tools/comfy\|tools/build_sprite_frames\|tools/audit_sprites\|tools/ui_read_judge' --include='*.md' --include='*.py' --include='*.gd' .` — ноль живых ссылок на старый путь

## 4. Воспроизводимость

- [x] 4.1 `scripts/character_kit/README.md`: назначение, чем отличается от `scripts/concept_art/`, команда прогона из корня, где лежит вывод
- [x] 4.2 Паспорт `dwpose`: источник, версия, команда установки, пометка «на свежем клоне невоспроизводимо» — и та же пометка в шапке `dwpose_cli.py`
- [x] 4.3 Остальные внешние зависимости (Pillow, HTTP-клиент ComfyUI, `ffmpeg`/`ffprobe`) — каждая либо штатная, либо в README
- [x] 4.4 Один прогон шага на синтетическом входе (без сервера генерации): не проходит — зафиксировать фактическое состояние как результат смены, а не как «сделано»

## 5. Приёмка конвейера

- [x] 5.1 `scripts/character_kit/test_character_kit.py` — один self-check: путь пакета не указывает в стенд, приёмка на заведомо сломанном входе возвращает `fail` с причиной
- [x] 5.2 Подключить self-check туда же, где запускаются остальные `scripts/test_*.py` (`scripts/doc_gates.sh`, шаг «тесты самих проверщиков»)
- [x] 5.3 «Инструмент не живёт в двух домах»: `git ls-files | grep -c 'build_sprite_frames\|audit_sprites\|ui_read_judge'` — по одному носителю на инструмент

## 6. Документы и решение владельца

- [x] 6.1 `docs/QUESTIONS.md`: Q-M139 остаётся открытым, в фактах — «единственный носитель конвейера больше не стенд»; вариант (в) дорожает/дешевеет ровно на это
- [x] 6.2 `docs/DECISIONS.md`: новая запись о переносе (обязательная секция «Отвергнутые», иначе `gdd_gate.py` краснеет) — чем дом выбран, почему боевая модель не переехала
- [x] 6.3 `docs/CHANGELOG.md` — запись разреза
- [x] 6.4 `python3 scripts/gen_docs_index.py` — индекс документации
- [x] 6.5 Проверить, что `README.md` § «Структура проекта» описывает и `scripts/character_kit/`, и оставшуюся роль стенда

## 7. Измерение

- [x] 7.1 `python3 scripts/check_repo_layout.py` — состав корня не изменился (стенд на месте), Python в принятом доме
- [x] 7.2 `python3 scripts/check_docs_links.py` и `bash scripts/doc_gates.sh` — только две прежние находки (docs↔code, testmap), новых нет
- [x] 7.3 `python3 scripts/gdd_gate.py` — GREEN, `d_without_rejected` не вырос
- [x] 7.4 `openspec validate battle-demo-donor-transfer --strict`, затем `openspec validate --all --strict` — тех же шесть прежних падений
- [x] 7.5 `bash scripts/ci2_checkers.sh` — GREEN
- [x] 7.6 `MCP_SSH_HOST= game/run_tests.sh` — GREEN (перенос в `game/` не заходит, но гейт обязан остаться зелёным)
- [x] 7.7 Коммит точечным `git add` (не `-A`): перенос, ссылки, документы — одним коммитом, чтобы в истории не осталось состояния «оригинал удалён, ссылки в пустоту»


---

## Измеренное (2026-11-09)

- Перенесено `git mv`: 18 файлов кода (17 `.py` + `comfy_check.sh`), `workflows/`,
  `spec.json`, `poses/` (224), `a_pose_v2/`, `beasts/`, запись прогонов в `runs/`
  (манифесты, вердикты, аудиты, 10 логов, реестр прогонов, 4 отчёта приёмки UI,
  23 пофайловых отчёта клипов) — всего 311 файлов в индексе, 16 МБ.
- Вывод (1,7 ГБ: `clips` 814 МБ, `clips-apose` 784 МБ, `gen` 135 МБ, `kit`,
  `a_pose`, `clips-mirror`, `mirror-src`, `screenshots`) уехал `mv` на том же томе
  в `character_kit/` и закрыт `.gitignore`; `character_kit` добавлен в
  `OUTPUT_DIRS` сверщика корня. Стенд: 1,9 ГБ → 153 МБ.
- 31 untracked `.import`-файл в перенесённых носителях удалён: метаданные импорта
  Godot для файлов, которые больше не лежат в Godot-проекте.
- Все 17 модулей импортируются из корня репо (`dwpose` 1.0.1 на машине есть, веса
  `yolx_l.onnx`/`dw-ll_ucoco_384.onnx` лежат в его `ckpts/`). Паспорт зависимости
  записан в README пакета; закладку design.md «невоспроизводимо» она снимает:
  зависимость не объявлена ни в одном манифесте, но ставится `pip install`.
- Генеративные шаги (ComfyUI 192.168.0.230:8188) в этой смене не гонялись: сервер
  чужой, оплаченных GPU-сессий не заказывали. Проверено на синтетике: приёмка
  ломаного клипа даёт «брак» с причиной, чистый кадр не бракуется, пути пакета не
  смотрят в стенд мимо `paths.STAND`, вывод закрыт `.gitignore`.
- Гейты: `check_repo_layout` — «корень в перечне (13 носителей), вывод прогонов
  пуст»; `check_docs_links` — OK (135 заметок); `doc_gates.sh` — те же две прежние
  находки (docs↔code, testmap 146→148), новых нет; `gdd_gate.py` — GREEN;
  `openspec validate --all --strict` — 89/6 (те же шесть); `ci2_checkers.sh` —
  GREEN; `MCP_SSH_HOST= game/run_tests.sh` — `GATE VERDICT: GREEN`
  (123 passed / 2 skipped / 0 failed).
- Попутно снят с диска `game/concept_art/` (90 файлов, gitignored): прогон
  генератора с `cwd = game/` положил копию корневого вывода в `res://`, из-за чего
  `test_compile_all` падал на «каталог верхнего уровня не описан в SCAN/SKIP».
  45 файлов побайтово совпадают с `concept_art/`, остальное — `.import`-метаданные.
  Та же щель и та же санкция, что описаны в `.gitignore` (строка про
  `/game/concept_art/`).
