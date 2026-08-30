"""
scenario_7_battle_spells.py — Сценарий «Боевые заклинания → система заклинаний»
(седьмой сценарий).

Конвертирует 20 боевых заклинаний (SpellRegistry) в быструю форму
архитектуру (SpellDef) через BattleSpellBridge и применяет их в бою как
обычные заклинания.

Три части:
  1. SPELLIFY — каждое из 20 заклинаний представляется как быстрое:
     speed=fast, template/params выведены из категории, cost = мана.
  2. APPLY_IN_BATTLE — заклинание применяется к юниту в реальном BattleState
     через BattleSpellBridge.apply_spell (урон/статус/лечение/воскрешение/
     иммунитет/сопротивление/unknown).
  3. INTEGRATION — переведённые заклинания регистрируются в системе
     (SpellbookRegistry) и проверяется рост счётчика заклинаний.

Протокол: живая игра, сокет localhost:9095, newline-delimited JSON.

Запуск:
    python3 tools/scenarios/scenario_7_battle_spells.py
    # или через оркестратора:
    ./tools/shell/play_scenario.sh 7
"""

import socket
import json
import sys

HOST, PORT = "localhost", 9095


def send_cmd(sock, action, args=None, cmd_id=0):
    msg = {"id": cmd_id, "action": action, "args": args or {}}
    sock.sendall((json.dumps(msg) + "\n").encode("utf-8"))
    sock.settimeout(10.0)
    buf = ""
    while "\n" not in buf:
        chunk = sock.recv(65536)
        if not chunk:
            break
        buf += chunk.decode("utf-8")
    return json.loads(buf.split("\n")[0])


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
    # Урон (damage_multiplier): amount = mult, SP=8 → damage = 8*mult.
    ("magic_arrow", "damage", 10),
    ("lightning_bolt", "damage", 25),
    ("fireball", "damage", 20),
    ("armageddon", "damage", 40),
    ("meteor_shower", "damage", 30),

    # Баффы (keyword): применяется статус на юните.
    ("haste", "keyword", "HASTE"),
    ("precision", "keyword", "PRECISION"),
    ("wind_wall", "keyword", "WIND_WALL"),
    ("bloodlust", "keyword", "BLOODLUST"),
    ("bless", "keyword", "BLESS"),
    ("shield", "keyword", "SHIELD"),
    ("stoneskin", "keyword", "STONESKIN"),

    # Дебафы (debuff): применяется статус на враге.
    ("curse", "debuff", "CURSE"),
    ("misfortune", "debuff", "MISFORTUNE"),
    ("slow", "debuff", "SLOW"),
    ("weakness", "debuff", "WEAKNESS"),
    ("slow_mass", "debuff", "SLOW"),

    # Спец-заклинания.
    ("cure", "heal", None),
    ("resurrection", "revive", None),
    ("town_portal", "portal", None),
]

# Ожидаемые шаблоны (система заклинаний) для каждого category.
CAT_TEMPLATE = {
    "damage": "DIRECT_DAMAGE",
    "keyword": "KEYWORD_BUFF",
    "debuff": "DEBUFF_CONTROL",
    "heal": "HEAL_CLEAR",
    "revive": "REVIVE",
    "portal": "PORTAL",
}

# Бафф- и дебаффы, к которым нежность разума / нежить / драконы имеют иммунитет.
MIND_IMMUNE = ["curse", "misfortune", "weakness", "slow"]


