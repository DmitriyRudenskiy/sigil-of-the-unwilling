# Design: restructure-game-folders

## Context

См. proposal.md (Why). Фактическое состояние `game/` на момент работы:

- Код в 9 доменных папках в корне: `core/` (22 `.gd`), `systems/` (11),
  `entities/` (15), `world/` (32), `city/` (13), `ui/` (20, есть
  `ui/components/`), `economy/` (3), `demographics/` (5), `data/` (20 `.gd` +
  2 `.json`).
- `scenes/` — 4 `.tscn` (MainMenu, World, Battle, CityArena);
  `assets/` — уже каноничная папка ресурсов (artifacts, audio, cursors, raw,
  tiles, ui).
- `default_bus_layout.tres` и `icon.svg` в корне; пустые `game/game/`,
  `game/tmp/`.
- `project.godot`: `run/main_scene="res://scenes/MainMenu.tscn"`,
  `audio/buses="res://default_bus_layout.tres"`, 10 записей `[autoload]`
  (SoundManager, Settings, GameEventBus, SocketController — из `core/`;
  Spellbook, TemplateBootstrap, Artifacts, Spells, Resources — из `data/`;
  Units — из `entities/`).
- Ссылки: ~453 `res://`-ссылки в `.gd`, 4 `ext_resource` в `.tscn`,
  пути в `tools/` (`.gd`/`.sh`/`.py`). Динамически склеиваемых `res://`
  путей на переезжающие папки **нет** (единственный динамический префикс —
  `"res://tools/"`, он остаётся на месте). Все ссылки — статические строки.
- ~90+ классов зарегистрированы через `class_name`: межскриптовые
  зависимости резолвятся по имени класса, а не по пути — перемещение не
  ломает их, ломать можно только явные `preload("res://…")`/`load("res://…")`,
  `ext_resource` и `[autoload]`.
- Ограничения: правило 6 AGENT.md (после перемещений — обязательный
  `rm -rf .godot`); правило 8.1 (все запуски Godot — под `sleep+kill`
  таймаутом); тестовый раннер сканирует `res://tests/**`; CI —
  `tools/shell/run_all_ci_checks.sh` (compile_all + check_scene_refs +
  card_validation + check_tileset + тесты).
- Не-игровые dev-материалы в корне `game/`: `prototype/` (3 `.html`),
  `lair/` (1 `README.md`), `backup_assets/` (40 tracked + gitignored
  `.import`), пустой `game/tmp/` (gitignored). Проверено: ссылок на эти
  каталоги из скриптов/тестов/тулзов **нет** — перенос их не требует
  правок кода. В корне репозитория папок с такими именами нет (нет
  коллизий для `git mv`).
- Git-дерево сейчас dirty (410 удалённых docs-файлов, 44 untracked) —
  предсуществующее состояние; миграция оперирует фактическим диском и
  `git mv` только для переезжающих файлов.

## Goals / Non-Goals

**Goals:**
- Корень `res://` содержит только то, без чего игра не работает:
  `project.godot`, `icon.svg`, `README.md`, `assets/`, `scenes/`,
  `scripts/` (с `scripts/autoload/`) — плюс исключение по требованию
  пользователя: `tests/` и `tools/` (работают на Godot через `--path game`).
- Каждое переезжающее имя файла сохраняет историю Git.
- После миграции: зелёный полный CI (compile + проверки + тесты) при
  неизменном поведении.
- Документация (`AGENT.md`, `game/README.md`, `docs/`) описывает новую
  структуру — правила AGENT.md «структура = flat-домены» заменяются новыми.

**Non-Goals:**
- Не меняем поведение, API, имена классов, имена сцен/узлов.
- Не переносим `game/` в корень репозитория.
- Не трогаем `tests/` и `tools/` (исключение пользователя: остаются в
  `game/`, т.к. работают на Godot).
- Не трогаем внутреннюю организацию `assets/`, `scenes/`, `tests/`, `tools/`.
- Не переименовываем файлы/классы (в т.ч. `snake_case`-исключения вроде
  `hex_autotiler.gd` — это отдельная чистка).
