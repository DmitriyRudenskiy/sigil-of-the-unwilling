## 1. Снять с отслеживания то, чего уже нет в дереве

- [x] 1.1 `git rm -r --cached image-clone tools` — снять 29 файлов `image-clone/` и 6 файлов `tools/spellbook_sheets/` с отслеживания; содержимое рабочего дерева не трогать (его уже нет)
- [x] 1.2 Убедиться, что `git status` после 1.1 не содержит ` D` по этим путям, а `git ls-files image-clone tools` пуст
- [x] 1.3 Снять с отслеживания два журнала под корневым `artifacts/` (`head_export_gate_2026-11-09.log`, `mcp_smoke_local_2026-11-09.log`); третий (`full_gate_local_2026-11-09.log`) не отслеживается и остаётся на диске

## 2. `.gitignore`: актуализация

- [x] 2.1 Добавить в `.gitignore` корневой `artifacts/` с комментарием «вывод прогонов; в git — числа в задаче, не лог»
- [x] 2.2 Перевести блок `image-clone/` (строки 31–63) на `/game/image-clone/`, перенеся **все** исключения `!…/manifest.json` и `!…/MANIFEST.json` без изменений
- [x] 2.3 Перенести правило `.reserve/` из `.git/info/exclude:9` в `.gitignore` — **в том же коммите**, где удаляется строка из `info/exclude`; проверить, что между правками `git status --porcelain` не показывает 69 каталогов
- [x] 2.4 Добавить `.pytest_cache/` (сейчас закрыт своим авто-`.gitignore`, косметика); `/data/` со строки 2 **оставить** как страховку от повторения
- [x] 2.5 Проверить блок на реальном дереве: `git status --ignored` показывает `game/image-clone/map/shot_transitions.png` как отслеживаемый, а пиксели попыток — как ignored
- [x] 2.6 Убедиться, что правило 2.1 корень-анкоред: `git check-ignore -v game/assets/artifacts/wolf_medallion.png` не даёт совпадения
- [x] 2.7 `git check-ignore -v .reserve` после 2.3 ссылается на `.gitignore`, а не на `.git/info/exclude`

## 3. `doc/` → `docs/`

- [x] 3.1 `git mv doc/SAVE_MATRIX.md docs/save-matrix.md`, `git mv doc/races-economy.md docs/`, `git mv doc/social-mechanics.md docs/`; каталог `doc/` исчезает
- [x] 3.2 Добавить трём файлам frontmatter по конвенции `docs/` (`title`, `tags`, `status: draft|reference`, `date`); wikilinks — без пути
- [x] 3.3 Перевести внутренние ссылки `social-mechanics.md` ↔ `races-economy.md` в форму wikilink без пути
- [x] 3.4 Обновить `scripts/check_save_matrix.py`: `DOC`, `DOC_DIR`, `SEARCH_ROOTS` (строки 35–39) и docstring (строки 2, 7, 13, 14) — адрес `docs/save-matrix.md`
- [x] 3.5 Обновить `scripts/test_check_save_matrix.py` под новый адрес; прогон `python3 -m pytest scripts/test_check_save_matrix.py` зелёный
- [x] 3.6 Обновить адрес в `openspec/specs/save-migration/spec.md` (строка 10) — тем же текстом, что дельта этого change
- [x] 3.7 Прогон `python3 scripts/check_docs_links.py` — зелёный; `python3 scripts/check_save_matrix.py` — зелёный

## 4. `rpg_system.py` → `game/tools/`

- [x] 4.1 `git mv rpg_system.py game/tools/rpg_system.py` (дом — `game/tools/`, где Python-инструменты живут и так; `prototypes/` уходит по группе 5)
- [x] 4.2 Проверить, что `python3 game/tools/rpg_system.py` печатает прогон так же, как до переезда (модуль автономен, `__main__`-симуляция)
- [x] 4.3 Убедиться, что ни одна ссылка в репозитории не осталась битой (`git grep -n rpg_system`)
- [x] 4.4 Убедиться, что `game/tests/smoke/test_compile_all.gd` и `scripts/check_asset_provenance.py` прогоняются с новым файлом без исключений

