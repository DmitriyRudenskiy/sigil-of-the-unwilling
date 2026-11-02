#!/usr/bin/env python3
"""Самопроверка драйвера матрицы `scripts/scenario_matrix.py` (**T-238**).

Godot не нужен: разбор, план, сверка полноты, дубли и сравнение прогонов проверяются на
подставных строках того же формата, который печатает `game/tools/matrix_report.gd`.
Драйвер без этой самопроверки — тот же риск, что матрица без инструментов: молчаливый
недобор (2026-10-26: 11 строк `error=?` отработали кодом 0).

Запуск: `/home/user/.venv/godot-mcp-tests/bin/python -m pytest scripts/test_scenario_matrix.py -q`
(системный python3 pytest не содержит).
"""

import json
import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import scenario_matrix as sm  # noqa: E402


def row(role="collector", cls="fighter", **kw):
    parts = [f"class={cls}", f"seed={kw.get('seed', 11)}", f"turns={kw.get('turns', 7)}",
             f"survived={str(kw.get('survived', True)).lower()}",
             f"goal={str(kw.get('goal', True)).lower()}",
             f"goal_turn={kw.get('goal_turn', 5)}",
             f"error={kw.get('error', '')}"]
    for key, value in kw.items():
        if key not in ("seed", "turns", "survived", "goal", "goal_turn", "error"):
            parts.append(f"{key}={value}")
    return f"MATRIX|{'|'.join(parts)}"


INVENTORY = "\n".join(
    [f"MATRIX-CELL|role={role}|class={cls}|seed={100 + i}|turns={60 if role == 'collector' else 90}"
     for i, (role, cls) in enumerate(
         [(r, c) for r in ("collector", "traveler") for c in ("barbarian", "fighter", "rogue")])]
    + ["MATRIX-INV|roles=2|classes=3|cells=6"]
)


# ─────────────────────────────── разбор строк ───────────────────────────────


def test_parse_fields_coerces_and_keeps_equals():
    fields = sm.parse_fields("class=fighter|turns=12|goal=true|reason=бой: ход 3 = 0 урона")
    assert fields["class"] == "fighter"
    assert fields["turns"] == 12
    assert fields["goal"] is True
    assert fields["reason"] == "бой: ход 3 = 0 урона"


def test_parse_fields_rejoins_pipe_without_equals():
    # Значение с `|` внутри (текстовый `block=`) не должно рождать фантомное поле.
    fields = sm.parse_fields("class=fighter|block=нет места|во дворе|turns=3")
    assert fields["turns"] == 3
    assert fields["block"] == "нет места|во дворе"


def test_parse_run_tags_role_and_ignores_trace():
    stdout = "\n".join([
        "MATRIX-START|role=collector|turns=60|classes=2",
        row(cls="barbarian"),
        "MATRIX-BEAT|class=barbarian|turn=4",
        "MATRIX-SLOW|class=barbarian|turn=5|frames=900",
        "MATRIX-LEDGER|class=barbarian|level=1",
        row(cls="fighter"),
        "MATRIX-SUMMARY|class=SUMMARY|profiles=2|goal=2/2",
        "MATRIX-DETERMINISM|class=fighter|runs=2|same=true|hashes=a,b",
    ])
    parsed = sm.parse_run(stdout, "collector")
    assert [r["class"] for r in parsed["rows"]] == ["barbarian", "fighter"]
    assert all(r["role"] == "collector" for r in parsed["rows"])
    assert parsed["summary"]["profiles"] == 2
    assert parsed["determinism"][0]["same"] is True
    assert parsed["errors"] == []


def test_parse_run_collects_tool_errors():
    parsed = sm.parse_run("MATRIX-ERRORS|n=1|classes=rogue(?)", "trader")
    assert parsed["errors"] == ["n=1|classes=rogue(?)"]


# ─────────────────────────────── инвентарь ───────────────────────────────


def test_parse_inventory_reads_cells_and_checks_count():
    cells = sm.parse_inventory(INVENTORY)
    assert len(cells) == 6
    assert cells[0]["role"] == "collector" and cells[0]["turns"] == 60


def test_parse_inventory_without_inv_line_is_error():
    with pytest.raises(sm.MatrixError):
        sm.parse_inventory("MATRIX-CELL|role=collector|class=fighter|seed=1|turns=60")


def test_parse_inventory_count_mismatch_is_error():
    with pytest.raises(sm.MatrixError):
        sm.parse_inventory("MATRIX-CELL|role=collector|class=fighter|seed=1|turns=60\n"
                           "MATRIX-INV|roles=1|classes=1|cells=2")


def test_parse_inventory_duplicate_cell_is_error():
    with pytest.raises(sm.MatrixError):
        sm.parse_inventory(
            "MATRIX-CELL|role=collector|class=fighter|seed=1|turns=60\n"
            "MATRIX-CELL|role=collector|class=fighter|seed=2|turns=60\n"
            "MATRIX-INV|roles=1|classes=1|cells=2")


# ─────────────────────────────── план ───────────────────────────────


def test_plan_default_is_sample_one_class_per_role():
    selected, skipped = sm.plan(sm.parse_inventory(INVENTORY))
    assert len(selected) == 2 and not skipped
    assert {c["role"] for c in selected} == {"collector", "traveler"}
    assert {c["class"] for c in selected} == {"barbarian"}


def test_plan_full_takes_every_cell():
    selected, _ = sm.plan(sm.parse_inventory(INVENTORY), full=True)
    assert len(selected) == 6