- Не решаем судьбу `_arhive/`, `debug_atlases/`, `debug_map.png` в корне
  репозитория (чужое dev-мусорное состояние).

## Decisions

### D1. Dev-материалы: раскол по «работает на Godot или нет»

Требование пользователя: в `game/` остаётся только то, без чего игра не
работает; исключение — тесты и тулзы, которые работают на Godot.
Проверено: ссылок на `prototype/`, `lair/`, `backup_assets/` из
скриптов/тестов/тулзов нет (grep по `res://` и относительным путям) —
перенос не затрагивает код. Коллизий имён в корне репозитория нет.

Решение:
- **Остаются в `game/`**: `tests/` и `tools/` — тестовый раннер сканирует
  `res://tests/**`, все CI-команды уходят через `--path game`; вынос
  сломал бы headless-запуски (`-s tests/run_tests.gd`,
  `-s tools/compile_all.gd`) и dev-портативность.
- **В корень репозитория** (`git mv`): `prototype/` (HTML-прототипы, не
  Godot), `lair/` (контент-доки фракции), `backup_assets/` (архив
  ассетов). Это возвращает изначальный дизайн AGENT.md, где корень
  репозитория — dev-рабочее пространство («Тут живут … backup_assets/,
  lair/, …»). Следствие: `res://tests/**` и `res://tools/**` не меняются —
  тестовые ссылки и `tools/` практически не требуют правок (только ссылки
  на переезжающие домены внутри `tools/*.gd`).
- **`game/tmp/` — удалить** (пустой). Scratch-пространство — корневой
  `tmp/`, который **создаётся закоммиченным** (требование пользователя):
  внутри кладётся `tmp/.gitignore`-маркер с правилами `*` и `!.gitignore`
  (в Git попадает только маркер, содержимое — игнорируется), а в корневом
  `.gitignore` паттерн `tmp/` заменяется на `tmp/*` + `!tmp/.gitignore`
  (обязательно: директорный паттерн `tmp/` запрещал бы коммит маркера —
  git не заглядывает в игнорируемую папку). В правила (AGENT.md) прописано:
  корневой `tmp/` — для временных/черновых файлов.

Альтернативы: (a) вынести всё, включая tests/tools, в корень — отклонено,
ломает Godot-запуски; (b) спрятать dev-папки под `scripts/` — отклонено,
нарушает «scripts/ = только игровой код» (D2).
Нюанс портативности: сама игра остаётся самодостаточной (копирование
`game/` даёт запускаемый проект); dev-материалы просто переезжают за
пределы игровой папки. Формулировка «game/ — самодостаточная папка» в
AGENT.md уточняется (входит в задачу обновления доков).

### D2. `scripts/` — доменные подпапки, а не плоский каталог

Строгое чтение Godot Docs дало бы ~140 `.gd` в одной папке. Отклоняется:
(1) доменная группировка — задокументированная архитектура
(`docs/architecture/ARCHITECTURE.md` описывает слои core/systems/world/
city/ui/economy/data), она несёт смысл и не дублируется `class_name`;
(2) Godot Docs рекомендует группировку «по типам ИЛИ по сущностям» — внутри
`scripts/` сохраняем сущности, в корне — типы. Итог:
`scripts/{core,systems,entities,world,city,ui,economy,data,demographics}/`
(+ `ui/components/` внутри).

### D3. Синглтоны — `scripts/autoload/`

Пользователь дал выбор `autoload/` или `singletons/`. Выбран `autoload/`:
совпадает с термином секции `[autoload]` project.godot — имя папки
однозначно указывает «это те самые глобалы из конфига», и новые autoloads
автоматически знают, куда себя положить. Переезжают ровно 10 файлов из
`[autoload]` (4 из `core/`, 5 из `data/`, 1 из `entities/`); остальной код
доменов остаётся в своих подпапках. Имена классов (`SoundManager`,
`SpellRegistry`, …) и ключи в `[autoload]` не меняются — меняются только
пути в конфиге.

