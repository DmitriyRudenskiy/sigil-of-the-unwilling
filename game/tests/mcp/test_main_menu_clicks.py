"""UI-3 шаг 3 (D-204): клики по главному меню — путь «клик → сигнал → обработчик».

Урок D-202: проверка ведётся настоящим попаданием мышью по узлу, а не вызовом
`current_scene._on_new_game()` (так делают соседние тесты-переходы — они покрывают
приём сцены, а не проводку кнопки). Настоящее попадание уважает `disabled`, и только
оно и имеет смысл для второго случая: отключённый пункт не реагирует именно потому,
что не принимает ввод, — `emit_signal("pressed")` прошёл бы мимо причины.

Отключённым пунктом проверяется `CreditsButton` («Титры»): он выключен всегда
(экрана-носителя нет, Т-133), тогда как `ContinueButton` зависит от наличия сейвов
в `user://`, который общие для всего MCP-сьюта.
"""
from __future__ import annotations

from conftest import _wait_for_scene


def _boot_menu(mcp):
    mcp.run_scene("res://scenes/main_menu.tscn")
    mcp.wait_ready()
    _wait_for_scene(mcp, "main_menu")
    mcp.wait_frames(10)


def _click(mcp, node_path: str) -> dict:
    """Настоящий клик: InputEventMouseButton через root.push_input (не emit_signal)."""
    return mcp.execute_code(
        "var btn = get_tree().current_scene.get_node(\"" + node_path + "\")\n"
        "var center = btn.get_global_rect().get_center()\n"
        "var ev = InputEventMouseButton.new()\n"
        "ev.button_index = MOUSE_BUTTON_LEFT\n"
        "ev.position = center\n"
        "ev.global_position = center\n"
        "ev.pressed = true\n"
        "get_tree().root.push_input(ev)\n"
        "var up = ev.duplicate()\n"
        "up.pressed = false\n"
        "get_tree().root.push_input(up)\n"
        'return {"disabled": btn.disabled, "text": btn.text, "at": str(center)}'
    )


def _scene_marker(mcp) -> str:
    return mcp.execute_code(
        "var s = get_tree().current_scene\n"
        "if s == null or s.get_script() == null:\n"
        '    return {"marker": ""}\n'
        'return {"marker": s.get_script().resource_path}'
    )["marker"]


def test_new_game_click_enters_character_creation(mcp):
    """Задача 3.4: нажатие доступного пункта ведёт в существующую сцену."""
    _boot_menu(mcp)

    r = _click(mcp, "RightColumn/NewGameButton")
    assert r["disabled"] is False, f"«Новая игра» должна быть доступна: {r}"

    _wait_for_scene(mcp, "character_creation", timeout=120.0)


def test_disabled_credits_click_keeps_menu(mcp):
    """Задача 3.4: нажатие disabled не меняет сцену."""
    _boot_menu(mcp)

    before = _scene_marker(mcp)
    assert "main_menu" in before, f"стартовали не из меню: {before}"

    r = _click(mcp, "RightColumn/CreditsButton")
    assert r["disabled"] is True, f"«Титры» без носителя обязаны быть отключены: {r}"

    mcp.wait_frames(30)
    after = _scene_marker(mcp)
    assert "main_menu" in after, f"disabled-кнопка сменила сцену: {before} → {after}"
