# AGENT.md — руководство для агентов и разработчиков

Строгий свод правил для работы с проектом **Sigil of the Unwilling** (hex strategy, Godot 4.7).
Перед правкой прочитай `docs/architecture/ARCHITECTURE.md` — там описаны слои и запреты между ними.

> Этот файл — адаптация общего шаблона под **конкретную структуру проекта**.
> Не слепо копировать шаблоны: структура ниже — плоская, а не вложенная.

---

## 0. TL;DR — Жёсткие правила (читать первым)

Эти правила имеют высший приоритет. При конфликте с другими разделами — следовать им.

1. **Никогда не запускать Godot голой командой в CI/скриптах.** Все автоматические запуски — через обёртку `run_godot` с жёстким таймаутом (раздел 8.1). Код возврата `124` (убит по таймауту) = **провал проверки**, лечим зависание. Единственное легальное исключение — интерактивный запуск с окном для ручной проверки UI (помечено явно).
2. **Завершение процессов:**
   - `-s`-раннеры (`extends SceneTree`) — вызвать `quit()` в конце
   - Инструменты внутри дерева нод (`extends Node`) — `get_tree().quit()` в конце
   - Сцены — через `--quit-after N` + обёртку
3. **Память в тестах:**
   - `Node` → `free()` (не `queue_free()` — в headless может не быть кадра, будет `leaked instance`)
   - `RefCounted`/`Resource` → **не освобождать вручную** (счётчик ссылок; `free()` запрещён)
4. **Нет `get_node("../../../")`.** Только `%UniqueNodes`, `@export`, DI через `ServiceContainer`.
5. **Перед коммитом — только чистый гейт.** `run_all_ci_checks.sh` без ошибок из списка 8.2.
6. **MCP-сервер (`mcp_interaction_server`) — только локальные dev-сессии.** Никогда не коммитить включённым в `project.godot`, никогда не включать в CI или релизных сборках. Это remote code execution в живой игре. Биндится только на `127.0.0.1:9090`.
7. **Кэш `.godot/`** чистить после любых перемещений файлов, смены `class_name`, странных ошибок резолвинга (см. 7.6). CI собирает реестр **только при первом отсутствии** — протухший не обновит.
8. **Коммиты — атомарные, на русском**, по конвенции (раздел 14). Не включать мусор из списка 7.9; изменения `docs/`, `openspec/`, `AGENT.md` — отдельными `docs`/`chore`-коммитами.
9. **Детерминизм тестов:** всегда использовать фиксированный seed для генерации карт/рандома (раздел 9). Запрещено использовать `Time.get_ticks_msec()` или реальный `randf()` без seed в тестах.

---

## 1. Структура проекта

- **Корень Godot-проекта — `game/`.** `project.godot` лежит в `game/project.godot`.
  Игра полностью self-contained в `game/`: её можно скопировать на другую машину
  и запустить без остального репозитория (см. `game/README.md`).
- **Корень репозитория — dev-рабочее пространство.** Тут живут `docs/`, `tmp/`,
  `backup_assets/`, `lair/`, `prototype/` и OpenSpec (`openspec/`).
- **Внутри `game/` — только то, что нужно игре для запуска**, плюс явные исключения
  `tests/` и `tools/`: `project.godot`, `assets/`, `scenes/`, `scripts/`,
  `tests/`, `tools/`, `README.md`, `icon.svg`.
- Все пути в коде — `res://…` относительно **корня проекта** `game/`:
  `res://scripts/systems/BattleState.gd`, `res://scripts/core/GameLogger.gd`, `res://scenes/World.tscn`.
- Тесты и тулзы, исполняемые Godot, лежат в `game/tests/` и `game/tools/` (игровые пути, коммитим);
  раннер сканирует `res://tests/**`, CI выполняется через Godot с `--path game`.

```text
.                                   # Корень репозитория = dev-материалы
├── AGENT.md                        # Этот файл
├── README.md                       # Краткая справка
├── docs/                           # Документация проекта
│   ├── architecture/ARCHITECTURE.md
│   ├── howto/
│   ├── overview/
│   └── systems/
├── tmp/                            # Временные/черновые файлы (каталог закоммичен, содержимое gitignored)
├── backup_assets/                  # Архив/резерв ассетов (вне игры)
├── lair/                           # Логово — контент фракции; см. lair/README.md
├── prototype/                      # HTML-прототипы
├── openspec/                       # Изменения OpenSpec (см. раздел 15)
└── game/                           # ← Godot-проект (портативный, self-contained)
    ├── project.godot
    ├── README.md
    ├── icon.svg
    ├── .godot/                     # Кэш Godot (gitignored)
    ├── scripts/                    # Весь GDScript-код
    │   ├── autoload/               # Синглтоны: SoundManager, Settings, GameEventBus, …
    │   ├── core/                   # Ядро: HexUtils, GameLogger, GameSession, ServiceContainer
    │   ├── systems/                # Бой: BattleController/State/AI/View/UI/Input, BattleFlow, …
    │   ├── entities/               # Герой и юниты: Hero*, HeroInventory, …
    │   ├── world/                  # Карта и мир: MapGenerator/Model/Renderer, Borough, City…
    │   ├── city/                   # Модель города: CityTurnProcessor, системы, Arena
    │   ├── ui/                     # UI: AdventureUI, BattleUI, панели, components
    │   ├── economy/                # Экономические процессы хода
    │   ├── demographics/           # Население, потребности, черты
    │   └── data/                   # Определения: BuildingDefs, Artifact, ScrollRules, GameSettings …
    ├── assets/                     # Только ассеты (без кода)
    │   ├── data/                   # spells.json, spells.schema.json
    │   ├── settings/               # Конфиг движка: default_bus_layout.tres
    │   ├── tilesets/               # hex_atlas_*.png, hex_tileset.tres
    │   └── audio/ cursors/ raw/ ui/ units/
    ├── scenes/                     # .tscn: MainMenu, World, Battle, CityArena
    ├── tests/                      # GUT-тесты: test_*.gd (наследники gut_base.gd)
    │   ├── gut_base.gd             # Общая база (ServiceContainer + compat-шимы)
    │   ├── unit/                   # Unit-тесты (GUT, include_subdirs)
    │   └── fakes/                  # Моки/фейки
    └── addons/gut/                 # GUT 9.7.1 (фреймворк тестов, CLI: gut_cmdln.gd)
    └── tools/                      # Инструменты: compile_all, check_scene_refs, shell/
```

