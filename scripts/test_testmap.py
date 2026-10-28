"""Тесты самого носителя `scripts/testmap.py` (T-227).

Метрики карты тестов используются как рэтчет, поэтому их обязан проверять тест:
иначе «покрытие выросло» можно будет заявить, не изменив ни одного теста, — ровно тот
класс дефекта, из-за которого `q_ghost_rows` и `check_docs_links` получили свои тесты.
"""
from __future__ import annotations

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import testmap as tm  # noqa: E402


def _mk(tmp_path: pathlib.Path, files: dict[str, str]) -> pathlib.Path:
    for rel, text in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    return tmp_path / "game"


def _patch(monkeypatch, game: pathlib.Path):
    monkeypatch.setattr(tm, "GAME", game)
    monkeypatch.setattr(tm, "SCRIPTS", game / "scripts")
    monkeypatch.setattr(tm, "TESTS", game / "tests")
    monkeypatch.setattr(tm, "ROOT", game.parent)


def test_coverage_finds_holes_and_skips_service_paths(monkeypatch, tmp_path):
    game = _mk(tmp_path, {
        "game/scripts/core/alpha.gd": "class_name Alpha\nfunc a() -> void:\n\tpass\n",
        "game/scripts/core/beta.gd": "func b() -> void:\n\tpass\n",
        "game/scripts/core/orphan.gd": "func c() -> void:\n\tpass\n",
        "game/scripts/build/gen_thing.gd": "func d() -> void:\n\tpass\n",
        "game/tests/unit/test_alpha.gd":
            "extends BaseTest\nfunc test_alpha() -> void:\n\tAlpha.new()\n",
        "game/tests/unit/test_beta.gd":
            "extends BaseTest\nfunc test_beta() -> void:\n"
            '\tvar s := preload("res://scripts/core/beta.gd")\n',
    })
    _patch(monkeypatch, game)
    cov = tm.coverage()
    assert cov["covered"] == 2
    # orphan — единственная настоящая дыра; gen_thing исключён как генератор
    assert cov["holes"] == ["scripts/core/orphan.gd"]
    assert cov["production_files"] == 3


def test_autoload_singleton_is_named_by_its_registered_name(monkeypatch, tmp_path):
    """У автозагрузки без `class_name` имя из `project.godot` — единственное, чем её
    может назвать тест: `HexGrid.shift_right()` не содержит ни `res://…/hex_grid.gd`,
    ни `class_name`. Без этого правила четыре синглтона выглядели вечно открытыми
    дырами (T-227 С-5)."""
    game = _mk(tmp_path, {
        "game/project.godot":
            '[application]\nconfig/name="x"\n\n[autoload]\n\n'
            'HexGrid="*res://scripts/autoload/hex_grid.gd"\n'
            'CursorController="*res://scripts/autoload/cursor_controller.gd"\n'
            '\n[rendering]\n',
        "game/scripts/autoload/hex_grid.gd": "extends Node\nfunc shift_right() -> void:\n\tpass\n",
        "game/scripts/autoload/cursor_controller.gd": "extends Node\nfunc f() -> void:\n\tpass\n",
        "game/tests/unit/core/test_static_caches.gd":
            "extends BaseTest\nfunc test_grid() -> void:\n\tHexGrid.shift_right()\n",
    })
    _patch(monkeypatch, game)
    cov = tm.coverage()
    assert tm.autoload_names()["res://scripts/autoload/hex_grid.gd"] == "HexGrid"
    assert cov["holes"] == ["scripts/autoload/cursor_controller.gd"]


def test_merge_group_needs_three_files_and_the_most_specific_carrier(monkeypatch, tmp_path):
    files = {
        "game/scripts/world/foo.gd": "func x() -> void:\n\tpass\n",
        "game/scripts/world/foo_bar.gd": "func y() -> void:\n\tpass\n",
    }
    for n in "abc":
        files[f"game/tests/unit/test_foo_{n}.gd"] = f"extends BaseTest\nfunc test_{n}() -> void:\n\tpass\n"
    for n in "xyz":
        files[f"game/tests/unit/test_foo_bar_{n}.gd"] = f"extends BaseTest\nfunc test_{n}() -> void:\n\tpass\n"
    _patch(monkeypatch, _mk(tmp_path, files))
    groups = dict(tm.merges())
    assert sorted(groups["scripts/world/foo.gd"]) == ["test_foo_a.gd", "test_foo_b.gd", "test_foo_c.gd"]
    # test_foo_bar_* принадлежит foo_bar, а не более короткому foo
    assert len(groups["scripts/world/foo_bar.gd"]) == 3


