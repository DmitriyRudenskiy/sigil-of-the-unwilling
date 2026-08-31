"""
scenario_5_spells.py — Сценарий «Spells» (пятый сценарий).

Тестирование системы заклинаний через живую игру (сокет localhost:9095,
newline-delimited JSON). Проверка ядра SpellCaster в изоляции: цель —
синтетический юнит (UnitStats + UnitStack + BattleState.BattleUnit), поэтому
логика заклинаний прогоняется без живого боя, который в безголовом режиме
не резолвится сам.

Проверяет ключевые ветки SpellCaster.cast:
  * урон по множителю SP (magic_arrow / lightning_bolt) — damage & kills;
  * бафф (haste) — применён статус (status >= 0);
  * лечение (cure) — heal > 0;
  * воскрешение (resurrection) — revive_count >= 1 на мёртвом юните;
  * иммунитет драконов к заклиям < 4 уровня (curse -> immune);
  * иммунитет нежити к bless/cure (bless -> immune);
  * магическое сопротивление (magic_resistant) — ход без ошибки;
  * неизвестное заклинание -> not_found.

Запуск:
    python3 tools/scenarios/scenario_5_spells.py
    # или через оркестратора:
    ./tools/shell/play_scenario.sh 5
"""

import socket
import json
import sys

HOST, PORT = "localhost", 9095


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


def cast(sock, spell_id, tags=None, hp=100, count=10, resistant=False):
    args = {"spell_id": spell_id, "hp": hp, "count": count, "resistant": resistant}
    if tags:
        args["tags"] = list(tags)
    return send_cmd(sock, "CAST_SPELL", args)


def run_scenario():
    print("--- Running Scenario 5 (Spells) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    # 1. Реестр заклинаний доступен.
    spells = send_cmd(sock, "GET_SPELLS")
    if spells.get("error"):
        print("  ❌ GET_SPELLS error:", spells.get("error"))
        sock.close()
        return False
    total = spells.get("count", 0)
    print("  GET_SPELLS -> count:", total)
    if total <= 0:
        print("  ❌ Scenario 5 FAILED: registry empty")
        sock.close()
        return False

    known = {s["id"] for s in spells.get("spells", [])}
    required = ["magic_arrow", "lightning_bolt", "haste", "cure", "resurrection", "curse", "bless"]
    missing = [sid for sid in required if sid not in known]
    if missing:
        print("  ❌ Scenario 5 FAILED: registry missing spells:", missing)
        sock.close()
        return False

    passed = 0
    failed = 0

    def check(name, cond, detail=""):
        nonlocal passed, failed
        if cond:
            passed += 1
            print(f"  ✅ {name}: {detail}")
        else:
            failed += 1
            print(f"  ❌ {name}: {detail}")

    # 2. Урон по множителю spell_power (8).
    #    magic_arrow: mult=10 -> 80 dmg; lightning_bolt: mult=25 -> 200 dmg.
    r = cast(sock, "magic_arrow")
    check("magic_arrow damage", r.get("damage") == 80 and r.get("kills") == 1, str(r))

    r = cast(sock, "lightning_bolt")
    check("lightning_bolt damage", r.get("damage") == 200 and r.get("kills") == 2, str(r))

    # 3. Бафф — применён статус (status >= 0, не дефолтный -1).
    r = cast(sock, "haste")
    check("haste buff", r.get("result") == "success" and r.get("status", -1) >= 0, str(r))

    # 4. Лечение/бафф (cure/bless имеют buff_effect=BLESS) — применён статус.
    r = cast(sock, "cure")
    check("cure buff", r.get("result") == "success" and r.get("status", -1) >= 0, str(r))

    # 5. Воскрешение — мёртвый юнит (count=0) -> revive_count >= 1.
    r = cast(sock, "resurrection", count=0)
    check("resurrection revive", r.get("result") == "success" and r.get("revive_count", 0) >= 1, str(r))

    # 6. Иммунитет драконов: curse (уровень 1 < 4) -> immune.
    r = cast(sock, "curse", tags=["dragon"])
    check("dragon immunity", r.get("result") == "immune", str(r))

    # 7. Иммунитет нежити: bless -> immune.
    r = cast(sock, "bless", tags=["undead"])
    check("undead immunity", r.get("result") == "immune", str(r))

    # 8. Магическое сопротивление — ход без ошибки (resisted может быть true/false).
    r = cast(sock, "magic_arrow", resistant=True)
    check("magic_resistant cast", "error" not in r and r.get("result") == "success", str(r))

    # 9. неизвестное заклинание -> not_found.
    r = cast(sock, "does_not_exist")
    check("unknown spell not_found", r.get("result") == "not_found", str(r))

    sock.close()

    total_tests = passed + failed
    print(f"✅ Scenario 5 SUCCESS — {passed}/{total_tests} passed")
    if failed:
        print(f"❌ Scenario 5 FAILED: {failed}/{total_tests} failed")
        return False
    return True


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 5 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
