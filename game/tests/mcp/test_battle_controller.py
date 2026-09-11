"""TASK_18 B3.3: бой через BattleController (публичные _on_* пути).

В отличие от test_battle_full_e2e (прямой executor), здесь действия
идут через контроллер: _on_move_requested / _on_attack_requested /
_on_wait — тот же путь, что и из UI.
"""
from __future__ import annotations

INIT_CODE = """
var battle = get_tree().current_scene
if battle == null or not battle.has_method("start_battle"):
    return {"error": "Battle scene not ready"}
var units_reg = get_node("/root/Units")
units_reg.ensure_definitions()
var atk: Array[UnitStack] = [units_reg.make_fixed_stack("swordsmen", 10)]
var def: Array[UnitStack] = [units_reg.make_fixed_stack("goblins", 1)]
battle.start_battle(
    atk, def,
    {"attack": 5, "defense": 3},
    {"attack": 3, "defense": 2},
    {}, {}, 42, null
)
return {"status": "battle_started"}
"""

STATE_CODE = """
var bs = get_tree().current_scene.get_battle_state()
return {
    "over": bs.battle_over,
    "winner": int(bs.battle_winner),
    "player_turn": bs.is_player_turn,
}
"""

# Действие активного юнита через BattleController._on_*.
ACTION_CODE = """
var battle = get_tree().current_scene
var bs = battle.get_battle_state()
if bs.battle_over:
    return {"action": "over"}
var unit = bs.active_unit
if unit == null or not unit.is_alive():
    return {"action": "noop"}

var target = null
for e in bs.defender_units:
    if e.is_alive() and HexUtils.hex_distance(unit.cell, e.cell, bs.hex_shift_right) == 1:
        target = e
        break
if target != null:
    battle._on_attack_requested(unit, target)
    return {"action": "attack"}

if not unit.has_moved:
    var blocked = bs.build_all_blocked(unit, battle.obstacles)
    var reachable = bs.get_reachable_for_unit(unit, func() -> Dictionary: return blocked)
    var nearest = null
    var nd := 99999
    for e in bs.defender_units:
        if not e.is_alive():
            continue
        var d = HexUtils.hex_distance(unit.cell, e.cell, bs.hex_shift_right)
        if d < nd:
            nd = d
            nearest = e
    if nearest != null and reachable.size() > 0:
        var best_cell = Vector2i(-1, -1)
        var best_d := nd
        for c in reachable:
            var dc = HexUtils.hex_distance(c, nearest.cell, bs.hex_shift_right)
            if dc < best_d:
                best_d = dc
                best_cell = c
        if best_cell != Vector2i(-1, -1):
            battle._on_move_requested(unit, best_cell)
            return {"action": "move"}

battle._on_wait()
return {"action": "wait"}
"""


def test_battle_via_controller_reaches_winner(battle_scene):
    mcp = battle_scene

    init = mcp.execute_code(INIT_CODE)
    assert init.get("status") == "battle_started", f"Init failed: {init}"
    mcp.wait_frames(20)

    last_action = None
    state = {}
    for _ in range(150):
        state = mcp.execute_code(STATE_CODE)
        assert "error" not in state, f"State failed: {state}"
        if state["over"]:
            break
        if state["player_turn"]:
            last_action = mcp.execute_code(ACTION_CODE)
            assert "error" not in last_action, f"Action failed: {last_action}"
        mcp.wait_frames(12)
    else:
        raise AssertionError(f"Бой не завершился за 150 итераций; last={last_action}")

    # Несимметричный бой: победитель — атакующие (Side.ATTACKER == 1)
    assert state["winner"] == 1, f"Неожиданный победитель: {state}"

    finished = mcp.execute_code(
        'return get_tree().current_scene.get_node("BattleTurnExecutor")._end_emitted'
    )
    assert finished is True, "end_battle (через controller) не сработал"
