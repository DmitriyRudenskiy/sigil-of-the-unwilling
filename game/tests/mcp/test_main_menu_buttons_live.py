"""UI-3 шаг 3 (D-204): живой главный меню — состав колонки и состояние пунктов.

Граница уровня (зафиксирована уроком, см. TICKETS):
настоящее попадание мышью из скрипта в Godot 4.7 недостижимо —
`Viewport.push_input`, посланный из команды MCP-сервера, обрывает сокет
игрового interaction server («wait failed: Connection closed»), а путь
BaseButton «отпустил → pressed» требует мышиного фокуса, который ставит только
сам viewport (`gui_set_mouse_focus` в API нет). Hit-testing остаётся ручным
smoke; здесь — состояние пунктов в запущенной игре и проводка обработчика.
"""
from __future__ import annotations

import pytest

from conftest import boot_menu

COLUMN = [
    "NewGameButton", "ContinueButton", "LoadButton", "SettingsButton",
    "CreditsButton", "ExitButton",
]


def _buttons(mcp) -> list:
    """`execute_code` разворачивает результат: возвращается сразу список словарей."""
    return mcp.execute_code(
        'var col = get_tree().current_scene.get_node("RightColumn")\n'
        "var out = []\n"
        "for c in col.get_children():\n"
        '    out.append({"name": str(c.name), "text": c.text, "disabled": c.disabled,'
        ' "visible": c.visible})\n'
        "return out"
    )


# smoke-пара (T-329): меню живое + мир живой — два факта, без которых
# остальной свит не о чем. В слой smoke попадает только по MCP_SMOKE=1.
@pytest.mark.smoke
def test_live_menu_column_matches_contract(mcp):
    """Шесть пунктов в порядке макета 09 (с амендментом D-301), все видимы."""
    boot_menu(mcp)
    rows = _buttons(mcp)
    assert [r["name"] for r in rows] == COLUMN, f"состав колонки разошёлся с макетом: {rows}"
    for r in rows:
        assert r["visible"], f"пункт не виден в живом меню: {r}"
        assert r["text"], f"у пункта пустой текст (локаль не применена): {r}"


def test_live_disabled_states(mcp):
    """AC3/AC6: «Титры» и «Выход» отключены, «Новая игра» и «Настройки» доступны."""
    boot_menu(mcp)
    states = {r["name"]: r["disabled"] for r in _buttons(mcp)}
    assert states["CreditsButton"] is True, f"«Титры» без носителя обязаны быть отключены: {states}"
    assert states["ExitButton"] is True, f"«Выход» обязана быть отключена (AC6): {states}"
    assert states["NewGameButton"] is False, f"«Новая игра» должна быть доступна: {states}"
    assert states["SettingsButton"] is False, f"«Настройки» должны быть доступны: {states}"
    # «Загрузить» (D-301 (в)) — живой пункт, а не заглушка: он доступен и при
    # пустых слотах, потому что пустоту объясняет сам список слотов.
    assert states["LoadButton"] is False, f"«Загрузить» обязан быть доступен: {states}"


def test_live_load_entry_opens_the_campaign_slots(mcp):
    """T-307: у экрана слотов есть живой вход, и говорит он про кампанийный сейв.

    До правки экран не открывался ниоткуда, а его строки читались из легаси
    `SaveManager` — магазина, который кампания не пишет: игрок видел бы
    «сохранений нет» вечно.
    """
    boot_menu(mcp)
    state = mcp.execute_code(
        'var screen = get_tree().current_scene.get_node("SaveLoadScreen")\n'
        'assert(not screen.visible)\n'
        'var btn = get_tree().current_scene.get_node("RightColumn/LoadButton")\n'
        'assert(not btn.disabled)\n'
        'btn.emit_signal("pressed")\n'
        'var list = screen.get_node("Panel/Box/SlotList")\n'
        'return {"visible": screen.visible, "rows": list.get_child_count(),'
        ' "slots": screen.SLOT_COUNT}'
    )
    assert state["visible"] is True, f"«Загрузить» не открыл экран слотов: {state}"
    assert state["rows"] == state["slots"], (
        f"рядов {state['rows']}, а слотов у экрана {state['slots']} — состав ряда "
        "должен принадлежать носителю сейва (T-307)"
    )


def test_disabled_credits_press_keeps_menu(mcp):
    """Нажатие отключённого пункта не меняет сцену (проводка обработчика в живой игре)."""
    boot_menu(mcp)
    before = mcp.execute_code(
        "var s = get_tree().current_scene\n"
        'return {"marker": s.get_script().resource_path if s.get_script() else str(s)}'
    )["marker"]
    assert "main_menu" in before, f"стартовали не из меню: {before}"

    mcp.execute_code(
        'var btn = get_tree().current_scene.get_node("RightColumn/CreditsButton")\n'
        'assert(btn.disabled)\n'
        'btn.emit_signal("pressed")\n'
        "return true"
    )
    mcp.wait_frames(30)
    after = mcp.execute_code(
        "var s = get_tree().current_scene\n"
        'return {"marker": s.get_script().resource_path if s.get_script() else str(s)}'
    )["marker"]
    assert "main_menu" in after, f"отключённый пункт сменил сцену: {before} → {after}"