### Состав `game/` и правила для `tmp/`

Внутри `game/` gitignore-ится только кэш/служебное: `.godot/`, `.DS_Store`, `*.log`, `__pycache__/` (см. `.gitignore`).

**Важно:** `*.import` и `*.uid` **коммитятся** — это sidecar-файлы импорта Godot 4, необходимые для кросс-машинной воспроизводимости. Без них на другой машине/в CI импорт пойдёт с дефолтами → расхождения и лишние ребилды. `.uid`-файлы (Godot 4.4+) фиксируют стабильные UID скриптов — без них «плавающие» UID и битые ссылки.

Корневой `tmp/` — рабочее пространство для черновых/временных файлов. Каталог сам
отслеживается в Git (через `tmp/.gitignore`), всё содержимое в нём игнорируется.
В `tmp/` **не должно** оказываться того, что предназначается для игры (код, сцены, данные).
Если в `tmp/` появилась готовая игровая фича — выносим в `game/` (соответствующий слой)
и коммитим её там, а из `tmp/` убираем.

---

## 2. Соглашения об именах

> **Отклонение от шаблона.** В этом проекте **скрипты — `PascalCase`**
> (например `BattleState.gd`, `HexUtils.gd`, `HeroArmyController.gd`),
> потому что у большинства файлов есть `class_name` и класс резолвится по имени.

- **Скрипты (`.gd`)**: `PascalCase` (как и `class_name`). НЕ `snake_case`.
- **`class_name`**: `PascalCase`. Большинство скриптов регистрируют `class_name` — такие классы
  **не нужно `preload`-ить**; обращаться прямо по имени (`BattleState`, `HexUtils`).
  **Запрещено** создавать `class_name` с именами, совпадающими с глобальными автозагрузками:
  `Resources`, `Units`, `Spells`, `Settings`, `Artifacts` — это вызовет конфликт имён.
- **Сигналы и переменные (GDScript)**: `snake_case`.
- **Узлы в сцене (Editor)**: `PascalCase`.
- **`.tscn` / `.tres` / ассеты**: `snake_case`.
- **C#-скрипты**: `PascalCase.cs` (исключение, здесь C# не используется).

**Конвенция проекта** (не встроенное требование Godot): имя файла должно совпадать с `class_name`.
Это упрощает навигацию и работу инструментов; инструменты проекта проверяют это соответствие.

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
   `ServiceContainer` — `res://scripts/core/ServiceContainer.gd`, дефолтный механизм DI в проекте).
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
   **Исключение для централизованных ассетов:** если ассет уже лежит в `game/assets/` —
   не дублировать его рядом со сценой, использовать существующий путь.
2. **Общие ресурсы** (шрифты, палитры, тайлсеты, шейдеры) — в соседних папках по типу
   данных (`tilesets/`, `assets/shaders/`).
3. **Third-party плагины** — в `addons/` с лицензиями.
4. **Hand-edited данные** — через `.tres` (текстовые), а не `.res` (бинарные), чтобы
   диффы в Git были чистыми. (`hex_tileset.tres` — пример.)

---

## 6. Порядок членов в скрипте

Строгий порядок для читаемости и совместимости с инструментами:

```gdscript
01. @tool
02. @icon("res://path/to/icon.svg")  # опционально
03. class_name
04. extends
05. # docstring (краткое описание)

06. signals
07. enums
08. constants
09. static var / static func  # группировать вместе
10. @export variables
11. public variables
12. private variables (_underscored)
13. @onready variables

14. _init()
15. _enter_tree()
16. _ready()
17. другие built-in virtual methods (_process, _physics_process, etc.)
18. public methods
19. private methods
20. subclasses
```

Числа — только для нумерации секций, в коде их нет.

---

## 7. Правила поведения агента

1. **`game/` = Godot-проект.** `res://…` — это пути внутри `game/`. Игровой код пишем
   только в `game/`; тесты и тулзы, исполняемые Godot, — в `game/tests/` и `game/tools/`;
   прочие dev-материалы (документация, прототипы, архивы ассетов) — в корне репозитория.
2. **Никогда не хардкодить `get_node("../../../")`.** Использовать `%NodeName`
   (Scene Unique Nodes), `@export` или Dependency Injection через `ServiceContainer`.
3. **Классы с `class_name` резолвятся по имени.** Не добавлять лишний `preload` для
   файлов из `scripts/core/`, `scripts/systems/`, `scripts/entities/`, `scripts/world/`, `scripts/ui/`, `scripts/data/`.
