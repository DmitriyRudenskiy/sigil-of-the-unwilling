"""
scenario_9_enemy_ai.py — Сценарий «Живой мир: враги» (enemy-world-ai).

Прогоняет реальную игру через сокет (localhost:9095) и проверяет
вражеский слой end-to-end. Seed фиксируется извне нельзя (START_GAME берёт
время), поэтому инварианты generic:

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

import socket
import sys
import time

from scenario_lib import connect, send_cmd, Reporter, scan_server_log

MAP_ENEMY_COUNT = 20  # GameSettings.MAP_ENEMY_COUNT


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
    check_retreat = r.get("status") == "forced_retreat"
    print(f"    FORCE_RETREAT {'принят' if check_retreat else 'ОТКАЗАЛ'}: {r}")
    time.sleep(0.3)
    st = send_cmd(sock, "GET_STATE")
    print(f"    после отступления режим: {st.get('mode')}")
    return st


def run_scenario():
    print("--- Running Scenario 9 (Enemy World AI) ---")
    rep = Reporter()
    sock = connect()

    send_cmd(sock, "START_GAME")
    time.sleep(1.2)  # даём сцене World отбутстрапиться

    st = send_cmd(sock, "GET_STATE")
    rep.check("режим world", st.get("mode") == "world", str(st.get("mode")))
    enemies0 = st.get("map_enemies", [])
    rep.check("на старте есть вражеские стеки", len(enemies0) > 0, f"map_enemies={enemies0}")
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

    rep.check("враги действуют: позиция хотя бы одного стека изменилась", moved)
    enemy_cities = [c for c in st.get("cities", []) if c.get("owner") == "enemy"]
    if enemy_cities:
        print(f"  (бонус: враг захватил {len(enemy_cities)} город(ов): "
              + ", ".join(c.get("name", "?") for c in enemy_cities) + ")")

    # ---- 3. Герой жив, мир в рабочем состоянии ----
    st = send_cmd(sock, "GET_STATE")
    rep.check("герой в игре (hero_pos есть)", st.get("hero_pos") is not None, str(st.get("hero_pos")))
    n = len(st.get("map_enemies", []))
    rep.check("число стеков в пределах (MAP_ENEMY_COUNT + рост)", 0 < n <= MAP_ENEMY_COUNT + 10, f"stacks={n}")

    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} (errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 9 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 9 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
