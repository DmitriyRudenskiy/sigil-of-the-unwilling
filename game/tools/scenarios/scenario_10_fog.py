"""
scenario_10_fog.py — Сценарий «Туман войны» (fog-of-war).

Прогоняет реальную игру через сокет (localhost:9095) и проверяет туман
войны end-to-end:

  1. GET_STATE содержит блок fog: explored >= 1, visible >= 1 и
     visible <= explored (visible — текущий диск, explored — накопленный).
  2. visible_enemies — отфильтрованный список: не больше, чем всех стеков.
  3. Движение героя раскрывает туман: explored монотонно не убывает и к
     концу прогона строго больше, чем на старте (разведка — за героем).
     Туман раскрывает вражьи стеки: за прогон герой видел строго больше
     отдельных стеков, чем в стартовом кадре.
  4. В конце герой жив, режим world.

Разведка: каждый день герой шлёт MOVE_TO ближайшей деревне. Неразведанные
клетки непроходимы, поэтому A* режет путь по границе разведанного — герой
следует частичному пути и продвигает границу тумана на клетку-две; каждый
следующий день путь длиннее. Если путь не найден вовсе — один шаг в соседнюю
клетку в сторону цели.

Бой с врагом (туман не скрывает столкновение на видимой клетке) сценарий
аварийно отступает (FORCE_RETREAT) и продолжает.

Запуск:
    python3 game/tools/scenarios/scenario_10_fog.py
    # или через оркестратора:
    ./game/tools/shell/play_scenario.sh 10
"""

import socket
import sys
import time

from scenario_lib import connect, send_cmd, Reporter, scan_server_log, wait_arrival

MAX_DAYS = 25
NEIGHBORS = [(-1, 0), (1, 0), (0, -1), (0, 1),
             (-1, -1), (1, -1), (-1, 1), (1, 1)]


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
    rep = Reporter()
    sock = connect()

    send_cmd(sock, "START_GAME")
    time.sleep(1.2)  # даём сцене World отбутстрапиться

    st = send_cmd(sock, "GET_STATE")
    rep.check("режим world", st.get("mode") == "world", str(st.get("mode")))

    fog = st.get("fog")
    rep.check("GET_STATE содержит блок fog", isinstance(fog, dict), str(st.keys()))
    e0, v0 = fog_counts(st)
    rep.check("explored >= 1 (диск героя раскрыт)", e0 >= 1, f"explored={e0}")
    rep.check("visible >= 1 (герой видит себя)", v0 >= 1, f"visible={v0}")
    rep.check("visible <= explored", v0 <= e0, f"visible={v0}, explored={e0}")

    enemies = st.get("map_enemies", [])
    visible_enemies = st.get("visible_enemies", [])
    rep.check("visible_enemies — список", isinstance(visible_enemies, list))
    rep.check("visible_enemies <= всех стеков", len(visible_enemies) <= len(enemies), f"visible={len(visible_enemies)}, all={len(enemies)}")
    print(f"  на старте: explored={e0}, visible={v0}, врагов видимо {len(visible_enemies)}/{len(enemies)}")

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

        villages = [v for v in st.get("map_villages", []) if (v["x"], v["y"]) not in visited_villages]
        target = None
        if villages:
            villages.sort(key=lambda v: abs(v["x"] - hx) + abs(v["y"] - hy))
            target = villages[0]

        moved = False
        if target is not None:
            r = send_cmd(sock, "MOVE_TO", {}, top={"x": target["x"], "y": target["y"]})
            if "error" not in r:
                wait_arrival(sock, {"x": target["x"], "y": target["y"]})
                hx2 = send_cmd(sock, "GET_STATE").get("hero_pos", {})
                if hx2 == {"x": target["x"], "y": target["y"]}:
                    visited_villages.add((target["x"], target["y"]))
                moved = True
        if not moved and target is not None:
            near = sorted(NEIGHBORS, key=lambda d: abs(d[0] + hx - target["x"]) + abs(d[1] + hy - target["y"]))
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

    monotone = all(b >= a for a, b in zip(explored_samples, explored_samples[1:]))
    rep.check("explored монотонен (не убывает по дням)", monotone, str(explored_samples))
    e_final = explored_samples[-1]
    rep.check("туман раскрылся движением (explored вырос)", e_final > e0, f"start={e0}, final={e_final}")
    rep.check("скрытые враги стали видимыми на подходе", len(seen_enemy_cells) > len(visible_enemies), f"seen={len(seen_enemy_cells)}, start={len(visible_enemies)}")

    rep.check("герой в игре (hero_pos есть)", st.get("hero_pos") is not None, str(st.get("hero_pos")))
    rep.check("режим world в конце", st.get("mode") == "world", str(st.get("mode")))

    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} (errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 10 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 10 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
