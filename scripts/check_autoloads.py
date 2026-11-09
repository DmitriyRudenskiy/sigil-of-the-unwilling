#!/usr/bin/env python3
"""Предпроверка автолоадов project.godot (T-344).

Гейт умел молча портить project.godot: вендорный MCP-сервер инжектит
autoload-строку, а cleanup делал `git checkout -- project.godot`, сносивший
заодно и незакоммиченные правки носителя (инцидент 2026-11-06). Снапшот +
восстановление в trap снимают саму порчу; эта предпроверка ловит ЕЁ РЕЗУЛЬТАТ
до прогона: секция `[autoload]` — закрытый набор из 15 записей, и GdUnit без
автолоадов не спорит, а молча краснеет.

Расхождение с каноном — красный гейт, а не молчаливая подмена (тот же смысл,
что «клетки нет в манифесте» у прежнего носителя). Порядок записей — тоже
факт дерева: перестановка автолоадов меняет порядок инициализации.

Самопроверка: scripts/test_check_autoloads.py (python-уровень CHECKERS в game/run_tests.sh).
"""
from __future__ import annotations

import re
import sys

# Канон секции [autoload]: 15 записей, порядок = порядок в project.godot.
EXPECTED = [
    "McpInteractionServer",
    "Settings",
    "SoundManager",
    "GameEventBus",
    "Spellbook",
    "PauseController",
    "CursorController",
    "TemplateBootstrap",
    "Units",
    "Artifacts",
    "Spells",
    "Resources",
    "Services",
    "HexCellArtCache",
    "HexGrid",
]


def parse_autoloads(text: str) -> list:
    """Имена автолоадов из текста project.godot, в порядке следования."""
    names: list = []
    in_section = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            in_section = stripped == "[autoload]"
            continue
        if not in_section or not stripped or stripped[:1] in (";", "#"):
            continue
        matched = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"', stripped)
        if matched:
            names.append(matched.group(1))
    return names


def check(text: str) -> list:
    """Список расхождений с каноном; пустой список = секция канонична."""
    names = parse_autoloads(text)
    problems: list = []
    if names == EXPECTED:
        return problems
    missing = [n for n in EXPECTED if n not in names]
    extra = [n for n in names if n not in EXPECTED]
    if missing:
        problems.append(f"нет записей: {missing}")
    if extra:
        problems.append(f"лишние записи (вендорный инжект?): {extra}")
    if not missing and not extra:
        problems.append(f"порядок записей изменился: {names}")
    return problems


def main(argv: list) -> int:
    path = argv[1] if len(argv) > 1 else "game/project.godot"
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as exc:
        print(f"AUTOLOAD-PRECHECK: RED — {path} не читается: {exc}")
        return 1
    problems = check(text)
    if problems:
        print(f"AUTOLOAD-PRECHECK: RED — секция [autoload] не канон ({len(EXPECTED)} записей):")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"AUTOLOAD-PRECHECK: OK ({len(EXPECTED)} записей)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
