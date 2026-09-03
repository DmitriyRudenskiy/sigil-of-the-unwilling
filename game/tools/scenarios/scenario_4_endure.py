"""
scenario_4_endure.py — Сценарий «Endure».

Проверяет долговременную стабильность игры в безголовом режиме: запуск игры и
серия ходов (END_TURN) без перемещений. На каждом шаге: герой в world-режиме,
ОД восстанавливаются до максимума каждый день, соединения не рвётся.

Регрессионная проверка: игра «живёт» дольше одного авто-выхода (1 сек в
безголовом режиме — WorldController._handle_headless_exit) и держит цикл
день/ОД скольгодно долго.

Запуск:
    python3 tools/scenarios/scenario_4_endure.py
    # или: ./tools/shell/play_scenario.sh 4
    # или: ./tools/shell/run_all_scenarios.sh
"""

import sys

from scenario_lib import connect, send_cmd, Reporter, scan_server_log

DAYS = 20  # сколько дней проиграть


def run_scenario():
    print("--- Running Scenario 4 (Endure: stability + OD recovery) ---")
    rep = Reporter()
    sock = connect()

    print("  start_game ->", send_cmd(sock, "START_GAME"))

    max_days = DAYS + 50  # защита от зависания
    recovered = 0
    day = 0

    while day < max_days and recovered < DAYS:
        st = send_cmd(sock, "GET_STATE")
        mode = st.get("mode")
        if mode != "world":
            rep.check("world mode", False, f"unexpected mode '{mode}'")
            break

        if st.get("hero_pos") is None:
            rep.check("hero_pos present", False, "hero_pos missing")
            break

        send_cmd(sock, "END_TURN")  # тратим день, ОД должны восстановиться
        day += 1

        # Ждём, пока ОД восстановятся до максимума (проверка восстановления).
        waited = 0
        while waited < 200:
            s = send_cmd(sock, "GET_STATE")
            if s.get("move_points") == s.get("max_move_points") and s.get("max_move_points", 0) > 0:
                recovered += 1
                break
            if s.get("mode") != "world":
                rep.check("stable mode during recovery", False,
                          f"mode changed to '{s.get('mode')}'")
                break
            import time
            time.sleep(0.05)
            waited += 1

    rep.check(f"OD recovered {DAYS} days", recovered >= DAYS, f"{recovered}/{DAYS}")
    rep.check("game stable", day > 0, f"{day} day(s)")
    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} "
          f"(errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 4 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 4 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
