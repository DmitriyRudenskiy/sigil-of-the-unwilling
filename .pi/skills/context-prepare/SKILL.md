---
name: context-prepare
description: "Подготовка полного контекста проекта: склейка всех сцен и скриптов в один файл с абсолютными путями для передачи в LLM или другие инструменты."
---

# Подготовка контекста проекта

Склеить все `.gd` и `.tscn` файлы проекта в один файл-контекст с разделителями-путями.

## Быстрый старт

```bash
# Полный контекст проекта
bash .pi/skills/context-prepare/scripts/prepare.sh

# Только скрипты (без сцен)
bash .pi/skills/context-prepare/scripts/prepare.sh --scripts-only

# Исключить addon'ы и тесты
bash .pi/skills/context-prepare/scripts/prepare.sh --no-addons --no-tests

# Конкретные директории
bash .pi/skills/context-prepare/scripts/prepare.sh --dirs scripts/ui scripts/map
```

## Результат

Файл `/tmp/project_context.txt` содержит все скрипты и сцены в формате:
```
==========================================================================
ПУТЬ: /Users/user/GAMES_TROLES/game/scripts/map/MapController.gd
==========================================================================
[содержимое файла]
```

## Параметры

| Флаг | Описание |
|------|----------|
| `--scripts-only` | Только `.gd` файлы |
| `--no-addons` | Исключить `*/addons/*` |
| `--no-tests` | Исключить `*/tests/*` |
| `--no-tools` | Исключить `*/tools/*` |
| `--dirs <d1> <d2>` | Только указанные директории |
| `--output <path>` | Путь вывода (по умолчанию `/tmp/project_context.txt`) |

## Размер контекста

```bash
wc -l /tmp/project_context.txt
du -h /tmp/project_context.txt
```

## Использование

1. Запустить `prepare.sh` для генерации файла
2. Передать `/tmp/project_context.txt` как контекст в LLM
3. При необходимости отфильтровать по параметрам
