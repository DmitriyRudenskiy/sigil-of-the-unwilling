"""Тесты самого носителя `scripts/check_openspec_specs.py` (T-274).

Проверщик — нулевой гейт структуры сведённых спек, поэтому его собственные суждения
обязаны быть тестом: без него «в носителе дельта» и «в носителе нет Purpose» можно
было бы объявлять по вкусу, а носитель, съехавший с формата, молча переживает
ещё одну архивацию смены — ровно так 2026-10-27 и появились 12 битых файлов.
"""
from __future__ import annotations

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_openspec_specs as cs  # noqa: E402

GOOD = """# x Specification

## Purpose

Назначение.

## Requirements

### Requirement: Что-то SHALL работать

Что-то SHALL работать при любых данных.
"""


def test_clean_spec_has_no_issues() -> None:
    assert cs.find_issues(GOOD) == []


def test_delta_headers_are_rejected_in_main_spec() -> None:
    for verb in ("ADDED", "MODIFIED", "REMOVED", "RENAMED"):
        broken = GOOD.replace("## Requirements", f"## {verb} Requirements")
        problems = cs.find_issues(broken)
        assert any("дельта-заголовок" in p and verb in p for p in problems), verb


def test_missing_purpose_is_named_separately_from_delta_header() -> None:
    """Два дефекта не должны сворачиваться в один: чинить их надо разными правками."""
    no_purpose = GOOD.split("## Purpose\n\nНазначение.\n\n", 1)[1]
    assert cs.find_issues(no_purpose) == ["нет секции «## Purpose»"]
    both = no_purpose.replace("## Requirements", "## ADDED Requirements")
    problems = cs.find_issues(both)
    assert len(problems) == 2 and any("ADDED" in p for p in problems)


def test_russian_heading_is_not_mistaken_for_the_section() -> None:
    """`## Требования` — не тот заголовок: валидатор openspec смотрит на английский."""
    assert cs.find_issues(GOOD.replace("## Requirements", "## Требования")) == [
        "нет секции «## Requirements»"
    ]


def test_delta_header_is_reported_once_not_twice() -> None:
    """Дельта и «нет секции Requirements» — один и тот же промах, дважды о нём молоть
    вредно: правка одна (переименовать заголовок), и отчёт обязан вести к ней."""
    delta_only = GOOD.replace("## Requirements", "## ADDED Requirements")
    problems = cs.find_issues(delta_only)
    assert len(problems) == 1 and "дельта-заголовок" in problems[0]


def test_repo_carrier_is_clean() -> None:
    """Носитель обязан быть чистым: это и есть инвариант, который защищает гейт."""
    bad = []
    for path in sorted(cs.MAIN_SPECS.glob("*/spec.md")):
        problems = cs.find_issues(path.read_text(encoding="utf-8"))
        if problems:
            bad.append(f"{path.parent.name}: {problems}")
    assert bad == [], "сведённые спеки с дельта-структурой:\n" + "\n".join(bad)


def test_delta_headers_remain_legal_in_changes() -> None:
    """Обратная половина правила: в changes/ дельта-заголовки живы — значит проверка
   scope'ится сведёнными спеками, а не всем openspec/ подряд."""
    deltas = [p for p in (cs.REPO / "openspec" / "changes").glob("*/specs/*/spec.md")
              if cs.DELTA_HEADER.search(p.read_text(encoding="utf-8"))]
    assert deltas, "в changes/ не осталось ни одной дельты — под вопросом сам критерий"
