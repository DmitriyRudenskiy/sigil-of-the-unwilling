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

import socket
import sys
import time

from scenario_lib import connect, send_cmd, Reporter, scan_server_log


def run_scenario():
    print("--- Running Scenario 12 (Hero Survival: death flow) ---")
    rep = Reporter()
    sock = connect()

    send_cmd(sock, "START_GAME")
    time.sleep(1.2)  # даём сцене World ноутстрапиться

    st = send_cmd(sock, "GET_STATE")
    rep.check("режим world", st.get("mode") == "world", str(st.get("mode")))
    rep.check("есть города игрока", len(st.get("cities", [])) > 0, str([c.get("name") for c in st.get("cities", [])]))
    rep.check("герой жив на старте", st.get("hero_pos") is not None, str(st.get("hero_pos")))

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
    rep.check("мир тикает, герой жив после ходов", alive_after_ticks, "hero_pos не пропал")

    # ---- 3. Смерть по hero-survival (честная цепочка) ----
    r = send_cmd(sock, "HERO_DIE")
    if not rep.check("HERO_DIE принят", r.get("status") == "hero_dead", str(r)):
        sock.close()
        print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 12 ({rep.summary()})")
        return rep.ok

    st = send_cmd(sock, "GET_STATE")
    eg = st.get("endgame")
    rep.check("GET_STATE содержит блок endgame", isinstance(eg, dict), str(st.keys()))
    rep.check("смерть без преемника → DEFEAT", eg.get("state") == "DEFEAT", str(eg))
    rep.check("end_reason = unsuccessored_death", eg.get("end_reason") == "unsuccessored_death", str(eg))
    rep.check("герой снят с карты (hero_pos=None)", st.get("hero_pos") is None, str(st.get("hero_pos")))

    r = send_cmd(sock, "END_TURN")
    rep.check("END_TURN после DEFEAT заблокирован", r.get("error") == "Game over", str(r))
    st = send_cmd(sock, "GET_STATE")
    rep.check("сервер жив (GET_STATE отвечает)", isinstance(st.get("endgame"), dict), str(st.get("endgame")))

    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} (errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 12 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 12 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
