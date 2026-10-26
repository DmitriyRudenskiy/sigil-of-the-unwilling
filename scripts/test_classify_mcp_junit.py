"""Классификатор MCP-журнала (`classify_mcp_junit.py`, D-265): жёлтый — только readiness.

Тест держит границу «среда» / «регрессия»: если классификатор начнёт прощать что-то
кроме подписки `wait_ready`, гейт станет зелёным при настоящом падении, и это ровно то,
ради чего D-265 не приняли молча. Запускается из корня репо:
`python3 -m pytest scripts/test_classify_mcp_junit.py -q`."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import classify_mcp_junit as clf  # noqa: E402

# Ровно та строка, что упала 2026-10-26 в трёх прогонах гейта (gate_t219*.txt).
READY_MSG = (
    'failed on setup with "godot_mcp.MCPError: игра не готова за 180 с '
    '(последняя ошибка: тулз game_eval вернул ошибку: '
    'Not connected to game interaction server.)"'
)


def _junit(cases: str) -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<testsuites><testsuite name="pytest" tests="3" errors="0" failures="0">\n'
        + cases
        + "\n</testsuite></testsuites>\n"
    )


def _write(tmp_path: Path, body: str) -> Path:
    p = tmp_path / "junit-mcp.xml"
    p.write_text(_junit(body), encoding="utf-8")
    return p


def _case(name: str, inner: str = "") -> str:
    return '  <testcase classname="tests.mcp.test_x" name="%s">%s</testcase>' % (name, inner)


def test_clean_run_is_green(tmp_path: Path) -> None:
    p = _write(
        tmp_path,
        _case("test_a") + "\n" + _case("test_b", "<skipped message=\"по запросу\"/>"),
    )
    res = clf.classify([p])
    assert res["verdict"] == clf.GREEN
    assert res["counts"]["passed"] == 1
    assert res["counts"]["skipped"] == 1


def test_readiness_error_is_yellow_not_red(tmp_path: Path) -> None:
    p = _write(
        tmp_path,
        _case("test_a")
        + "\n"
        + _case("test_cluster_reset_in_battle_scene", "<error message=%r>trace</error>" % READY_MSG),
    )
    res = clf.classify([p])
    assert res["verdict"] == clf.YELLOW
    assert len(res["yellow"]) == 1
    assert "test_cluster_reset_in_battle_scene" in res["yellow"][0]
    assert res["red"] == []


def test_assertion_failure_is_red(tmp_path: Path) -> None:
    p = _write(
        tmp_path,
        _case("test_a", '<failure message="assert 1 == 2">trace</failure>'),
    )
    assert clf.classify([p])["verdict"] == clf.RED


def test_non_readiness_error_is_red(tmp_path: Path) -> None:
    # Тот же MCPError, но не readiness: узел не поднялся/тулз соврал — это регрессия.
    p = _write(
        tmp_path,
        _case(
            "test_a",
            '<error message=%r>trace</error>'
            % ('failed on setup with "godot_mcp.MCPError: тулз run_project вернул ошибку: boom"',),
        ),
    )
    assert clf.classify([p])["verdict"] == clf.RED


def test_mixed_readiness_and_failure_stays_red(tmp_path: Path) -> None:
    p = _write(
        tmp_path,
        _case("test_ready", "<error message=%r>t</error>" % READY_MSG)
        + "\n"
        + _case("test_real", '<failure message="assert">t</failure>'),
    )
    res = clf.classify([p])
    assert res["verdict"] == clf.RED
    assert len(res["yellow"]) == 1 and len(res["red"]) == 1


def test_teardown_error_is_red(tmp_path: Path) -> None:
    p = _write(
        tmp_path,
        _case("test_a", '<error message="failed on teardown with KeyError">t</error>'),
    )
    assert clf.classify([p])["verdict"] == clf.RED


def test_missing_file_is_not_silently_green(tmp_path: Path) -> None:
    assert clf.main(["classify_mcp_junit.py", str(tmp_path / "нет.xml")]) == 2


def test_unparsable_journal_is_not_silently_green(tmp_path: Path) -> None:
    p = tmp_path / "junit-mcp.xml"
    p.write_text("<testsuites><testsuite", encoding="utf-8")
    assert clf.main(["classify_mcp_junit.py", str(p)]) == 2


def test_no_arguments_is_not_silently_green() -> None:
    assert clf.main(["classify_mcp_junit.py"]) == 2


def test_yellow_exits_three_and_is_printed(tmp_path: Path, capsys: pytest.CaptureFixture) -> None:
    p = _write(tmp_path, _case("test_ready", "<error message=%r>t</error>" % READY_MSG))
    assert clf.main(["classify_mcp_junit.py", str(p)]) == 3
    out = capsys.readouterr().out
    assert clf.YELLOW in out
    # Жёлтый обязан быть назван по имени жертвы: «2 error» без имён неотличим от сокрытия.
    assert "test_ready" in out
    assert "MCP RED" not in out


def test_green_exits_zero_and_is_distinct_from_yellow(tmp_path: Path) -> None:
    # Разные коды нужны гейту: право снять красный с pytest есть только у жёлтого (3).
    p = _write(tmp_path, _case("test_a"))
    assert clf.main(["classify_mcp_junit.py", str(p)]) == 0


def test_pattern_list_is_single_sourced() -> None:
    # Расширение списка молча превращает жёлтое в свалку; каждый паттерн — замер.
    assert clf.READINESS_PATTERNS == ("игра не готова за",)
