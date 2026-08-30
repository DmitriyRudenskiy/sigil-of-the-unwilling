"""
scenario_1_collect.py — Сценарий «Collect All» (первый сценарий).

Прогоняет реальную игру через сокет (localhost:9095, action-based,
newline-delimited JSON) и собирает все ресурсные узлы на карте:
Старта игры -> герой ходит к ближайшему узлу -> собирает (авто-подбор при
прохождении по клетке, плюс COLLECT_HERE как страховка) -> новый день.

Если герой заходит в клетку рядом с вражеским стеком — начинается бой,
который в безголовом режиме не резолвится сам: сценарий выходит из боя
командой FORCE_RETREAT и продолжает сбор.

Запуск:
    python3 tools/scenarios/scenario_1_collect.py
    # или через оркестратора:
    ./tools/shell/play_scenario.sh 1
"""

import socket
import json
import sys

HOST, PORT = "localhost", 9095


def send_cmd(sock, action, args=None, top=None, cmd_id=0):
    # Протокол: newline-delimited JSON. MOVE_TO читает x/y из ВЕРХНЕГО уровня.
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


def wait_arrival(sock, target, tries=50):
    # Движение анимировано: ждём, пока герой реально встанет на клетку.
    # Герой может упереться в ОД раньше — тогда вернёмся за ним за день.
    for _ in range(tries):
        s = send_cmd(sock, "GET_STATE")
        if s.get("hero_pos") == {"x": target["x"], "y": target["y"]}:
            return True
        if not s.get("moving", True) and s.get("hero_pos") != {"x": target["x"], "y": target["y"]}:
            return False  # остановился по исчерпании ОД
        import time
        time.sleep(0.1)
    return False


def run_scenario():
    print("--- Running Scenario 1 (Collect All) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    # 1. Новая игра (сцена World.tscn сама запускает мир в _ready).
    print("  start_game ->", send_cmd(sock, "START_GAME"))

    collected = 0
    day = 0
    max_days = 120  # защита от зависания

    while day < max_days:
        st = send_cmd(sock, "GET_STATE")
        mode = st.get("mode")

        # Бой: в безголовом режиме он не резолвится сам — отступаем и дальше.
        if mode == "battle":
            print(f"  [{day}] battle -> forced retreat")
            send_cmd(sock, "FORCE_RETREAT")
            send_cmd(sock, "END_TURN")
            day += 1
            continue

        if mode != "world":
            print(f"  [{day}] unexpected mode '{mode}' — stopping")
            break

        resources = st.get("map_resources", [])
        if not resources:
            break

        # Ближайший узел к герою (по манхэттену).
        hx = st["hero_pos"]["x"]
        hy = st["hero_pos"]["y"]
        resources.sort(key=lambda n: abs(n["x"] - hx) + abs(n["y"] - hy))
        target = resources[0]

        resp = send_cmd(sock, "MOVE_TO", {}, top={"x": target["x"], "y": target["y"]})
        if "error" in resp:
            send_cmd(sock, "END_TURN")  # не хватает ОД — ждём новый день
            day += 1
            continue

        # Герой авто-собирает ресурс, проходя по клетке (auto-pickup).
        if not wait_arrival(sock, target):
            send_cmd(sock, "END_TURN")  # уперся в ОД, вернёмся завтра
            day += 1
            continue

        # Страховка: если по какой-то причине авто-подбор не сработал — собрать.
        if resp.get("status") == "moving":
            coll = send_cmd(sock, "COLLECT_HERE")
            if coll.get("status") == "collected":
                collected += 1

        # Тратим день — восстанавлием ОД.
        send_cmd(sock, "END_TURN")
        day += 1

    # Финальная проверка: все узлы собраны (считаем по фактическому остатку).
    st = send_cmd(sock, "GET_STATE")
    remaining = len(st.get("map_resources", []))
    sock.close()

    if remaining == 0:
        print(f"✅ Scenario 1 SUCCESS — all collected in {day} day(s)")
        return True
    print(f"❌ Scenario 1 FAILED: {remaining} resource(s) left after {day} day(s)")
    return False


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 1 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
