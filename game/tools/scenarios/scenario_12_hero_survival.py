"""
scenario_12_hero_survival.py — Сценарий «Герой и смерть» (hero-survival).

Прогоняет реальную игру через сокет (localhost:9095) и проверяет поток
смерти/преемственности hero-survival end-to-end:

  1. GET_STATE в режиме world, есть города игрока.
  2. Мир тикает: END_TURN проходит, герой жив (hero_pos на месте).
  3. Смерть по hero-survival: HERO_DIE (честная цепочка — mark_combat_dead +
     hero_died). В свежем мире у героя нет последователей-преемников, поэтому
     по факту wiring'а («Знак переходит» без преемника) забег идёт в DEFEAT
     с end_reason = "unsuccessored_death", а герой снят с карты (hero_pos=None).

Консоль чиста (гейт operability): никаких SCRIPT ERROR / Invalid call.

Запуск:
    python3 game/tools/scenarios/scenario_12_hero_survival.py
    # или через оркестратора:
    ./game/tools/shell/play_scenario.sh 12
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


def run_scenario():
    print("--- Running Scenario 12 (Hero Survival: death flow) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    send_cmd(sock, "START_GAME")
    time.sleep(1.2)  # даём сцене World ноутстрапиться

    st = send_cmd(sock, "GET_STATE")
    if not check("режим world", st.get("mode") == "world", str(st.get("mode"))):
        return False
    if not check("есть города игрока", len(st.get("cities", [])) > 0,
                 str([c.get("name") for c in st.get("cities", [])])):
        return False
    if not check("герой жив на старте", st.get("hero_pos") is not None,
                 str(st.get("hero_pos"))):
        return False

    # ---- 2. Мир тикает: герой жив после ходов (need-tick в end_turn) ----
    alive_after_ticks = True
    for _ in range(6):
        r = send_cmd(sock, "END_TURN")
        if "error" in r:
            alive_after_ticks = False
            break
        st = send_cmd(sock, "GET_STATE")
        if st.get("mode") == "battle":
            st = send_cmd(sock, "GET_STATE")
        if st.get("hero_pos") is None:
            alive_after_ticks = False
            break
        time.sleep(0.3)
    check("мир тикает, герой жив после ходов", alive_after_ticks,
          "hero_pos не пропал")

    # ---- 3. Смерть по hero-survival (честная цепочка) ----
    r = send_cmd(sock, "HERO_DIE")
    if not check("HERO_DIE принят", r.get("status") == "hero_dead", str(r)):
        return False

    st = send_cmd(sock, "GET_STATE")
    eg = st.get("endgame")
    if not check("GET_STATE содержит блок endgame", isinstance(eg, dict), str(st.keys())):
        return False

    # Свежий герой без последователей → по факту wiring'а преемника нет:
    # «Знак переходит» некуда → забег идёт в DEFEAT (unsuccessored_death).
    check("смерть без преемника → DEFEAT", eg.get("state") == "DEFEAT", str(eg))
    check("end_reason = unsuccessored_death",
          eg.get("end_reason") == "unsuccessored_death", str(eg))
    check("герой снят с карты (hero_pos=None)", st.get("hero_pos") is None,
          str(st.get("hero_pos")))

    # Ввод заблокирован после окончания забега.
    r = send_cmd(sock, "END_TURN")
    check("END_TURN после DEFEAT заблокирован", r.get("error") == "Game over", str(r))
    st = send_cmd(sock, "GET_STATE")
    check("сервер жив (GET_STATE отвечает)", isinstance(st.get("endgame"), dict),
          str(st.get("endgame")))

    sock.close()

    if FAILURES:
        print(f"❌ Scenario 12 FAILED ({len(FAILURES)}): " + "; ".join(FAILURES))
        return False
    print("✅ Scenario 12 SUCCESS — death flow works: "
          "hero died unsuccessored → DEFEAT, world clean")
    return True


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 12 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