## 5. Корневой бойлплейт

- [x] 5.1 Перенести три раздела корневого `CHANGELOG.md` (2026-09-27, 2026-09-25, 2026-02-22) в `docs/CHANGELOG.md` — принятый носитель журнала; тексты разделов не переписывать
- [x] 5.2 Проверить перенос: `grep -c '2026-09-25\|2026-02-22' docs/CHANGELOG.md` > 0 **до** удаления файла
- [x] 5.3 `git rm CHANGELOG.md` — только после 5.2
- [x] 5.4 `git rm LICENSE SECURITY.md CODE_OF_CONDUCT.md CONTRIBUTING.md .editorconfig`
- [x] 5.5 **Ничего не удалять и не перемещать внутри `game/`:** `game/assets/fonts/LICENSE.txt` (OFL, шрифты PT) остаётся; проверить `git status` на отсутствие удалений под `game/`
- [x] 5.6 `git rm prototypes/battle-hud/index.html && git rm -r prototypes` — каталог-убежище из дерева уходит
- [x] 5.7 `README.md`: убрать строку 5 (бейдж на `LICENSE`), строку 204 (`CONTRIBUTING.md`), строку 247 (`.editorconfig`), строку 253 (раздел «Лицензия»)
- [x] 5.8 Проверка: `git grep -n -E 'SECURITY\.md|CODE_OF_CONDUCT|CONTRIBUTING\.md|\.editorconfig'` даёт совпадения только в `openspec/changes/archive/` и `battle-demo/`

## 6. Перепривязка ссылок на `game/image-clone/`

- [x] 6.1 `scripts/gen_map_art.py` — docstring (строка 12) и путь сырья (строка 507)
- [x] 6.2 `game/assets/objects/world_map_objects.json`, `world_map_roads.json`, `world_map_threat.json` — поле `source` меняет префикс на `game/image-clone/map/raw/` (51 поле)
- [x] 6.3 `game/run_tests.sh` — путь лаборатории переведён. `test_compile_all.gd` НЕ правится: SKIP сверяет имя каталога верхнего уровня `res://`, а при `--path game` лаборатория остаётся `res://image-clone` — запись уже верная
- [x] 6.4 `AGENTS.md` (строка 205) — НЕ правится: там не путь, а имя сессии в уроке про fast-forward push. Пути в этом файле нет
- [x] 6.5 `game/image-clone/map/shot_transitions.png.import` и `.cells.json` — правки нет: `source_file="res://image-clone/…"` относителен `res://` (= `game/`), а не корня репо, и потому был верен и до переезда. `Godot --headless --path game --import` прошёл DONE, uid `qujelv1ubd2a` сохранён, `.cells.json` путей не содержит
- [x] 6.6 `openspec/specs/image-clone-lab/spec.md` — оставлен дельте: ADDED-требование объявляет blanket-правило «все пути `image-clone/…` разрешаются относительно `game/image-clone/`», оно покрывает строки 589 и 638; `queue.json` в 6.3 не читается (run_tests.sh читает `etalons/manifest.json` — переведён)
- [x] 6.8 **Найдено при верификации:** переезд лаборатории был доделан только наполовину — в `game/image-clone/` лежали три файла `map/`, а `spec.json`, `queue.json`, `docs/` (вердикты, промты, уроки, style card) и манифесты эталонов отсутствовали, из-за чего `test_clone.py` падал на `FileNotFoundError`. 26 файлов, которые `.gitignore` прятать не собирался, восстановлены из индекса (`77913c83~1`) и уложены по адресу `jobloop.LAB`; три игнорируемых остались игнорируемыми. Попутно переведены три ссылки, пропущенные 6.1–6.7 (`test_clone.py` — путь живой спеки, `generate.py` — цитата правила `.gitignore`, `place_campaign_art.py` — `SRC`). Мерка: 191 проверка OK, `test_generate.py` passed

