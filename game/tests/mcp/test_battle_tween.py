"""
MCP-тест: отсутствие телепортаций при быстром переключении Движение → Атака.
Использует tugcantopaloglu/godot-mcp для управления живой сценой боя.
"""
from __future__ import annotations

import asyncio

import pytest

pytestmark = pytest.mark.asyncio


async def _init_battle(mcp):
    """Инициализация боя через game_eval."""
    return await mcp.execute_code("""
        var battle = get_tree().current_scene
        if battle == null or not battle.has_method("start_battle"):
            return {"error": "Battle scene not ready"}
        var units_reg = get_node("/root/Units")
        units_reg.ensure_definitions()
        var atk: Array[UnitStack] = [units_reg.make_fixed_stack("swordsmen", 10)]
        var def: Array[UnitStack] = [units_reg.make_fixed_stack("goblins", 8)]
        battle.start_battle(
            atk, def,
            {"attack": 5, "defense": 3},
            {"attack": 3, "defense": 2},
            {}, {}, 42, null
        )
        return {"status": "battle_started"}
    """)


async def _get_units(mcp):
    """Получить список юнитов боя."""
    return await mcp.execute_code("""
        var battle = get_tree().current_scene
        var bs = battle.get_battle_state()
        var units = []
        var i := 0
        for u in bs.attacker_units:
            if u.is_alive():
                units.append({"uid": u.uid, "idx": i, "side": "attacker",
                              "cell": {"x": u.cell.x, "y": u.cell.y}})
            i += 1
        i = 0
        for u in bs.defender_units:
            if u.is_alive():
                units.append({"uid": u.uid, "idx": i, "side": "defender",
                              "cell": {"x": u.cell.x, "y": u.cell.y}})
            i += 1
        return {"is_player_turn": bs.is_player_turn,
                "battle_over": bs.battle_over, "units": units}
    """)


async def test_move_then_attack_no_teleport(battle_scene):
    """Движение + сразу атака — без телепортаций."""
    mcp = battle_scene

    init = await _init_battle(mcp)
    assert init.get("status") == "battle_started", f"Init failed: {init}"
    await mcp.wait_frames(20)

    state = await _get_units(mcp)
    assert not state["battle_over"]
    assert state["is_player_turn"]

    attackers = [u for u in state["units"] if u["side"] == "attacker"]
    defenders = [u for u in state["units"] if u["side"] == "defender"]
    assert len(attackers) > 0
    assert len(defenders) > 0

    player = attackers[0]
    enemy = defenders[0]

    # Команда движения
    await mcp.execute_code(f"""
        var battle = get_tree().current_scene
        var executor = battle.get_node("BattleTurnExecutor")
        var bs = battle.get_battle_state()
        var unit = bs.attacker_units[{player['idx']}]
        var blocked = bs.build_all_blocked(unit, battle.obstacles)
        var reachable = bs.get_reachable_for_unit(unit, func() -> Dictionary: return blocked)
        var target = Vector2i(-1, -1)
        for cell in reachable:
            target = cell
            break
        if target != Vector2i(-1, -1):
            executor.request_move(unit, target)
        return {{"moved": target != Vector2i(-1, -1)}}
    """)

    # Сразу атака (не ждём окончания движения)
    await mcp.execute_code(f"""
        var battle = get_tree().current_scene
        var executor = battle.get_node("BattleTurnExecutor")
        var bs = battle.get_battle_state()
        var atk = bs.attacker_units[{player['idx']}]
        var def = bs.defender_units[{enemy['idx']}]
        executor.request_attack(atk, def)
        return {{"attacked": true}}
    """)

    # Сбор позиций спрайта
    positions = []
    for _ in range(30):
        pos = await mcp.execute_code(f"""
            var battle = get_tree().current_scene
            var view = battle.get_node("BattleView")
            var unit = battle.get_battle_state().attacker_units[{player['idx']}]
            var sprite = view._sprites_by_uid.get(unit.uid, null)
            if sprite == null:
                return {{"error": "sprite gone"}}
            return {{"x": sprite.position.x, "y": sprite.position.y}}
        """)
        if "error" in pos:
            break
        positions.append(pos)
        await asyncio.sleep(1 / 60.0)

    # Проверка: нет скачков > 100px за кадр
    TELEPORT_PX = 100.0
    teleports = 0
    for i in range(1, len(positions)):
        dx = abs(positions[i]["x"] - positions[i - 1]["x"])
        dy = abs(positions[i]["y"] - positions[i - 1]["y"])
        dist = (dx**2 + dy**2) ** 0.5
        if dist > TELEPORT_PX:
            teleports += 1

    assert teleports == 0, f"Найдено {teleports} телепортаций спрайта"

    # Бой не завис
    await mcp.wait_frames(60)
    final = await mcp.execute_code("""
        var bs = get_tree().current_scene.get_battle_state()
        return {"battle_over": bs.battle_over}
    """)
    assert "error" not in final
