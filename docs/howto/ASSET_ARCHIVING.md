# Архивация неиспользуемых ассетов

Утилита `game/tools/analyze_assets.py` находит ассеты в `game/assets/`, на которые
**не ведёт ни один путь** из игры (ни `res://`-референсы в коде/сценах/конфах, ни
data-driven реестры — юниты из `units.json`, артефакты из `artifacts.json`, спрайты
юнитов из `*_unit.json`). Перемещает их в `_archive/` с manifest'ом отката и
требует прогона operability перед коммитом.

## Запуск

```bash
cd /Users/user/sigil-of-the-unwilling

# 1) Отчёт: какие ассеты считаются неиспользуемыми (без перемещения)
python3 game/tools/analyze_assets.py

# 2) Архивация: перемещает найденные ассеты (+ .import sidecar) в _archive/,
#    пишет manifest.json
python3 game/tools/analyze_assets.py --archive
```

### Категории и критерии

| Категория | Путь | Критерий «неиспользуем» |
|-----------|------|-------------------------|
| `raw` | `assets/raw/*` | Правиilo: всё что в `raw/` — неиспользуемо (исходники AI/картинок) |
| `units` | `assets/units/*` | PNG юнита не резолвится ни в одном `*_unit.json` (альта/замены) |
| `artifacts` | `assets/artifacts/*` | PNG артефакта нет в `artifacts.json` |
| `cursors` | `assets/cursors/*` | `cursor_XX.png` не встречается ни в одном `res://…` |
| `ui` | `assets/ui/*` | PNG не референсен ни в коде/сценах/конфах (кроме `_STAT_ICON`) |

### Как работает детекция

- **Static refs** — сканирует содержимое `.gd`, `.tscn`, `.tres`, `.json` на
  наличие `res://assets/…`. Если путь к ассету нигде не встречается — кандидат.
- **Data-driven** — парсит JSON-реестры (`units.json`, `artifacts.json`,
  `*_unit.json` и т.п.) и резолвит ожидаемые `*_unit.png` / PNG артефактов.

> `STATIC_EXTS` (`.gd`, `.tscn`, `.tres`, `.json`) — единый источник списка
> расширений для статического скана; правки тут же тянут и AGENT.md.

## Откат (rollback)

```bash
python3 game/tools/analyze_assets.py --restore
```

Задача 4.2: читает `_archive/manifest.json`, возвращает каждый перемещённый
ассет (+ `.import` sidecar) на исходный `res://`-путь, удаляет manifest.
Полная обратимость — `_archive/` это не потеря, а откладываемое перемещение.

## Перед коммитом — операционная проверка (обязательно)

Архивация **перемещает файлы**, поэтому после `--archive` нужно убедиться, что
игра не сломалась. Полный `run_operability.sh` долго гоняется (>10 мин) — в
рабочем порядке достаточно быстрой выборки:

1. **Юнит-тесты** — `run_godot 150 $GODOT --headless --path game -s tests/run_tests.gd`
   → `ALL TESTS PASSED`, `0 failed`.
2. **Сборка ссылок в сценах** — `run_godot 120 $GODOT --headless --path game -s tools/check_scene_refs.gd`
   → `scene refs check: N ok, 0 errors` (ни один удалённый ассет не упомянут в сцене).
3. **Компиляция** — `run_godot 120 $GODOT --headless --path game -s tools/compile_all.gd`
   → `compile check: N ok, 0 errors`.
4. **Загрузка ключевых сцен** — `run_godot 90 $GODOT --headless --path game -s tools/run_scene.gd`
   с `SCENE_PATH=scenes/{MainMenu,World,Battle,CityArena}.tscn` → `exit 0`,
   без `SCRIPT ERROR` / `missing` / `not loaded`.

Если что-то из этого **DIRTY** — значит удалённый ассет оказался нужен:
`python3 game/tools/analyze_assets.py --restore`, разберитесь почему детекция
пропустила референс, чините уту/реестр, потом заново.

Полный прогон для финальной верификации (после всех правок):
`run_godot 540 bash game/tools/shell/run_operability.sh` — должен быть `CLEAN`.
См. `docs/howto/OPERABILITY.md` и `docs/CONSOLE_ALLOWLIST.md`.

## Ограничения (ponytail)

- Детекция — эвристическая: static scan ловит `res://` в указанных расширениях,
  data-driven — по конкретным JSON-реестрам. Если ассет грузится через путь,
  собранный в рантайме из строки (не `res://`-литерал), детекция его пропустит.
  Поэтому **обязателен** прогон operability/тестов после архивации — он ловит
  реальные «missing asset» в рантайме.
- `_archive/` хранится в корне репозитория (не в `game/`), чтобы не раздувать
  игровой проект; каталог **отслеживается в Git** (`manifest.json` + перемещённые
  ассеты) — это и есть откат из истории. Игнорируются только `.import`-sideкары
  (см. корневой `.gitignore`: `**/*.import`), они пересобираются при импорте.
