# AGENT.md — руководство для агентов и разработчиков

Строкий свод правил для работы с проектом **Sigil of the Unwilling** (hex strategy, Godot 4.7).
Перед правкой прочитай `docs/architecture/ARCHITECTURE.md` — там описаны слои и запреты между ними.

> Этот файл — адаптация общего шаблона под **конкретную структуру проекта**.
> Не слепо копировать шаблоны: структура ниже — плоская, а не вложенная.

---

## 1. Структура проекта

- **Корень Godot-проекта — `game/`.** `project.godot` лежит в `game/project.godot`.
  Игра полностью само-contained в `game/`: её можно скопировать на другую машину
  и запустить без остального репозитория (см. `game/README.md`).
- **Корень репозитория — dev-рабочее пространство.** Тут живут `docs/`, `tmp/`,
  `backup_assets/`, `lair/`, `prototype/` и OpenSpec (`openspec/`).
- **Внутри `game/` — только то, что нужно игре для запуска**, плюс явное исключение
  `tests/` и `tools/`: `project.godot`, `assets/`, `scenes/`, `scripts/`,
  `tests/`, `tools/`, `README.md`, `icon.svg`.
- Все пути в коде — `res://…` относительно **корня проекта** `game/`:
  `res://scripts/systems/BattleState.gd`, `res://scripts/core/GameLogger.gd`, `res://scenes/World.tscn`.
- Тесты лежат прямо в `game/tests/` (внутри проекта, отслеживаются в Git);
  раннер сканирует `res://tests/**` — поэтому `tests/` не выносится из `game/`.
  То же для `tools/`: CI и утилиты выполняются через Godot с `--path game`.

```text
.                                   # Корень репозитория = dev-материалы
├── AGENT.md                        # Этот файл
├── README.md                       # Краткая справка
├── docs/                           # Документация проекта (architecture, howto, concepts, …)
├── tmp/                            # Временные/черновые файлы (каталог закоммичен, содержимое gitignored)
├── backup_assets/                  # Архив/резерв ассетов (вне игры)
├── lair/                           # Логово — контент фракции; см. lair/README.md
├── prototype/                      # HTML-прототипы
├── openspec/                       # Изменения OpenSpec
└── game/                           # ← Godot-проект (портативный, self-contained)
    ├── project.godot
    ├── README.md                   # Как запустить на другой машине
    ├── icon.svg
    ├── .godot/                     # Кэш Godot (gitignored)
    ├── scripts/                    # Весь GDScript-код
    │   ├── autoload/               # 10 синглтонов: SoundManager, Settings, GameEventBus, …
    │   ├── core/                   # Ядро: HexUtils, GameLogger, GameSession, …
    │   ├── systems/                # Бой: BattleController/State/AI/View/UI/Input, BattleFlow, …
    │   ├── entities/               # Герой и юниты: Hero*, HeroInventory, …
    │   ├── world/                  # Карта и мир: MapGenerator/Model/Renderer, Borough, City…
    │   ├── city/                   # Модель города: CityTurnProcessor, системы, Arena
    │   ├── ui/                     # UI: AdventureUI, BattleUI, панели, components
    │   ├── economy/                # Экономические процессы хода
    │   ├── demographics/           # Население, потребности, черты
    │   └── data/                   # Определения: BuildingDefs, Artifact, ScrollRules, …
    ├── assets/                     # Только ассеты (без кода)
    │   ├── data/                   # spells.json, spells.schema.json
    │   ├── settings/               # Конфиг движка: default_bus_layout.tres
    │   ├── tilesets/               # hex_atlas_*.png, hex_tileset.tres
    │   └── audio/ cursors/ raw/ ui/ units/   # Медиа и текстуры
    ├── scenes/                     # .tscn: MainMenu, World, Battle, CityArena
    ├── tests/                      # Тесты: test_*.gd, unit/, fakes/ (exec: --path game)
    └── tools/                      # Инструменты: compile_all, check_scene_refs, shell/
```

### Состав `game/` и правила для `tmp/`

Внутри `game/` — игровой Godot-проект и только явное исключение `tests/`, `tools/`
(они исполняются на Godot с `--path game`). Инструментальные скрипты
(`process_assets*.py`, `ai_agent.py`, `generate_map_preview.py`,
`organize_assets.py`, `biome_showcase.py`) — в `game/tools/`.