def test_two_files_on_one_carrier_is_not_a_merge_candidate(monkeypatch, tmp_path):
    files = {
        "game/scripts/world/foo.gd": "func x() -> void:\n\tpass\n",
        "game/tests/unit/test_foo_a.gd": "extends BaseTest\nfunc test_a() -> void:\n\tpass\n",
        "game/tests/unit/test_foo_b.gd": "extends BaseTest\nfunc test_b() -> void:\n\tpass\n",
    }
    _patch(monkeypatch, _mk(tmp_path, files))
    assert tm.merges() == []


def test_ambiguous_attribution_is_not_reported(monkeypatch, tmp_path):
    # ни в имени теста, ни в явном приоритете носителя — оба упоминаются одинаково
    files = {
        "game/scripts/world/one.gd": "class_name One\nfunc x() -> void:\n\tpass\n",
        "game/scripts/world/two.gd": "class_name Two\nfunc y() -> void:\n\tpass\n",
    }
    for n in "abc":
        files[f"game/tests/unit/test_mixed_{n}.gd"] = (
            "extends BaseTest\nfunc test_a() -> void:\n\tOne.new()\n\tTwo.new()\n"
        )
    _patch(monkeypatch, _mk(tmp_path, files))
    assert tm.merges() == []


BODY = (
    "extends BaseTest\n"
    "func test_same() -> void:\n"
    "\tvar s := System.new()\n"
    "\ts.run(3)\n"
    '\tassert_int(s.total).is_equal(3)\n'
    '\tassert_str(s.state).is_equal("done")\n'
    "\tassert_bool(s.ok).is_true()\n"
    "\tassert_that(s.empty).is_false()\n"
)
OTHER = (
    "extends BaseTest\n"
    "func test_other() -> void:\n"
    "\tvar q := Other.new()\n"
    "\tq.step(4)\n"
    '\tassert_int(q.total).is_equal(4)\n'
    '\tassert_str(q.state).is_equal("idle")\n'
    "\tassert_bool(q.ok).is_true()\n"
    "\tassert_that(q.empty).is_false()\n"
)


def test_duplicate_bodies_count_only_across_files(monkeypatch, tmp_path):
    files = {
        "game/scripts/core/sys.gd": "class_name System\nfunc x() -> void:\n\tpass\n",
        "game/tests/unit/test_a.gd": BODY,
        "game/tests/unit/test_b.gd": BODY.replace("test_same", "test_b"),
        # совпадение внутри одного файла — не межфайловый дубль: два разных сценария
        # могут быть написаны одинаково, и это вопрос к чтению, а не к удалению
        "game/tests/unit/test_c.gd": OTHER + "\n" + OTHER.replace("test_other", "test_c2"),
    }
    _patch(monkeypatch, _mk(tmp_path, files))
    dup = tm.duplicates()
    assert len(dup) == 1
    assert sorted(x.split("::")[0].split("/")[-1] for x in dup[0]) == ["test_a.gd", "test_b.gd"]


def test_trivial_bodies_are_not_duplicates(monkeypatch, tmp_path):
    tiny = "extends BaseTest\nfunc test_a() -> void:\n\tassert_true(true)\n"
    _patch(monkeypatch, _mk(tmp_path, {
        "game/scripts/core/sys.gd": "func x() -> void:\n\tpass\n",
        "game/tests/unit/test_a.gd": tiny,
        "game/tests/unit/test_b.gd": tiny.replace("test_a", "test_b"),
    }))
    assert tm.duplicates() == []


def test_baseline_snapshot_carries_the_ratchet_keys(monkeypatch, tmp_path):
    game = _mk(tmp_path, {
        "game/scripts/core/alpha.gd": "class_name Alpha\nfunc a() -> void:\n\tpass\n",
        "game/scripts/core/orphan.gd": "func c() -> void:\n\tpass\n",
        "game/tests/unit/test_alpha.gd": "extends BaseTest\nfunc test_a() -> void:\n\tAlpha.new()\n",
    })
    _patch(monkeypatch, game)
    root = game.parent
    monkeypatch.setattr(tm, "ROOT", root)
    (root / "scripts").mkdir(exist_ok=True)
    assert tm.main(["--write-baseline"]) == 0
    snap = json.loads((root / "scripts" / "testmap.baseline.json").read_text(encoding="utf-8"))
    assert snap["gd_files"] == 1 and snap["gd_tests"] == 1
    assert snap["holes"] == 1
    assert {"merge_groups", "merge_files", "duplicate_groups", "py_files", "py_tests"} <= set(snap)


