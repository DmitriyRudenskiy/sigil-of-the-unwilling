"""TASK_17 §6.3.3: подойти к деревне → захватить.

Живой мир: телепортируем героя к деревне (подход), открываем
клетку в тумане и идём через WorldInteractionController
capture_village_at — флаг деревни сменяется на 🏳️.
"""
from __future__ import annotations

CAPTURE = """
var world = get_tree().current_scene
var map = world.get_map_gen()
if map.village_cells.size() == 0:
    return {"ready": false, "reason": "no villages"}
var cell: Vector2i = map.village_cells[0]
# Подход: герой к соседней свободной клетке
var cities = world.get_cities()
var mov = world.get_hero().get_component("Movement")
var near: Vector2i = cell
for c in HexUtils.ring(cell, 1):
    if c != cell and cities.city_at(c) == null:
        near = c
        break
mov.teleport(near)
# Развеиваем туман (иначе _reject отклонит «не разведано»)
var fog = world.get_fog()
if fog != null:
    fog.visible[cell] = 1
    fog.explored[cell] = 1
# Захват через игровой контроллер (тот же путь, что клик по UI)
var ic = world.get_node("InteractionController")
var ok = ic.capture_village_at(cell)
var flag = "?"
var node = world.get_node("WorldSpawner")._village_nodes.get(cell)
if node != null:
    var f = node.get_node_or_null("Flag")
    if f != null:
        flag = f.text
return {
    "ready": true,
    "ok": ok,
    "flag": flag,
    "hero_cell": {"x": near.x, "y": near.y},
    "village_cell": {"x": cell.x, "y": cell.y},
}
"""


def test_village_capture(full_game):
    mcp = full_game

    r = mcp.execute_code(CAPTURE)
    assert r["ready"] is True, f"Нет деревень на карте: {r}"
    assert r["ok"] is True, f"Захват не прошёл: {r}"
    assert r["flag"] == "🏳️", f"Флаг не сменён: {r}"
    # Герой действительно подошёл (рядом, а не на деревне)
    assert r["hero_cell"] != r["village_cell"], r
    # Захват клетки без деревни — false
    r2 = mcp.execute_code(
        "var w = get_tree().current_scene\n"
        "var map = w.get_map_gen()\n"
        "var none = Vector2i(-1, -1)\n"
        "for c in HexUtils.ring(map.village_cells[0], 2):\n"
        "    if not map.village_cells.has(c):\n"
        "        none = c\n"
        "        break\n"
        "var fog = w.get_fog()\n"
        "if fog != null:\n"
        "    fog.visible[none] = 1\n"
        "return {\"ok\": w.get_node(\"InteractionController\").capture_village_at(none)}"
    )
    assert r2["ok"] is False, f"Захват пустой клетки прошёл: {r2}"