Внутри `game/` gitignore-ится только кэш/служебное: `.godot/`, `.DS_Store`, `*.log`,
`*.import`, `*.uid`, `__pycache__/` (см. `.gitignore`); остальное отслеживается в Git.

Корневой `tmp/` — рабочее пространство для черновых/временных файлов. Каталог сам
отслеживается в Git (через `tmp/.gitignore`), всё содержимое в нём игнорируется.
В `tmp/` **не должно** оказываться того, что предназначается для игры (код, сцены, данные).
Если в `tmp/` появилась готовая игровая фича — выносим в `game/` (соответствующий слой)
и коммитим её там, а из `tmp/` убираем.

---

## 2. Соглашения об именами

> **Отклонение от шаблона.** В этом проекте **скрипты — `PascalCase`**
> (например `BattleState.gd`, `HexUtils.gd`, `HeroArmyController.gd`),
> потому что у почти каждого файла есть `class_name` и класс резолвится по имени.

- **Скрипты (`.gd`)**: `PascalCase` (как и `class_name`). НЕ `snake_case`.
- **`class_name`**: `PascalCase`. ~91 файл регистрирует `class_name` — такие классы
  **не нужно `preload`-ить**; обращаться прямо по имени (`BattleState`, `HexUtils`).
- **Сигналы и переменные (GDScript)**: `snake_case`.
- **Узлы в сцене (Editor)**: `PascalCase`.
- **`.tscn` / `.tres` / ассеты**: `snake_case`.
- **C#-скрипты**: `PascalCase.cs` (исключение, здесь C# не используется).

Проверь, что имя файла совпадает с `class_name` — иначе Godot ругается в редакторе.

---

## 3. Архитектура сцен и узлов

Основа — принципы из `docs/architecture/ARCHITECTURE.md`:

1. **Данные отделены от визуала.** Координатор (например `BattleController`) связывает
   модули, но не содержит тяжёлой логики.
2. **Логика не работает с узлами сцены.** `BattleState`/`BattleAI`/`MapModel` оперируют
   типизированными данными, а не `Node`. Визуал (`BattleView`/`MapRenderer`) не меняет
   состояние.
3. **UI показывает состояние и излучает намерения игрока**, но не принимает решений.
4. **Self-Contained Scenes (слабая связанность).** Никаких `get_node("../../../")`.
   Связь через **сигналы**, **Callable** и **Dependency Injection** (через
   `ServiceContainer`/`ServiceLocator` или `@export`).
5. **Logical vs Spatial hierarchy.** Узел — ребёнок только если логически зависит от
   родителя. Иначе — `top_level = true` или другой корень.
6. **Main Scene**: `scenes/MainMenu.tscn` → `World` (логика/мир, сменяем) + `GUI`
   (персистентный UI).

### Запреты между модулями боя (из ARCHITECTURE.md)

- `BattleState` не знает о спрайтах и узлах.
- `BattleAI` не использует `await`, узлы и анимации.
- `BattleView` не меняет `BattleState`.
- `BattleUI` не принимает боевых решений — только сигналы.
- `BattleController` связывает модули и управляет `await`.

---

## 4. Сцены vs Скрипты

- **Сцены (`PackedScene`)** — для игровых сущностей, уровней, экранов: движок инстанцирует
  их пачками на C++-стороне, что быстрее императивного кода.
- **Скрипты** — для переиспользуемых инструментов и логики; классы с `class_name` +
  иконкой регистрируются как кастомные editor-типы.

---

## 5. Правила организации директорий

1. **Группируй ресурсы близко к сцене.** Эксклюзивные текстуры/звук — в той же папке,
   что и `.tscn`, с префиксом имени сцены (`player_albedo.png` → `player.tscn`).
2. **Общие ресурсы** (шрифты, палитры, тайлкеты, шейдеры) — в соседних папках по типу
   данных (`tilesets/`, `assets/shaders/`).
3. **Third-party плагины** — в `addons/` с лицензиями.
4. **Hand-edited данные** — через `.tres` (текстовые), а не `.res` (бинарные), чтобы
   диффы в Git были чистыми. (`hex_tileset.tres` — пример.)

---

## 6. Порядок членов в скрипте

Строгий порядок для читаемости и совместимости с инструментами:

