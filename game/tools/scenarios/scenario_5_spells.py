"""
scenario_5_spells.py — Сценарий «Spells».

Проверка яда SpellCaster через сокет (localhost:9095): синтетический юнит
(UnitStats + UnitStack + BattleState.BattleUnit), поэтому логика заклинаний
прогоняется без живого боя (в безголовом режиме он не резолвится сам).

Проверяет ветки SpellCaster.cast:
  * урон по множителю SP (magic_arrow / lightning_bolt) — damage & kills;
  * бафф (haste) — применён статус (status >= 0);
  * лечение (cure) — применён статус;
  * воскрешение (resurrection) — revive_count >= 1 на мёртвом юните;
  * иммунитет драконов к заклинаниям < 4 уровня (curse -> immune);
  * иммунитет нежити к bless (bless -> immune);
  * магическое сопротивление (resistant) — ход без ошибки;
  * неизвестное заклинание -> not_found.

Запуск:
    python3 tools/scenarios/scenario_5_spells.py
    # или: ./tools/shell/play_scenario.sh 5
    # или: ./tools/shell/run_all_scenarios.sh
"""

import sys

from scenario_lib import connect, send_cmd, Reporter, scan_server_log


def cast(sock, spell_id, tags=None, hp=100, count=10, resistant=False):
    args = {"spell_id": spell_id, "hp": hp, "count": count, "resistant": resistant}
    if tags:
        args["tags"] = list(tags)
    return send_cmd(sock, "CAST_SPELL", args)


def run_scenario():
    print("--- Running Scenario 5 (Spells) ---")
    rep = Reporter()
    sock = connect()

    # 1. Реестр заклинаний доступен.
    spells = send_cmd(sock, "GET_SPELLS")
    rep.check("GET_SPELLS no error", "error" not in spells, str(spells.get("error")))
    if "error" in spells:
        sock.close()
        print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 5 ({rep.summary()})")
        return rep.ok
    total = spells.get("count", 0)
    rep.check("spell registry non-empty", total > 0, f"count={total}")

    known = {s["id"] for s in spells.get("spells", [])}
    required = ["magic_arrow", "lightning_bolt", "haste", "cure", "resurrection", "curse", "bless"]
    rep.check("registry has required spells",
              all(sid in known for sid in required),
              f"missing={[s for s in required if s not in known]}")

    # 2. Урон по множителю SP=8: magic_arrow mult=10 -> 80 dmg; lightning_bolt mult=25 -> 200 dmg.
    r = cast(sock, "magic_arrow")
    rep.check("magic_arrow damage", r.get("damage") == 80 and r.get("kills") == 1, str(r))

    r = cast(sock, "lightning_bolt")
    rep.check("lightning_bolt damage", r.get("damage") == 200 and r.get("kills") == 2, str(r))

    # 3. Бафф — применён статус (status >= 0, не дефолтный -1).
    r = cast(sock, "haste")
    rep.check("haste buff", r.get("result") == "success" and r.get("status", -1) >= 0, str(r))

    # 4. Лечение (cure) — применён статус.
    r = cast(sock, "cure")
    rep.check("cure buff", r.get("result") == "success" and r.get("status", -1) >= 0, str(r))

    # 5. Воскрешение — мёртвый юнит (count=0) -> revive_count >= 1.
    r = cast(sock, "resurrection", count=0)
    rep.check("resurrection revive", r.get("result") == "success" and r.get("revive_count", 0) >= 1, str(r))

    # 6. Иммунитет драконов: curse (ур. 1 < 4) -> immune.
    r = cast(sock, "curse", tags=["dragon"])
    rep.check("dragon immunity", r.get("result") == "immune", str(r))

    # 7. Иммунитет нежити: bless -> immune.
    r = cast(sock, "bless", tags=["undead"])
    rep.check("undead immunity", r.get("result") == "immune", str(r))

    # 8. Магическое сопротивление — ход без ошибки.
    r = cast(sock, "magic_arrow", resistant=True)
    rep.check("magic_resistant cast", "error" not in r and r.get("result") == "success", str(r))

    # 9. неизвестное заклинание -> not_found.
    r = cast(sock, "does_not_exist")
    rep.check("unknown spell not_found", r.get("result") == "not_found", str(r))

    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} "
          f"(errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 5 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 5 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