def test_plan_roles_and_classes_intersect():
    inv = sm.parse_inventory(INVENTORY)
    selected, _ = sm.plan(inv, roles=["traveler"], classes=["fighter", "rogue"])
    assert sorted((c["role"], c["class"]) for c in selected) == [
        ("traveler", "fighter"), ("traveler", "rogue")]


def test_plan_cell_overrides_and_turns_override():
    inv = sm.parse_inventory(INVENTORY)
    selected, _ = sm.plan(inv, cell="rogue,traveler", turns=15)
    assert len(selected) == 1
    assert selected[0]["class"] == "rogue" and selected[0]["turns"] == 15


def test_plan_unknown_cell_is_error():
    with pytest.raises(sm.MatrixError):
        sm.plan(sm.parse_inventory(INVENTORY), cell="paladin,traveler")


def test_plan_expensive_switch_skips_pricely_cells():
    inv = sm.parse_inventory(INVENTORY)
    selected, skipped = sm.plan(inv, full=True, expensive="skip", expensive_above=60)
    assert {c["role"] for c in selected} == {"collector"}
    assert {c["role"] for c, _ in skipped} == {"traveler"}
    assert all("дорогая сцена" in why for _, why in skipped)


# ─────────────────────────────── сверка прогона ───────────────────────────────


def test_check_run_reports_missing_row_as_error_record():
    inv = sm.parse_inventory(INVENTORY)
    selected, _ = sm.plan(inv, roles=["collector"])
    records, problems = sm.check_run(selected, [{"role": "collector", "class": "barbarian"}])
    assert len(records) == 3
    assert problems and "нет строки прогона" in problems[0]
    missing = [r for r in records if r["error"] == "нет строки прогона"]
    assert len(missing) == 2


def test_check_run_reports_duplicate_and_ghost_rows():
    selected = [{"role": "collector", "class": "fighter"}]
    rows = [{"role": "collector", "class": "fighter"}, {"role": "collector", "class": "fighter"},
            {"role": "collector", "class": "wizard"}]
    _records, problems = sm.check_run(selected, rows)
    assert any("дубль строки" in p for p in problems)
    assert any("строка вне плана" in p for p in problems)


def test_cell_record_has_spec_shape():
    record = sm.cell_record({"class": "fighter", "role": "collector", "seed": 9, "turns": 6,
                             "survived": True, "goal": False, "goal_turn": -1, "error": "",
                             "secs": 4.5, "rare_nodes": 3, "hero": "alive"})
    assert set(record) == {"class", "role", "seed", "turns", "survived", "goal_met",
                           "goal_turn", "seconds", "error", "metrics"}
    assert record["goal_met"] is False
    assert record["seconds"] == 4.5
    assert record["metrics"] == {"hero": "alive", "rare_nodes": 3}


def test_cell_record_without_secs_leaves_seconds_empty():
    # Строка старой сборки (без `secs`) не должна превращать время в ноль: ноль — это
    # измерение, пустое поле — отсутствие измерения.
    assert sm.cell_record({"class": "a", "role": "r"})["seconds"] is None


def test_build_report_counts_goals_and_survived():
    records = [sm.cell_record({"class": "a", "role": "r", "survived": True, "goal": True}),
               sm.cell_record({"class": "b", "role": "r", "survived": False, "goal": False})]
    report = sm.build_report(records, {"roles": ["r"]}, "abc123", "tool")
    assert report["summary"] == {"cells": 2, "goal_met": "1/2", "survived": "1/2"}
    assert report["head_sha"] == "abc123"


# ─────────────────────────────── история и сравнение ───────────────────────────────


def rec(role="collector", cls="fighter", goal=True, survived=True, error=""):
    return {"role": role, "class": cls, "goal_met": goal, "survived": survived, "error": error}


def test_compare_cells_finds_goal_and_survival_regressions():
    regressions, improvements = sm.compare_cells(
        [rec(cls="a", goal=True, survived=True), rec(cls="b", goal=False)],
        [rec(cls="a", goal=False, survived=False), rec(cls="b", goal=True)])
    assert any("a: цель" in r for r in regressions)
    assert any("a: герой" in r for r in regressions)
    assert improvements == ["collector×b: цель достигнута впервые"]


def test_compare_cells_turn_drop_is_not_regression():
    old = [{"role": "r", "class": "a", "goal_met": True, "survived": True, "error": "", "turns": 40}]
    now = [{"role": "r", "class": "a", "goal_met": True, "survived": True, "error": "", "turns": 12}]
    regressions, _ = sm.compare_cells(old, now)
    assert regressions == []


def test_compare_cells_new_error_is_regression():
    regressions, _ = sm.compare_cells([rec()], [rec(error="бой-висяк")])
    assert len(regressions) == 1 and "бой-висяк" in regressions[0]


def test_previous_entry_matches_only_same_scope():
    entries = [{"scope": {"roles": ["collector"]}, "head_sha": "old", "cells": [rec()]},
               {"scope": {"roles": ["traveler"]}, "head_sha": "other", "cells": [rec()]}]
    assert sm.previous_entry(entries, {"roles": ["collector"]})["head_sha"] == "old"
    assert sm.previous_entry(entries, {"roles": ["builder"]}) is None


def test_history_roundtrip(tmp_path):
    path = tmp_path / "history.jsonl"
    sm.append_history(str(path), {"head_sha": "a", "cells": [rec()]})
    sm.append_history(str(path), {"head_sha": "b", "cells": [rec()]})
    entries = sm.load_history(str(path))
    assert [e["head_sha"] for e in entries] == ["a", "b"]
    assert json.loads(path.read_text(encoding="utf-8").splitlines()[1])["head_sha"] == "b"


def test_load_history_missing_file_is_empty(tmp_path):
    assert sm.load_history(str(tmp_path / "нет.jsonl")) == []