### D4. Разделение `data/` по типу содержимого

`data/*.gd` (20 файлов) → `scripts/data/` (это код, пусть и
data-ориентированный: реестры, defs, правила). `data/spells.json`,
`data/spells.schema.json` → `assets/data/` (это данные/ресурсы).
Обоснование: суть передела — в корне и в подпапках тип ≠ типу; json,
загружаемый через `load("res://data/spells.json")`, — ресурс наравне с
текстурами. Альтернатива `data/`-папка у корня (как в некоторых Godot-
проектах) отклоняется: пользователь явно перечислил только
assets/scenes/scripts/autoloads.

### D5. `default_bus_layout.tres` → `assets/settings/`

Это layout шин аудио движка (конфигурный `.tres`), а не игровой звук.
`assets/audio/` — игровые mp3/wav, туда не совать. `assets/settings/` —
новый подкаталог для конфигов-ресурсов (на будущее — темы, палитры).
Обновляется `audio/buses` в project.godot. `icon.svg` остаётся в корне
(`config/icon="res://icon.svg"`) — каноничное место.

### D6. Миграция ссылок — детерминированная таблица подстановки

Все ссылки статические (проверено: нет склейки путей), поэтому применяем
ordered sed-маппинг по тексту всех `.gd`, `.tscn`, `.tres`, `project.godot`,
`.py`, `.sh`, `.md` (в `game/` + `AGENT.md` + `docs/`):

| # | От (паттерн) | Кому | Кому |
|---|---|---|---|
| 1 | `res://core/{SoundManager,Settings,GameEventBus,SocketController}.gd` | 4 файла | `res://scripts/autoload/…` |
| 2 | `res://data/{SpellbookRegistry,TemplateBootstrap,ArtifactRegistry,SpellRegistry,ResourceRegistry}.gd` | 5 файлов | `res://scripts/autoload/…` |
| 3 | `res://entities/UnitRegistry.gd` | 1 файл | `res://scripts/autoload/UnitRegistry.gd` |
| 4 | `res://core/…` | все ост. | `res://scripts/core/…` |
| 5 | `res://data/*.gd` | все ост. | `res://scripts/data/…` |
| 6 | `res://{systems,entities,world,city,ui,economy,demographics}/…` | | `res://scripts/<domain>/…` |
| 7 | `res://data/{spells.json,spells.schema.json}` | 2 файла | `res://assets/data/…` |
| 8 | `res://default_bus_layout.tres` | 1 файл | `res://assets/settings/default_bus_layout.tres` |

Порядок критичен: правила 1–3 (autoload-исключения) ДО правил 4–6
(генерика). Не трогаются: `res://scenes/`, `res://assets/`, `res://tests/`,
`res://tools/`, `res://icon.svg`, корневые артефакты
(`res://UNIT_REPORT.txt`, `res://benchmark_results.json`).
Для `project.godot` правила 1–3, 7, 8 применяются вручную/точечно
(файл редактируется редкими правками, не седом целиком — меньше риск
сломать `[input]`-секцию).

После подстановки — контрольный grep: `grep -rn "res://\(core\|systems\|entities\|world\|city\|ui\|economy\|demographics\)/" game/ AGENT.md docs/` и
`res://data/` (без `assets/data`) — должны дать 0 совпадений.

### D7. Перемещение файлов — `git mv`, `.uid` уезжает вместе

`git mv` сохраняет историю (140+ файлов — история видима). `.uid`-файлы
(Godot 4.4+) и `.import` переезжают вместе с владельцем (`.uid` — в Git,
`.import` — gitignored, пересоздаст движок). Пустые исходные папки
удаляются; пустой `game/game/` удаляем; пустой `game/tmp/` (gitignored) —
удаляем, scratch теперь в корневом `tmp/` (закоммиченная директория,
содержимое игнорируется — см. D1). Dev-материалы
(`prototype/`, `lair/`, `backup_assets/`) — `git mv` в корень репозитория
(D1).

