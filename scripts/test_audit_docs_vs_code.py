"""Тесты сверщика документации с кодом (`audit_docs_vs_code.py`).

Зачем: у гейта был найден собственный дефект — ratchet-проверка была записана
наоборот (allowlist сравнивался со списком *незадокументированных*, поэтому
«устаревшими» считались все имена, а при корректном наборе — наоборот, молча
зелёные). Такие баги не видно по выводу «всё чисто», поэтому поведение сверщика
фиксируется тестами, как и у классификатора MCP-журнала.

Запуск: `python3 -m pytest scripts/test_audit_docs_vs_code.py -q`
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_docs_vs_code as audit  # noqa: E402


@pytest.fixture
def world(tmp_path, monkeypatch):
    """Мини-репо: project.godot, один скрипт, одна сцена, три заметки."""
    game = tmp_path / "game"
    (game / "scenes" / "ui").mkdir(parents=True)
    (game / "scripts" / "campaign" / "save").mkdir(parents=True)
    (game / "scripts").mkdir(exist_ok=True)
    (game / "addons" / "vendor").mkdir(parents=True)
    (game / "project.godot").write_text(
        "[autoload]\n\nServices=\"*res://scripts/services.gd\"\n\n"
        "[input]\n\ncamera_up={\n\"deadzone\": 0.5\n}\n",
        encoding="utf-8",
    )
    (game / "scripts" / "services.gd").write_text("class_name ServiceHolder\n", encoding="utf-8")
    (game / "scripts" / "campaign" / "save" / "mvp_save_schema.gd").write_text(
        'const SECTIONS := {\n\t"campaign": TYPE_DICTIONARY,\n}\n', encoding="utf-8"
    )
    (game / "scenes" / "ui" / "battle_ui.tscn").write_text("[node name=\"BattleUI\"]\n", encoding="utf-8")
    (game / "addons" / "vendor" / "GdUnitCmdTool.gd").write_text("# vendor\n", encoding="utf-8")
    docs = tmp_path / "docs"
    docs.mkdir()
    monkeypatch.setattr(audit, "ROOT", tmp_path)
    monkeypatch.setattr(audit, "GAME", game)
    monkeypatch.setattr(audit, "DOCS", docs)
    monkeypatch.setattr(audit, "_allowlist", lambda: set())
    # Базлайн репозитория (146 имён) тестам неизвестен: пусть метрика стартует с нуля,
    # иначе рост нельзя ни разогнать, ни проверить.
    monkeypatch.setattr(audit, "_baseline", lambda: {"named_only_in_registries": 0})
    return tmp_path


def _write_doc(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def test_all_facts_documented_is_green(world):
    _write_doc(world / "docs" / "map.md",
               "Services, camera_up, battle_ui.tscn, campaign, ServiceHolder — всё названо.")
    res = audit.audit()
    assert res["undocumented"] == [], res
    assert res["doc_refs_absent_in_code"] == [], res
    assert audit.main_for() == 0


def test_missing_input_action_is_red(world):
    _write_doc(world / "docs" / "map.md", "Services, battle_ui.tscn, campaign.")
    res = audit.audit()
    assert sorted(r["name"] for r in res["undocumented"]) == ["ServiceHolder", "camera_up"], res
    assert audit.main_for() == 1


def test_broken_reference_is_red(world):
    _write_doc(world / "docs" / "map.md",
               "Services, camera_up, battle_ui.tscn, campaign. См. GoneScreen.gd")
    res = audit.audit()
    assert [r["name"] for r in res["doc_refs_absent_in_code"]] == ["GoneScreen.gd"], res


def test_absence_marker_line_is_not_a_broken_reference(world):
    _write_doc(world / "docs" / "map.md",
               "Services, camera_up, battle_ui.tscn, campaign.\n"
               "Панели decision_panel.tscn в репо нет, работает fallback.\n")
    res = audit.audit()
    assert res["doc_refs_absent_in_code"] == [], res


def test_registry_docs_are_historical(world):
    """Реестры вправе называть удалённые файлы: переписывать историю нельзя."""
    _write_doc(world / "docs" / "CHANGELOG.md", "Удалён GoneScreen.gd")
    _write_doc(world / "docs" / "map.md", "Services, camera_up, battle_ui.tscn, campaign.")
    res = audit.audit()
    assert res["doc_refs_absent_in_code"] == [], res


def test_vendor_paths_are_not_broken_references(world):
    _write_doc(world / "docs" / "map.md",
               "Services, camera_up, battle_ui.tscn, campaign. Прогон: GdUnitCmdTool.gd")
    res = audit.audit()
    assert res["doc_refs_absent_in_code"] == [], res


def test_allowlisted_class_is_yellow_not_red(world, monkeypatch):
    _write_doc(world / "docs" / "map.md", "Services, camera_up, battle_ui.tscn, campaign.")
    monkeypatch.setattr(audit, "_allowlist", lambda: {"ServiceHolder"})
    res = audit.audit()
    assert res["undocumented"] == [], res
    assert res["allowlist_stale"] == [], res


def test_allowlist_entry_that_became_documented_is_stale(world, monkeypatch):
    """Ratchet: имя задокументировали — запись обязана уехать из allowlist."""
    _write_doc(world / "docs" / "map.md",
               "Services, camera_up, battle_ui.tscn, campaign, ServiceHolder.")
    monkeypatch.setattr(audit, "_allowlist", lambda: {"ServiceHolder"})
    res = audit.audit()
    assert res["allowlist_stale"] == ["ServiceHolder"], res
    assert audit.main_for() == 1


def test_name_named_only_in_a_ticket_is_not_documented(world):
    """Упоминание в TICKETS — не документация (T-278).

    Аудит читал весь `docs/`, включая реестры и журналы, поэтому класс мог стать
    «задокументированным» одним упоминанием в теле тикета: зелёный вместо носителя.
    Такое имя не красится (реестр — не ложь), но попадает в отдельную опись.
    """
    _write_doc(world / "docs" / "map.md", "Services, camera_up, battle_ui.tscn, campaign.")
    _write_doc(world / "docs" / "mvp" / "TICKETS.md",
               "### T-9 · Про ServiceHolder\nносителю не место в тикете\n")
    res = audit.audit()
    assert res["undocumented"] == [], res
    assert [r["name"] for r in res["named_only_in_registries"]] == ["ServiceHolder"], res


def test_registry_only_count_is_a_ratchet(world, monkeypatch):
    """Рост описи красен, стагнация — нет: 146 чужих имён вычищаются не этим срезом."""
    _write_doc(world / "docs" / "map.md", "Services, camera_up, battle_ui.tscn, campaign.")
    _write_doc(world / "docs" / "mvp" / "TICKETS.md", "ServiceHolder назван здесь и больше нигде.")
    assert audit.main_for() == 1, "базлайн 0 и одно новое имя — гейт обязан краснеть"
    monkeypatch.setattr(audit, "_baseline", lambda: {"named_only_in_registries": 1})
    assert audit.main_for() == 0, "унаследованное имя не новый грех"


def test_allowlist_entry_named_only_in_a_ticket_is_not_stale(world, monkeypatch):
    """Allowlist чистится по живой заметке, иначе имя уходит из списка в никуда."""
    _write_doc(world / "docs" / "map.md", "Services, camera_up, battle_ui.tscn, campaign.")
    _write_doc(world / "docs" / "mvp" / "TICKETS.md", "ServiceHolder")
    monkeypatch.setattr(audit, "_allowlist", lambda: {"ServiceHolder"})
    res = audit.audit()
    assert res["allowlist_stale"] == [], res
    assert res["named_only_in_registries"] == [], res
    assert audit.main_for() == 0
