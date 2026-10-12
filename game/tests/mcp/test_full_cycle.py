"""TASK_17 §6.3.4 (переписано на cutover D-157): фикстура полного цикла
(меню → персонаж → main.tscn). Игра, запущенная через меню со созданием
персонажа, доходит до кампании K-канона и может ходить.
"""
from __future__ import annotations


def test_full_cycle_from_menu(full_cycle):
    mcp = full_cycle

    r = mcp.execute_code(
        "var c = get_tree().current_scene.get(\"composition\")\n"
        "return {\"campaign\": c != null and c.campaign != null, "
        "\"turn\": c.campaign.current_turn if c != null else -1}"
    )
    assert r["campaign"] is True, r
    assert r["turn"] == 1, r

    for _ in range(3):
        mcp.execute_code(
            'get_tree().current_scene.get("composition").advance_turn()\n'
            'return {"ok": true}'
        )
    after = mcp.execute_code(
        'return get_tree().current_scene.get("composition").campaign.current_turn'
    )
    assert after == 4, f"Три хода не прошли: {after}"
