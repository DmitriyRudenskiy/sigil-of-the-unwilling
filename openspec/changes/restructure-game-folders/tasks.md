# Tasks: restructure-game-folders

См. design.md: порядок «сначала файлы → потом ссылки → потом кэш» (D8),
таблица подстановки (D6), autoload-состав (D3).

## 1. Базовая линия (до прикосновений к дереву)

- [x] 1.1 Прогнать полный CI: (5/5 passed, exit 0, лог: tmp/ci_baseline.log) `bash tools/shell/run_all_ci_checks.sh`
      (под `sleep+kill`-таймаутом, правило 8.1). Записать результат в лог
      (compile ok / проверки / тесты) как базовую линию; если что-то
      красное ДО миграции — зафиксировать список для отличия от регрессии.

## 2. Перемещение файлов (git mv, история сохраняется)

- [x] 2.1 `mkdir -p scripts` и `git mv` девяти доменных папок (88 rename; data/world — по файлам, т.к. в них есть предсуществующие D-файлы; untracked `.uid`/`hex_autotiler.gd`/`tile_atlas.gd` — обычным mv) в `scripts/`:
      `core systems entities world city ui economy demographics data`
      (вместе с `.uid`, подпапками `ui/components/`).
- [x] 2.2 Создать `scripts/autoload/` (10 .gd + .uid; `.uid` в core/data/entities не отслеживались — `mv`) и `git mv` туда 10 синглтонов:
      `core/{SoundManager,Settings,GameEventBus,SocketController}.gd`,
      `data/{SpellbookRegistry,TemplateBootstrap,ArtifactRegistry,SpellRegistry,ResourceRegistry}.gd`,
      `entities/UnitRegistry.gd` (плюс их `.uid`).
- [x] 2.3 `mkdir -p assets/data assets/settings`; (`default_bus_layout.tres` оказался untracked — `mv`, не `git mv`)
      `git mv data/spells.json data/spells.schema.json → assets/data/`,
      `git mv default_bus_layout.tres → assets/settings/`.
- [x] 2.4 `git mv` dev-материалов (D1) в корень репозитория: (.import-файлы backup_assets уехали вместе с каталогом)
      `game/prototype` → `./prototype`, `game/lair` → `./lair`,
      `game/backup_assets` → `./backup_assets`.
- [x] 2.5 Создать корневой `tmp/` (проверено: `git add -n tmp/` → только `tmp/.gitignore`; `git check-ignore`: содержимое игнорируется. Пустого `game/tmp/` на диске не оказалось — был вложенный `game/game/tmp`, убран вместе с `game/game/`) — директорию для временных/черновых
      файлов (D1): `tmp/.gitignore` с правилами `*` и `!.gitignore`
      (маркер, чтобы директория закоммитилась, содержимое — игнорируется);
      в корневом `.gitignore` заменить `tmp/` на `tmp/*` + `!tmp/.gitignore`;
      удалить пустой `game/tmp/`. Проверка: `git status` видит
      `tmp/.gitignore`, а файл `tmp/whatever` — не видит.
- [x] 2.6 Удалить пустые исходные каталоги (корень `game/`: project.godot, icon.svg, README.md, assets/, scenes/, scripts/, tests/, tools/ — ровно целевой состав; `game/game/` удалён) (`core systems entities world
      city ui economy demographics data`) и пустой `game/game/`;
      убедиться, что в корне `game/` остались только: `project.godot`,
      `icon.svg` (+`.import`), `README.md`, `assets/`, `scenes/`, `scripts/`,
      `tests/`, `tools/`, `.godot/`.

## 3. Обновление ссылок

- [x] 3.1 Применить ordered-подстановку (116 файлов; grep-свип: 0 совпадений на все три проверки) (правила D6, порядок 1→8) по
      `game/**/*.{gd,tscn,tres}` + `tools/**/*.{gd,py,sh}`: autoload-
      исключения (правила 1–3) ДО генерики (4–6), json → `assets/data/`,
      tres → `assets/settings/`. После — grep-свип:
      `grep -rnE 'res://(core|systems|entities|world|city|ui|economy|demographics)/' game/`
      и `grep -rn 'res://data/' game/ | grep -v 'res://assets/data/'` и
      `grep -rn 'res://default_bus_layout' game/ | grep -v assets/settings`
      дают 0 совпадений.
