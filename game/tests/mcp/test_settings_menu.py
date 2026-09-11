"""TASK_18 B3.5: настройки через меню — экран открывается, значения сохраняются.

MainMenu → SettingsButton → SettingsScreen; меняем громкость через
Settings (autoload), сохраняем и проверяем персистентность в user://.
"""
from __future__ import annotations

from conftest import _wait_for_scene


def _boot_menu(mcp):
    mcp.run_scene("res://scenes/MainMenu.tscn")
    mcp.wait_ready()
    _wait_for_scene(mcp, "MainMenu")
    mcp.wait_frames(10)


def test_settings_screen_opens_from_menu(mcp):
    _boot_menu(mcp)

    mcp.execute_code("get_tree().current_scene._on_settings()\nreturn {\"ok\": true}")
    mcp.wait_frames(5)

    r = mcp.execute_code(
        "var s = get_tree().current_scene._settings_screen\n"
        "return {\"visible\": s.visible and s.show}"
    )
    assert r["visible"] is True, f"SettingsScreen не открылся: {r}"


def test_settings_change_persists(mcp):
    _boot_menu(mcp)

    mcp.execute_code(
        "Settings.set_master_volume(77)\n"
        "Settings.save()\n"
        'return {"master": Settings.master_volume}'
    )
    # Персистентность: перечитываем конфиг с диска через _load()
    r = mcp.execute_code(
        "Settings._config = ConfigFile.new()\n"
        "Callable(Settings, \"_load\").call()\n"
        'return {"master": Settings.master_volume}'
    )
    assert r["master"] == 77, f"settings.cfg не сохранился: {r}"

    # Валидация: громкость ограничивается [0, 100]
    mcp.execute_code("Settings.set_master_volume(-5)\nreturn {\"ok\": true}")
    clamped = mcp.execute_code("return Settings.master_volume")
    assert clamped == 0, f"clamp(−5) == 0: {clamped}"

    # Возврат к дефолтам (чистота для других тестов)
    mcp.execute_code("Settings.reset_to_defaults()\nSettings.save()\nreturn {\"ok\": true}")
    defaults = mcp.execute_code("return Settings.master_volume")
    assert defaults == 80, f"DEFAULT_MASTER_VOL == 80: {defaults}"