- [x] 6.7 Проверка: `git grep -n -E '(^|[^a-z/])image-clone/'` даёт совпадения только в исторических носителях (`openspec/changes/archive/`, `docs/CHANGELOG.md`, `docs/DECISIONS.md` D-193/D-284, `docs/mvp/TICKETS.md`, акт `docs/reference/map-baseline/review-11-3/REVIEW.md`) и в `openspec/specs/image-clone-lab/spec.md`, который переводит дельта. Критерий расширен DECISIONS/TICKETS/reference: это акты, а не ссылки, и перекраивать их тот же принцип, что и в D3 про `artifacts/`

## 7. Проверка состава корня

- [x] 7.1 `scripts/check_repo_layout.py`: перечень разрешённого корня в самом скрипте; проверки — состав корня, отсутствие отслеживаемых файлов под выводом прогонов, отсутствие `doc/`, `tools/`, `prototypes/` и корневого бойлплейта, отсутствие `.py` в `game/` вне `game/tools/` и `game/tests/`, отсутствие `.gd` в корне проекта Godot, отсутствие правил игнорирования в `.git/info/exclude`
- [x] 7.2 Перечень на старте включает `battle-demo/`, `.reserve/`, `tmp/`, `reference/`, `data/` с явной пометкой «ждёт решения» — иначе первый прогон красится о том, что разрез не трогает
- [x] 7.3 `scripts/test_check_repo_layout.py` — падает на постороннем каталоге в корне, проходит на чистом дереве, **не** срабатывает на `game/assets/artifacts/`, падает на правиле, живущем в `.git/info/exclude`, падает на `.py` в `game/scripts/`, падает на `.gd` в корне `game/`
- [x] 7.4 Подключить в `scripts/ci2_checkers.sh` рядом с остальными `check_*.py`; проверить, что `bash scripts/ci2_checkers.sh` зелёный на текущем дереве после 1–6
  Итог подключения: checker 7 рядом с 1–6; `bash scripts/ci2_checkers.sh` — GREEN
  (первый раз: checker 1 был красен из-за `.uid`-сирот, checker 3 — из-за линеек
  из `=` в снятых логах прогонов под `docs/mvp/matrix/`; второе снято исключение
  пути в самом чекере, настоящих маркеров `<<<<<<<`/`>>>>>>>` в репо ноль).
  Тест добавлен в `TESTS` гейта `doc_gates.sh` (17 файлов → 18).

## 8. Документация структуры

- [x] 8.1 `README.md` § «Структура проекта» — привести перечень к фактическому корню: `game/`, `docs/`, `scripts/`, `openspec/`, `reference/`, `.pi/`, `tmp/`; убрать строки про удалённые носители
- [x] 8.2 `README.md` — описать `.pi/` (промпты `/opsx-*`, единственный навык `ui-grid-review`) наравне с прочими носителями
- [x] 8.3 `docs/DECISIONS.md` — запись о переездах (`doc/`→`docs/`, `image-clone/`→`game/image-clone/`, `rpg_system.py`→`game/tools/`, генераторы `ui_kit`→`game/tools/ui_kit/`, `dbg_stats.gd`→`game/tools/`), об удалении корневого бойлплейта, о сокращении `.pi/skills/` и о том, что вывод прогонов в дерево не попадает
- [x] 8.4 `docs/QUESTIONS.md` — новый Q-M## под решение о судьбе `battle-demo/` (следующий свободный номер после Q-M138; пометку AGENTS.md «занято до Q-M101» не читать как факт — реестр идёт дальше)
- [x] 8.5 `docs/CHANGELOG.md` — запись по конвенции журнала: что, почему так, чем измерено (176/176 md5, 0 расхождений; 0 отслеживаемых файлов в `data/`; 45 снимаемых курсоров; две сгнившие записи провенанса)
  Итог: README § «Структура проекта» переписан целиком (старое дерево описывало
  `game/` построчно и содержало оборванный уровень отступов на `tilesets/`, а таблица
  «Открытые изменения» звала три изменения, два из которых заархивированы); `.pi/`
  описан в том же дереве, чем он и является — промпты `/opsx-*` плюс один навык.
  D-317 покрывает переезды, бойлплейт, `.pi/skills/` и вывод прогонов; Q-M139 заведён
  под `battle-demo/` (реестр дошёл до Q-M138, пометка AGENTS.md устарела). Запись
  журнала — первой секцией, с меркой и с тем, что осталось владельцу.

