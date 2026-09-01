"""
scenario_8_city.py — Сценарий «Город в мире» (city-in-world).

Прогоняет реальную игру через сокет (localhost:9095, action-based,
newline-delimited JSON) и проверяет городскую подсистему end-to-end:

  1. Столица существует с начала игры (uid 0, owner "player", стартовый
     набор: промышленность/золото/еда/последователи).
  2. Герой входит в клетку столицы → экран города открывается сам
     (city_screen_open=true); CITY_CLOSE закрывает.
  3. CITY_BUILD: ферма построена в столице (промышленность списана,
     зданий +1).
  4. CITY_HIRE: последователь нанят (появился в команде героя,
     free_followers города уменьшилось).
  5. CITY_LEVEL: структурированный результат (ok или reason — уровень
     растёт только при выполнении условий).
  6. END_TURN: дань городов пришла герою (стратегическое золото > 0).
  7. Переход к ближайшей незахваченной деревне → захват: появился новый
     город (owner "player", стартовый набор), в нём работают
     CITY_BUILD и CITY_HIRE.

Запуск:
    python3 game/tools/scenarios/scenario_8_city.py
    # или через оркестратора:
    ./game/tools/shell/play_scenario.sh 8
"""

import json
import socket
import sys
import time

HOST, PORT = "localhost", 9095

FAILURES = []


def send_cmd(sock, action, args=None, top=None, cmd_id=0):
    # Протокол: newline-delimited JSON.
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


def wait_arrival(sock, target, tries=80):
    # Движение анимировано: ждём, пока герой реально встанет на клетку.
    for _ in range(tries):
        s = send_cmd(sock, "GET_STATE")
        if s.get("hero_pos") == target:
            return True
        if not s.get("moving", True) and s.get("hero_pos") != target:
            return False  # остановился по исчерпании ОД
        time.sleep(0.1)
    return False


def move_to_cell(sock, cell, day_budget=40):
    # Ходим к клетке, переночуя сколько нужно (ОД ~10/день). День тратится
    # только если герой НЕ дошёл за текущий день.
    for _ in range(day_budget):
        st = send_cmd(sock, "GET_STATE")
        if st.get("mode") == "battle":
            send_cmd(sock, "FORCE_RETREAT")
            send_cmd(sock, "END_TURN")
            continue
        if st.get("hero_pos") == cell:
            return True
        r = send_cmd(sock, "MOVE_TO", {}, top={"x": cell["x"], "y": cell["y"]})
        if "error" in r:
            return False  # недосягаемо (непроходимая цель/стена)
        wait_arrival(sock, cell)
        if send_cmd(sock, "GET_STATE").get("hero_pos") == cell:
            return True
        send_cmd(sock, "END_TURN")
    return send_cmd(sock, "GET_STATE").get("hero_pos") == cell


def step_away(sock, cell):
    # Одна клетка в любую сторону (объединённые offset-таблицы odd-r/even-r;
    # MOVE_TO сам отклонит непроходимые). Возвращает новую клетку или None.
    offsets = [(1, 0), (1, -1), (0, -1), (-1, 0), (0, 1), (1, 1),
               (-1, -1), (-1, 1)]
    for dx, dy in offsets:
        cand = {"x": cell["x"] + dx, "y": cell["y"] + dy}
        r = send_cmd(sock, "MOVE_TO", {}, top=cand)
        if "error" in r:
            continue
        wait_arrival(sock, cand)
        st = send_cmd(sock, "GET_STATE")
        if st.get("hero_pos") == cand:
            return cand
    return None


def find_village(sock):
    """Ближайшая к герою деревня, на которой ещё нет города."""
    st = send_cmd(sock, "GET_STATE")
    city_cells = {f"{c['center']['x']},{c['center']['y']}" for c in st.get("cities", [])}
    villages = [v for v in st.get("map_villages", [])
                if f"{v['x']},{v['y']}" not in city_cells]
    if not villages:
        return None
    hx, hy = st["hero_pos"]["x"], st["hero_pos"]["y"]
    villages.sort(key=lambda v: abs(v["x"] - hx) + abs(v["y"] - hy))
    return villages[0]


