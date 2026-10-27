"""Тесты чекера связности `docs/` (`scripts/check_docs_links.py`).

Файл лежит в репо с смены `gdd-phase-workflow` (T-223): до него в списке уровней
`scripts/doc_gates.sh` значился `scripts/test_check_docs_links.py`, которого никогда
не существовало, а молчаливое выпадение отсутствующего файла из списка и есть тот
класс «зелёная проверка, которая ничего не проверила».

Что ломается молча, если тестов нет: граф wikilinks (битая ссылка = «документ
ссылается на то, чего нет» — ровно та дыра, что D-275 закрыл для `Q-M##`),
исключение банковской зоны, словарь статусов.

Запуск: `python3 -m pytest scripts/test_check_docs_links.py -q`
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_docs_links as chk  # noqa: E402


@pytest.fixture
def vault(tmp_path, monkeypatch):
    docs = tmp_path / "docs"
    (docs / "mvp").mkdir(parents=True)
    (docs / "bank").mkdir()
    (docs / "01-core-loop.md").write_text(
        "---\ntitle: Цикл\nstatus: verified\ndate: 2026-10-27\n---\n\n# Цикл\n"
        "Основание: [[02-mechanics]].\n", encoding="utf-8")
    (docs / "02-mechanics.md").write_text(
        "---\ntitle: Механики\nstatus: deepened\ndate: 2026-10-27\n---\n\n# Механики\n"
        "См. [[01-core-loop]].\n", encoding="utf-8")
    monkeypatch.setattr(chk, "DOCS", str(docs))
    monkeypatch.setattr(chk, "BANK_DIR", str(docs / "bank"))
    return docs


def _stems(files):
    return {Path(p).stem for p in files}


def test_valid_graph_is_clean(vault):
    files = chk.doc_files()
    assert chk.check_wikilinks(files, _stems(files)) == []
    assert chk.check_statuses(files) == []
    assert chk.check_filenames(files) == []


def test_broken_wikilink_is_found(vault):
    (vault / "01-core-loop.md").write_text(
        "---\ntitle: Цикл\nstatus: verified\n---\n\nСм. [[09-net-chto-takogo]].\n",
        encoding="utf-8")
    files = chk.doc_files()
    assert ("01-core-loop.md", "09-net-chto-takogo") in chk.check_wikilinks(files, _stems(files))


def test_wikilink_with_path_is_broken(vault):
    """Wikilink обязан быть без пути (AGENTS.md): `[[docs/02-mechanics]]` — ошибка."""
    (vault / "01-core-loop.md").write_text(
        "---\ntitle: Цикл\nstatus: verified\n---\n\nСм. [[docs/02-mechanics]].\n",
        encoding="utf-8")
    files = chk.doc_files()
    assert ("01-core-loop.md", "docs/02-mechanics") in chk.check_wikilinks(files, _stems(files))


def test_link_inside_inline_code_is_not_data(vault):
    """Пример в backticks — не ссылка: иначе архивные логи и доки-инструкции краснеют."""
    (vault / "01-core-loop.md").write_text(
        "---\ntitle: Цикл\nstatus: verified\n---\n\n`[[09-net-chto-takogo]]` — пример.\n",
        encoding="utf-8")
    files = chk.doc_files()
    assert chk.check_wikilinks(files, _stems(files)) == []


def test_archive_logs_are_out_of_the_graph_as_sources(vault):
    """Архивный лог не источник: цитата битой ссылки в логе не красит гейт."""
    (vault / "STRUCTURE_AUDIT.md").write_text(
        "Архивный лог: был [[09-net-chto-takogo]].\n", encoding="utf-8")
    files = chk.doc_files()
    sources = chk.source_files(files)
    assert "STRUCTURE_AUDIT.md" not in [Path(p).name for p in sources]
    assert chk.check_wikilinks(sources, _stems(files)) == []


def test_cyrillic_filename_is_found(vault):
    (vault / "Механики-старые.md").write_text("---\nstatus: draft\n---\n", encoding="utf-8")
    assert "Механики-старые.md" in chk.check_filenames(chk.doc_files())


def test_unknown_status_is_found_and_contour_statuses_are_allowed(vault):
    (vault / "01-core-loop.md").write_text(
        "---\ntitle: Цикл\nstatus: polyrenev\n---\n", encoding="utf-8")
    assert chk.check_statuses(chk.doc_files()) == [("01-core-loop.md", "polyrenev")]
    for st in ("audited", "verified", "locked", "canon"):
        (vault / "01-core-loop.md").write_text(
            f"---\ntitle: Цикл\nstatus: {st}\n---\n", encoding="utf-8")
        assert chk.check_statuses(chk.doc_files()) == []


def test_bank_zone_is_excluded(vault):
    """Банк вне чекера (D-102): его битые ссылки и статусы не гейтятся."""
    (vault / "bank" / "K-1.md").write_text(
        "---\ntitle: Банк\nstatus: kakoj-to\n---\n\n[[09-net-chto-takogo]]\n", encoding="utf-8")
    files = chk.doc_files()
    assert not any("/bank/" in p for p in files)