```gdscript
01. @tool
02. class_name
03. extends
04. # docstring (краткое описание)

05. signals
06. enums
07. constants
08. @export variables
09. public variables
10. private variables (_underscored)
11. @onready variables

12. _init()
13. _enter_tree()
14. _ready()
15. другие built-in virtual methods
16. public methods
17. private methods
18. subclasses
```

Числа — только для нумерации секций, в коде их нет.

---

## 7. Правила поведения агента

1. **`game/` = Godot-проект.** `res://…` — это пути внутри `game/`. Игровой код пишем
   только в `game/`; dev-материалы (тесты/тулзы/доки) — в корне репозитория.
2. **Никогда не хардкодить `get_node("../../../")`.** Использовать `%NodeName`
   (Scene Unique Nodes), `@export` или Dependency Injection.
3. **Классы с `class_name` резолвятся по имени.** Не добавлять лишний `preload` для
   файлов из `scripts/core/`, `scripts/systems/`, `scripts/entities/`, `scripts/world/`, `scripts/ui/`, `scripts/data/`.
4. **Ранние ассерты** в `_ready()` или через DI — ловить неправильно настроенные сцены
   сразу, а не в бою.
5. **Никогда не создавать `Node` только чтобы держать данные.** Использовать
   `Resource` (видим в Inspector, сохраняется в `.tres`) или `RefCounted` (внутренние
   структуры без Inspector). В проекте почти всё состояние — `RefCounted`/`Resource`.
6. **Перемещение/переименование файлов.** Кэш Godot десинхронизируется. Делать через
   Godot Editor **или** убедиться, что есть чистый коммит beforehand, и после —
   очистить `.godot/` (`rm -rf .godot`) и перезагрузить проект при странных ошибках.
   **Обязательно чистить `.godot/`** после любых перемещений файлов, смены версий
   `class_name` или если проверки начали падать с «Could not find type X» — иначе
   устаревший реестр `global_script_class_cache.cfg` даёт ложные ошибки (см. 8.2).
7. **Логи — через `GameLogger`.** Не слать `print()` в продакшн-код. Тег выбирается по
   домену: `GameLogger.battle(...)`, `world(...)`, `inventory(...)`, `ui(...)`,
   `warn(...)`, `error(...)`. Ошибки-граничные условия (лимиты, фолбэки) — через
   `GameLogger`, а не через тишину.
8. **Данные — типизированные объекты, не `Dictionary`.** (`GameSettings` держит все
   константы: `MAX_HERO_ARMY_SIZE`, `BATTLE_MAX_UNITS_PER_SIDE` и т.д.)
9. **Сейдж только игровые пути.** Не тащить в коммит `assets/` (если это не новый
   игровой ассет), `graphify/`, `grepai/`, python-скрипты, `backup_assets/`,
   `__pycache__/`, `.godot/`, логи, `.DS_Store`.

---

## 8. Команды (headless, без GPU/окна)

Godot в headless-режиме гоняет сцены в бесконечном цикле. Для smoke-тестов сцена должна
сама завершаться (через `--autoquit` или `quit()` в `_init`/после инициализации).

Все команды Godot идут с `--path game` (корень проекта — `game/`).

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

# Компиляция ВСЕХ скриптов (быстро, без запуска игры)
$GODOT --headless --path game -s tools/compile_all.gd
# → "compile check: N ok, 0 errors"

# Полный CI: компиляция + проверки сцен/данных/тайлкетов + юнит-тесты
bash tools/shell/run_all_ci_checks.sh
# --fast  : только компиляция + проверки (без тестов)
# --tests : только тесты

# ⚠️ run_all_ci_checks.sh АВТОМАТИЧЕСКИ соберёт реестр class_name, если его нет —
#    чистый checkout работает из коробки, .godot вручную собирать/чистить не надо
#    (см. правило 8.2).

# Облегённый вариант (README): compile + scene-refs + подборка тестов + world smoke
./tools/shell/run_all_ci_checks.sh

# Юнит-тесты (главный раннер сканирует res://tests/**).
$GODOT --headless --path game -s tests/run_tests.gd
# → "Total: N passed, 0 failed" / "ALL TESTS PASSED"

# Проверка ссылок в сценах / валидация карт / целостность тайлкетов
$GODOT --headless --path game -s tools/check_scene_refs.gd
$GODOT --headless --path game -s tools/card_validation/validate_card_spells.gd --strict --json
$GODOT --headless --path game -s tools/check_tileset.gd

