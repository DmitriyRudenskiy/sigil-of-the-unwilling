"""TASK_18 B3.1: создание персонажа через меню — герой с профилем попадает в мир.

full_cycle фикстура: меню → _on_new_game → CharacterCreation → _on_create → World.
Проверяем, что профиль персонажа дошёл до живого героя и мир ходит.
"""
from __future__ import annotations


def test_created_hero_reaches_world(full_cycle):
    mcp = full_cycle

    r = mcp.execute_code(
        "var w = get_tree().current_scene\n"
        "var h = w.get_hero()\n"
        "return {\n"
        '    "hero": h != null,\n'
        '    "name": h.hero_name if h != null else "",\n'
        '    "components": h._components.size() if h != null else 0,\n'
        '    "turn": w.get_cities().current_turn\n'
        "}"
    )
    assert r["hero"] is True, r
    assert r["name"] == "McpCycleHero", f"Не тот герой: {r['name']}"
    assert r["components"] == 14, f"Компоненты героя: {r['components']}"

    # Мир живой: ход проходит
    mcp.execute_code("get_tree().current_scene.do_end_turn()\nreturn {\"ok\": true}")
    after = mcp.execute_code("return get_tree().current_scene.get_cities().current_turn")
    assert after == r["turn"] + 1, (r["turn"], after)


def test_created_hero_has_needs_and_army(full_cycle):
    mcp = full_cycle

    r = mcp.execute_code(
        "var h = get_tree().current_scene.get_hero()\n"
        "var army = h.get_army()\n"
        "var needs = h.needs\n"
        "return {\n"
        '    "army": army.army.size() if army != null else -1,\n'
        '    "needs": needs.needs.size() if needs != null else -1,\n'
        "}"
    )
    assert r["army"] >= 0, r
    assert r["needs"] > 0, f"Потребности не инициализированы: {r}"
