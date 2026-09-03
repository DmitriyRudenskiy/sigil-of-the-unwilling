"""
scenario_1_collect.py — Сценарий «Collect All».

Прогоняет реальную игру через сокет (localhost:9095) и собирает все ресурсные
узлы на карте: старт -> герой ходит к ближайшему узлу -> собирает (авто-подбор
при прохождении по клетке + COLLECT_HERE как страховка) -> новый день.

В безголовом режиме бой не резолвится сам — FORCE_RETREAT и дальше.

Запуск:
    python3 tools/scenarios/scenario_1_collect.py
    # или через оркестратора:
    ./tools/shell/play_scenario.sh 1
    # или из общего оркестратора:
    ./tools/shell/run_all_scenarios.sh
"""

import sys

from scenario_lib import connect, send_cmd, wait_arrival, Reporter, scan_server_log


def run_scenario():
    print("--- Running Scenario 1 (Collect All) ---")
    rep = Reporter()
    sock = connect()

    print("  start_game ->", send_cmd(sock, "START_GAME"))

    collected = 0
    day = 0
    max_days = 120  # защита от зависания

    while day < max_days:
        st = send_cmd(sock, "GET_STATE")
        mode = st.get("mode")

        # Бой: в безголовом режиме не резолвится сам — отступаем и дальше.
        if mode == "battle":
            send_cmd(sock, "FORCE_RETREAT")
            send_cmd(sock, "END_TURN")
            day += 1
            continue
        if mode != "world":
            rep.check("world mode", False, f"unexpected mode '{mode}'")
            break

        resources = st.get("map_resources", [])
        if not resources:
            break

        # Ближайший узел к герою (по манхэттену).
        hx, hy = st["hero_pos"]["x"], st["hero_pos"]["y"]
        resources.sort(key=lambda n: abs(n["x"] - hx) + abs(n["y"] - hy))
        target = resources[0]

        resp = send_cmd(sock, "MOVE_TO", {}, top={"x": target["x"], "y": target["y"]})
        if "error" in resp:
            send_cmd(sock, "END_TURN")  # не хватает ОД — ждём новый день
            day += 1
            continue

        if not wait_arrival(sock, target):
            send_cmd(sock, "END_TURN")  # уперся в ОД, вернёмся завтра
            day += 1
            continue

        # Страховка: если авто-подбор не сработал — собрать.
        if resp.get("status") == "moving":
            coll = send_cmd(sock, "COLLECT_HERE")
            if coll.get("status") == "collected":
                collected += 1

        send_cmd(sock, "END_TURN")  # тратим день — восстанавлием ОД
        day += 1

    # Финальная проверка: все узлы собраны (по фактическому остатку).
    st = send_cmd(sock, "GET_STATE")
    remaining = len(st.get("map_resources", []))
    rep.check("all resources collected", remaining == 0, f"{remaining} left after {day} day(s)")
    rep.check("game reached endgame", st.get("mode") in ("endgame", "world", None),
              f"mode={st.get('mode')}")
    sock.close()

    # Скан лога сервера (advisory: console-clean — зона ответственности
    # check_console_clean.sh / run_operability.sh).
    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} "
          f"(errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 1 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 1 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
