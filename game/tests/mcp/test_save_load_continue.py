"""TASK_14 §8 (7): Save → Load → продолжить игру.

Живой мир: тратим ману, сохраняем, тратим ещё, загружаем сейв
(перезагрузка сцены с pending_save) и проверяем, что состояние
откатилось к моменту сохранения, а игра продолжает ходить.
"""
from __future__ import annotations

import time

GET_BASELINE = """
var world = get_tree().current_scene
var hero = world.get_hero()
hero.magic.spend_mana(7)
return {
    "name": hero.hero_name,
    "mana": hero.magic.mana_current,
    "cell": {"x": hero.current_cell.x, "y": hero.current_cell.y},
    "turn": world.get_cities().current_turn,
}
"""

MUTATE_AFTER_SAVE = """
var hero = get_tree().current_scene.get_hero()
hero.magic.spend_mana(5)
return {"mana": hero.magic.mana_current}
"""

LOAD_SAVE = """
var world = get_tree().current_scene
# reload_current_scene блокирует главный поток — вызываем отложенно,
# чтобы eval вернулся
world.call_deferred("request_load_game")
return {"requested": true}
"""

AFTER_LOAD = """
var world = get_tree().current_scene
var hero = world.get_hero()
if hero == null:
    return {"ready": false}
return {
    "ready": true,
    "name": hero.hero_name,
    "mana": hero.magic.mana_current,
    "cell": {"x": hero.current_cell.x, "y": hero.current_cell.y},
    "turn": world.get_cities().current_turn,
}
"""

END_TURN = """
var world = get_tree().current_scene
world.do_end_turn()
return {"turn": world.get_cities().current_turn}
"""


def _wait_world(mcp, timeout: float = 120.0) -> dict:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            r = mcp.execute_code(AFTER_LOAD, timeout=5.0)
        except Exception:  # noqa: BLE001 — reload/таймауты MCP, просто ждём
            # во время reload interaction-сервер временно недоступен
            time.sleep(1.0)
            continue
        if r.get("ready"):
            return r
        try:
            mcp.wait_frames(10)
        except Exception:  # noqa: BLE001 — см. выше
            time.sleep(1.0)
    raise AssertionError("Мир не завершил перезагрузку/ботст랩 вовремя")


def test_save_load_then_continue(full_game):
    mcp = full_game

    baseline = mcp.execute_code(GET_BASELINE)
    assert "error" not in baseline, f"Baseline failed: {baseline}"

    saved = mcp.execute_code("return get_tree().current_scene.save_game()")
    assert saved is True, f"save_game() не вернул true: {saved}"

    mutated = mcp.execute_code(MUTATE_AFTER_SAVE)
    assert mutated["mana"] < baseline["mana"], (
        f"Мутация после сейва не применилась: {mutated} vs {baseline}"
    )

    mcp.execute_code(LOAD_SAVE)
    loaded = _wait_world(mcp)

    # Состояние откатилось к моменту сохранения (не к post-save мутации)
    assert loaded["name"] == baseline["name"]
    assert loaded["mana"] == baseline["mana"], (
        f"Ману не откатил сейв: {loaded['mana']} != {baseline['mana']}"
    )
    assert loaded["cell"] == baseline["cell"]
    assert loaded["turn"] == baseline["turn"]

    # Игра продолжается: ход проходит без ошибок
    after_turn = mcp.execute_code(END_TURN)
    assert after_turn["turn"] == baseline["turn"] + 1, after_turn
