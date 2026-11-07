"""Единый smoke-контракт потока (D-157; remove-campaign-mechanic 1.2/2.3).

Навигация: main_menu → character_creation → Знак → экран приключения. Контракт
проверяет, что поток донёс до мира: профиль создания (hero_name, T-110) и выбор
Знака (T-002, проводка 1.3). Первый ход кампейна из контракта снят: после Знака
игрок в мире, хода как кампейн-операции там нет (D-229 снял и авто-таймер дня).
Кампейн-контракты — `test_campaign_carrier` поверх fixture `campaign_game`.
"""
from __future__ import annotations


def test_full_cycle_from_menu(full_cycle):
    mcp = full_cycle

    # 1) Навигационная поверхность репойнта: мы на экране приключения, мир собран.
    r = mcp.execute_code(
        "var w = get_tree().current_scene\n"
        "var h = w.get_hero()\n"
        "return {\n"
        '    "script": w.get_script().resource_path,\n'
        '    "map": w.get_map_gen() != null,\n'
        '    "hero": h.hero_name if h != null else "",\n'
        '    "sign": h.sign_id if h != null else ""}'
    )
    assert r["script"].endswith("scripts/world/world_controller.gd"), f"Не экран приключения: {r}"
    assert r["map"] is True, f"Мир не сгенерирован: {r}"

    # 2) Проводка T-110: профиль создания дошёл до героя на карте.
    assert r["hero"] == "McpCycleHero", f"pending_new_game не потреблён: {r}"

    # 2b) Проводка T-002 + 1.3: выбор Знака дошёл до героя (SignChoiceUI → мир).
    assert r["sign"] == "harmony", f"pending_sign_id не потреблён: {r}"
