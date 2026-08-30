"""
scenario_4_endure.py — Сценарий «Endure» (четвёр сценарий).

Проверяет долговременную стабильность игры в безголовом режиме: запуск игры
и серия ходов (END_TURN) без перемещений. На каждом шаге проверяет, что:
  * герой не покинул мировой режим (нет сбоев/рестартов сцены),
  * очки действия (ОД) восстанавливаются до максимума каждый день,
  * соединения не рвётся (сервер отвечает на каждый запрос).

Это регрессионная проверка: игра должна «жить» дольше, чем один авто-выход
(1 сек в безголовом режиме) — см. WorldController._handle_headless_exit — и
поддерживать цикл день/ОД скольгодно долго.

Запуск:
    python3 tools/scenarios/scenario_4_endure.py
    # или через оркестратора:
    ./tools/shell/play_scenario.sh 4
"""

import socket
import json
import sys
import time

HOST, PORT = "localhost", 9095
DAYS = 20  # сколько дней проиграть


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


def run_scenario():
    print("--- Running Scenario 4 (Endure: stability + OD recovery) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    print("  start_game ->", send_cmd(sock, "START_GAME"))

    max_days = DAYS + 50  # защита от зависания
    recovered = 0
    day = 0

    while day < max_days and recovered < DAYS:
        st = send_cmd(sock, "GET_STATE")
        mode = st.get("mode")

        if mode != "world":
            print(f"  [{day}] unexpected mode '{mode}' — stopping")
            break

        hero = st.get("hero_pos")
        if hero is None:
            print(f"  [{day}] hero_pos missing — stopping")
            break

        # Ход: тратим день, ОД должны восстановиться.
        send_cmd(sock, "END_TURN")
        day += 1

        # Ждём, пока ОД восстановятся до максимума (проверка восстановления).
        waited = 0
        while waited < 200:
            s = send_cmd(sock, "GET_STATE")
            if s.get("move_points") == s.get("max_move_points") and s.get("max_move_points", 0) > 0:
                recovered += 1
                break
            if s.get("mode") != "world":
                print(f"  [{day}] mode changed to '{s.get('mode')}' during recovery — stopping")
                sock.close()
                return False
            time.sleep(0.05)
            waited += 1

    sock.close()

    if recovered >= DAYS:
        print(f"✅ Scenario 4 SUCCESS — {recovered}/{DAYS} days recovered OD, stable for {day} day(s)")
        return True
    print(f"❌ Scenario 4 FAILED: only {recovered}/{DAYS} days recovered OD over {day} day(s)")
    return False


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 4 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