## 9. `data/` — расчистка диска (исполняется последним из всех шагов; не откатывается через git)

- [x] 9.1 Убедиться, что `git ls-files data | wc -l` = 0 и `git check-ignore data` подтверждает правило — в git этот шаг не входит ни при каком исходе
- [x] 9.2 `lsof +D data` пустой; живой `openviking-server` держит хранилище в `cwd` процесса (`run_bowser/data/`), а не здесь — проверить, что это всё ещё так
- [x] 9.3 `rm -rf data` — только после 9.1 и 9.2 и только после того, как группы 1–8 и 10–14 зелёные
- [x] 9.4 Правило `/data/` в `.gitignore` не удалять: оно страхует повторение
  Исполнено последним, после зелёных 1–8 и 10–14. Мерка перед `rm -rf`:
  `git ls-files data` = 0; `git check-ignore -v data` → `.gitignore:2:/data/`;
  `lsof +D data` пуст; `lsof` процесса `openviking-server` (PID 867, порт 1933)
  держит только `/Users/user/run_bowser/data/` — живой сервер живёт в своём `cwd`,
  а репозиторный каталог осиротел с того запуска, когда сервер стартовал из репозитория.
  Последняя реальная запись — 2026-11-05 15:00 (`_system/usage_audit/usage_audit.sqlite3`),
  после него трогались только `.DS_Store` от Finder. Снято 2715 файлов / 101 МБ
  (`viking/` 92 МБ, `_system/` 4,7 МБ, `vectordb/` 2,6 МБ); пофайловый список —
  `/tmp/sotu-data-files.txt` (до перезагрузки машины). Правило `/data/` оставлено.

## 10. Мусор внутри `scripts/`

- [x] 10.1 `git rm -r --cached scripts/concept_art/concept_art` — 45 отслеживаемых сгенерированных курсоров, ноль ссылок; живые курсоры (`game/assets/cursors/*.png`, 12 файлов) не затронуты, проверить счётчик до и после
- [x] 10.2 Добавить в `.gitignore` (сделано в 2.2: правило легло до снятия файлов, щель закрыта первой) правило на удвоенный путь `scripts/concept_art/concept_art/` — строка 29 закрывает только корневой `/concept_art/`, и именно через эту щель носитель попал в индекс
- [x] 10.3 `git rm scripts/concept_art/spec_copy.json scripts/concept_art/spec_copy{2,3,4,5,6}.json` — шесть неиспользуемых копий; **`spec_copy48.json` остаётся** (его читает `jobloop.py:398`)
- [x] 10.4 `git rm scripts/split_02f.py` — одноразовая миграция `docs/02f-social.md`, уже исполненная, ноль ссылок
- [x] 10.5 **Не трогать:** `scripts/hero_anim/out/**/picked.json` (`.gitignore:71` прямо объясняет, что в git попадает вердикт выбора варианта), `scripts/concept_art/etalons_*/` (живые: `game/assets/ui/campaign_screen/MANIFEST.json`, `game/assets/PROVENANCE.md`), `scripts/concept_art/test_clone.py` (906 строк assert-ов — живой самотест лаборатории, не обвязанный в `doc_gates.sh`, а не мусор)
- [x] 10.6 `game/tools/probe_road_art.gd` — заведён с `.uid` и починен: `src.get_atlas_texture()` не существует в Godot 4.7, взят `src.texture`. Зонд заработал и сразу выдал предмет охоты: у листов дорог и объектов `region=(82,82)` при `tile_size=(82,95)`. Оставлять untracked-файл значило оставить его без носителя — его не было в git вовсе
- [x] 10.7 Добавить в `.gitignore` `game/user/` (сделано в 2.3) — каталог `user://` пуст сейчас и появится при первом запуске, а правила нет

