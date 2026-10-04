"""autopilot-scenario-matrix: сценарный пилот, роль Собиратель × класс wizard.

Hard-fail: только техсбои (мир не готов, пилот не стартовал, герой погиб,
затык, таймаут). Недостижение цели роли (rare < 20) — warning в отчёте,
калибровка по отчёту (фаза 5), не fail.
"""
from __future__ import annotations

import json
import time
from pathlib import Path

from conftest import MCPError

ROLE = "collector"
CLASS_ID = "wizard"
TIMEOUT_S = 420.0
REPORT_OUT = Path(__file__).parent.parent.parent / "tools" / "mcp" / "reports"

# seed = f(класс, роль) — тот же FNV-1a, что в ScenarioTargets.seed_for.
def _seed_for() -> int:
    key = f"{CLASS_ID}|{ROLE}"
    h = 1469598103
    for ch in key:
        h = ((h ^ ord(ch)) * 1099511628211) % 2147483647
    return h + 1000000


SEED = _seed_for()

# Настройка мира ПЕРЕД ботстлабом: seed в persistence, класс в pending_new_game.
PREPARE = """
var r = ScenarioPilot.prepare_world(__SEED__, "__CLASS__")
return r
""".replace("__SEED__", str(SEED)).replace("__CLASS__", CLASS_ID)

START = """
var w = get_tree().current_scene
if w == null or w.get_hero() == null:
    return {"error": "world not ready"}
var pilot = get_node_or_null("/root/ScenarioPilot")
if pilot == null or pilot.get_script() == null or not str(pilot.get_script().resource_path).contains("ScenarioPilot"):
    return {"error": "pilot node not found"}
w.set_meta("scenario_pilot", pilot)
var r = pilot.start_scenario(w, __SEED__, "__ROLE__", "__CLASS__")
return r
""".replace("__SEED__", str(SEED)).replace("__ROLE__", ROLE).replace("__CLASS__", CLASS_ID)

STATE = """
var w = get_tree().current_scene
var pilot = w.get_meta("scenario_pilot") if w != null else null
if pilot == null:
    return {"error": "no pilot"}
return pilot.report()
"""

REPORT_FILE = """
var w = get_tree().current_scene
var pilot = w.get_meta("scenario_pilot") if w != null else null
if pilot == null:
    return ""
return pilot.read_report_text()
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


def _start_world_with_pilot(mcp) -> None:
    try:
        mcp.stop_running_scene()
    except MCPError:
        pass
    mcp.run_scene("res://scenes/world.tscn")
    mcp.wait_ready()
    _wait_world(mcp)


def _start_scenario(mcp) -> None:
    # Порядок: prepare (seed+класс в persistence) → reload_current_scene
    # (ботстлаб заново: новый seed, профиль применён) → пилот → start_scenario.
    prepared = mcp.execute_code(PREPARE)
    assert prepared.get("status") == "prepared", f"prepare_world: {prepared}"
    mcp.execute_code("get_tree().reload_current_scene()\nreturn {\"ok\": true}", timeout=180.0)
    mcp.wait_ready()
    _wait_world(mcp)
    mcp.instantiate_scene("res://scenes/probe/ScenarioPilot.tscn", "/root")
    started = mcp.execute_code(START)
    assert started.get("status") == "scenario_started", f"Прогон не стартовал: {started}"


def test_scenario_pilot_collector_wizard(mcp):
    _start_world_with_pilot(mcp)
    _start_scenario(mcp)

    report = None
    deadline = time.time() + TIMEOUT_S
    while time.time() < deadline:
        state = mcp.execute_code(STATE)
        assert not state.get("error"), f"Техсбой прогона: {state.get('error')}"
        if state.get("done"):
            report = state
            break
        time.sleep(5.0)

    assert report is not None, f"Прогон не завершился за {TIMEOUT_S:.0f} с — автоигрок застрял"

    # ── Hard-fail: техсбои ──
    assert report.get("turns", 0) > 0, "Прогон не сделал ни одного хода"
    endgame = report.get("endgame", {})
    assert str(endgame.get("state", "")) != "DEFEAT", (
        f"Герой погиб на ходу {report.get('turns')} (endgame={endgame})"
    )
    assert report.get("role") == ROLE
    assert report.get("hero_class") == CLASS_ID

    # ── Метрики роли: цель не достигнута → warning, не fail ──
    warnings = list(report.get("warnings", []))
    rm = report.get("role_metrics", {})
    if not report.get("goal_met"):
        warnings.append(
            "collector: редкие %s < %s за %s ходов — калибровать по отчёту"
            % (rm.get("rare_extracted", 0), rm.get("rare_goal", 0), report.get("turns"))
        )

    # ── Отчёт в репо (артефакт калибровки) ──
    file_text = mcp.execute_code(REPORT_FILE)
    out = REPORT_OUT / f"scenario_{CLASS_ID}_{ROLE}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    if file_text:
        out.write_text(file_text)
    else:
        out.write_text(json.dumps(report, ensure_ascii=False, indent=2))

    print(
        "\n[scenario-pilot] class=%s role=%s seed=%s turns=%s goal_met=%s "
        "rare=%s/%s goal_reached_turn=%s"
        % (
            CLASS_ID, ROLE, SEED, report.get("turns"), report.get("goal_met"),
            rm.get("rare_extracted"), rm.get("rare_goal"), report.get("goal_reached_turn"),
        )
    )
    for w in warnings:
        print(f"[scenario-pilot] WARNING: {w}")
    print(f"[scenario-pilot] отчёт: {out}")