4. **Ранние ассерты** в `_ready()` или через DI — ловить неправильно настроенные сцены
   сразу, а не в бою.
5. **Никогда не создавать `Node` только чтобы держать данные.** Использовать
   `Resource` (видим в Inspector, сохраняется в `.tres`) или `RefCounted` (внутренние
   структуры без Inspector). В проекте почти всё состояние — `RefCounted`/`Resource`.
6. **Перемещение/переименование файлов.** Делать через Godot Editor **или** убедиться, что
   есть чистый коммит до правки, и после — очистить `.godot/` (`rm -rf game/.godot`)
   и перезапустить CI (`bash game/tools/shell/run_all_ci_checks.sh` — реестр пересоберётся по 8.3).
   **Обязательно чистить `.godot/`** после любых перемещений файлов, смены версий `class_name`
   или если проверки начали падать с «Could not find type X» — иначе устаревший реестр
   `global_script_class_cache.cfg` даёт ложные ошибки (см. 8.3).
7. **Логи — через `GameLogger`** (`res://scripts/core/GameLogger.gd`). Не слать `print()` в продакшн-код.
   Тег выбирается по домену: `GameLogger.battle(...)`, `world(...)`, `inventory(...)`, `ui(...)`,
   `warn(...)`, `error(...)`. Ошибки-граничные условия (лимиты, фолбэки) — через
   `GameLogger`, а не через тишину.
8. **Данные — типизированные объекты, не `Dictionary`.** `GameSettings` (`res://scripts/data/GameSettings.gd`)
   держит все константы: `MAX_HERO_ARMY_SIZE`, `BATTLE_MAX_UNITS_PER_SIDE` и т.д.
9. **Коммитить только игровые пути.** Не тащить в коммит `backup_assets/`, `__pycache__/`,
   `.godot/`, логи, `.DS_Store`, `tmp/` (кроме явно разрешённых файлов). Включённый
   `mcp_interaction_server` в `project.godot` — в коммите запрещён (проверяется машинно в 8.2).

---

## 8. Команды (headless, без GPU/окна)

Godot в headless-режиме гоняет сцены в бесконечном цикле. **Все команды ниже оборачиваются
в `run_godot`** (см. 8.1) — иначе зависший процесс повесит CI.

Все команды Godot идут с `--path game` (корень проекта — `game/`). В Godot 4 сцена
передаётся **позиционно**, флага `--scene` нет. `N` в `--quit-after N` — **кадры, не секунды**.

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot  # macOS
# GODOT=godot  # Linux (если godot в PATH)
LOG=/tmp/godot_run.log

# Компиляция ВСЕХ скриптов (быстро, без запуска игры)
run_godot "$LOG" 60 --headless --path game -s tools/compile_all.gd
# → "compile check: N ok, 0 errors"

# Полный CI: компиляция + проверки сцен/данных/тайлсетов + юнит-тесты + console clean
# (bash-скрипты не оборачиваем — таймауты внутри CI, но логируем)
bash game/tools/shell/run_all_ci_checks.sh >"$LOG" 2>&1
# --fast  : только компиляция + проверки (без тестов и console clean) — допустим для quick sanity check

# ⚠️ run_all_ci_checks.sh АВТОМАТИЧЕСКИ соберёт реестр class_name, если его нет —
#    чистый checkout работает из коробки. Заранее собирать не надо; чистить после
#    перемещений — обязательно (см. 7.6, 8.3).

# Юнит-тесты (GUT 9.7.1, addons/gut). Полный прогон — маркер "All tests passed!"
run_godot "$LOG" 150 --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# или «голый» запуск — GUT сам подхватит game/.gutconfig.json:
run_godot "$LOG" 150 --headless --path game -s addons/gut/gut_cmdln.gd

# Один файл / отбор по имени метода / отбор по имени файла:
run_godot "$LOG" 60 --headless --path game -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_hex_utils.gd -gexit
run_godot "$LOG" 60 --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gunit_test_name=hex_distance -gexit
run_godot "$LOG" 60 --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=battle -gexit

# Проверка ссылок в сценах / валидация карт / целостность тайлсетов
run_godot "$LOG" 60 --headless --path game -s tools/check_scene_refs.gd
run_godot "$LOG" 60 --headless --path game -s tools/spell_validation/validate_spells.gd -- --strict --json
run_godot "$LOG" 60 --headless --path game -s tools/check_tileset.gd

# Анализ и архивация НЕИСПОЛЬЗУЕМЫХ ассетов (game/tools/analyze_assets.py):
#   отчёт  — python3 game/tools/analyze_assets.py        (без перемещения)
#   архив  — python3 game/tools/analyze_assets.py --archive  (в _archive/ + manifest)
#   откат  — python3 game/tools/analyze_assets.py --restore
# ⚠️ после --archive ОБЯЗАТЕЛЬНО прогнать operability/тесты (см. docs/howto/ASSET_ARCHIVING.md):
#   перемещение файлов может сломать рантайм, если детекция пропустила референс.

# Запуск сцены (позиционно, --quit-after N кадров обязателен; см. правило 8.1)
run_godot "$LOG" 180 --headless --path game scenes/World.tscn --quit-after 120

# ЛЕГАЛЬНОЕ ИСКЛЮЧЕНИЕ: интерактивный запуск с окном для ручной проверки UI (только локально!)
# $GODOT --path game scenes/MainMenu.tscn
```

> Если после переключения ветки поехали ошибки кэша/импорта:
> `rm -rf game/.godot && bash game/tools/shell/run_all_ci_checks.sh` (реестр пересоберётся по 8.3).

### 8.1. Обёртка `run_godot`

**Универсальная обёртка** для запусков Godot. Принимает путь к логу, таймаут в секундах,
и аргументы **без `$GODOT`** (бинарник подставляется внутри).

```bash
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}  # macOS по умолчанию

