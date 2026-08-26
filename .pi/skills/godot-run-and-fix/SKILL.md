---
name: godot-run-and-fix
description: Запускать проекты Godot в режиме отладки, захватывать вывод консоли (ошибки SCRIPT ERROR, parse errors, runtime crashes) и автоматически исправлять найденные проблемы. Использовать при работе с Godot-проектами для быстрой отладки и исправления ошибок.
---

# Godot Run & Fix

Автоматический запуск, захват ошибок и исправление Godot 4.x проектов.

## Быстрый старт

```bash
# Запустить проект и захватить ошибки
bash scripts/run_and_fix.sh <путь_к_проекту>

# Запустить с таймаутом (по умолчанию 30 сек)
bash scripts/run_and_fix.sh <путь_к_проекту> 15

# Запустить конкретную сцену или скрипт
bash scripts/run_and_fix.sh <путь_к_проекту> 30 -- --headless -s tests/debug_load.gd
```

## Как использовать

1. **Запустить проект** с помощью `run_and_fix.sh`:
   ```bash
   bash scripts/run_and_fix.sh /path/to/project
   ```

2. **Проанализировать вывод** — скрипт собирает ошибки и предупреждения в файлы:
   ```
   /tmp/godot_errors_<PID>.txt    — ошибки (SCRIPT ERROR, Invalid call, etc.)
   /tmp/godot_warnings_<PID>.txt  — предупреждения (WARNING, LEAK, deprecated, etc.)
   /tmp/godot_full_<PID>.txt      — полный лог (stdout + stderr)
   ```

3. **Исправить ошибки**:
   - `Parse error` → прочитать файл по пути, исправить синтаксис
   - `Cannot find member` → проверить API Godot 4.x, добавить `preload()`
   - `Variant inference` → добавить явные типы `: int`, `: String`
   - `Nonexistent function` → проверить имя метода или добавить функцию
   - `Indentation error` → исправить отступы (табы, не пробелы)

4. **Повторить** пока вывод не станет чистым

## Тесты

| Тест | Запуск | Назначение |
|------|--------|------------|
| `tests/debug_load.gd` | `-s tests/debug_load.gd` | Проверка загрузки скриптов + runtime-проверка методов |
| `tests/test_runtime_integration.gd` | `-s tests/test_runtime_integration.gd` | Загрузка World.tscn, проверка инициализации сцены |
| `tests/test_socket_protocol.gd` | `-s tests/test_socket_protocol.gd` | Проверка TCP-протокола (фреймирование, roundtrip) |

## Шаблоны исправлений

### Parse Error: Expected indented block
```gdscript
# Было:
func _on_signal() -> void:

# Стало:
func _on_signal() -> void:
	pass
```

### Variant inference error
```gdscript
# Было:
var count = some_dict[key]

# Стало:
var count: int = some_dict[key] as int
```

### Cannot find member / headless class_name
```gdscript
# Было:
var data := MySingleton.get_data()

# Стало:
const _MySingleton = preload("res://scripts/MySingleton.gd")
var data := _MySingleton.get_data()
```

### Nonexistent function (missing method)
```gdscript
# Ошибка: Invalid call. Nonexistent function 'get_avatar_texture' in base 'Node2D (HeroController)'
# Решение: добавить метод в класс
func get_avatar_texture() -> Texture2D:
	return null
```

### Coroutine in match
```gdscript
# Было:
match command:
	"init": return _init_command(args)  # _init_command has await

# Стало:
match command:
	"init": return await _init_command(args)
```

## Режимы запуска

| Режим | Флаг | Назначение |
|-------|------|------------|
| Headless | `--headless` | Без GUI, для отладки скриптов |
| Test server | `--headless --test-server` | TCP сервер на порту 9080 |
| Scene | `-s <путь>` | Запустить скрипт как entry point |
| Verbose | `--verbose` | Подробный вывод для диагностики |

## Захватываемые ошибки

### Ошибки (exit code = количество)
- `SCRIPT ERROR` — runtime-ошибки GDScript
- `Parse error` — синтаксические ошибки
- `Invalid call` — вызов несуществующего метода
- `Nonexistent function` — метод не найден
- `Cannot find` — пропущенный член класса
- `Too many arguments` — неверное количество аргументов
- `Cannot infer` — ошибка вывода типов
- `Nonexistent class` — пропущенный `class_name`
- `Invalid get/set` — обращение к несуществующему свойству
- `E 0:` — формат ошибки Godot 4

### Предупреждения (не влияют на exit code)
- `WARNING`, `NOTICE` — системные предупреждения
- `LEAK`, `leaked`, `ObjectDB.*leak` — утечки объектов
- `deprecated`, `deprecate` — устаревшие API
- `W 0:` — формат предупреждения Godot 4
