# AGENT.md — руководство для агентов и разработчиков

Строкий свод правил для работы с проектом **HoMM3-like hex strategy** (Godot 4.7).
Перед правкой прочитай `docs/ARCHITECTURE.md` — там описаны слои и запреты между ними.

> Этот файл — адаптация общего шаблона под **конкретную структуру проекта**.
> Не слепо копировать шаблоны: структура ниже — плоская, а не вложенная.

---

## 1. Структура проекта

- **Корень Godot-проекта — `game/`.** `project.godot` лежит в `game/project.godot`.
  Игра полностью само-contained в `game/`: её можно скопировать на другую машину
  и запустить без остального репозитория (см. `game/README.md`).
- **Корень репозитория — dev-рабочее пространство.** Тут живут `tests/`, `tools/`,
  `docs/`, `previews/`, `backup_assets/`, `tmp/`, `lair/`, dev-сцены `scenes/`.
- Все пути в коде — `res://…` относительно **корня проекта** `game/`:
  `res://systems/BattleState.gd`, `res://core/GameLogger.gd`, `res://scenes/World.tscn`.
- Тесты исполняются через симлинк `game/tests -> ../tests` (gitignored, локальная
  dev-связка; при клоне создать заново: `ln -s ../tests game/tests`).

```text
.                                   # Корень репозитория = dev-материалы
├── AGENT.md                        # Этот файл
├── README.md                       # Краткая справка
├── game/                           # ← Godot-проект (портативный)
│   ├── project.godot
│   ├── README.md                   # Как запустить на другой машине
│   ├── .godot/                     # Кэш Godot (gitignored)
│   ├── core/       # Ядро: HexUtils, GameLogger, GameSession, GameSettings,
│   │               #   ServiceContainer/Locator, autoloads
│   ├── systems/    # Бой: BattleController/State/AI/View/UI/Input, BattleFlow, …
│   ├── entities/   # Герой и юниты: Hero*, UnitRegistry, HeroInventory, …
│   ├── world/      # Карта и мир: MapGenerator/Model/Renderer, Borough, City…
│   ├── city/       # Модель города: CityTurnProcessor, системы (Спринт 6–11), Arena
│   ├── ui/         # UI: AdventureUI, BattleUI, панели, components
│   ├── economy/    # Экономические процессы хода
│   ├── data/       # Ресурсы/константы: SpellRegistry, ArtifactRegistry, …
│   ├── scenes/     # .tscn: MainMenu, World, Battle, CityArena
│   ├── tilesets/   # hex_atlas_*.png, hex_tileset.tres
│   ├── assets/     # Ассеты: artifacts, audio, cursors, raw, ui, units
│   └── tests -> ../tests           # Симлинк (локально, не коммитится)
├── tests/        # Тесты: test_*.gd, unit/, fakes/ (exec: --path game)
├── tools/        # Инструменты: compile_all, check_scene_refs, card_validation, shell/
├── docs/         # Документация: ARCHITECTURE, TESTING, TOOLS, CONCEPT_*, …
├── lair/         # Логово — контент фракции; см. lair/README.md
├── previews/     # Превью-картинки (не игровые)
├── scenes/       # Dev-сцены: BiomePreview, TestTerrain (не в игре)
├── backup_assets/ # Архив/резерв ассетов (не в игре)
└── tmp/          # Временные/черновые файлы (gitignored)
```

### Dev-папки в корне (не часть игры)

`previews/`, `backup_assets/`, `docs/`, `tools/`, `tests/`, `tmp/`, `lair/`, `scenes/`
(dev-сцены), `prototype_interfes/` — **не входят в portable-проект `game/`** и не должны
туда попадать. Инструментальные скрипты (`process_assets*.py`, `ai_agent.py`,
`generate_map_preview.py`, `organize_assets.py`, `biome_showcase.py`) — в `tools/`.

Эти папки **не игнорируются Git** (в `.gitignore`: `.godot/`, `.DS_Store`, `*.log`,
`*.import`, `*.uid`, `__pycache__/`, `tmp/`, `game/tests`), поэтому в игровые коммиты их
добавляем только при осознанном изменении dev-инструментария; игровые пути стейджим
внутри `game/`.

`tmp/` — рабочее пространство для черновых/временных файлов: в нём **не должно** оказываться
того, что предназначается для игры (код, сцены, данные). Если в `tmp/` появилась готовая
игровая фича — выносим в `game/` (соответствующий слой) и коммитим её там, а из `tmp/` убираем.

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

Основа — принципы из `docs/ARCHITECTURE.md`:

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
   файлов из `core/`, `systems/`, `entities/`, `world/`, `ui/`, `data/`.
4. **Ранние ассерты** в `_ready()` или через DI — ловить неправильно настроенные сцены
   сразу, а не в бою.
5. **Никогда не создавать `Node` только чтобы держать данные.** Использовать
   `Resource` (видим в Inspector, сохраняется в `.tres`) или `RefCounted` (внутренние
   структуры без Inspector). В проекте почти всё состояние — `RefCounted`/`Resource`.
6. **Перемещение/переименование файлов.** Кэш Godot десинхронизируется. Делать через
   Godot Editor **или** убедиться, что есть чистый коммит beforehand, и после —
   очистить `.godot/` (`rm -rf .godot`) и перезагрузить проект при странных ошибках.
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

# Облегённый вариант (README): compile + scene-refs + подборка тестов + world smoke
./tools/run_checks.sh

# Юнит-тесты (главный раннер сканирует res://tests/**; нужен симлинк game/tests)
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

---

## 9. Тесты

- Файлы: `tests/test_*.gd` в корне репозитория (рекурсивно с `tests/unit/`), исполняются
  из проекта `game/` через симлинк `game/tests`. Автономные SceneTree-раннеры
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

- `docs/ARCHITECTURE.md` — слои, координаторы, запреты между модулями (читать первым).
- `docs/OVERVIEW.md`, `docs/TOOLS.md`, `docs/BIOME_SYSTEM.md`.
- `docs/ADDING_TERRAINS.md`, `docs/ADDING_UNITS.md` — как добавлять контент.
- `docs/PLAN_MASTER.md`, `docs/TASK.md` — дорожная карта.
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
