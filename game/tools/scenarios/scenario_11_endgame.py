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

Победа (path_completed / domination) по сокету недетерминирована (нужны
реальные бои/слава) — покрыта юнит-тестами tests/test_endgame.gd.

Запуск:
    python3 game/tools/scenarios/scenario_11_endgame.py
    # или через оркестратора:
    ./game/tools/shell/play_scenario.sh 11
"""

import json
import socket
import sys
import time

HOST, PORT = "localhost", 9095

FAILURES = []


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


def check(label, cond, detail=""):
    mark = "✅" if cond else "❌"
    suffix = f" — {detail}" if detail and not cond else ""
    print(f"  {mark} {label}{suffix}")
    if not cond:
        FAILURES.append(f"{label}{suffix}")
    return cond


def endgame_block(st):
    return st.get("endgame") or {}


def run_scenario():
    print("--- Running Scenario 11 (Endgame Conditions) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    send_cmd(sock, "START_GAME")
    time.sleep(1.2)  # даём сцене World отбутстрапиться

    # ---- 1. Блок endgame, забег RUNNING ----
    st = send_cmd(sock, "GET_STATE")
    check("режим world", st.get("mode") == "world", str(st.get("mode")))
    eg = endgame_block(st)
    if not check("GET_STATE содержит блок endgame", isinstance(eg, dict), str(st.keys())):
        return False
    check("на старте забег RUNNING", eg.get("state") == "RUNNING", str(eg))
    check("на старте end_reason пуст", eg.get("end_reason", "") == "", str(eg))

    # ---- 2. До endgame мир работает ----
    r = send_cmd(sock, "END_TURN")
    check("END_TURN до endgame проходит", "error" not in r, str(r))
    st = send_cmd(sock, "GET_STATE")
    if st.get("mode") == "battle":
        # Враг оказался рядом — аварийное отступление (не влияет на проверки).
        print("  [battle] враг атаковал — аварийное отступление")
        send_cmd(sock, "FORCE_RETREAT")
        st = send_cmd(sock, "GET_STATE")
    check("после первого хода забег всё ещё RUNNING",
          endgame_block(st).get("state") == "RUNNING",
          str(endgame_block(st)))

    # ---- 3. Смерть героя без преемника -> DEFEAT ----
    r = send_cmd(sock, "HERO_DIE")
    check("HERO_DIE принят", r.get("status") == "hero_dead", str(r))
    st = send_cmd(sock, "GET_STATE")
    eg = endgame_block(st)
    check("забег DEFEAT", eg.get("state") == "DEFEAT", str(eg))
    check("end_reason = unsuccessored_death",
          eg.get("end_reason") == "unsuccessored_death", str(eg))

    # ---- 4. Липкое состояние, ввод заблокирован ----
    # Герой к этому моменту снят с поля (терминальный сценарий) —
    # координаты берём из последнего состояния, если оно ещё есть.
    hp = st.get("hero_pos")
    hx = hp.get("x", 1) if isinstance(hp, dict) else 1
    hy = hp.get("y", 1) if isinstance(hp, dict) else 1
    r = send_cmd(sock, "MOVE_TO", {}, top={"x": hx + 1, "y": hy})
    check("MOVE_TO после endgame запрещён", r.get("error") == "Game over", str(r))
    r = send_cmd(sock, "END_TURN")
    check("END_TURN после endgame запрещён", r.get("error") == "Game over", str(r))
    st = send_cmd(sock, "GET_STATE")
    eg = endgame_block(st)
    check("состояние липкое: всё ещё DEFEAT", eg.get("state") == "DEFEAT", str(eg))
    check("сервер жив (GET_STATE отвечает)", isinstance(st.get("endgame"), dict))

    sock.close()

    if FAILURES:
        print(f"❌ Scenario 11 FAILED ({len(FAILURES)}): " + "; ".join(FAILURES))
        return False
    print("✅ Scenario 11 SUCCESS — endgame works: RUNNING → DEFEAT "
          "(unsuccessored_death), ввод заблокирован, состояние липкое")
    return True


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 11 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
