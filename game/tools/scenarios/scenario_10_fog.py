"""
scenario_10_fog.py — Сценарий «Туман войны» (fog-of-war).

Прогоняет реальную игру через сокет (localhost:9095) и проверяет туман
войны end-to-end:

  1. GET_STATE содержит блок fog: explored >= 1, visible >= 1 и
     visible <= explored (visible — текущий диск, explored — накопленный).
  2. visible_enemies — отфильтрованный список: не больше, чем всех стеков.
  3. Движение героя раскрывает туман: explored монотонно не убывает и к
     концу прогона строго больше, чем на старте (разведка — за героем).
     Туман раскрывает новые вражьи стеки: за прогон герой видел строго
     больше отдельных стеков, чем в стартовом кадре.
  4. В конце герой жив, режим world.

Разведка: каждый день герой шлёт MOVE_TO ближайшей деревне. Неразведанные
клетки непроходимы, поэтому A* режет путь по границе разведанного — герой
следует частичному пути и продвигает границу тумана на клетку-две; каждый
следующий день путь длиннее. Если путь не найден вовсе (цель в «окне»
воды и т.п.) — один шаг в соседнюю клетку в сторону цели.

Бой с врагом (туман не скрывает столкновение на видимой клетке)
сценарий аварийно отступает (FORCE_RETREAT) и продолжает.

Запуск:
    python3 game/tools/scenarios/scenario_10_fog.py
    # или через оркестратора:
    ./game/tools/shell/play_scenario.sh 10
"""

import json
import socket
import sys
import time

HOST, PORT = "localhost", 9095

FAILURES = []
MAX_DAYS = 25
# 8 окрестностей (для hex достаточно — шаг в любую проходимую сторону).
NEIGHBORS = [(-1, 0), (1, 0), (0, -1), (0, 1),
             (-1, -1), (1, -1), (-1, 1), (1, 1)]


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


def wait_arrival(sock, target, tries=60):
    for _ in range(tries):
        s = send_cmd(sock, "GET_STATE")
        if s.get("hero_pos") == {"x": target["x"], "y": target["y"]}:
            return True
        if not s.get("moving", True) and s.get("hero_pos") != {"x": target["x"], "y": target["y"]}:
            return False
        time.sleep(0.1)
    return False


def handle_battle(sock):
    st = send_cmd(sock, "GET_STATE")
    if st.get("mode") == "battle":
        print("  [battle] враг атаковал героя — аварийное отступление")
        send_cmd(sock, "FORCE_RETREAT")
        send_cmd(sock, "END_TURN")
    return st


def fog_counts(st):
    fog = st.get("fog") or {}
    return int(fog.get("explored", 0)), int(fog.get("visible", 0))