## 11. `.pi/skills/`: остаётся один навык

- [x] 11.1 `git rm -r .pi/skills/changelog .pi/skills/content-audit .pi/skills/create-epics .pi/skills/loop-me .pi/skills/verification-before-completion`; `ui-grid-review` остаётся
- [x] 11.2 `docs/19-gdd-workflow.md` — убрать вызовы удалённых навыков: шаг 1 (`content-audit`), шаг 3 (`loop-me`), шаг 4 (`create-epics`, `changelog`), раздел финализации (`verification-before-completion`) и строки таблицы 104. Иначе документ опишет процесс с пятью отсутствующими носителями
- [x] 11.3 Правки 11.1 и 11.2 — **одним коммитом**; проверить `git grep -n 'навык\|\.pi/skills' docs/19-gdd-workflow.md`
- [x] 11.4 Промпты `.pi/prompts/opsx-*.md` и `.pi/todos/` не трогать — они не в списке
- [x] 11.5 Фикс инструмента оставшегося навыка: `scripts/ui_diff.py` строка 55 — `%%` в help-строке `--min-change`. Сейчас `python3 scripts/ui_diff.py --help` падает (`ValueError: unsupported format character`), той же веткой `p.error()` падает и на `--cols 0`. Проверка: `--help` и `--cols 0` печатают usage, а не traceback
- [x] 11.6 Регрессия навыка после разреза: `ui_grid.py --self-check`, `ui_grid.py` на `reference/12_inventory_parchment_sheet.jpeg`, `ui_grid.py --cell D5 --zoom 3`, `ui_diff.py --before --after --cell`, `Godot --path game --script tools/ui_dump.gd -- --scene=res://scenes/ui/artifact_inventory_screen.tscn --cell=D5` — все пять шагов должны отработать как в замерах этого change (15 узлов D5, тронутые A1,C1,A2,C2,A3,C3)

## 12. `game/report.sh` и сиротство D-138

- [x] 12.1 `git rm game/report.sh`
- [x] 12.2 `docs/DECISIONS.md` — запись, что **D-138 остаётся правилом** («ни одно число в отчёте не пишется по памяти»), но перестал быть автоматизированным: блоки отчёта собираются командами вручную, метод счёта тестов — `grep -c 'func test_'` по `game/tests`. Без этой строки реестр продолжит ссылаться на несуществующий носитель
- [x] 12.3 `AGENTS.md:446` — убрать упоминание `game/report.sh`-блока под флагом `ENABLE_CI_WAIT` (сам запрет CI-поллинга остаётся в силе)
- [x] 12.4 Архивные упоминания не переписывать (D3): `docs/CHANGELOG.md`, `docs/mvp/TICKETS.md:551`, `docs/mvp/TEST-MAP.md:707`, `game/run_tests.sh:131` — исторические цитаты; проверить, что `git grep -n report\.sh` даёт совпадения только там

## 13. `game/dbg_stats.gd` → `game/tools/`

