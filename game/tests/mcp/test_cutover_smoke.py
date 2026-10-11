"""Cutover-смоук (D-157, раунд 10 §1.3/§1.4): меню → New Game → создание → кампания → ход.

Автоматическая часть smoke-AC на НОВОЙ навигационной поверхности
(пост-cutover): main_menu.tscn → character_creation.tscn → main.tscn
(K-канон: TurnDriver composition root) → один ход кампании.
Меню-ручки вызваны напрямую (установленный паттерн test_settings_menu:
в --test-server-режиме _ready может пропустить подключение сигналов).
"""
from __future__ import annotations

from conftest import MCPError, _wait_for_scene


def test_menu_new_game_to_campaign_turn(mcp):
    # 1) Меню живо
    mcp.run_scene("res://scenes/main_menu.tscn")
    mcp.wait_ready()
    _wait_for_scene(mcp, "main_menu")
    mcp.wait_frames(10)

    # 2) New Game → создание персонажа (ручка меню — тот же путь, что сигнал кнопки)
    mcp.execute_code("get_tree().current_scene._on_new_game()\nreturn {\"ok\": true}")
    _wait_for_scene(mcp, "character_creation")
    mcp.wait_frames(10)

    # 3) Создание: профиль (is_valid: name/race/class/culture/background) → Create
    mcp.execute_code(
        "var cc = get_tree().current_scene\n"
        'cc._profile.name = "CutoverSmokeHero"\n'
        "cc._profile.race = cc._race_keys[0]\n"
        "cc._profile.character_class = cc._class_keys[0]\n"
        "cc._profile.culture = cc._culture_keys[0]\n"
        "cc._profile.background = cc._background_keys[0]\n"
        "cc._on_create()\n"
        'return {"ok": true}'
    )
    # 4) Кампания: main.tscn (не world.tscn — cutover)
    _wait_for_scene(mcp, "main/main.gd")
    mcp.wait_frames(10)

    # 5) Один ход кампании (тот же вызов, что делает day-таймер main.gd)
    r = mcp.execute_code(
        "var m = get_tree().current_scene\n"
        "var t0 = m.composition.campaign.current_turn\n"
        "m.composition.advance_turn()\n"
        'return {"t0": t0, "t1": m.composition.campaign.current_turn, '
        '"done": m.composition.campaign.is_done()}'
    )
    assert r.get("t0") == 1, f"Кампания не на первом ходе: {r}"
    assert r.get("t1") == 2, f"Ход не завершился (ожидался переход 1 → 2): {r}"
    assert r.get("done") is False, f"Кампания завершилась после одного хода: {r}"
