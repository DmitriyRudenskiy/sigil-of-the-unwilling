"""
scenario_6_battle.py — Сценарий «Бой и цепочки заклинаний».

Две задачи:
  1. Эмуляция боя (EMULATE_BATTLE): две армии сражаются до победы через
     BattleState + BattleActionResolver. Проверяет структурные инварианты
     разрешёного боя.
  2. Все цепочки заклинаний (CAST_IN_BATTLE): каждое из 20 заклинаний прогоняется
     в контексте боя — юниты живут в реальном BattleState, каст через
     apply_spell. Проверяется категория эффекта: урон/бафф/лечение/воскрешение/
     иммунитет/сопротивление/unknown.
  3. Ротации: защитное → атака → лечение → атака (перебор комбинаций на одном
     BattleState).

Протокол: живая игра, сокет localhost:9095, newline-delimited JSON.

Запуск:
    python3 tools/scenarios/scenario_6_battle.py
    # или: ./tools/shell/play_scenario.sh 6
    # или: ./tools/shell/run_all_scenarios.sh
"""

import sys

from scenario_lib import connect, send_cmd, Reporter, scan_server_log


def emulate_battle(sock, attacker_army, defender_army, attacker_bonus=None, defender_bonus=None):
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
    rep = Reporter()
    sock = connect()

    # [1] ЭМУЛЯЦИЯ БОЯ: две армии сражаются до победы.
    print("\n[1] Battle emulation")
    report = emulate_battle(sock, ATK_ARMY, DEF_ARMY, BONUS, BONUS)
    if report.get("error"):
        rep.check("EMULATE_BATTLE no error", False, str(report.get("error")))
    else:
        winner = report.get("winner")
        atk_surv = report.get("atk_survivors", [])
        def_surv = report.get("def_survivors", [])
        turns = report.get("turns", 0)
        events = report.get("events", [])
        atk_loss = report.get("atk_loss")
        atk_lost = sum(s.get("count", 0) for s in atk_loss if isinstance(s, dict)) \
            if isinstance(atk_loss, list) else 0
        atk_now = sum(s.get("count", 0) for s in atk_surv)
        def_now = sum(s.get("count", 0) for s in def_surv)

        rep.check("battle resolved", report.get("battle_over") is True, f"battle_over={report.get('battle_over')}")
        rep.check("winner set", winner in ("attacker", "defender"), f"winner={winner}")
        rep.check("turns > 0", isinstance(turns, int) and turns > 0, f"turns={turns}")
        rep.check("atk_survivors is list", isinstance(atk_surv, list), f"n={len(atk_surv)}")
        rep.check("def_survivors is list", isinstance(def_surv, list), f"n={len(def_surv)}")
        rep.check("attacks happened", isinstance(events, list) and any(e.get("action") == "attack" for e in events), f"events={len(events)}")
        rep.check("atk_lost >= 0", isinstance(atk_lost, int) and atk_lost >= 0, f"lost={atk_lost}")
        rep.check("atk survivors <= start", atk_now <= sum(s.get("count", 0) for s in ATK_ARMY), f"{atk_now} <= {sum(s.get('count', 0) for s in ATK_ARMY)}")
        rep.check("def survivors <= start", def_now <= sum(s.get("count", 0) for s in DEF_ARMY), f"{def_now} <= {sum(s.get('count', 0) for s in DEF_ARMY)}")
        if winner == "attacker":
            rep.check("loser defender dead", def_now == 0, f"def_surv={def_now}")
        elif winner == "defender":
            rep.check("loser attacker dead", atk_now == 0, f"atk_surv={atk_now}")

    # [2] ВСЕ ЦЕПОЧКИ ЗАКЛИНАНИЙ — каждое из 20 заклинаний в бою.
    print("\n[2] All spell chains (in battle context)")
    damage_spells = {"magic_arrow": 10, "lightning_bolt": 25, "fireball": 20, "armageddon": 40, "meteor_shower": 30}
    for spell_id, mult in damage_spells.items():
        r = cast_in_battle(sock, spell_id)
        dmg = 8 * mult
        rep.check(f"{spell_id} damage", r.get("result") == "success" and r.get("damage") == dmg and r.get("kills", 0) >= 1, str(r))

    buff_spells = ["haste", "precision", "wind_wall", "bloodlust", "curse", "misfortune", "bless", "cure", "slow", "weakness", "shield", "stoneskin", "slow_mass"]
    for spell_id in buff_spells:
        r = cast_in_battle(sock, spell_id)
        rep.check(f"{spell_id} buff", r.get("result") == "success" and r.get("status", -1) >= 0, str(r))

    r = cast_in_battle(sock, "town_portal")
    rep.check("town_portal no-op", r.get("result") == "success" and r.get("damage", 0) == 0 and r.get("status", -1) == -1, str(r))

    r = cast_in_battle(sock, "resurrection", target_count=0, target_hp=100)
    rep.check("resurrection revive", r.get("result") == "success" and r.get("revive_count", 0) >= 1, str(r))

    r = cast_in_battle(sock, "curse", target_tags=["dragon"])
    rep.check("dragon immunity (curse)", r.get("result") == "immune", str(r))
    r = cast_in_battle(sock, "armageddon", target_tags=["dragon"])
    rep.check("dragon not immune to lvl4", r.get("result") == "success", str(r))

    r = cast_in_battle(sock, "curse", target_tags=["undead"])
    rep.check("undead immunity (curse)", r.get("result") == "immune", str(r))
    r = cast_in_battle(sock, "slow", target_tags=["undead"])
    rep.check("undead immunity (slow)", r.get("result") == "immune", str(r))

    for spell_id in ["curse", "misfortune", "weakness", "slow"]:
        r = cast_in_battle(sock, spell_id, target_tags=["mind_immune"])
        rep.check(f"mind_immune immunity ({spell_id})", r.get("result") == "immune", str(r))

    r = cast_in_battle(sock, "magic_arrow", resistant=True)
    rep.check("magic_resistant cast", "error" not in r and r.get("result") == "success", str(r))

    r = cast_in_battle(sock, "does_not_exist")
    rep.check("unknown spell not_found", r.get("result") == "not_found", str(r))

    # [3] РОТАЦИИ: защитное → атака → лечение → атака (перебор комбинаций).
    print("\n[3] Rotations: buff -> attack -> heal -> attack")
    defensive_spells = ["shield", "stoneskin", "bless", "wind_wall", "haste", "precision", "bloodlust"]
    heal_spells = ["cure"]
    for dspell in defensive_spells:
        for hspell in heal_spells:
            seq = [
                {"cmd": "cast", "spell": dspell, "self": True},
                {"cmd": "attack"},
                {"cmd": "cast", "spell": hspell, "self": True},
                {"cmd": "attack"},
            ]
            rep_seq = run_sequence(sock, seq)
            if rep_seq.get("error"):
                rep.check(f"{dspell}+{hspell} seq", False, f"error={rep_seq.get('error')}")
                continue
            steps = rep_seq.get("steps", [])
            rep.check(f"{dspell}+{hspell} steps", len(steps) == 4, f"n={len(steps)} detail={steps}")
            if len(steps) != 4:
                continue
            s0, s1, s2, s3 = steps
            rep.check(f"{dspell}+{hspell} buff-applied",
                      s0.get("cmd") == "cast" and s0.get("spell") == dspell
                      and s0.get("result", {}).get("result") == "success"
                      and s0.get("result", {}).get("status", -1) >= 0, str(s0))
            rep.check(f"{dspell}+{hspell} attack-1",
                      s1.get("cmd") == "attack" and isinstance(s1.get("result"), dict)
                      and int(s1.get("result", {}).get("damage", 0)) > 0, str(s1))
            rep.check(f"{dspell}+{hspell} heal-resolved",
                      s2.get("cmd") == "cast" and s2.get("spell") == hspell
                      and s2.get("result", {}).get("result") == "success", str(s2))
            rep.check(f"{dspell}+{hspell} attack-2",
                      s3.get("cmd") == "attack" and isinstance(s3.get("result"), dict)
                      and int(s3.get("result", {}).get("damage", 0)) > 0, str(s3))
            rep.check(f"{dspell}+{hspell} caster-survives", rep_seq.get("caster_alive") is True, str(rep_seq))

    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} "
          f"(errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 6 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 6 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