- [x] 13.1 `git mv game/dbg_stats.gd game/tools/dbg_stats.gd` и `git mv game/dbg_stats.gd.uid game/tools/dbg_stats.gd.uid` — парой, иначе checker 1 `ci2_checkers.sh` краснеет на `.gd` без `.uid`
- [x] 13.2 `game/tests/smoke/test_compile_all.gd` строка 26 — комментарий перечисляет файл по имени («scripts 418 + scenes 2 + dbg_stats.gd», всего 421); после переезда счётчик 420, `MIN_COMPILED := 400` цел. Комментарий правится в том же коммите
- [x] 13.3 Осознанное последствие: `tools` входит в `SKIP` этого теста, то есть файл перестаёт компилироваться гейтом. Для 15-строчной диагностики без загрузчиков это согласовано с соседями (`diag_*.gd`, `map_shot.gd`) и фиксируется здесь, а не остаётся незамеченным
- [x] 13.4 Прогон `test_compile_all.gd` зелёный после переезда
- [x] 13.5 Проверка: `git ls-files game | grep -E '^game/[^/]+\.gd$'` пуст — в корне проекта Godot больше нет скриптов

## 14. Генераторы ассетов: один дом, живой провенанс

- [x] 14.1 Слить два дома генераторов `game/assets/**` в один: `game/scripts/ui_kit/{build_mana_bar,build_round_button}.py` и `scripts/ui_kit/*.py` (6 файлов) → `game/tools/ui_kit/`. `game/scripts/ui_kit/` был единственным Python внутри `res://scripts/`
- [x] 14.2 `game/assets/PROVENANCE.md` — обновить пути `scripts/ui_kit/*.py` и `game/scripts/ui_kit/*.py` на новый
- [x] 14.3 `game/assets/ui/widgets/MANIFEST.json` — поле `"generator": "scripts/ui_kit/build_round_button.py"` ведёт в несуществующий путь (файл жил в `game/scripts/ui_kit/`); поправить на новый
- [x] 14.4 `game/assets/PROVENANCE.md` объявляет `game/tools/recolor_button_textures.py` — **файла нет**. Уточнение при исполнении: он **существовал** и был снят шагом `f4de4cf3` («Шаг 4 ui-mockup-parity») по AC6 билета ASSET-2; `git log --diff-filter=D` пустел из-за того, что искался путь без `--all`. Запись переписана: имя без слэша + явная пометка «снят f4de4cf3», заодно выправлена живая ссылка в `docs/17-ui-style-guide.md`
- [x] 14.5 `scripts/check_asset_provenance.py` — проверка «путь генератора из `PROVENANCE.md` / `MANIFEST.json` существует в индексе»; сейчас проверяется наличие строки, из-за чего обе сгнившие записи проходили гейт как хорошие. Правило: backtick-путь **со слэшем** и поле `generator`, похожее на путь, — обязаны быть в `git ls-files`; имя без слэша (`+ gen_building_icons2.gd`) и внешний инструмент (`krea2 (ComfyUI)`) — не пути
- [x] 14.6 Тест на новую проверку: падает на вымышленном пути генератора, проходит на дереве после 14.2–14.4 (`scripts/test_check_asset_provenance.py`, 4 теста + самопроверка чекера)
- [x] 14.7 Перепривязать вызовы: `scripts/doc_gates.sh`, `game/assets/ui/*/MANIFEST.json`; проверить `git grep -n 'ui_kit/'` на отсутствие старых путей вне архива и исторических цитат. Итог: 65 ссылок в 18 файлах + `docs/18-system-map.md` (каталог упразднён); `doc_gates.sh` генераторы не вызывал; исторические цитаты (`docs/CHANGELOG.md`, `docs/mvp/**`, архив) не тронуты

## 15. Верификация