### D8. Порядок: сначала файлы, потом ссылки, потом кэш

Сначала `git mv` (дерево), затем подстановка ссылок, затем `rm -rf game/.godot`
и полный CI. Обратно не работает: компиляция по старому кэшу
(`global_script_class_cache.cfg`) даст ложные «Could not find type» (правило
6). Базовая линия: перед миграцией — один успешный прогон
`run_all_ci_checks.sh` (чтобы отличить «сломали» от «было уже»).

## Risks / Trade-offs

- [Пропущенная ссылка (особенно в `.md`/`.py`/`.sh`)] → ordered-маппинг
  покрывает все текстовые форматы + финальный grep-свип по старым префиксам
  + зелёный CI (compile_all компилирует ВСЕ скрипты, включая `tools/`).
- [Десинхронизация кэша Godot после перемещений] → обязательный `rm -rf
  .godot` (правило 6) перед первым запуском; CI-скрипт сам пересоберёт
  реестр `class_name`.
- [Dirty git-дерево (410 D / 44 ??) размывает дифф] → миграция одним
  коммитом только из `git mv` + правок ссылок; чужие dirty-файлы не
  коммитим; до миграции — фиксация базовой линии CI.
- [Импорт-файлы (`.import`) со старыми путями] → gitignored, удаляются вместе
  с `.godot/`; движок переимпортирует по новым путям.
- [Разрыв старых правил в AGENT.md (flat-домены в корне `game/`,
  dev-материалы внутри `game/`, «self-contained»-состав) — агент начнёт
  создавать файлы по старым правилам] → обновление AGENT.md (разделы 1, 5,
  8) входит в те же задачи, что и миграция; порядок: структура + AGENT.md в
  одном коммите; self-contained-формулировка уточняется: игра остаётся
  самодостаточной для запуска, dev-материалы — в корне репозитория.
- [Альтернативный layout (плоский `scripts/`) оказался бы ближе к букве
  Godot Docs] → принята осознанная отсечка (D2): доменная группировка
  важнее для проекта с 9 слоями; решение задокументировано в AGENT.md.

## Migration Plan

0. **Базовая линия**: `bash tools/shell/run_all_ci_checks.sh` (полный) —
   записать результат; при красном до-стейте — зафиксировать, что именно
   было красным до.
1. `git mv` девяти доменных папок → `scripts/`; создать `scripts/autoload/`
   и `git mv` в него 10 синглтонов (правила D3).
2. `git mv data/spells.json data/spells.schema.json` → `assets/data/`;
   `git mv default_bus_layout.tres` → `assets/settings/`;
   `git mv prototype lair backup_assets` → корень репозитория; создать
   корневой `tmp/` с `.gitignore`-маркером, заменить в корневом
   `.gitignore` `tmp/` → `tmp/*` + `!tmp/.gitignore`, удалить пустой
   `game/tmp/` (D1).
3. Подстановка ссылок по таблице D6 (код: `.gd`, `.tscn`; конфиг:
   `project.godot`; инструменты: `tools/**`; доки: `AGENT.md`,
   `game/README.md`, `docs/**`).
4. Удалить пустые исходные каталоги и `game/game/`.
5. `rm -rf game/.godot`; прогнать полный CI под таймаут-обёрткой (правило
   8.1); при ошибках — точечные доправки ссылок.
6. Smoke: headless-запуск `scenes/MainMenu.tscn` и `scenes/World.tscn` с
   `--autoquit` (по 40–60 с) — автостартовые autoloads подтянулись.
7. Один коммит: структура + ссылки + доки.
8. **Rollback**: `git revert` коммита (все перемещения — `git mv`, revert
   зеркальный); при конфликтах с чужим dirty-деревом — `git restore` по
   файлам из коммита.

## Open Questions

- Нет: все решения, влияющие на подход или разбиение на задачи, закрыты в
  D1–D8 (в т.ч. «autoload vs singletons» — D3, «куда dev-папки» — D1).
