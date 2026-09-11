"""TASK_17 §6.3.4: фикстура полного цикла (меню → персонаж → мир).

Проверяем, что игра, запущенная через меню со созданием персонажа,
доходит до живого мира и может ходить.
"""
from __future__ import annotations


def test_full_cycle_from_menu(full_cycle):
    mcp = full_cycle

    r = mcp.execute_code(
        "var w = get_tree().current_scene\n"
        "return {\"hero\": w.get_hero() != null, "
        "\"name\": w.get_hero().hero_name if w.get_hero() != null else \"\"}"
    )
    assert r["hero"] is True, r
    assert r["name"] == "McpCycleHero", r

    turn = mcp.execute_code("return get_tree().current_scene.get_cities().current_turn")
    mcp.execute_code("get_tree().current_scene.do_end_turn()\nreturn {\"ok\": true}")
    after = mcp.execute_code("return get_tree().current_scene.get_cities().current_turn")
    assert after == turn + 1, (turn, after)