- [x] 15.1 `python3 scripts/check_docs_links.py` — зелёный
- [x] 15.2 `python3 scripts/check_save_matrix.py` — зелёный
- [x] 15.3 `python3 scripts/check_repo_layout.py` — зелёный
- [x] 15.4 `python3 scripts/check_asset_provenance.py` — зелёный, включая новую проверку путей генераторов
- [x] 15.5 `bash scripts/doc_gates.sh` — зелёный: он вызывает 35 скриптов по пути и потому является главным регресс-тестом переездов `ui_kit`
- [x] 15.6 `bash game/run_tests.sh` — полный набор, 0 failures / 0 errors / 0 orphans
- [x] 15.7 `openspec validate repo-structure-cleanup --type change --strict` — valid
- [x] 15.8 `git status` чист; `git ls-files artifacts tools doc image-clone prototypes data scripts/concept_art/concept_art` пуст; `git ls-files game/assets/artifacts | wc -l` = 120, как в `e7af3b70`
- [x] 15.9 `git ls-files game/assets/fonts/LICENSE.txt` непустой; `git ls-files LICENSE SECURITY.md CODE_OF_CONDUCT.md CONTRIBUTING.md .editorconfig CHANGELOG.md game/report.sh scripts/split_02f.py` пуст
- [x] 15.10 `grep -c '2026-09-25' docs/CHANGELOG.md` > 0 — перенесённый журнал пережил удаление файла
- [x] 15.11 `git ls-files .pi/skills` даёт ровно `ui-grid-review/SKILL.md`; `git ls-files .pi/prompts | wc -l` = 6 (промпты не затронуты)
- [x] 15.12 `git ls-files game | grep -E '^game/[^/]+\.(gd|py)$'` пуст; `git ls-files game | grep '\.py$' | grep -vE '^game/(tools|tests)/'` пуст
- [x] 15.13 `git ls-files game/assets/cursors | wc -l` = 12 — живые курсоры не задеты группой 10
- [x] 15.14 `python3 scripts/ui_diff.py --help` печатает usage, а не traceback — оставшийся навык обязан быть исправен
Итог верификации (2026-11-09). Зелёные: 15.1 (132 заметки), 15.2, 15.3
(14 носителей), 15.4 (993 строки реестра), 15.7 (`Change 'repo-structure-cleanup'
is valid`), 15.6 — `GATE VERDICT: GREEN`: 3694 тест-кейса, 0 errors / 0 failures /
0 orphans, TIER COVERAGE 394/394, MCP 123 passed / 2 skipped (причины обязательны:
нет узлов городов в сцене боя; съёмка по запросу), READINESS-CLASSIFIER GREEN,
`PUSH: OK`. Мерка 15.8–15.14 совпала целиком: снятые пути пусты,
`game/assets/artifacts` = 120 как в `e7af3b70`, бойлплейт отсутствует,
`game/assets/fonts/LICENSE.txt` на месте, `2026-09-25` в журнале пережил удаление
файла, `.pi/skills` = один `ui-grid-review/SKILL.md` при шести промптах, в корне
`game/` ни `.gd`, ни `.py`, Python только в `tools/` и `tests/`, живых курсоров 12,
`ui_diff.py --help` печатает usage.

Два красных в 15.5 (`doc_gates.sh`) — не этого разреза, сверено с worktree на
`77913c83~1`: (а) рэтчет `testmap` `merge_files 146 → 148 (+2)` — те же числа до
разреза; (б) `audit_docs_vs_code` — семь ссылок доков на `scenes/archive/world.tscn`
(носитель снят катом D-157, доки не сведены), `ProbeGlyphLayer` (класс добавлен
`5671d941`, чужая сессия), устаревший allowlist `CampaignCity` и базлайн
`adventure_hud.tscn`. До разреза аудит показывал девять строк
`doc_ref`, осталось семь; сами четыре предмета относятся к архиву мира и к чужой
инициативе — править их здесь значит перелезть через чужой незавершённый свод.

Попутно, потому что без этого 15.6 не исполняется: `game/run_tests.sh` был мёртв
для любого вызова из чистого окружения (`set -u` + голая ссылка `$MCP_SSH_HOST`
до `source` настроек машины, живёт с `f375146d`), и GENART-секция роняла вывод
лаборатории в `game/concept_art/`. Оба сняты `3b899c9b`.