BLANK_PREFIX = (
    "extends BaseTest\n"
    "func test_a() -> void:\n"
    "\tvar s := System.new()\n"
    "\ts.boot()\n"
    "\n"
    "\tassert_int(s.a).is_equal(1)\n"
    "\tassert_bool(s.ok).is_true()\n"
    "\tassert_that(s.one).is_false()\n"
)
BLANK_PREFIX_B = BLANK_PREFIX.replace("test_a", "test_b").replace("s.a).is_equal(1)", "s.b).is_equal(2)")


def test_shared_prefix_before_blank_line_is_not_a_duplicate(monkeypatch, tmp_path):
    """Общая фикстура двух разных сценариев — не дубль.

    Метрика когда-то резала тело по первой пустой строке: оставался префикс, и любая
    пара тестов с общим setup объявлялась дублем (на реальном наборе — 5 «дублей»,
    из них настоящих 2). Порог длины этот дефект не ловил: префикс длиннее 60 символов.
    """
    _patch(monkeypatch, _mk(tmp_path, {
        "game/scripts/core/sys.gd": "class_name System\nfunc x() -> void:\n\tpass\n",
        "game/tests/unit/test_a.gd": BLANK_PREFIX,
        "game/tests/unit/test_b.gd": BLANK_PREFIX_B,
    }))
    assert tm.duplicates() == []


def _measure(holes=1, merge_files=0, dupes=0):
    """Синтетический вывод measure() — ровно той формы, что читает snapshot()."""
    return {
        "gd_files": 2, "gd_tests": 4, "py_files": 1, "py_tests": 2,
        "coverage": {"production_files": 5, "covered": 5 - holes,
                     "holes": ["scripts/core/x%d.gd" % i for i in range(holes)]},
        "merge_groups": [("scripts/core/sys.gd", ["a", "b", "c"])] if merge_files else [],
        "duplicates": [["x::t", "y::t"]] * dupes,
    }


BASE = {"gd_files": 2, "gd_tests": 4, "py_files": 1, "py_tests": 2,
        "holes": 1, "merge_groups": 0, "merge_files": 0, "duplicate_groups": 0}


def test_check_passes_at_baseline():
    code, lines = tm.check(_measure(), dict(BASE))
    assert code == 0
    assert lines[0].startswith("TESTMAP OK")


def test_check_fails_on_new_hole_and_names_the_metric():
    code, lines = tm.check(_measure(holes=2), dict(BASE))
    assert code == 1
    assert any("holes: было 1 → стало 2" in ln for ln in lines)


def test_check_fails_on_new_fragmentation_file():
    """Третий (четвёртый) файл на одном носителе — регрессия, а не «норм, новый тест».
    Именно эту ветку рэтчет заводит: файл на тикет вместо файла на носителя."""
    code, lines = tm.check(_measure(merge_files=3), dict(BASE))
    assert code == 1
    assert any("merge_files" in ln for ln in lines)


def test_check_fails_on_new_duplicate():
    code, lines = tm.check(_measure(dupes=1), dict(BASE))
    assert code == 1
    assert any("duplicate_groups" in ln for ln in lines)


def test_check_accepts_improvement_but_asks_to_rebase():
    base = dict(BASE, holes=4)
    code, lines = tm.check(_measure(holes=1), base)
    assert code == 0
    assert "holes 4→1" in lines[0] and "--write-baseline" in lines[0]


def test_check_without_baseline_is_red_not_silent():
    code, lines = tm.check(_measure(), None)
    assert code == 2 and "не зафиксирован" in lines[0]


def test_check_baseline_key_set_must_match_metrics():
    """Тот же урок, что D-277 в gdd_gate: молча отсутствующий ключ — это «ноль
    допусков» или «метрику убрали и забыли», а не проверка."""
    code, lines = tm.check(_measure(), {"holes": 1})
    assert code == 2 and "НЕ СООТВЕТСТВУЕТ МЕТРИКАМ" in lines[0]
    code, lines = tm.check(_measure(), dict(BASE, q_ghost_rows=0))
    assert code == 2 and "лишних" in lines[0] and "q_ghost_rows" in lines[0]
