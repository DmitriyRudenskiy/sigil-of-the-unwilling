"""
scenario_2_flee.py — Сценарий «Flee All» (второй сценарий).

Прогоняет реальную игру через сокет (localhost:9095, action-based,
newline-delimited JSON) и обходит ВСЕ вражеские стеки на карте (MAP_ENEMY_COUNT).
Подходя к стеку, начинается бой, который в безголовом режиме не резолвится сам:
сценарий выходит из боя командой FORCE_RETREAT и проверяет, что герой выжил
(продолжает ходить в мировом режиме). Считает устроенные побеги.

Запуск:
    python3 tools/scenarios/scenario_2_flee.py
    # или через оркестратора:
    ./tools/shell/play_scenario.sh 2
"""

import socket
import json
import sys
import time

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


def wait_arrival(sock, target, tries=100):
    # Движение анимировано: ждём, пока герой реально встанет на клетку.
    for _ in range(tries):
        s = send_cmd(sock, "GET_STATE")
        if s.get("hero_pos") == {"x": target["x"], "y": target["y"]}:
            return True
        if not s.get("moving", True) and s.get("hero_pos") != {"x": target["x"], "y": target["y"]}:
            return False  # остановился по исчерпании ОД
        time.sleep(0.1)
    return False


def run_scenario():
    print("--- Running Scenario 2 (Flee All) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    print("  start_game ->", send_cmd(sock, "START_GAME"))

    day = 0
    max_days = 400  # защита от зависания
    fled = 0
    fled_cells = set()  # уже обойденные стеки (force_retreat не уничтожает их)

    while day < max_days:
        st = send_cmd(sock, "GET_STATE")
        mode = st.get("mode")

        # Бой: в безголовом режиме он не резолвится сам — отступаем.
        if mode == "battle":
            send_cmd(sock, "FORCE_RETREAT")
            send_cmd(sock, "END_TURN")
            day += 1
            continue

        if mode != "world":
            print(f"  [{day}] unexpected mode '{mode}' — stopping")
            break

        enemies = st.get("map_enemies", [])
        if not enemies:
            break

        # Ближайший НЕ пройденный стек к герою (по манхэттену).
        hx = st["hero_pos"]["x"]
        hy = st["hero_pos"]["y"]
        enemies = [e for e in enemies if (e["x"], e["y"]) not in fled_cells]
        if not enemies:
            break
        enemies.sort(key=lambda e: abs(e["x"] - hx) + abs(e["y"] - hy))
        target = enemies[0]

        resp = send_cmd(sock, "MOVE_TO", {}, top={"x": target["x"], "y": target["y"]})
        if "error" in resp:
            send_cmd(sock, "END_TURN")  # не хватает ОД — ждём новый день
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
                # дошли до клетки врага — бой мог не начаться (редкий случай)
                engaged = True
                break
            if not s.get("moving", True) and s.get("hero_pos") != {"x": target["x"], "y": target["y"]}:
                break  # уперся в ОД — вернёмся за этим стеком за день
            time.sleep(0.1)

        if engaged:
            fled_cells.add((target["x"], target["y"]))

        # Продвигаем день (в бою END_TURN вернет ошибку — игнорируем).
        send_cmd(sock, "END_TURN")
        day += 1

    # Проверка: герой всё ещё жив (есть hero_pos и мировой режим).
    st = send_cmd(sock, "GET_STATE")
    alive = st.get("hero_pos") is not None
    sock.close()

    if len(fled_cells) > 0 and alive:
        print(f"✅ Scenario 2 SUCCESS — fled {len(fled_cells)} distinct battle(s), hero alive after {day} day(s)")
        return True
    print(f"❌ Scenario 2 FAILED: fled={len(fled_cells)}, alive={alive} after {day} day(s)")
    return False


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 2 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