def run_scenario():
    print("--- Running Scenario 10 (Fog of War) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    send_cmd(sock, "START_GAME")
    time.sleep(1.2)  # даём сцене World отбутстрапиться

    st = send_cmd(sock, "GET_STATE")
    if not check("режим world", st.get("mode") == "world", str(st.get("mode"))):
        return False

    # ---- 1. Блок fog в состоянии ----
    fog = st.get("fog")
    if not check("GET_STATE содержит блок fog", isinstance(fog, dict), str(st.keys())):
        return False
    e0, v0 = fog_counts(st)
    check("explored >= 1 (диск героя раскрыт)", e0 >= 1, f"explored={e0}")
    check("visible >= 1 (герой видит себя)", v0 >= 1, f"visible={v0}")
    check("visible <= explored", v0 <= e0, f"visible={v0}, explored={e0}")

    # ---- 2. Филтр врагов в тумане ----
    enemies = st.get("map_enemies", [])
    visible_enemies = st.get("visible_enemies", [])
    check("visible_enemies — список", isinstance(visible_enemies, list))
    check("visible_enemies <= всех стеков",
          len(visible_enemies) <= len(enemies),
          f"visible={len(visible_enemies)}, all={len(enemies)}")
    print(f"  на старте: explored={e0}, visible={v0}, "
          f"врагов видимо {len(visible_enemies)}/{len(enemies)}")

    # ---- 3. Движение расширяет туман ----
    explored_samples = [e0]
    visited_villages = set()
    seen_enemy_cells = set()
    for c in visible_enemies:
        seen_enemy_cells.add(f"{c['x']}-{c['y']}")

    for day in range(1, MAX_DAYS + 1):
        st = handle_battle(sock)
        if st.get("mode") != "world":
            print(f"  [{day}] неожиданный режим '{st.get('mode')}' — стоп")
            break
        hx = st["hero_pos"]["x"]
        hy = st["hero_pos"]["y"]

        # Цель: ближайшая непосещённая деревня (может быть за туманом).
        villages = [v for v in st.get("map_villages", [])
                    if (v["x"], v["y"]) not in visited_villages]
        target = None
        if villages:
            villages.sort(key=lambda v: abs(v["x"] - hx) + abs(v["y"] - hy))
            target = villages[0]

        moved = False
        if target is not None:
            r = send_cmd(sock, "MOVE_TO", {}, top={"x": target["x"], "y": target["y"]})
            if "error" not in r:
                # Частичный путь уже сдвинул героя к цели (до границы тумана);
                # если цель оказалась в разведанной зоне — герой дошёл.
                wait_arrival(sock, {"x": target["x"], "y": target["y"]})
                hx2 = send_cmd(sock, "GET_STATE").get("hero_pos", {})
                if hx2 == {"x": target["x"], "y": target["y"]}:
                    visited_villages.add((target["x"], target["y"]))
                moved = True
        if not moved and target is not None:
            # Путь не найден вовсе — шаг в соседнюю клетку в сторону цели.
            near = sorted(NEIGHBORS,
                          key=lambda d: abs(d[0] + hx - target["x"])
                                        + abs(d[1] + hy - target["y"]))
            for dx, dy in near:
                r = send_cmd(sock, "MOVE_TO", {}, top={"x": hx + dx, "y": hy + dy})
                if "error" not in r:
                    wait_arrival(sock, {"x": hx + dx, "y": hy + dy})
                    moved = True
                    break
        if not moved:
            print(f"  [{day}] шаг не удался (вода/блок?) — END_TURN")

        send_cmd(sock, "COLLECT_HERE")
        send_cmd(sock, "END_TURN")
        time.sleep(0.4)
        st = send_cmd(sock, "GET_STATE")
        e_now, _ = fog_counts(st)
        for c in st.get("visible_enemies", []):
            seen_enemy_cells.add(f"{c['x']}-{c['y']}")
        explored_samples.append(e_now)
        if day % 5 == 0 or day == MAX_DAYS:
            print(f"  [{day}] explored={e_now}, деревень visited={len(visited_villages)}")

    # Монотонность и прирост.
    monotone = all(b >= a for a, b in zip(explored_samples, explored_samples[1:]))
    check("explored монотонен (не убывает по дням)", monotone,
          str(explored_samples))
    e_final = explored_samples[-1]
    check("туман раскрылся движением (explored вырос)",
          e_final > e0, f"start={e0}, final={e_final}")
    # Туман раскрыл новые вражьи стеки: за прогон герой видел строго больше
    # отдельных стеков, чем в стартовом кадре.
    check("скрытые враги стали видимыми на подходе",
          len(seen_enemy_cells) > len(visible_enemies),
          f"seen={len(seen_enemy_cells)}, start={len(visible_enemies)}")

    # ---- 4. Мир в рабочем состоянии ----
    check("герой в игре (hero_pos есть)", st.get("hero_pos") is not None,
          str(st.get("hero_pos")))
    check("режим world в конце", st.get("mode") == "world",
          str(st.get("mode")))

    sock.close()

    if FAILURES:
        print(f"❌ Scenario 10 FAILED ({len(FAILURES)}): " + "; ".join(FAILURES))
        return False
    print(f"✅ Scenario 10 SUCCESS — fog works: explored {e0}→{e_final}, "
          f"villages {len(visited_villages)}, вражьих стеков раскрыто: "
          f"{len(seen_enemy_cells)}")
    return True


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 10 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
