# Тестирование

## Компиляция

```bash
godot --headless -s tools/compile_all.gd
```

## Проверка сцен

```bash
godot --headless -s tools/check_scene_refs.gd
```

## Тесты

```bash
godot --headless -s tests/test_hex_utils.gd
godot --headless -s tests/test_unit_registry.gd
godot --headless -s tests/test_map_model.gd
godot --headless -s tests/test_battle_state.gd
godot --headless -s tests/test_battle_ai.gd
godot --headless -s tests/test_battle_integration.gd
```

## Smoke-тест мира

```bash
godot --headless res://scenes/World.tscn --autoquit
```

## Ожидаемый результат

- Компиляция без ошибок.
- Проверка сцен без ошибок.
- Все тесты завершаются с кодом 0.
- Мир запускается и печатает `[World] Scene ready.`.