# Запуск сцены (нужен --autoquit, иначе зависнет)
$GODOT --headless --path game --scene scenes/World.tscn --autoquit
$GODOT --path game --scene scenes/MainMenu.tscn          # с окном, для ручной проверки
```

> Если после переключения ветки поехали ошибки кэша/импорта:
> `rm -rf game/.godot` и перезагрузить проект (см. правило 6).

## 8.1. ⚠️ КРИТИЧЕСКОЕ ПРАВИЛО: запуск Godот-сцен/скриптов — только с жёстким таймаутом

Запуск Godot (`--scene`, `-s script.gd`) **всегда** оборачиваем в жёсткий таймаут через
фоновый процесс + `kill`, потому что зависшая сцена/скрипт гоняет main-loop бесконечно и
может «повесить» всю команду (хэндлер отрубает через ~5000 с — теряется весь прогресс).

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

# Универсальный обёртка: запускает Godot, ждёт до N секунд, убивает, возвращает код.
run_godot() {  # run_godot <секунд> <остальные_аргументы...>
  local secs="$1"; shift
  "$GODOT" "$@" >/tmp/godot_run.log 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) &
  local killer=$!
  wait "$pid"
  local rc=$?
  kill "$killer" 2>/dev/null
  return "$rc"
}

# Примеры:
run_godot 40 $GODOT --headless --path game --scene scenes/World.tscn --autoquit
cat /tmp/godot_run.log | grep -vE 'loading_editor_layout|ready'
```

- Для smoke-запуска сцены добавляем `--autoquit` (см. правило 8) — но всё равно оборачиваем.
- Если сцена должна завершиться сама (`quit()` после `await process_frame`) — всё равно
  держим `kill`-таймаут на всякий случай.
- `timeout` на macOS **отсутствует**, поэтому используем именно `sleep + kill`.
- Проверку UI лучше делать через `SceneTree`-скрипт с `_init()` + `quit()` (каноничный
  раннер из правила 9), а не через `--scene` — он гарантиленно завершается.
- Если после `run_godot` в `/tmp/godot_run.log` есть `SCRIPT ERROR` / `Parse Error` —
  чиним; чистый прогон = только предупреждения импорта без ошибок скриптов.

### 8.2. Реестр `class_name` и автозагрузка в CI

Проект массово использует `class_name` (~91 класс). При загрузке GDScript Godot резолвит
эти имена по **глобальному реестру** `.godot/global_script_class_cache.cfg`.

- **Важно:** headless-запуски (`-s script.gd`, обычный импорт) реестр **не пишут** — он
  строится только **ректором** (`godot --editor`). Без пресбортого реестра все проверки
  падают с `SCRIPT ERROR: Parse Error: Could not find type "BattleState" in the current
  scope` и `Failed to instantiate an autoload … does not inherit from 'Node'`.
- **Поэтому `run_all_ci_checks.sh` автостартует реестр:** если `.godot/global_script_class_cache.cfg`
  отсутствует, скрипт один раз прогоняет `godot --headless --path game --editor` (с таймаутом
  240 с — импорт прёвается загрузкой UI-макета, но кэш успевает записаться) и только потом
  запускает проверки. Чистый checkout **работает из коробки** — ничего собирать не надо.
- **Обязательная чистка кэша:** если после правок поехали странные ошибки кэша/импорта —
  `rm -rf game/.godot` и заново прогоните CI (он соберёт реестр заново).
- **Определение провала** — по логу (маркеры `SCRIPT ERROR:`, `Failed to load script`,
  `Could not find type`, `does not inherit from`, `RESULT: FAILED`, `SOME TESTS FAILED`),
  а не по коду выхода: Godot возвращает `0` даже когда скрипт не загрузился.
- **Ложные срабатывания:** приложение само логирует `SaveManager: parse error …` — поэтому
  в маркеры провала **не** включают `Parse error`/`File not found`.

### Рабочий цикл запуска/сборки

1. Быстрый прогон (`--fast`, ~1 мин) — проверить, что CI стартует и компиляция чистая.
2. Полный прогон (`run_all_ci_checks.sh`, до ~5 мин с первого раза из-за автозагрузки
   реестра) — все проверки + юнит-тесты (`4759 passed, 0 failed` из 75 файлов).
3. Оба прогон **всегда** оборачивать в жёсткий таймаут (см. правило 8.1).

---