- [x] 3.2 Точечно поправить `game/project.godot`: 10 строк `[autoload]` →
      `res://scripts/autoload/…`, `audio/buses` →
      `res://assets/settings/default_bus_layout.tres`; `run/main_scene` и
      `config/icon` не менять.
- [x] 3.3 Проверить `.tscn` (4 ext_resource → res://scripts/…) (4 `ext_resource` в scenes/): пути скриптов
      `res://systems/BattleController.gd`, `res://ui/MainMenu.gd`,
      `res://world/CityArenaView.gd`, `res://world/WorldController.gd` →
      `res://scripts/…`.
- [x] 3.4 Обновить документацию (AGENT.md — новое дерево + правила корневой tmp/; game/README.md — «Состав»; root README.md; docs/** — 27 файлов, ordered-подстановка с защитой от .md-ссылок) с путями: `AGENT.md` (раздел 1 «Структура
      проекта» — новое дерево: в `game/` только игра + `tests/` + `tools/`,
      dev-материалы (`prototype/`, `lair/`, `backup_assets/`) — в корне
      репозитория, scratch — корневой `tmp/`: в правилах зафиксировать, что
      это директория для временных/черновых файлов (закоммичена через
      `.gitignore`-маркер, содержимое игнорируется; вместо `game/tmp/`);
      уточнить self-contained-
      формулировку; раздел 5 — правила организации, раздел 8 — примеры
      команд с новыми путями), `game/README.md` (раздел «Состав»),
      `docs/**` (grep по старым префиксам `game/core/`, `res://core/`,
      `game/lair/`, `game/backup_assets/` и т.п.).

## 4. Кэш и верификация

- [x] 4.1 `rm -rf game/.godot` (обязательно после перемещений, правило 6).
- [x] 4.2 Прогнать полный CI (5/5, exit 0, лог tmp/ci_after_restructure.log). Найден баг Godot 4.7: `-s`-режим сбрасывает AudioBusLayout из подпапки до дефолта (только Master) → фикс в tests/run_tests.gd: пере-применение layout из audio/buses, если шин нет (game-режим не затронут, проверено).: `bash tools/shell/run_all_ci_checks.sh` —
      compile_all: 0 errors, check_scene_refs ok, card_validation ok,
      check_tileset ok, тесты: 0 failed. При ошибках — точечные доправки
      ссылок и повтор (кэш не трогать между повторами).
- [x] 4.3 Smoke headless (MainMenu: 0 SCRIPT ERROR, exit 0; World: 0 SCRIPT ERROR, exit 0; autoloads грузятся, шин Music/SFX на месте) с `--autoquit` + таймаут-обёрткой (по 40–60 с):
      `--scene scenes/MainMenu.tscn` и `--scene scenes/World.tscn`; в логе —
      загрузка всех 10 autoloads без SCRIPT ERROR, сцена дошла до
      autoquit/штатного завершения.
- [x] 4.4 Финальный grep-свип (все проверки: 0 совпадений — old res:// домены, res://data/, старый bus layout, game/<domain>, game/prototype|lair|backup_assets, game/tmp|docs; двойных префиксов нет) по всему репозиторию (включая `docs/`,
      `AGENT.md`, `openspec/` исключая сам change): ноль ссылок на
      устаревшие пути `res://core|systems|entities|world|city|ui|economy|demographics|data`
      (без `scripts/`/`assets/` префиксов) и `game/core/` и т.п.; ноль
      ссылок на `game/prototype`, `game/lair`, `game/backup_assets`.

## 5. Фиксация

- [ ] 5.1 Один коммит: структура + ссылки + доки (message: «Restructure
      game/ to Godot Docs layout: scripts/ (+autoload/), assets/data,
      assets/settings»). Чужие dirty-файлы (410 D docs, 44 ??) в коммит не
      включать.
- [ ] 5.2 После коммита: быстрый `run_all_ci_checks.sh --fast` для
      подтверждения зелёного состояния закоммиченного дерева.
