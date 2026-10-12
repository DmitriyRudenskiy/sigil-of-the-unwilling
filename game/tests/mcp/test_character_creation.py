"""Cutover D-157 (акт 14-й итерации, раунд 5 §1): навигационная поверхность
main_menu → character_creation → main.tscn.

Smoke AC §1.4(б): профиль проходит создание, кампанийная линия (K-канон)
стартует, ход идёт. Герой-профиль в main.tscn не потребляется (MVP-срез;
sign-слой — T-020), поэтому проверяется композиция, а не герой.
"""
from __future__ import annotations


def test_creation_lands_on_campaign_line(full_cycle):
    mcp = full_cycle

    r = mcp.execute_code(
        "var s = get_tree().current_scene\n"
        'var c = s.get("composition")\n'
        "return {\n"
        '    "script": s.get_script().resource_path,\n'
        '    "turn": c.campaign.current_turn,\n'
        '    "seed": c.campaign.seed,\n'
        '    "roster": c.population_system.size()\n'
        "}"
    )
    assert r["script"].endswith("scripts/main/main.gd"), f"Не main.tscn: {r}"
    assert r["turn"] == 1, f"Кампания не на ходе 1: {r}"
    assert r["seed"] == 12345, f"CAMPAIGN_SEED не дошёл: {r}"
    assert r["roster"] == 20, f"Стартовое население не из config: {r}"


def test_campaign_turn_advances(full_cycle):
    mcp = full_cycle

    before = mcp.execute_code(
        'return get_tree().current_scene.get("composition").campaign.current_turn'
    )
    mcp.execute_code(
        'get_tree().current_scene.get("composition").advance_turn()\n'
        'return {"ok": true}'
    )
    after = mcp.execute_code(
        'return get_tree().current_scene.get("composition").campaign.current_turn'
    )
    assert after == before + 1, f"Ход не прошёл: {before} -> {after}"
