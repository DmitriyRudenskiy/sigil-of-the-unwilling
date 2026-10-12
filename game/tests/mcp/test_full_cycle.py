"""Единый cutover smoke-контракт (D-157; сведение двойного исполнения,
раунд 6 §1.2: «один smoke-контракт, одна реализация»).

Навигация: main_menu → character_creation → main.tscn (K-канон-линия) +
первый ход (1→2). Профиль создания доходит до кампании (hero_name —
проводка T-110). Три хода и полный цикл 21 — в композите
(test_cutover_composite), не в smoke. Поглощены: test_character_creation
(дубль навигации), test_cutover_smoke (дубль раунда 10).
"""
from __future__ import annotations


def test_full_cycle_from_menu(full_cycle):
    mcp = full_cycle

    # 1) Навигационная поверхность репойнта: мы в кампании, seed/население из конфига.
    r = mcp.execute_code(
        "var s = get_tree().current_scene\n"
        'var c = s.get("composition")\n'
        "return {\n"
        '    "script": s.get_script().resource_path,\n'
        '    "turn": c.campaign.current_turn,\n'
        '    "seed": c.campaign.seed,\n'
        '    "roster": c.population_system.size(),\n'
        '    "hero": c.hero_name\n'
        "}"
    )
    assert r["script"].endswith("scripts/main/main.gd"), f"Не main.tscn: {r}"
    assert r["turn"] == 1, f"Кампания не на ходе 1: {r}"
    assert r["seed"] == 12345, f"CAMPAIGN_SEED не дошёл: {r}"
    assert r["roster"] == 20, f"Стартовое население не из конфига: {r}"

    # 2) Проводка T-110: профиль создания дошёл до кампании.
    assert r["hero"] == "McpCycleHero", f"pending_new_game не потреблён: {r}"

    # 3) Первый ход (минимум smoke: 1→2).
    mcp.execute_code(
        'get_tree().current_scene.get("composition").advance_turn()\n'
        'return {"ok": true}'
    )
    after = mcp.execute_code(
        'return get_tree().current_scene.get("composition").campaign.current_turn'
    )
    assert after == 2, f"Первый ход не прошёл: 1 -> {after}"
