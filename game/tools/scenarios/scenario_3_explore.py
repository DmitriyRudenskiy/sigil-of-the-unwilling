"""
scenario_3_explore.py — Сценарий «Explore».

Прогоняет игру через сокет (localhost:9095) и обеспечивает ПОЛНОЕ изучение
карты: герой посещает ВСЕ деревни и собирает ВСЕ ресурсные узлы. Деревни не
«сгорают» при посещении — сценарий ведёт учёт посещённых клеток сам. Каждый
день берёт ближайшую цель (непосещённая деревня или ресурс), идёт к ней,
собирает (COLLECT_HERE как страховка) и тратит день на восстановление ОД.

Бой (вблизи врага) — FORCE_RETREAT и дальше.

Условие победы: все деревни посещены И все ресурсы собраны.

Запуск:
    python3 tools/scenarios/scenario_3_explore.py
    # или: ./tools/shell/play_scenario.sh 3
    # или: ./tools/shell/run_all_scenarios.sh
"""

import sys

from scenario_lib import connect, send_cmd, wait_arrival, keep_alive, move_toward, Reporter, scan_server_log


def run_scenario():
    print("--- Running Scenario 3 (Explore: all villages + all resources) ---")
    rep = Reporter()
    sock = connect()

    print("  start_game ->", send_cmd(sock, "START_GAME"))

    init_st = send_cmd(sock, "GET_STATE")
    total_villages = len(init_st.get("map_villages", []))

    day = 0
    max_days = 400
    collected = 0
    visited = 0
    visited_villages = set()

    while day < max_days:
        # Если бой — отступаем и сдвигаем день.
        st = send_cmd(sock, "GET_STATE")
        if st.get("mode") == "battle":
            send_cmd(sock, "FORCE_RETREAT")
            send_cmd(sock, "END_TURN")
            day += 1
            continue

        mode = st.get("mode")
        if mode != "world":
            rep.check("world mode", False, f"unexpected mode '{mode}'")
            break

        # hero-survival: 33 цели (узлы+деревни) — долго; keep_alive не даёт
        # герою сдохнуть от голода по дороге.
        st = keep_alive(sock, st)

        resources = st.get("map_resources", [])
        villages = st.get("map_villages", [])
        unvisited = [v for v in villages if (v["x"], v["y"]) not in visited_villages]
        if not resources and not unvisited:
            break

        hx, hy = st["hero_pos"]["x"], st["hero_pos"]["y"]
        hcell = (hx, hy)

        targets = []
        for v in unvisited:
            if (v["x"], v["y"]) != hcell:
                targets.append({"x": v["x"], "y": v["y"], "type": "village"})
        for r in resources:
            if (r["x"], r["y"]) != hcell:
                targets.append({"x": r["x"], "y": r["y"], "type": "resource"})

        # Если остались только цели на клетке героя — собираем, что стоит на ней.
        if not targets:
            if resources and (hx, hy) in {(r["x"], r["y"]) for r in resources}:
                coll = send_cmd(sock, "COLLECT_HERE")
                if coll.get("status") == "collected":
                    collected += 1
            send_cmd(sock, "END_TURN")
            day += 1
            continue

        targets.sort(key=lambda n: abs(n["x"] - hx) + abs(n["y"] - hy))
        target = targets[0]

        # Туман режет прямой путь (unreachable) — move_toward шлёт к
        # waypoint'у ближе к герою; каждый день explored расширяется.
        if not move_toward(sock, st, target):
            send_cmd(sock, "END_TURN")  # путь не построен — подходим завтра
            day += 1
            continue

        if not wait_arrival(sock, target):
            send_cmd(sock, "END_TURN")  # застрял на промежуточной точке, вернёмся завтра
            day += 1
            continue

        if target["type"] == "resource":
            coll = send_cmd(sock, "COLLECT_HERE")
            if coll.get("status") == "collected":
                collected += 1
        if target["type"] == "village":
            visited_villages.add((target["x"], target["y"]))
            visited += 1

        send_cmd(sock, "END_TURN")
        day += 1

    st = send_cmd(sock, "GET_STATE")
    remaining_res = len(st.get("map_resources", []))
    rep.check("all resources collected", remaining_res == 0, f"{remaining_res} left")
    rep.check("all villages visited", visited >= total_villages,
              f"{visited}/{total_villages}")
    rep.check("game reached endgame", st.get("mode") in ("endgame", "world", None),
              f"mode={st.get('mode')}")
    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} "
          f"(errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 3 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 3 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
