# Тестирование

Корень Godot-проекта — `game/`. Все команды запускаются с `--path game`.
Тесты лежат в `game/tests/` (и `game/tests/unit/`) — GUT-скрипты,
наследники `tests/gut_base.gd`. Фреймворк: **GUT 9.7.1** в `game/addons/gut/`.

## Компиляция

```bash
godot --headless --path game -s tools/compile_all.gd
```

## Полный набор тестов

```bash
# Все флаги явно:
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Или «голый» запуск — GUT сам подхватит game/.gutconfig.json
# (dirs=res://tests, include_subdirs, should_exit):
godot --headless --path game -s addons/gut/gut_cmdln.gd
# → «---- All tests passed! ----» только при failing==0 && risky==0 && pending==0
```

## Отдельные тесты

```bash
godot --headless --path game -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_hex_utils.gd -gexit
godot --headless --path game -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_world_persistence.gd -gexit
```

## Отбор тестов

```bash
# По имени файла (подстрока) во всех каталогах:
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=battle -gexit
# По имени тест-метода (подстрока):
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gunit_test_name=survival -gexit
```

## Проверка сцен / данных / тайлкетов

```bash
godot --headless --path game -s tools/check_scene_refs.gd
godot --headless --path game -s tools/spell_validation/validate_spells.gd --strict --json
godot --headless --path game -s tools/check_tileset.gd
```

## Smoke-тесты миров

```bash
godot --headless --path game --scene scenes/World.tscn --quit-after 120
godot --headless --path game --scene scenes/MainMenu.tscn --quit-after 120
```

## Интеграционные тесты (внутри GUT)

Все ранние «автономные SceneTree-раннеры» теперь обычные GUT-тесты
(`await get_tree().create_timer(...)`, `before_all()` и т.д.):

```bash
godot --headless --path game -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_runtime_integration.gd -gexit
godot --headless --path game -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_world_entry.gd -gexit
```

`test_runtime_integration` грузит живой World.tscn — под GUT
`Platform.is_gut_run()` (CLI-аргументы `-gtest`/`-gdir`) подавляет
headless-авто-quit из `WorldController._handle_headless_exit()`, иначе
процесс умер бы на 1-й секунде. Сценарии гейта ходят через `--test-server`.

## Специфика GUT 9.7.1 (подводные камни)

- `GutTest` — потомок `Node`, НЕ SceneTree: `root` и `process_frame`
  как голые идентификаторы дают Parse Error. Писать `get_tree().root` /
  `await get_tree().process_frame`.
- `_ready()` на узлах, добавленных синхронно в headless-тесте, НЕ срабатывает
  (кадров нет) — UI для headless строить в `_init()`.
- `ClassDB.class_exists("<class_name>")` в контексте GUT возвращает false,
  а статические вызовы по class_name и через file-level `const preload()`
  падают (коллизия с `Object.get_name` и пр.). Рабочий паттерн:
  `const X := preload("res://...gd")` **внутри функции**.
- `push_error` падает тест; `printerr` — нет (но тест без ассертов станет
  `[Risky]`, а risky блокирует «All tests passed!»).
- Сигнальные ожидания (`assert_push_error`/`assert_engine_error`) объявлять
  **после** вызова, который шлёт сигнал.
- `stub()` не работает на статических методах скриптов (тихо не применяется).
- Не существует `assert_approx`/`assert_not_empty` — шимы в `tests/gut_base.gd`.
- Скрипт с Parse Error GUT молча игнорирует (`Ignoring script … does not
  extend GutTest`) — число «Scripts» в итоговой сводке сверяй с числом
  файлов в `tests/`.

## CI-скрипты

```bash
bash tools/shell/run_all_ci_checks.sh          # полный CI (compile + refs + spell-validation + tileset + GUT + console clean)
bash tools/shell/run_all_ci_checks.sh --fast   # быстрый CI (без тестов и console clean)
bash tools/shell/play_scenario.sh              # сценарные прогоны (default N=1)
```

Оба гейта (`run_all_ci_checks.sh` и `run_operability.sh`) гатят GUT-шаг
маркером `All tests passed!` в логе: скан ERROR/WARN-паттернов не видит
падение ассертов (GUT печатает `[Failed]:`, не `ERROR:`).

## Ожидаемый результат

- Компиляция без ошибок.
- Проверка сцен без ошибок.
- GUT: `Passing Tests == Tests`, маркер `All tests passed!`.
- Мир запускается и печатает `[World] Scene ready, seed=<N>` (сид мира).
