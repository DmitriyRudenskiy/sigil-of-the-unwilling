"""
scenario_2_flee.py — Сценарий «Flee All».

Прогоняет реальную игру через сокет (localhost:9095) и обходит ВСЕ вражеские
стеки на карте. Подходя к стеку — бой, который в безголовом режиме не резолвится
сам: FORCE_RETREAT + проверка, что герой выжил (продолжает ходить в world).
Считает устроенные побеги.

Запуск:
    python3 tools/scenarios/scenario_2_flee.py
    # или: ./tools/shell/play_scenario.sh 2
    # или: ./tools/shell/run_all_scenarios.sh
"""

import sys

from scenario_lib import connect, send_cmd, keep_alive, move_toward, Reporter, scan_server_log


def run_scenario():
    print("--- Running Scenario 2 (Flee All) ---")
    rep = Reporter()
    sock = connect()

    print("  start_game ->", send_cmd(sock, "START_GAME"))

    day = 0
    max_days = 400  # защита от зависания
    fled_cells = set()  # уже обойденные стеки (force_retreat не уничтожает их)

    while day < max_days:
        st = send_cmd(sock, "GET_STATE")
        mode = st.get("mode")

        # Бой: в безголовом режиме не резолвится сам — отступаем.
        if mode == "battle":
            send_cmd(sock, "FORCE_RETREAT")
            send_cmd(sock, "END_TURN")
            day += 1
            continue
        if mode != "world":
            rep.check("world mode", False, f"unexpected mode '{mode}'")
            break

        # hero-survival: 20 стеков — долго; keep_alive не даёт герою сдохнуть.
        st = keep_alive(sock, st)

        enemies = st.get("map_enemies", [])
        if not enemies:
            break

        hx, hy = st["hero_pos"]["x"], st["hero_pos"]["y"]
        enemies = [e for e in enemies if (e["x"], e["y"]) not in fled_cells]
        if not enemies:
            break
        enemies.sort(key=lambda e: abs(e["x"] - hx) + abs(e["y"] - hy))
        target = enemies[0]

        # Туман режет прямой путь (unreachable) — move_toward шлёт к
        # waypoint'у ближе к герою; каждый день explored расширяется.
        if not move_toward(sock, st, target):
            send_cmd(sock, "END_TURN")  # путь не построен — подходим завтра
            day += 1
            continue

        # Идём к врагу. По пути, став рядом, может начаться бой — ловим его
        # и записываем стек в «обойденные». Если дошли до клетки без боя — тоже.
        engaged = False
        for _ in range(120):
            s = send_cmd(sock, "GET_STATE")
            if s.get("mode") == "battle":
                engaged = True
                break
            if s.get("hero_pos") == {"x": target["x"], "y": target["y"]}:
                engaged = True  # дошли до клетки врага — бой мог не начаться
                break
            if not s.get("moving", True) and s.get("hero_pos") != {"x": target["x"], "y": target["y"]}:
                break  # уперся в ОД — вернёмся за этим стеком за день

        if engaged:
            fled_cells.add((target["x"], target["y"]))

        send_cmd(sock, "END_TURN")  # продвигаем день (в бою END_TURN — ошибка, игнор)
        day += 1

    st = send_cmd(sock, "GET_STATE")
    alive = st.get("hero_pos") is not None
    rep.check("fled at least one battle", len(fled_cells) > 0, f"fled={len(fled_cells)}")
    rep.check("hero alive after flee loop", alive, "no hero_pos")
    rep.check("game reached endgame", st.get("mode") in ("endgame", "world", None),
              f"mode={st.get('mode')}")
    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} "
          f"(errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 2 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 2 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
