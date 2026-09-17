"""7.2 MCP-сценарий: поселение доживает до шторма (детерминизм).

Два прогона с одним seed дают идентичный результат.
"""
import json

from conftest import MCPError

SEED = 20260917

RUN_CODE = """
var rng := RandomNumberGenerator.new()
rng.seed = %d
var c = Settlement.form_caravan({"human": 3, "lizard": 2, "harpy": 2})
c.assign_cluster(Vector2i(30, 30))
c.add_resource("food", 500.0)
c.add_resource("wood", 50.0)
SettlementBuildings.start_build(c, "woodcutters_camp", Vector2i(31, 30))
SettlementBuildings.start_build(c, "shelter", Vector2i(30, 31))
var last := {}
for i in 40:
    SettlementResolve.on_day_passed(c, rng, false)
    SettlementBuildings.on_day_passed(c, rng)
    SettlementReputation.on_day_passed(c, rng)
    last = {
        "day": int(c.state["day"]),
        "settlers": int(c.state["settlers"].size()),
        "hostility": int(c.state["hostility"]),
        "reputation": SettlementReputation.total_reputation(c),
        "defeat": str(c.state["defeat"]),
    }
return last
""" % SEED


def _start(mcp):
    # run_project без сцены — eval работает через autoload
    mcp._portal.call(
        mcp._call, "run_project", {"projectPath": mcp._project_path}, 300.0
    )
    mcp._running = True
    mcp.wait_ready()


def _run(mcp) -> dict:
    out = mcp.execute_code(RUN_CODE)
    if isinstance(out, str):
        return json.loads(out)
    return out


def test_settlement_survives_to_storm(mcp):
    _start(mcp)
    r = _run(mcp)
    assert r["day"] == 40
    # поселение дожило: не все поселенцы ушли
    assert r["settlers"] > 0
    # hostility > 0 (поселенцы + лагеря)
    assert r["hostility"] > 0


def test_settlement_determinism(mcp):
    _start(mcp)
    a = _run(mcp)
    b = _run(mcp)
    assert a == b
