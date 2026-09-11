"""TASK_17 §6.3.2: смерть героя → преемник.

Живой мир: вытесняем героя из города, обнуляем потребности
(streak=2), прогоняем ход — герой умирает от истощения,
открывается death sequence, преемник вступает в роль.
"""
from __future__ import annotations

import time

PREPARE_DEATH = """
var world = get_tree().current_scene
var hero = world.get_hero()
var cities = world.get_cities()
# 1. Герой должен быть вне города (в городе потребности восстанавливаются)
var mov = hero.get_component("Movement")
var start = mov.get_current_cell()
var free_cell = null
for r in range(1, 6):
    for y in range(start.y - r, start.y + r + 1):
        for x in range(start.x - r, start.x + r + 1):
            var c := Vector2i(x, y)
            if c == start or cities.city_at(c) != null:
                continue
            free_cell = c
            break
        if free_cell != null:
            break
    if free_cell != null:
        break
if free_cell == null:
    free_cell = start
mov.teleport(free_cell)
# 2. Все потребности = 0, zero_streak = 2 → следующий tick убьёт
for id in NeedType.all_ids():
    hero.needs.needs[id] = 0.0
    hero.needs.zero_streak[id] = 2
return {
    "hero": hero.hero_name,
    "cell": {"x": free_cell.x, "y": free_cell.y},
    "in_city": cities.city_at(free_cell) != null,
}
"""

END_TURN = """
var world = get_tree().current_scene
world.do_end_turn()
return {"turn": world.get_cities().current_turn}
"""

DEATH_STATE = """
var world = get_tree().current_scene
var dead_seq = world.find_child("SuccessorButton", true, false)
var btn_visible = false
if dead_seq != null:
    btn_visible = dead_seq.visible and dead_seq.show
return {
    "death_open": world.is_death_sequence_open(),
    "successor_btn": dead_seq != null,
    "successor_btn_visible": btn_visible,
    "hero_alive": world.get_hero() != null,
}
"""

CHOOSE_SUCCESSOR = """
var world = get_tree().current_scene
var btn = world.find_child("SuccessorButton", true, false)
if btn == null:
    return {"clicked": false}
btn.pressed.emit()
return {"clicked": true}
"""

NEW_HERO = """
var h = get_tree().current_scene.get_hero()
return {"name": h.hero_name if h != null else null}
"""


def test_hero_death_triggers_succession(full_game):
    mcp = full_game

    prep = mcp.execute_code(PREPARE_DEATH)
    assert prep["in_city"] is False, f"Не удалось вынести героя из города: {prep}"
    old_name = prep["hero"]
    turn = mcp.execute_code("return get_tree().current_scene.get_cities().current_turn")

    mcp.execute_code(END_TURN)

    state = mcp.execute_code(DEATH_STATE)
    assert state["death_open"] is True, f"Death sequence не открыт: {state}"
    assert state["successor_btn"] is True, state

    if state["successor_btn_visible"]:
        result = mcp.execute_code(CHOOSE_SUCCESSOR)
        assert result["clicked"] is True
        # Преемник вступает в роль
        new_name = None
        deadline = time.time() + 30
        while time.time() < deadline:
            r = mcp.execute_code(NEW_HERO)
            if r["name"] is not None and r["name"] != old_name:
                new_name = r["name"]
                break
            time.sleep(0.5)
        assert new_name is not None, f"Преемник не заменил героя: {r}"
        # После смены героя мир продолжает жить
        after = mcp.execute_code("return get_tree().current_scene.get_cities().current_turn")
        assert after == turn + 1, after
    else:
        # Никого нет на преемство — проигрыш, герой удалён
        assert state["hero_alive"] is False, (
            f"Преемник недоступен, но герой ещё в мире: {state}"
        )
