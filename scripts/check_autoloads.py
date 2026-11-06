#!/usr/bin/env python3
"""Префлайт автозагрузок (T-344): каждая запись `[autoload]` → существующий файл.

Причина: `static_caches.gd` держит идентификатор автозагрузки как литерал, и
несуществующий файл превращается не в «тихий скип», а в падение компиляции всего
проекта (прогон: 1 error + 1 failure, виновник — строка в project.godot). Проверка
дешёвая и ловит класс до GdUnit: опечатка в пути, переименованный носитель без
правки секции, пустая строка, оставшаяся после инжекта вендорного MCP-сервера.

Вызов: python3 scripts/check_autoloads.py [--project game/project.godot]
"""

from __future__ import annotations

import sys
from pathlib import Path


def autoloads(project: Path) -> list[tuple[str, str]]:
    """Пары (имя, путь) из секции [autoload] простого ini-вида project.godot."""
    rows: list[tuple[str, str]] = []
    in_section = False
    for line in project.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            in_section = line == "[autoload]"
            continue
        if in_section and line and not line.startswith(("#", ";")) and "=" in line:
            name, value = line.split("=", 1)
            rows.append((name.strip(), value.strip().strip('"')))
    return rows


def main(argv: list[str]) -> int:
    project = Path(argv[2] if len(argv) > 2 else "game/project.godot")
    if not project.is_file():
        print(f"AUTOLOADS: Красный — файл проекта не найден: {project}")
        return 1
    bad: list[str] = []
    for name, value in autoloads(project):
        target = value[1:] if value.startswith("*") else value
        if not target.startswith("res://"):
            bad.append(f"{name} = {value!r} — не res://-скрипт (пустая строка после инжекта?)")
        elif not (project.parent / target.removeprefix("res://")).is_file():
            bad.append(f"{name} = {value!r} — файла нет: {target}")
    if bad:
        print(f"AUTOLOADS: Красный — битых записей {len(bad)} (из {len(autoloads(project))}):")
        for row in bad:
            print(f"  - {row}")
        return 1
    print(f"AUTOLOADS: OK — записей {len(autoloads(project))}, все указывают на файл")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