# run_godot <логфайл> <таймаут_сек> <аргументы Godot — БЕЗ $GODOT>
run_godot() {
  local log="$1" secs="$2"; shift 2
  
  # Проверка, что GODOT задан и существует
  if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
    echo "❌ ERROR: GODOT binary not found or not executable: $GODOT" >&2
    return 1
  fi
  
  "$GODOT" "$@" >"$log" 2>&1 &
  local pid=$!
  
  # Killer с защитой от PID reuse
  (
    sleep "$secs"
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      if kill -0 "$pid" 2>/dev/null; then
        kill -KILL "$pid" 2>/dev/null
      fi
    fi
  ) &
  local killer=$!
  
  wait "$pid"
  local rc=$?
  kill -TERM "$killer" 2>/dev/null
  
  # rc=143 (SIGTERM) или 137 (SIGKILL) = убит по таймауту = провал
  if [ $rc -eq 143 ] || [ $rc -eq 137 ]; then
    echo "❌ TIMEOUT: Godot hung, killed after ${secs}s" >&2
    return 124  # Код обёртки для таймаута
  fi
  return "$rc"
}

# Примеры (из корня репозитория):
run_godot /tmp/godot_run.log 60 --headless --path game -s tools/compile_all.gd
run_godot /tmp/godot_run.log 180 --headless --path game scenes/World.tscn --quit-after 120
cat /tmp/godot_run.log | grep -vE 'loading_editor_layout|Godot Engine'
```

**Linux-альтернатива** (если доступен `timeout`):
```bash
timeout -k 5s "${secs}s" "$GODOT" "$@" >"$log" 2>&1
rc=$?
if [ $rc -eq 124 ] || [ $rc -eq 137 ]; then
  echo "❌ TIMEOUT: Godot hung" >&2
  return 124
fi
```

**Правила завершения процессов** (TL;DR п.2):

| Тип запуска | Метод завершения |
|-------------|------------------|
| `-s`-раннеры (`extends SceneTree`/`MainLoop`) | Вызов `quit()` в конце скрипта |
| Инструменты внутри дерева нод (`extends Node`) | Вызов `get_tree().quit()` в конце |
| Сцены (`scenes/World.tscn`) | Флаг `--quit-after N` (кадров) + обёртка `run_godot` |

Код возврата `124` означает, что процесс завис и был убит — это **провал проверки**,
нужно лечить зависание, а не глотать ошибку.

### 8.2. Гейт «конец цикла» — run-and-debug (обязательный)

**Перед коммитом любого цикла** прогоняем CI + релевантный smoke-сценарий, ловим лог,
сканируем на ошибки/предупреждения, чиним, гоняем до чистоты — и **только после чистоты**
коммитим. Не коммитим «грязным» — это финальный контроль качества цикла.

**Процедура:**
1. Быстрый прогон: `bash game/tools/shell/run_all_ci_checks.sh --fast >/tmp/godot_run_fast.log 2>&1`
2. Полный прогон (финальная верификация): `bash game/tools/shell/run_all_ci_checks.sh >/tmp/godot_run_full.log 2>&1`
3. Скан лога шаблонами ниже. Есть error-маркеры → чиним → повторяем 1–3.

**«Чисто» = в логе НЕТ:**
- Движковые ошибки (регистрозависимо, точная капитализация из логов Godot):
  `SCRIPT ERROR`, `Parse Error` (с большой P), `Invalid call`, `Nonexistent function`,
  `Nonexistent class`, `Nonexistent base`, `Too many arguments`, `Cannot infer`,
  `Invalid get/set`, `Failed to load script`, `Can't load script`, `Could not find type`,
  `does not inherit from`
- Тестовые провалы: `SOME TESTS FAILED`, `RESULT: FAILED`
- Утечки сверх порога (см. ниже)

**Машинный гейт** (exit 1 при наличии ошибок):
```bash
LOG=/tmp/godot_run_full.log

# Движковые ошибки (регистрозависимо, без -i)
ERROR_RE='SCRIPT ERROR|Parse Error|Invalid call|Nonexistent function|Nonexistent class|Nonexistent base|Too many arguments|Cannot infer|Invalid get/set|Failed to load script|Can'"'"'t load script|Could not find type|does not inherit from|SOME TESTS FAILED|RESULT: FAILED'
if grep -qE "$ERROR_RE" "$LOG"; then
  echo "❌ Gate FAILED: engine/test errors found in $LOG"
  exit 1
fi

# Утечки: разрешено до 20 ObjectDB instances (из CONSOLE_ALLOWLIST.md)
# Проверяем строки с "leaked", исключаем разрешённые пороги
LEAK_COUNT=$(grep -oE 'WARNING: [0-9]+ ObjectDB instances were leaked' "$LOG" | grep -oE '[0-9]+' | head -1)
if [ ! -z "$LEAK_COUNT" ] && [ "$LEAK_COUNT" -gt 20 ]; then
  echo "❌ Gate FAILED: $LEAK_COUNT ObjectDB instances leaked (threshold: 20)"
  exit 1
fi

# Машинная проверка: MCP-сервер выключен в project.godot
if grep -q 'mcp_interaction_server' game/project.godot; then
  echo "❌ Gate FAILED: mcp_interaction_server is enabled in project.godot"
  exit 1
fi

echo "✅ Gate PASSED"
```

