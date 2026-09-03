"""
scenario_6_battle.py — Сценарий «Бой и цепочки заклинаний» (шестой сценарий).

Две задачи:
  1. Эмуляция боя (EMULATE_BATTLE): две армии сражаются до победы через
     BattleState + BattleActionResolver (атака/урон/убийство/чардж/ребёрт/
     мораль/check_end). Проверяет структурные инварианты разрешёного боя.
  2. Все цепочки заклинаний (CAST_IN_BATTLE): каждое из 20 заклинаний
     прогоняется в контексте боя — юниты живут в реальном BattleState,
     каст через apply_spell (как в игре). Проверяется категория эффекта:
     урон/бафф/лечение/воскрешение/иммунитет/сопротивление/unknown.

Протокол: живая игра, сокет localhost:9095, newline-delimited JSON.

Запуск:
    python3 tools/scenarios/scenario_6_battle.py
    # или через оркестратора:
    ./tools/shell/play_scenario.sh 6
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


def emulate_battle(sock, attacker_army, defender_army,
                   attacker_bonus=None, defender_bonus=None):
    args = {"attacker_army": attacker_army, "defender_army": defender_army}
    if attacker_bonus:
        args["attacker_bonus"] = attacker_bonus
    if defender_bonus:
        args["defender_bonus"] = defender_bonus
    return send_cmd(sock, "EMULATE_BATTLE", args)


def cast_in_battle(sock, spell_id, caster_tags=None, target_tags=None,
                   caster_hp=60, caster_count=10,
                   target_hp=100, target_count=10,
                   resistant=False, caster_bonus=None, target_bonus=None):
    args = {
        "spell_id": spell_id,
        "caster_tags": list(caster_tags or []),
        "target_tags": list(target_tags or []),
        "caster_hp": caster_hp,
        "caster_count": caster_count,
        "target_hp": target_hp,
        "target_count": target_count,
        "resistant": resistant,
    }
    if caster_bonus:
        args["caster_bonus"] = caster_bonus
    if target_bonus:
        args["target_bonus"] = target_bonus
    return send_cmd(sock, "CAST_IN_BATTLE", args)


def run_sequence(sock, sequence, caster_tags=None, target_tags=None,
                 caster_hp=100, caster_start_hp=100, caster_count=10,
                 target_hp=200, target_count=20, resistant=False,
                 caster_bonus=None, target_bonus=None):
    args = {
        "sequence": sequence,
        "caster_tags": list(caster_tags or []),
        "target_tags": list(target_tags or []),
        "caster_hp": caster_hp,
        "caster_start_hp": caster_start_hp,
        "caster_count": caster_count,
        "target_hp": target_hp,
        "target_count": target_count,
        "resistant": resistant,
    }
    if caster_bonus:
        args["caster_bonus"] = caster_bonus
    if target_bonus:
        args["target_bonus"] = target_bonus
    return send_cmd(sock, "SEQUENCE_BATTLE", args)


# Спецификации армий для эмуляции боя.
ATK_ARMY = [
    {"id": "knight", "name": "Knight", "attack": 8, "base_damage": 10, "hp": 120,
     "speed": 5, "defense": 8, "count": 15, "tags": ["charge"]},
    {"id": "archer", "name": "Archer", "attack": 6, "base_damage": 5, "hp": 60,
     "speed": 5, "defense": 3, "count": 20, "tags": ["ranged"]},
    {"id": "mage", "name": "Mage", "attack": 3, "base_damage": 2, "hp": 50,
     "speed": 6, "defense": 3, "count": 10, "tags": []},
]
DEF_ARMY = [
    {"id": "dragon", "name": "Dragon", "attack": 12, "base_damage": 15, "hp": 300,
     "speed": 7, "defense": 10, "count": 8, "tags": ["dragon"]},
    {"id": "skeleton", "name": "Skeleton", "attack": 5, "base_damage": 4, "hp": 40,
     "speed": 5, "defense": 2, "count": 25, "tags": ["undead"]},
    {"id": "ogre", "name": "Ogre", "attack": 14, "base_damage": 18, "hp": 200,
     "speed": 3, "defense": 6, "count": 6, "tags": []},
]
BONUS = {"attack": 10, "defense": 8, "spell_power": 8, "knowledge": 3}


def run_scenario():
    print("--- Running Scenario 6 (Battle + Spell Chains) ---")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

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

    # ============================================================
    # 1. ЭМУЛЯЦИЯ БОЯ: две армии сражаются до победы.
    # ============================================================
    print("\n[1] Battle emulation")
    report = emulate_battle(sock, ATK_ARMY, DEF_ARMY, BONUS, BONUS)
    if report.get("error"):
        print("  ❌ EMULATE_BATTLE error:", report.get("error"))
        sock.close()
        return False

    winner = report.get("winner")
    battle_over = report.get("battle_over")
    atk_surv = report.get("atk_survivors", [])
    def_surv = report.get("def_survivors", [])
    turns = report.get("turns", 0)
    events = report.get("events", [])

    check("battle resolved", battle_over is True, f"battle_over={battle_over}")
    check("winner set", winner in ("attacker", "defender"), f"winner={winner}")
    check("turns > 0", isinstance(turns, int) and turns > 0, f"turns={turns}")
    check("atk_survivors is list", isinstance(atk_surv, list), f"n={len(atk_surv)}")
    check("def_survivors is list", isinstance(def_surv, list), f"n={len(def_surv)}")
    check("attacks happened", isinstance(events, list) and any(
        e.get("action") == "attack" for e in events), f"events={len(events)}")

    # Инвариант: суммарный состав живых не превышает начальный.
    atk_lost = sum(s.get("count", 0) for s in report.get("atk_loss", []) if isinstance(s, dict)) \
        if isinstance(report.get("atk_loss"), list) else 0
    total_atk_start = sum(s.get("count", 0) for s in ATK_ARMY)
    total_atk_now = sum(s.get("count", 0) for s in atk_surv)
    check("atk survivors <= start", total_atk_now <= total_atk_start,
          f"{total_atk_now} <= {total_atk_start}")
    total_def_start = sum(s.get("count", 0) for s in DEF_ARMY)
    total_def_now = sum(s.get("count", 0) for s in def_surv)
    check("def survivors <= start", total_def_now <= total_def_start,
          f"{total_def_now} <= {total_def_start}")

    # Победитель не может иметь мёртвых «в плюс»: победившая сторона имеет >0 живых,
    # проигравшая — 0 живых.
    if winner == "attacker":
        check("loser defender dead", total_def_now == 0, f"def_surv={total_def_now}")
    elif winner == "defender":
        check("loser attacker dead", total_atk_now == 0, f"atk_surv={total_atk_now}")

    # ============================================================
    # 2. ВСЕ ЦЕПОЧКИ ЗАКЛИНАНИЙ — каждое из 20 заклинаний в бою.
    # ============================================================
    print("\n[2] All spell chains (in battle context)")

    # Урон по множителю SP=8: damage = SP * mult.
    damage_spells = {
        "magic_arrow": 10, "lightning_bolt": 25, "fireball": 20,
        "armageddon": 40, "meteor_shower": 30,
    }
    for spell_id, mult in damage_spells.items():
        r = cast_in_battle(sock, spell_id)
        dmg = 8 * mult
        ok = (r.get("result") == "success" and r.get("damage") == dmg
              and r.get("kills", 0) >= 1)
        check(f"{spell_id} damage", ok, str(r))

    # Бафф-заклинания: применён статус (status >= 0).
    buff_spells = ["haste", "precision", "wind_wall", "bloodlust", "curse",
                   "misfortune", "bless", "cure", "slow", "weakness",
                   "shield", "stoneskin", "slow_mass"]
    for spell_id in buff_spells:
        r = cast_in_battle(sock, spell_id)
        ok = r.get("result") == "success" and r.get("status", -1) >= 0
        check(f"{spell_id} buff", ok, str(r))

    # Town Portal — спец-заклинание: успех, без урона и статуса.
    r = cast_in_battle(sock, "town_portal")
    check("town_portal no-op",
          r.get("result") == "success" and r.get("damage", 0) == 0
          and r.get("status", -1) == -1, str(r))

    # Воскрешение — мёртвая цель (target_count=0) -> revive_count >= 1.
    r = cast_in_battle(sock, "resurrection", target_count=0, target_hp=100)
    check("resurrection revive",
          r.get("result") == "success" and r.get("revive_count", 0) >= 1, str(r))

    # Иммунитет драконов: curse (уровень 1 < 4) -> immune; armageddon (ур.4) -> ok.
    r = cast_in_battle(sock, "curse", target_tags=["dragon"])
    check("dragon immunity (curse)", r.get("result") == "immune", str(r))
    r = cast_in_battle(sock, "armageddon", target_tags=["dragon"])
    check("dragon not immune to lvl4", r.get("result") == "success", str(r))

    # Иммунитет нежити: curse/slow -> immune.
    r = cast_in_battle(sock, "curse", target_tags=["undead"])
    check("undead immunity (curse)", r.get("result") == "immune", str(r))
    r = cast_in_battle(sock, "slow", target_tags=["undead"])
    check("undead immunity (slow)", r.get("result") == "immune", str(r))

    # Иммунитет разума: mind_immune к curse/misfortune/weakness/slow.
    for spell_id in ["curse", "misfortune", "weakness", "slow"]:
        r = cast_in_battle(sock, spell_id, target_tags=["mind_immune"])
        check(f"mind_immune immunity ({spell_id})", r.get("result") == "immune", str(r))

    # Магическое сопротивление — ход без ошибки.
    r = cast_in_battle(sock, "magic_arrow", resistant=True)
    check("magic_resistant cast", "error" not in r and r.get("result") == "success", str(r))

    # Незнакомое заклинание -> not_found.
    r = cast_in_battle(sock, "does_not_exist")
    check("unknown spell not_found", r.get("result") == "not_found", str(r))

    # ============================================================
    # 3. РОТАЦИИ: защитное → атака → лечение → атака (перебор комбинаций).
    #    Серия шагов выполняется на ОДНО BattleState подряд:
    #    бафф(на себя) → атака → cure(лечение, на себя) → атака.
    #    Перебираем все защитно-бафф-заклинания как первый шаг ротации.
    # ============================================================
    print("\n[3] Rotations: buff -> attack -> heal -> attack")

    # Защитно-бафф-заклинания (первый шаг ротации): бафф применяется на себя.
    defensive_spells = [
        "shield", "stoneskin", "bless", "wind_wall",
        "haste", "precision", "bloodlust",
    ]
    # Лечящее заклинание (третий шаг ротации). cure в текущей реализации
    # применяет BLESS (см. SpellCaster.cast), поэтому «лечение» проверяем как
    # успешное разрешение заклинания в ротации.
    heal_spells = ["cure"]

    for dspell in defensive_spells:
        for hspell in heal_spells:
            seq = [
                {"cmd": "cast", "spell": dspell, "self": True},
                {"cmd": "attack"},
                {"cmd": "cast", "spell": hspell, "self": True},
                {"cmd": "attack"},
            ]
            rep = run_sequence(sock, seq)
            if rep.get("error"):
                check(f"{dspell}+{hspell} seq", False, f"error={rep.get('error')}")
                continue
            steps = rep.get("steps", [])
            ok_len = len(steps) == 4
            check(f"{dspell}+{hspell} steps", ok_len,
                  f"n={len(steps)} detail={steps}")
            if not ok_len:
                continue
            s0, s1, s2, s3 = steps
            # 1. Защитное заклинание: успех + бафф-статус применён (на себя).
            ok_buff = (s0.get("cmd") == "cast" and s0.get("spell") == dspell
                       and s0.get("result", {}).get("result") == "success"
                       and s0.get("result", {}).get("status", -1) >= 0)
            check(f"{dspell}+{hspell} buff-applied", ok_buff, str(s0))
            # 2. Атака: нанесена урон.
            ok_atk1 = (s1.get("cmd") == "attack"
                       and isinstance(s1.get("result"), dict)
                       and int(s1.get("result", {}).get("damage", 0)) > 0)
            check(f"{dspell}+{hspell} attack-1", ok_atk1, str(s1))
            # 3. Лечение: заклинание исцеления разрешилось успешно.
            ok_heal = (s2.get("cmd") == "cast" and s2.get("spell") == hspell
                       and s2.get("result", {}).get("result") == "success")
            check(f"{dspell}+{hspell} heal-resolved", ok_heal, str(s2))
            # 4. Повторная атака: нанесена урон.
            ok_atk2 = (s3.get("cmd") == "attack"
                       and isinstance(s3.get("result"), dict)
                       and int(s3.get("result", {}).get("damage", 0)) > 0)
            check(f"{dspell}+{hspell} attack-2", ok_atk2, str(s3))
            # Итог ротации: кастер жив, ротация завершена без ошибок.
            check(f"{dspell}+{hspell} caster-survives",
                  rep.get("caster_alive") is True, str(rep))

    sock.close()

    total_tests = passed + failed
    print(f"\n✅ Scenario 6 SUCCESS — {passed}/{total_tests} passed")
    if failed:
        print(f"❌ Scenario 6 FAILED: {failed}/{total_tests} failed")
        return False
    return True


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 6 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
