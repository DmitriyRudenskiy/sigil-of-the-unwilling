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

## Проверка сцен / данных / тайлкетов

```bash
godot --headless --path game -s tools/check_scene_refs.gd
godot --headless --path game -s tools/spell_validation/validate_spells.gd --strict --json
godot --headless --path game -s tools/check_tileset.gd
```

## Smoke-тесты миров

```bash
godot --headless --path game --scene scenes/World.tscn --autoquit
godot --headless --path game --scene scenes/MainMenu.tscn --autoquit
```

## Автономные SceneTree-раннеры

Запускаются сами через `godot -s` (главный раннер их пропускает):

```bash
godot --headless --path game -s tests/test_runtime_integration.gd
godot --headless --path game -s tests/test_city_arena_view.gd
```

## CI-скрипты

```bash
bash tools/shell/run_all_ci_checks.sh      # полный CI (--fast / --tests)
bash tools/shell/play_scenario.sh          # сценарные прогоны (default N=1)
./tools/shell/run_all_ci_checks.sh         # full CI (compile + refs + spell-validation + tileset + tests)
```

## Ожидаемый результат

- Компиляция без ошибок.
- Проверка сцен без ошибок.
- Все тесты завершаются с кодом 0.
- Мир запускается и печатает `[World] Scene ready.`.