def run_scenario():
    print("--- Running Scenario 8 (City in World) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    send_cmd(sock, "START_GAME")
    time.sleep(1.0)  # даём сцене World отбутстрапиться

    st = send_cmd(sock, "GET_STATE")
    if not check("режим world", st.get("mode") == "world", str(st.get("mode"))):
        return False
    cap = st.get("capital") or {}
    check("столица есть (uid 0)", cap.get("uid") == 0, str(cap))
    check("столица принадлежит игроку", cap.get("owner") == "player", cap.get("owner", ""))
    check("стартовый набор: промышленность 30", abs(cap.get("industry", 0) - 30.0) < 0.01,
          str(cap.get("industry")))
    check("стартовый набор: свободные последователи 2", cap.get("free_followers") == 2,
          str(cap.get("free_followers")))
    capital_cell = {"x": cap["center"]["x"], "y": cap["center"]["y"]}

    # ---- 2. Входим в столицу → экран открывается сам ----
    check("ход к столице", move_to_cell(sock, capital_cell))
    check("экран города открыт в столице",
          send_cmd(sock, "GET_STATE").get("city_screen_open") is True)
    send_cmd(sock, "CITY_CLOSE")
    check("CITY_CLOSE закрыл экран",
          send_cmd(sock, "GET_STATE").get("city_screen_open") is False)
    # Чистый авто-открыт: выходим на соседнюю клетку и возвращаемся.
    away = step_away(sock, capital_cell)
    if away is not None:
        check("ход на соседнюю клетку", move_to_cell(sock, capital_cell))
        check("экран открылся САН при входе в столицу",
              send_cmd(sock, "GET_STATE").get("city_screen_open") is True)
    else:
        check("ход на соседнюю клетку", move_to_cell(sock, capital_cell),
              "нет свободной клетки — пропускаем чистую проверку авто-открытия")

    # ---- 3. Постройка фермы в столице (uid явно, чтобы экран пере-привязался) ----
    # Ходы к столице прошли несколько END_TURN — столица за это время
    # напроизводила промышленность, поэтому проверяем Дельту (−12),
    # а не абсолютный остаток.
    ind_before = float((send_cmd(sock, "GET_STATE").get("capital") or {}).get("industry", 0))
    r = send_cmd(sock, "CITY_BUILD", {"uid": 0, "building": "farm"})
    check("CITY_BUILD: ферма построена", r.get("ok") is True, str(r.get("reason", r)))
    check("CITY_BUILD: зданий стало 1", (r.get("city") or {}).get("buildings") == 1)
    ind_after = (r.get("city") or {}).get("industry", -1)
    check("CITY_BUILD: промышленность списана (стоимость фермы 12)",
          abs((ind_before - float(ind_after)) - 12.0) < 0.01,
          "before=%.2f after=%s" % (ind_before, ind_after))

    # ---- 4. Найм последователя ----
    st = send_cmd(sock, "GET_STATE")
    followers_before = len(st.get("followers", []))
    r = send_cmd(sock, "CITY_HIRE", {"uid": 0})
    check("CITY_HIRE: последователь нанят", r.get("ok") is True, str(r.get("reason", r)))
    f = r.get("follower") or {}
    check("CITY_HIRE: есть имя и путь", bool(f.get("name")) and bool(f.get("path")), str(f))
    check("CITY_HIRE: free_followers 2→1", (r.get("city") or {}).get("free_followers") == 1)
    st = send_cmd(sock, "GET_STATE")
    check("CITY_HIRE: герой видит нового последователя",
          len(st.get("followers", [])) == followers_before + 1)

    # ---- 5. Улучшение уровня (структурированный ответ в любом случае) ----
    r = send_cmd(sock, "CITY_LEVEL", {"uid": 0})
    check("CITY_LEVEL: структурированный результат",
          "ok" in r and "city" in r, str(r))
    if r.get("ok"):
        check("CITY_LEVEL: уровень вырос до 2", (r.get("city") or {}).get("level") == 2)

    send_cmd(sock, "CITY_CLOSE")

    # ---- 6. Ход: дань городов → герою ----
    st = send_cmd(sock, "GET_STATE")
    gold_before = st.get("strategic_resources", {}).get("gold", 0)
    send_cmd(sock, "END_TURN")
    time.sleep(0.5)
    st = send_cmd(sock, "GET_STATE")
    gold_after = st.get("strategic_resources", {}).get("gold", 0)
    check("END_TURN: дань пришла герою (золото выросло)", gold_after > gold_before,
          f"{gold_before} → {gold_after}")

    # ---- 7. Захват деревни ----
    village = find_village(sock)
    if not check("найдена незахваченная деревня", village is not None):
        return False
    print(f"  деревня: ({village['x']}, {village['y']})")
    check("ход к деревне", move_to_cell(sock, village))
    st = send_cmd(sock, "GET_STATE")
    new_cities = [c for c in st.get("cities", [])
                  if c["center"] == {"x": village["x"], "y": village["y"]}]
    if not check("деревня захвачена: город появился", len(new_cities) == 1,
                 str(st.get("cities"))):
        return False
    vc = new_cities[0]
    check("захваченная деревня: owner player", vc.get("owner") == "player")
    check("захваченная деревня: имя задано", bool(vc.get("name")))
    check("захваченная деревня: набор (2 последователя, 30 пром-сти)",
          vc.get("free_followers") == 2 and abs(vc.get("industry", 0) - 30.0) < 0.01,
          str(vc))
    check("захваченная деревня: экран открыт", st.get("city_screen_open") is True)

    vuid = vc["uid"]
    r = send_cmd(sock, "CITY_BUILD", {"uid": vuid, "building": "farm"})
    check("CITY_BUILD в деревне: ферма построена", r.get("ok") is True,
          str(r.get("reason", r)))
    r = send_cmd(sock, "CITY_HIRE", {"uid": vuid})
    check("CITY_HIRE в деревне: последователь нанят", r.get("ok") is True,
          str(r.get("reason", r)))

    send_cmd(sock, "CITY_CLOSE")
    check("CITY_CLOSE после деревни",
          send_cmd(sock, "GET_STATE").get("city_screen_open") is False)
    # city-navigation: на старте уже два города (Перворечье + Город 2).
    check("всего городов: 3 (столица + Город 2 + деревня)",
          len(send_cmd(sock, "GET_STATE").get("cities", [])) == 3)

    sock.close()

    if FAILURES:
        print(f"❌ Scenario 8 FAILED ({len(FAILURES)}): " + "; ".join(FAILURES))
        return False
    print("✅ Scenario 8 SUCCESS — city in world works end-to-end")
    return True


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 8 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
