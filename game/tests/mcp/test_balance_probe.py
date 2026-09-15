"""balance-core: MCP-автопрогонка ранней игры.

Hard-fail только на техсбоях (смерть героя, затык автоигрока, MCP-ошибка,
таймаут). Нарушение порогов метрик — warning в отчёте, не fail (калибровка
делается по отчёту, см. openspec/changes/balance-core).
"""
from __future__ import annotations

import json
import time
from pathlib import Path

from conftest import MCPError

PROBE_SEED = 20260913
REPORT_OUT = Path(__file__).parent.parent.parent / "tools" / "mcp" / "reports"
PROBE_TIMEOUT_S = 420.0

START_PROBE = """
var w = get_tree().current_scene
if w == null or w.get_hero() == null:
    return {"error": "world not ready"}
var probe = get_node_or_null("/root/BalanceProbe")
if probe == null or probe.get_script() == null or not str(probe.get_script().resource_path).contains("BalanceProbe"):
    return {"error": "probe node not found — instantiate_scene не запущен"}
w.set_meta("balance_probe", probe)
var r = probe.start_probe(w, __SEED__)
return r
""".replace("__SEED__", str(PROBE_SEED))

PROBE_STATE = """
var w = get_tree().current_scene
var probe = w.get_meta("balance_probe") if w != null else null
if probe == null:
    return {"error": "no probe"}
return probe.report()
"""

PROBE_REPORT_FILE = """
var w = get_tree().current_scene
var probe = w.get_meta("balance_probe") if w != null else null
if probe == null:
    return ""
var s = probe.read_report_text()
return s
"""


def _wait_world(mcp, timeout: float = 180.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        r = mcp.execute_code(
            "var w = get_tree().current_scene\n"
            "return {\"hero\": w != null and w.get_hero() != null}"
        )
        if r.get("hero"):
            return
        time.sleep(1.0)
    raise MCPError("World не завершил ботстлаб за %.0f с" % timeout)


def _save_report(report: dict, local_path: Path) -> None:
    local_path.parent.mkdir(parents=True, exist_ok=True)
    local_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))


def _start_world_with_probe(mcp) -> None:
    # Предыдущий Godot (если был) держит порт 9090 — стоп перед новым запуском,
    # иначе wait_port_free в run_scene висит 60 с и падает (2-й итерации детерм.теста).
    try:
        mcp.stop_running_scene()
    except MCPError:
        pass
    mcp.run_scene("res://scenes/World.tscn")
    mcp.wait_ready()
    _wait_world(mcp)
    mcp.instantiate_scene("res://scenes/probe/BalanceProbe.tscn", "/root")


def test_balance_probe_runs_early_game(mcp):
    _start_world_with_probe(mcp)
    started = mcp.execute_code(START_PROBE)
    assert started.get("status") == "probe_started", f"Прогон не стартовал: {started}"

    report = None
    deadline = time.time() + PROBE_TIMEOUT_S
    last_turn = -1
    while time.time() < deadline:
        state = mcp.execute_code(PROBE_STATE)
        assert not state.get("error"), f"Техсбой прогона: {state.get('error')}"
        if state.get("done"):
            report = state
            break
        # Прогресс: ход сдвинулся — сбрасываем «мёртвый» таймаут локально
        # (общий таймаут остаётся жёстким; лимит MAX_TURNS внутри прогона 60)
        last_turn = int(state.get("turn", last_turn))
        time.sleep(5.0)

    assert report is not None, (
        f"Прогон не завершился за {PROBE_TIMEOUT_S:.0f} с (последний ход: {last_turn}) — "
        "автоигрок застрял"
    )

    # ── Hard-fail: только техсбои (смерть героя → error внутри прогона) ──
    assert report.get("turns", 0) > 0, "Прогон не сделал ни одного хода"

    # attribute-weight-system: герой доживает 60 ходов (RUNNING, не DEFEAT)
    assert report.get("endgame") != "DEFEAT", (
        f"attribute-weight-system: герой погиб на ходу {report.get('turns')} "
        f"(endgame={report.get('endgame')})"
    )
    # Ресурсы добываются (весовая система не блокирует полностью)
    # ponytail: проверяем по отчёту, если поле есть; если нет — warning, не fail
    extracted = report.get("resources_extracted", 0)
    if extracted == 0 and report.get("turns", 0) >= 10:
        warnings.append(
            "attribute-weight-system: ресурсы не добываются (0 extracted) — "
            "возможно, весовая система слишком жёсткая"
        )

    # ── Сохраняем отчёт в репо (артефакт калибровки) ───────────────────────
    file_report_text = mcp.execute_code(PROBE_REPORT_FILE)
    report_out = REPORT_OUT / f"balance_{PROBE_SEED}.json"
    report_out.parent.mkdir(parents=True, exist_ok=True)
    if file_report_text:
        report_out.write_text(file_report_text)
    else:
        _save_report(report, report_out)

    # ── Warnings — в stdout, не fail ────────────────────────────────────────
    warnings = report.get("warnings", [])
    print(
        "\n[balance-probe] seed=%s turns=%s first_building=%s first_recruit=%s "
        "first_collision=%s first_win=%s losses=%s stuck_max=%s season=%s endgame=%s"
        % (
            report.get("seed"), report.get("turns"),
            report.get("first_building_turn"), report.get("first_recruit_turn"),
            report.get("first_collision_turn"), report.get("first_win_turn"),
            report.get("losses"), report.get("stuck_max"), report.get("season"),
            report.get("endgame"),
        )
    )
    for w in warnings:
        print(f"[balance-probe] WARNING: {w}")
    print(f"[balance-probe] отчёт: {report_out}")


def test_balance_probe_deterministic(mcp):
    """Два запуска с одним seed дают одинаковые ключевые метрики."""
    results = []
    for i in range(2):
        _start_world_with_probe(mcp)
        started = mcp.execute_code(START_PROBE)
        assert started.get("status") == "probe_started", f"Прогон #{i} не стартовал: {started}"
        deadline = time.time() + PROBE_TIMEOUT_S
        while time.time() < deadline:
            state = mcp.execute_code(PROBE_STATE)
            assert not state.get("error"), f"Техсбой прогона #{i}: {state.get('error')}"
            if state.get("done"):
                results.append(state)
                break
            time.sleep(5.0)
        assert len(results) == i + 1, f"Прогон #{i} не завершился за {PROBE_TIMEOUT_S:.0f} с"

    a, b = results
    for key in ("turns", "first_building_turn", "first_recruit_turn",
                "first_collision_turn", "first_win_turn", "losses", "battles_fought"):
        assert a.get(key) == b.get(key), (
            f"Неразрезультативность по seed: {key}: {a.get(key)} != {b.get(key)}"
        )
