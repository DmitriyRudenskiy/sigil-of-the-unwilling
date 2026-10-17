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

from conftest import _wait_for_scene

COLUMN = [
    "NewGameButton", "ContinueButton", "SettingsButton", "CreditsButton", "ExitButton",
]


def _boot_menu(mcp):
    mcp.run_scene("res://scenes/main_menu.tscn")
    mcp.wait_ready()
    _wait_for_scene(mcp, "main_menu")
    mcp.wait_frames(10)


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


def test_live_menu_column_matches_contract(mcp):
    """Пять пунктов в порядке макета, все видимы, тексты не пусты."""
    _boot_menu(mcp)
    rows = _buttons(mcp)
    assert [r["name"] for r in rows] == COLUMN, f"состав колонки разошёлся с макетом: {rows}"
    for r in rows:
        assert r["visible"], f"пункт не виден в живом меню: {r}"
        assert r["text"], f"у пункта пустой текст (локаль не применена): {r}"


def test_live_disabled_states(mcp):
    """AC3/AC6: «Титры» и «Выход» отключены, «Новая игра» и «Настройки» доступны."""
    _boot_menu(mcp)
    states = {r["name"]: r["disabled"] for r in _buttons(mcp)}
    assert states["CreditsButton"] is True, f"«Титры» без носителя обязаны быть отключены: {states}"
    assert states["ExitButton"] is True, f"«Выход» обязана быть отключена (AC6): {states}"
    assert states["NewGameButton"] is False, f"«Новая игра» должна быть доступна: {states}"
    assert states["SettingsButton"] is False, f"«Настройки» должны быть доступны: {states}"


def test_disabled_credits_press_keeps_menu(mcp):
    """Нажатие отключённого пункта не меняет сцену (проводка обработчика в живой игре)."""
    _boot_menu(mcp)
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
