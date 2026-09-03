"""
scenario_11_endgame.py — Сценарий «Терминальные состояния» (endgame-conditions).

Прогоняет реальную игру через сокет (localhost:9095) и проверяет endgame
end-to-end:

  1. GET_STATE содержит блок endgame; на старте забег RUNNING.
  2. До endgame мир работает: END_TURN проходит.
  3. HERO_DIE (тест-only акция: честная цепочка смерти — mark_combat_dead +
     hero_died, как при потере боя). Новый герой без преемника -> забег
     DEFEAT, end_reason = "unsuccessored_death".
  4. Терминальный забег липкий и блокирует ввод: MOVE_TO и END_TURN
     возвращают ошибку "Game over"; GET_STATE продолжает работать и
     возвращает то же DEFEAT-состояние.

Победа (path_completed / domination) по сокету недетерминирована — покрыта
юнит-тестами tests/test_endgame.gd.

Запуск:
    python3 game/tools/scenarios/scenario_11_endgame.py
    # или через оркестратора:
    ./game/tools/shell/play_scenario.sh 11
"""

import socket
import sys
import time

from scenario_lib import connect, send_cmd, Reporter, scan_server_log


def endgame_block(st):
    return st.get("endgame") or {}


def run_scenario():
    print("--- Running Scenario 11 (Endgame Conditions) ---")
    rep = Reporter()
    sock = connect()

    send_cmd(sock, "START_GAME")
    time.sleep(1.2)  # даём сцене World отбутстрапиться

    st = send_cmd(sock, "GET_STATE")
    rep.check("режим world", st.get("mode") == "world", str(st.get("mode")))
    eg = endgame_block(st)
    rep.check("GET_STATE содержит блок endgame", isinstance(eg, dict), str(st.keys()))
    rep.check("на старте забег RUNNING", eg.get("state") == "RUNNING", str(eg))
    rep.check("на старте end_reason пуст", eg.get("end_reason", "") == "", str(eg))

    r = send_cmd(sock, "END_TURN")
    rep.check("END_TURN до endgame проходит", "error" not in r, str(r))
    st = send_cmd(sock, "GET_STATE")
    if st.get("mode") == "battle":
        print("  [battle] враг атаковал — аварийное отступление")
        send_cmd(sock, "FORCE_RETREAT")
        st = send_cmd(sock, "GET_STATE")
    rep.check("после первого хода забег всё ещё RUNNING", endgame_block(st).get("state") == "RUNNING", str(endgame_block(st)))

    r = send_cmd(sock, "HERO_DIE")
    rep.check("HERO_DIE принят", r.get("status") == "hero_dead", str(r))
    st = send_cmd(sock, "GET_STATE")
    eg = endgame_block(st)
    rep.check("забег DEFEAT", eg.get("state") == "DEFEAT", str(eg))
    rep.check("end_reason = unsuccessored_death", eg.get("end_reason") == "unsuccessored_death", str(eg))

    hp = st.get("hero_pos")
    hx = hp.get("x", 1) if isinstance(hp, dict) else 1
    hy = hp.get("y", 1) if isinstance(hp, dict) else 1
    r = send_cmd(sock, "MOVE_TO", {}, top={"x": hx + 1, "y": hy})
    rep.check("MOVE_TO после endgame запрещён", r.get("error") == "Game over", str(r))
    r = send_cmd(sock, "END_TURN")
    rep.check("END_TURN после endgame запрещён", r.get("error") == "Game over", str(r))
    st = send_cmd(sock, "GET_STATE")
    eg = endgame_block(st)
    rep.check("состояние липкое: всё ещё DEFEAT", eg.get("state") == "DEFEAT", str(eg))
    rep.check("сервер жив (GET_STATE отвечает)", isinstance(st.get("endgame"), dict))

    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} (errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 11 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 11 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
