"""TASK_17 §6.3.1: городской цикл — построить ферму → ход → проверить урожай.

Живой мир: в первом городе строем ферму (12 промышленности, 2 рабочих),
прогоняем ход и проверяем, что зерно появилось в хранилище.
"""
from __future__ import annotations

BUILD_FARM = """
var world = get_tree().current_scene
var city = world.get_cities().cities[0]
var def = BuildingDefs.farm()
# Достаем 12 промышленности, если стартовые запасы малы
city.storage[&"industry"] = float(city.storage.get(&"industry", 0.0)) + 30.0
# Ферме нужны 2 рабочих — гарантируем наличие
city.add_followers(3)
var found = city.first_free_build_cell(def)
if found == Vector2i(-1, -1):
    return {"built": false, "reason": "no cell"}
var bld = city.build_building(def, found)
return {
    "built": bld != null,
    "cell": {"x": found.x, "y": found.y},
    "buildings": city.buildings.size(),
}
"""

END_TURN = """
var world = get_tree().current_scene
world.do_end_turn()
var city = world.get_cities().cities[0]
var ctx = city.resource_ctx
return {
    "turn": world.get_cities().current_turn,
    "grain": ctx.amount(&"grain") if ctx != null else -1.0,
    "buildings": city.buildings.size(),
}
"""


def test_farm_build_and_harvest(full_game):
    mcp = full_game

    baseline = mcp.execute_code("var w = get_tree().current_scene\n"
                                "var c = w.get_cities().cities[0]\n"
                                "var ctx = c.resource_ctx\n"
                                "return {\"turn\": w.get_cities().current_turn, "
                                "\"grain\": ctx.amount(&\"grain\") if ctx != null else -1.0, "
                                "\"buildings\": c.buildings.size()}")
    assert baseline["buildings"] >= 0

    built = mcp.execute_code(BUILD_FARM)
    assert built["built"] is True, f"Ферма не построилась: {built}"
    assert built["buildings"] == baseline["buildings"] + 1

    after = mcp.execute_code(END_TURN)
    assert after["turn"] == baseline["turn"] + 1, after
    # Ферма с 2 рабочими даёт 3 зерна за ход (может быть чуть меньше при
    # нехватке рабочих в стартовом городе — но урожай должен быть > 0)
    assert after["grain"] > baseline["grain"], (
        f"Зерно не появилось: {after['grain']} <= {baseline['grain']}"
    )
    assert after["buildings"] == built["buildings"]
