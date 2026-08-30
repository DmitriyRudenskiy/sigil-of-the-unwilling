"""
scenario_3_explore.py — Сценарий «Explore» (третий сценарий).

Прогоняет игру через сокет (localhost:9095) и обеспечивает ПОЛНОЕ
изучение карты: герой посещает ВСЕ деревни (MAP_VILLAGE_COUNT) и собирает
ВСЕ ресурсные узлы (MAP_RESOURCE_COUNT). Деревни в режиме игры не
«сгорают» при посещении, поэтому сценарий ведёт учёт посещённых клеток
сам (set). Каждый день берёт ближайшую цель (посещённая деревня исключена,
клетка героя исключена), идёт к ней, собирает ресурс (COLLECT_HERE как
страховка) и тратит день на восстановление ОД.

Если герой заходит в клетку рядом с вражеским стеком — начинается бой,
который в безголовом режиме не резолвится сам: сценарий выходит из боя
FORCE_RETREAT и продолжает изучение.

Условие победы: все деревни посещены И все ресурсы собраны.

Запуск:
    python3 tools/scenarios/scenario_3_explore.py
    # или через оркестратора:
    ./tools/shell/play_scenario.sh 3
"""

import socket
import json
import sys
import time

HOST, PORT = "localhost", 9095


def send_cmd(sock, action, args=None, top=None, cmd_id=0):
    if args is None:
        args = {}
    msg = {"id": cmd_id, "action": action, "args": args}
    if top:
        msg.update(top)
    sock.sendall((json.dumps(msg) + "\n").encode("utf-8"))
    sock.settimeout(10.0)
    buf = ""
    while "\n" not in buf:
        chunk = sock.recv(65536)
        if not chunk:
            break
        buf += chunk.decode("utf-8")
    return json.loads(buf.split("\n")[0])


def wait_arrival(sock, target, tries=100):
    for _ in range(tries):
        s = send_cmd(sock, "GET_STATE")
        if s.get("hero_pos") == {"x": target["x"], "y": target["y"]}:
            return True
        if not s.get("moving", True) and s.get("hero_pos") != {"x": target["x"], "y": target["y"]}:
            return False
        time.sleep(0.1)
    return False


def handle_battle(sock):
    # Если сейчас бой — отступаем и сдвигаем день.
    st = send_cmd(sock, "GET_STATE")
    if st.get("mode") == "battle":
        send_cmd(sock, "FORCE_RETREAT")
        send_cmd(sock, "END_TURN")
        return True
    return False


def run_scenario():
    print("--- Running Scenario 3 (Explore: all villages + all resources) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    print("  start_game ->", send_cmd(sock, "START_GAME"))

    # Запоминаем общее число деревни для проверки посещения.
    init_st = send_cmd(sock, "GET_STATE")
    total_villages = len(init_st.get("map_villages", []))

    day = 0
    max_days = 400
    collected = 0
    visited = 0
    visited_villages = set()  # посещённые деревни (клетки)

    while day < max_days:
        if handle_battle(sock):
            day += 1
            continue

        st = send_cmd(sock, "GET_STATE")
        mode = st.get("mode")
        if mode != "world":
            print(f"  [{day}] unexpected mode '{mode}' — stopping")
            break

        resources = st.get("map_resources", [])
        villages = st.get("map_villages", [])

        # Деревни, которые ещё не посещены.
        unvisited = [v for v in villages if (v["x"], v["y"]) not in visited_villages]
        if not resources and not unvisited:
            break

        hx = st["hero_pos"]["x"]
        hy = st["hero_pos"]["y"]
        hcell = (hx, hy)

        # Цель: ближайшая из (непосещённые деревни + ресурсы), кроме клетки героя.
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

        resp = send_cmd(sock, "MOVE_TO", {}, top={"x": target["x"], "y": target["y"]})
        if "error" in resp:
            send_cmd(sock, "END_TURN")  # не хватает ОД — ждём новый день
            day += 1
            continue

        if not wait_arrival(sock, target):
            send_cmd(sock, "END_TURN")  # уперся в ОД, вернёмся завтра
            day += 1
            continue

        if target["type"] == "resource" and resp.get("status") == "moving":
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
    sock.close()

    if remaining_res == 0 and visited >= total_villages:
        print(f"✅ Scenario 3 SUCCESS — collected {collected} resource(s), visited {visited}/{total_villages} villages in {day} day(s)")
        return True
    print(f"❌ Scenario 3 FAILED: {remaining_res} resource(s) left, {visited}/{total_villages} villages visited after {day} day(s)")
    return False


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 3 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
