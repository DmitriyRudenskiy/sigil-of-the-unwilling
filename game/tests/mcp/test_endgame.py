"""TASK_18 B3.4: конец игры — EndgameController завершает сессию и пишет хронику.

Живой мир: вызываем EndgameController._end("VICTORY") и проверяем:
состояние сессии, сигнал game_ended, запись в Chronicle, идемпотентность.
"""
from __future__ import annotations

SETUP_HOOKS = """
var w = get_tree().current_scene
var eg = w.find_child("EndgameController", true, false)
if eg == null:
    return {"error": "EndgameController не найден"}
var sess = eg._session
if sess == null:
    return {"error": "session не привязан"}
var chron = w._persistence.chronicle if w._persistence != null else null
return {
    "terminal": sess.is_terminal(),
    "state": int(sess.state),
    "chronicle": chron.entries.size() if chron != null else -1,
}
"""

END_GAME = """
var w = get_tree().current_scene
var eg = w.find_child("EndgameController", true, false)
var hits = []
var cb = func(result, reason, summary): hits.append([str(result), str(reason)])
if not GameEventBus.game_ended.is_connected(cb):
    GameEventBus.game_ended.connect(cb)
eg._end("VICTORY", &"mcp_test_victory")
if GameEventBus.game_ended.is_connected(cb):
    GameEventBus.game_ended.disconnect(cb)
var sess = eg._session
var chron = w._persistence.chronicle
return {
    "terminal": sess.is_terminal(),
    "state": int(sess.state),
    "reason": str(sess.end_reason),
    "chronicle": chron.entries.size() if chron != null else -1,
    "emitted": hits.size(),
    "emitted_result": str(hits[0][0]) if hits.size() > 0 else "",
}
"""


def test_endgame_victory_full_flow(full_game):
    mcp = full_game

    before = mcp.execute_code(SETUP_HOOKS)
    assert "error" not in before, f"Setup: {before}"
    assert before["terminal"] is False, f"Сессия уже терминальна: {before}"
    # GameState.RUNNING == 0
    assert before["state"] == 0, before

    r = mcp.execute_code(END_GAME)
    assert "error" not in r, f"End: {r}"
    assert r["terminal"] is True, r
    assert r["state"] == 1, f"GameState.VICTORY == 1: {r}"
    assert r["reason"] == "mcp_test_victory", r
    assert r["emitted"] == 1, f"game_ended должен emit один раз: {r}"
    assert r["emitted_result"] == "VICTORY", r
    assert r["chronicle"] == before["chronicle"] + 1, \
        f"Хроника не выросла: {before} -> {r}"

    # Второй _end — no-op (не дублирует запись в хронике)
    again = mcp.execute_code(
        'var w = get_tree().current_scene\n'
        'var eg = w.find_child("EndgameController", true, false)\n'
        "eg._end(\"VICTORY\", &\"second\")\n"
        "var chron = w._persistence.chronicle\n"
        'return {"chronicle": chron.entries.size()}'
    )
    assert again["chronicle"] == r["chronicle"], \
        f"Дубль записи в хронике: {again} vs {r}"
