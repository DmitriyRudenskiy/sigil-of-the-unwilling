"""
scenario_7_battle_spells.py — Сценарий «Боевые заклинания → система заклинаний».

Три части:
  1. SPELLIFY — каждое из 20 заклинаний представляется как быстрое
     (speed=fast, template/params выведены из категории, cost = мана).
  2. APPLY_IN_BATTLE — заклинание применяется к юниту в реальном BattleState
     через BattleSpellBridge.apply_spell.
  3. INTEGRATION — переведённые заклинания регистрируются в системе
     (SpellbookRegistry) и проверяется рост счётчика заклинаний.

Протокол: живая игра, сокет localhost:9095, newline-delimited JSON.

Запуск:
    python3 tools/scenarios/scenario_7_battle_spells.py
    # или: ./tools/shell/play_scenario.sh 7
    # или: ./tools/shell/run_all_scenarios.sh
"""

import sys

from scenario_lib import connect, send_cmd, Reporter, scan_server_log


def battle_spell(sock, spell_id, tags=None, hp=100, count=10, resistant=False):
    args = {
        "spell_id": spell_id,
        "tags": list(tags or []),
        "hp": hp,
        "count": count,
        "resistant": resistant,
    }
    return send_cmd(sock, "BATTLE_SPELL", args)


def spell_registry(sock):
    return send_cmd(sock, "SPELL_REGISTRY")


## 20 боевых заклинаний с ожидаемой категорией конвертации.
## category: damage / keyword / debuff / heal / revive / portal
SPELLS = [
    ("magic_arrow", "damage", 10),
    ("lightning_bolt", "damage", 25),
    ("fireball", "damage", 20),
    ("armageddon", "damage", 40),
    ("meteor_shower", "damage", 30),
    ("haste", "keyword", "HASTE"),
    ("precision", "keyword", "PRECISION"),
    ("wind_wall", "keyword", "WIND_WALL"),
    ("bloodlust", "keyword", "BLOODLUST"),
    ("bless", "keyword", "BLESS"),
    ("shield", "keyword", "SHIELD"),
    ("stoneskin", "keyword", "STONESKIN"),
    ("curse", "debuff", "CURSE"),
    ("misfortune", "debuff", "MISFORTUNE"),
    ("slow", "debuff", "SLOW"),
    ("weakness", "debuff", "WEAKNESS"),
    ("slow_mass", "debuff", "SLOW"),
    ("cure", "heal", None),
    ("resurrection", "revive", None),
    ("town_portal", "portal", None),
]

CAT_TEMPLATE = {
    "damage": "DIRECT_DAMAGE",
    "keyword": "KEYWORD_BUFF",
    "debuff": "DEBUFF_CONTROL",
    "heal": "HEAL_CLEAR",
    "revive": "REVIVE",
    "portal": "PORTAL",
}

MIND_IMMUNE = ["curse", "misfortune", "weakness", "slow"]


def run_scenario():
    print("--- Running Scenario 7 (Battle Spells -> Spell system) ---")
    rep = Reporter()
    sock = connect()

    # [1] SPELLIFY — 20 боевых заклинаний → быстрой форме.
    print("\n[1] Battle-spellify all 20 battle spells")
    spell_results = {}
    for sid, category, expected_kw in SPELLS:
        r = battle_spell(sock, sid)
        if r.get("error"):
            rep.check(f"{sid} spellify", False, f"error={r.get('error')}")
            continue
        spell = r.get("spell") or {}
        tmpl = spell.get("template")
        speed = spell.get("speed")
        cost = spell.get("cost")
        params = spell.get("params") or {}
        ok_tmpl = tmpl == CAT_TEMPLATE[category]
        ok_speed = speed == "fast"
        ok_cost = isinstance(cost, (int, float)) and cost >= 0
        ok_params = True
        if category == "damage":
            ok_params = params.get("amount") == expected_kw
        elif category in ("keyword", "debuff"):
            ok_params = params.get("keyword") == expected_kw
        rep.check(f"{sid} spellify", ok_tmpl and ok_speed and ok_cost and ok_params,
                  f"tmpl={tmpl} speed={speed} cost={cost} params={params}")
        spell_results[sid] = r

    # [2] APPLY_IN_BATTLE — заклинание применяется в бою как обычное.
    print("\n[2] Apply each spell in battle context")
    for sid, category, expected_kw in SPELLS:
        r = spell_results.get(sid) or battle_spell(sock, sid)
        apply = r.get("apply") or {}
        if category == "damage":
            dmg = 8 * expected_kw
            rep.check(f"{sid} damage",
                      apply.get("result") == "success" and apply.get("damage") == dmg and apply.get("kills", 0) >= 1, str(apply))
        elif category in ("keyword", "debuff"):
            rep.check(f"{sid} {category}", apply.get("result") == "success" and apply.get("status", -1) >= 0, str(apply))
        elif category == "heal":
            rep.check(f"{sid} heal/clear", apply.get("result") == "success" and "heal" in apply, str(apply))
        elif category == "revive":
            rep.check(f"{sid} revive", apply.get("result") == "success" and apply.get("revive_count", 0) >= 1, str(apply))
        elif category == "portal":
            rep.check(f"{sid} portal no-op",
                      apply.get("result") == "success" and apply.get("damage", 0) == 0 and apply.get("status", -1) == -1, str(apply))

    r = battle_spell(sock, "curse", tags=["dragon"])
    rep.check("dragon immunity (curse)", r.get("apply", {}).get("result") == "immune", str(r))
    r = battle_spell(sock, "armageddon", tags=["dragon"])
    rep.check("dragon not immune to lvl4", r.get("apply", {}).get("result") == "success", str(r))

    r = battle_spell(sock, "curse", tags=["undead"])
    rep.check("undead immunity (curse)", r.get("apply", {}).get("result") == "immune", str(r))
    r = battle_spell(sock, "slow", tags=["undead"])
    rep.check("undead immunity (slow)", r.get("apply", {}).get("result") == "immune", str(r))

    for sid in MIND_IMMUNE:
        r = battle_spell(sock, sid, tags=["mind_immune"])
        rep.check(f"mind_immune immunity ({sid})", r.get("apply", {}).get("result") == "immune", str(r))

    r = battle_spell(sock, "magic_arrow", resistant=True)
    rep.check("magic_resistant cast", "error" not in r and r.get("apply", {}).get("result") == "success", str(r))

    r = battle_spell(sock, "does_not_exist")
    rep.check("unknown spell not_found", r.get("apply", {}).get("result") == "not_found", str(r))

    # [3] INTEGRATION — переведённые заклинания в системе.
    print("\n[3] Converted spells registered in spell system")
    reg = spell_registry(sock)
    if reg.get("error"):
        rep.check("spell_registry", False, f"error={reg.get('error')}")
    else:
        count = reg.get("count", 0)
        rep.check("spell_registry grew by >=20", isinstance(count, int) and count >= 525, f"count={count}")
        rep.check("template_count > 0", isinstance(reg.get("template_count", 0), int) and reg.get("template_count", 0) > 0, f"templates={reg.get('template_count')}")

    sock.close()

    errors, warnings = scan_server_log()
    print(f"  console: {'CLEAN' if not errors else 'DIRTY'} "
          f"(errors={len(errors)}, warnings={len(warnings)})")
    for e in errors[:5]:
        print(f"    [console] {e}")

    print(f"{'PASS' if rep.ok else 'FAIL'} Scenario 7 ({rep.summary()})")
    return rep.ok


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 7 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
