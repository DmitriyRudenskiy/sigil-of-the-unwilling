# Тестирование

Корень Godot-проекта — `game/`. Все команды запускаются с `--path game`.
Тесты лежат в `game/tests/` (внутри Godot-проекта, отслеживаются в Git).

## Компиляция

```bash
godot --headless --path game -s tools/compile_all.gd
```

## Полный набор тестов

```bash
godot --headless --path game -s tests/run_tests.gd
# → "=== Total: N passed, 0 failed ===" / "ALL TESTS PASSED"
```

## Отдельные тесты

```bash
godot --headless --path game -s tests/test_hex_utils.gd
godot --headless --path game -s tests/test_unit_registry.gd
godot --headless --path game -s tests/test_map_model.gd
godot --headless --path game -s tests/test_battle_state.gd
godot --headless --path game -s tests/test_battle_ai.gd
godot --headless --path game -s tests/test_battle_integration.gd
```

## Отбор тестов

Флаги главного раннера (`tests/run_tests.gd`):

```bash
godot --headless --path game -s tests/run_tests.gd --filter battle   # файлы/методы, содержащие "battle"
godot --headless --path game -s tests/run_tests.gd --tag unit        # файлы с меткой tag(...)
godot --headless --path game -s tests/run_tests.gd --tag unit --tag slow  # несколько тегов (ИЛИ)
godot --headless --path game -s tests/run_tests.gd --list            # список файлов и test_*-методов без запуска
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

## Автономные SceneTree-раннеры

Запускаются сами через `godot -s` (главный раннер их пропускает —
`SKIP_FILES` в `tests/run_tests.gd`):

```bash
godot --headless --path game -s tests/test_runtime_integration.gd  # интеграция мира (асинхронная, ~4 с инициализация)
godot --headless --path game -s tests/test_audio_world_entry.gd   # audio smoke: world-entry SFX
godot --headless --path game -s tests/test_city_arena_view.gd     # headless-окно на World.tscn (арена города)
godot --headless --path game -s tests/test_validation_runner.gd   # валидация спеллов/карт
```

## CI-скрипты

```bash
bash tools/shell/run_all_ci_checks.sh          # полный CI (compile + refs + spell-validation + tileset + tests + console clean)
bash tools/shell/run_all_ci_checks.sh --fast   # быстрый CI (без тестов)
bash tools/shell/run_all_ci_checks.sh --tests  # только тесты
bash tools/shell/play_scenario.sh              # сценарные прогоны (default N=1)
```

## Ожидаемый результат

- Компиляция без ошибок.
- Проверка сцен без ошибок.
- Все тесты завершаются с кодом 0.
- Мир запускается и печатает `[World] Scene ready, seed=<N>` (сид мира).