**Разрешённые безобидные предупреждения** (не роняют гейт) — в `docs/CONSOLE_ALLOWLIST.md`:
`WARNING: [1-9]`, `WARNING: 10-19`, `WARNING: 20 ObjectDB instances were leaked at exit` (20 —
порог allowlist), SoundManager-предупреждения и т.п.

### 8.3. Реестр `class_name` и автозагрузка в CI

Проект массово использует `class_name`. При загрузке GDScript Godot резолвит эти имена
по **глобальному реестру** `.godot/global_script_class_cache.cfg`.

- **Важно:** headless-запуски (`-s script.gd`, обычный импорт) реестр **не пишут** — он
  строится только **редактором** (`godot --editor`). Без предсобранного реестра все проверки
  падают с `SCRIPT ERROR: Parse Error: Could not find type "BattleState" in the current
  scope` и `Failed to instantiate an autoload … does not inherit from 'Node'`.
- **Поэтому `run_all_ci_checks.sh` собирает реестр:** если `.godot/global_script_class_cache.cfg`
  отсутствует, скрипт один раз прогоняет `godot --headless --path game --editor --quit`
  (кэш пишется при инициализации, `--quit` заставляет движок выйти сразу после — без таймаута)
  и только потом запускает проверки. Чистый checkout **работает из коробки**.
- **Важное уточнение:** CI собирает реестр **только при его отсутствии**. Если после перемещения
  файлов реестр протух (существует, но устарел) — CI его не обновит, проверки упадут. Поэтому
  правило 7.6 (чистить `.godot/` после перемещений) остаётся **обязательным**.
- **Определение провала** — по логу (маркеры из 8.2), а не по коду выхода: Godot возвращает
  `0` даже когда скрипт не загрузился.
- **Ложные срабатывания:** приложение само логирует `SaveManager: parse error …` (с маленькой p) —
  это кастомный лог, а не движковая ошибка. Гейт использует `Parse Error` (с большой P) —
  регистрозависимый grep не ловит кастомные логи.

---

## 9. Тесты

- **Структура:**
  - `game/tests/test_*.gd` — основные тесты (сканируются главным раннером)
  - `game/tests/unit/` — unit-тесты (сканируются)
  - `game/tests/fakes/` — моки/фейки (не сканируются)
  - `game/tests/runners/` — **автономные раннеры** (НЕ сканируются главным раннером, запускаются отдельно через `run_godot`)
