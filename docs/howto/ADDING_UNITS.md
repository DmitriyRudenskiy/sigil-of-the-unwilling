# Как добавить нового юнита

## 1. Добавить характеристики

Открыть `game/scripts/autoload/UnitRegistry.gd`.

Добавить запись в `UNITS`:

```gdscript
"my_unit": ["My Unit", 5, 18, 6, 2],
```

Формат: `[display_name, base_damage, hp, speed, defense]`

## 2. Добавить во фракцию

Добавить ключ юнита в один из `FACTION_SETS`, если юнит должен появляться у врагов.

## 3. Добавить портрет

Положить:
- `res://assets/units/my_unit.png` — большой портрет.
- `res://assets/units/my_unit_s.png` — маленький портрет.

## 4. Проверка

```bash
godot --headless -s tools/compile_all.gd
godot --headless -s tests/test_unit_registry.gd
```
