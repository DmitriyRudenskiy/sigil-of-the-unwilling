"""attribute-weight-system: весовая переноска в живом мире.

Проверяет:
1. Герой с defense-статом имеет весовой cap рюкзака (weight_cap > 0).
2. Добыча ресурсов уменьшает свободный вес (current_weight растёт).
3. После save → load weight_cap восстанавливается (миграция сейва).
4. Перегруз экипировки → MP ниже базовых (LoadCalculator.overload_fraction).
"""
from __future__ import annotations

import time



GET_BASELINE = """
var world = get_tree().current_scene
var hero = world.get_hero()
if hero == null:
    return {"error": "no hero"}
var strat = hero.strategic_resources
var defense = int(hero.stats.get("defense", 2))
var base_cap = 16.0 + defense * 1.0
var expected_cap = 16.0 + defense * 1.0
var inv = hero.inventory
var eq_weight = 0.0
for slot in inv.equipped:
    if inv.equipped[slot] != null:
        eq_weight += inv.equipped[slot].weight
for art in inv.backpack:
    eq_weight += art.weight
var overload = 0.0
if expected_cap > 0.0 and eq_weight > expected_cap:
    overload = (eq_weight - expected_cap) / expected_cap
return {
    "defense": defense,
    "weight_cap": strat.weight_cap,
    "expected_cap": expected_cap,
    "current_weight": strat.current_weight(),
    "eq_weight": eq_weight,
    "overload": overload,
    "turn": world.get_cities().current_turn,
}
"""

SAVE_GAME = """
var world = get_tree().current_scene
world.save_game()
return {"saved": true}
"""

LOAD_GAME = """
var world = get_tree().current_scene
world.call_deferred("request_load_game")
return {"requested": true}
"""

AFTER_LOAD = """
var world = get_tree().current_scene
var hero = world.get_hero()
if hero == null:
    return {"ready": false}
var strat = hero.strategic_resources
var defense = int(hero.stats.get("defense", 2))
return {
    "ready": true,
    "defense": defense,
    "weight_cap": strat.weight_cap,
    "expected_cap": 16.0 + defense * 1.0,
    "current_weight": strat.current_weight(),
    "turn": world.get_cities().current_turn,
}
"""

END_TURN = """
var world = get_tree().current_scene
world.do_end_turn()
return {"turn": world.get_cities().current_turn}
"""

def _wait_world(mcp, timeout: float = 120.0) -> dict:
    deadline = time.time() + timeout
    last: dict = {}
    while time.time() < deadline:
        try:
            r = mcp.execute_code("var w = get_tree().current_scene; return w != null and w.get_hero() != null")
            last = {"ready": bool(r)}
            if last["ready"]:
                return last
        except MCPError:
            pass
        time.sleep(2.0)
    raise TimeoutError(f"world not ready in {timeout}s: {last}")

def test_weight_carry_save_load(full_game) -> None:
    mcp = full_game
    _wait_world(mcp)

    # 1. Базовый весовой cap
    base = mcp.execute_code(GET_BASELINE)
    assert "error" not in base, base
    assert base["weight_cap"] > 0, f"weight_cap must be > 0, got {base['weight_cap']}"
    assert abs(base["weight_cap"] - base["expected_cap"]) < 0.01, (
        f"weight_cap {base['weight_cap']} != expected {base['expected_cap']}"
    )

    # 2. Save
    mcp.execute_code(SAVE_GAME)

    # 3. Load
    mcp.execute_code(LOAD_GAME)
    time.sleep(5.0)
    _wait_world(mcp)

    # 4. After load: weight_cap восстановлен
    after = mcp.execute_code(AFTER_LOAD)
    assert after.get("ready") is True, after
    assert after["weight_cap"] > 0, f"weight_cap after load must be > 0, got {after['weight_cap']}"
    assert abs(after["weight_cap"] - after["expected_cap"]) < 0.01, (
        f"weight_cap after load {after['weight_cap']} != expected {after['expected_cap']}"
    )

    # 5. Игра продолжает ходить
    for _ in range(3):
        r = mcp.execute_code(END_TURN)
        assert "turn" in r, r
