"""
scenario_9_enemy_ai.py — Сценарий «Живой мир: враги» (enemy-world-ai).

Прогоняет реальную игру через сокет (localhost:9095) и проверяет
вражеский слой end-to-end. Seed фиксируется извне нельзя
(START_GAME берёт время), поэтому инварианты generic:

  1. На старте на карте есть вражеские стеки (map_enemies непусто).
  2. После END_TURN враги действуют сами: позиция хотя бы одного стека
     изменилась (движение к цели) — и/или бой инициирован врагом
     (режим battle в ответ на END_TURN).
  3. Если враг добрался до героя — бой начался с ролями: враг атакующий.
     Сценарий аварийно отступает (FORCE_RETREAT) и проверяет, что игра
     вернулась в режим world и герой жив.
  4. Число стеков не превышает MAP_ENEMY_COUNT + разумный запас на
     сезонный рост/возрождение.

Запуск:
    python3 game/tools/scenarios/scenario_9_enemy_ai.py
    # или через оркестратора:
    ./game/tools/shell/play_scenario.sh 9
"""

import json
import socket
import sys
import time

HOST, PORT = "localhost", 9095

FAILURES = []
MAP_ENEMY_COUNT = 20  # GameSettings.MAP_ENEMY_COUNT


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


def enemy_cells(st):
    return {(e["x"], e["y"]) for e in st.get("map_enemies", [])}


def handle_possible_battle(sock, label):
    """Если враг добрался до героя — бой начался (roles swapped).
    Аварийно отступаем и проверяем возврат в world."""
    st = send_cmd(sock, "GET_STATE")
    if st.get("mode") != "battle":
        return st
    print(f"  [{label}] враг атаковал героя — бой (роли: враг атакующий)")
    r = send_cmd(sock, "FORCE_RETREAT")
    check(f"{label}: FORCE_RETREAT принят", r.get("status") == "forced_retreat", str(r))
    time.sleep(0.3)
    st = send_cmd(sock, "GET_STATE")
    check(f"{label}: после отступления режим world", st.get("mode") == "world",
          str(st.get("mode")))
    return st


def run_scenario():
    print("--- Running Scenario 9 (Enemy World AI) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    send_cmd(sock, "START_GAME")
    time.sleep(1.2)  # даём сцене World отбутстрапиться

    st = send_cmd(sock, "GET_STATE")
    if not check("режим world", st.get("mode") == "world", str(st.get("mode"))):
        return False
    enemies0 = st.get("map_enemies", [])
    if not check("на старте есть вражеские стеки", len(enemies0) > 0,
                 f"map_enemies={enemies0}"):
        return False
    print(f"  стеков на старте: {len(enemies0)}")
    start_cells = enemy_cells(st)

    # ---- 2. Два хода мира: враги действуют сами ----
    moved = False
    for i in (1, 2):
        send_cmd(sock, "END_TURN")
        time.sleep(0.6)  # ход врагов + возможный бой синхронны в END_TURN
        st = handle_possible_battle(sock, f"END_TURN {i}")
        now = enemy_cells(st)
        if now != start_cells:
            moved = True
        print(f"  [END_TURN {i}] стеков: {len(now)}, клеток изменилось: "
              f"{len(now.symmetric_difference(start_cells))}")

    if not check("враги действуют: позиция хотя бы одного стека изменилась",
                 moved):
        pass  # уже записано в FAILURES
    # Дополнительный (необязательный) сигнал: деревня захвачена врагом.
    enemy_cities = [c for c in st.get("cities", []) if c.get("owner") == "enemy"]
    if enemy_cities:
        print(f"  (бонус: враг захватил {len(enemy_cities)} город(ов): "
              + ", ".join(c.get("name", "?") for c in enemy_cities) + ")")

    # ---- 3. Герой жив, мир в рабочем состоянии ----
    st = send_cmd(sock, "GET_STATE")
    check("герой в игре (hero_pos есть)", st.get("hero_pos") is not None,
          str(st.get("hero_pos")))
    n = len(st.get("map_enemies", []))
    check("число стеков в пределах (MAP_ENEMY_COUNT + рост)",
          0 < n <= MAP_ENEMY_COUNT + 10, f"stacks={n}")

    sock.close()

    if FAILURES:
        print(f"❌ Scenario 9 FAILED ({len(FAILURES)}): " + "; ".join(FAILURES))
        return False
    print("✅ Scenario 9 SUCCESS — enemy layer is alive")
    return True


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 9 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
