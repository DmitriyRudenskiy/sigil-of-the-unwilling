"""TASK_14 §8 (10): переходы сцен World → Battle → World.

Полный ботст랩 мира, переход в бой (бой стартует и жив),
возврат в мир (новый ботст랩 завершается, герой на месте).
"""
from __future__ import annotations

import time

BATTLE_INIT = """
var battle = get_tree().current_scene
if battle == null or not battle.has_method("start_battle"):
    return {"error": "Battle scene not ready"}
var units_reg = get_node("/root/Units")
units_reg.ensure_definitions()
var atk: Array[UnitStack] = [units_reg.make_fixed_stack("swordsmen", 4)]
var def: Array[UnitStack] = [units_reg.make_fixed_stack("goblins", 3)]
battle.start_battle(
    atk, def,
    {"attack": 5, "defense": 3},
    {"attack": 3, "defense": 2},
    {}, {}, 7, null
)
return {"status": "battle_started"}
"""

WORLD_OK = """
var w = get_tree().current_scene
if w == null:
    return {"ready": false}
return {
    "ready": w.get_hero() != null and w.get_map_gen() != null,
    "hero": w.get_hero() != null,
}
"""


def _change_scene(mcp, scene: str) -> None:
    mcp.execute_code(f'get_tree().change_scene_to_file("{scene}")')
    deadline = time.time() + 120
    while time.time() < deadline:
        try:
            if mcp.execute_code(WORLD_OK, timeout=5.0).get("ready"):
                return
        except Exception:  # noqa: BLE001 — сцена ещё грузится
            pass
        time.sleep(1.0)
    raise AssertionError(f"Сцена {scene} не стала готова за 120 с")


def test_world_battle_world_transitions(full_game):
    mcp = full_game

    # 1) Мир живой (full_game гарантировал ботст랩)
    assert mcp.execute_code(WORLD_OK)["ready"]

    # 2) Переход в бой
    mcp.execute_code('get_tree().change_scene_to_file("res://scenes/Battle.tscn")')
    mcp.wait_ready()
    mcp.wait_frames(20)

    init = mcp.execute_code(BATTLE_INIT)
    assert init.get("status") == "battle_started", f"Бой не стартовал: {init}"
    mcp.wait_frames(30)
    state = mcp.execute_code(
        'var bs = get_tree().current_scene.get_battle_state(); '
        'return {"over": bs.battle_over, "turn": bs.is_player_turn}'
    )
    assert state["turn"] is True, f"Игровой ход не начался: {state}"

    # 3) Возврат в мир
    _change_scene(mcp, "res://scenes/World.tscn")
    r = mcp.execute_code(WORLD_OK)
    assert r["hero"] is True, f"Героя нет после возврата: {r}"
