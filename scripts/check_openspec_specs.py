"""Главная спека обязана быть спекой, а не дельтой (T-274).

`openspec/changes/<смена>/specs/**/spec.md` — дельта: там заголовки
`## ADDED|MODIFIED|REMOVED|RENAMED Requirements` правильные. `openspec/specs/**`
— сведённый носитель: там тот же заголовок ломает `openspec validate --strict`
(«Spec must have a Requirements section»), и 2026-10-27 в этот статус съехали
12 файлов, сведённых из архивированных смен.

Проверка нулевая, не рэтчет: дельта-заголовок в носителе — не степень, а факт.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MAIN_SPECS = REPO / "openspec" / "specs"
DELTA_HEADER = re.compile(r"^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*$", re.MULTILINE)
PURPOSE = re.compile(r"^## Purpose\s*$", re.MULTILINE)
REQUIREMENTS = re.compile(r"^## Requirements\s*$", re.MULTILINE)


def find_issues(text: str) -> list[str]:
    """Описание дефектов одной главной спеки: дельта-заголовки, отсутствие Purpose."""
    problems = [f"дельта-заголовок «{m.group(0).strip()}» в сведённой спеке"
                for m in DELTA_HEADER.finditer(text)]
    if not PURPOSE.search(text):
        problems.append("нет секции «## Purpose»")
    if not REQUIREMENTS.search(text) and not DELTA_HEADER.search(text):
        # Дельта уже названа выше: требовать от неё «## Requirements» — два раза о том же.
        problems.append("нет секции «## Requirements»")
    return problems


def main(argv: list[str]) -> int:
    bad: list[tuple[Path, list[str]]] = []
    files = sorted(MAIN_SPECS.glob("*/spec.md"))
    for path in files:
        problems = find_issues(path.read_text(encoding="utf-8"))
        if problems:
            bad.append((path, problems))
    for path, problems in bad:
        for problem in problems:
            print(f"  {path.relative_to(REPO)}: {problem}")
    print(f"OPENSPEC SPECS: {'RED — ' + str(len(bad)) + ' файл(ов) с дельта-структурой' if bad else 'OK'}"
          f" (проверено {len(files)} сведённых спек)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