def run_scenario():
    print("--- Running Scenario 7 (Battle Spells -> Spell system) ---")
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
    # 1. SPELLIFY — 20 боевых заклинаний → быстрой форме («быстрые»).
    # ============================================================
    print("\n[1] Battle-spellify all 20 battle spells")
    spell_results = {}
    for sid, category, expected_kw in SPELLS:
        r = battle_spell(sock, sid)
        if r.get("error"):
            check(f"{sid} spellify", False, f"error={r.get('error')}")
            continue
        spell = r.get("spell") or {}
        tmpl = spell.get("template")
        speed = spell.get("speed")
        cost = spell.get("cost")
        params = spell.get("params") or {}
        # category → шаблон.
        ok_tmpl = tmpl == CAT_TEMPLATE[category]
        # Все боевые заклинания — «быстрые».
        ok_speed = speed == "fast"
        # cost = мана (base_mana), неотрицательное число.
        ok_cost = isinstance(cost, (int, float)) and cost >= 0
        # params: keyword для keyword/debuff; amount для damage.
        ok_params = True
        if category == "damage":
            ok_params = params.get("amount") == expected_kw
        elif category in ("keyword", "debuff"):
            ok_params = params.get("keyword") == expected_kw
        check(f"{sid} spellify", ok_tmpl and ok_speed and ok_cost and ok_params,
              f"tmpl={tmpl} speed={speed} cost={cost} params={params}")
        spell_results[sid] = r

    # ============================================================
    # 2. APPLY_IN_BATTLE — заклинание применяется в бою как обычное заклинание.
    # ============================================================
    print("\n[2] Apply each spell in battle context")
    for sid, category, expected_kw in SPELLS:
        r = spell_results.get(sid) or battle_spell(sock, sid)
        apply = r.get("apply") or {}

        if category == "damage":
            dmg = 8 * expected_kw
            ok = (apply.get("result") == "success"
                  and apply.get("damage") == dmg
                  and apply.get("kills", 0) >= 1)
            check(f"{sid} damage", ok, str(apply))
        elif category in ("keyword", "debuff"):
            ok = apply.get("result") == "success" and apply.get("status", -1) >= 0
            check(f"{sid} {category}", ok, str(apply))
        elif category == "heal":
            ok = apply.get("result") == "success" and "heal" in apply
            check(f"{sid} heal/clear", ok, str(apply))
        elif category == "revive":
            ok = apply.get("result") == "success" and apply.get("revive_count", 0) >= 1
            check(f"{sid} revive", ok, str(apply))
        elif category == "portal":
            ok = (apply.get("result") == "success"
                  and apply.get("damage", 0) == 0
                  and apply.get("status", -1) == -1)
            check(f"{sid} portal no-op", ok, str(apply))

    # Иммунитет драконов: curse (ур.1 < 4) → immune; armageddon (ур.4) → ok.
    r = battle_spell(sock, "curse", tags=["dragon"])
    check("dragon immunity (curse)", r.get("apply", {}).get("result") == "immune", str(r))
    r = battle_spell(sock, "armageddon", tags=["dragon"])
    check("dragon not immune to lvl4", r.get("apply", {}).get("result") == "success", str(r))

    # Иммунитет нежити: curse/slow → immune.
    r = battle_spell(sock, "curse", tags=["undead"])
    check("undead immunity (curse)", r.get("apply", {}).get("result") == "immune", str(r))
    r = battle_spell(sock, "slow", tags=["undead"])
    check("undead immunity (slow)", r.get("apply", {}).get("result") == "immune", str(r))

    # Иммунитет разума: curse/misfortune/weakness/slow → immune.
    for sid in MIND_IMMUNE:
        r = battle_spell(sock, sid, tags=["mind_immune"])
        check(f"mind_immune immunity ({sid})",
              r.get("apply", {}).get("result") == "immune", str(r))

    # Магическое сопротивление — ход без ошибки, success.
    r = battle_spell(sock, "magic_arrow", resistant=True)
    check("magic_resistant cast", "error" not in r and r.get("apply", {}).get("result") == "success",
          str(r))

    # Незнакомое заклинание → not_found.
    r = battle_spell(sock, "does_not_exist")
    check("unknown spell not_found", r.get("apply", {}).get("result") == "not_found", str(r))

    # ============================================================
    # 3. INTEGRATION — переведённые заклинания в системе.
    # ============================================================
    print("\n[3] Converted spells registered in spell system")
    reg = spell_registry(sock)
    if reg.get("error"):
        check("spell_registry", False, f"error={reg.get('error')}")
    else:
        count = reg.get("count", 0)
        # 505 исходных + 20 переведённых (каждое регистрируется один раз,
        # но некоторые apply выше уже вызывали BATTLE_SPELL — поэтому проверяем
        # что count >= 505 + 20).
        check("spell_registry grew by >=20",
              isinstance(count, int) and count >= 525, f"count={count}")
        check("template_count > 0",
              isinstance(reg.get("template_count", 0), int) and reg.get("template_count", 0) > 0,
              f"templates={reg.get('template_count')}")

    sock.close()

    total_tests = passed + failed
    print(f"\n✅ Scenario 7 SUCCESS — {passed}/{total_tests} passed")
    if failed:
        print(f"❌ Scenario 7 FAILED: {failed}/{total_tests} failed")
        return False
    return True


if __name__ == "__main__":
    try:
        ok = run_scenario()
    except Exception as e:  # noqa: BLE001
        print(f"❌ Scenario 7 error: {e}")
        ok = False
    sys.exit(0 if ok else 1)
