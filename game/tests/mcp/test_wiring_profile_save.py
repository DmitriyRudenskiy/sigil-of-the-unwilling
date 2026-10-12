"""Т-110-проводка (раунд 11 §1.2): профиль конструктора доходит до кампании,
Continue восстанавливает ход и состояние.

Два e2e акта директивы:
1. «создал профиль → профиль виден в кампании» (имя/раса/класс → партийный
   слот K-M5/§7, секция "party" сейва);
2. «сохранил → Continue → ход и состояние восстановлены» (MvpSaveManager
   slot 1 → main.gd → load_save_state: ход, герой).

Day-таймер main.gd выключен в тестах: проводка требует стабильного
состояния, таймер — отдельная забота (smoke-тест покрывает ход).
"""
from __future__ import annotations

from conftest import _wait_for_scene


def _create_campaign(mcp, hero_name: str) -> None:
    """Меню → New Game → создание (профиль) → main.tscn (кампания).

    ВХОД: текущая сцена = main_menu (один run_scene на тест — run_scene
    запускает НОВОГО Godot, повторный вызов в живом процессе упадёт на
    wait_port_free(immediate=True), T-120-инвариант).
    """
    mcp.wait_frames(10)
    mcp.execute_code("get_tree().current_scene._on_new_game()\nreturn {\"ok\": true}")
    _wait_for_scene(mcp, "character_creation")
    mcp.wait_frames(10)
    mcp.execute_code(
        "var cc = get_tree().current_scene\n"
        f'cc._profile.name = "{hero_name}"\n'
        "cc._profile.race = cc._race_keys[0]\n"
        "cc._profile.character_class = cc._class_keys[0]\n"
        "cc._profile.culture = cc._culture_keys[0]\n"
        "cc._profile.background = cc._background_keys[0]\n"
        "cc._on_create()\n"
        'return {"ok": true}'
    )
    _wait_for_scene(mcp, "main/main.gd")
    # Стабильное состояние: day-таймер (авто-advance_turn каждые 3с) — выключен.
    mcp.execute_code(
        "get_tree().current_scene._is_day_cycle_active = false\nreturn {\"ok\": true}"
    )
    mcp.wait_frames(10)


def test_profile_reaches_campaign(mcp):
    mcp.run_scene("res://scenes/main_menu.tscn")
    mcp.wait_ready()
    _wait_for_scene(mcp, "main_menu")
    _create_campaign(mcp, "WiringHero")
    r = mcp.execute_code(
        "var m = get_tree().current_scene\n"
        "var h = m.composition.hero_identity\n"
        'var party = m.composition.build_save_state().get("party", [])\n'
        'return {"hero_name": h.get("hero_name", ""), '
        '"race": h.get("hero_race", ""), '
        '"class": h.get("hero_class", ""), '
        '"party_size": party.size(), '
        '"party_hero": (party[0].get("hero_name", "") if party.size() > 0 else "")}'
    )
    assert r.get("hero_name") == "WiringHero", f"Имя героя не дошло: {r}"
    assert r.get("race") != "", f"Раса не дошла: {r}"
    assert r.get("class") != "", f"Класс не дошёл: {r}"
    assert r.get("party_size") == 1, f"Партийный слот (R1: 1 герой): {r}"
    assert r.get("party_hero") == "WiringHero", f"Секция party сейва: {r}"


def test_save_continue_restores_turn_and_state(mcp):
    # Один Godot на весь тест (run_scene = новый Godot, T-120-инвариант);
    # все последующие переходы — in-process (change_scene_to_file/execute_code).
    mcp.run_scene("res://scenes/main_menu.tscn")
    mcp.wait_ready()
    _wait_for_scene(mcp, "main_menu")
    # Чистота: слот 1 не зависит от предыдущих прогонов (user:// персистентен).
    mcp.execute_code("MvpSaveManager.delete_slot(1)\nreturn {\"ok\": true}")

    _create_campaign(mcp, "SaveHero")
    # Два хода (t: 1 → 3) + сейв в слот 1.
    r = mcp.execute_code(
        "var m = get_tree().current_scene\n"
        "m.composition.advance_turn()\n"
        "m.composition.advance_turn()\n"
        'var t = m.composition.campaign.current_turn\n'
        "var res = MvpSaveManager.save_slot(1, m.composition.build_save_state())\n"
        'return {"turn": t, "save_ok": res.get("ok", false), '
        '"save_msg": res.get("message", "")}'
    )
    assert r.get("turn") == 3, f"Ходы не прошли: {r}"
    assert r.get("save_ok") is True, f"Сейв не записан: {r}"

    # Меню → Continue (слот 1 → pending_campaign_save → main.gd).
    mcp.execute_code(
        'get_tree().change_scene_to_file("res://scenes/main_menu.tscn")\n'
        'return {"ok": true}'
    )
    _wait_for_scene(mcp, "main_menu")
    mcp.wait_frames(10)
    mcp.execute_code("get_tree().current_scene._on_continue()\nreturn {\"ok\": true}")
    _wait_for_scene(mcp, "main/main.gd")
    mcp.execute_code(
        "get_tree().current_scene._is_day_cycle_active = false\nreturn {\"ok\": true}"
    )
    mcp.wait_frames(10)

    r = mcp.execute_code(
        "var m = get_tree().current_scene\n"
        'return {"turn": m.composition.campaign.current_turn, '
        '"hero": m.composition.hero_identity.get("hero_name", "")}'
    )
    assert r.get("turn") == 3, f"Continue не восстановил ход: {r}"
    assert r.get("hero") == "SaveHero", f"Continue не восстановил героя: {r}"
