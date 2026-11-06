"""Самопроверка check_autoloads.py (T-344): предпроверка обязана краснеть сама.

Канон 15 записей проходит; пропажа, лишняя (вендорный инжект) и перестановка
записи — красные. Парсер обязан читать только секцию [autoload] и не ловить
имена из чужих секций project.godot.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_autoloads as ca  # noqa: E402


def _project_text(autoload_lines: list) -> str:
    """Синтетический project.godot: секции до/после, внутри — заданные записи."""
    head = "\n".join([
        "config_version=5",
        "",
        "[application]",
        'config/name="Sigil of the Unwilling"',
        "",
    ])
    tail = "\n".join([
        "",
        "[display]",
        "window/size/viewport_width=1280",
        "",
        "[rendering]",
        'renderer/rendering_method="gl_compatibility"',
    ])
    body = "\n".join(autoload_lines)
    return f"{head}\n[autoload]\n{body}\n{tail}\n"


def _line(name: str) -> str:
    return f'{name}="*res://scripts/autoload/{name.lower()}.gd"'


def test_canonical_fifteen_pass():
    lines = [_line(n) for n in ca.EXPECTED]
    assert ca.check(_project_text(lines)) == []


def test_missing_record_is_red():
    lines = [_line(n) for n in ca.EXPECTED if n != "HexCellArtCache"]
    problems = ca.check(_project_text(lines))
    assert len(problems) == 1
    assert "нет записей" in problems[0]
    assert "HexCellArtCache" in problems[0]


def test_vendor_inject_extra_record_is_red():
    lines = [_line(n) for n in ca.EXPECTED]
    lines.append('VendorInject="*res://addons/vendor/inject.gd"')
    problems = ca.check(_project_text(lines))
    assert len(problems) == 1
    assert "лишние записи" in problems[0]
    assert "VendorInject" in problems[0]


def test_reordered_records_are_red():
    lines = [_line(n) for n in ca.EXPECTED]
    lines[0], lines[1] = lines[1], lines[0]
    problems = ca.check(_project_text(lines))
    assert len(problems) == 1
    assert "порядок" in problems[0]


def test_parser_reads_only_autoload_section():
    # Имя HexGrid встречается в других секциях — парсер не должен его съесть.
    text = "\n".join([
        "[application]",
        'config/name="HexGrid"',
        "",
        "[autoload]",
        _line("Settings"),
        "",
        "[editor_plugins]",
        "enabled=PackedStringArray()",
    ])
    assert ca.parse_autoloads(text) == ["Settings"]


def test_canonical_real_file_passes():
    # Настоящее дерево: файл лежит в game/ относительно корня репо.
    real = Path(__file__).resolve().parents[1] / "game" / "project.godot"
    if not real.exists():
        return  # самопроверка исполнима и вне полного дерева (только синтетика)
    assert ca.check(real.read_text(encoding="utf-8")) == []