## 9. Тесты

- Файлы: `game/tests/test_*.gd` (рекурсивно с `game/tests/unit/`), исполняются
  из проекта `game/` (тот же каталог). Автономные SceneTree-раннеры
  (`test_runtime_integration.gd`, `debug_load.gd`, `run_tests.gd`, `test_validation_runner.gd`)
  **пропускаются** главным раннером — они запускаются сами через `godot -s`.
- **Шаблон тестового файла**:
  ```gdscript
  extends SceneTree
  var _passed: int = 0
  var _failed: int = 0

  func _init() -> void:
      var failed := 0
      failed += _test_что_то()
      failed += _test_ещё_что()
      if failed == 0:
          print("... tests passed")
      else:
          printerr("... tests failed: ", failed)
      _failed = failed
      _passed = 1 if failed == 0 else 0
      await process_frame
      quit(1 if failed > 0 else 0)

  func _test_что_то() -> int:
      var errors := 0
      # ... проверки через printerr + инкремент errors ...
      return errors
  ```
  Тест **не обязан** добавлять узлы в дерево. Если код требует дерева — добавлять
  осторожно (`get_root().add_child(node)`); `queue_redraw()`/`_process` должны быть
  защищены `is_inside_tree()`.
- **Фейки/моки** — в `tests/fakes/` (`fake_battle_flow.gd`, `fake_hero.gd`, …):
  лёгкие замены координаторов для изоляции логики.
- **Asserts** — через `printerr` + возврат счётчика ошибок (в проекте нет `assert`-хелпера);
  раннер считает каждый файл теста за 1 единицу, поэтому возвращай `errors`.
- **Память**: для `RefCounted`-объектов (например `BattleState`) освобождать `free()`,
  не `queue_free()`.

---

## 10. Автогрузы (Singletons)

Только для систем с глобальным доступом и изолированным состоянием. В `project.godot`:

```
SoundManager, Settings, GameEventBus, CardSpells, CardTemplateBootstrap,
SocketController, Units, Artifacts, Spells, Resources
```

- Без `*` в `project.godot` — грузятся со стартом (`SoundManager`, `SocketController`).
- С `*` — отложенная загрузка (`Settings`, `Units`, `Spells`, `Artifacts`, `CardSpells`, …).
- `GameEventBus` — центральная шина событий для связи слоёв (не заменять прямыми сигналами
  там, где связь глобальная/множественная).

Не злоупотреблять autoloads для обычной связи сцен — использовать сигналы/DI.

---

## 11. Документация

- `docs/architecture/ARCHITECTURE.md` — слои, координаторы, запреты между модулями (читать первым).
- `docs/overview/ASSET_PIPELINE.md`, `docs/howto/TOOLS.md`, `docs/systems/BIOME_SYSTEM.md`.
- `docs/howto/ADDING_TERRAINS.md`, `docs/howto/ADDING_UNITS.md` — как добавлять контент.
- `docs/overview/PLAN_MASTER.md`, `docs/overview/TASK.md` — дорожная карта.
- `TESTING.md` — справка по headless-запуску сцен.

---

## 12. Чек-лист перед коммитом

1. `bash tools/shell/run_all_ci_checks.sh --fast` (или полный) — зелёный.
2. `tests/run_tests.gd` — `ALL TESTS PASSED`, `0 failed`.
3. Нет лишних `print()`; граничные условия логированы через `GameLogger`.
4. Соблюдён порядок членов скрипта и `class_name` = имени файла.
5. Стейджены только затронутые игровые пути; мусор (`graphify/`, `grepai/`,
   python-скрипты, `backup_assets/`, `.godot/`, `*.log`, `.DS_Store`) — в коммите нет.
6. Если двигал/переименовал файлы — почистил `.godot/` и проверил, что кэш пересобрался.


#!/bin/bash
# runwt.sh <timeout_seconds> <cmd...>
TO="${1:?need timeout}"; shift
OUT="$(mktemp)"; PIDFILE="$(mktemp)"
"$@" >"$OUT" 2>&1 &
PID=$!
echo "$PID" >"$PIDFILE"
( sleep "$TO"; kill -9 "$PID" 2>/dev/null ) &
KILLER=$!
wait "$PID"; RC=$?
kill "$KILLER" 2>/dev/null
cat "$OUT"
rm -f "$OUT" "$PIDFILE"
exit $RC