- **Фреймворк:** GUT 9.7.1 (`game/addons/gut/`, CLI `addons/gut/gut_cmdln.gd`).
  Конфиг: `game/.gutconfig.json` (dirs=res://tests, include_subdirs, should_exit).
  Гейты (`run_operability.sh`, `run_all_ci_checks.sh`) гатят шаг маркером
  `All tests passed!` в логе — он печатается только при failing==0 && risky==0 && pending==0.
- **Запуск одного теста:**
  ```bash
  run_godot "$LOG" 60 --headless --path game -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_hex_utils.gd -gexit
  # отбор по имени метода / по имени файла:
  run_godot "$LOG" 60 --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gunit_test_name=hex_distance -gexit
  run_godot "$LOG" 60 --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=battle -gexit
  ```
- **Подводные камни GUT 9.7.1** (полный список — `docs/howto/TESTING.md`):
  `GutTest` — Node, не SceneTree (`get_tree().root`, не `root`); статические
  вызовы по class_name в headless-GUT не работают — `preload()` внутри функции;
  `stub()` не работает на статических методах скриптов; `push_error` валит тест,
  тест без ассертов = `[Risky]` (валит «All tests passed!»); `assert_push_error`/
  `assert_engine_error` — только после вызова, шлющего сигнал; скрипт с Parse Error
  GUT молча игнорирует — сверяй число «Scripts» с числом файлов в `tests/`.
- **Шаблон тестового файла** (имя функции — валидный snake_case идентификатор):
  ```gdscript
  extends "res://tests/gut_base.gd"

  func test_hex_distance_neighbors() -> void:
      assert_eq(
          HexUtils.distance(Vector2i.ZERO, Vector2i(1, 0)),
          1,
          "соседние клетки — дистанция 1"
      )
      assert_true(HexUtils.is_valid(Vector2i.ZERO), "ноль — валидная клетка")
  ```
  Тест **не обязан** добавлять узлы в дерево. Если код требует дерева —
  `add_child(node)` (GutTest — Node, сам в дереве) или `get_tree().root.add_child(node)`;
  `queue_redraw()`/`_process` должны быть защищены `is_inside_tree()`.
  Асинхронные тесты: `await get_tree().process_frame` / `create_timer(...)` —
  в GUT кадры идут, в отличие от старого `-s`-раннера.
- **Фейки/моки** — в `tests/fakes/` (`fake_battle_flow.gd`, `fake_hero.gd`, …):
  лёгкие замены координаторов для изоляции логики.
- **Asserts** — нативные GUT (`assert_eq/true/false/almost_eq/...`) + шимы
  `assert_approx`/`assert_not_empty`/`check` в `gut_base.gd` (compat со старым API).
  Итог: `Passing Tests == Tests` + маркер `All tests passed!`.
- **Память** (TL;DR п.3):
  - `Node` в тестах → `queue_free()` (GUT дожидается кадров; `free()` допустим, если узел уже не нужен сразу).
  - `RefCounted`/`Resource` → **не освобождать вручную** (считает счётчик ссылок; `free()` на них запрещён).
- **Детерминизм:**
  - Всегда использовать фиксированный seed для генерации карт/рандома:
    ```gdscript
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345  # Фиксированный seed для воспроизводимости
    var map := MapGenerator.generate(rng)
    ```
  - **Запрещено** использовать `Time.get_ticks_msec()` или реальный `randf()` без seed в тестах —
    это источник флейков.

---

## 10. Автогрузы (Singletons)

Только для систем с глобальным доступом и изолированным состоянием. В `project.godot`:

```ini
[autoload]
SocketController="res://scripts/autoload/SocketController.gd"
SoundManager="*res://scripts/autoload/SoundManager.gd"
Settings="*res://scripts/autoload/Settings.gd"
GameEventBus="*res://scripts/autoload/GameEventBus.gd"
Spellbook="*res://scripts/autoload/Spellbook.gd"
TemplateBootstrap="*res://scripts/autoload/TemplateBootstrap.gd"
Units="*res://scripts/autoload/Units.gd"
Artifacts="*res://scripts/autoload/Artifacts.gd"
Spells="*res://scripts/autoload/Spells.gd"
Resources="*res://scripts/autoload/Resources.gd"
```

**Семантика `*` в Godot 4.x:**
- **Без `*`** (например `SocketController`) — загружается **везде** (и в редакторе, и в экспортированной игре).
- **С `*`** (например `SoundManager="*res://..."`) — **editor-only**, загружается только в редакторе,
  в экспортированной игре отключён (нужно загружать явно, если требуется).

**Опциональный dev-автозагрузчик:** `mcp_interaction_server.gd` (из раздела 13, godot-mcp).
**Не коммитить включённым** в `project.godot`, никогда не включать в CI или релизных сборках.
MCP = удалённое исполнение произвольного GDScript в живой игре → только локальные dev-сессии.
Машинно проверяется в гейте 8.2.

Не злоупотреблять autoloads для обычной связи сцен — использовать сигналы/DI.

---

## 11. Документация

- `docs/architecture/ARCHITECTURE.md` — слои, координаторы, запреты между модулями (читать первым).
- `docs/overview/ASSET_PIPELINE.md`, `docs/howto/TOOLS.md`, `docs/systems/BIOME_SYSTEM.md`.
- `docs/howto/ADDING_TERRAINS.md`, `docs/howto/ADDING_UNITS.md` — как добавлять контент.
- `docs/howto/OPERABILITY.md` — полная проверка работоспособности (`run_operability.sh`).
- `docs/howto/ASSET_ARCHIVING.md` — архивация неиспользуемых ассетов (`game/tools/analyze_assets.py`).
- `docs/CONSOLE_ALLOWLIST.md` — список разрешённых предупреждений Godot для гейта 8.2.
- `docs/TESTING.md` — справка по headless-запуску сцен.

---

## 12. Чек-лист перед коммитом

1. `bash game/tools/shell/run_all_ci_checks.sh --fast` (или полный) — зелёный, гейт из 8.2 проходит.
2. GUT-прогон (см. 8.3) — `Passing Tests == Tests`, маркер `All tests passed!`.
3. Нет лишних `print()`; граничные условия логированы через `GameLogger`.
4. Соблюдён порядок членов скрипта и `class_name` = имени файла.
5. Стейджены только затронутые игровые пути; мусор (см. правило 7.9) — в коммите нет.
   **Машинная проверка:** `git diff --cached --name-only | grep -vE '^(game/|docs/|openspec/|AGENT\.md|README\.md)'` — если есть вывод, убрать мусор из стейджинга.
6. Если двигал/переименовал файлы — почистил `game/.godot` и проверил, что кэш пересобрался.
7. `mcp_interaction_server` **выключен** в `project.godot` (проверяется машинно в 8.2).
8. Commit message — по конвенции (раздел 14).

---

## 13. Матрица выбора инструментов QA и отладки

В проекте используется **GUT 9.7.1** (`game/addons/gut/`, CLI `addons/gut/gut_cmdln.gd`).
Для интерактивного QA и live-отладки интегрирован **godot-mcp (Full Control)**.

### Зоны ответственности: Когда что использовать

#### 1. Unit-тесты (GUT) — Headless CLI
**Использовать для:**
- Проверки изолированной логики: математика hex-сетки (`HexUtils`), стейт-машины (`BattleState`), экономика, обработка данных.
- Регрессионного тестирования в CI/CD (через `run_all_ci_checks.sh`).
- Тестов, которые должны выполняться быстро, детерминированно и без рендеринга (`--headless`).
- Проверки контрактов данных (JSON схемы, валидация спеллов).

#### 2. godot-mcp (Full Control) — Runtime Interaction
**Суть:** Расширенный MCP-сервер, внедряющийся в запущенную игру через TCP-сокет.
Требует добавления `mcp_interaction_server.gd` в AutoLoad (работает только на **Godot 4.4+**,
что совместимо с нашим 4.7).

**БЕЗОПАСНОСТЬ:**
- Это **remote code execution** — удалённое исполнение произвольного GDScript в живой игре.
- Сокет биндится **только на `127.0.0.1:9090`** (localhost) — недоступен извне.
- Использовать **только в локальных dev-сессиях**.
- Никогда не включать в CI, никогда не коммитить включённым, никогда не оставлять в релизных сборках.

**Использовать для:**
- **Runtime Eval (`game_eval`):** Выполнения произвольного GDScript кода прямо в живой игре
  (например, `HeroArmyController.add_unit(...)`).
- **Манипуляций в реальном времени:** Изменения свойств нод, переподключения сигналов,
  удаления объектов во время геймплея без перезапуска сцены.
- **Симуляции ввода:** Эмуляции нажатий клавиш (WASD), кликов мышью, тач-ввода для UX-тестов.
- **Визуальной инспекции:** Создания скриншотов (`game_screenshot`), управления камерой,
  проверки шейдеров и освещения.
- **Сложных систем:** Тестирования Multiplayer-синхронизации (через `SocketController` —
  игровой мультиплеер, не связанный с MCP), физики (joints, raycasts) и анимаций в реальном времени.

**Правило:** Если баг воспроизводится только в "живом" геймплее или требует визуальной
оценки — используем `godot-mcp`. Если это ошибка в чистой логике или расчётах — пишем
unit-тест и гоняем через `--headless`.

---

## 14. Коммит-месседжи и ветки

### Конвенция коммитов
Формат: `<тип>(<область>): <краткое описание>`

**Типы:**
- `feat` — новая фича
- `fix` — исправление бага
- `refactor` — рефакторинг без изменения поведения
- `test` — добавление/правка тестов
- `docs` — документация (включая `docs/`, `AGENT.md`, `README.md`)
- `chore` — тулзы, CI, инфраструктура (включая `openspec/`)
- `perf` — оптимизация производительности
- `style` — форматирование, отступы (без изменения логики)

**Области:** `battle`, `world`, `city`, `ui`, `economy`, `demographics`, `hero`, `ci`, `mcp`, `docs`, `tests`.

**Язык:** русский. Краткое описание — настоящее время, без точки в конце.

**Примеры:**
- `feat(battle): добавить фазу отступления в BattleFlow`
- `fix(world): HexUtils.distance возвращает 0 для одинаковых клеток`
- `test(battle): покрыть тестами BattleState.turn_end`
- `chore(ci): увеличить таймаут compile_all до 90 секунд`
- `docs(architecture): обновить схему слоёв`

### Ветки
- `main` — стабильная, только после полного CI и ревью.
- `dev` — рабочая, сливается в `main` по готовности фичи.
- `feat/<короткое-имя>` — ветки фич, отпочковываются от `dev`.
- `fix/<номер-или-имя>` — ветки фиксов.
- `experiment/<имя>` — throwaway-ветки для прототипов; не мержатся, удаляются после решения.

Перед мержем в `main`: полный CI зелёный, все тесты проходят, `mcp_interaction_server` выключен,
нет `tmp/` мусора в диффе.

### Взаимодействие агента с ветками
- **Агент коммитит напрямую в `dev`** (без PR) для мелких правок (баги, тесты, документация).
- **Для крупных фич** агент создаёт `feat/<имя>`-ветку, работает в ней, затем мержит в `dev`.
- **Мерж в `main`** — только человеком после ревью и полного CI.

---

## 15. OpenSpec

`openspec/` — каталог для спецификаций изменений до их реализации (design docs, API-контракты,
предложения по рефакторингу).

**Когда писать OpenSpec:**
- Изменение затрагивает **более одного слоя** из `ARCHITECTURE.md`.
- Меняется публичный API модуля, используемого ≥3 клиентами.
- Вводится новая подсистема или крупная переработка существующей.
- Изменение требует координации с другими подсистемами (например, бой + экономика).

**Когда НЕ писать OpenSpec:**
- Локальные баги в одном модуле.
- Добавление контента по существующему пайплайну (юниты, билдинги, спеллы — см.
  `docs/howto/ADDING_UNITS.md`).
- Рефакторинг в пределах одного файла/модуля без изменения API.

**Процесс:**
1. Создать `openspec/YYYY-MM-DD-<короткое-имя>.md` с описанием проблемы, вариантов решения,
   выбранного варианта и плана миграции.
2. Получить аппрув (для локального агента: **остановиться и запросить у человека** в комментариях к PR или в таск-трекере).
3. Реализовать в отдельной `feat/`-ветке.
4. После мержа обновить статус в спеке на `implemented` со ссылкой на коммит.

Спеки — живые документы. Устаревшие переносятся в `openspec/archive/`.

---

## 16. Модель разрешений агента

### Что агент может менять свободно (без запроса):
- Скрипты в `game/scripts/` (кроме `autoload/` — см. ниже)
- Тесты в `game/tests/`
- Инструменты в `game/tools/`
- Документацию в `docs/`
- OpenSpec-спеки в `openspec/`
- `AGENT.md` (с последующим уведомлением человека)

### Что требует явного запроса у человека:
- **`game/project.godot`** — любые изменения (автозагрузки, настройки движка, `export_presets.cfg`)
- **`game/scripts/autoload/`** — добавление/удаление/переименование синглтонов
- **CI-скрипты** (`game/tools/shell/`) — изменения логики проверок
- **`docs/CONSOLE_ALLOWLIST.md`** — добавление/удаление разрешённых предупреждений
- **`ARCHITECTURE.md`** — изменения архитектурных правил
- **Структура проекта** — перемещение директорий, переименование слоёв

### Приоритет документов при конфликте:
1. **`AGENT.md` (этот файл)** — высший приоритет, TL;DR в разделе 0 имеет абсолютный приоритет
2. **`docs/architecture/ARCHITECTURE.md`** — архитектурные правила
3. **`docs/howto/*.md`** — howto-гайды
4. **Комментарии в коде** — локальные уточнения

### Что делать при противоречии правил реальности:
Если правила из `AGENT.md` или `ARCHITECTURE.md` противоречат тому, что агент видит в коде
(например, код использует запрещённый паттерн, но работает):
1. **Остановиться** — не применять паттерн в новом коде
2. **Запросить у человека** — уточнить, является ли это легальным исключением или багом
3. **Задокументировать решение** — обновить `AGENT.md` или `ARCHITECTURE.md` после получения ответа

**Запрещено:** молча патчить код по шаблону из `AGENT.md`, если это ломает существующую логику.

---

## 17. Форматирование и линтинг

Проект **не использует** автоматический форматтер (`gdformat`) или линтер (`gdlint`).
Агент должен следовать стилю, установленному в существующем коде (см. разделы 2, 6).

Если в будущем будет внедрён форматтер:
- Запустить `gdformat game/scripts/` перед коммитом
- Добавить проверку в CI: `gdlint game/scripts/`
- Обновить этот раздел

---

## 18. Экспорт и релизные сборки

**Файл конфигурации экспорта:** `game/export_presets.cfg` (создаётся через Godot Editor:
Project → Export → Add).

**Правила:**
- `export_presets.cfg` **коммитится** в Git (содержит настройки экспорта, но не секреты).
- **Секреты** (API keys, passwords) — **никогда не коммитить**; использовать environment variables или `.env` файлы (gitignored).
- **MCP-сервер** (`mcp_interaction_server`) — **никогда не включать** в релизные сборки (проверяется машинно в 8.2).
- **Editor-only автозагрузки** (с `*` в `project.godot`) — автоматически отключаются в экспорте.

**Процесс релизной сборки:**
1. Убедиться, что `mcp_interaction_server` выключен в `project.godot`.
2. Запустить полный CI (`run_all_ci_checks.sh`) — зелёный.
3. Экспорт через Godot Editor или CLI: `godot --headless --path game --export-release "Linux/X11" builds/game.x86_64`
4. Протестировать экспортированную сборку на целевой платформе.

---

## Приложение A: Быстрый старт для агента

```bash
# 1. Клонировать репозиторий
git clone <repo-url>
cd <repo-name>

# 2. Проверить, что Godot установлен
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot  # macOS
# export GODOT=godot  # Linux

# 3. Запустить быстрый CI (sanity check)
bash game/tools/shell/run_all_ci_checks.sh --fast >/tmp/godot_run_fast.log 2>&1

# 4. Проверить лог
grep -E 'SCRIPT ERROR|Parse Error|SOME TESTS FAILED' /tmp/godot_run_fast.log && echo "❌ FAIL" || echo "✅ PASS"

# 5. Запустить полный CI (финальная верификация)
bash game/tools/shell/run_all_ci_checks.sh >/tmp/godot_run_full.log 2>&1

# 6. Проверить гейт (из раздела 8.2)
LOG=/tmp/godot_run_full.log
ERROR_RE='SCRIPT ERROR|Parse Error|Invalid call|Nonexistent function|Nonexistent class|Nonexistent base|Too many arguments|Cannot infer|Invalid get/set|Failed to load script|Can'"'"'t load script|Could not find type|does not inherit from|SOME TESTS FAILED|RESULT: FAILED'
if grep -qE "$ERROR_RE" "$LOG"; then
  echo "❌ Gate FAILED"
  exit 1
fi
echo "✅ Gate PASSED"
```

---

## Приложение B: Troubleshooting

### Проблема: `SCRIPT ERROR: Parse Error: Could not find type "BattleState"`
**Причина:** Реестр `class_name` не собран или протух.
**Решение:**
```bash
rm -rf game/.godot
bash game/tools/shell/run_all_ci_checks.sh  # Реестр пересоберётся автоматически
```

### Проблема: Процесс Godot зависает в CI (код 124)
**Причина:** Скрипт или сцена не завершаются корректно.
**Решение:**
1. Проверить, что `-s`-раннеры вызывают `quit()` в конце.
2. Проверить, что сцены используют `--quit-after N` (кадров).
3. Увеличить таймаут в `run_godot`, если легитимно долгая операция.

### Проблема: `Failed to instantiate an autoload … does not inherit from 'Node'`
**Причина:** Автозагрузка указана в `project.godot`, но скрипт не найден или не наследуется от `Node`.
**Решение:**
1. Проверить путь к скрипту в `project.godot`.
2. Убедиться, что скрипт наследуется от `Node` (для автозагрузок обязательно).
3. Пересобрать реестр: `rm -rf game/.godot && bash game/tools/shell/run_all_ci_checks.sh`.

### Проблема: `WARNING: 25 ObjectDB instances were leaked at exit`
**Причина:** Утечка `Node`-объектов (не вызван `free()` или `queue_free()`).
**Решение:**
1. Проверить тесты — для `Node` использовать `free()`, не `queue_free()`.
2. Проверить, что все добавленные в дерево ноды удаляются.
3. Если утечка ≤20 — это разрешено (см. `docs/CONSOLE_ALLOWLIST.md`).

### Проблема: MCP-сервер не отвечает
**Причина:** Сервер не запущен или биндится не на тот порт.
**Решение:**
1. Убедиться, что `mcp_interaction_server.gd` добавлен в AutoLoad (только для локальной dev-сессии!).
2. Проверить, что сервер биндится на `127.0.0.1:9090`.
3. Проверить firewall (порт 9090 должен быть открыт для localhost).
4. **После использования — выключить сервер в `project.godot`** (иначе гейт 8.2 упадёт).